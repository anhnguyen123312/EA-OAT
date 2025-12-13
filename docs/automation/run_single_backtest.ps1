<#
.SYNOPSIS
    Quick single backtest run for testing

.DESCRIPTION
    Runs one backtest with current parameters and shows results.
    Use this to verify the setup works before running full optimization.

.EXAMPLE
    .\run_single_backtest.ps1 -MT5Path "C:\Program Files\MetaTrader 5"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$MT5Path = "C:\Program Files\MetaTrader 5"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MQL5Root = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$TesterDir = Join-Path $MQL5Root "tester"
$ProfilesDir = Join-Path $MQL5Root "Profiles\Tester"

$Terminal = Join-Path $MT5Path "terminal64.exe"
$ConfigFile = Join-Path $ProfilesDir "backtest_config.ini"
$ReportFile = Join-Path $TesterDir "backtest_report.htm"

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Quick Single Backtest" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check terminal exists
if (-not (Test-Path $Terminal)) {
    Write-Host "[ERROR] MT5 Terminal not found at: $Terminal" -ForegroundColor Red
    Write-Host "Please specify correct path with -MT5Path parameter" -ForegroundColor Red
    exit 1
}

# Create minimal config
$config = @"
[Tester]
Expert=Experts\V2-oat.ex5
Symbol=XAUUSD
Period=M30
FromDate=2024.06.01
ToDate=2024.09.01
Model=1
Optimization=0
Deposit=10000
Currency=USD
Visual=0
Report=tester\backtest_report
ReplaceReport=1
ShutdownTerminal=1
"@

# Ensure directory exists
if (-not (Test-Path $ProfilesDir)) {
    New-Item -ItemType Directory -Path $ProfilesDir -Force | Out-Null
}

$config | Out-File -FilePath $ConfigFile -Encoding ASCII -Force

Write-Host "Config created: $ConfigFile" -ForegroundColor Green
Write-Host "Starting MT5 backtest..." -ForegroundColor Yellow
Write-Host "This may take several minutes. MT5 will close automatically when done." -ForegroundColor Yellow
Write-Host ""

# Delete old report
if (Test-Path $ReportFile) {
    Remove-Item $ReportFile -Force
}

# Run
$process = Start-Process -FilePath $Terminal -ArgumentList "/config:`"$ConfigFile`"" -PassThru

# Wait
$timeout = 300
$elapsed = 0
while (-not $process.HasExited -and $elapsed -lt $timeout) {
    Start-Sleep -Seconds 5
    $elapsed += 5
    Write-Host "." -NoNewline
}
Write-Host ""

# Check result
Start-Sleep -Seconds 2
if (Test-Path $ReportFile) {
    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host "  BACKTEST COMPLETED" -ForegroundColor Green
    Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host ""
    Write-Host "Report saved to: $ReportFile" -ForegroundColor Green
    Write-Host ""
    
    # Quick parse
    $html = Get-Content $ReportFile -Raw -Encoding UTF8
    
    if ($html -match 'Total Net Profit[^\d.-]*(-?\d+\.?\d*)') {
        Write-Host "Net Profit: `$$($Matches[1])" -ForegroundColor Cyan
    }
    if ($html -match 'Total Trades[^\d]*(\d+)') {
        Write-Host "Total Trades: $($Matches[1])" -ForegroundColor Cyan
    }
    if ($html -match 'Profit Factor[^\d.]*(\d+\.?\d*)') {
        Write-Host "Profit Factor: $($Matches[1])" -ForegroundColor Cyan
    }
    if ($html -match 'Maximal Drawdown[^\d.]*(\d+\.?\d*)') {
        Write-Host "Max Drawdown: $($Matches[1])%" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "Open the HTML report in browser for full details." -ForegroundColor Yellow
    
} else {
    Write-Host ""
    Write-Host "[ERROR] Backtest failed or timed out." -ForegroundColor Red
    Write-Host "Report not found at: $ReportFile" -ForegroundColor Red
}
