## 02. Layer 2: Execution & Position Risk – Gộp Lệnh + Quản Lý Position

### 📍 Tổng quan thiết kế mới

Trong kiến trúc cũ, **Layer 2 (Execution)** và **Layer 3 (Risk Management)** có nhiều phần trùng nhau:

- Cùng can thiệp vào lot size và risk.
- Cùng theo dõi positions để chạy DCA, BE, Trailing.
- Cùng có logic Basket TP/SL, Daily MDD liên quan tới stop-all.

Điều này làm khó debug, khó đọc flow và khó xác định “risk đang được quản lý ở đâu”.  
Thiết kế mới **gộp Execution + Risk Management vào một Layer duy nhất**:

- **Layer 0 – Risk Gate (`risk_gate.mqh`)**: Gate điều kiện hệ thống theo trạng thái rủi ro tài khoản (Daily MDD, optional session gate đơn giản) + tính khung `maxLotSize` (lot cap động theo equity) **ở level account**. Risk Gate **không xử lý spread/rollover** và **không tính `maxRiskPips`** nữa.
- **Layer 1 – Methods (`01_LAYER1_DETECTION.md`)**: Detect, tính `entry/sl/tp`, RR, score, tạo `PositionPlan` (DCA/BE/Trail) cho từng setup.
- **Layer 2 – Execution & Position Risk (tài liệu này)**: Thực thi ExecutionOrder, quản lý toàn bộ vòng đời lệnh & position (DCA, BE, Trail, Basket), cập nhật risk thực tế sử dụng.
- **Layer 3 – Analytics**: Chỉ đọc dữ liệu, hiển thị dashboard và thống kê; không ra quyết định trading.

Tư duy mới: **Layer 2 là “trái tim” vận hành lệnh + risk per position**, Layer 0 chỉ định khung, Layer 1 cung cấp kế hoạch, Layer 3 chỉ quan sát.

---

### 🔗 Vị trí trong kiến trúc sau khi gộp

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 0: RISK GATE                                        │
│  ├─ Daily MDD, (optional) session gate đơn giản            │
│  └─ Xuất RiskGateResult (canTrade, maxLotSize, flags MDD)  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: METHODS (Detection)                              │
│  ├─ Scan() từng phương pháp (SMC, ICT, Custom…)           │
│  ├─ Tự tính Entry/SL/TP, RR, score                         │
│  └─ Xuất ExecutionOrder[] + PositionPlan                   │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2: EXECUTION & POSITION RISK (layer mới)            │
│  ├─ Nhận ExecutionOrder[] + PositionPlan + RiskGateResult  │
│  ├─ Phân bổ budget risk/lot cho từng setup                 │
│  ├─ Đặt lệnh (pending/market), TTL, hủy khi hết hạn        │
│  ├─ Track PositionState (per position)                     │
│  │   ├─ DCA add-on                                         │
│  │   ├─ Breakeven (move SL → entry)                        │
│  │   ├─ Trailing stop                                      │
│  │   └─ Basket TP/SL (toàn rổ)                             │
│  └─ Cập nhật risk thực tế để lần check RiskGate tiếp theo  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: ANALYTICS                                        │
│  ├─ Đọc state từ Layer 2                                   │
│  ├─ Vẽ dashboard, objects                                  │
│  └─ Ghi log & thống kê                                     │
└─────────────────────────────────────────────────────────────┘
```

---

### 🧩 Đầu vào của Layer 2 (sau merge)

Layer 2 không tự “nghĩ ra chiến lược”, mà chỉ xử lý và thực thi những gì đã được Layer 0 & Layer 1 phê duyệt:

- **1. ExecutionOrder[] từ Layer 1**
  - Mỗi ExecutionOrder là một **kế hoạch lệnh cụ thể**:
    - Hướng (BUY/SELL), kiểu lệnh (MARKET/LIMIT/STOP).  
    - Entry, SL, TP đã tính sẵn.  
    - Lot đề xuất cho entry chính.  
    - Liên kết tới `PositionPlan` của setup đó.  
    - Thông tin meta: methodName, pattern, score, lý do vào lệnh…
  - Toàn bộ Entry/SL/TP, RR, score đã được method xử lý; Layer 2 **không tính lại**.

- **2. PositionPlan (per setup) từ Layer 1**
  - Mô tả đầy đủ:
    - DCA Plan: số levels, trigger theo R/giá, lot multiplier, entry kiểu gì.  
    - BE Plan: trigger R, move all positions hay từng vị thế, điều kiện bổ sung.  
    - Trail Plan: start R, step R, distance ATR/points, strategy (“lock profit”, “follow structure”…).  

- **3. RiskGateResult từ Layer 0**
  - Cung cấp **khung risk tổng** hiện tại:
    - `canTrade`, `tradingHalted`, `reason`.  
    - `maxRiskPips`, `maxLotSize`.  
    - `remainingRiskPips`, `remainingLotSize` sau khi đã tính toàn bộ positions + pending hiện tại.
  - Layer 2 dùng để **phân bổ budget** cho từng setup, không ghi đè logic của Layer 0.

- **4. Thông tin thị trường hiện tại**
  - Session active nào (FULL DAY / MULTI-WINDOW, Asia/London/NY).  
  - Những thông tin này dùng cho **filter đặt lệnh**, không dùng để tính lại risk%.

---

### 🎯 Nhiệm vụ chính của Layer 2 (sau khi gộp)

#### 1. Phân bổ budget risk/lot cho từng setup

- Với mỗi setup do Layer 1 cung cấp:
  - Tính **tổng risk dự kiến** của setup:  
    - Risk entry chính = lot_main × distance_SL.  
    - Risk DCA tổng = Σ(lot_DCA_level × distance_SL gốc) theo PositionPlan.
  - So sánh với `remainingRiskPips` và `remainingLotSize`:
    - Nếu vượt → scale giảm toàn bộ lot (entry + DCA) theo một tỷ lệ chung, hoặc bỏ setup nếu sau scale lot quá nhỏ.
    - Nếu vừa trong khung → **chốt budget** cho setup đó (risk không được vượt budget này về sau).

Sau bước này, mỗi setup có một **budget risk cố định**; Layer 2 sẽ đảm bảo việc đặt lệnh & DCA của setup đó **không vượt budget**.

#### 2. Thực thi ExecutionOrder (đặt lệnh)

- Điều kiện để đặt lệnh:
  - `RiskGateResult.canTrade = true`.  
  - Setup đã được cấp budget, còn room risk/lot hữu ích sau khi scale.  
  - Session, spread, rollover **đạt yêu cầu** (filter cuối cùng).
- Thực thi:
  - Dùng kiểu entry sẵn có trong ExecutionOrder: LIMIT / STOP / MARKET.  
  - Lot = lot sau khi scale theo budget và giới hạn bởi `remainingLotSize`.  
  - Nếu lot thực tế < minLot của symbol → bỏ lệnh, log lý do.
- Ngay sau khi đặt:
  - Gắn link tới `PositionPlan` và setupID để sau này tái sử dụng khi lệnh khớp.  
  - Thêm lệnh vào danh sách pending với TTL (bars).

Lưu ý: Layer 2 **không** tính lại risk% hay dynamic lot; mọi thứ dựa trên budget đã cấp + constraint min/max lot của symbol.

#### 3. Quản lý pending orders & TTL

- Mỗi pending order được Layer 2 theo dõi:
  - Số bar đã qua kể từ lúc đặt (TTL tính theo bar).  
  - Nếu `barsAge >= TTL` mà chưa khớp → hủy lệnh, log lý do.
- Khi hủy pending:
  - Loại bỏ khỏi danh sách pending của Layer 2.  
  - Giải phóng phần budget đã allocate cho entry đó (và nếu setup không còn lệnh nào active, có thể giải phóng cả phần DCA chưa dùng).

TTL vì thế **chỉ tồn tại trong Layer 2**, không còn logic TTL trùng lặp ở nơi khác.

#### 4. Tạo & quản lý PositionState cho từng vị thế

Khi pending được khớp hoặc market order fill:

- Tạo `PositionState` mới cho ticket đó, gồm tối thiểu:
  - Entry, original SL, TP, original lot, direction.  
  - Tham chiếu tới PositionPlan và setupID.  
  - Cờ trạng thái: đã thêm DCA level 1/2/3 chưa, đã BE chưa, lastTrailR, v.v.
- Mỗi tick hoặc mỗi bar:
  - Tính profit theo **R** cho position (dựa trên original SL).  
  - Dựa trên PositionPlan để:
    - Quyết định có mở thêm DCA hay không.  
    - Quyết định có move SL về BE hay không.  
    - Quyết định có trail SL hay không.

Tất cả DCA/BE/Trail đều được thực hiện **tại Layer 2**, không đẩy xuống thêm một Layer Risk Manager riêng.


### 🧠 Quy tắc phân chia nhiệm vụ – tránh trùng với Layer 0 & 3

- **Layer 0 (Risk Gate)**:
  - Chỉ:
    - Check Daily MDD, Session, Spread, Rollover.  
    - Tính `maxRiskPips`, `maxLotSize`, `remainingRisk/lot`.  
  - Không:
    - Theo dõi từng position.  
    - DCA, BE, Trailing, Basket TP/SL.

- **Layer 2 (Execution & Position Risk)**:
  - Chỉ:
    - Thực thi ExecutionOrders.  
    - Quản lý pending + TTL.  
    - Quản lý toàn bộ vòng đời position (DCA, BE, Trail, Basket).  
    - Cập nhật risk sử dụng thực tế.  
  - Không:
    - Tính lại risk% theo balance/equity (đã thuộc Layer 0).  
    - Tự kích hoạt stop-all theo Daily MDD (cờ này do Layer 0 báo).

- **Layer 3 (Analytics)**:
  - Chỉ đọc dữ liệu từ Layer 2 để hiển thị; không ra bất kỳ quyết định giao dịch nào.

---

### 📈 Tóm tắt flow đầy đủ cho một setup (sau merge)

1. **Layer 0 – Risk Gate**
   - Check Daily MDD, session, spread, rollover.  
   - Tính `maxLotSize`, `maxRiskPips`, `remainingLotSize`, `remainingRiskPips`.  
   - Nếu ok: cho phép Layer 1 scan.

2. **Layer 1 – Detection & Methods**
   - Mỗi method scan thị trường, tạo MethodSignal và PositionPlan.  
   - Arbiter chọn setup tốt nhất và build thành **ExecutionOrder arrays** (có thể nhiều lệnh cho một setup).

3. **Layer 2 – Execution & Position Risk**
   - Nhận ExecutionOrder[] + PositionPlan + RiskGateResult.  
   - Phân bổ budget risk/lot cho setup; scale lot nếu cần, reject nếu không đủ room.  
   - Đặt lệnh LIMIT/STOP/MARKET; gắn PositionPlan, track pending + TTL.  
   - Khi lệnh khớp → tạo PositionState; thực thi DCA/BE/Trail, Basket TP/SL theo plan.  
   - Khi position/pending đóng → cập nhật risk/lot đã dùng, trả lại room cho các setup sau.

4. **Layer 3 – Analytics**
   - Đọc toàn bộ state & history từ Layer 2, hiển thị dashboard & thống kê; **không** can thiệp logic.

Nhờ đó, từng setup đi trọn vòng đời: **được gate bởi Layer 0, được thiết kế chiến lược tại Layer 1, được thực thi & quản lý trọn vẹn tại Layer 2, và được quan sát tại Layer 3**, không còn phần việc trùng lặp giữa Execution và Risk Management.

---

### ✅ Checklist thiết kế cho Layer 2 (phiên bản gộp)

- Không tính lại risk% theo balance/equity – chỉ dùng budget từ Layer 0.  
- Là **nơi duy nhất**:
  - Quản lý pending/TTL.  
  - DCA, BE, Trailing, Basket TP/SL.  
  - Cập nhật risk/lot đang sử dụng thực tế.  
- Không chạy lại Daily MDD – chỉ tôn trọng cờ `tradingHalted` từ Layer 0.  
- Expose đủ dữ liệu cho Layer 3 hiển thị nhưng không để Layer 3 ra quyết định.

---

**File**: `docs/v3/02_LAYER2_EXECUTION.md`  
**Phiên bản**: v3 – Layer 2 gộp Execution + Position Risk  
**Mục đích**: Chuẩn hóa thiết kế Layer 2 tối giản, không trùng nhiệm vụ với Layer 0 & 3, thay thế hoàn toàn Layer Risk Management riêng lẻ trước đây.


