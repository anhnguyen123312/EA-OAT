# Crowconcept V2.0 (SMC/ICT) — **Spec để Dev có thể code MT5 (M15/M30, XAUUSD)**

> **Giả định mặc định (có thể chỉnh):**
>
> * Symbol: `XAUUSD` (spot).
> * TF: M15/M30 (tối ưu M15 cho trigger, M30 cho bối cảnh).
> * **Quy đổi:** `1 pip = 10 points`, `1 “giá” = 10 pip = 1000 points`.
> * Spread trung bình ≤ **35 points** (3.5 pip).
> * TZ phiên: **Asia/Ho_Chi_Minh (GMT+7)**.
> * News filter: **OFF**.

---

## 1) Summary (ý đồ chiến lược)

* **Khai thác SMC/ICT:** chuỗi **Liquidity Sweep → BOS/CHOCH → Pullback về OB/FVG → Stop order trigger**.
* **Ưu tiên thuận cấu trúc:** chỉ Sell sau **BOS xuống**, Buy sau **BOS lên**.
* **SL** luôn đặt **ngoài cực trị đã bị sweep/OB** + buffer; **TP** chốt tại liquidity đối diện / R:R 1:2–1:3.
* **TTL** chặt: hủy nếu không khớp sau 3–5 nến M15 hoặc POI bị vô hiệu.
* **Risk** cố định theo % balance, có **DCA** giới hạn theo side.

---

## 2) Detection Library (Formal Rules)

> Ký hiệu:
>
> * `H[i], L[i], O[i], C[i]`: High/Low/Open/Close của nến `i` (i=0 là nến hiện tại, 1 là nến trước…).
> * `ATR(n)`: Average True Range. Mặc định `n=14` (M15).
> * **Buffer** = `50–100 points` (5–10 pip), mặc định **70 points**.
> * **MinStop** = `max(300 points, 1.0 × ATR(14))`.

### 2.1 Structure: **BOS / CHOCH**

* **Inputs:** `FractalK=3`, `LookbackSwing=50 bars`.
* **BOS lên:** khi `C[0]` **đóng cửa** > `maxSwingHigh`, trong đó `maxSwingHigh` là đỉnh swing gần nhất (đỉnh có `H[j]` > `H[j±1…j±K]`).
* **BOS xuống:** tương tự với đáy swing.
* **Displacement check (xác nhận lực):** thân nến phá vỡ phải thỏa:
  `abs(C[0]-O[0]) ≥ 0.6 × ATR(14)` **và** đóng cửa vượt swing ≥ `50 points`.
* **TTL cho trạng thái BOS:** 40 bars (M15) – hết TTL coi như **reset**.

### 2.2 **Liquidity Sweep**

* **Inputs:** `LookbackLiq=30 bars`, `MinWickPct=35%`.
* **Sweep đỉnh (buy-side):** có nến với `H[i]` **vượt** `maxHigh(30)` nhưng **đóng cửa** `C[i]` **≤** `maxHigh(30)` **hoặc** thân nhỏ/đuôi dài:
  `UpperWickPct = (H[i]-max(C[i],O[i]))/(H[i]-L[i]) ≥ MinWickPct`.
* **Sweep đáy** ngược lại.
* **TTL sweep:** 20 bars. Dùng làm **extreme** để đặt SL.

### 2.3 **Order Block (OB)**

* **OB giảm:** **bullish candle cuối cùng** ngay trước **BOS xuống** mà sau đó giá tạo **displacement giảm**.

  * Vùng OB = `[Open(bullish), High(bullish)]`.
* **OB tăng:** ngược lại.
* **Touch count:** tối đa **3 lần** chạm; lần thứ 4 coi **suy yếu**.
* **TTL OB:** 120 bars (M15).
* **Invalidate:** có **đóng cửa** vượt hẳn đỉnh/đáy OB **+ 50 points**.

### 2.4 **Fair Value Gap (FVG)**

* **Định nghĩa (3 nến):**

  * **FVG tăng:** `L[i] > H[i+2] + MinFVG` **và** `C[i+1]` nằm giữa không fill.
  * **FVG giảm:** `H[i] < L[i+2] - MinFVG`.
* **Inputs:** `MinFVG=150 points`, `FillMinPct=25%`, `MitigatePct=35%`, `CompletionPct=85%`.
* **Trạng thái:**

  * **Valid:** fill < `MitigatePct`.
  * **Mitigated:** `MitigatePct ≤ fill < CompletionPct`.
  * **Completed (vô hiệu):** `fill ≥ CompletionPct` **hoặc** có **close** vượt mép đối diện `> 50 points`.
* **TTL FVG:** 60 bars.
* **Giữ tối đa** `K_FVG_KeepPerSide=6` mỗi chiều.

### 2.5 **Momentum Breakout (momo trigger – tùy chọn)**

* **Inputs:** `MinDispATR=0.7`, `FailBars=4`, `TTL=20`.
* **Tín hiệu:** chuỗi ≥2 nến cùng màu, mỗi nến có `body ≥ MinDispATR × ATR(14)` và phá minor swing.
* **Fail:** sau tín hiệu, nếu `FailBars` không tiếp diễn phá swing kế tiếp → bỏ.

---

## 3) Conflicts & Priority (độ ưu tiên khi xung đột)

1. **BOS + Sweep + OB/FVG cùng hướng** → **Ưu tiên cao nhất**.
2. Nếu **FVG completed** nhưng OB còn valid → dùng **OB**.
3. Nếu có **momo breakout** ngược hướng với SMC (BOS/sweep) → **bỏ momo**, giữ SMC.
4. Nếu **OB touched ≥3 lần** → giảm size 50% hoặc bỏ; **FVG mitigated** chỉ còn entry limit nông.
5. **Spread > SpreadMax** hoặc **ngoài phiên** → **không vào**.

---

## 4) Risk & Execution

### 4.1 Entry

* **Stop-entry (khuyến nghị, giống ảnh):**

  * **Sell:** sau **sweep đỉnh + BOS xuống + pullback** chạm **OB/FVG giảm**, xuất hiện **nến kích hoạt giảm** ⇒ đặt **SellStop = Low(trigger) − Buffer**.
  * **Buy:** tương tự, **BuyStop = High(trigger) + Buffer**.
* **Limit-entry (tùy chọn):** tại **OB open** (sell) / **mép dưới FVG** (buy). **Hủy** nếu giá đi quá **50% FVG** ngược hướng.

### 4.2 Stop Loss (SL)

* **Mặc định:**
  `SL = extreme(sweep hoặc OB) ± Buffer` **và** `SLDistance ≥ MinStop`.
* Nếu `SLDistance < MinStop` → đẩy SL ra để đạt `MinStop` **hoặc** bỏ lệnh nếu RR < `MinRR`.

### 4.3 Take Profit (TP)

* **TP1:** liquidity đối diện gần nhất (equal lows/highs hoặc swing gần).
* **TP2:** R:R mục tiêu **1:2 ~ 1:3** hoặc POI tiếp theo.
* **BE/Trail:** khi đạt **+1R** → dời **SL→BE**; sau đó trail theo **last swing M5/M15**.

### 4.4 Sizing & DCA

* **RiskPerTrade:** mặc định **0.30%** balance.
* **MaxLotPerSide:** giới hạn tuyệt đối theo side (ví dụ 3.0 lots).
* **DCA (tùy chọn, max 2 add-ons):**

  * Add-on #1 khi giá đi **+0.75R**, size = **0.5×** lệnh gốc, SL chung giữ theo rule trail.
  * Add-on #2 khi **+1.5R**, size = **0.33×**, **không vượt MaxLotPerSide**.
* **Daily Max DD:** đóng tất cả & ngừng giao dịch khi **MDD ngày ≥ 8%**.

### 4.5 Filters

* **Spread ≤ 35 points**, **tick volume > 0**, **không giao dịch 5 phút trước/after rollover**; Phiên mặc định **08:00–23:00 GMT+7** (có thể chỉnh).

---

## 5) MT5 Translation Guide

* **Series/Indicator:**

  * Nến: `iOpen/High/Low/Close(_Symbol, PERIOD_M15, shift)` hoặc `CopyRates`.
  * ATR: `iATR(_Symbol, PERIOD_M15, 14)`.
* **Fractal swing:** so sánh `H[j]` với `H[j±1..±K]` (K=3).
* **FVG:** kiểm tra khoảng trống giữa `H[i]` và `L[i+2]` (giảm) / `L[i]` và `H[i+2]` (tăng).
* **Time/Session:** dùng `TimeToStruct(TimeCurrent())` + TZ offset **Asia/Ho_Chi_Minh**.
* **Pip/Point:**

  * `double PIP = 10* _Point;`
  * `double PRICE_UNIT = 1000 * _Point;`
* **Pending orders:** `OrderSend()` (hedging) với `ORDER_TYPE_BUY_STOP/SELL_STOP`.
* **Object draw (debug):** `ObjectCreate`/`ObjectSet` cho box/line.

---

## 6) MT5 Pseudocode (flow tổng quát)

```text
OnTick():
  if !SessionOpen() or Spread() > InpSpreadMax: return
  UpdateSeries()

  // 1) Cấu trúc
  bosDir = DetectBOS(fractalK, lookbackSwing, atrMinBody)

  // 2) Liquidity sweep gần nhất
  sweep = DetectSweep(lookbackLiq, minWickPct)

  // 3) Xác định POI
  ob = FindOB(bosDir)
  fvg = FindFVG(bosDir)

  // 4) Xác nhận pullback chạm POI
  if Touched(ob) or Touched(fvg):
      trigger = TriggerCandle(bosDir) // nến đảo chiều tại POI + body >= 0.4*ATR

      if trigger.exists:
          // 5) Tính entry/SL/TP
          entry = (bosDir==DOWN) ? trigger.low - Buffer : trigger.high + Buffer
          slExtreme = ExtremeForSL(sweep, ob, bosDir)
          sl = AdjustMinStop(slExtreme, entry, MinStop)
          rrOK = (RR(entry,sl,TP_by_liquidity(bosDir)) >= MinRR)

          if rrOK:
             PlaceStopOrder(bosDir, entry, sl, tp1, tp2)
             StartTTL(order, bars=5)

  // 6) Quản trị lệnh
  For each open position:
     if ProfitInR(pos) >= 1.0 and !pos.movedBE: MoveSLtoBE(pos)
     if ProfitInR(pos) >= 0.75 and DCAcount(side)<1: AddOn(pos, 0.5*vol)
     if ProfitInR(pos) >= 1.5 and DCAcount(side)<2: AddOn(pos, 0.33*vol)
     if DailyMDD() >= 0.08: CloseAllAndHalt()
```

---

## 7) **MQL5 Snippets** (tối giản, có thể compile)

### (a) **Session & Spread guard**

```cpp
input int    InpSpreadMax = 35; // points
input string InpTZ         = "Asia/Ho_Chi_Minh"; // chỉ dùng label

bool SessionOpen()
{
   // phiên 08:00–23:00 GMT+7
   datetime t = TimeCurrent();
   MqlDateTime s; TimeToStruct(t,s);
   int hour = (s.hour + 7 + 24) % 24; // offset thô
   return (hour>=8 && hour<23);
}
bool SpreadOK(){ return ( (SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)) <= InpSpreadMax ); }
```

### (b) **Skeleton BOS / CHOCH / FVG / OB**

```cpp
bool IsSwingHigh(int i,int K=3){
   double h = iHigh(_Symbol,PERIOD_M15,i);
   for(int k=1;k<=K;k++) if(h<=iHigh(_Symbol,PERIOD_M15,i-k) || h<=iHigh(_Symbol,PERIOD_M15,i+k)) return false;
   return true;
}

int DetectBOS(int K=3,int lookback=50,double atrMul=0.6)
{
   int dir=0; // 1 up, -1 down
   double atr[]; ArraySetAsSeries(atr,true);
   int h=iATR(_Symbol,PERIOD_M15,14); CopyBuffer(h,0,0,60,atr);
   // lấy swing gần
   int sh = iBarShift(_Symbol,PERIOD_M15,TimeCurrent())+1;
   for(int i=K+1;i<lookback;i++){
      if(IsSwingHigh(i,K)){
        double level=iHigh(_Symbol,PERIOD_M15,i);
        if(iClose(_Symbol,PERIOD_M15,0) > level && MathAbs(iClose(_Symbol,PERIOD_M15,0)-iOpen(_Symbol,PERIOD_M15,0)) >= atrMul*atr[0])
           dir= 1;
      }
      if(IsSwingLow(i,K)){
        double level=iLow(_Symbol,PERIOD_M15,i);
        if(iClose(_Symbol,PERIOD_M15,0) < level && MathAbs(iClose(_Symbol,PERIOD_M15,0)-iOpen(_Symbol,PERIOD_M15,0)) >= atrMul*atr[0])
           dir=-1;
      }
   }
   return dir;
}

bool FindFVG(int i, bool up, double minSizePts=150.0)
{
   double H0=iHigh(_Symbol,PERIOD_M15,i);
   double L2=iLow (_Symbol,PERIOD_M15,i+2);
   double L0=iLow (_Symbol,PERIOD_M15,i);
   double H2=iHigh(_Symbol,PERIOD_M15,i+2);
   if(up)   return (L0 > H2 + minSizePts*_Point);
   else     return (H0 < L2 - minSizePts*_Point);
}

// OB: trả về vùng [price1, price2] đơn giản
bool FindLastBearOB(double &p1,double &p2)
{
   for(int i=5;i<80;i++){
     double o=iOpen(_Symbol,PERIOD_M15,i), c=iClose(_Symbol,PERIOD_M15,i);
     if(c>o){ // bullish candle trước cú rơi mạnh
        if(iClose(_Symbol,PERIOD_M15,i-1) < iLow(_Symbol,PERIOD_M15,i-2)){ // heuristic displacement
           p1=o; p2=iHigh(_Symbol,PERIOD_M15,i); return true;
        }
     }
   }
   return false;
}
```

### (c) **Entry + SL/TP placement**

```cpp
double PIP() { return 10*_Point; }
double PRICE_UNIT(){ return 1000*_Point; }

void PlaceSellStop(double triggerLow,double sweepHigh,double riskPct=0.30)
{
   double buffer = 70*_Point;
   double entry  = triggerLow - buffer;
   double sl     = MathMax(sweepHigh + buffer, entry + 300*_Point); // MinStop 300 pts
   double rr_tp  = entry - (sl - entry)*2.5; // TP ~ RR 1:2.5

   double lots = CalcLotsByRisk(riskPct, sl-entry); // tự viết theo balance & tickvalue
   MqlTradeRequest r={0}; MqlTradeResult res;
   r.action=TRADE_ACTION_PENDING; r.symbol=_Symbol;
   r.type=ORDER_TYPE_SELL_STOP;  r.volume=lots;
   r.price=NormalizeDouble(entry,_Digits);
   r.sl   =NormalizeDouble(sl,_Digits);
   r.tp   =NormalizeDouble(rr_tp,_Digits);
   r.deviation=20;
   OrderSend(r,res);
}
```

### (d) **DCA add logic với giới hạn**

```cpp
input double MaxLotPerSide = 3.0;

int CountSidePositions(int dir){
   int n=0;
   for(int i=0;i<PositionsTotal();i++){
     ulong ticket=PositionGetTicket(i);
     if(PositionGetSymbol(i)==_Symbol){
        int t=(int)PositionGetInteger(POSITION_TYPE);
        if( (dir<0 && t==POSITION_TYPE_SELL) || (dir>0 && t==POSITION_TYPE_BUY) ) n++;
     }
   }
   return n;
}

void TryDCA(int dir, double addMult)
{
   // dir: -1 sell, +1 buy
   double sideLots=0.0;
   for(int i=0;i<PositionsTotal();i++){
      if(PositionGetSymbol(i)==_Symbol){
        int t=(int)PositionGetInteger(POSITION_TYPE);
        if( (dir<0 && t==POSITION_TYPE_SELL) || (dir>0 && t==POSITION_TYPE_BUY) )
           sideLots += PositionGetDouble(POSITION_VOLUME);
      }
   }
   if(sideLots >= MaxLotPerSide) return;

   // điều kiện R đã đạt 0.75R hay 1.5R => tự tính từ Entry/SL hiện tại
   // nếu đạt, gửi lệnh market add-on với khối lượng = addMult * lot gốc, nhưng không vượt MaxLotPerSide.
}
```

---

## 8) Edge Cases cần xử lý

* **Gap mở cửa** hoặc **tin tức** khiến **entry khớp nhưng trượt SL/TP**: thêm `MaxSlippage` & kiểm tra `SymbolInfoSessionTrade`.
* **Volatility spike**: nếu `ATR(14)` tăng > **2× trung bình 50 phiên** → giảm risk 50% hoặc tắt entry mới.
* **Missing ticks/Weekend rollover**: tránh đặt pending trong **5 phút** quanh 00:00 server.
* **Suffix symbol** (ví dụ `XAUUSD.a`): lấy `_Symbol` tự động, không hard-code.
* **Digits thay đổi**: luôn `NormalizeDouble(price, _Digits)`.
* **Hedging/Netting**: kiểm `ACCOUNT_MARGIN_MODE`; với netting, chuyển sang **pending→market** sau khớp.

---

## 9) Backtest Plan

* **Grid tham số:**

  * `FractalK ∈ {2,3,4}`, `ATR_14`, `MinDispATR ∈ {0.6,0.7,0.8}`
  * `MinFVG ∈ {120,150,180} points`, `MitigatePct ∈ {30,35,40}`, `CompletionPct ∈ {80,85,90}`
  * `Buffer ∈ {50,70,100} points`, `MinStop ∈ {300,400} points`
  * `RiskPerTrade ∈ {0.2%,0.3%,0.5%}`, `RR target ∈ {1:2,1:2.5,1:3}`
  * `TTL ∈ {3,4,5} bars`
* **KPIs:** Win-rate, Profit Factor, Expectancy, Sharpe, **MDD/ngày ≤ 8%**, số lệnh/ngày, Avg RR.
* **Walk-forward:** 3 đoạn (6 tháng/đoạn) → optimize → forward 2 tháng; rolling update mỗi tháng.
* **Robustness:** Out-of-sample, randomize spread ±10 points, add slippage 10–30 points.

---

### Ghi chú triển khai

* Bắt đầu bằng **detector độc lập** (BOS, Sweep, OB, FVG) trả về cấu trúc dữ liệu đơn giản (giá trị, TTL, touches).
* Cấp **Arbiter** gom tín hiệu theo **Priority ở mục 3** để tạo `TradePlan`.
* **Executor** chịu trách nhiệm gửi lệnh, TTL order, quản trị DCA/BE/Trail, guard theo **Risk & Filters**.

> Cần mình xuất thêm **file .mqh** tách lớp (detectors/arbiter/executor) hoặc viết **indicator vẽ box/label** để debug không? Tôi có thể tạo khung mã hoàn chỉnh dựa trên spec này.
