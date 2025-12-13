<#
.SYNOPSIS
    Setup helper - copies config files to correct locations

.DESCRIPTION
    Copies the template files to the MT5 Profiles/Tester directory
    so they can be used by Strategy Tester.

.EXAMPLE
    .\setup.ps1
#>

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MQL5Root = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ProfilesDir = Join-Path $MQL5Root "Profiles\Tester"
$TesterDir = Join-Path $MQL5Root "tester"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SMC/ICT EA - Setup Helper" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Create directories
if (-not (Test-Path $ProfilesDir)) {
    New-Item -ItemType Directory -Path $ProfilesDir -Force | Out-Null
    Write-Host "[OK] Created: $ProfilesDir" -ForegroundColor Green
}

if (-not (Test-Path $TesterDir)) {
    New-Item -ItemType Directory -Path $TesterDir -Force | Out-Null
    Write-Host "[OK] Created: $TesterDir" -ForegroundColor Green
}

# Copy config file
$srcConfig = Join-Path $ScriptDir "backtest_config.txt"
$dstConfig = Join-Path $ProfilesDir "backtest_config.ini"
if (Test-Path $srcConfig) {
    Copy-Item $srcConfig $dstConfig -Force
    Write-Host "[OK] Copied backtest_config.ini" -ForegroundColor Green
} else {
    Write-Host "[SKIP] backtest_config.txt not found" -ForegroundColor Yellow
}

# Copy set file
$srcSet = Join-Path $ScriptDir "V2-oat.set.txt"
$dstSet = Join-Path $ProfilesDir "V2-oat.set"
if (Test-Path $srcSet) {
    Copy-Item $srcSet $dstSet -Force
    Write-Host "[OK] Copied V2-oat.set" -ForegroundColor Green
} else {
    Write-Host "[SKIP] V2-oat.set.txt not found" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: .\run_single_backtest.ps1 -MT5Path 'C:\Program Files\MetaTrader 5'" -ForegroundColor White
Write-Host "2. If OK, run: .\optimize_ea.ps1 -MT5Path 'C:\Program Files\MetaTrader 5'" -ForegroundColor White
Write-Host ""
