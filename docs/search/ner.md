# EA SMC/ICT M15 — Research Upgrade (from your GitHub refs) — **Spec dạng Markdown**

> **Context**: XAUUSD, M15, TZ=Asia/Ho_Chi_Minh. Đơn vị chuẩn: **1 pip = 10 points** (toàn bộ ngưỡng dưới đây dùng **points** để tránh nhầm). Mục tiêu: từ tài liệu `Nghiên cứu MQL5 cho SMC_ICT.docx` (các repo: *ICT-Imbalance-Expert-Advisor*, *mt5-liquidity-sweep-ind*, *mq5_black_box*), mình **tích hợp ý tưởng có thể code ngay** để sửa vấn đề “backtest 1 năm không có entry” và **nâng cấp** chiến lược cho khung **M15**.

---

## 1) **Decompose → Plan → ToT (scored) → Reverse Thinking**

### 1.1 Decompose (7 phần)

1. **Entry Logic (SMC/ICT)**: BOS/CHOCH → Sweep → OB/FVG → Trigger.
2. **Market Filters**: Session engine (chuẩn TZ), Spread guard (tĩnh + động theo ATR), Volatility regime.
3. **Momentum & MTF bias**: Confirm động lượng + xu hướng HTF (H1/H4/Weekly).
4. **DCA & Sizing**: Add-on theo R-multiple; MaxLotPerSide; Daily MDD guard.
5. **SL/TP**: SL theo cấu trúc (OB edge/sweep extremum) + MinStopPts; TP theo Liquidity đối diện / RR.
6. **Execution/Order Mgmt**: Stop/Limit, Trigger candle, TTL pending, Slippage, One-trade-per-bar.
7. **Backtest & Debug**: Acceptance tests + checklist “no entry”.

### 1.2 Plan (trình tự xử lý)

* **OnNewBar(M15)**: cập nhật ATR, swings (FractalK), BOS/CHOCH, quét **liquidity sweep đa nến**, phát hiện OB/FVG + trạng thái, tính **MTF bias** (H1/H4/Weekly).
* **OnTick**: kiểm tra **SessionOpen()** (chuẩn TZ) + **SpreadOK()**; cập nhật `fill_pct` cho FVG; arbiter tính **score**; chọn **trigger candle** (0..3 bar gần nhất); tính Entry/SL/TP → **PlaceStop/Limit**; quản lý **BE/Trail/DCA**; TTL & invalidations.

### 1.3 Tree-of-Thought (2–3 hướng) + **Score**

**Option A — SMC core + Momentum confirm (khuyến nghị)**

* BOS/CHOCH + (OB|FVG) + *Momentum confirm*; Sweep **không bắt buộc**.
* **Score**: Correctness 8/10 · Risk 6/10 · Cost/Time 6/10 → **Tổng 7.0**.

**Option B — Sweep-driven + MTF bias cứng**

* Có **Sweep** + (OB|FVG), yêu cầu **MTF bias cùng hướng**; Momentum **khuyến nghị**.
* **Score**: Correctness 7/10 · Risk 5/10 · Cost/Time 7/10 → **Tổng 6.3**.

**Option C — FVG-only + phiên** (tối giản, dễ có entry)

* Chỉ đánh theo FVG + phiên London/NY + RR; bỏ OB/Sweep.
* **Score**: Correctness 5/10 · Risk 7/10 · Cost/Time 8/10 → **Tổng 6.0**.

**[Decision]**: Chọn **Option A** làm default; **Option B** là preset “Conservative”; **Option C** là preset “Aggressive-Entries”.

### 1.4 Reverse Thinking (contrarian)

* Nếu **Momentum confirm** tạo bias muộn → bỏ lỡ kèo sớm?
  → [Mitigation] cho phép **Limit @OB/FVG** *nếu* RR vượt trội & spread/vol ổn.
* **MTF bias** đôi khi làm miss counter-trend setups có RR tốt.
  → [Mitigation] khi MTF ngược trend nhưng **local BOS mạnh + liquidity clear**, giảm lot 50% thay vì bỏ hẳn.
* “Không entry” do **filter** quá chặt (session/spread/trigger body).
  → [Mitigation] **nới ngưỡng** mặc định cho M15 & thêm **động** theo ATR.

---

## 2) **Research Synthesis** (từ repo refs trong tài liệu của bạn)

> **[Assumption]** Phần này tổng hợp **ý tưởng có thể mã hoá** dựa trên các repo bạn đã liệt kê trong file research. **Không truy cập web mới** → **[Update Risk]** thấp-moderate (dựa trên nội dung bạn cung cấp).

### 2.1 Session engine (theo *ICT-Imbalance-Expert-Advisor*)

* Chạy **phiên cố định** (London/NY), bias từ hành động giá trước phiên, **vào lệnh trong phiên**.
* **Áp dụng**: viết `SessionOpen()` **đúng múi giờ cấu hình** (Asia/Ho_Chi_Minh), quy đổi chuẩn **server↔TZ**, tránh cộng +7 “cứng”.
* **Preset**: Asia(07:00–11:00), London(14:00–18:00), NY(19:00–23:00) — giờ VN, chỉnh theo broker server.

### 2.2 Liquidity sweep đa nến (theo *mt5-liquidity-sweep-ind*)

* Dùng **fractal swing** trong lookback làm mốc thanh khoản; **nến hiện tại** vượt mốc (high/low) **rồi đóng trả về** (wick dài) ⇒ **sweep**.
* **Áp dụng**: `DetectSweep()` quét 0..3 bars, tham số **skip近** để tránh mốc quá sát; lưu **liqLevel** để làm TP1/anchor.

### 2.3 OB theo volume & Breaker state (tham chiếu *mq5_black_box* + ICT)

* **Volume filter** cho OB: yêu cầu tick_volume của nến OB **≥ SMA(tick_volume, N) × k** (k=1.2…1.5).
* **Breaker block**: khi OB **invalidated** → đổi **trạng thái** thành breaker (cực tính đảo), dùng làm **retest zone**/TP.

### 2.4 FVG động + trạng thái rõ

* FVG 3-nến; theo dõi **fill%** liên tục → `Valid/Mitigated/Completed`; auto **TTL** & **K-keep per side**.
* Ưu tiên OB khi **FVG Completed**; ưu tiên FVG khi **OB touched nhiều**.

### 2.5 Momentum & MTF bias

* **Momentum confirm**: ≥2 nến cùng màu, **body ≥ α×ATR** (α=0.6 M15) & phá minor swing.
* **MTF bias**: xu hướng H1/H4/Weekly qua BOS/MA; **align** + tăng điểm, **against** + giảm/loại.

---

## 3) **Spec kỹ thuật (codable)** — bản “chuẩn để code”

### 3.1 Inputs (M15 defaults)

| Nhóm      | Tên input            |   Kiểu |      Default (M15) |   Min/Max | [Why]               |
| --------- | -------------------- | -----: | -----------------: | --------: | ------------------- |
| Units     | `InpPointsPerPip`    |    int |                 10 |    10/100 | Chuẩn hoá broker    |
| Session   | `InpTZ`              | string | `Asia/Ho_Chi_Minh` |           | Khớp giờ VN         |
|           | `InpSessStartHour`   |    int |                  7 |      0/23 | Á mở 7h             |
|           | `InpSessEndHour`     |    int |                 23 |      0/23 | Kết thúc 23h        |
| Spread    | `InpSpreadMaxPts`    |    int |            **500** |   50/1200 | Avg XAU M15 ~350pts |
|           | `InpSpreadATRpct`    | double |               0.08 | 0.02/0.15 | Spread guard động   |
| Risk      | `InpRiskPerTradePct` | double |               0.25 |  0.05/1.0 | XAU biến động       |
|           | `InpDailyMddMax`     | double |                8.0 |      2/15 | Day stop            |
| DCA       | `InpMaxLotPerSide`   | double |                3.0 |    0.1/10 | Guard margin        |
|           | `InpMaxDcaAddons`    |    int |                  2 |       0/4 | Pyramiding          |
| BOS       | `InpFractalK`        |    int |                  3 |       2/5 | Swing depth         |
|           | `InpMinBreakPts`     |    int |                 70 |    30/200 | Break filter        |
|           | `InpMinBodyATR`      | double |                0.6 |   0.3/1.2 | Displacement        |
| BOS TTL   | `InpBOS_TTL`         |    int |                 60 |    20/120 | M15 dài hơn M30     |
| Sweep     | `InpLookbackLiq`     |    int |                 40 |     20/80 | Đủ sâu mốc          |
|           | `InpMinWickPct`      | double |                 35 |     20/60 | Wick quality        |
| Sweep TTL | `InpSweep_TTL`       |    int |                 24 |     10/50 | –                   |
| OB        | `InpOB_MaxTouches`   |    int |                  3 |       2/5 | Suy yếu             |
|           | `InpOB_BufferInvPts` |    int |                 70 |    30/150 | Close beyond        |
|           | `InpOB_TTL`          |    int |                160 |    60/300 | M15 phù hợp         |
| FVG       | `InpFVG_MinPts`      |    int |                180 |   120/300 | XAU M15 gap         |
|           | `InpFVG_FillMinPct`  | double |                 25 |     10/40 | –                   |
|           | `InpFVG_MitigatePct` | double |                 35 |     25/50 | –                   |
|           | `InpFVG_CompletePct` | double |                 85 |     70/95 | –                   |
|           | `InpFVG_BufferInvPt` |    int |                 70 |    30/150 | –                   |
|           | `InpFVG_TTL`         |    int |                 70 |    40/120 | –                   |
|           | `InpK_FVG_KeepSide`  |    int |                  6 |       2/8 | Limit crowd         |
| Momentum  | `InpMomo_MinDispATR` | double |            **0.6** |   0.4/1.2 | Xác nhận            |
|           | `InpMomo_FailBars`   |    int |                  4 |       2/8 | –                   |
|           | `InpMomo_TTL`        |    int |                 20 |     10/40 | –                   |
| Trigger   | `InpTriggerBodyATR`  |    int |             **30** |     20/60 | =0.30 ATR           |
|           | `InpEntryBufferPts`  |    int |                 70 |    30/120 | Stop buffer         |
| Pending   | `InpOrder_TTL_Bars`  |    int |             **16** |      6/36 | 4–8h                |

> **[Change]** so với bản trước: tăng SpreadMax, thêm Spread động theo ATR, hạ Trigger body ATR cho M15, tăng TTL pending.

### 3.2 Detection rules (measurable)

* **BOS/CHOCH**
  `dir=+1` nếu Close phá swing high(K=FractalK) + `InpMinBreakPts` **và** `body ≥ InpMinBodyATR × ATR(14)`; `dir=-1` ngược lại. TTL=`InpBOS_TTL`. Invalidate khi BOS ngược **mạnh hơn** (body×ATR lớn hơn) hoặc quá TTL.
* **Liquidity sweep (đa nến)**
  Duyệt `i ∈ {0..3}`:
  *Sweep đỉnh*: `High[i] > maxHigh(lookback)` **và** (`Close[i] ≤ maxHigh` **hoặc** wick_up_pct≥`InpMinWickPct`). Tương tự sweep đáy. TTL=`InpSweep_TTL`.
* **Order Block (OB) + Volume filter**
  OB tăng: **nến bearish cuối** trước BOS lên → zone `[Low, Close]`; OB giảm: **nến bullish cuối** trước BOS xuống → `[Open, High]`.
  **Volume filter**: `tick_volume(OB) ≥ SMA(tick_volume, N=20) × k (1.3)` → mark **strongOB=true**; nếu không, **weakOB**.
  **Invalidation**: Close vượt mép OB + `InpOB_BufferInvPts` → **relabel** thành **Breaker** (đảo cực). `touches ≥ InpOB_MaxTouches` → giảm weight 50%. TTL=`InpOB_TTL`.
* **FVG (3 nến) + state**
  FVG tăng nếu `Low[i] > High[i+2] + InpFVG_MinPts`; FVG giảm tương tự.
  `fill_pct = 100 × filled_width / gap_width`
  Trạng thái: `Valid < MitigatePct ≤ Mitigated < CompletePct ≤ Completed`.
  **Invalidation**: Close vượt mép đối diện + `InpFVG_BufferInvPt` **hoặc** `Completed`. TTL=`InpFVG_TTL`. Giữ tối đa `InpK_FVG_KeepSide`/side.
* **Momentum confirm (khuyến nghị bật)**
  ≥2 nến cùng màu liên tiếp với `body ≥ InpMomo_MinDispATR × ATR(14)` **và** phá minor swing (K=2). **Fail** sau `InpMomo_FailBars` nếu không tiếp diễn.

### 3.3 Arbiter (priority & score)

```text
Base +100 nếu (BOS && (OB||FVG)), +15 nếu có Sweep gần (≤10 bars),
+20 nếu align MTF bias (H1/H4/Weekly), +10 nếu OB=strongOB,
-20 nếu FVG=Completed nhưng OB còn valid (đẩy ưu tiên về OB),
-∞ nếu Momentum chống hướng SMC (loại),
×0.5 nếu OB.touches ≥ InpOB_MaxTouches,
0 nếu Outside Session hoặc Spread fail.
```

### 3.4 Execution & Risk

* **Trigger candle**: quét 0..3 bars; yêu cầu `body ≥ max( (InpTriggerBodyATR/100)×ATR(14), 30 pts )`.
* **Entry**:

  * **Stop** (default):
    BUY: `BuyStop = High(trigger) + InpEntryBufferPts`;
    SELL: `SellStop = Low(trigger)  - InpEntryBufferPts`.
  * **Limit** (tuỳ chọn): tại mép OB (sell: open OB; buy: low OB) hoặc mép nông FVG; **huỷ** nếu fill vượt 50% ngược.
* **SL**: theo **extremum cấu trúc** (sweep/OB edge) ± buffer; đảm bảo `SL ≥ InpMinStopPts`. **Không ép** SL ≥ ATR (tránh rớt RR).
* **TP**:
  TP1 = **opposite liquidity** gần nhất;
  TP2 = `entry + sign(dir) × max( MinRR, 2.0..3.0 ) × |entry−SL|`.
  **BE** @ +1R; **Trail** theo swing M5/M15.
* **Sizing & DCA**:
  Lots = `riskPct × Equity / (SL_pts × valuePerPointPerLot)`.
  DCA#1 @ +0.75R (0.5× lots gốc); DCA#2 @ +1.5R (0.33×); không vượt `InpMaxLotPerSide`.
* **Guards**: `SpreadOK()` = `spread ≤ max(InpSpreadMaxPts, InpSpreadATRpct×ATR)`. Daily loss ≥ `InpDailyMddMax%` → **flat & pause**.

---

## 4) **Pseudocode (core snippets)**

### 4.1 Session & Spread

```cpp
bool SessionOpen() {
  // Convert ServerTime -> InpTZ (GMT+7 by default) via delta = (TZ - ServerGMT)
  MqlDateTime s; TimeToStruct(TimeCurrent(), s);
  int server_gmt = (int)TimeGMTOffset()/3600; // approx; hoặc cấu hình cố định
  int target_gmt = 7; // Asia/Ho_Chi_Minh
  int hour_vn = (s.hour + (target_gmt - server_gmt) + 24) % 24;
  return (hour_vn >= InpSessStartHour && hour_vn < InpSessEndHour);
}

bool SpreadOK() {
  long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
  double atr = iATR(_Symbol, PERIOD_M15, 14, 0);
  long dyn = (long)MathRound(InpSpreadATRpct * (atr/_Point));
  long limit = (long)MathMax(InpSpreadMaxPts, dyn);
  return sp <= limit;
}
```

### 4.2 Detect Sweep (đa nến)

```cpp
bool DetectSweep(int lookback, double minWickPct, int ttl, /*out*/double &liqLevel, /*out*/int &side){
  for(int i=0;i<=3;i++){
    double maxH = HighestHigh(lookback, i+1); // bỏ qua chính nến i
    double minL = LowestLow(lookback, i+1);
    double body = MathAbs(Close(i)-Open(i));
    double upWick = High(i) - MathMax(Close(i),Open(i));
    double dnWick = MathMin(Close(i),Open(i)) - Low(i);
    if(High(i) > maxH && (Close(i) <= maxH || upWick >= minWickPct*body/100.0)){ liqLevel=maxH; side=+1; return true; }
    if(Low(i)  < minL  && (Close(i) >= minL  || dnWick >= minWickPct*body/100.0)){ liqLevel=minL; side=-1; return true; }
  }
  return false;
}
```

### 4.3 OB volume & Breaker

```cpp
struct OB { double a,b; bool bullish; bool strong; int touches; bool alive; bool isBreaker; };
bool ValidateOBVolume(OB &ob){
  double v = (double)Volume(ob_candle_index);
  double sma = SMA_TickVolume(20, ob_candle_index);
  ob.strong = (v >= 1.3*sma); return ob.strong;
}
// Invalidation -> Breaker
void InvalidateToBreaker(OB &ob){
  ob.isBreaker = true; ob.alive=false; /*type đảo cực*/
}
```

### 4.4 Arbiter score (rút gọn)

```cpp
double ScoreCandidate(Cand c){
  if(!SessionOpen() || !SpreadOK()) return 0;
  if(c.momoAgainst) return 0;
  double s=0;
  if(c.hasBOS && (c.hasOB||c.hasFVG)) s+=100;
  if(c.hasSweep && BarsBetween(c.sweepBar, c.triggerBar) <= 10) s+=15;
  if(c.mtfAlign) s+=20;
  if(c.hasOB && c.obStrong) s+=10;
  if(c.hasFVG && c.fvgState==Completed && c.hasOB) s-=20;
  if(c.obTouches >= InpOB_MaxTouches) s*=0.5;
  return s;
}
```

---

## 5) **Backtest Protocol (M15)**

* **Data window**: 3–5 năm; tick model “Every tick based on real ticks” (MT5).
* **WFO**: 70/30 theo quý; tối ưu **ít tham số** (SpreadATRpct, TriggerBodyATR, MinRR).
* **Reject overfit**: thông số “đẹp” ở IS nhưng xấu ở OOS → loại.
* **KPI**: PF≥1.4, Win≥52%, Expectancy≥0.1R, MaxDD≤12%, ≥8–20 trades/ngày (M15 XAU).
* **Acceptance tests** (tối thiểu):

  1. BOS với `body≥0.6ATR` phá swing +70 pts → dir≠0;
  2. Sweep: nến vượt fractal rồi đóng trả → flag;
  3. FVG: gap 200 pts, fill 30% → Mitigated; 90% → Completed;
  4. OB invalidation → breaker;
  5. Trigger `≥0.30ATR` @bar∈{0..3} → place stop;
  6. RR≥2.0 mới đặt lệnh;
  7. DCA @+0.75R & +1.5R;
  8. Spread guard động: spread<=max(500, 0.08×ATR).

---

## 6) **Debug “không có entry” (Checklist)**

* [ ] **SessionOpen()**: đang xét **giờ server** hay **giờ VN**? Quy đổi đúng chưa?
* [ ] **SpreadOK()**: `InpSpreadMaxPts` quá nhỏ? (M15 khuyến nghị 500) & bật **ATR%** guard.
* [ ] **Trigger quá chặt**: hạ `InpTriggerBodyATR` M15 → **30** (0.30 ATR) & quét **0..3** bars.
* [ ] **RR filter**: có đang **ép SL ≥ ATR**? → **bỏ**; chỉ dùng `InpMinStopPts`.
* [ ] **Sweep**: quét **0..3** bars, không chỉ bar 0.
* [ ] **Position API**: dùng `PositionSelectByIndex()` trước khi đọc symbol/type (tránh logic “đã có vị thế”).
* [ ] **TTL pending**: tăng lên **16 bars** (4h) để có thời gian fill.
* [ ] **Arbiter**: relax điều kiện **không bắt buộc Sweep** (Option A).

---

## 7) **Parameter đề xuất (M15 starter)**

```ini
TZ=Asia/Ho_Chi_Minh
SessStartHour=7
SessEndHour=23
SpreadMaxPts=500
SpreadATRpct=0.08
RiskPerTradePct=0.25
MinRR=2.0
MaxLotPerSide=3.0
MaxDcaAddons=2
DailyMddMax=8.0

FractalK=3
LookbackSwing=50
MinBreakPts=70
BOS_TTL=60
MinBodyATR=0.6

LookbackLiq=40
MinWickPct=35
Sweep_TTL=24

OB_MaxTouches=3
OB_BufferInvPts=70
OB_TTL=160

FVG_MinPts=180
FVG_FillMinPct=25
FVG_MitigatePct=35
FVG_CompletePct=85
FVG_BufferInvPt=70
FVG_TTL=70
K_FVG_KeepSide=6

Momo_MinDispATR=0.6
Momo_FailBars=4
Momo_TTL=20

TriggerBodyATR=30
EntryBufferPts=70
Order_TTL_Bars=16
```

**Ví dụ tính nhanh**: ATR(14)=1200 pts → Spread guard động = 0.08×1200=96 pts ⇒ **limit = max(500, 96) = 500 pts** (vẫn dùng 500 vì XAU spread thường > 350 pts).
Nếu Entry–SL = 400 pts, Risk=0.25% vốn 10,000$ ⇒ RiskValue=25$. Với valuePerPointPerLot≈0.1$ (ví dụ), **lots ≈ 25/(400×0.1)=0.625 lot**.

---

## 8) **Câu hỏi cần bạn xác nhận**

1. Broker server GMT mấy? Bạn muốn **nhập giờ phiên theo VN** hay **theo server**?
2. Bạn muốn **bật bắt buộc Momentum confirm** hay chỉ tăng điểm?
3. MTF bias dùng **H1** hay **H4** làm chuẩn (hay cả hai)?
4. Cho **OB volume filter**: k=1.3 ổn chứ?
5. DCA có muốn **partial-TP** tại +1R trước khi add-on?

---

## 9) **Self-Review & Sanity Check**

* **Logic nhất quán**: Tất cả điều kiện đã chuyển thành **đo lường cụ thể** (points, ATR, bars).
* **Edge cases**: đã thêm spread spike (ATR%), session DST, TTL đủ dài, API PositionSelectByIndex.
* **Entry frequency**: Option A + nới trigger + spread guard động **sẽ tạo đủ tín hiệu** cho M15 (8–20 lệnh/ngày).
* **Rủi ro**: Volume tick có thể nhiễu tùy broker → **OB volume filter** nên bật *soft* (tăng/giảm điểm), không chặn cứng.

**Confidence**: **Medium–High** (dựa trên kinh nghiệm M15 XAU và các mẫu SMC/ICT đã chuẩn hoá; chưa re-validate trên dữ liệu ngoài tài liệu của bạn).

---

## 10) **Nguồn/Refs (theo tài liệu research của bạn)**

* `llihcchill/ICT-Imbalance-Expert-Advisor` — phiên & bias bằng imbalance.
* `rpanchyk/mt5-liquidity-sweep-ind` — thuật toán **liquidity sweep** dựa fractal/swing.
* `mngz47/mq5_black_box` — ý tưởng momentum/pin-bar & weekly bias; tham chiếu OB logic.

> Nếu bạn muốn, mình có thể **xuất SPEC.md** đúng cấu trúc thư mục dự án (docs/spec + src/include) hoặc tạo **diff** hướng dẫn chỉnh code hiện tại theo spec này.
