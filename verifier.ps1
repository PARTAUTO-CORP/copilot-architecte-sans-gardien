#requires -Version 7.3
<#
  Read-only check of a Copilot Architecte install. Standalone.
  The expected list comes from the kit's payload folder, so it cannot drift.
  Reads only the settings it checks and never prints a configuration file.
  Exit code: 0 if everything is OK, 1 otherwise.
#>
param(
    [string]$CopilotHome = $(if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' }),
    [string]$ProfilePath = $PROFILE.CurrentUserAllHosts,
    [switch]$SkipUserEnv
)
$payload = Join-Path $PSScriptRoot 'payload'
$script:failed = 0

function Check([string]$Name, [bool]$Ok, [string]$Detail = '') {
    if (-not $Ok) { $script:failed++ }
    Write-Host ("[{0}] {1}{2}" -f $(if ($Ok) { 'OK' } else { 'KO' }), $Name, $(if ($Detail) { " - $Detail" } else { '' }))
}

function Get-Frontmatter([string]$Path) {
    $m = [regex]::Match((Get-Content $Path -Raw), '(?s)\A---\r?\n(.*?)\r?\n---')
    if (-not $m.Success) { return @{} }
    $h = @{}
    foreach ($line in $m.Groups[1].Value -split '\r?\n') {
        if ($line -match '^([\w-]+):\s*(.*)$') { $h[$Matches[1]] = $Matches[2] }
    }
    $h
}

function Test-SameFiles([string]$Kind) {
    # Python leaves __pycache__ when the tests run; install.ps1 does not copy it.
    $files = Get-ChildItem (Join-Path $payload $Kind) -Recurse -File | Where-Object FullName -NotMatch '__pycache__'
    $bad = @($files | Where-Object {
            $t = Join-Path $CopilotHome ([IO.Path]::GetRelativePath($payload, $_.FullName))
            -not (Test-Path $t) -or (Get-FileHash $t).Hash -ne (Get-FileHash $_.FullName).Hash
        } | ForEach-Object Name)
    Check "$Kind installed and identical to the kit ($($files.Count) files)" ($bad.Count -eq 0) ($bad -join ', ')
}

# Copilot CLI
$cli = Get-Command copilot -ErrorAction SilentlyContinue
Check 'copilot command found' ([bool]$cli) $(if ($cli) { (copilot --version 2>&1 | Select-Object -First 1) })

# Agents and skills
Test-SameFiles 'agents'
Test-SameFiles 'skills'
Test-SameFiles 'scraper'
Test-SameFiles 'decision'

$agents = Get-ChildItem (Join-Path $payload 'agents') -File
$skillNames = (Get-ChildItem (Join-Path $payload 'skills') -Directory).Name

$badAgents = @($agents | Where-Object {
        $f = Get-Frontmatter $_.FullName
        $f['name'] -ne ($_.Name -replace '\.agent\.md$') -or -not $f['description'] -or $f['tools'] -ne '["*"]'
    } | ForEach-Object Name)
Check 'agent frontmatter: name, description, all tools' ($badAgents.Count -eq 0) ($badAgents -join ', ')

$badSkills = @($skillNames | Where-Object {
        $f = Get-Frontmatter (Join-Path $payload "skills/$_/SKILL.md")
        $f['name'] -ne $_ -or -not $f['description']
    })
Check 'skill frontmatter: name matches folder, description' ($badSkills.Count -eq 0) ($badSkills -join ', ')

# Agent -> skills matrix, and broken references
$broken = @()
$matrix = foreach ($a in $agents) {
    $line = Select-String -Path $a.FullName -Pattern '^\*\*Skills :\*\* (.+)$' | Select-Object -First 1
    $used = if ($line) { $line.Matches[0].Groups[1].Value -split ',\s*' } else { @() }
    $broken += $used | Where-Object { $_ -notin $skillNames }
    if (-not $used) { $broken += "$($a.Name) has no skills line" }
    [pscustomobject]@{ Agent = $a.Name -replace '\.agent\.md$'; Skills = $used -join ', ' }
}
Check 'skills referenced by agents all exist' ($broken.Count -eq 0) ($broken -join ', ')
$usedSkills = $matrix.Skills -split ',\s*' | Select-Object -Unique
$orphans = @($skillNames | Where-Object { $_ -notin $usedSkills })
Check 'every skill is used by an agent' ($orphans.Count -eq 0) ($orphans -join ', ')

# The kit must stay neutral
$personal = @(Get-ChildItem $payload -Recurse -File | Where-Object FullName -NotMatch '__pycache__' | Select-String -Pattern 'steev|cedri|cédric|C:\\Users' | ForEach-Object Filename | Select-Object -Unique)
Check 'no personal name or path in the kit' ($personal.Count -eq 0) ($personal -join ', ')

# Global instructions
$instructions = Join-Path $CopilotHome 'copilot-instructions.md'
Check 'global instructions installed' ((Test-Path $instructions) -and (Select-String -Path $instructions -Pattern 'copilot-architecte' -Quiet))

# Settings
$settingsPath = Join-Path $CopilotHome 'settings.json'
$s = $null
try { $s = Get-Content $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable } catch { }
Check 'settings.json is valid JSON' ($null -ne $s)
if ($s) {
    Check 'defaultPermissionMode = allow-all' ($s['defaultPermissionMode'] -eq 'allow-all')
    Check 'defaultMode = interactive' ($s['defaultMode'] -eq 'interactive')
    Check 'experimental on' ($s['experimental'] -eq $true)
    Check 'sandbox off' ($s['sandbox']['enabled'] -eq $false)
    Check 'no denied URL' (@($s['deniedUrls']).Count -eq 0)
    Check 'bypass not disabled in user settings' (-not ($s['permissions'] -and $s['permissions']['disableBypassPermissionsMode']))
    Check 'rubber duck consulted automatically' ($s['subagents'] -and $s['subagents']['agents'] -and $s['subagents']['agents']['rubber-duck'] -and $s['subagents']['agents']['rubber-duck']['autoInvoke'] -eq $true)
    $statusLine = $s['statusLine']
    $statusLineOk = $statusLine -and $statusLine['type'] -eq 'command' -and $statusLine['command'] -match 'statusline\.ps1' -and $statusLine['refreshInterval'] -gt 0
    Check 'statusLine configured for Copilot context/session display' $statusLineOk
    $statusScript = Join-Path $CopilotHome 'statusline.ps1'
    Check 'statusLine script exists and is executable' ((Test-Path $statusScript) -and (Get-Item $statusScript).Length -gt 0)
}

# Launchers
$hasLaunchers = (Test-Path $ProfilePath) -and (Select-String -Path $ProfilePath -Pattern 'function cop .*--yolo' -Quiet) -and (Select-String -Path $ProfilePath -Pattern 'function copr .*--yolo' -Quiet) -and (Select-String -Path $ProfilePath -Pattern 'function cop-pentest' -Quiet)
Check 'cop, copr and cop-pentest launchers in the profile' $hasLaunchers
Check 'cop can ask the user' ($hasLaunchers -and -not (Select-String -Path $ProfilePath -Pattern 'function cop .*--no-ask-user' -Quiet))

# An earlier install's hook would keep refusing commands.
Check 'no Gardien left from an earlier install' (-not (Test-Path (Join-Path $CopilotHome 'hooks/architecte-gardien.json')) -and -not (Test-Path (Join-Path $CopilotHome 'gardien/garde.ps1')))

# MCP servers: only presence is checked here, /mcp in Copilot shows sign-in and tools
$mcp = $null
try { $mcp = Get-Content (Join-Path $CopilotHome 'mcp-config.json') -Raw -ErrorAction Stop | ConvertFrom-Json -AsHashtable } catch { }
$missing = @('firecrawl', 'tinyfish', 'olostep', 'apify', 'jina', 'playwright', 'jev', 'sequential-thinking') | Where-Object { -not ($mcp -and $mcp['mcpServers'] -and $mcp['mcpServers'].Contains($_)) }
Check 'scraping and decision MCP servers registered' (@($missing).Count -eq 0) (@($missing) -join ', ')
if ($mcp -and $mcp['mcpServers']) { Write-Host "     registered: $($mcp['mcpServers'].Keys -join ', ')" }

# Scraping engine
$venvRelative = if ($IsWindows) { 'venv/Scripts/python.exe' } else { 'venv/bin/python' }
$venvPython = Join-Path $CopilotHome 'scraper' $venvRelative
$engineOk = (Test-Path $venvPython) -and ((& $venvPython -c 'import httpx, selectolax.lexbor, pyarrow.parquet; print(1)' 2>$null) -eq '1')
Check 'scraping engine: Python environment ready' $engineOk $(if (-not $engineOk) { 'Python packages missing, rerun install.ps1' })

# Jev browser: find_spec, because importing browser-harness would start its setup
$decisionPython = Join-Path $CopilotHome 'decision' $venvRelative
$jevOk = (Test-Path $decisionPython) -and ((& $decisionPython -c "import importlib.util as u; print(all(u.find_spec(m) for m in ('jev_ultrafast', 'browser_harness')))" 2>$null) -eq 'True')
Check 'Jev browser: Python environment ready' $jevOk $(if (-not $jevOk) { 'Python packages missing, rerun install.ps1' })
$jevTools = if ($jevOk) { '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | & $decisionPython (Join-Path $CopilotHome 'decision/jev_mcp.py') 2>$null }
Check 'Jev server answers and offers run_decision' ([string]$jevTools -match 'run_decision')
if (-not (Test-Path (Join-Path $CopilotHome 'decision/.env'))) { Write-Host '[!!] No TypeSafe key yet (./mcp-scraping.ps1): agents skip Jev and use the rubber duck and playwright' }

# Environment: permanent "true" would trust any folder
if (-not $SkipUserEnv) {
    Check 'COPILOT_ALLOW_ALL not permanent' ([string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable('COPILOT_ALLOW_ALL', 'User')))
}

# Information, not a failure: another antivirus may be in charge
try {
    if (-not (Get-MpComputerStatus).RealTimeProtectionEnabled) { Write-Host '[!!] Windows Defender real-time protection is OFF: check that another antivirus is active' }
} catch { }

# Information, not a failure: the free MCP servers and the local engine work without a browser
if ($IsLinux) {
    if (-not (Test-Path '/opt/google/chrome/chrome')) { Write-Host '[!!] Google Chrome missing: the playwright MCP server and the Jev browser cannot open pages (bash installer.sh as root installs it)' }
    if ((id -u) -eq '0') { Write-Host '[!!] Installed for root: the Jev browser cannot start Chrome as root, a dedicated user is safer' }
}

Write-Host "`nAgent -> skills matrix:"
$matrix | Format-Table -AutoSize | Out-String -Width 160 | Write-Host

Write-Host "Not covered here: run /env and /agents in Copilot to confirm runtime loading, then the smoke test in the kit."
if ($script:failed) { Write-Host "RESULT: $($script:failed) check(s) KO"; exit 1 }
Write-Host 'RESULT: all checks OK'
