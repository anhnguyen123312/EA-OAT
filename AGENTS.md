Bạn cần các chỉ dẫn chung, áp dụng cho toàn bộ dự án.
Ưu tiên sự đơn giản, dễ đọc và dễ bảo trì.
Bạn muốn các chỉ dẫn của mình có thể hoạt động trên nhiều công cụ AI khác nhau, không chỉ Cursor.
Luôn ghi log vào bot để User có thể debug, Tạo cái dashboard trong backtest

---

## Agent Workspace (Cursor, Claude, …)

Để AI luôn nhớ context EA và chỉ tập trung vào file chính, dự án sử dụng **folder chuẩn cho agents**:

- `.agent/` – workspace cho tất cả AI tools
  - `.agent/agents/cursor.md` – profile & rules riêng cho Cursor
  - `.agent/agents/claude.md` – profile & rules riêng cho Claude
  - `.agent/workflows/init-ea-context.md` – workflow chuẩn để load context EA
  - `.agent/commands/build-and-check.ps1` – script compile + đọc log cho `V2-oat.mq5`
  - `.agent/knowledge/` – nơi lưu requirements & context hiện tại (do AI tạo/ghi)

**Nguyên tắc cho mọi AI (Cursor, Claude, …):**

- Luôn đọc: `AGENTS.md` + profile tương ứng trong `.agent/agents/*.md`
- Luôn hiểu rõ kiến trúc EA và logic mô tả trong `docs/v3/*.md` trước khi sửa code
- Mặc định chỉ tập trung vào các file chính:
  - `Experts/V2-oat.mq5`
  - `Include/detectors.mqh`
  - `Include/arbiter.mqh`
  - `Include/executor.mqh`
  - `Include/risk_manager.mqh`
  - `Include/stats_manager.mqh`
  - `Include/draw_debug.mqh`
- Bỏ qua các folder/code không liên quan (archive, indicators, scripts, services, tester configs, …) trừ khi user yêu cầu rất rõ.

Workflow khởi động chuẩn: đọc `AGENTS.md` → đọc `.agent/agents/{tool}.md` → đọc `.agent/workflows/init-ea-context.md` → (nếu có) đọc `.agent/knowledge/current-requirement.md` → chỉ sau đó mới được sửa code.

---

## EA OAT – v2.1 (theo kiến trúc docs/v3) ✅

**Ngày tạo**: October 21, 2025  
**Version**: 2.1 (EA OAT)  
**Status**: Ready for Testing

### Kiến Trúc EA OAT theo docs/v3

Kiến trúc OAT đang được mô tả chi tiết trong bộ tài liệu:

- `docs/v3/00_RISK_GATE.md` – Layer 0: Risk Gate  
- `docs/v3/01_LAYER1_DETECTION.md` – Layer 1: Detection / Methods  
- `docs/v3/02_LAYER2_EXECUTION.md` – Layer 2: Execution & Position Risk  
- `docs/v3/03_LAYER3_ANALYTICS.md` – Layer 3: Analytics & Dashboard  

Mapping sang code hiện tại:

- **Layer 0 – Risk Gate**
  - Logic chính: `Include/Core/risk_gate.mqh`
  - Struct kết quả: `Include/Common/signal_structs.mqh` (`RiskGateResult`)

- **Layer 1 – Detection / Methods**
  - Detector & setup builder: `Include/detectors.mqh`
  - Arbiter / scoring / pattern: `Include/arbiter.mqh`

- **Layer 2 – Execution & Position Risk**
  - Thực thi lệnh + quản lý vòng đời position:  
    - `Include/executor.mqh`  
    - `Include/risk_manager.mqh`

- **Layer 3 – Analytics**
  - Thống kê & dashboard:  
    - `Include/stats_manager.mqh`  
    - `Include/draw_debug.mqh`
