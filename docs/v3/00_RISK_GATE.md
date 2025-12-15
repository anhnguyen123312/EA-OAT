## 00. Layer 0: Risk Gate – Kiểm tra rủi ro đầu tiên

### 📍 Tổng quan

**Layer 0: Risk Gate** là lớp kiểm tra **đầu tiên** trong kiến trúc bot. Nhiệm vụ của nó là:
- **Quyết định có được phép trade hay không** trên mỗi tick dựa trên trạng thái rủi ro tài khoản (Daily MDD).
- **Áp trần lot size tối đa** dựa trên equity (dynamic lot sizing) và cấu hình risk per trade.
- (Tuỳ chọn) **Gate phiên giao dịch coarse-level** theo khung giờ VN (FULL_DAY / MULTI_WINDOW) để tránh trade ngoài thời gian mong muốn.

Lưu ý quan trọng:
- Risk Gate **không còn xử lý** spread, rollover hay các filter môi trường chi tiết – các phần này được thực hiện tại Execution layer.
- Risk Gate **không tính số risk pips** (maxRiskPips); việc phân bổ risk theo pips/SL cụ thể được thực hiện tại Layer 2 (Execution & Position Risk), nơi có đầy đủ thông tin SL cho từng setup.

Risk Gate được implement trong `CRiskGate` (file `Include/Core/risk_gate.mqh`) và trả về kết quả qua `RiskGateResult` (file `Include/Common/signal_structs.mqh`). Toàn bộ các layer phía sau (Detection → Arbitration → Execution) **chỉ chạy khi Risk Gate cho phép**.

---

## 1. Cấu trúc dữ liệu & tham số

### 1.1. RiskGateResult – Kết quả Risk Gate

**RiskGateResult** là output chuẩn của Layer 0, gồm các trường chính:
- **canTrade**:  
  - `true`: tất cả check đều pass, EA được phép tiếp tục chạy Detection/Arbitration/Execution.  
  - `false`: ít nhất một điều kiện fail, EA phải dừng xử lý logic trade cho tick hiện tại.
- **maxRiskPips**: trường dự phòng cho thiết kế tổng thể, nhưng **Layer 0 hiện tại không gán/không tính toán giá trị này** (luôn để 0). Việc tính toán risk pips/SL cụ thể được thực hiện tại Layer 2.
- **maxLotSize**: lot size tối đa được phép sử dụng (dynamic theo equity, có cap `lotMax`).
- **tradingHalted**: trạng thái “bị khóa trade” do Daily MDD:
  - `true`: đã chạm/vượt ngưỡng MDD ngày, mọi lệnh mới đều bị chặn.
  - `false`: vẫn được phép trade nếu các điều kiện khác ok.
- **reason**: chuỗi giải thích tại sao `canTrade = false` (ví dụ: “Daily MDD limit reached”, “Outside trading session”, “Spread too wide”, “Rollover time”).
- **filledRiskPips, filledLotSize**: tổng rủi ro (pips) và lot đã sử dụng bởi các positions đã mở.
- **pendingRiskPips, pendingLotSize**: tổng rủi ro (pips) và lot bị khoá trong các pending orders.
- **remainingRiskPips, remainingLotSize**: phần rủi ro và lot **còn lại có thể dùng** sau khi đã trừ đi phần đã occupied bởi positions và pending orders.

Trong bản code hiện tại, `CRiskGate::Check()` **chỉ tính và gán**:
- `canTrade`
- `maxLotSize`
- `tradingHalted`
- `reason`  

Trường `maxRiskPips` luôn giữ giá trị 0 (Risk Gate **không còn tính risk pips**). Các trường về filled/pending/remaining risk & lots được thiết kế để các layer khác (chủ yếu Layer 2) sử dụng và bổ sung thêm, chứ không do Risk Gate tự đi scan positions/orders.

Các trường về filled/pending/remaining risk & lots được thiết kế để các layer khác (Risk Manager / Executor) sử dụng và bổ sung thêm, chứ không do Risk Gate tự đi scan positions/orders.

### 1.2. Tham số cấu hình chính của CRiskGate

CRiskGate được khởi tạo với tập tham số:
- **symbol**: symbol đang trade (ví dụ `XAUUSD`).
- **timeframe**: khung thời gian dùng cho ATR (ví dụ `PERIOD_M30`).
- **riskPct**: phần trăm risk trên mỗi lệnh (ví dụ 0.5%).
- **dailyMddMax**: ngưỡng Daily MDD tối đa (tính theo %).
- **useDailyMDD**: có bật check Daily MDD không.
- **useEquityMDD**: Daily MDD tính trên **Equity** (`true`) hay **Balance** (`false`).
- **dailyResetHour**: giờ reset MDD mỗi ngày (theo giờ broker, hiện tại giả định GMT+7).
- **sessionOpen**: bật/tắt session filter.
- **sessStartHour / sessEndHour**: giờ bắt đầu/kết thúc session (theo giờ broker, giả định GMT+7).
- **spreadMaxPts**: spread tối đa cho phép (tính bằng points, ví dụ 500 pts = 50 pips trên XAUUSD 3-digit).
- **spreadATRpct**: ngưỡng spread tối đa theo tỉ lệ ATR (ví dụ 0.08 = 8% ATR).
- **lotBase**: base lot size ban đầu (ví dụ 0.1).
- **lotMax**: trần lot tối đa tuyệt đối (ví dụ 5.0).
- **equityPerLotInc**: mỗi khi equity tăng thêm bao nhiêu USD thì tăng lot.
- **lotIncrement**: mức lot tăng thêm ở mỗi “bậc” equity.

Ngoài ra, CRiskGate còn giữ các state nội bộ:
- **m_startDayBalance**: giá trị tài khoản tại thời điểm reset ngày (dùng để tính drawdown).
- **m_tradingHalted**: cờ “đã dừng trade do MDD”.
- **m_lastDayCheck**: mốc thời gian lần cuối thực hiện reset ngày.
- **m_atrHandle**: handle indicator ATR dùng cho việc:
  - Giới hạn spread theo ATR.
  - Giới hạn SL tối đa (suy ra maxRiskPips).

---

## 2. Luồng xử lý chính của Risk Gate

### 2.1. Thứ tự các bước trong Check()

Mỗi lần `CRiskGate::Check()` được gọi, luồng xử lý luôn theo thứ tự sau:

1. **Daily MDD Check** (nếu `useDailyMDD = true`):
   - Cập nhật/Reset thông tin ngày nếu đến giờ reset.
   - Tính drawdown theo phần trăm so với `m_startDayBalance`, trên Equity hoặc Balance.
   - Nếu drawdown hiện tại ≥ `dailyMddMax`:
     - Đánh dấu `m_tradingHalted = true`.
     - Trả về `RiskGateResult` với:
       - `tradingHalted = true`
       - `canTrade = false`
       - `reason = "Daily MDD limit reached"`.
   - Nếu chưa chạm MDD: tiếp tục bước 2.

2. **Session Check**:
   - Nếu `sessionOpen = false`: bỏ qua check, luôn cho qua.
   - Nếu `sessionOpen = true`:
     - Lấy giờ hiện tại của broker (`GetLocalHour()` – hiện tại lấy trực tiếp giờ server, được giả định đã là GMT+7).
     - Kiểm tra giờ đó có nằm trong khoảng `[sessStartHour, sessEndHour)` hay không.
     - Nếu **không nằm trong khoảng**:
       - Trả về `canTrade = false`, `reason = "Outside trading session"`.

3. **Tính toán giới hạn lot (maxLotSize)**:
- Lấy Balance hiện tại.
- Tính **Risk Amount** sơ bộ = Balance × (riskPct / 100) – dùng như tham số tổng thể cho risk, nhưng **không quy đổi thành số pip** tại Layer 0.
- Lấy Equity hiện tại, `lotBase`, `equityPerLotInc`, `lotIncrement`, `lotMax`.
- Tính **maxLotSize** bằng dynamic lot sizing:
  - Lot tăng dần theo equity từng bậc (equityPerLotInc, lotIncrement).
  - Luôn cap tại `lotMax`.
- Ghi các giá trị này vào `RiskGateResult`:
  - `maxLotSize` (đã cap theo `lotMax`)
- Set:
  - `canTrade = true`
  - `tradingHalted = false` (trong trường hợp Daily MDD ok)
  - `reason = "OK"`.

Kết quả: nếu đến cuối hàm không có check nào fail, EA được phép tiếp tục chạy các layer sau với “khung rủi ro” đã tính sẵn.

---

## 3. Daily MDD Logic

### 3.1. Reset ngày

Risk Gate theo dõi Daily MDD theo **ngày giao dịch**, với các điểm chính:
- Mỗi ngày, tại giờ `dailyResetHour` (theo giờ broker, hiện tại giả định GMT+7):
  - Cập nhật `m_startDayBalance` = giá trị tài khoản hiện tại:
    - Nếu `useEquityMDD = true`: dùng Equity.
    - Nếu `useEquityMDD = false`: dùng Balance.
  - Đặt lại `m_tradingHalted = false` để mở khóa trade cho ngày mới.
  - Log ra message dạng “Daily tracking reset. Start balance: $X”.
- Việc reset chỉ thực hiện **một lần** cho mỗi lần tới giờ reset, tránh reset liên tục trong cùng giờ.

### 3.2. Cách tính Drawdown & ngưỡng dừng trade

Khi `useDailyMDD = true`, mỗi lần `CheckDailyMDD()`:
- Lấy:
  - `currentValue` = Equity hoặc Balance hiện tại (tuỳ theo `useEquityMDD`).
  - `startDayBalance` = giá trị ghi nhận tại thời điểm reset ngày.
- Tính:
  - **drawdown tuyệt đối** = `startDayBalance - currentValue` (chỉ quan tâm chiều giảm).
  - **drawdown%** = drawdown / startDayBalance × 100.
- So sánh:
  - Nếu drawdown% ≥ `dailyMddMax`:
    - Đánh dấu `m_tradingHalted = true`.
    - Log message dạng “Trading HALTED: Daily MDD X% ≥ Y%”.
    - Trong `Check()`, ngay lập tức trả về:
      - `canTrade = false`
      - `tradingHalted = true`
      - `reason = "Daily MDD limit reached"`.
  - Nếu drawdown% < `dailyMddMax`: không thay đổi trạng thái halt, tiếp tục các check khác.

Vì `m_tradingHalted` là state nội bộ, trạng thái “bị khoá trade” sẽ được **giữ nguyên** cho đến khi reset ngày tiếp theo.

---

## 4. Session Logic (giờ giao dịch)

### 4.1. Cơ chế tổng quát

Risk Gate hỗ trợ một **session liên tục** trong ngày, xác định bởi:
- **sessStartHour**: giờ bắt đầu session.
- **sessEndHour**: giờ kết thúc session (exclusive).
- Các giá trị trên được hiểu theo **giờ server** (broker time), và trong kiến trúc v3 đang giả định broker đã chạy ở GMT+7 (hoặc đã được cấu hình tương ứng).

### 4.2. Điều kiện mở/đóng session

Logic hiện tại:
- Nếu **session filter tắt** (`sessionOpen = false`):
  - `IsSessionOpen()` luôn trả về `true`.
  - EA có thể trade 24/7 (trừ các chặn khác như MDD, spread, rollover).
- Nếu **session filter bật** (`sessionOpen = true`):
  - Lấy giờ hiện tại từ server (`GetLocalHour()` – trả về trực tiếp `dt.hour`).
  - Một tick được xem là **trong session** nếu:
    - `sessStartHour ≤ hour < sessEndHour`.
  - Nếu tick đang ở **ngoài khoảng này**:
    - `Check()` trả về `canTrade = false`, `reason = "Outside trading session"`.

Lưu ý kiến trúc v3:
- Tài liệu business trước đây mô tả 2 mode: **FULL_DAY** và **MULTI_WINDOW** với nhiều cửa sổ session.  
- Trong code `risk_gate.mqh` hiện tại, session logic của Risk Gate **chỉ implement dạng một khoảng liên tục** `sessStartHour → sessEndHour`.  
- Việc bật/tắt nhiều window (Asia/London/NY) nếu có sẽ thuộc về lớp cấu hình/logic khác, không nằm trong CRiskGate.

---

## 5. Spread Logic

Spread được kiểm tra theo **2 lớp bảo vệ song song**:

### 5.1. Giới hạn spread cố định (static max)

- Spread hiện tại được quy đổi về đơn vị **points** trên symbol (ví dụ XAUUSD 3-digit).  
- Nếu spreadPts > `spreadMaxPts`:
  - `IsSpreadOK()` trả về `false`.
  - `Check()` chặn trade với `reason = "Spread too wide"`.

### 5.2. Giới hạn spread theo ATR (dynamic ATR%)

- Lấy ATR hiện tại (chu kì 14) của symbol/timeframe đã cấu hình.
- Tính ngưỡng spread tối đa theo ATR:
  - `maxSpreadATR` = ATR × `spreadATRpct`.  
- Nếu spread hiện tại (theo giá) lớn hơn `maxSpreadATR`:
  - Spread bị coi là bất thường so với volatility.
  - `IsSpreadOK()` trả về `false`, `reason = "Spread too wide"`.

Kết luận:
- Spread chỉ được xem là **OK** nếu **đồng thời thỏa mãn**:
  - Không vượt `spreadMaxPts`.
  - Không vượt ngưỡng động theo ATR.

---

## 6. Rollover Logic

Rollover được dùng để tránh trade trong khoảng thời gian:
- Spread thường mở rộng mạnh.
- Thanh khoản thấp.

Logic hiện tại:
- Lấy giờ & phút hiện tại theo giờ server.
- Nếu:
  - `hour == 0` (tức khoảng 00h)  
  - **và** `0 ≤ minute ≤ 5`  
- Thì:
  - `IsRolloverTime()` trả về `true`.
  - `Check()` chặn trade với `reason = "Rollover time"`.

Khoảng thời gian 5 phút này áp dụng **mỗi ngày**, theo múi giờ server (giả định GMT+7).

---

## 7. Tính toán Max Risk Pips

### 7.1. Input và mục tiêu

Mục tiêu: từ **Risk Amount** (USD) và các tham số symbol, tìm ra:
- Số pip tối đa cho khoảng cách SL sao cho:
  - Nếu dùng lot tối đa (`lotMax`), tổng số tiền risk không vượt Risk Amount.
  - Khoảng cách SL vẫn được cap theo ATR để không quá lớn/phi thực tế.

Các input chính:
- Balance hiện tại.
- `riskPct` (risk mỗi lệnh, %).
- `lotMax` (trần lot).
- Giá trị point của symbol.
- ATR hiện tại.

### 7.2. Các bước tính toán

1. Tính **Risk Amount**:
   - RiskAmount = Balance × \( \frac{riskPct}{100} \).
2. Giả định pip value chuẩn cho XAUUSD (1 lot ≈ 10 USD/pip) để chuyển giữa $ và pips.
3. Tính **maxRiskPips** sơ bộ:
   - Dựa vào RiskAmount, lotMax và pip value:
   - maxRiskPips (sơ bộ) ≈ RiskAmount / (lotMax × pipValue).
4. Lấy ATR hiện tại và quy đổi sang SL tối đa cho phép (theo pips), với hệ số bảo vệ (ví dụ 3.5 × ATR), để:
   - Tạo một **maxSLPips** – SL hợp lý theo volatility.
5. Lấy:
   - maxRiskPips = min(maxRiskPips sơ bộ, maxSLPips).

Kết quả: `maxRiskPips` được giới hạn bởi **cả Risk Amount lẫn volatility thực tế**.

---

## 8. Tính toán Max Lot Size (dynamic lot sizing)

### 8.1. Mục tiêu

MaxLotSize được dùng để:
- Tạo cơ chế **tăng lot theo equity** một cách có kiểm soát.
- Đảm bảo tổng lot không vượt trần `lotMax` ngay cả khi equity tăng mạnh.

### 8.2. Logic dynamic lot sizing

Các tham số chính:
- **lotBase**: lot khởi điểm (ví dụ 0.1).
- **equityPerLotInc**: mỗi khi equity tăng thêm X USD thì tăng thêm một bậc lot.
- **lotIncrement**: lượng lot tăng cho mỗi bậc.
- **lotMax**: trần lot tuyệt đối.

Các bước:
1. Lấy **Equity** hiện tại.
2. Tính số “bậc”:
   - increments = floor(Equity / equityPerLotInc).
3. Tính lot động:
   - dynamicLot = lotBase + increments × lotIncrement.
4. Áp trần:
   - Nếu dynamicLot > lotMax → dùng lotMax.

Kết quả:  
**maxLotSize** = min(dynamicLot, lotMax).

Lưu ý:
- Công thức này **không phụ thuộc trực tiếp vào maxRiskPips**, mà tạo ra một trần lot độc lập dựa trên equity.
- Khi dùng thực tế, Execution/Risk Manager sẽ kết hợp:
  - Lot tính theo risk & SL cụ thể.
  - Trần maxLotSize và remainingLotSize để giới hạn thêm.

---

## 9. Tích hợp với Execution & Risk Manager

### 9.1. Cách Execution sử dụng RiskGateResult

Trong luồng chuẩn:
- `OnTick()` gọi `g_riskGate.Check()` **trước** khi chạy Detection/Arbitration/Execution.
- Nếu `canTrade = false`:
  - EA **return sớm**, không chạy bất kỳ logic tín hiệu hoặc đặt lệnh nào.
- Nếu `canTrade = true`:
  - Các layer sau được phép:
    - Đọc `maxRiskPips` để:
      - Reject những setup có SL quá xa.
      - Hoặc scale down risk nếu SL dài hơn mức khuyến nghị.
    - Đọc `maxLotSize` để:
      - So sánh với lot tính ra từ risk & khoảng cách SL.
      - Áp dụng giới hạn lot tối đa cho direction đó.

### 9.2. Giới hạn theo side (BUY / SELL)

Trong kiến trúc tổng thể:
- Risk Gate cung cấp **trần lot chung** (`maxLotSize`).
- Risk Manager / Execution:
  - Tự tính tổng lot đang mở theo từng direction (BUY / SELL).
  - Từ đó suy ra **remainingLotSize** cho direction đang xét:
    - remainingLotSize = maxLotSize – currentSideLots.
  - Nếu remainingLotSize ≤ 0:
    - Lệnh mới bị reject với lý do vượt trần lot.
  - Nếu remainingLotSize > 0:
    - Lot của lệnh mới được giới hạn bởi min(requestedLots, remainingLotSize).

Các trường `filledLotSize`, `pendingLotSize`, `remainingLotSize` trong `RiskGateResult` được thiết kế để đóng vai trò dữ liệu trung tâm cho những tính toán này, dù phần tính chi tiết hiện được thực hiện chủ yếu ở Risk Manager/Execution.

---

## 10. Khởi tạo & vòng đời của Risk Gate

### 10.1. Khởi tạo trong OnInit()

Trong `OnInit()` của EA:
- Tạo instance `g_riskGate`.
- Gọi hàm init với:
  - Symbol, timeframe.
  - Risk params (riskPct, dailyMddMax, dùng Equity hay Balance, dailyResetHour).
  - Session params (bật/tắt session, sessStartHour, sessEndHour).
  - Spread params (spreadMaxPts, spreadATRpct).
  - Lot sizing params (lotBase, lotMax, equityPerLotInc, lotIncrement).
- Nếu tạo ATR indicator thất bại:
  - Init trả về `false`.
  - Có log error và EA không nên tiếp tục chạy.
- Nếu init thành công:
  - Reset Daily tracking.
  - Log “Risk Gate initialized” + thông tin start balance.

### 10.2. Sử dụng trong OnTick()

Trong `OnTick()`:
- **Bước 1**: luôn gọi Risk Gate:
  - `RiskGateResult riskResult = g_riskGate.Check();`
- **Bước 2**:
  - Nếu `riskResult.canTrade == false`:
    - Có thể log lý do `riskResult.reason` (nếu khác “OK”).
    - **Return ngay** – không chạy Detection/Arbitration/Execution.
  - Nếu `riskResult.canTrade == true`:
    - Tiếp tục:
      - Chạy Detection (detectors).
      - Xử lý Arbitration (build candidate).
      - Tính Entry/SL/TP trong Execution.
    - Khi quyết định lot & SL, Execution có thể:
      - So sánh SL với `maxRiskPips`.
      - Scale hoặc cap lot theo `maxLotSize`/remainingLotSize.

---

## 11. Logging & Error Handling

### 11.1. Logging chính

Risk Gate log những sự kiện quan trọng:
- **Khi init thành công**:
  - Thông báo đã khởi tạo, kèm start balance.
- **Khi reset ngày**:
  - Log “Daily tracking reset” với balance lúc reset.
- **Khi chạm Daily MDD**:
  - Log cảnh báo “Trading HALTED: Daily MDD X% ≥ Y%”.
- **Khi bị block do điều kiện môi trường**:
  - Có thể log ở `OnTick()`:
    - “Risk Gate BLOCKED: Spread too wide”
    - “Risk Gate BLOCKED: Outside trading session”
    - “Risk Gate BLOCKED: Rollover time”
- **Khi ATR không khởi tạo được**:
  - Log lỗi “Failed to create ATR indicator”.

### 11.2. Hành vi khi lỗi

- **ATR handle invalid**:
  - Init trả về `false`, EA không nên tiếp tục.
  - Các phép tính dùng ATR trả về 0, cần tránh dùng trong live nếu chưa init thành công.
- **Không reset được Daily tracking đúng giờ**:
  - Logic hiện tại dựa trên so sánh giờ & lastDayCheck, nếu điều kiện không trùng:
    - MDD vẫn được tính trên `m_startDayBalance` cũ.
    - Có thể dẫn đến ngày mới vẫn bị giữ trạng thái halt nếu không reset đúng.
- **Spread/Session/Rollover fail**:
  - Không phải lỗi kỹ thuật, mà là điều kiện chặn trade; EA đơn giản là dừng xử lý trade cho tick đó.

---

## 12. Best Practices & Checklist

### 12.1. Khuyến nghị cấu hình

- **Daily MDD**:
  - Luôn bật trên tài khoản live.
  - Nên dùng Equity để tính MDD.
  - Ngưỡng gợi ý:
    - 5–8% cho profile conservative.
    - 8–12% cho profile aggressive.
  - Giờ reset nên đặt trước giờ mở session (ví dụ 6h nếu session 7–23).
- **Session**:
  - Dùng 1 khoảng liên tục phù hợp với timezone broker, ví dụ:
    - 6AM – 2AM tomorrow giờ broker nếu broker GMT+7.
  - Nếu broker không ở GMT+7, cần đồng bộ lại tham số sessStartHour/sessEndHour cho đúng.
- **Spread**:
  - Đặt `spreadMaxPts` sát với điều kiện thực tế của XAUUSD (ví dụ 500 pts).
  - Kết hợp thêm `spreadATRpct` (ví dụ 8%) để tự co giãn theo volatility.
- **Lot sizing**:
  - Bắt đầu với lotBase nhỏ (0.05–0.1).
  - Chọn equityPerLotInc & lotIncrement sao cho đường tăng lot mượt và không quá nhanh.
  - Đặt lotMax tương ứng với đòn bẩy/tài khoản để tránh over-leverage.

### 12.2. Checklist triển khai & test

- Risk Gate init thành công (có log đúng).
- Daily MDD:
  - Drawdown bị khóa trade đúng ngưỡng.
  - Trạng thái halt được reset đúng giờ dailyResetHour.
- Session:
  - Ngoài khoảng sessStartHour–sessEndHour thì trade bị chặn.
  - Trong khoảng thì không bị chặn (nếu các điều kiện khác ok).
- Spread:
  - Spread vượt `spreadMaxPts` → không có lệnh mới.
  - Spread trong ngưỡng và phù hợp ATR → lệnh được phép đi tiếp (nếu pass các check khác).
- Rollover:
  - Trong khoảng 00:00–00:05 (giờ server) thì không có lệnh mới.
- MaxRiskPips & MaxLotSize:
  - Giá trị thay đổi hợp lý khi Balance/Equity/ATR thay đổi.
  - Không vượt lotMax, SL không bị nhỏ/quá lớn bất hợp lý.
- Integration:
  - `OnTick()` luôn gọi Risk Gate trước tất cả logic khác.
  - Khi Risk Gate block, các layer sau không được chạy.

---

**Cập nhật lần cuối**: 2025-12-16  
**Phiên bản tài liệu**: v3 – Layer 0: Risk Gate (mô tả logic, không chứa code)  
**File code liên quan**: `Include/Core/risk_gate.mqh`, `Include/Common/signal_structs.mqh`
