## Claude Agent Profile

**Mục tiêu:** Đảm bảo Claude luôn:

- Nắm rõ context của **EA OAT v2.1 (theo kiến trúc docs/v3)**
- Tập trung vào các file EA chính
- Không lãng phí thời gian vào code/indicator không liên quan

### 1. Bộ tài liệu phải load trước

- `AGENTS.md` (tóm tắt EA + critical fixes)  
- `docs/v3/00_RISK_GATE.md` (risk gate & high level rules)  
- `docs/v3/01_LAYER1_DETECTION.md` (detection layer)  
- `docs/v3/02_LAYER2_EXECUTION.md` (execution & order logic)  
- `docs/v3/03_LAYER3_ANALYTICS.md` (analytics & dashboard)

Nếu task liên quan đến logic cụ thể, map như sau:

- **Detection** → `Include/detectors.mqh`  
- **Arbiter/Scoring** → `Include/arbiter.mqh`  
- **Execution/SL/TP/Entry** → `Include/executor.mqh`  
- **Risk/DCA/BE/Trailing** → `Include/risk_manager.mqh`  
- **Stats/Dashboard** → `Include/stats_manager.mqh`, `Include/draw_debug.mqh`  
- **Main EA flow** → `Experts/V2-oat.mq5`

### 2. Ưu tiên / Bỏ qua

**Ưu tiên tuyệt đối:**

- `Experts/V2-oat.mq5`  
- `Include/detectors.mqh`  
- `Include/arbiter.mqh`  
- `Include/executor.mqh`  
- `Include/risk_manager.mqh`  
- `Include/stats_manager.mqh`  
- `Include/draw_debug.mqh`

**Mặc định bỏ qua (trừ khi user nói rõ):**

- Tất cả dưới `archive/`  
- Indicators, Scripts, Services  
- Files cấu hình tester cũ, `.set`, logs, resources ngoại vi

### 3. Nhớ context & requirement

- Trước khi đề xuất refactor/sửa bug:
  - Đọc `.agent/knowledge/current-requirement.md` (nếu có)
  - Tôn trọng business rules mô tả trong `docs/v3` và `AGENTS.md`
- Không tự ý thay đổi:
  - Risk model
  - Entry/Exit rules
  - v2.1 scoring system  
  trừ khi trong requirement yêu cầu rõ.

### 4. Workflow gợi ý cho Claude

1. **Hiểu yêu cầu**  
   - Đọc nguyên văn yêu cầu user  
   - Đọc `.agent/knowledge/current-requirement.md`
2. **Load context EA**  
   - Đọc `AGENTS.md` + docs `docs/v3/*.md` liên quan
3. **Xác định file mục tiêu**  
   - Chỉ xem các file trong danh sách ưu tiên (mục 2)
4. **Đề xuất thay đổi**  
   - Giải thích ngắn gọn, rõ ràng, không lan man
5. **Nhắc user** chạy build & backtest nếu dùng ngoài môi trường tự động


