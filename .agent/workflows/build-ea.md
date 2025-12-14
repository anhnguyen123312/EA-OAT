---
description: Build and check errors for EA after code changes - Auto error detection
---

# Build & Check EA Workflow (Auto Error Detection)

Workflow tự động compile EA và phân tích errors/warnings. Cursor sẽ tự động chạy workflow này sau mỗi lần chỉnh sửa code.

## 🚀 Cursor Auto Command

**Cursor tự động chạy command này sau mỗi lần edit code:**

```powershell
# Cursor sẽ tự động gọi command này
.agent/commands/build-and-check.ps1
```

**Hoặc chạy thủ công:**

```powershell
# Với custom paths
.agent/commands/build-and-check.ps1 -EAPath "path/to/ea.mq5" -MetaEditor "path/to/metaeditor64.exe"
```

## 🎯 Mục Đích

Tự động:
1. ✅ Compile EA
2. ✅ Đọc và phân tích log file
3. ✅ Trích xuất errors và warnings
4. ✅ Hiển thị kết quả rõ ràng
5. ✅ Đề xuất cách fix nếu có lỗi

---

## 📋 Workflow Tự Động

### Step 1: Compile EA và Phân Tích Tự Động

**Cursor sẽ tự động chạy script này:**

```powershell
# ============================================
# AUTO BUILD & CHECK EA WORKFLOW
# ============================================

$eaPath = "c:\Users\midds\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\V2-oat.mq5"
$logPath = "c:\Users\midds\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\MQL5\Experts\V2-oat.log"
$metaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"

# Step 1: Compile EA
Write-Host "🔨 Compiling EA..." -ForegroundColor Cyan
$compileResult = & $metaEditor /compile:"$eaPath" /log 2>&1

# Step 2: Wait for log file (max 5 seconds)
$timeout = 5
$elapsed = 0
while (-not (Test-Path $logPath) -and $elapsed -lt $timeout) {
    Start-Sleep -Milliseconds 500
    $elapsed += 0.5
}

# Step 3: Read and analyze log
if (Test-Path $logPath) {
    $logContent = Get-Content $logPath -Raw
    
    # Extract error count
    $errorMatch = [regex]::Match($logContent, '(\d+)\s+error\(s\)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $errorCount = if ($errorMatch.Success) { [int]$errorMatch.Groups[1].Value } else { 0 }
    
    # Extract warning count
    $warningMatch = [regex]::Match($logContent, '(\d+)\s+warning\(s\)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    $warningCount = if ($warningMatch.Success) { [int]$warningMatch.Groups[1].Value } else { 0 }
    
    # Extract errors (lines containing "error" and file info)
    $errorLines = $logContent -split "`n" | Where-Object { 
        $_ -match 'error' -and ($_ -match '\.mq[5h]' -or $_ -match 'line:')
    }
    
    # Extract warnings (lines containing "warning" and file info)
    $warningLines = $logContent -split "`n" | Where-Object { 
        $_ -match 'warning' -and ($_ -match '\.mq[5h]' -or $_ -match 'line:')
    }
    
    # Step 4: Display Results
    Write-Host "`n═══════════════════════════════════════════════════" -ForegroundColor Gray
    Write-Host "📊 COMPILE RESULTS" -ForegroundColor Yellow
    Write-Host "═══════════════════════════════════════════════════" -ForegroundColor Gray
    
    if ($errorCount -eq 0 -and $warningCount -eq 0) {
        Write-Host "✅ SUCCESS: No errors, no warnings!" -ForegroundColor Green
        Write-Host "   EA compiled successfully." -ForegroundColor Green
    }
    elseif ($errorCount -eq 0) {
        Write-Host "✅ SUCCESS: No errors!" -ForegroundColor Green
        Write-Host "⚠️  WARNINGS: $warningCount warning(s) found" -ForegroundColor Yellow
    }
    else {
        Write-Host "❌ FAILED: $errorCount error(s) found" -ForegroundColor Red
        if ($warningCount -gt 0) {
            Write-Host "⚠️  WARNINGS: $warningCount warning(s)" -ForegroundColor Yellow
        }
    }
    
    Write-Host "═══════════════════════════════════════════════════`n" -ForegroundColor Gray
    
    # Step 5: Display Errors (if any)
    if ($errorCount -gt 0) {
        Write-Host "❌ ERRORS:" -ForegroundColor Red
        Write-Host "─────────────────────────────────────────────────" -ForegroundColor Gray
        foreach ($error in $errorLines) {
            if ($error.Trim() -ne "") {
                # Extract file and line number
                $fileMatch = [regex]::Match($error, '([\w\\]+\.mq[5h])')
                $lineMatch = [regex]::Match($error, 'line:\s*(\d+)')
                
                $fileName = if ($fileMatch.Success) { $fileMatch.Groups[1].Value } else { "unknown" }
                $lineNum = if ($lineMatch.Success) { $lineMatch.Groups[1].Value } else { "?" }
                
                Write-Host "  📄 $fileName : Line $lineNum" -ForegroundColor Red
                Write-Host "     $($error.Trim())" -ForegroundColor DarkRed
            }
        }
        Write-Host "─────────────────────────────────────────────────`n" -ForegroundColor Gray
        
        # Suggest fixes
        Write-Host "💡 SUGGESTIONS:" -ForegroundColor Cyan
        Write-Host "   1. Check file paths and line numbers above" -ForegroundColor White
        Write-Host "   2. Verify variable/function declarations" -ForegroundColor White
        Write-Host "   3. Check include statements" -ForegroundColor White
        Write-Host "   4. Review syntax errors" -ForegroundColor White
        Write-Host ""
    }
    
    # Step 6: Display Warnings (if any)
    if ($warningCount -gt 0) {
        Write-Host "⚠️  WARNINGS:" -ForegroundColor Yellow
        Write-Host "─────────────────────────────────────────────────" -ForegroundColor Gray
        foreach ($warning in $warningLines) {
            if ($warning.Trim() -ne "") {
                $fileMatch = [regex]::Match($warning, '([\w\\]+\.mq[5h])')
                $lineMatch = [regex]::Match($warning, 'line:\s*(\d+)')
                
                $fileName = if ($fileMatch.Success) { $fileMatch.Groups[1].Value } else { "unknown" }
                $lineNum = if ($lineMatch.Success) { $lineMatch.Groups[1].Value } else { "?" }
                
                Write-Host "  📄 $fileName : Line $lineNum" -ForegroundColor Yellow
                Write-Host "     $($warning.Trim())" -ForegroundColor DarkYellow
            }
        }
        Write-Host "─────────────────────────────────────────────────`n" -ForegroundColor Gray
    }
    
    # Return status for Cursor
    if ($errorCount -gt 0) {
        exit 1  # Error occurred
    }
    else {
        exit 0  # Success
    }
}
else {
    Write-Host "❌ ERROR: Log file not found after compilation" -ForegroundColor Red
    Write-Host "   Check if MetaEditor path is correct: $metaEditor" -ForegroundColor Yellow
    exit 1
}
```

---

## 🔄 Cách Sử Dụng

### Tự Động (Cursor)

Cursor sẽ tự động chạy workflow này khi:
- ✅ Bạn chỉnh sửa file `.mq5` hoặc `.mqh`
- ✅ Bạn yêu cầu "compile EA" hoặc "check errors"
- ✅ Bạn save file sau khi edit

### Thủ Công

Bạn có thể chạy thủ công bằng cách:

```powershell
# Copy toàn bộ script trên vào PowerShell và chạy
```

---

## 📁 Files Liên Quan

**EA chính:**
- `Experts/V2-oat.mq5` - Main EA file

**Include files:**
- `Include/detectors.mqh` - Detection layer
- `Include/arbiter.mqh` - Arbitration layer  
- `Include/executor.mqh` - Execution layer
- `Include/risk_manager.mqh` - Risk management
- `Include/stats_manager.mqh` - Statistics
- `Include/draw_debug.mqh` - Visualization

---

## ⚙️ Cấu Hình

### MetaEditor Path

Nếu đường dẫn MetaEditor khác, sửa biến `$metaEditor`:

```powershell
# Default installation
$metaEditor = "C:\Program Files\MetaTrader 5\metaeditor64.exe"

# Portable installation
$metaEditor = "D:\MT5\metaeditor64.exe"
```

### EA Path

Nếu EA ở vị trí khác, sửa biến `$eaPath`:

```powershell
$eaPath = "C:\Your\Path\To\V2-oat.mq5"
```

---

## 📊 Kết Quả Mẫu

### ✅ Thành Công

```
═══════════════════════════════════════════════════
📊 COMPILE RESULTS
═══════════════════════════════════════════════════
✅ SUCCESS: No errors, no warnings!
   EA compiled successfully.
═══════════════════════════════════════════════════
```

### ❌ Có Lỗi

```
═══════════════════════════════════════════════════
📊 COMPILE RESULTS
═══════════════════════════════════════════════════
❌ FAILED: 2 error(s) found
⚠️  WARNINGS: 1 warning(s)
═══════════════════════════════════════════════════

❌ ERRORS:
─────────────────────────────────────────────────
  📄 detectors.mqh : Line 123
     'variableName' - undeclared identifier
  📄 arbiter.mqh : Line 45
     'functionName' - function not defined
─────────────────────────────────────────────────

💡 SUGGESTIONS:
   1. Check file paths and line numbers above
   2. Verify variable/function declarations
   3. Check include statements
   4. Review syntax errors
```

---

## 🔧 Troubleshooting

### Log File Không Tìm Thấy

1. Kiểm tra đường dẫn MetaEditor có đúng không
2. Kiểm tra quyền truy cập file
3. Thử compile thủ công trong MetaEditor

### Không Parse Được Errors

1. Kiểm tra format log file (có thể khác version MT5)
2. Xem log file trực tiếp: `Get-Content $logPath`

### Exit Code Không Đúng

- `exit 0` = Success (no errors)
- `exit 1` = Failed (has errors)

Cursor sẽ dựa vào exit code để biết compile thành công hay thất bại.

---

## 📝 Lưu Ý

1. **Auto-compile**: Cursor sẽ tự động compile khi bạn edit code
2. **Error Detection**: Tự động trích xuất và hiển thị errors/warnings
3. **File Tracking**: Tự động tìm file và line number có lỗi
4. **Suggestions**: Tự động đề xuất cách fix lỗi phổ biến
5. **Real-time**: Kết quả hiển thị ngay sau khi compile

---

**Version**: 2.0  
**Last Updated**: 2025-01-XX  
**Status**: Auto Error Detection Enabled ✅