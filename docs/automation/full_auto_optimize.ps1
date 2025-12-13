<#
.SYNOPSIS
    SMC/ICT EA Full Auto-Optimization with Git Integration
    
.DESCRIPTION
    Fully automated system that:
    1. Tests multiple timeframes (M15, M30, H1, H4)
    2. Optimizes EA parameters for each
    3. Commits results to git with win rate
    4. Uses $1000 starting capital

.EXAMPLE
    .\full_auto_optimize.ps1 -MT5Path "C:\Program Files\MetaTrader 5"
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$MT5Path = "C:\Program Files\MetaTrader 5",
    
    [Parameter(Mandatory=$false)]
    [int]$TargetWinRate = 80,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxIterationsPerTimeframe = 20,
    
    [Parameter(Mandatory=$false)]
    [string]$Symbol = "XAUUSD",
    
    [Parameter(Mandatory=$false)]
    [string]$FromDate = "2024.06.01",
    
    [Parameter(Mandatory=$false)]
    [string]$ToDate = "2024.11.01"
)

# ═══════════════════════════════════════════════════════════════════════════
# Configuration
# ═══════════════════════════════════════════════════════════════════════════
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$MQL5Root = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$TesterDir = Join-Path $MQL5Root "tester"
$ProfilesDir = Join-Path $MQL5Root "Profiles\Tester"

$Terminal = Join-Path $MT5Path "terminal64.exe"
$MetaEditor = Join-Path $MT5Path "metaeditor64.exe"

$EASource = Join-Path $MQL5Root "Experts\V2-oat.mq5"
$ConfigFile = Join-Path $ProfilesDir "backtest_config.ini"
$SetFile = Join-Path $ProfilesDir "V2-oat.set"
$ResultsDir = Join-Path $ScriptDir "results"

# Deposit = $1000
$Deposit = 1000

# Timeframes to test (AI selects best one)
$Timeframes = @("M15", "M30", "H1", "H4")

# Parameters to optimize
$OptimizableParams = @(
    @{Name="InpMinRR"; Min=1.5; Max=4.0; Step=0.5; Current=2.5},
    @{Name="InpFractalK"; Min=3; Max=7; Step=1; Current=5},
    @{Name="InpMinBreakPts"; Min=100; Max=300; Step=50; Current=150},
    @{Name="InpMinStopPts"; Min=800; Max=1200; Step=100; Current=1000},
    @{Name="InpSpreadMaxPts"; Min=300; Max=500; Step=50; Current=400}
)

# ═══════════════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════════════

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "HEADER" { "Cyan" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..." "INFO"
    
    if (-not (Test-Path $Terminal)) {
        Write-Log "MT5 Terminal not found at: $Terminal" "ERROR"
        return $false
    }
    
    if (-not (Test-Path $EASource)) {
        Write-Log "EA source not found at: $EASource" "ERROR"
        return $false
    }
    
    # Check git
    try {
        $gitVersion = git --version
        Write-Log "Git found: $gitVersion" "SUCCESS"
    } catch {
        Write-Log "Git not found. Commits will be skipped." "WARNING"
    }
    
    # Create directories
    @($ProfilesDir, $TesterDir, $ResultsDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
        }
    }
    
    Write-Log "Prerequisites OK" "SUCCESS"
    return $true
}

function Compile-EA {
    Write-Log "Compiling EA..."
    $process = Start-Process -FilePath $MetaEditor `
        -ArgumentList "/compile:`"$EASource`"" `
        -Wait -PassThru -NoNewWindow
    
    Start-Sleep -Seconds 2
    
    if (Test-Path ($EASource -replace "\.mq5$", ".ex5")) {
        Write-Log "Compile OK" "SUCCESS"
        return $true
    }
    Write-Log "Compile failed" "ERROR"
    return $false
}

function Create-ConfigFile {
    param([string]$Period)
    
    $config = @"
[Tester]
Expert=Experts\V2-oat.ex5
ExpertParameters=V2-oat.set
Symbol=$Symbol
Period=$Period
FromDate=$FromDate
ToDate=$ToDate
Model=1
Optimization=0
Deposit=$Deposit
Currency=USD
Leverage=100
Visual=0
Report=tester\backtest_report
ReplaceReport=1
ShutdownTerminal=1
"@
    $config | Out-File -FilePath $ConfigFile -Encoding ASCII -Force
}

function Create-SetFile {
    param([hashtable]$Params)
    
    $templatePath = Join-Path $ScriptDir "V2-oat.set.txt"
    
    if (Test-Path $templatePath) {
        $content = Get-Content $templatePath -Raw
        foreach ($p in $Params.GetEnumerator()) {
            $pattern = "(?m)^$($p.Key)=.*$"
            $replacement = "$($p.Key)=$($p.Value)"
            $content = $content -replace $pattern, $replacement
        }
        $content | Out-File -FilePath $SetFile -Encoding ASCII -Force
    }
}

function Run-Backtest {
    $ReportFile = Join-Path $TesterDir "backtest_report.htm"
    
    if (Test-Path $ReportFile) {
        Remove-Item $ReportFile -Force
    }
    
    $process = Start-Process -FilePath $Terminal `
        -ArgumentList "/config:`"$ConfigFile`"" `
        -PassThru
    
    $timeout = 300
    $elapsed = 0
    while (-not $process.HasExited -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 3
        $elapsed += 3
        Write-Host "." -NoNewline
    }
    Write-Host ""
    
    Start-Sleep -Seconds 2
    return (Test-Path $ReportFile)
}

function Parse-Report {
    $ReportFile = Join-Path $TesterDir "backtest_report.htm"
    
    if (-not (Test-Path $ReportFile)) {
        return $null
    }
    
    $html = Get-Content $ReportFile -Raw -Encoding UTF8
    
    $result = @{
        TotalTrades = 0
        WinTrades = 0
        WinRate = 0.0
        ProfitFactor = 0.0
        NetProfit = 0.0
        MaxDrawdown = 0.0
        MaxDrawdownPct = 0.0
    }
    
    if ($html -match 'Total Trades[^\d]*(\d+)') { $result.TotalTrades = [int]$Matches[1] }
    if ($html -match 'Profit Trades[^\d]*(\d+)') { $result.WinTrades = [int]$Matches[1] }
    if ($result.TotalTrades -gt 0) { $result.WinRate = [math]::Round(($result.WinTrades / $result.TotalTrades) * 100, 2) }
    if ($html -match 'Profit Factor[^\d.]*(\d+\.?\d*)') { $result.ProfitFactor = [double]$Matches[1] }
    if ($html -match 'Total Net Profit[^\d.-]*(-?\d+\.?\d*)') { $result.NetProfit = [double]$Matches[1] }
    if ($html -match 'Maximal Drawdown[^\d.]*(\d+\.?\d*)[^\(]*\((\d+\.?\d*)') { 
        $result.MaxDrawdown = [double]$Matches[1]
        $result.MaxDrawdownPct = [double]$Matches[2]
    }
    
    return $result
}

function Git-Commit {
    param([string]$Message)
    
    try {
        Set-Location $MQL5Root
        git add -A
        git commit -m "$Message"
        Write-Log "Git commit: $Message" "SUCCESS"
    } catch {
        Write-Log "Git commit failed: $_" "WARNING"
    }
}

function Save-Results {
    param(
        [string]$Timeframe,
        [hashtable]$Params,
        [hashtable]$Metrics,
        [int]$Iteration
    )
    
    $resultFile = Join-Path $ResultsDir "$Timeframe`_results.json"
    
    $entry = @{
        Iteration = $Iteration
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Timeframe = $Timeframe
        Deposit = $Deposit
        Parameters = $Params
        Metrics = $Metrics
    }
    
    $results = @()
    if (Test-Path $resultFile) {
        try { $results = Get-Content $resultFile | ConvertFrom-Json } catch {}
    }
    
    $results += $entry
    $results | ConvertTo-Json -Depth 10 | Out-File $resultFile -Encoding UTF8
}

# ═══════════════════════════════════════════════════════════════════════════
# Main Execution
# ═══════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SMC/ICT EA - FULL AUTO-OPTIMIZATION SYSTEM" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Deposit: `$$Deposit | Target Win Rate: $TargetWinRate%" -ForegroundColor Cyan
Write-Host "  Timeframes to test: $($Timeframes -join ', ')" -ForegroundColor Cyan
Write-Host "  Period: $FromDate to $ToDate" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisites check failed" "ERROR"
    exit 1
}

if (-not (Compile-EA)) {
    Write-Log "Compile failed" "ERROR"
    exit 1
}

# Track best results across all timeframes
$globalBest = @{
    Timeframe = ""
    WinRate = 0.0
    ProfitFactor = 0.0
    NetProfit = 0.0
    Params = @{}
    Metrics = @{}
}

# Test each timeframe
foreach ($tf in $Timeframes) {
    Write-Host ""
    Write-Log "════════════════════════════════════════════════════════════════" "HEADER"
    Write-Log "TESTING TIMEFRAME: $tf" "HEADER"
    Write-Log "════════════════════════════════════════════════════════════════" "HEADER"
    
    $bestForTF = @{
        WinRate = 0.0
        Params = @{}
        Metrics = @{}
    }
    
    # Reset params for each timeframe
    $params = @{}
    foreach ($p in $OptimizableParams) {
        $params[$p.Name] = $p.Current
        $p.Current = $p.Min  # Reset to min for fresh search
    }
    
    for ($iter = 1; $iter -le $MaxIterationsPerTimeframe; $iter++) {
        Write-Log "[$tf] Iteration $iter/$MaxIterationsPerTimeframe"
        
        # Vary parameters
        $paramIndex = ($iter - 1) % $OptimizableParams.Count
        $stepMult = [math]::Floor(($iter - 1) / $OptimizableParams.Count)
        
        foreach ($p in $OptimizableParams) {
            if ($OptimizableParams.IndexOf($p) -eq $paramIndex) {
                $newVal = $p.Min + ($p.Step * $stepMult)
                if ($newVal -gt $p.Max) { $newVal = $p.Max }
                $params[$p.Name] = $newVal
            }
        }
        
        Write-Log "  Params: InpMinRR=$($params['InpMinRR']), InpFractalK=$($params['InpFractalK'])"
        
        Create-ConfigFile -Period $tf
        Create-SetFile -Params $params
        
        if (-not (Run-Backtest)) {
            Write-Log "  Backtest failed, skipping" "WARNING"
            continue
        }
        
        $metrics = Parse-Report
        if ($null -eq $metrics) {
            Write-Log "  Parse failed, skipping" "WARNING"
            continue
        }
        
        Write-Log "  Result: Trades=$($metrics.TotalTrades), WinRate=$($metrics.WinRate)%, PF=$($metrics.ProfitFactor), Profit=`$$($metrics.NetProfit)"
        
        Save-Results -Timeframe $tf -Params $params -Metrics $metrics -Iteration $iter
        
        # Track best for this timeframe
        if ($metrics.WinRate -gt $bestForTF.WinRate) {
            $bestForTF.WinRate = $metrics.WinRate
            $bestForTF.Params = $params.Clone()
            $bestForTF.Metrics = $metrics
            Write-Log "  NEW BEST for $tf`: $($metrics.WinRate)%" "SUCCESS"
        }
        
        # Check if target reached
        if ($metrics.WinRate -ge $TargetWinRate) {
            Write-Log "TARGET REACHED for $tf`: $($metrics.WinRate)% >= $TargetWinRate%" "SUCCESS"
            break
        }
    }
    
    # Commit results for this timeframe
    $commitMsg = "optimization($tf): WinRate=$($bestForTF.WinRate)% PF=$($bestForTF.Metrics.ProfitFactor) Profit=`$$($bestForTF.Metrics.NetProfit) Deposit=`$$Deposit"
    Git-Commit -Message $commitMsg
    
    # Track global best
    if ($bestForTF.WinRate -gt $globalBest.WinRate) {
        $globalBest.Timeframe = $tf
        $globalBest.WinRate = $bestForTF.WinRate
        $globalBest.ProfitFactor = $bestForTF.Metrics.ProfitFactor
        $globalBest.NetProfit = $bestForTF.Metrics.NetProfit
        $globalBest.Params = $bestForTF.Params
        $globalBest.Metrics = $bestForTF.Metrics
    }
}

# Final summary
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  OPTIMIZATION COMPLETE" -ForegroundColor Green
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
Write-Host "  BEST TIMEFRAME: $($globalBest.Timeframe)" -ForegroundColor Yellow
Write-Host "  Win Rate: $($globalBest.WinRate)%" -ForegroundColor Yellow
Write-Host "  Profit Factor: $($globalBest.ProfitFactor)" -ForegroundColor Yellow
Write-Host "  Net Profit: `$$($globalBest.NetProfit)" -ForegroundColor Yellow
Write-Host ""
Write-Host "  Best Parameters:" -ForegroundColor Cyan
foreach ($p in $globalBest.Params.GetEnumerator()) {
    Write-Host "    $($p.Key) = $($p.Value)" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════════════" -ForegroundColor Green

# Save global best
$globalBest | ConvertTo-Json -Depth 10 | Out-File (Join-Path $ResultsDir "global_best.json") -Encoding UTF8

# Final git commit
$finalMsg = "optimization(BEST): TF=$($globalBest.Timeframe) WinRate=$($globalBest.WinRate)% PF=$($globalBest.ProfitFactor) Profit=`$$($globalBest.NetProfit)"
Git-Commit -Message $finalMsg

Write-Log "All results saved to: $ResultsDir" "SUCCESS"
Write-Log "Done!" "SUCCESS"
