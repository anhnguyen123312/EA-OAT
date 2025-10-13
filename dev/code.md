Dưới đây là **tài liệu thuần kỹ thuật** (spec) đã chuẩn hoá từ file bạn đưa. Mục tiêu: dev mở bằng Cursor có thể **code đúng y nguyên** theo mô tả mà không cần hỏi thêm. Toàn bộ quy tắc và ngưỡng đều được khóa bằng hằng số/config, có pseudocode MQL5, API nội bộ, test/acceptance và checklist. 

# 0) Scope & Kỳ vọng

* **Symbol/TF**: XAUUSD, M15/M30 (mặc định M15).
* **Phương pháp**: SMC/ICT pipeline: Liquidity Sweep → BOS/CHOCH → Pullback về OB/FVG → Trigger (ưu tiên Stop entry).
* **Quản trị rủi ro**: RiskPerTrade cố định, DCA tối đa 2 add-ons, Daily MDD guard.
* **Trading window**: 08:00–23:00 Asia/Ho_Chi_Minh.
* **Output yêu cầu**:

  * Indicator vẽ vùng/box (OB/FVG), marker BOS/Sweep, text trạng thái (Valid/Mitigated/Completed/Expired).
  * EA thực thi theo **arbiter** (bộ ưu tiên tín hiệu), quản lý SL/TP/BE/Trail/DCA.

---

# 1) Quy ước đơn vị (Unit Convention)

> **Mặc định dùng chuẩn trong tài liệu**:
> `1 pip = 10 points`, `1 PRICE_UNIT = 1000 points`. (Có hằng số để chuyển sang 100 points nếu broker khác.)

```cpp
// === Unit constants (switchable) ===
input int   InpPointsPerPip = 10;         // nếu broker cần 100, đổi thành 100
#define PIP(p)           ((p) * InpPointsPerPip * _Point)
#define POINTS(n)        ((n) * _Point)
#define PRICE_UNIT(n)    ((n) * 1000 * _Point)   // theo spec
input int   InpMinStopPts  = 300;         // = 30 pip khi 1 pip = 10 points
```

---

# 2) Cấu hình & Tham số (Inputs)

```cpp
// Session & Market
input string InpTZ              = "Asia/Ho_Chi_Minh";
input int    InpSessStartHour   = 8;    // 08:00 +07
input int    InpSessEndHour     = 23;   // 23:00 +07
input int    InpSpreadMaxPts    = 35;   // points

// Risk & DCA
input double InpRiskPerTradePct = 0.3;  // % equity
input double InpMinRR           = 2.0;
input double InpMaxLotPerSide   = 3.0;
input int    InpMaxDcaAddons    = 2;    // #1 at +0.75R (0.5x), #2 at +1.5R (0.33x)
input double InpDailyMddMax     = 8.0;  // %

/*** Detection thresholds ***/
// BOS
input int    InpFractalK        = 3;
input int    InpLookbackSwing   = 50;   // bars
input int    InpMinBreakPts     = 50;   // points
input int    InpBOS_TTL         = 40;   // bars (M15)
input double InpMinBodyATR      = 0.6;  // body >= 0.6*ATR(14)

// Sweep
input int    InpLookbackLiq     = 30;
input double InpMinWickPct      = 35.0; // %
input int    InpSweep_TTL       = 20;

// OB
input int    InpOB_MaxTouches   = 3;
input int    InpOB_BufferInvPts = 50;   // close beyond -> invalid
input int    InpOB_TTL          = 120;  // bars

// FVG
input int    InpFVG_MinPts      = 150;
input double InpFVG_FillMinPct  = 25.0;
input double InpFVG_MitigatePct = 35.0;
input double InpFVG_CompletePct = 85.0;
input int    InpFVG_BufferInvPt = 50;
input int    InpFVG_TTL         = 60;
input int    InpK_FVG_KeepSide  = 6;

// Momentum (tuỳ chọn)
input double InpMomo_MinDispATR = 0.7;
input int    InpMomo_FailBars   = 4;
input int    InpMomo_TTL        = 20;

// Execution
input int    InpTriggerBodyATR  = 40;  // = 0.40 ATR (x100)
input int    InpEntryBufferPts  = 70;
input int    InpOrder_TTL_Bars  = 5;   // pending timeout
```

---

# 3) Mô hình trạng thái (State Machine)

```
[SCAN] -> (detectors) -> [CANDIDATE SET]
[CANDIDATE SET] --arbiter--> [ENTRY DECISION]
[ENTRY DECISION] --place--> [PENDING ORDERS] --filled--> [POSITION LIVE]
[POSITION LIVE] --manage--> [BE/TRAIL/DCA/EXIT] --exit--> [DONE]
TTL timeouts or invalidation at each state → prune.
```

* **TTL áp cho**: BOS, Sweep, OB, FVG, Momentum và Pending Order (Order_TTL_Bars). Hết TTL hoặc có **invalidation** → xoá.

---

# 4) Detection Library (chuẩn hoá)

## 4.1 BOS/CHOCH

* **BOS lên**: Close hiện tại > swing high gần nhất (FractalK) + `InpMinBreakPts`, và **thân nến** ≥ `InpMinBodyATR*ATR(14)`.
* **BOS xuống**: tương tự cho swing low.
* **TTL**: `InpBOS_TTL` bars. **Gia hạn** nếu có displacement tiếp diễn cùng chiều trong 20 bars.
* **Invalidation**: Có BOS ngược chiều **mạnh hơn** hoặc hết TTL. 

## 4.2 Liquidity Sweep

* **Sweep đỉnh**: H[i] > maxHigh (trong `InpLookbackLiq`), nhưng C[i] ≤ maxHigh **hoặc** wick trên % ≥ `InpMinWickPct`.
* **Sweep đáy**: ngược lại.
* **TTL**: `InpSweep_TTL`. **Invalidation**: có BOS vượt cực trị sweep + `InpOB_BufferInvPts` **hoặc** hết TTL. 

## 4.3 Order Block (OB)

* **Định nghĩa**: Nến **ngược chiều cuối** trước BOS/displacement.

  * OB giảm (supply): nến bullish cuối trước BOS xuống → vùng `[Open, High]`.
  * OB tăng (demand): nến bearish cuối trước BOS lên → vùng `[Low, Close]`.
* **Touches**: đếm số lần chạm. `touches >= 4` → **invalid**.
* **Invalidation**: close vượt mép OB + `InpOB_BufferInvPts`.
* **TTL**: `InpOB_TTL`. 

## 4.4 Fair Value Gap (FVG)

* **Phát hiện** 3 nến:

  * FVG tăng: `Low[i] > High[i+2] + InpFVG_MinPts`.
  * FVG giảm: `High[i] < Low[i+2] - InpFVG_MinPts`.
* **Fill %**:

  * `fill_pct = 100 * (đoạn giá đã đi vào gap / độ rộng gap)`.
  * Trạng thái:

    * `Valid` nếu `fill_pct < MitigatePct`.
    * `Mitigated` nếu `MitigatePct ≤ fill_pct < CompletePct`.
    * `Completed` nếu `fill_pct ≥ CompletePct`.
* **Invalidation**: close vượt mép đối diện + `InpFVG_BufferInvPt` hoặc `Completed`.
* **TTL**: `InpFVG_TTL`. Giữ tối đa `InpK_FVG_KeepSide` mỗi chiều. 

## 4.5 Momentum (tuỳ chọn)

* ≥ 2 nến **cùng màu**, mỗi **body ≥ InpMomo_MinDispATR*ATR(14)**, phá **minor swing** (K=2).
* **Fail** nếu trong `InpMomo_FailBars` không tiếp diễn phá swing tiếp. TTL=`InpMomo_TTL`. 

---

# 5) Arbiter (Ưu tiên & Xung đột)

Áp trọng số theo pipeline:

1. **BOS + Sweep + (OB|FVG) cùng hướng** → ưu tiên cao nhất.
2. **FVG Completed nhưng OB còn valid** → ưu tiên OB (giảm weight FVG).
3. **Momentum ngược SMC** → bỏ Momentum.
4. **OB touched ≥ InpOB_MaxTouches** → giảm khối lượng 50% hoặc bỏ; **FVG Mitigated** → chỉ Limit tại mép nông.
5. **Spread > InpSpreadMaxPts** hoặc **ngoài phiên** → không vào. 

Triển khai dạng **score**:

```cpp
double ScoreCandidate(const Candidate& c) {
  double s = 0.0;
  if(c.hasBOS && c.hasSweep && (c.hasOB || c.hasFVG)) s += 100.0;
  if(c.hasFVG && c.fvgState==Completed && c.hasOB)   s -= 20.0; // đẩy ưu tiên về OB
  if(c.hasMomo && c.momoAgainstSmc)                  return 0.0;
  if(c.obTouches >= InpOB_MaxTouches)                s *= 0.5;
  if(c.fvgState==Mitigated)                          s -= 10.0;
  if(!SessionOpen() || !SpreadOK())                  return 0.0;
  return s;
}
```

---

# 6) Thực thi lệnh (Execution)

## 6.1 Trigger Candle

* **Điều kiện trigger**: body ≥ `InpTriggerBodyATR/100 * ATR(14)` (mặc định 0.4 ATR).
* **Stop entry (ưu tiên)**:

  * SELL: `SellStop = Low(trigger) - InpEntryBufferPts`.
  * BUY:  `BuyStop  = High(trigger) + InpEntryBufferPts`.
* **Limit entry (tuỳ chọn)**:

  * Tại **OB open** (sell) hoặc **mép dưới FVG** (buy).
  * **Huỷ** nếu giá vượt 50% FVG ngược. 

## 6.2 SL/TP

* **SL** = cực trị (sweep hoặc mép OB) ± buffer, bảo đảm **≥ InpMinStopPts**; nếu không đạt **RR** tối thiểu → **bỏ lệnh**.
* **TP**:

  * `TP1`: đối diện liquidity gần nhất.
  * `TP2`: theo `InpMinRR` (2.0–3.0) **hoặc** POI tiếp theo.
  * **BE** tại +1R; **trail** theo swing M5/M15. 

## 6.3 Sizing & DCA

* `lots = CalcLotsByRisk(InpRiskPerTradePct, |SL-Entry|)`.
* **DCA**:

  * Add-on #1 khi **floating ≥ +0.75R**, size = 0.5× lệnh gốc.
  * Add-on #2 khi **floating ≥ +1.5R**, size = 0.33×.
  * Không vượt `InpMaxLotPerSide`.
* **Daily guard**: nếu lỗ ngày ≥ `InpDailyMddMax`% → **đóng tất cả** & **ngừng**. 

---

# 7) Pseudocode (Engine Loop)

```text
OnTick():
  if !SessionOpen() || !SpreadOK() || ReachedDailyMDD(): return
  UpdateSeries() // iOpen/High/Low/Close, ATR

  bosDir = DetectBOS(InpFractalK, InpLookbackSwing, InpMinBodyATR, InpMinBreakPts, InpBOS_TTL)
  sweep  = DetectSweep(InpLookbackLiq, InpMinWickPct, InpSweep_TTL)
  ob     = FindOB(bosDir, InpOB_TTL, InpOB_BufferInvPts, InpOB_MaxTouches)
  fvg    = FindFVG(bosDir, InpFVG_MinPts, InpFVG_TTL, InpFVG_BufferInvPt, InpFVG_FillMinPct, InpFVG_MitigatePct, InpFVG_CompletePct, InpK_FVG_KeepSide)
  momo   = DetectMomentum(InpMomo_MinDispATR, InpMomo_FailBars, InpMomo_TTL) // optional

  candidates = BuildCandidates(bosDir, sweep, ob, fvg, momo)
  best = ArgMax(candidates, ScoreCandidate)

  if best.valid and best.score >= 100:
     trig = GetTriggerCandle(bosDir, InpTriggerBodyATR/100.0)
     if trig:
       entry = (bosDir<0) ? trig.low  - POINTS(InpEntryBufferPts)
                          : trig.high + POINTS(InpEntryBufferPts)
       sl = AdjustSL(best, entry, InpMinStopPts)
       rr = CalcRR(entry, sl, best, InpMinRR)
       if rr >= InpMinRR: PlaceStopOrder(bosDir, entry, sl, TargetTP(entry, sl, best))
       SetOrderTTL(InpOrder_TTL_Bars)

  ManageOpenPositions() // BE@+1R, Trail, DCA at +0.75R & +1.5R, DailyMDD guard
  GarbageCollectByTTLAndInvalidation()
```

> Mọi chi tiết trên khớp với logic trong tài liệu gốc (BOS/CHOCH, Sweep, OB, FVG, Momentum; TTL/Invalidation; ưu tiên; entry/SL/TP/DCA). 

---

# 8) API nội bộ (Headers .mqh)

## 8.1 detectors.mqh

```cpp
struct Swing { int index; double price; };
int   DetectBOS(int K, int lookback, double minBodyATR, int minBreakPts, int ttlBars); // return dir {-1,0,1}
bool  DetectSweep(int lookback, double minWickPct, int ttlBars, /*out*/double& liqLevel, /*out*/int side);
bool  FindLastOB(int dir, /*out*/double& p1, /*out*/double& p2, /*out*/int touches);
bool  FindBestFVG(int dir, /*out*/double& a, /*out*/double& b, /*out*/int state /*0=valid,1=mitigated,2=completed*/);
bool  DetectMomentum(double minDispATR, int failBars, int ttlBars, /*out*/int dir);
```

## 8.2 arbiter.mqh

```cpp
struct Candidate { bool hasBOS, hasSweep, hasOB, hasFVG, hasMomo, momoAgainstSmc; int obTouches; int fvgState; int dir; };
double ScoreCandidate(const Candidate& c);
Candidate BuildBestCandidate(...);
```

## 8.3 executor.mqh

```cpp
bool   SessionOpen();
bool   SpreadOK();
double CalcLotsByRisk(double riskPct, double slPoints);
bool   PlaceStopOrder(int dir, double entry, double sl, double tp);
double TargetTP(double entry, double sl, const Candidate& c); // combine LiquidityOpposite & RR
void   ManageOpenPositions(); // BE, trail, DCA, daily MDD
void   SetOrderTTL(int bars);
void   GarbageCollectByTTLAndInvalidation();
```

## 8.4 draw_debug.mqh

```cpp
void DrawOB(double p1, double p2, color c, const string tag);
void DrawFVG(double a, double b, color c, const string tag, int state);
void MarkBOS(int barIndex, int dir);
void MarkSweep(double level, int side);
void LabelState(const string text);
```

---

# 9) Logging & JSON Schemas

* **Trade log** và **Trade spec** JSON theo schema (copy-ready) — sử dụng khi backtest/triage:

```json
// trade_spec.schema.json (rút gọn)
{
  "symbol": "XAUUSD",
  "timeframe": "M15",
  "timezone": "Asia/Ho_Chi_Minh",
  "order_type": "Stop",
  "risk_per_trade": 0.3,
  "min_rr": 2.5,
  "buffer_points": 70,
  "min_stop_points": 300,
  "max_dca_addons": 2,
  "daily_mdd_max": 0.08,
  "session_hours": ["08:00","23:00"]
}
```

```json
// trade_log.schema.json (rút gọn)
{
  "timestamp": "2025-10-14T10:00:00+07:00",
  "timezone": "Asia/Ho_Chi_Minh",
  "session": "Asia",
  "method": "BOS",
  "order_type": "Stop",
  "prices": {"entry": 2005.00, "sl": 1990.00, "tp": 2035.00},
  "risk": {"R": 1.0, "%Equity": 0.3},
  "rationale": "Pullback sau BOS lên chạm FVG valid",
  "evidence": ["https://tradingview.com/chart/...","ICT-2020"]
}
```

> Schema này khớp với phần ví dụ & định nghĩa trong tài liệu gốc. 

---

# 10) Acceptance Tests (tối thiểu)

1. **BOS Detect**: cho dữ liệu có thân nến = `0.7*ATR(14)` vượt swing `InpMinBreakPts` → `dir=±1`, TTL=`InpBOS_TTL`.
2. **Sweep**: nến có wick trên 40% vượt maxHigh nhưng đóng ≤ maxHigh → đánh dấu sweep đỉnh, TTL=`InpSweep_TTL`.
3. **FVG State**: gap 200 pts; khi fill 30% → state=Mitigated; khi 90% → Completed & invalid.
4. **OB Invalidation**: close vượt mép OB + 50 pts → OB invalid; touches≥4 → invalid.
5. **Entry Calc**: trigger body 0.45*ATR; BuyStop = High(trigger)+70 pts; SL ≥ 300 pts; RR≥2.0 mới đặt lệnh; TTL pending = 5 bars.
6. **DCA**: +0.8R → add #1 (0.5x) nếu tổng lot side < `InpMaxLotPerSide`; +1.6R → add #2 (0.33x).
7. **Daily MDD**: lỗ ngày ≥ 8% → đóng toàn bộ & ngừng giao dịch.
8. **Filters**: Spread > 35 pts **hoặc** ngoài 08:00–23:00 → không vào lệnh.

---

# 11) Folder Structure (Cursor Project)

```
/src
  /include
    detectors.mqh
    arbiter.mqh
    executor.mqh
    draw_debug.mqh
  SMC_ICT_EA.mq5
  SMC_ICT_INDICATOR.mq5
/tests
  data_feed_samples.csv
  acceptance_runner.mq5
/docs
  SPEC.md   // chính là tài liệu này
  CHANGELOG.md
```

---

# 12) Ghi chú triển khai & Edge cases

* **Slippage/Gaps**: giới hạn `MaxSlippage = 30 pts`, bỏ lệnh nếu vượt.
* **Volatility spike**: nếu `ATR(14) > 2 × SMA(ATR,50)` → giảm risk 50%.
* **Rollover**: không đặt pending ±5 phút quanh 00:00 server.
* **Netting/Hedging**: nếu `ACCOUNT_MARGIN_MODE` là netting → hợp nhất vị thế & chuyển add-on thành tăng khối lượng cùng chiều.
* **Symbol suffix/digits**: luôn dùng `_Symbol`, `NormalizeDouble` theo `_Digits`. 

---

# 13) Mẫu code then chốt (compile-ready snippets)

```cpp
bool SessionOpen() {
  datetime t = TimeCurrent(); MqlDateTime s; TimeToStruct(t, s);
  int hour = (s.hour + 7) % 24;  // GMT+7 offset (server time → local window)
  return (hour >= InpSessStartHour && hour < InpSessEndHour);
}

bool SpreadOK() {
  long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
  return (sp <= InpSpreadMaxPts);
}

double CalcLotsByRisk(double riskPct, double slPoints) {
  double bal = AccountInfoDouble(ACCOUNT_EQUITY);
  double riskValue = bal * (riskPct/100.0);
  double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
  double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
  double valuePerPointPerLot = tickValue * (POINTS(1) / tickSize);
  double lots = riskValue / (slPoints * valuePerPointPerLot);
  return NormalizeDouble(MathMax(0.01, lots), 2);
}
```

```cpp
bool PlaceStopOrder(int dir, double entry, double sl, double tp) {
  MqlTradeRequest r; ZeroMemory(r);
  r.action = TRADE_ACTION_PENDING; r.symbol = _Symbol; r.deviation = 20;
  r.type   = (dir < 0) ? ORDER_TYPE_SELL_STOP : ORDER_TYPE_BUY_STOP;
  r.price  = NormalizeDouble(entry, _Digits);
  r.sl     = NormalizeDouble(sl, _Digits);
  r.tp     = NormalizeDouble(tp, _Digits);
  r.volume = CalcLotsByRisk(InpRiskPerTradePct, MathAbs(sl - entry)/_Point);
  MqlTradeResult res; return OrderSend(r, res);
}
```

---

# 14) Checklist cho Dev (Cursor)

* [ ] Tạo module `detectors.mqh` theo chữ ký ở §8.1, pass các Acceptance Tests §10.
* [ ] Vẽ OB/FVG/BOS/Sweep bằng `draw_debug.mqh` với tag duy nhất/TTL.
* [ ] Arbiter score đúng quy tắc §5; bỏ Momentum khi nghịch hướng SMC.
* [ ] Entry **Stop** mặc định, **Limit** chỉ dùng khi cấu hình bật & thoả điều kiện FVG/OB.
* [ ] SL luôn ≥ `InpMinStopPts`; bỏ lệnh nếu `RR < InpMinRR`.
* [ ] Quản trị DCA đúng ngưỡng +0.75R / +1.5R, không vượt `InpMaxLotPerSide`.
* [ ] Daily MDD guard chủ động đóng & chặn lệnh mới.
* [ ] Tất cả tham số/đơn vị dùng **points**; macro `PIP()`/`POINTS()` để tránh nhầm.
* [ ] Log JSON theo schema §9 khi fill/close.

---

# 15) Lưu ý về mâu thuẫn đơn vị (nếu gặp broker khác)

* Spec này **khóa** theo chuẩn `1 pip = 10 points`. Nếu broker dùng `1 pip = 100 points`, **chỉ cần đổi** `InpPointsPerPip = 100` **không đổi code khác**. (Đã trừu tượng hoá qua macro). 

---

Nếu bạn muốn, mình có thể tách sẵn bộ file `.mqh/.mq5` theo khung ở §11 để bạn import thẳng vào Cursor.
