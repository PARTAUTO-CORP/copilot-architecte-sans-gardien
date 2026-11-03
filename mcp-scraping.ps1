#requires -Version 7.3
<#
  Registers the scraping and decision MCP servers in the Copilot user configuration. Re-runnable.

  Servers without a key are always registered. For the others, type the key when asked,
  or press Enter to skip. Keys are typed here, never given to an AI in a chat.
  Copilot's documented format stores them in clear text in mcp-config.json.
#>
param(
    [string]$CopilotHome = $(if ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' }),
    [switch]$NoPrompt,
    [switch]$PromptWindow
)
$ErrorActionPreference = 'Stop'

if (-not $NoPrompt -and -not $PromptWindow) {
    $pwsh = Get-Command pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) { throw 'PowerShell 7 is required for guided setup. Run installer.cmd to install it, then retry.' }

    Write-Host ''
    Write-Host 'A separate PowerShell 7 window will open for the account and API-key setup.' -ForegroundColor Cyan
    Write-Host 'Follow its prompts; API keys are entered in hidden fields. When finished, that window closes and this installation resumes.'
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', "`"$PSCommandPath`"",
        '-CopilotHome', "`"$CopilotHome`"",
        '-PromptWindow'
    )
    $child = Start-Process -FilePath $pwsh.Source -ArgumentList $arguments -WorkingDirectory $PSScriptRoot -WindowStyle Normal -PassThru -Wait
    if ($child.ExitCode -ne 0) { throw "Guided PowerShell 7 setup failed (exit code $($child.ExitCode))." }
    return
}

$decisionEnv = Join-Path $CopilotHome 'decision\.env'
if ($PromptWindow) {
    $Host.UI.RawUI.WindowTitle = 'Copilot Architecte - Configuration guidee'
    Write-Host ''
    Write-Host 'COPILOT ARCHITECTE - Guided account setup' -ForegroundColor Cyan
    Write-Host "Working directory: $PSScriptRoot"
    Write-Host 'Do not type commands. Follow each prompt and paste keys only into the hidden key fields; press Enter to skip an optional provider.'
    Write-Host 'When setup finishes, this PowerShell 7 window will close automatically and the original installation will continue.'
}

$configPath = Join-Path $CopilotHome 'mcp-config.json'
# Parse before any write: a corrupt file must stop the script, not be overwritten.
$config = if (Test-Path $configPath) { Get-Content $configPath -Raw | ConvertFrom-Json -AsHashtable }
if ($null -eq $config) { $config = [ordered]@{} }
if ($config['mcpServers'] -isnot [System.Collections.IDictionary]) { $config['mcpServers'] = [ordered]@{} }
$servers = $config['mcpServers']

function Set-Http([string]$Name, [string]$Url, [hashtable]$Headers = @{}) {
    $entry = [ordered]@{ type = 'http'; url = $Url; tools = @('*') }
    if ($Headers.Count) { $entry['headers'] = $Headers }
    $servers[$Name] = $entry
}

# No key needed here: sign-in through /mcp in Copilot, or usable with free limits.
Set-Http 'firecrawl' 'https://mcp.firecrawl.dev/v2/mcp-oauth'
Set-Http 'tinyfish' 'https://agent.tinyfish.ai/mcp'
Set-Http 'apify' 'https://mcp.apify.com'
Set-Http 'jina' 'https://mcp.jina.ai/v1'
if (-not $servers.Contains('olostep')) { Set-Http 'olostep' 'https://mcp.olostep.com/mcp' }
$servers['jev'] = [ordered]@{
    type    = 'local'
    command = (Join-Path $CopilotHome 'decision\venv\Scripts\python.exe')
    args    = @((Join-Path $CopilotHome 'decision\jev_mcp.py'))  # direct to TypeSafe, key in decision\.env
    env     = @{}
    tools   = @('*')
}
$servers['playwright'] = [ordered]@{
    type    = 'local'
    command = 'npx'
    args    = @('-y', '@playwright/mcp@0.0.84', '--headless', '--isolated')  # pinned: a new release must not run unreviewed
    env     = @{}
    tools   = @('*')
}
$servers['sequential-thinking'] = [ordered]@{
    type    = 'local'
    command = 'npx'
    args    = @('-y', '@modelcontextprotocol/server-sequential-thinking@2.0.0')  # free fallback for decisions, needs Node 24
    env     = @{}
    tools   = @('*')
}

# Key required: nothing is registered without a key, a server that cannot sign in only wastes context.
$keyed = @(
    @{ Name = 'olostep';    Label = 'Olostep (optional, sign-in also works)'; Where = 'olostep.com/dashboard/api-keys'; Add = { param($k) Set-Http 'olostep' 'https://mcp.olostep.com/mcp' @{ Authorization = "Bearer $k" } } }
    @{ Name = 'crawlbase';   Label = 'Crawlbase'; Where = 'crawlbase.com dashboard'; Add = { param($k) Set-Http 'crawlbase' 'https://mcp.crawlbase.com/mcp' @{ Authorization = "Bearer $k" } } }
    @{ Name = 'decodo';      Label = 'Decodo'; Where = 'decodo.com dashboard'; Add = { param($k) Set-Http 'decodo' 'https://mcp.decodo.com/mcp' @{ Authorization = "Bearer $k" } } }
    @{ Name = 'oxylabs';     Label = 'Oxylabs'; Where = 'oxylabs.io dashboard'; Add = { param($k) Set-Http 'oxylabs' 'https://mcp.oxylabs.io/mcp' @{ Authorization = "Bearer $k" } } }
    @{ Name = 'scrapingbee'; Label = 'ScrapingBee'; Where = 'scrapingbee.com dashboard'; Add = { param($k) Set-Http 'scrapingbee' "https://mcp.scrapingbee.com/mcp?api_key=$([uri]::EscapeDataString($k))" } }
    @{ Name = 'brightdata';  Label = 'Bright Data'; Where = 'brightdata.com dashboard'; Add = { param($k) Set-Http 'brightdata' "https://mcp.brightdata.com/mcp?token=$([uri]::EscapeDataString($k))" } }
)
if (-not $NoPrompt) {
    foreach ($s in $keyed) {
        $key = Read-Host -MaskInput "$($s.Label) key ($($s.Where)) - Enter to skip"
        if ($key) { & $s.Add $key.Trim() }
    }
    # Jev decisions and the Jev browser share the TypeSafe key. Delete decision\.env to type it again.
    if (-not (Test-Path $decisionEnv)) {
        $typesafeUrl = 'https://console.typesafe.ai/keys'
        Write-Host ''
        Write-Host 'ACTION REQUIRED - Configure TypeSafe for Jev' -ForegroundColor Yellow
        Write-Host 'A browser window will open to TypeSafe. Sign in or create an account, then create/copy your API key.'
        Write-Host 'Return here and paste the key at the hidden prompt. The key is saved locally, never displayed.'
        try {
            Start-Process $typesafeUrl -ErrorAction Stop
        } catch {
            Write-Warning "Could not open the TypeSafe page automatically. Open this URL yourself: $typesafeUrl"
        }
        $typesafe = Read-Host -MaskInput 'TypeSafe API key (press Enter to skip)'
        if ($typesafe) {
            $textKey = Read-Host -MaskInput 'OpenRouter key, only for typing text in the Jev browser (openrouter.ai/keys) - Enter to skip'
            New-Item -ItemType Directory -Force (Split-Path $decisionEnv) | Out-Null
            Set-Content -LiteralPath $decisionEnv -Value "TYPESAFE_API_KEY=$($typesafe.Trim())`nTEXT_MODEL_API_KEY=$($textKey.Trim())"
        }
    }
}

New-Item -ItemType Directory -Force $CopilotHome | Out-Null
if (Test-Path $configPath) {
    $backup = Join-Path $CopilotHome ("backups\mcp-config-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    New-Item -ItemType Directory -Force (Split-Path $backup) | Out-Null
    Copy-Item -LiteralPath $configPath -Destination $backup
}
$json = $config | ConvertTo-Json -Depth 16
$null = $json | ConvertFrom-Json
Set-Content -LiteralPath $configPath -Value $json

Write-Host ''
Write-Host 'STEP 1 - Open Copilot and go to /mcp' -ForegroundColor Cyan
Write-Host '  This is where you confirm the MCP servers are loaded and where the sign-in prompts appear.'
Write-Host '  If Firecrawl, TinyFish, Olostep or Apify ask for a login, accept the prompt and continue.'
Write-Host ''
Write-Host 'STEP 2 - Add any API keys you want to enable' -ForegroundColor Cyan
Write-Host '  The script already pre-registered the free/public servers. Extra keys are only needed for paid or rate-limited providers.'
Write-Host '  Paste a key only when prompted; press Enter to skip a provider.'
Write-Host ''
Write-Host 'STEP 3 - TypeSafe and OpenRouter (Jev browser)' -ForegroundColor Cyan
Write-Host '  For the Jev browser / decision stack, you can set the key now or skip it and use the rubber duck / Playwright fallback.'
Write-Host "  Keys go into: $(Join-Path $CopilotHome 'decision\.env')"
Write-Host ''
Write-Host "MCP servers registered: $($servers.Keys -join ', ')"
Write-Host 'Next action: open /mcp in Copilot, then run /env and /agents to confirm all tools are visible.'
