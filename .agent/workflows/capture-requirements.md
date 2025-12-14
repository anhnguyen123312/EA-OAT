---
description: Capture user requirements and generate AI-readable knowledge files
---

# Capture Requirements & Generate Knowledge Workflow

Workflow tự động capture yêu cầu từ user và tạo knowledge files để AI hiểu rõ context, rules, và requirements.

## 🎯 Mục Đích

Khi user yêu cầu thay đổi/update code:
1. ✅ Capture yêu cầu chi tiết
2. ✅ Tạo knowledge files (AI-readable format)
3. ✅ Lưu context, rules, và requirements
4. ✅ Đảm bảo AI hiểu chính xác khi chỉnh sửa

---

## 📋 Quy Trình

### Step 1: Capture Requirements

Khi user yêu cầu thay đổi code, Cursor sẽ:

1. **Phân tích yêu cầu**:
   - File nào cần thay đổi?
   - Logic nào cần sửa?
   - Business rules nào liên quan?
   - Constraints/requirements gì?

2. **Tìm context liên quan**:
   - Code files liên quan
   - Documentation files
   - Existing rules và patterns

3. **Tạo knowledge file**:
   - Format: `.agent/knowledge/{timestamp}-{requirement-id}.md`
   - Chứa đầy đủ context, rules, requirements

### Step 2: Generate Knowledge File

Knowledge file format:

```markdown
# Requirement: [Title]

## 📅 Metadata
- **Date**: YYYY-MM-DD HH:MM:SS
- **Requirement ID**: REQ-YYYYMMDD-HHMMSS
- **Status**: PENDING | IN_PROGRESS | COMPLETED
- **Priority**: LOW | MEDIUM | HIGH | CRITICAL

## 🎯 User Request
[Original user request - giữ nguyên]

## 📝 Detailed Requirements

### What to Change
- [ ] File 1: `path/to/file.mqh`
  - Change: Description
  - Reason: Why
  - Impact: What will be affected

### Business Rules
- Rule 1: Description
- Rule 2: Description

### Technical Constraints
- Constraint 1: Description
- Constraint 2: Description

## 🔍 Context

### Related Files
- `Include/detectors.mqh` - Line X-Y: Related code
- `docs/v2/code_logic/02_DETECTORS.md` - Section: Related docs

### Current Implementation
[Code snippets hoặc mô tả implementation hiện tại]

### Expected Behavior
[Behavior mong đợi sau khi thay đổi]

## ✅ Acceptance Criteria
- [ ] Criterion 1
- [ ] Criterion 2
- [ ] Criterion 3

## 🔗 Related Knowledge
- Link to related docs
- Link to related code
- Link to related rules

## 📝 Implementation Notes
[Notes khi implement - sẽ được update trong quá trình làm]

## ✅ Verification Checklist
- [ ] Code changes implemented
- [ ] Tests passed
- [ ] Documentation updated
- [ ] No breaking changes
```

### Step 3: Update Knowledge During Implementation

Trong quá trình implement:
- Update "Implementation Notes"
- Track progress
- Document decisions

### Step 4: Mark Complete

Khi hoàn thành:
- Update status: COMPLETED
- Add verification results
- Link to changes made

---

## 📁 File Structure

```
.agent/
├── knowledge/
│   ├── REQ-20250115-143022-change-detector-logic.md
│   ├── REQ-20250115-150530-update-entry-rules.md
│   └── current-requirement.md  [Latest active requirement]
├── workflows/
│   └── capture-requirements.md  [This file]
└── commands/
    └── generate-knowledge.ps1     [Script to generate knowledge]
```

---

## 🔄 Auto Flow

### Khi User Yêu Cầu Thay Đổi Code

1. **Cursor tự động**:
   - Capture yêu cầu
   - Phân tích context
   - Tạo knowledge file
   - Lưu vào `.agent/knowledge/`

2. **Trước khi implement**:
   - Đọc knowledge file
   - Hiểu rõ requirements
   - Verify context

3. **Trong khi implement**:
   - Update knowledge file với progress
   - Document decisions
   - Track changes

4. **Sau khi hoàn thành**:
   - Mark complete
   - Verify all criteria
   - Update docs nếu cần

---

## 📝 Example

### User Request:
"Thay đổi logic detector BOS để check retest nhiều lần hơn"

### Generated Knowledge File:

```markdown
# Requirement: Update BOS Detector Retest Logic

## 📅 Metadata
- **Date**: 2025-01-15 14:30:22
- **Requirement ID**: REQ-20250115-143022
- **Status**: PENDING
- **Priority**: MEDIUM

## 🎯 User Request
Thay đổi logic detector BOS để check retest nhiều lần hơn

## 📝 Detailed Requirements

### What to Change
- [ ] File: `Include/detectors.mqh`
  - Function: `DetectBOS()` hoặc `UpdateBOSRetest()`
  - Change: Tăng số lần check retest từ 2 lên 3-4 lần
  - Reason: Tăng độ chính xác của BOS detection
  - Impact: Có thể ảnh hưởng đến scoring và entry timing

### Business Rules
- BOS retest phải track trong vòng 60 bars (BOS_TTL)
- Retest tolerance: 150 points (BOSRetestTolerance)
- Retest count ảnh hưởng đến BOS strength score

### Technical Constraints
- Không được break existing BOS detection
- Phải maintain backward compatibility
- Phải update docs tương ứng

## 🔍 Context

### Related Files
- `Include/detectors.mqh` - Line 200-350: BOS detection logic
- `docs/v2/code_logic/02_DETECTORS.md` - Section: BOS Retest Tracking
- `Include/arbiter.mqh` - Line 150-200: BOS retest scoring

### Current Implementation
```cpp
// Current: Check retest 2 times max
int retestCount = 0;
for(int i = 0; i < 60; i++) {
    if(price close within tolerance) {
        retestCount++;
        if(retestCount >= 2) break;  // ← Change this
    }
}
```

### Expected Behavior
- Check retest 3-4 lần thay vì 2 lần
- Update retest count tracking
- Adjust scoring logic nếu cần

## ✅ Acceptance Criteria
- [ ] BOS retest check được 3-4 lần
- [ ] Retest count được track chính xác
- [ ] Scoring logic updated nếu cần
- [ ] Docs updated
- [ ] No breaking changes

## 🔗 Related Knowledge
- `docs/v2/code_logic/02_DETECTORS.md` - BOS Retest Tracking section
- `.cursorrules` - Code style rules
- `docs/v2/business/ENTRY_RULES.md` - Entry rules affected by BOS

## 📝 Implementation Notes
[Will be updated during implementation]

## ✅ Verification Checklist
- [ ] Code changes implemented
- [ ] Tests passed
- [ ] Documentation updated
- [ ] No breaking changes
```

---

## 🚀 Usage

### Manual Trigger

```powershell
# Generate knowledge from user request
.agent/commands/generate-knowledge.ps1 `
    -Request "Thay đổi logic detector BOS" `
    -Files "Include/detectors.mqh" `
    -Priority "MEDIUM"
```

### Auto Trigger

Cursor tự động tạo knowledge file khi:
- User yêu cầu thay đổi code
- User yêu cầu update feature
- User yêu cầu fix bug

---

## 📝 Notes

- Knowledge files giúp AI hiểu rõ context trước khi implement
- Format structured để AI dễ parse và hiểu
- Tự động link đến related files và docs
- Track progress và decisions trong quá trình implement

---

**Version**: 1.0  
**Last Updated**: 2025-01-XX  
**Status**: Active ✅

