## Workflow: Init EA Context (Cursor & Claude)

Workflow này dùng chung cho tất cả AI (Cursor, Claude, …) khi làm việc với **SMC/ICT EA v2.1**.

### Bước 1: Đọc tổng quan hệ thống

1. Đọc `AGENTS.md` để nắm:
   - Kiến trúc 5 layers
   - File chính của từng layer
   - Critical fixes mới nhất

2. Đọc các docs v3 tương ứng:
   - `docs/v3/00_RISK_GATE.md`
   - `docs/v3/01_LAYER1_DETECTION.md`
   - `docs/v3/02_LAYER2_EXECUTION.md`
   - `docs/v3/03_LAYER3_ANALYTICS.md`

### Bước 2: Đọc requirement hiện tại

- Nếu tồn tại: `.agent/knowledge/current-requirement.md`
  - Đọc nguyên file
  - Không suy diễn ngoài những gì file này mô tả

### Bước 3: Giới hạn phạm vi code

Chỉ coi đây là **vùng code chính**:

- `Experts/V2-oat.mq5`
- `Include/detectors.mqh`
- `Include/arbiter.mqh`
- `Include/executor.mqh`
- `Include/risk_manager.mqh`
- `Include/stats_manager.mqh`
- `Include/draw_debug.mqh`

Mặc định **bỏ qua** khi không được yêu cầu rõ:

- `archive/**`
- `Indicators/**`, `Scripts/**`, `Services/**`
- Files `.set`, logs tester, resources phụ (`.bmp`, `.hlsl`, …)

### Bước 4: Thực hiện task

1. Sửa code/logic trong các file chính ở trên
2. Ghi log đầy đủ (debug friendly)
3. Giữ code đơn giản, dễ đọc, dễ bảo trì

### Bước 5: Build & Check EA

- Chạy script: `.agent/commands/build-and-check.ps1`
  - Compile `Experts/V2-oat.mq5`
  - Đọc log và hiển thị errors/warnings

### Bước 6: Cập nhật docs & knowledge

- Nếu thay đổi logic → update docs tương ứng trong `docs/v2`/`docs/v3`
- Nếu là yêu cầu mới lớn → tạo/ghi vào `.agent/knowledge/REQ-*.md` và update `current-requirement.md`


