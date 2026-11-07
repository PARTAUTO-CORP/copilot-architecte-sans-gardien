#requires -Version 7.3
<#
  Installs Copilot Architecte in full-power mode. Re-runnable.
  Every file it changes is first copied to <CopilotHome>\backups\architecte-<date>.
  Extra agents, skills and unrelated settings are kept.

  .\install.ps1                         default install
  .\install.ps1 -Model <name> -Effort xhigh  effort used with a fixed model (default: high; Auto picks its own)
  .\install.ps1 -Model claude-opus-5.5  pin a model available on your plan
#>
param(
    [string]$CopilotHome = $(if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' }),
    [string]$ProfilePath = $PROFILE.CurrentUserAllHosts,
    [ValidateSet('none', 'minimal', 'low', 'medium', 'high', 'xhigh', 'max')]
    [string]$Effort = 'high',
    [string]$Model = '',
    [switch]$SkipUserEnv,  # used by tests: leaves the persistent user environment untouched
    [string]$VsCodeMcp = $(if ($SkipUserEnv) { '' } else { Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Code/User/mcp.json' }),  # %APPDATA% on Windows, ~/.config on Linux
    [switch]$SkipScraperDeps,  # skips the Python environment of the scraper (download of about 200 MB)
    [switch]$NoPrompt,  # no question about MCP keys; run .\mcp-scraping.ps1 later to add them
    [switch]$Reset  # reinitialize kit-owned files and remove obsolete files recorded in the kit manifest
)
$ErrorActionPreference = 'Stop'
# Relative paths use '/': Join-Path turns it into '\' on Windows.
$venvPython = if ($IsWindows) { 'venv/Scripts/python.exe' } else { 'venv/bin/python' }

$payload = Join-Path $PSScriptRoot 'payload'
if (-not (Test-Path $payload)) { throw "Missing payload folder: $payload" }

if (-not $NoPrompt -and -not $Reset) {
    Write-Host ''
    Write-Host 'COPILOT ARCHITECTE - Installation mode' -ForegroundColor Cyan
    Write-Host '  1. Update (recommended): add new kit files, update kit files with backups, and keep personal settings and extra files.'
    Write-Host '  2. Reinitialize: restore kit files to this package version and remove obsolete kit files recorded by the installer.'
    Write-Host '     Personal settings and files not recorded as kit-owned are kept in either mode.'
    $mode = Read-Host 'Choose 1 or 2 [1]'
    if ($mode -eq '2') { $Reset = $true }
    elseif ([string]::IsNullOrWhiteSpace($mode) -or $mode -eq '1') { $Reset = $false }
    else { throw 'Installation cancelled: choose 1 or 2.' }
}
if ($Reset -and -not $NoPrompt) {
    Write-Host 'Reinitialization will replace kit-owned files (backups are created first) and remove only obsolete files recorded by the installer.' -ForegroundColor Yellow
    if ((Read-Host 'Type REINITIALISER to confirm') -cne 'REINITIALISER') {
        throw 'Reinitialization cancelled before any changes.'
    }
}

$settingsPath = Join-Path $CopilotHome 'settings.json'
# Parse before any write: a corrupt settings.json must stop the install, not be overwritten.
$settings = if (Test-Path $settingsPath) {
    Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
}
if ($null -eq $settings) { $settings = [ordered]@{} }

$backupDir = Join-Path $CopilotHome ("backups/architecte-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))

function Backup-Item([string]$Path, [string]$Name) {
    if (-not (Test-Path $Path)) { return }
    $target = Join-Path $backupDir $Name
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $Path -Destination $target -Force
}

function Set-MarkedBlock([string]$Path, [string]$Name, [string]$Body) {
    $begin = '# >>> copilot-architecte >>>'
    $end = '# <<< copilot-architecte <<<'
    $block = "$begin`n$($Body.Trim())`n$end"
    $current = if (Test-Path $Path) { Get-Content $Path -Raw } else { '' }
    if ($null -eq $current) { $current = '' }
    $pattern = '(?s)' + [regex]::Escape($begin) + '.*?' + [regex]::Escape($end)
    $new = if ($current -match $pattern) {
        # MatchEvaluator: the block contains $args, which must stay literal.
        [regex]::Replace($current, $pattern, { param($m) $block })
    } else {
        ($current.TrimEnd() + "`n`n" + $block + "`n").TrimStart()
    }
    if ($new -ceq $current) { return }
    Backup-Item $Path $Name
    New-Item -ItemType Directory -Force (Split-Path $Path) | Out-Null
    Set-Content -LiteralPath $Path -Value $new -NoNewline
}

# 1. Agents, skills and scraping engine
$sources = @(Get-ChildItem (Join-Path $payload 'agents') -File) +
           @(Get-ChildItem (Join-Path $payload 'skills') -Recurse -File) +
           @(Get-ChildItem (Join-Path $payload 'scraper') -File) +
           @(Get-ChildItem (Join-Path $payload 'decision') -File)
$manifestPath = Join-Path $CopilotHome 'architecte-manifest.json'
$oldManagedFiles = @()
if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -AsHashtable
    if ($manifest['schemaVersion'] -ne 1 -or $manifest['managedFiles'] -isnot [array]) {
        throw "Invalid Copilot Architecte ownership manifest: $manifestPath"
    }
    $oldManagedFiles = @($manifest['managedFiles'] | ForEach-Object { [string]$_ })
}
$sep = [IO.Path]::DirectorySeparatorChar
$copilotRoot = [IO.Path]::GetFullPath($CopilotHome).TrimEnd($sep) + $sep
foreach ($relative in $oldManagedFiles) {
    if ([IO.Path]::IsPathRooted($relative) -or $relative -match '(^|[\\/])\.\.([\\/]|$)') {
        throw "Unsafe path in Copilot Architecte ownership manifest: $relative"
    }
    $resolvedPath = [IO.Path]::GetFullPath((Join-Path $CopilotHome $relative))
    if (-not $resolvedPath.StartsWith($copilotRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unsafe path in Copilot Architecte ownership manifest: $relative"
    }
}
$currentManagedFiles = @($sources | ForEach-Object { [IO.Path]::GetRelativePath($payload, $_.FullName) })
foreach ($file in $sources) {
    $relative = [IO.Path]::GetRelativePath($payload, $file.FullName)
    $target = Join-Path $CopilotHome $relative
    if (Test-Path $target) {
        if ((Get-FileHash $target).Hash -eq (Get-FileHash $file.FullName).Hash) { continue }
        Backup-Item $target $relative
    }
    New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $target -Force
}

if ($Reset) {
    foreach ($relative in $oldManagedFiles | Where-Object { $_ -notin $currentManagedFiles }) {
        $stalePath = [IO.Path]::GetFullPath((Join-Path $CopilotHome $relative))
        if (Test-Path -LiteralPath $stalePath -PathType Leaf) {
            Backup-Item $stalePath $relative
            Remove-Item -LiteralPath $stalePath -Force
        }
    }
}
$manifestFiles = if ($Reset) { $currentManagedFiles } else { @($oldManagedFiles + $currentManagedFiles | Select-Object -Unique) }
$manifestChanged = -not (Test-Path $manifestPath) -or
    (($manifest['schemaVersion'] -ne 1) -or
     (@($manifestFiles).Count -ne @($oldManagedFiles).Count) -or
     (($manifestFiles -join "`n") -cne ($oldManagedFiles -join "`n")))
if ($manifestChanged) {
    Backup-Item $manifestPath 'architecte-manifest.json'
    [ordered]@{ schemaVersion = 1; managedFiles = @($manifestFiles) } |
        ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestPath
}

# 2. Global instructions (merged, so personal instructions stay)
Set-MarkedBlock (Join-Path $CopilotHome 'copilot-instructions.md') 'copilot-instructions.md' `
    (Get-Content (Join-Path $payload 'copilot-instructions.md') -Raw)

# 3. Persistent settings (merged, unrelated keys stay)
$settings['defaultPermissionMode'] = 'allow-all'
$settings['defaultMode'] = 'interactive'
$settings['stayInAutopilot'] = $false
$settings['experimental'] = $true
$settings['memory'] = $true
$settings['askUser'] = $true
$settings['continueOnAutoMode'] = $true
$settings['keepAlive'] = 'busy'
$settings['powershellFlags'] = @('-NoProfile', '-NoLogo', '-ExecutionPolicy', 'Bypass')
if ($Model) { $settings['model'] = $Model }

# Keep a persistent summary of the current context and session activity as a one-line status bar.
$statusLineScript = Join-Path $CopilotHome 'statusline.ps1'
$statusLineScriptBody = @'
$ErrorActionPreference = 'Stop'

function Format-CompactNumber([object]$Value) {
    if ($null -eq $Value) { return 'n/a' }
    $n = [double]::Parse([string]$Value)
    if ($n -ge 1000) { return ('{0:0.#}k' -f ($n / 1000)) }
    return [string]([math]::Round($n))
}

function Format-DurationMs([object]$Ms) {
    if ($null -eq $Ms) { return '00:00:00' }
    $totalSeconds = [long]([double]$Ms / 1000)
    $hours = [int]($totalSeconds / 3600)
    $minutes = [int](($totalSeconds % 3600) / 60)
    $seconds = [int]($totalSeconds % 60)
    return '{0:00}:{1:00}:{2:00}' -f $hours, $minutes, $seconds
}

try {
    $raw = [Console]::In.ReadToEnd()
    if ([string]::IsNullOrWhiteSpace($raw)) { $data = @{} }
    else { $data = $raw | ConvertFrom-Json -AsHashtable }

    $context = if ($data.ContainsKey('context_window')) { $data['context_window'] } else { @{} }
    $cost = if ($data.ContainsKey('cost')) { $data['cost'] } else { @{} }
    $modelData = if ($data.ContainsKey('model')) { $data['model'] } else { @{} }
    $workspace = if ($data.ContainsKey('workspace')) { $data['workspace'] } else { @{} }
    $directory = if ($data['cwd']) { [string]$data['cwd'] } elseif ($workspace['current_dir']) { [string]$workspace['current_dir'] } else { (Get-Location).Path }

    $remote = if ($data.ContainsKey('remote')) { $data['remote'] } else { @{} }
    $remoteContext = if ($remote -and $remote['context']) { $remote['context'] } else { @{} }
    $branch = [string]$remoteContext['branch']
    if (-not $branch -and (Get-Command git -ErrorAction SilentlyContinue)) {
        $gitBranch = & git -C $directory rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) { $branch = [string]$gitBranch }
    }
    if (-not $branch) { $branch = 'n/a' }

    $displayLimit = $context['displayed_context_limit']
    $currentTokens = $context['current_context_tokens']
    $usedPct = $context['current_context_used_percentage']
    if ($null -eq $usedPct -and $displayLimit -gt 0 -and $null -ne $currentTokens) {
        $usedPct = [double]$currentTokens * 100 / [double]$displayLimit
    }
    if ($null -eq $usedPct) { $usedPct = $context['used_percentage'] }
    $usedText = if ($null -ne $usedPct) { [math]::Min(100, [math]::Max(0, [double]$usedPct)) } else { $null }
    $gauge = if ($null -ne $usedText) {
        $filled = [int][math]::Round($usedText / 10, [MidpointRounding]::AwayFromZero)
        ('█' * $filled) + ('░' * (10 - $filled))
    } else { '░' * 10 }
    $percentText = if ($null -ne $usedText) { '{0:0}%' -f $usedText } else { 'n/a' }
    $contextText = '{0}/{1}' -f (Format-CompactNumber $currentTokens), (Format-CompactNumber $displayLimit)

    $requestCount = $cost['total_premium_requests']
    if ($null -eq $requestCount -and $cost.ContainsKey('total_requests')) { $requestCount = $cost['total_requests'] }
    $requestText = if ($null -ne $requestCount) { [string]([int]$requestCount) } else { 'n/a' }

    $modelText = if ($modelData.ContainsKey('display_name') -and -not [string]::IsNullOrWhiteSpace([string]$modelData['display_name'])) {
        [string]$modelData['display_name']
    } else {
        'Copilot'
    }

    $durationText = Format-DurationMs $cost['total_duration_ms']
    [Console]::Out.WriteLine(('[{0}] {1} | branch {2} | Context {3} {4} {5} | Req {6} | {7}' -f `
        $modelText, $directory, $branch, $contextText, $gauge, $percentText, $requestText, $durationText))
} catch {
    [Console]::Error.WriteLine("Status line failed: $($_.Exception.Message)")
    exit 1
}
'@
New-Item -ItemType Directory -Force (Split-Path $statusLineScript) | Out-Null
Set-Content -LiteralPath $statusLineScript -Value $statusLineScriptBody -NoNewline

if ($settings['statusLine'] -isnot [System.Collections.IDictionary]) { $settings['statusLine'] = [ordered]@{} }
$settings['statusLine']['type'] = 'command'
$settings['statusLine']['command'] = "pwsh -NoProfile -ExecutionPolicy Bypass -File `"$statusLineScript`""
$settings['statusLine']['padding'] = 1
$settings['statusLine']['refreshInterval'] = 5

if ($settings['footer'] -isnot [System.Collections.IDictionary]) { $settings['footer'] = [ordered]@{} }
$settings['footer']['showQuota'] = $true
$settings['footer']['showContext'] = $true

# Deny rules beat --yolo and the sandbox blocks commands even in autopilot: lift both.
$settings['deniedUrls'] = @()
if ($settings['sandbox'] -isnot [System.Collections.IDictionary]) { $settings['sandbox'] = [ordered]@{} }
$settings['sandbox']['enabled'] = $false
if ($settings['permissions'] -is [System.Collections.IDictionary]) {
    $settings['permissions'].Remove('disableBypassPermissionsMode')
}

# Rubber duck: critique by another model family at high-stakes moments. Off by default in Copilot.
if ($settings['subagents'] -isnot [System.Collections.IDictionary]) { $settings['subagents'] = [ordered]@{} }
if ($settings['subagents']['agents'] -isnot [System.Collections.IDictionary]) { $settings['subagents']['agents'] = [ordered]@{} }
if ($settings['subagents']['agents']['rubber-duck'] -isnot [System.Collections.IDictionary]) { $settings['subagents']['agents']['rubber-duck'] = [ordered]@{} }
$settings['subagents']['agents']['rubber-duck']['autoInvoke'] = $true

New-Item -ItemType Directory -Force $CopilotHome | Out-Null
Backup-Item $settingsPath 'settings.json'
$json = $settings | ConvertTo-Json -Depth 32
$null = $json | ConvertFrom-Json  # never write invalid JSON: Copilot could fail to start
Set-Content -LiteralPath $settingsPath -Value $json

# 4. Removes the Gardien of an earlier install, backed up first: its hook would keep refusing commands.
foreach ($relative in 'hooks/architecte-gardien.json', 'gardien/garde.ps1', 'gardien/journal.jsonl', 'skills/script-guard/SKILL.md') {
    $old = Join-Path $CopilotHome $relative
    if (Test-Path -LiteralPath $old) {
        Backup-Item $old $relative
        Remove-Item -LiteralPath $old -Force
    }
}
foreach ($folder in 'gardien', 'skills/script-guard') {
    $old = Join-Path $CopilotHome $folder
    if ((Test-Path -LiteralPath $old) -and -not (Get-ChildItem -LiteralPath $old -Force)) { Remove-Item -LiteralPath $old -Force }
}

# 5. Launchers: these options have no persistent setting, so they live in the profile.
# COPILOT_ALLOW_ALL=true trusts the folder and loads its hooks, so it is set only for this launch.
# Copilot rejects --reasoning-effort on the Auto model, so it is passed only with a fixed model.
$fixedModel = [string]$settings['model']
$effortFlag = if ($fixedModel -and $fixedModel -ne 'auto') { " --reasoning-effort $Effort" } else { '' }
$flags = "--yolo --experimental --enable-all-github-mcp-tools --allow-all-mcp-server-instructions$effortFlag"
# copr has no one to answer: it stays autonomous.
$autoFlags = '--autopilot --no-ask-user --max-autopilot-continues 999999'
Set-MarkedBlock $ProfilePath 'powershell-profile.ps1' @"
function Invoke-CopilotArchitecte {
    `$env:COPILOT_ALLOW_ALL = 'true'
    try { copilot @args } finally { Remove-Item Env:COPILOT_ALLOW_ALL -ErrorAction SilentlyContinue }
}
function cop { Invoke-CopilotArchitecte $flags --agent architect @args }
function copr { Invoke-CopilotArchitecte $flags $autoFlags --agent architect --enable-memory -p `$args[0] @(`$args | Select-Object -Skip 1) }
function cop-pentest { Invoke-CopilotArchitecte $flags --agent pentest @args }
"@

# An earlier kit version made this variable permanent, which trusted any folder.
if (-not $SkipUserEnv) {
    [Environment]::SetEnvironmentVariable('COPILOT_ALLOW_ALL', $null, 'User')
}

# 6. MCP servers
& (Join-Path $PSScriptRoot 'mcp-scraping.ps1') -CopilotHome $CopilotHome -NoPrompt:$NoPrompt

# JEV also for Copilot in VS Code, which reads its own file.
if ($VsCodeMcp -and (Test-Path (Split-Path $VsCodeMcp))) {
    try {
        $vs = if (Test-Path $VsCodeMcp) { Get-Content $VsCodeMcp -Raw | ConvertFrom-Json -AsHashtable }
        if ($null -eq $vs) { $vs = [ordered]@{} }
        if ($vs['servers'] -isnot [System.Collections.IDictionary]) { $vs['servers'] = [ordered]@{} }
        $vs['servers']['jev'] = [ordered]@{ type = 'stdio'; command = (Join-Path $CopilotHome 'decision' $venvPython); args = @((Join-Path $CopilotHome 'decision/jev_mcp.py')) }
        Backup-Item $VsCodeMcp 'vscode-mcp.json'
        $vs | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $VsCodeMcp
    } catch { Write-Warning "VS Code MCP file left unchanged, it could not be read: $VsCodeMcp" }
}

# 7. Python environments: scraping engine and browser decisions, kept apart so one failure leaves the other working
if (-not $SkipScraperDeps) {
    $python = Get-Command $(if ($IsWindows) { 'python' } else { 'python3' }) -ErrorAction SilentlyContinue
    if ($python) {
        # The real file, not a symlink such as ~/.local/bin/python3: a venv built from a symlink cannot find its standard library.
        $pythonExe = & $python.Source -c 'import os, sys; print(os.path.realpath(sys.executable))'
        foreach ($part in 'scraper', 'decision') {
            & $pythonExe -m venv (Join-Path $CopilotHome "$part/venv")
            & (Join-Path $CopilotHome $part $venvPython) -m pip install --quiet -r (Join-Path $CopilotHome "$part/requirements.txt")
            if ($LASTEXITCODE -ne 0) { Write-Warning "Python packages of '$part' failed to install. Everything else is in place." }
        }
    } else {
        Write-Warning 'Python not found: the MCP servers work, but the scraping engine needs Python 3.10+ and the Jev browser 3.12+.'
    }
}

# Warn only: turning it on needs admin rights, and another antivirus may legitimately be in charge.
try {
    if (-not (Get-MpComputerStatus).RealTimeProtectionEnabled) {
        Write-Warning 'Windows Defender real-time protection is OFF. Unless another antivirus is active, turn it on in Windows Security.'
    }
} catch { }

Write-Host "Installation mode: $(if ($Reset) { 'reinitialized kit files' } else { 'update; personal settings and untracked files preserved' })"
Write-Host "Installed in: $CopilotHome"
Write-Host "Profile: $ProfilePath"
Write-Host "Backups (if anything changed): $backupDir"
Write-Host "Open a new PowerShell 7 terminal (pwsh), then run ./verifier.ps1 and start Copilot with: cop"
