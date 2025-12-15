## Cursor Agent Profile

**Mục tiêu:** Đảm bảo Cursor luôn:

- Nhớ đúng **context EA OAT v2.1 (theo kiến trúc docs/v3)**
- Hiểu rõ kiến trúc EA OAT và các file chính
- Bỏ qua code không liên quan, chỉ tập trung vào EA chính

### 1. Files bắt buộc phải đọc trước khi sửa code

- `AGENTS.md`  
- `docs/v3/00_RISK_GATE.md`  
- `docs/v3/01_LAYER1_DETECTION.md`  
- `docs/v3/02_LAYER2_EXECUTION.md`  
- `docs/v3/03_LAYER3_ANALYTICS.md`

Nếu task liên quan đến logic cụ thể:

- Detection: `Include/detectors.mqh`  
- Execution/Entry/SL/TP: `Include/executor.mqh`  
- Arbitration/Scoring: `Include/arbiter.mqh`  
- Risk & DCA: `Include/risk_manager.mqh`  
- Stats & Dashboard: `Include/stats_manager.mqh`, `Include/draw_debug.mqh`  
- Main flow: `Experts/V2-oat.mq5`

### 2. Phạm vi code cần ưu tiên

**Luôn ưu tiên đọc/sửa:**

- `Experts/V2-oat.mq5` (EA chính)  
- `Include/detectors.mqh`  
- `Include/arbiter.mqh`  
- `Include/executor.mqh`  
- `Include/risk_manager.mqh`  
- `Include/stats_manager.mqh`  
- `Include/draw_debug.mqh`

**Mặc định bỏ qua / chỉ đọc khi user yêu cầu rõ:**

- Folder `archive/`  
- `Indicators/`, `Scripts/`, `Services/`  
- Các file `.set`, `.hlsl`, `.bmp`, logs tester, profile cũ, v.v.

### 3. Quy tắc nhớ context

Khi bắt đầu **bất kỳ task nào liên quan đến EA**:

1. Đọc lại `AGENTS.md` (tổng quan EA + critical fixes)  
2. Đọc/refresh `docs/v3/*.md` tương ứng với layer sẽ sửa  
3. Kiểm tra `.agent/knowledge/current-requirement.md` nếu tồn tại:
   - Hiểu rõ yêu cầu hiện tại
   - Không tự suy diễn ngoài phạm vi requirement

### 4. Quy trình chuẩn cho Cursor

1. **Init Context**
   - Đọc `AGENTS.md`
   - Đọc `.agent/agents/cursor.md` (file này)
   - Đọc `.agent/knowledge/current-requirement.md` (nếu có)
2. **Xác định phạm vi code**
   - Chỉ scan các file trong danh sách ưu tiên ở mục 2
3. **Thực hiện thay đổi**
   - Sửa code ngắn gọn, nhiều log, dễ debug
4. **Build & Check**
   - Gọi script `.agent/commands/build-and-check.ps1`
5. **Cập nhật docs**
   - Nếu thay đổi logic → update docs trong `docs/v2`/`docs/v3` tương ứng


