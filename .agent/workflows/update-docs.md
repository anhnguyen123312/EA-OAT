---
description: Auto update documentation when code or requirements change
---

# Auto Update Documentation Workflow

Workflow tự động cập nhật documentation khi có thay đổi code hoặc yêu cầu từ user.

## 🎯 Mục Đích

Tự động:
1. ✅ Phát hiện thay đổi code hoặc yêu cầu user
2. ✅ Xác định file docs cần cập nhật
3. ✅ Cập nhật docs gốc (không tạo file mới)
4. ✅ Giữ nguyên cấu trúc và tên file

---

## 📋 Quy Trình Tự Động

### Step 1: Phát Hiện Thay Đổi

Cursor tự động phát hiện khi:
- Code file được edit (`.mq5`, `.mqh`)
- User yêu cầu cập nhật docs
- Logic hoặc business rules thay đổi

### Step 2: Xác Định File Docs Cần Cập Nhật

**Mapping Code → Docs:**

| Code File | Documentation File |
|-----------|-------------------|
| `Include/detectors.mqh` | `docs/v2/code_logic/02_DETECTORS.md` |
| `Include/arbiter.mqh` | `docs/v2/code_logic/03_ARBITER.md` |
| `Include/executor.mqh` | `docs/v2/code_logic/04_EXECUTOR.md` |
| `Include/risk_manager.mqh` | `docs/v2/code_logic/05_RISK_MANAGER.md` |
| `Include/stats_manager.mqh` | `docs/v2/code_logic/06_STATS_DASHBOARD.md` |
| `Experts/V2-oat.mq5` | `docs/v2/code_logic/08_MAIN_FLOW.md` |
| Config parameters | `docs/v2/business/07_CONFIGURATION.md` |
| Entry logic | `docs/v2/business/ENTRY_RULES.md` |
| Risk rules | `docs/v2/business/RISK_MANAGEMENT_RULES.md` |
| Trading rules | `docs/v2/business/TRADING_RULES.md` |
| System overview | `docs/v2/business/01_SYSTEM_OVERVIEW.md` |
| DCA mechanism | `docs/v2/business/DCA_MECHANISM.md` |
| Trading schedule | `docs/v2/business/TRADING_SCHEDULE.md` |

### Step 3: Đọc File Docs Hiện Tại

```powershell
# Cursor sẽ đọc file docs để hiểu nội dung hiện có
$docPath = "docs/v2/code_logic/02_DETECTORS.md"
$currentContent = Get-Content $docPath
```

### Step 4: So Sánh Với Code Mới

- Đọc code file đã thay đổi
- So sánh logic với docs hiện tại
- Xác định phần cần cập nhật

### Step 5: Cập Nhật Docs Gốc

**Quy tắc:**
- ✅ Sửa trực tiếp file docs gốc
- ✅ Xóa thông tin cũ không còn đúng
- ✅ Thêm thông tin mới
- ❌ KHÔNG tạo file mới

### Step 6: Xác Nhận Cập Nhật

- Kiểm tra nội dung đã cập nhật đúng
- Đảm bảo không có thông tin mâu thuẫn
- Giữ nguyên format và cấu trúc

---

## 🔍 Ví Dụ Cụ Thể

### Ví Dụ 1: Thay Đổi Detector Logic

**Tình huống:** User thay đổi logic trong `Include/detectors.mqh`

**Cursor sẽ:**
1. Phát hiện file `detectors.mqh` đã thay đổi
2. Xác định cần cập nhật: `docs/v2/code_logic/02_DETECTORS.md`
3. Đọc file docs hiện tại
4. So sánh logic mới với docs
5. Cập nhật trực tiếp file `02_DETECTORS.md`
6. Xóa phần logic cũ, thêm logic mới

### Ví Dụ 2: Thay Đổi Entry Rules

**Tình huống:** User yêu cầu "cập nhật entry rules về OB"

**Cursor sẽ:**
1. Phát hiện yêu cầu từ user
2. Xác định cần cập nhật: `docs/v2/business/ENTRY_RULES.md`
3. Đọc file docs hiện tại
4. Cập nhật phần OB entry rules
5. Giữ nguyên các phần khác

### Ví Dụ 3: Thay Đổi Configuration

**Tình huống:** User thay đổi config parameters trong EA

**Cursor sẽ:**
1. Phát hiện config đã thay đổi
2. Xác định cần cập nhật: `docs/v2/business/07_CONFIGURATION.md`
3. Đọc file docs hiện tại
4. Cập nhật parameters mới
5. Xóa parameters cũ nếu không còn dùng

---

## ❌ Những Điều KHÔNG ĐƯỢC LÀM

1. **KHÔNG tạo file mới với version:**
   - ❌ `02_DETECTORS_v2.md`
   - ❌ `ENTRY_RULES_2025.md`
   - ❌ `CONFIGURATION_updated.md`

2. **KHÔNG tạo timeline/changelog:**
   - ❌ `CHANGELOG.md`
   - ❌ `UPDATE_HISTORY.md`
   - ❌ `VERSION_LOG.md`

3. **KHÔNG giữ version cũ trong file:**
   - ❌ Thêm section "Old Logic" trong docs
   - ❌ Comment out phần cũ
   - ❌ Tạo backup trong docs folder

4. **KHÔNG tạo file backup:**
   - ❌ `02_DETECTORS.md.backup`
   - ❌ `ENTRY_RULES.md.old`

---

## ✅ Những Điều PHẢI LÀM

1. **Cập nhật trực tiếp file gốc:**
   - ✅ Sửa `02_DETECTORS.md` trực tiếp
   - ✅ Sửa `ENTRY_RULES.md` trực tiếp

2. **Giữ nguyên tên và cấu trúc:**
   - ✅ Giữ tên file như cũ
   - ✅ Giữ cấu trúc thư mục

3. **Cập nhật nội dung mới nhất:**
   - ✅ Xóa thông tin cũ không còn đúng
   - ✅ Thêm thông tin mới
   - ✅ Cập nhật examples nếu có

4. **Đảm bảo tính nhất quán:**
   - ✅ Docs phải khớp với code hiện tại
   - ✅ Không có thông tin mâu thuẫn

---

## 🔧 Troubleshooting

### Docs không khớp với code

1. Kiểm tra mapping Code → Docs có đúng không
2. Đọc lại code file để xác nhận logic
3. Cập nhật lại docs cho khớp

### Không biết cập nhật file nào

1. Xem mapping table ở Step 2
2. Hoặc tìm trong `docs/v2/README.md` để biết cấu trúc
3. Hỏi user nếu không chắc

### User yêu cầu cập nhật nhưng không rõ file nào

1. Hỏi user cụ thể muốn cập nhật phần nào
2. Hoặc tự động detect dựa vào context
3. Cập nhật tất cả file liên quan nếu cần

---

## 📝 Notes

- Tất cả cập nhật docs phải **in-place** (sửa trực tiếp)
- Không tạo file mới trừ khi user yêu cầu cụ thể
- Giữ nguyên format markdown và cấu trúc
- Đảm bảo docs luôn sync với code

---

**Version**: 1.0  
**Last Updated**: 2025-01-XX  
**Status**: Auto Update Enabled ✅

