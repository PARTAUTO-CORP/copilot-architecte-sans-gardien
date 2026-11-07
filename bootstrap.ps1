# Installs what is missing (PowerShell 7, Python, Node, Copilot CLI), then the kit, then checks it.
# Runs under Windows PowerShell 5.1: keep this file ASCII and free of PowerShell 7 syntax.
# Exit code: 0 everything OK, 1 a check failed or a prerequisite could not be installed.
param(
    [string]$CopilotHome,
    [string]$ProfilePath,
    [string]$Effort,
    [string]$Model,
    [switch]$NoPrompt,
    [switch]$SkipUserEnv,
    [switch]$SkipScraperDeps,
    [switch]$Reset
)
$ErrorActionPreference = 'Stop'

function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Get-ToolVersion([string]$Command, [string]$Argument) {
    # The Windows Store stub for python fails or prints nothing: both mean "missing".
    try {
        $text = (& $Command $Argument 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) { return $null }
        $found = [regex]::Match($text, '(\d+)\.(\d+)')
        if ($found.Success) { return [version]$found.Value }
    } catch { }
    return $null
}

function Install-WithWinget([string]$Name, [string]$Id) {
    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        throw "$Name is missing and winget is not available. Install $Name by hand, then run this again."
    }
    Write-Host "Installing $Name..."
    & winget install --id $Id --exact --silent --accept-package-agreements --accept-source-agreements | Out-Host
    Update-SessionPath
}

function Confirm-Tool([string]$Name, [string]$Command, [string]$Argument, [version]$Minimum, [string]$WingetId) {
    $version = Get-ToolVersion $Command $Argument
    if ($version -and $version -ge $Minimum) { Write-Host "[OK] $Name $version"; return }
    Install-WithWinget $Name $WingetId
    $version = Get-ToolVersion $Command $Argument
    if (-not $version -or $version -lt $Minimum) { throw "$Name $Minimum or newer is still missing. Install it by hand, then run this again." }
    Write-Host "[OK] $Name $version"
}

# On Linux, installer.sh has already installed the prerequisites. $IsLinux does not exist in 5.1, so it is false there.
if (-not $IsLinux) { try {
    # A ZIP downloaded from GitHub marks every file as coming from the internet, and the launchers would then refuse to run.
    Get-ChildItem $PSScriptRoot -Recurse -File | Unblock-File

    Confirm-Tool 'PowerShell 7' 'pwsh' '--version' ([version]'7.3') 'Microsoft.PowerShell'
    Confirm-Tool 'Python' 'python' '--version' ([version]'3.12') 'Python.Python.3.12'
    Confirm-Tool 'Node.js' 'node' '--version' ([version]'24.0') 'OpenJS.NodeJS.LTS'

    if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing GitHub Copilot CLI...'
        & npm.cmd install -g '@github/copilot' | Out-Host
        Update-SessionPath
        $npmBin = Join-Path $env:APPDATA 'npm'
        if ($env:Path -notlike "*$npmBin*") { $env:Path += ";$npmBin" }
        if (-not (Get-Command copilot -ErrorAction SilentlyContinue)) { throw 'GitHub Copilot CLI could not be installed: run npm install -g @github/copilot' }
    }
    Write-Host '[OK] GitHub Copilot CLI'
} catch {
    Write-Host "[KO] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} }

$common = @()
if ($CopilotHome) { $common += '-CopilotHome', $CopilotHome }
if ($ProfilePath) { $common += '-ProfilePath', $ProfilePath }
if ($SkipUserEnv) { $common += '-SkipUserEnv' }

$installArgs = @($common)
if ($Effort) { $installArgs += '-Effort', $Effort }
if ($Model) { $installArgs += '-Model', $Model }
if ($NoPrompt) { $installArgs += '-NoPrompt' }
if ($SkipScraperDeps) { $installArgs += '-SkipScraperDeps' }
if ($Reset) { $installArgs += '-Reset' }

& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install.ps1') @installArgs
if ($LASTEXITCODE -ne 0) { Write-Host '[KO] install.ps1 failed: see the message above.' -ForegroundColor Red; exit 1 }

& pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'verifier.ps1') @common
$checks = $LASTEXITCODE

# Only the list of accounts is read here, never a token.
$home2 = if ($CopilotHome) { $CopilotHome } elseif ($env:COPILOT_HOME) { $env:COPILOT_HOME } else { Join-Path $HOME '.copilot' }
$loggedIn = $false
try { $loggedIn = @((Get-Content (Join-Path $home2 'config.json') -Raw | ConvertFrom-Json).loggedInUsers).Count -gt 0 } catch { }
if (-not $loggedIn) {
    if ($NoPrompt) { Write-Host '[!!] Copilot is not signed in yet. Run: copilot login' }
    else { & copilot login }
}

if ($checks -eq 0) { Write-Host 'Done. Open a new PowerShell 7 terminal and type: cop' -ForegroundColor Green }
exit $checks
