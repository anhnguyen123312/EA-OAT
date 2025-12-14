# Cursor Agent - MQL5 EA Development

Thư mục này chứa các workflows và commands để Cursor tự động làm việc với MQL5 EA.

## 📁 Cấu Trúc

```
.agent/
├── workflows/
│   └── build-ea.md          # Workflow documentation
├── commands/
│   └── build-and-check.ps1  # Auto build & check command
└── README.md                 # This file
```

## 🚀 Sử Dụng

### Tự Động (Cursor)

Cursor sẽ tự động chạy command sau mỗi lần edit code:

```powershell
.agent/commands/build-and-check.ps1
```

### Thủ Công

Bạn có thể chạy thủ công:

```powershell
# Với default paths
.agent/commands/build-and-check.ps1

# Với custom paths
.agent/commands/build-and-check.ps1 `
    -EAPath "path/to/your/ea.mq5" `
    -MetaEditor "path/to/metaeditor64.exe"
```

## 📋 Workflows

### Build & Check EA

**File**: `.agent/workflows/build-ea.md`

**Mô tả**: Tự động compile EA và phân tích errors/warnings.

**Khi nào chạy**:
- Sau khi edit file `.mq5` hoặc `.mqh`
- Khi user yêu cầu "compile EA" hoặc "check errors"

**Kết quả**:
- ✅ Success: Hiển thị "No errors"
- ❌ Failed: Hiển thị errors với file và line number

### Auto Update Documentation

**File**: `.agent/workflows/update-docs.md`

**Mô tả**: Tự động cập nhật documentation khi code hoặc requirements thay đổi.

**Khi nào chạy**:
- Sau khi thay đổi code logic
- Khi user yêu cầu cập nhật docs
- Khi business rules thay đổi

**Quy tắc**:
- ✅ Cập nhật docs gốc (không tạo file mới)
- ✅ Giữ nguyên tên file và cấu trúc
- ❌ KHÔNG tạo file với version/timeline
- ❌ KHÔNG tạo backup files

**Mapping Code → Docs**:
- `detectors.mqh` → `docs/v2/code_logic/02_DETECTORS.md`
- `arbiter.mqh` → `docs/v2/code_logic/03_ARBITER.md`
- `executor.mqh` → `docs/v2/code_logic/04_EXECUTOR.md`
- `risk_manager.mqh` → `docs/v2/code_logic/05_RISK_MANAGER.md`
- Config → `docs/v2/business/07_CONFIGURATION.md`
- Entry rules → `docs/v2/business/ENTRY_RULES.md`
- Xem chi tiết trong workflow file

## ⚙️ Cấu Hình

### Default Paths

Command script sử dụng default paths:
- **EA Path**: `Experts/V2-oat.mq5` (relative to workspace)
- **MetaEditor**: `C:\Program Files\MetaTrader 5\metaeditor64.exe`

### Custom Paths

Nếu paths khác, có thể:
1. Sửa trong `.agent/commands/build-and-check.ps1`
2. Hoặc pass parameters khi chạy command

## 🔧 Troubleshooting

### Command không chạy

1. Kiểm tra file `.cursorrules` có tồn tại không
2. Kiểm tra quyền execute PowerShell scripts
3. Kiểm tra paths có đúng không

### Log file không tìm thấy

1. Kiểm tra MetaEditor path
2. Kiểm tra EA file path
3. Kiểm tra quyền truy cập file

### Errors không parse được

1. Kiểm tra format log file (có thể khác version MT5)
2. Xem log file trực tiếp để debug

## 📝 Notes

- Tất cả commands sử dụng PowerShell
- Exit codes: 0 = success, 1 = failed
- Cursor sẽ dựa vào exit code để biết kết quả

---

**Version**: 1.0  
**Last Updated**: 2025-01-XX

