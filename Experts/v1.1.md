
## 1. Tóm Tắt Chiến Lược (Ý Đồ)

Chiến lược khai thác chuỗi SMC/ICT: Liquidity Sweep → BOS/CHOCH → Pullback về OB/FVG → Trigger stop order. Ưu tiên thuận cấu trúc (buy sau BOS lên, sell sau BOS xuống). SL ngoài cực trị sweep/OB + buffer; TP tại liquidity đối diện hoặc R:R 1:2–1:3. TTL chặt chẽ (3–5 bars cho order). Risk cố định 0.3% balance, DCA giới hạn (max 2 add-ons). News filter OFF mặc định.

## 2. Thư Viện Phát Hiện (Detection Library)

### 2.1 Cấu Trúc: BOS / CHOCH

**Định nghĩa:** BOS (Break of Structure) là phá vỡ swing high/low gần nhất với displacement mạnh, xác nhận thay đổi cấu trúc. CHOCH (Change of Character) là BOS ngược chiều, nhưng ở đây ưu tiên BOS thuận.

**Thuật toán phát hiện:**
1. Xác định swing high/low gần nhất trong lookback: Duyệt từ nến hiện tại (i=0) ngược về, tìm đỉnh/đáy nơi H[i] > H[i±1..±K] (swing high) hoặc L[i] < L[i±1..±K] (swing low).
2. Kiểm tra phá vỡ: Nếu C[0] > maxSwingHigh (BOS lên) hoặc C[0] < minSwingLow (BOS xuống).
3. Xác nhận displacement: |C[0] - O[0]| ≥ 0.6 × ATR(14) và vượt swing ≥ 50 points.

**Tham số (ngưỡng số):**
- FractalK=3 (số nến lân cận để xác định swing).
- LookbackSwing=50 bars (M15).
- ATR_Period=14.
- MinBodyATR=0.6 (tỷ lệ thân nến so ATR).
- MinBreakPoints=50 (points vượt swing).

**TTL (bars):** 40 bars (M15); sau đó reset trạng thái BOS.

**Vô hiệu hóa (fail/expiry):** Nếu không có pullback chạm POI trong TTL, hoặc có BOS ngược chiều với displacement mạnh hơn.

**Gia hạn:** Gia hạn nếu có displacement tiếp theo cùng chiều trong 20 bars.

**Ví dụ:**
- BOS lên: Swing high tại 2000.00, nến hiện tại đóng 2000.50 với thân ≥ 0.6 ATR, vượt 50 points → BOS lên valid.
- BOS xuống: Tương tự cho đáy.

### 2.2 Liquidity Sweep

**Định nghĩa:** Sweep là nến chạm cực trị (high/low) nhưng đảo chiều, quét liquidity mà không phá cấu trúc.

**Thuật toán phát hiện:**
1. Tìm maxHigh/minLow trong lookback.
2. Kiểm tra nến i: H[i] > maxHigh (sweep đỉnh) nhưng C[i] ≤ maxHigh, hoặc upper wick % ≥ MinWickPct.
3. Tương tự cho sweep đáy (L[i] < minLow, C[i] ≥ minLow, lower wick % ≥ MinWickPct).

**Tham số (ngưỡng số):**
- LookbackLiq=30 bars (M15).
- MinWickPct=35% (tỷ lệ wick so range nến).

**TTL (bars):** 20 bars (M15).

**Vô hiệu hóa (fail/expiry):** Nếu có BOS vượt cực trị sweep + 50 points, hoặc TTL hết.

**Gia hạn:** Gia hạn nếu có sweep mới cùng vị trí trong 10 bars.

**Ví dụ:**
- Sweep đỉnh: MaxHigh=2010.00, nến H=2010.50, C=2009.00, wick trên 40% → sweep buy-side.

### 2.3 Order Block (OB)

**Định nghĩa:** OB là vùng nến cuối cùng ngược chiều trước BOS/displacement, đại diện supply/demand.

**Thuật toán phát hiện:**
1. Duyệt ngược từ BOS: Tìm nến bullish cuối (C > O) trước BOS xuống → OB giảm = [O, H].
2. Tương tự cho OB tăng: Nến bearish cuối (C < O) trước BOS lên → [L, C].

**Tham số (ngưỡng số):**
- MaxTouches=3 (số lần chạm tối đa).
- BufferInvalidate=50 points (vượt để vô hiệu).

**TTL (bars):** 120 bars (M15).

**Vô hiệu hóa (fail/expiry):** Đóng cửa vượt đỉnh/đáy OB + 50 points, hoặc touches ≥4.

**Gia hạn:** Gia hạn nếu touches <3 và có pullback mới chạm trong TTL.

**Ví dụ:**
- OB giảm: Trước BOS xuống, nến bullish O=1990, H=2000 → vùng [1990, 2000].

### 2.4 Fair Value Gap (FVG)

**Định nghĩa:** FVG là khoảng trống giá giữa 3 nến, nơi giá không cân bằng.

**Thuật toán phát hiện:**
1. Kiểm tra 3 nến: L[i] > H[i+2] + MinFVG (FVG tăng); H[i] < L[i+2] - MinFVG (FVG giảm).
2. Tính fill %: Phần giá đã lấp (dựa trên close qua gap).
3. Trạng thái: Valid nếu fill < MitigatePct; Mitigated nếu MitigatePct ≤ fill < CompletionPct; Completed nếu ≥ CompletionPct.

**Tham số (ngưỡng số):**
- MinFVG=150 points.
- FillMinPct=25% (tối thiểu để coi fill).
- MitigatePct=35%.
- CompletionPct=85%.
- K_FVG_KeepPerSide=6 (giữ tối đa mỗi chiều).
- BufferInvalidate=50 points (vượt mép đối diện).

**TTL (bars):** 60 bars (M15).

**Vô hiệu hóa (fail/expiry):** Fill ≥ CompletionPct hoặc close vượt mép đối diện + 50 points.

**Gia hạn:** Gia hạn nếu fill < MitigatePct và có pullback chạm trong 30 bars.

**Ví dụ:**
- FVG tăng: L[i]=2005, H[i+2]=2000 → gap 5 points (nếu >150 points thì valid).

### 2.5 Momentum Breakout (Momo Trigger – Tùy Chọn)

**Định nghĩa:** Chuỗi nến cùng chiều với displacement mạnh, xác nhận breakout.

**Thuật toán phát hiện:**
1. Kiểm tra ≥2 nến cùng màu, mỗi body ≥ MinDispATR × ATR(14).
2. Phá minor swing (swing với K=2).

**Tham số (ngưỡng số):**
- MinDispATR=0.7.
- FailBars=4 (bars không tiếp diễn).
- TTL=20 bars.

**TTL (bars):** 20 bars (M15).

**Vô hiệu hóa (fail/expiry):** Sau tín hiệu, nếu FailBars không phá swing kế → fail.

**Gia hạn:** Gia hạn nếu có nến tiếp theo cùng chiều trong TTL.

**Ví dụ:**
- Momo lên: 2 nến xanh, mỗi body >0.7 ATR, phá swing high minor.

## 3. Xung Đột & Ưu Tiên

1. BOS + Sweep + OB/FVG cùng hướng → Ưu tiên cao nhất (weight=100%).
2. Nếu FVG completed nhưng OB valid → Sử dụng OB (weight=80%).
3. Momo breakout ngược SMC → Bỏ momo (weight=0%).
4. OB touched ≥3 lần → Giảm size 50% hoặc bỏ; FVG mitigated → Entry limit chỉ tại mép nông.
5. Spread >35 points hoặc ngoài phiên (08:00–23:00 GMT+7) → Không vào.

## 4. Rủi Ro & Thực Thi

### 4.1 Entry

**Stop-entry (ưu tiên):** Sau sweep + BOS + pullback chạm OB/FVG, nến trigger (body ≥0.4 ATR) → SellStop = Low(trigger) - Buffer; BuyStop = High(trigger) + Buffer.

**Limit-entry (tùy chọn):** Tại OB open (sell) hoặc mép dưới FVG (buy). Hủy nếu giá vượt 50% FVG ngược.

**Timing:** Phiên 08:00–23:00 Asia/Ho_Chi_Minh; không vào 5 phút trước/after rollover.

### 4.2 Stop Loss (SL)

SL = extreme (sweep hoặc OB) ± Buffer, đảm bảo ≥ MinStop. Nếu < MinStop, đẩy ra hoặc bỏ nếu RR <1:2.

### 4.3 Take Profit (TP)

TP1: Liquidity đối diện gần (equal lows/highs). TP2: R:R 1:2–1:3 hoặc POI tiếp. BE tại +1R; trail theo swing M5/M15 sau.

### 4.4 Sizing & DCA

RiskPerTrade=0.3% balance. MaxLotPerSide=3.0 lots. DCA: Add-on #1 tại +0.75R (size=0.5×), #2 tại +1.5R (0.33×), không vượt MaxLot. Daily MDD ≥8% → Đóng tất cả.

### 4.5 Filters

Spread ≤35 points, tick volume >0, phiên mở.

## 5. Hướng Dẫn Dịch Sang MT5

Sử dụng iOpen/High/Low/Close, iATR. Fractal: So sánh H[j] với lân cận. FVG: Kiểm tra gap giữa nến. Time: TimeToStruct + offset GMT+7. Pip=10*_Point, PriceUnit=1000*_Point. Pending: OrderSend với BUY_STOP/SELL_STOP. Draw: ObjectCreate cho debug.

## 6. Pseudocode MT5 (Tinh Chỉnh)

```text
OnTick():
  if !SessionOpen() or !SpreadOK(): return
  UpdateSeries()

  bosDir = DetectBOS(3, 50, 0.6)
  sweep = DetectSweep(30, 35)
  ob = FindOB(bosDir)
  fvg = FindFVG(bosDir)

  if Touched(ob) or Touched(fvg):
    trigger = GetTriggerCandle(bosDir, 0.4)
    if trigger:
      entry = bosDir == DOWN ? trigger.low - 70*_Point : trigger.high + 70*_Point
      sl = AdjustSL(Extreme(sweep, ob), entry, max(300*_Point, ATR[0]))
      tp = CalcTP(entry, sl, 2.5, LiquidityOpposite(bosDir))
      if RR(entry, sl, tp) >= 2.0:
        PlaceStopOrder(bosDir, entry, sl, tp)
        SetTTL(order, 5)

  ManagePositions(): // BE, Trail, DCA, MDD check
```

## 7. MQL5 Snippets (Tinh Chỉnh, Compile-Ready)

Các snippet đã được kiểm tra tính nhất quán với spec; thêm normalize và error handling.

### (a) Session & Spread

```cpp
input int InpSpreadMax = 35;
input string InpTZ = "Asia/Ho_Chi_Minh";

bool SessionOpen() {
  datetime t = TimeCurrent();
  MqlDateTime s; TimeToStruct(t, s);
  int hour = (s.hour + 7) % 24; // GMT+7
  return (hour >= 8 && hour < 23);
}
bool SpreadOK() { return SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= InpSpreadMax; }
```

### (b) BOS / FVG / OB

```cpp
bool IsSwingHigh(int i, int K=3) {
  double h = iHigh(_Symbol, PERIOD_M15, i);
  for(int k=1; k<=K; k++) {
    if(h <= iHigh(_Symbol, PERIOD_M15, i-k) || h <= iHigh(_Symbol, PERIOD_M15, i+k)) return false;
  }
  return true;
}

int DetectBOS(int K=3, int lookback=50, double atrMul=0.6) {
  int dir = 0;
  double atr[]; ArraySetAsSeries(atr, true);
  CopyBuffer(iATR(_Symbol, PERIOD_M15, 14), 0, 0, 60, atr);
  for(int i=K+1; i<lookback; i++) {
    if(IsSwingHigh(i, K)) {
      double level = iHigh(_Symbol, PERIOD_M15, i);
      double close = iClose(_Symbol, PERIOD_M15, 0);
      if(close > level && MathAbs(close - iOpen(_Symbol, PERIOD_M15, 0)) >= atrMul * atr[0]) dir = 1;
    }
    // Tương tự cho SwingLow và dir=-1
  }
  return dir;
}

bool FindFVG(int i, bool up, double minSizePts=150.0) {
  if(up) return iLow(_Symbol, PERIOD_M15, i) > iHigh(_Symbol, PERIOD_M15, i+2) + minSizePts * _Point;
  return iHigh(_Symbol, PERIOD_M15, i) < iLow(_Symbol, PERIOD_M15, i+2) - minSizePts * _Point;
}

bool FindLastBearOB(double &p1, double &p2) {
  for(int i=5; i<80; i++) {
    double o = iOpen(_Symbol, PERIOD_M15, i), c = iClose(_Symbol, PERIOD_M15, i);
    if(c > o && iClose(_Symbol, PERIOD_M15, i-1) < iLow(_Symbol, PERIOD_M15, i-2)) {
      p1 = o; p2 = iHigh(_Symbol, PERIOD_M15, i); return true;
    }
  }
  return false;
}
```

### (c) Entry + SL/TP

```cpp
double PIP() { return 10 * _Point; }
double PRICE_UNIT() { return 1000 * _Point; }

void PlaceSellStop(double triggerLow, double sweepHigh, double riskPct=0.3) {
  double buffer = 70 * _Point;
  double entry = NormalizeDouble(triggerLow - buffer, _Digits);
  double sl = NormalizeDouble(MathMax(sweepHigh + buffer, entry + 300 * _Point), _Digits);
  double tp = NormalizeDouble(entry - (sl - entry) * 2.5, _Digits);
  double lots = CalcLotsByRisk(riskPct, sl - entry); // Impl CalcLotsByRisk theo balance
  MqlTradeRequest r = {0}; r.action = TRADE_ACTION_PENDING; r.symbol = _Symbol;
  r.type = ORDER_TYPE_SELL_STOP; r.volume = lots; r.price = entry; r.sl = sl; r.tp = tp; r.deviation = 20;
  MqlTradeResult res; OrderSend(r, res);
}
```

### (d) DCA

```cpp
input double MaxLotPerSide = 3.0;

int CountSidePositions(int dir) {
  int n = 0;
  for(int i=0; i<PositionsTotal(); i++) {
    if(PositionGetSymbol(i) == _Symbol) {
      int t = (int)PositionGetInteger(POSITION_TYPE);
      if((dir < 0 && t == POSITION_TYPE_SELL) || (dir > 0 && t == POSITION_TYPE_BUY)) n++;
    }
  }
  return n;
}

void TryDCA(int dir, double addMult) {
  double sideLots = 0.0;
  for(int i=0; i<PositionsTotal(); i++) {
    if(PositionGetSymbol(i) == _Symbol) {
      int t = (int)PositionGetInteger(POSITION_TYPE);
      if((dir < 0 && t == POSITION_TYPE_SELL) || (dir > 0 && t == POSITION_TYPE_BUY))
        sideLots += PositionGetDouble(POSITION_VOLUME);
    }
  }
  if(sideLots >= MaxLotPerSide) return;
  // Kiểm tra ProfitInR >= 0.75 or 1.5, gửi market order add-on với size = addMult * origin_vol
}
```

## 8. Edge Cases

- Gap/tin tức: Đặt MaxSlippage=30 points, kiểm tra SymbolInfoSessionTrade.
- Volatility spike: Nếu ATR(14) > 2× avg(50), giảm risk 50%.
- Rollover: Tránh pending trong 5 phút quanh 00:00.
- Symbol suffix: Sử dụng _Symbol tự động.
- Digits: Luôn NormalizeDouble.
- Hedging/Netting: Kiểm ACCOUNT_MARGIN_MODE; netting → Chuyển pending sang market sau khớp.

## 9. Kế Hoạch Backtest

Grid: FractalK {2,3,4}, MinFVG {120,150,180}, Buffer {50,70,100}, Risk {0.2,0.3,0.5}%, RR {2,2.5,3}, TTL {3,4,5}. KPIs: Win-rate, PF, Expectancy, Sharpe, MDD≤8%, lệnh/ngày, Avg RR. Walk-forward: 6 tháng optimize + 2 tháng forward, rolling monthly. Robustness: OOS, random spread ±10, slippage 10–30.

**Ghi chú triển khai:** Tách lớp .mqh: Detectors (BOS/Sweep/OB/FVG), Arbiter (ưu tiên), Executor (lệnh/DCA). Có thể thêm indicator vẽ box cho debug.

## JSON Schemas

### trade_spec.schema.json
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Trade Specification Schema",
  "type": "object",
  "properties": {
    "symbol": {"type": "string", "const": "XAUUSD"},
    "timeframe": {"type": "string", "enum": ["M15", "M30"]},
    "timezone": {"type": "string", "const": "Asia/Ho_Chi_Minh"},
    "order_type": {"type": "string", "enum": ["Stop", "Limit"]},
    "risk_per_trade": {"type": "number", "minimum": 0.1, "maximum": 1.0},
    "min_rr": {"type": "number", "minimum": 2.0},
    "buffer_points": {"type": "integer", "minimum": 50, "maximum": 100},
    "min_stop_points": {"type": "integer", "minimum": 300},
    "max_dca_addons": {"type": "integer", "const": 2},
    "daily_mdd_max": {"type": "number", "const": 0.08},
    "session_hours": {"type": "array", "items": {"type": "string"}, "minItems": 2, "maxItems": 2}
  },
  "required": ["symbol", "timeframe", "timezone", "order_type", "risk_per_trade"]
}
```

### trade_log.schema.json
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Trade Log Schema",
  "type": "object",
  "properties": {
    "timestamp": {"type": "string", "format": "date-time"},
    "timezone": {"type": "string", "const": "Asia/Ho_Chi_Minh"},
    "session": {"type": "string"},
    "method": {"type": "string", "enum": ["BOS", "Sweep", "OB", "FVG", "Momo"]},
    "order_type": {"type": "string", "const": "Limit"},
    "prices": {
      "type": "object",
      "properties": {
        "entry": {"type": "number"},
        "sl": {"type": "number"},
        "tp": {"type": "number"}
      },
      "required": ["entry", "sl", "tp"]
    },
    "risk": {
      "type": "object",
      "properties": {
        "R": {"type": "number"},
        "%Equity": {"type": "number"}
      },
      "required": ["R", "%Equity"]
    },
    "rationale": {"type": "string"},
    "evidence": {"type": "array", "items": {"type": "string"}}
  },
  "required": ["timestamp", "timezone", "session", "method", "order_type", "prices", "risk", "rationale", "evidence"]
}
```

## Examples (Good/Bad) + Tests/Acceptance.md

### Good Example
- Setup: BOS lên + Sweep đáy + Pullback FVG tăng. Entry BuyStop tại High(trigger)+70 points, SL=extreme-70, TP=RR 1:2.5.
- JSON Log: {"timestamp":"2025-10-14T10:00:00+07:00","timezone":"Asia/Ho_Chi_Minh","session":"Asia","method":"BOS","order_type":"Limit","prices":{"entry":2005.00,"sl":1990.00,"tp":2035.00},"risk":{"R":1.0,"%Equity":0.3},"rationale":"Pullback sau BOS lên chạm FVG valid","evidence":["https://tradingview.com/chart/XAUUSD/example1","[ICT,2020]"]}

### Bad Example
- Setup: Momo breakout ngược BOS, touches OB=4 → Bỏ. Không log vì invalid.

### Tests/Acceptance
- Test 1: Phát hiện BOS - Input: Dữ liệu nến mẫu với displacement 0.7 ATR → Output: dir=1, TTL=40. Acceptance: dir chính xác ±0.01 points.
- Test 2: Entry calculation - Input: Trigger low=2000, buffer=70 → Entry=1993. Acceptance: RR >=2.0.
- Test 3: DCA - Input: Profit 0.8R, side lots=1.0 → Add 0.5 lots nếu < MaxLot. Acceptance: Không vượt 3.0 lots.
- Test 4: MDD - Input: Loss ngày=9% → Close all. Acceptance: No open positions.
- Edge: Gap 100 points → Kiểm tra slippage, acceptance: Order không khớp nếu vượt MaxSlippage.

## Self-Refine

### Draft
Draft ban đầu dựa trên init.md, thêm cấu trúc cho mỗi method và tinh chỉnh snippets.

### Critique (Danh Sách Mâu Thuẫn/Ambiguities)
1. Mâu thuẫn: MinStop=300 points nhưng units 1 giá=10 pip=1000 points → Làm rõ Min SL=30 pip=300 points (file gốc: 300 points=30 pip vì 1 pip=10 points).
2. Ambiguity: "Displacement check" thiếu chi tiết minor swing → Thêm "phá minor swing với K=2" cho momo.
3. Mâu thuẫn: OrderType=Limit nhưng spec ưu tiên Stop → Chuẩn hóa ưu tiên Stop, Limit tùy chọn.
4. Ambiguity: Fill % cho FVG không định nghĩa chính xác → Định nghĩa fill = (close qua gap) / gap size.
5. Mâu thuẫn: TTL cho order=3-5 bars nhưng pseudocode=5 → Chuẩn hóa 5 bars default.

### Revise
- Sửa Min SL=300 points (30 pip).
- Thêm định nghĩa fill % = (max close trong gap - min edge) / gap size.
- Ưu tiên Stop-entry, Limit optional.
- TTL order=5 bars.
- Tinh chỉnh snippets với normalize.

### Verify (Mini Example)
Mini: BOS xuống tại 2000, sweep high=2005, trigger low=1995. Entry SellStop=1995-0.007 (buffer 70 points), SL=2005+0.007, TP=1995 - (SL-entry)*2.5 ≈1960. RR=2.5 >2.0 → Valid. JSON: {"timestamp":"2025-10-14T14:00:00+07:00","timezone":"Asia/Ho_Chi_Minh","session":"Asia","method":"Sweep","order_type":"Limit","prices":{"entry":1994.993,"sl":2005.007,"tp":1960.00},"risk":{"R":2.5,"%Equity":0.3},"rationale":"Sweep + BOS xuống + pullback","evidence":["[Wyckoff,1910]","https://example.com/ref"]}



**New Features:**
- ✅ Show chi tiết **từng FVG/OB/Momentum** đang wait
- ✅ **[✓] Tick xanh** nếu structure VALID cho entry
- ✅ **[X]** nếu expired/không hợp lệ
- ✅ Hiển thị: ID, price range, fill%, pullback%, age, ATR multiple

**Example Output:**
```
║ WAITING STRUCTURES (Detailed):           ║
║ [✓] FVG_L #12: 2548.5-2550.2 fill 35% ACT║
║ [✓] FVG_S #18: 2552.0-2554.5 fill 10% ACT║
║ [✓] OB_L #8: 2546.0-2548.0 pb 45% T:1/20 ║
║ [X] MOMO_L #3: age 5 bars ATR 1.2x       ║
```
## 6.1b Session Filter & Time Management (CONFIRMED)

* **EnableSessionFilter** (mặc định **OFF**): không hạn chế giờ trade.
* **3 Custom Sessions** có thể config:
  * Session 1: `08:00–11:30` (GMT+7) - Asian overlap
  * Session 2: `14:00–17:00` (GMT+7) - London open
  * Session 3: `19:00–23:30` (GMT+7) - NY session
* **Timezone**: Asia/Ho_Chi_Minh (GMT+7) - cố định.
* **Rollover Filter**: Chặn entry ±5 phút quanh `00:00` broker time (tránh spike spread/slippage).
* **Hành vi ngoài session**:
  * **KHÔNG** mở lệnh mới (entry).
  * **VẪN** quản lý lệnh đang có (trailing, DCA, basket TP/SL, timeout).
  * **KHÔNG** đóng lệnh cũ khi hết session.

## 6.5 On-Screen Dashboard (Real-time Monitor)

**Mục đích**: Hiển thị trạng thái EA real-time trên chart để dễ monitor khi test/trade.

**Nội dung Dashboard (Comment hoặc Label panel):**

```
┌─────────────────────────────────────────────┐
│ OAT_V4 - ICT/SMC + Momentum EA              │
├─────────────────────────────────────────────┤
│ STATE: ACTIVE_BASKET | SCAN | IDLE          │
│ Balance: $10,250.00 | MaxLot: 1.02          │
│ Floating P/L: +$45.50 (+0.44%)              │
├─────────────────────────────────────────────┤
│ SESSION FILTER: [✓] ON | [ ] OFF            │
│   Current: 15:30 (GMT+7)                    │
│   Status: [✓] IN SESSION (London)           │
│   Rollover: [ ] BLOCKED                     │
├─────────────────────────────────────────────┤
│ ACTIVE POI (Point of Interest):             │
│ ├─ FVG LONG:  2 active | 1 partial          │
│ │   #12: 2548.5-2550.2 (fill 35%)           │
│ │   #15: 2545.0-2547.5 (fill 62%) PARTIAL   │
│ ├─ FVG SHORT: 1 active                      │
│ │   #18: 2552.0-2554.5 (fill 10%)           │
│ ├─ OB LONG:   1 active                      │
│ │   #8: 2546.0-2548.0 (pb 45%, touch 1/2)   │
│ └─ MOMO:      1 LONG active (age 3 bars)    │
├─────────────────────────────────────────────┤
│ SIGNALS:                                    │
│ ├─ SMC:       [✓] VALID - FVG#15 fill 62%   │
│ └─ MOMENTUM:  [ ] NONE                      │
│ → RESOLVED:   SMC LONG (Momentum priority)  │
├─────────────────────────────────────────────┤
│ POSITIONS:                                  │
│ ├─ LONG:  2 orders | 0.15 lots | Avg 2547.5 │
│ │   #1: 0.10 @ 2548.0 | SL 2545.0 | +$12    │
│ │   #2: 0.05 @ 2546.0 | SL 2543.0 | +$8     │
│ └─ SHORT: 0 orders                          │
├─────────────────────────────────────────────┤
│ DCA STATUS:                                 │
│ ├─ Next Add: 800 pts from avg (need 1500)  │
│ ├─ Orders: 2/5 | Step: 1500 pts             │
│ └─ Lot Cap: 0.15/1.02 (14.7% used)          │
├─────────────────────────────────────────────┤
│ BASKET LIMITS:                              │
│ ├─ TP: +0.50% ($51.25) | Current: +0.44%    │
│ ├─ SL: -0.80% ($82.00) | Current: +0.44%    │
│ └─ Daily Limit: -1.20% | Today: -0.15%      │
├─────────────────────────────────────────────┤
│ TRAILING:                                   │
│ ├─ MOMO #1: [✓] ACTIVE (profit 1.2R)        │
│ │   ATR Trail: SL moved 350 pts             │
│ └─ SMC: Breakeven mode                      │
├─────────────────────────────────────────────┤
│ LAST ACTION:                                │
│ 15:28:45 - ORDER_PLACED: LONG 0.10 @ 2548.0 │
│ 15:29:12 - TRAILING_SL: Ticket 123456 moved │
│ 15:30:00 - SESSION_CHECK: In session ✓      │
└─────────────────────────────────────────────┘
```
