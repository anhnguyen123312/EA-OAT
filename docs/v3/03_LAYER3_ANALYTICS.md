## 03. Layer 3: Analytics – Dashboard & Statistics (Read‑Only Layer)

### 📍 Tổng quan

Layer 3 là **Analytics Layer** – lớp chỉ dùng để **quan sát và phân tích**, không tham gia ra quyết định trade, không tính toán lại risk, không can thiệp vào Execution.

- **Nhiệm vụ chính**:
  - Thu thập dữ liệu từ các layer khác (Risk Gate, Execution/Position Risk, Stats).
  - Ghi nhận kết quả trade tổng thể (không cần chi tiết theo pattern/method).
  - Hiển thị **dashboard real‑time** (trên chart / trong backtest).
  - Ghi log phục vụ debug và phân tích hiệu suất.
- **Tính chất quan trọng**:
  - **Read‑only**: không đặt lệnh, không sửa SL/TP, không đóng position.
  - Tách biệt hoàn toàn khỏi business logic (risk, entry, exit).
  - Dữ liệu được chuẩn hóa qua các struct data (`RiskManagerData`, `StatsManagerData`, state từ Executor…).

Vị trí trong kiến trúc:

- **Layer 0 – Risk Gate**: Tính khung risk/account và filter điều kiện hệ thống.
- **Layer 1 – Methods (Detection)**: Tạo MethodSignal + PositionPlan.
- **Layer 2 – Execution & Position Risk**: Thực thi ExecutionOrder, DCA/BE/Trail/Basket, cập nhật risk thực tế.
- **Layer 3 – Analytics (tài liệu này)**: Đọc lại toàn bộ state, thống kê, hiển thị.

---

### 🔗 Input & Data Flow vào Layer 3

Layer 3 **không tự đoán** dữ liệu, mà chỉ đọc từ các nguồn chuẩn hóa:

- **Từ Layer 0 – Risk Gate (`risk_gate.mqh`)**:
  - Trạng thái `canTrade` / `tradingHalted` và lý do.
  - Thông tin khung risk: `maxRiskPips`, `maxLotSize`, `remainingRiskPips`, `remainingLotSize`.
  - Thông tin session (FULL_DAY / MULTI_WINDOW) và điều kiện thị trường (spread, rollover).
  - Các giá trị này dùng để **hiển thị risk profile**, không dùng để tính toán lại risk.

- **Từ Layer 2 – Execution & Position Risk (`executor.mqh` + `risk_manager.mqh`)**:
  - Danh sách **positions đang mở** theo symbol/direction, lot, SL/TP hiện tại, mức lợi nhuận theo R, số lần DCA, trạng thái BE/Trail.
  - Thông tin **pending orders**: loại lệnh (LIMIT/STOP/MARKET), TTL (bars tuổi), còn bao lâu thì hủy.
  - Dữ liệu **basket**: tổng floating P/L, floating %, trạng thái basket TP/SL.
  - Dữ liệu **risk per side**: tổng lot BUY, tổng lot SELL, `maxLotPerSide` đã tính.
  - Đây là nguồn để Layer 3 **vẽ trạng thái hiện tại** của hệ thống, đặc biệt trong backtest.

- **Từ Stats Layer (`stats_manager.mqh`)**:
  - Danh sách **TradeRecord** nội bộ (ticket, open/close time, rr, slPips, tpPips, outcome…).
  - Thống kê **Overall stats** cho toàn hệ thống (không phân tách theo pattern):
    - Tổng số lệnh.
    - Win/Loss count, winrate, profit factor, average RR, average profit/loss.
  - Layer 3 dùng để hiển thị **hiệu suất tổng thể** của bot, không can thiệp ticket.

**Data Flow high‑level**:

- Trong **OnTick**:
  - Main EA gọi các hàm lấy data (ví dụ: `riskManager.GetData()`, `statsManager.GetData()`, state từ Executor).
  - Data được truyền vào module vẽ dashboard (`draw_debug.mqh` / dashboard) để hiển thị.
- Trong **OnTrade / OnTradeTransaction**:
  - Khi lệnh khớp → Stats Manager `RecordTrade`.
  - Khi lệnh đóng → Stats Manager `UpdateClosedTrade`.
  - Lần tick tiếp theo, dashboard lấy số liệu mới nhất để update.

---

### 🎯 Nhiệm vụ chi tiết của Layer 3

#### 1. Dashboard real‑time (Chart HUD)

Dashboard là **bảng điều khiển real‑time** hiển thị ở góc trên trái chart (Comment hoặc OBJ_LABEL), phục vụ:

- **Monitoring nhanh**:
  - State tổng thể của EA (SCANNING / WAITING / IN POSITION / HALTED).
  - Balance, Equity, Floating P/L, % thay đổi so với đầu ngày.
  - Risk frame: MaxLotPerSide, remaining risk/lot.
  - Session hiện tại (Full Day / Asia / London / NY / Break).
  - Trạng thái Risk Gate (OK / BLOCKED + reason).
- **Thông tin hoạt động** (mức tổng quan, không đi vào chi tiết từng signal/pattern):
  - Bot đang trong trạng thái: chưa có setup, có setup đang chờ, hay đang giữ position.
- **Thông tin positions**:
  - Số lượng positions BUY/SELL, tổng lots.
  - Mỗi side: average price, tổng R đang chạy, số DCA đã kích hoạt.
  - Trạng thái BE / Trailing (ON/OFF, last trail R).
- **Performance summary (tổng quan)**:
  - Tổng số lệnh, Win/Loss, WinRate, Profit Factor, tổng lợi nhuận.

Yêu cầu thiết kế dashboard:

- Đơn giản, dễ đọc, rõ ràng theo từng block:
  - Block State & Risk.
  - Block Session & Market Filters.
  - Block Signals.
  - Block Positions.
  - Block Stats.
- Không che chart quan trọng, có thể dùng font nhỏ và màu LIME trong live, màu mặc định trong backtest.
- Update **mỗi tick** trong live, **theo progression** trong Strategy Tester.

#### 2. Logging phục vụ debug & phân tích

Layer 3 chịu trách nhiệm **log có cấu trúc**, giúp đọc lại hành vi bot:

- Log theo **sự kiện lớn**:
  - Risk Gate block (Daily MDD, Session closed, Spread too wide, Rollover).
  - Khi một setup được chọn, cùng score, RR, pattern.
  - Khi một ExecutionOrder được gửi sang Layer 2.
  - Khi DCA/BE/Trail/Basket được kích hoạt.
  - Khi Daily MDD / Basket SL / Basket TP được hit.
- Log **theo chu kỳ**:
  - Một bản tóm tắt trạng thái mỗi X phút (live) hoặc mỗi Y bars (backtest).
  - Gồm equity, số positions, risk đang sử dụng, trạng thái các session.

Nguyên tắc logging:

- Nội dung **ngắn gọn**, tập trung vào:
  - “Cái gì đã xảy ra?”
  - “Tại sao?” (lý do, điều kiện).
- Không spam log mỗi tick với cùng một thông tin; chỉ log khi state thay đổi hoặc khi qua mốc thời gian cố định.

#### 3. Thống kê hiệu suất (Stats Manager)

Stats Manager chịu trách nhiệm:

- Ghi lại **mỗi trade** với các thông tin cần thiết cho hiệu suất tổng quan:
  - Ticket, open/close time, direction, lots.
  - SL/TP tính theo pips; RR danh nghĩa cho setup đó.
  - Profit thực tế của trade, đánh dấu Win/Loss.
- Tính **OverallStats** cho toàn hệ thống (không phân tách theo pattern):
  - Tổng số lệnh, số Win, số Loss.
  - Win rate (%).
  - Average Profit per trade.
  - Average Win, Average Loss.
  - Profit Factor.
  - Average RR.

Layer 3 sử dụng các thống kê này để:

- Vẽ phần **STATS** trên dashboard (tổng quan).
- Hỗ trợ người dùng đọc kết quả backtest:
  - Hiểu kỳ vọng lợi nhuận tổng thể và độ biến động.
  - Đánh giá mức độ phù hợp của cấu hình risk/session hiện tại.

#### 4. Hỗ trợ Backtest Visualization

Trong Strategy Tester (visual mode), Layer 3:

- Đảm bảo dashboard hiển thị **đầy đủ** giống live:
  - Có thể thay đổi một số chi tiết nhỏ (màu chữ, tần suất log) để tránh overload.
- Không dùng các đối tượng đồ họa phức tạp nếu có nguy cơ làm backtest chậm; ưu tiên:
  - Comment() cho HUD text.
  - Một số OBJ_LABEL/OBJ_TEXT đơn giản nếu cần nhấn mạnh.
- Ghi log ít thường xuyên hơn (ví dụ: mỗi 5 phút dữ liệu backtest) để file log không quá nặng.

---

### 🚫 Những việc Layer 3 **không được làm**

Để tránh trùng lặp logic và khó debug, Layer 3 **tuyệt đối không**:

- Không tính lại:
  - Risk% per trade.
  - MaxLot hoặc MaxRiskPips.
  - Entry/SL/TP, RR cho setup.
- Không can thiệp Execution:
  - Không gửi lệnh mới.
  - Không sửa SL/TP.
  - Không đóng/mở positions.
- Không quyết định:
  - Có nên dừng trading khi Daily MDD đạt ngưỡng (đây là nhiệm vụ Layer 0 + Risk Manager/Execution).
  - Có nên bật/tắt một pattern hay method – Layer 3 chỉ cung cấp số liệu cho người dùng tự quyết định.

Layer 3 chỉ có vai trò **“gương soi”**: phản chiếu chính xác những gì các layer khác đang làm.

---

### 🧱 Cấu trúc file & trách nhiệm

- `stats_manager.mqh`:
  - Quản lý lịch sử trade nội bộ (TradeRecord).
  - Tính toán OverallStats (không cần breakdown chi tiết theo pattern).
  - Cung cấp struct `StatsManagerData` cho dashboard.
- `draw_debug.mqh` (hoặc dashboard module):
  - Nhận dữ liệu từ:
    - Risk Gate (RiskGateResult).
    - Risk Manager / Execution (RiskManagerData, state positions, pending).
    - Stats Manager (StatsManagerData).
  - Build thành chuỗi text dashboard + các label/objects trên chart.
  - Ẩn/hiện hoặc điều chỉnh layout theo chế độ:
    - Live vs Backtest.
    - User bật/tắt từng block thông tin (nếu có input config).

---

### 📊 Layout gợi ý cho Dashboard v3

Một layout tham chiếu (không ràng buộc cứng, chỉ để chuẩn hóa tư duy):

- **Header**:
  - Tên EA + phiên bản.
  - Symbol, Timeframe.
- **STATE & RISK**:
  - STATE hiện tại (SCANNING, IN POSITION, HALTED…).
  - Balance, Equity, Floating P/L, Daily P/L%.
  - MaxLotPerSide, CurrentSideLots BUY/SELL, Remaining.
  - Risk Gate status: OK / BLOCKED (lý do).
- **SESSION & MARKET**:
  - Session mode (FULL_DAY / MULTI_WINDOW).
  - Window hiện tại (Asia / London / NY / Break).
  - Spread hiện tại vs max, ATR snapshot.
- **SIGNALS (Latest / Active)**:
  - Method: SMC / ICT / Custom.
  - Pattern: BOS+OB / Sweep+FVG / Confluence…
  - Direction, RR, score.
  - Entry type: LIMIT / STOP / MARKET.
- **POSITIONS**:
  - Tổng số positions long/short, tổng lot mỗi bên.
  - Mỗi bên: average entry, current R, số DCA levels đã chạy.
  - Cờ BE/Trail (ON/OFF) và last trail R.
- **STATS**:
  - Tổng lệnh: Win/Loss, WinRate%, Profit Factor, Total Profit.
  - Option: Hiển thị top 1–2 patterns (theo winrate hoặc số lệnh).

Tất cả các block phải **dễ bỏ / dễ thêm** bằng config, để user có thể tùy chỉnh mức độ chi tiết cần xem.

---

### ✅ Checklist thiết kế Layer 3

- **Read‑Only**:
  - Không có bất kỳ lệnh nào truy cập trực tiếp vào OrderSend/SLTP.
  - Chỉ sử dụng dữ liệu đọc từ các layer khác.
- **Tách biệt logic**:
  - Không tính risk mới, không override logic của Risk Gate / Execution / Methods.
  - Mọi phép tính ở đây là thống kê và format hiển thị (đếm, tổng, trung bình…).
- **Đủ dữ liệu cho người dùng**:
  - Có thể nhìn dashboard + stats là hiểu ngay:
    - Bot đang trong trạng thái gì.
    - Đang risk bao nhiêu.
    - Pattern nào đang hiệu quả.
    - Tại sao hôm nay bot dừng (Daily MDD, Basket SL…).
- **Thân thiện backtest**:
  - Dashboard luôn visible.
  - Log không quá dày nhưng đủ để replay logic.

---

### 📎 Tài liệu liên quan

- `docs/v3/00_RISK_GATE.md` – Layer 0: Risk Gate (khung risk & session).
- `docs/v3/01_LAYER1_DETECTION.md` – Layer 1: Detection & Methods.
- `docs/v3/02_LAYER2_EXECUTION.md` – Layer 2: Execution & Position Risk.
- `docs/v2/code_logic/06_STATS_DASHBOARD.md` – Tài liệu legacy về dashboard/stats (tham khảo).


