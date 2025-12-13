<#
.SYNOPSIS
    SMC/ICT EA Auto-Optimization Script
    Tự động backtest và tối ưu hóa EA cho đến khi đạt target win rate

.DESCRIPTION
    Script này sẽ:
    1. Compile EA
    2. Chạy backtest qua MT5 CLI
    3. Parse kết quả từ HTML report
    4. Điều chỉnh parameters
    5. Lặp lại cho đến khi đạt target win rate

.PARAMETER MT5Path
    Đường dẫn đến thư mục MT5 (chứa terminal64.exe)

.PARAMETER TargetWinRate
    Target win rate cần đạt (default: 80%)

.PARAMETER MaxIterations
    Số lần lặp tối đa (default: 50)

.EXAMPLE
    .\optimize_ea.ps1 -MT5Path "C:\Program Files\MetaTrader 5" -TargetWinRate 80
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$MT5Path = "C:\Program Files\MetaTrader 5",
    
    [Parameter(Mandatory=$false)]
    [int]$TargetWinRate = 80,
    
    [Parameter(Mandatory=$false)]
    [int]$MaxIterations = 50,
    
    [Parameter(Mandatory=$false)]
    [string]$Symbol = "XAUUSD",
    
    [Parameter(Mandatory=$false)]
    [string]$Period = "M30",
    
    [Parameter(Mandatory=$false)]
    [string]$FromDate = "2024.01.01",
    
    [Parameter(Mandatory=$false)]
    [string]$ToDate = "2024.12.01"
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
$ReportFile = Join-Path $TesterDir "backtest_report.htm"
$ResultsLog = Join-Path $ScriptDir "optimization_results.json"

# ═══════════════════════════════════════════════════════════════════════════
# Parameters to optimize (name, min, max, step, current)
# ═══════════════════════════════════════════════════════════════════════════
$OptimizableParams = @(
    @{Name="InpMinRR"; Min=1.5; Max=4.0; Step=0.5; Current=2.5},
    @{Name="InpFractalK"; Min=3; Max=8; Step=1; Current=5},
    @{Name="InpMinBreakPts"; Min=100; Max=400; Step=50; Current=150},
    @{Name="InpMinStopPts"; Min=800; Max=1500; Step=100; Current=1000},
    @{Name="InpSpreadMaxPts"; Min=300; Max=600; Step=50; Current=500},
    @{Name="InpMinBodyATR"; Min=0.5; Max=1.2; Step=0.1; Current=0.8},
    @{Name="InpOB_MinSizePts"; Min=150; Max=350; Step=50; Current=200}
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
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Test-Prerequisites {
    Write-Log "Checking prerequisites..."
    
    if (-not (Test-Path $Terminal)) {
        Write-Log "MT5 Terminal not found at: $Terminal" "ERROR"
        Write-Log "Please specify correct path with -MT5Path parameter" "ERROR"
        return $false
    }
    
    if (-not (Test-Path $MetaEditor)) {
        Write-Log "MetaEditor not found at: $MetaEditor" "ERROR"
        return $false
    }
    
    if (-not (Test-Path $EASource)) {
        Write-Log "EA source not found at: $EASource" "ERROR"
        return $false
    }
    
    # Create directories if not exist
    if (-not (Test-Path $ProfilesDir)) {
        New-Item -ItemType Directory -Path $ProfilesDir -Force | Out-Null
    }
    if (-not (Test-Path $TesterDir)) {
        New-Item -ItemType Directory -Path $TesterDir -Force | Out-Null
    }
    
    Write-Log "All prerequisites OK" "SUCCESS"
    return $true
}

function Compile-EA {
    Write-Log "Compiling EA..."
    
    $logFile = Join-Path $ScriptDir "compile.log"
    
    $process = Start-Process -FilePath $MetaEditor `
        -ArgumentList "/compile:`"$EASource`" /log:`"$logFile`"" `
        -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -eq 0 -and (Test-Path ($EASource -replace "\.mq5$", ".ex5"))) {
        Write-Log "Compile successful" "SUCCESS"
        return $true
    } else {
        Write-Log "Compile failed. Check $logFile for details" "ERROR"
        if (Test-Path $logFile) {
            Get-Content $logFile | ForEach-Object { Write-Log $_ "ERROR" }
        }
        return $false
    }
}

function Create-ConfigFile {
    Write-Log "Creating backtest config..."
    
    $config = @"
[Tester]
Expert=Experts\V2-oat.ex5
ExpertParameters=V2-oat.set
Symbol=$Symbol
Period=$Period
FromDate=$FromDate
ToDate=$ToDate
Model=0
Optimization=0
Deposit=10000
Currency=USD
Leverage=100
Visual=0
Report=tester\backtest_report
ReplaceReport=1
ShutdownTerminal=1
"@
    
    $config | Out-File -FilePath $ConfigFile -Encoding ASCII -Force
    Write-Log "Config created: $ConfigFile" "SUCCESS"
}

function Create-SetFile {
    param([hashtable]$Params)
    
    Write-Log "Creating parameter set file..."
    
    # Read template and update values
    $templatePath = Join-Path $ScriptDir "V2-oat.set.txt"
    
    if (Test-Path $templatePath) {
        $content = Get-Content $templatePath -Raw
        
        foreach ($param in $Params.GetEnumerator()) {
            $pattern = "(?m)^$($param.Key)=.*$"
            $replacement = "$($param.Key)=$($param.Value)"
            $content = $content -replace $pattern, $replacement
        }
        
        $content | Out-File -FilePath $SetFile -Encoding ASCII -Force
    } else {
        # Create minimal set file
        $setContent = ""
        foreach ($param in $Params.GetEnumerator()) {
            $setContent += "$($param.Key)=$($param.Value)`n"
        }
        $setContent | Out-File -FilePath $SetFile -Encoding ASCII -Force
    }
    
    Write-Log "Set file created: $SetFile" "SUCCESS"
}

function Run-Backtest {
    Write-Log "Running backtest..."
    
    # Delete old report
    if (Test-Path $ReportFile) {
        Remove-Item $ReportFile -Force
    }
    
    # Run MT5 with config
    $process = Start-Process -FilePath $Terminal `
        -ArgumentList "/config:`"$ConfigFile`"" `
        -PassThru
    
    # Wait for completion (MT5 will shutdown automatically)
    $timeout = 600  # 10 minutes max
    $elapsed = 0
    
    while (-not $process.HasExited -and $elapsed -lt $timeout) {
        Start-Sleep -Seconds 5
        $elapsed += 5
        Write-Host "." -NoNewline
    }
    Write-Host ""
    
    if ($elapsed -ge $timeout) {
        Write-Log "Backtest timeout after $timeout seconds" "WARNING"
        try { $process.Kill() } catch {}
        return $false
    }
    
    # Check if report was generated
    Start-Sleep -Seconds 2
    if (Test-Path $ReportFile) {
        Write-Log "Backtest completed" "SUCCESS"
        return $true
    } else {
        Write-Log "Report not found at: $ReportFile" "ERROR"
        return $false
    }
}

function Parse-Report {
    Write-Log "Parsing backtest report..."
    
    if (-not (Test-Path $ReportFile)) {
        Write-Log "Report file not found" "ERROR"
        return $null
    }
    
    $html = Get-Content $ReportFile -Raw -Encoding UTF8
    
    # Parse metrics from HTML
    $result = @{
        TotalTrades = 0
        WinTrades = 0
        LossTrades = 0
        WinRate = 0.0
        ProfitFactor = 0.0
        NetProfit = 0.0
        MaxDrawdown = 0.0
    }
    
    # Extract Total Trades
    if ($html -match 'Total Trades[^\d]*(\d+)') {
        $result.TotalTrades = [int]$Matches[1]
    }
    
    # Extract Win Trades (Short Won + Long Won OR Profit Trades)
    if ($html -match 'Profit Trades[^\d]*(\d+)') {
        $result.WinTrades = [int]$Matches[1]
    } elseif ($html -match 'Short Won[^\d]*(\d+).*Long Won[^\d]*(\d+)') {
        $result.WinTrades = [int]$Matches[1] + [int]$Matches[2]
    }
    
    # Extract Loss Trades
    if ($html -match 'Loss Trades[^\d]*(\d+)') {
        $result.LossTrades = [int]$Matches[1]
    }
    
    # Calculate Win Rate
    if ($result.TotalTrades -gt 0) {
        $result.WinRate = [math]::Round(($result.WinTrades / $result.TotalTrades) * 100, 2)
    }
    
    # Extract Profit Factor
    if ($html -match 'Profit Factor[^\d.]*(\d+\.?\d*)') {
        $result.ProfitFactor = [double]$Matches[1]
    }
    
    # Extract Net Profit
    if ($html -match 'Total Net Profit[^\d.-]*(-?\d+\.?\d*)') {
        $result.NetProfit = [double]$Matches[1]
    }
    
    # Extract Max Drawdown
    if ($html -match 'Maximal Drawdown[^\d.]*(\d+\.?\d*)') {
        $result.MaxDrawdown = [double]$Matches[1]
    }
    
    Write-Log "Results: Trades=$($result.TotalTrades), Win=$($result.WinTrades), WinRate=$($result.WinRate)%, PF=$($result.ProfitFactor)"
    
    return $result
}

function Get-NextParameterSet {
    param(
        [array]$Params,
        [int]$Iteration
    )
    
    # Simple grid search: vary one parameter at a time
    $paramIndex = $Iteration % $Params.Count
    $stepMultiplier = [math]::Floor($Iteration / $Params.Count) + 1
    
    $newParams = @{}
    
    for ($i = 0; $i -lt $Params.Count; $i++) {
        $param = $Params[$i]
        
        if ($i -eq $paramIndex) {
            # Vary this parameter
            $newValue = $param.Current + ($param.Step * $stepMultiplier)
            if ($newValue -gt $param.Max) {
                $newValue = $param.Min
            }
            $newParams[$param.Name] = $newValue
            $Params[$i].Current = $newValue
        } else {
            $newParams[$param.Name] = $param.Current
        }
    }
    
    return $newParams
}

function Save-Results {
    param(
        [hashtable]$Params,
        [hashtable]$Metrics,
        [int]$Iteration
    )
    
    $entry = @{
        Iteration = $Iteration
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Parameters = $Params
        Metrics = $Metrics
    }
    
    $results = @()
    if (Test-Path $ResultsLog) {
        $results = Get-Content $ResultsLog | ConvertFrom-Json
        if ($results -eq $null) { $results = @() }
    }
    
    $results += $entry
    $results | ConvertTo-Json -Depth 10 | Out-File $ResultsLog -Encoding UTF8
}

# ═══════════════════════════════════════════════════════════════════════════
# Main Execution
# ═══════════════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  SMC/ICT EA Auto-Optimization System" -ForegroundColor Cyan
Write-Host "  Target Win Rate: $TargetWinRate%" -ForegroundColor Cyan
Write-Host "  Max Iterations: $MaxIterations" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Check prerequisites
if (-not (Test-Prerequisites)) {
    Write-Log "Prerequisites check failed. Exiting." "ERROR"
    exit 1
}

# Compile EA
if (-not (Compile-EA)) {
    Write-Log "EA compilation failed. Exiting." "ERROR"
    exit 1
}

# Create config file
Create-ConfigFile

# Optimization loop
$bestWinRate = 0.0
$bestParams = @{}
$iteration = 0

while ($iteration -lt $MaxIterations) {
    $iteration++
    
    Write-Host ""
    Write-Log "═══════════════════════════════════════════════════════════════"
    Write-Log "ITERATION $iteration / $MaxIterations"
    Write-Log "═══════════════════════════════════════════════════════════════"
    
    # Get next parameter set
    $currentParams = Get-NextParameterSet -Params $OptimizableParams -Iteration $iteration
    
    Write-Log "Testing parameters:"
    foreach ($p in $currentParams.GetEnumerator()) {
        Write-Log "  $($p.Key) = $($p.Value)"
    }
    
    # Create set file with current params
    Create-SetFile -Params $currentParams
    
    # Run backtest
    if (-not (Run-Backtest)) {
        Write-Log "Backtest failed, skipping iteration" "WARNING"
        continue
    }
    
    # Parse results
    $metrics = Parse-Report
    if ($metrics -eq $null) {
        Write-Log "Failed to parse report, skipping iteration" "WARNING"
        continue
    }
    
    # Save results
    Save-Results -Params $currentParams -Metrics $metrics -Iteration $iteration
    
    # Check if target reached
    if ($metrics.WinRate -ge $TargetWinRate) {
        Write-Host ""
        Write-Log "═══════════════════════════════════════════════════════════════" "SUCCESS"
        Write-Log "TARGET ACHIEVED!" "SUCCESS"
        Write-Log "Win Rate: $($metrics.WinRate)% >= $TargetWinRate%" "SUCCESS"
        Write-Log "═══════════════════════════════════════════════════════════════" "SUCCESS"
        
        Write-Log "Best Parameters:" "SUCCESS"
        foreach ($p in $currentParams.GetEnumerator()) {
            Write-Log "  $($p.Key) = $($p.Value)" "SUCCESS"
        }
        
        # Save best params to file
        $currentParams | ConvertTo-Json | Out-File (Join-Path $ScriptDir "best_params.json") -Encoding UTF8
        Write-Log "Best parameters saved to best_params.json" "SUCCESS"
        
        exit 0
    }
    
    # Track best so far
    if ($metrics.WinRate -gt $bestWinRate) {
        $bestWinRate = $metrics.WinRate
        $bestParams = $currentParams.Clone()
        Write-Log "New best win rate: $bestWinRate%" "SUCCESS"
    }
    
    Write-Log "Current best: $bestWinRate% (target: $TargetWinRate%)"
}

# Max iterations reached
Write-Host ""
Write-Log "═══════════════════════════════════════════════════════════════" "WARNING"
Write-Log "MAX ITERATIONS REACHED" "WARNING"
Write-Log "Best Win Rate achieved: $bestWinRate%" "WARNING"
Write-Log "Target was: $TargetWinRate%" "WARNING"
Write-Log "═══════════════════════════════════════════════════════════════" "WARNING"

if ($bestWinRate -gt 0) {
    Write-Log "Best Parameters:" "WARNING"
    foreach ($p in $bestParams.GetEnumerator()) {
        Write-Log "  $($p.Key) = $($p.Value)" "WARNING"
    }
    $bestParams | ConvertTo-Json | Out-File (Join-Path $ScriptDir "best_params.json") -Encoding UTF8
}

exit 0
