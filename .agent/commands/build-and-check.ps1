Param(
    [string]$EAPath = "c:\Users\midds\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\V2-oat.mq5",
    [string]$MetaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
)

Write-Host "=== Build & Check EA ===" -ForegroundColor Cyan
Write-Host "EA: $EAPath"
Write-Host "MetaEditor: $MetaEditor"

if (-not (Test-Path $MetaEditor)) {
    Write-Host "❌ MetaEditor not found: $MetaEditor" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $EAPath)) {
    Write-Host "❌ EA file not found: $EAPath" -ForegroundColor Red
    exit 1
}

# Compile EA với log
& "$MetaEditor" /compile:"$EAPath" /log | Out-Null

$logPath = [System.IO.Path]::ChangeExtension($EAPath, ".log")

Write-Host "Waiting for log file: $logPath" -ForegroundColor Yellow

$timeoutSeconds = 5
$elapsed = 0
while (-not (Test-Path $logPath) -and $elapsed -lt $timeoutSeconds) {
    Start-Sleep -Seconds 1
    $elapsed++
}

if (-not (Test-Path $logPath)) {
    Write-Host "❌ Log file not found after $timeoutSeconds seconds." -ForegroundColor Red
    exit 1
}

Write-Host "`n=== Compile Log ===" -ForegroundColor Cyan
$logContent = Get-Content $logPath
$logContent | ForEach-Object { Write-Host $_ }

$errorsLine = $logContent | Where-Object { $_ -match "error\(s\)" -or $_ -match "errors" } | Select-Object -Last 1

if ($errorsLine -and $errorsLine -match "0 error\(s\)" -or $errorsLine -match "0 errors") {
    Write-Host "`n✅ Compile thành công (0 errors)" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n❌ Compile có lỗi, vui lòng kiểm tra log bên trên." -ForegroundColor Red
    exit 1
}

# ============================================
# CURSOR AUTO COMMAND: Build & Check EA
# ============================================
# Command này được Cursor tự động gọi sau mỗi lần edit code
# Usage: .agent/commands/build-and-check.ps1

param(
    [string]$EAPath = "c:\Users\midds\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\V2-oat.mq5",
    [string]$MetaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"
)

# Calculate paths
$eaDir = Split-Path -Parent $EAPath
$eaName = [System.IO.Path]::GetFileNameWithoutExtension($EAPath)
$logPath = Join-Path $eaDir "$eaName.log"

# ============================================
# STEP 1: Compile EA
# ============================================
Write-Host "`n🔨 [CURSOR AUTO] Compiling EA..." -ForegroundColor Cyan
Write-Host "   File: $EAPath" -ForegroundColor Gray

if (-not (Test-Path $MetaEditor)) {
    Write-Host "❌ ERROR: MetaEditor not found at: $MetaEditor" -ForegroundColor Red
    Write-Host "   Please update MetaEditor path in .agent/commands/build-and-check.ps1" -ForegroundColor Yellow
    exit 1
}

try {
    $compileResult = & $MetaEditor /compile:"$EAPath" /log 2>&1
    $compileExitCode = $LASTEXITCODE
} catch {
    Write-Host "❌ ERROR: Failed to execute MetaEditor" -ForegroundColor Red
    Write-Host "   $_" -ForegroundColor DarkRed
    exit 1
}

# ============================================
# STEP 2: Wait for log file
# ============================================
$timeout = 5
$elapsed = 0
while (-not (Test-Path $logPath) -and $elapsed -lt $timeout) {
    Start-Sleep -Milliseconds 500
    $elapsed += 0.5
}

# ============================================
# STEP 3: Read and analyze log
# ============================================
if (-not (Test-Path $logPath)) {
    Write-Host "❌ ERROR: Log file not found after compilation" -ForegroundColor Red
    Write-Host "   Expected: $logPath" -ForegroundColor Yellow
    exit 1
}

$logContent = Get-Content $logPath -Raw

# Extract error count
$errorMatch = [regex]::Match($logContent, '(\d+)\s+error\(s\)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$errorCount = if ($errorMatch.Success) { [int]$errorMatch.Groups[1].Value } else { 0 }

# Extract warning count
$warningMatch = [regex]::Match($logContent, '(\d+)\s+warning\(s\)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
$warningCount = if ($warningMatch.Success) { [int]$warningMatch.Groups[1].Value } else { 0 }

# Extract error lines (more precise)
$errorLines = @()
$logLines = $logContent -split "`n"
foreach ($line in $logLines) {
    if ($line -match 'error' -and ($line -match '\.mq[5h]' -or $line -match 'line:\s*\d+')) {
        $errorLines += $line.Trim()
    }
}

# Extract warning lines
$warningLines = @()
foreach ($line in $logLines) {
    if ($line -match 'warning' -and ($line -match '\.mq[5h]' -or $line -match 'line:\s*\d+')) {
        $warningLines += $line.Trim()
    }
}

# ============================================
# STEP 4: Display Results
# ============================================
Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Gray
Write-Host "📊 [CURSOR AUTO] COMPILE RESULTS" -ForegroundColor Yellow
Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Gray

if ($errorCount -eq 0 -and $warningCount -eq 0) {
    Write-Host "✅ SUCCESS: No errors, no warnings!" -ForegroundColor Green
    Write-Host "   EA compiled successfully. Ready to use." -ForegroundColor Green
    $success = $true
}
elseif ($errorCount -eq 0) {
    Write-Host "✅ SUCCESS: No errors!" -ForegroundColor Green
    Write-Host "⚠️  WARNINGS: $warningCount warning(s) found" -ForegroundColor Yellow
    $success = $true
}
else {
    Write-Host "❌ FAILED: $errorCount error(s) found" -ForegroundColor Red
    if ($warningCount -gt 0) {
        Write-Host "⚠️  WARNINGS: $warningCount warning(s)" -ForegroundColor Yellow
    }
    $success = $false
}

Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Gray

# ============================================
# STEP 5: Display Errors (if any)
# ============================================
if ($errorCount -gt 0 -and $errorLines.Count -gt 0) {
    Write-Host "❌ ERRORS:" -ForegroundColor Red
    Write-Host "─────────────────────────────────────────────────" -ForegroundColor Gray
    
    $errorIndex = 1
    foreach ($error in $errorLines) {
        if ($error.Trim() -ne "") {
            # Extract file and line number
            $fileMatch = [regex]::Match($error, '([\w\\]+\.mq[5h])')
            $lineMatch = [regex]::Match($error, 'line:\s*(\d+)')
            
            $fileName = if ($fileMatch.Success) { $fileMatch.Groups[1].Value } else { "unknown" }
            $lineNum = if ($lineMatch.Success) { $lineMatch.Groups[1].Value } else { "?" }
            
            Write-Host "  [$errorIndex] 📄 $fileName : Line $lineNum" -ForegroundColor Red
            Write-Host "     $($error.Trim())" -ForegroundColor DarkRed
            $errorIndex++
        }
    }
    
    Write-Host "─────────────────────────────────────────────────`n" -ForegroundColor Gray
    
    # Suggest fixes
    Write-Host "💡 SUGGESTIONS:" -ForegroundColor Cyan
    Write-Host "   1. Check file paths and line numbers above" -ForegroundColor White
    Write-Host "   2. Verify variable/function declarations" -ForegroundColor White
    Write-Host "   3. Check include statements (#include)" -ForegroundColor White
    Write-Host "   4. Review syntax errors (missing semicolons, brackets)" -ForegroundColor White
    Write-Host "   5. Check type mismatches" -ForegroundColor White
    Write-Host ""
}

# ============================================
# STEP 6: Display Warnings (if any)
# ============================================
if ($warningCount -gt 0 -and $warningLines.Count -gt 0) {
    Write-Host "⚠️  WARNINGS:" -ForegroundColor Yellow
    Write-Host "─────────────────────────────────────────────────" -ForegroundColor Gray
    
    $warningIndex = 1
    foreach ($warning in $warningLines) {
        if ($warning.Trim() -ne "") {
            $fileMatch = [regex]::Match($warning, '([\w\\]+\.mq[5h])')
            $lineMatch = [regex]::Match($warning, 'line:\s*(\d+)')
            
            $fileName = if ($fileMatch.Success) { $fileMatch.Groups[1].Value } else { "unknown" }
            $lineNum = if ($lineMatch.Success) { $lineMatch.Groups[1].Value } else { "?" }
            
            Write-Host "  [$warningIndex] 📄 $fileName : Line $lineNum" -ForegroundColor Yellow
            Write-Host "     $($warning.Trim())" -ForegroundColor DarkYellow
            $warningIndex++
        }
    }
    
    Write-Host "─────────────────────────────────────────────────`n" -ForegroundColor Gray
}

# ============================================
# STEP 7: Return status
# ============================================
if ($success) {
    Write-Host "✅ [CURSOR AUTO] Build check completed successfully" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ [CURSOR AUTO] Build check failed - Please fix errors above" -ForegroundColor Red
    exit 1
}

