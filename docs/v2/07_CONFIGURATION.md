# 07. Cấu Hình & Tham Số (Configuration)

## 📍 Tổng Quan

File này mô tả tất cả tham số input của EA và cách tùy chỉnh.

---

## 1️⃣ Configuration Presets

**File**: `config_presets.mqh`

Bot cung cấp 3 preset profiles sẵn có:

### 🟢 Conservative (Low Risk)
```cpp  
struct ConservativePreset {
    // Risk
    RiskPerTrade: 0.2%
    MaxLotPerSide: 2.0
    DailyMDD: 5.0%
    
    // DCA
    EnableDCA: false         // ❌ No DCA
    MaxDcaAddons: 1
    
    // Trailing
    TrailStartR: 0.75R
    TrailStepR: 0.25R
    TrailATRMult: 2.5
}
```

**Phù hợp cho**: 
- Tài khoản nhỏ (<$5,000)
- Trader mới bắt đầu
- Muốn bảo vệ vốn tối đa

---

### 🟡 Balanced (Recommended)
```cpp
struct BalancedPreset {
    // Risk
    RiskPerTrade: 0.3%
    MaxLotPerSide: 3.0
    DailyMDD: 8.0%
    
    // DCA
    EnableDCA: true          // ✅ DCA enabled
    MaxDcaAddons: 2
    DcaLevel1: 0.75R
    DcaLevel2: 1.5R
    DcaSize1: 0.5× original
    DcaSize2: 0.33× original
    
    // Trailing
    TrailStartR: 1.0R
    TrailStepR: 0.5R
    TrailATRMult: 2.0
}
```

**Phù hợp cho**:
- Tài khoản trung bình ($5,000-$20,000)
- Trader có kinh nghiệm
- Cân bằng giữa risk và reward

---

### 🔴 Aggressive (High Risk)
```cpp
struct AggressivePreset {
    // Risk
    RiskPerTrade: 0.5%
    UseEquityBasedLot: true
    MaxLotPctEquity: 15.0%
    DailyMDD: 12.0%
    
    // DCA
    EnableDCA: true
    MaxDcaAddons: 3
    DcaLevel1: 0.5R
    DcaLevel2: 1.0R
    DcaLevel3: 1.5R
    DcaSize1: 0.618× original (Fibonacci)
    DcaSize2: 0.382× original
    DcaSize3: 0.236× original
    
    // Trailing
    TrailStartR: 0.75R
    TrailStepR: 0.3R
    TrailATRMult: 1.5
}
```

**Phù hợp cho**:
- Tài khoản lớn (>$20,000)
- Trader chuyên nghiệp
- Chấp nhận risk cao để tối đa hóa profit

---

## 2️⃣ Input Parameters

### 📌 Unit Convention
```cpp
input int InpPointsPerPip = 10;  // 10 or 100 depending on broker
```
- **XAUUSD 5-digit**: 10 points = 1 pip
- **XAUUSD 3-digit**: 100 points = 1 pip

---

### 📌 Session & Market

```cpp
input string InpTZ            = "Asia/Ho_Chi_Minh";  // Timezone
input int    InpSpreadMaxPts  = 500;                 // Max spread (pts)
input double InpSpreadATRpct  = 0.08;                // Spread ATR% guard
```

#### ⚙️ Session Mode Configuration (NEW)

Bot hỗ trợ **2 chế độ giao dịch theo thời gian**:

**Mode 1: FULL DAY** (Simple)
```cpp
enum TRADING_SESSION_MODE {
    SESSION_FULL_DAY = 0,      // 7-23h continuous
    SESSION_MULTI_WINDOW = 1   // 3 separate windows
};

input TRADING_SESSION_MODE InpSessionMode = SESSION_FULL_DAY;

// Full Day Settings
input int InpFullDayStart = 7;    // Start hour (GMT+7)
input int InpFullDayEnd   = 23;   // End hour (GMT+7)
```

**Mode 2: MULTI-WINDOW** (Flexible)
```cpp
// Window 1: Asia Session
input bool InpWindow1_Enable = true;   // Enable Window 1
input int  InpWindow1_Start  = 7;      // Start hour (GMT+7)
input int  InpWindow1_End    = 11;     // End hour (GMT+7)

// Window 2: London Session
input bool InpWindow2_Enable = true;   // Enable Window 2
input int  InpWindow2_Start  = 12;     // Start hour (GMT+7)
input int  InpWindow2_End    = 16;     // End hour (GMT+7)

// Window 3: NY Session
input bool InpWindow3_Enable = true;   // Enable Window 3
input int  InpWindow3_Start  = 18;     // Start hour (GMT+7)
input int  InpWindow3_End    = 23;     // End hour (GMT+7)
```

#### Giải Thích:
- **InpTZ**: Timezone reference (GMT+7)
- **InpSessionMode**: Toggle giữa FULL DAY và MULTI-WINDOW
- **InpFullDayStart/End**: Trading hours khi dùng Full Day mode
- **InpWindow[X]_Enable**: Bật/tắt từng window riêng lẻ
- **InpWindow[X]_Start/End**: Khung giờ cho mỗi window (GMT+7)
- **InpSpreadMaxPts**: Static max spread
- **InpSpreadATRpct**: Dynamic spread = max(500, 8% of ATR)

#### 📊 Timeline So Sánh:

**Full Day Mode**:
```
07:00 ══════════════════════════════════════════ 23:00
      │──────────── 16 hours continuous ─────────│
      └─ Trade liên tục, không có break ─────────┘
```

**Multi-Window Mode**:
```
07:00 ════ 11:00    12:00 ════ 16:00    18:00 ════════ 23:00
      │ Win1 │ BREAK │ Win2 │ BREAK │      Win3       │
      │ 4h   │  1h   │ 4h   │  2h   │       5h        │
      └──────┴───────┴──────┴───────┴─────────────────┘
      Total: 13 hours trading, 3 hours break
```

#### Ví Dụ Spread:
```
ATR = 8.0 points
Dynamic Max = max(500, 8.0/0.0001 × 0.08) = max(500, 640) = 640 pts

Current Spread = 450 pts
→ Spread OK ✅

Current Spread = 700 pts
→ Spread TOO WIDE ❌
```

#### 💡 Preset Examples:

**Preset 1: Full Coverage** (Default)
```cpp
InpSessionMode = SESSION_FULL_DAY;
InpFullDayStart = 7;
InpFullDayEnd = 23;

Expected:
  Coverage: 16h
  Trades/Day: 5-6
  Win Rate: 65%
```

**Preset 2: Quality Focus** (3 Windows)
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;
InpWindow1_Enable = true;   // Asia 7-11
InpWindow2_Enable = true;   // London 12-16
InpWindow3_Enable = true;   // NY 18-23

Expected:
  Coverage: 13h
  Trades/Day: 4-5
  Win Rate: 68-70%
```

**Preset 3: London + NY Only**
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;
InpWindow1_Enable = false;  // Skip Asia
InpWindow2_Enable = true;   // London only
InpWindow3_Enable = true;   // NY only

Expected:
  Coverage: 9h
  Trades/Day: 3-4
  Win Rate: 70-72%
```

**Chi tiết đầy đủ**: [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md)

---

### 📌 Risk Management

```cpp
input double InpRiskPerTradePct = 0.5;   // Risk per trade (%)
input double InpMinRR           = 2.0;   // Min R:R ratio
input double InpDailyMddMax     = 8.0;   // Daily MDD limit (%)
input int    InpMaxDcaAddons    = 2;     // Max DCA add-ons
```

#### Giải Thích:
- **InpRiskPerTradePct**: Risk mỗi trade (% of equity/balance)
- **InpMinRR**: Minimum Risk:Reward (2.0 = TP phải >= 2× SL)
- **InpDailyMddMax**: Max daily drawdown trước khi halt trading
- **InpMaxDcaAddons**: Số lượng DCA positions tối đa

#### Khuyến Nghị:
```
Small Account (<$5k):   Risk 0.2%, MDD 5%
Medium Account ($5-20k): Risk 0.3-0.5%, MDD 8%
Large Account (>$20k):   Risk 0.5-1%, MDD 10-12%
```

---

### 📌 Dynamic Lot Sizing

```cpp
input double InpLotBase         = 0.1;     // Base lot size
input double InpLotMax          = 5.0;     // Max lot size cap
input double InpEquityPerLotInc = 1000.0;  // Equity per lot inc ($)
input double InpLotIncrement    = 0.1;     // Lot increment
```

#### Công Thức:
```
MaxLot = LotBase + floor(Equity / EquityPerLotInc) × LotIncrement
```

#### Ví Dụ:
```
Base: 0.1, Max: 5.0, EquityPerInc: $1000, Increment: 0.1

Equity $2,500:
  MaxLot = 0.1 + floor(2500/1000) × 0.1
         = 0.1 + 2 × 0.1
         = 0.3

Equity $10,000:
  MaxLot = 0.1 + floor(10000/1000) × 0.1
         = 0.1 + 10 × 0.1
         = 1.1

Equity $50,000:
  MaxLot = 0.1 + floor(50000/1000) × 0.1
         = 0.1 + 50 × 0.1
         = 5.1 → Capped to 5.0
```

---

### 📌 Basket Manager

```cpp
input double InpBasketTPPct     = 0.0;  // Basket TP (%, 0=disabled)
input double InpBasketSLPct     = 0.0;  // Basket SL (%, 0=disabled)
input int    InpEndOfDayHour    = 0;    // EOD hour (0=disabled)
input int    InpDailyResetHour  = 6;    // Daily reset hour (GMT+7)
```

#### Ví Dụ Cấu Hình:
```
Basket TP: 0.3% (close all khi profit = 0.3% balance)
Basket SL: 1.2% (close all khi loss = 1.2% balance)
EOD Hour: 23 (close all positions at 23h GMT+7)
```

---

### 📌 BOS Detection

```cpp
input int    InpFractalK        = 3;     // Fractal K
input int    InpLookbackSwing   = 50;    // Lookback (bars)
input double InpMinBodyATR      = 0.6;   // Min body (ATR multiple)
input int    InpMinBreakPts     = 70;    // Min break (points)
input int    InpBOS_TTL         = 60;    // TTL (bars)
```

#### Điều Chỉnh:
- **Loose BOS** (nhiều signal): K=2, MinBreak=50, MinBody=0.4
- **Strict BOS** (ít signal): K=4, MinBreak=100, MinBody=0.8

---

### 📌 Liquidity Sweep

```cpp
input int    InpLookbackLiq     = 40;    // Lookback (bars)
input double InpMinWickPct      = 35.0;  // Min wick (%)
input int    InpSweep_TTL       = 24;    // TTL (bars)
```

#### Điều Chỉnh:
- **More Sweeps**: MinWick=25%, Lookback=60
- **Fewer Sweeps**: MinWick=45%, Lookback=30

---

### 📌 Order Block

```cpp
input int    InpOB_MaxTouches   = 3;     // Max touches
input int    InpOB_BufferInvPts = 70;    // Invalidation buffer (pts)
input int    InpOB_TTL          = 160;   // TTL (bars)
input double InpOB_VolMultiplier= 1.3;   // Strong OB threshold
```

---

### 📌 Fair Value Gap

```cpp
input int    InpFVG_MinPts      = 180;   // Min size (points)
input double InpFVG_FillMinPct  = 25.0;  // Min fill (%)
input double InpFVG_MitigatePct = 35.0;  // Mitigation (%)
input double InpFVG_CompletePct = 85.0;  // Completion (%)
input int    InpFVG_BufferInvPt = 70;    // Invalidation buffer (pts)
input int    InpFVG_TTL         = 70;    // TTL (bars)
```

---

### 📌 Execution

```cpp
input int    InpTriggerBodyATR  = 30;    // Trigger body (0.30 ATR)
input int    InpEntryBufferPts  = 70;    // Entry buffer (points)
input int    InpMinStopPts      = 300;   // Min stop (points)
input int    InpOrder_TTL_Bars  = 16;    // Pending order TTL (bars)
```

---

### 📌 Fixed SL Mode

```cpp
input bool   InpUseFixedSL      = false; // Use fixed SL
input int    InpFixedSL_Pips    = 100;   // Fixed SL (pips)
input bool   InpFixedTP_Enable  = false; // Use fixed TP
input int    InpFixedTP_Pips    = 200;   // Fixed TP (pips)
```

#### Khi Nào Dùng Fixed SL:
- ✅ Muốn consistent risk mỗi trade
- ✅ Backtest để tối ưu SL/TP values
- ❌ Không phù hợp với price action (bỏ qua structure)

---

### 📌 Feature Toggles

```cpp
input bool   InpEnableDCA       = true;  // Enable DCA
input bool   InpEnableBE        = true;  // Enable Breakeven
input bool   InpEnableTrailing  = true;  // Enable Trailing
input bool   InpUseDailyMDD     = true;  // Enable Daily MDD
input bool   InpUseEquityMDD    = true;  // Use Equity for MDD
```

---

### 📌 Dynamic Lot Sizing Options

```cpp
input bool   InpUseEquityBasedLot = false; // Use % Equity for MaxLot
input double InpMaxLotPctEquity   = 10.0;  // Max lot as % equity
```

#### Ví Dụ:
```
Equity: $10,000
MaxLotPctEquity: 10%

Max Exposure = $10,000 × 10% = $1,000
XAUUSD Contract Size = 100 oz
Current Price = $2650/oz

MaxLot = $1,000 / (100 × 2650 / 100)
       = $1,000 / $2,650
       = 0.38 lots
```

---

### 📌 Trailing Stop

```cpp
input double InpTrailStartR     = 1.0;   // Start at +XR
input double InpTrailStepR      = 0.5;   // Move every +XR
input double InpTrailATRMult    = 2.0;   // Distance (ATR multiple)
```

#### Ví Dụ:
```
Setup:
  TrailStartR: 1.0
  TrailStepR: 0.5
  TrailATRMult: 2.0
  ATR: 5.0 points

Timeline:
  +1.0R → Start trailing (SL = entry + 1R - 2×ATR)
  +1.5R → Trail again (+0.5R moved)
  +2.0R → Trail again (+0.5R moved)
```

---

### 📌 DCA Filters

```cpp
input bool   InpDcaRequireConfluence = false; // Require new BOS/FVG
input bool   InpDcaCheckEquity       = true;  // Check equity health
input double InpDcaMinEquityPct      = 95.0;  // Min equity %
```

---

### 📌 DCA Levels

```cpp
input double InpDcaLevel1_R     = 0.75;  // First DCA trigger (+XR)
input double InpDcaLevel2_R     = 1.5;   // Second DCA trigger (+XR)
input double InpDcaSize1_Mult   = 0.5;   // First DCA size (× original)
input double InpDcaSize2_Mult   = 0.33;  // Second DCA size (× original)
input double InpBeLevel_R       = 1.0;   // Breakeven trigger (+XR)
```

#### Ví Dụ Custom DCA:
```
Conservative:
  Level1: 1.0R, Size1: 0.3×
  Level2: 2.0R, Size2: 0.2×
  → Ít aggressive hơn

Aggressive:
  Level1: 0.5R, Size1: 0.618× (Fibonacci)
  Level2: 1.0R, Size2: 0.382×
  → Thêm vào sớm hơn, nhiều hơn
```

---

### 📌 Visualization

```cpp
input bool   InpShowDebugDraw   = true;  // Show debug drawings
input bool   InpShowDashboard   = true;  // Show dashboard
```

---

## 3️⃣ Timeframe-Specific Tuning

### M15 (Recommended)
```
BOS:
  MinBreakPts: 70
  BOS_TTL: 60
  
Sweep:
  LookbackLiq: 40
  Sweep_TTL: 24
  
OB:
  OB_TTL: 160
  BufferInvPts: 70
  
FVG:
  FVG_MinPts: 180
  FVG_TTL: 70
  
Execution:
  TriggerBodyATR: 30 (0.30 ATR)
  Order_TTL_Bars: 16
```

### M5 (Faster)
```
BOS:
  MinBreakPts: 50
  BOS_TTL: 120
  
Sweep:
  LookbackLiq: 60
  Sweep_TTL: 40
  
Execution:
  TriggerBodyATR: 25 (0.25 ATR)
  Order_TTL_Bars: 30
```

### H1 (Slower)
```
BOS:
  MinBreakPts: 100
  BOS_TTL: 30
  
Sweep:
  LookbackLiq: 20
  Sweep_TTL: 12
  
Execution:
  TriggerBodyATR: 40 (0.40 ATR)
  Order_TTL_Bars: 8
```

---

## 4️⃣ Optimization Tips

### 🎯 For Higher Win Rate
```
Increase:
  - MinBreakPts (stricter BOS)
  - MinBodyATR (larger candles only)
  - MinWickPct (clearer sweeps)
  - FVG_MinPts (larger gaps only)
  
Result:
  + Fewer but higher quality signals
  + Higher win rate
  - Fewer trades
```

### 🎯 For More Trades
```
Decrease:
  - MinBreakPts (50 instead of 70)
  - MinBodyATR (0.4 instead of 0.6)
  - MinWickPct (25% instead of 35%)
  
Result:
  + More trading opportunities
  - Lower win rate
  + More frequent profits/losses
```

### 🎯 For Aggressive Profit
```
Enable:
  - DCA with 3 levels
  - Trailing Start: 0.75R (earlier)
  - Trailing Step: 0.3R (more frequent)
  
Increase:
  - MaxDcaAddons: 3
  - DcaSize multipliers
  
Result:
  + Higher profit potential
  - Higher risk
```

### 🎯 For Capital Protection
```
Conservative Settings:
  - Risk: 0.2%
  - Daily MDD: 5%
  - No DCA
  - Trailing Start: 1.5R (later)
  - Fixed SL mode
  
Result:
  + Safer trading
  + Smaller drawdowns
  - Lower profit potential
```

---

## 5️⃣ Quick Config Examples

### Example 1: Scalper (M5)
```cpp
// More trades, quick profits
InpRiskPerTradePct = 0.3;
InpMinRR = 1.5;  // Lower RR
InpEnableDCA = false;
InpEnableBE = true;
InpEnableTrailing = false;
InpMinBreakPts = 40;  // Looser
InpOrder_TTL_Bars = 30;
```

### Example 2: Swing (H1)
```cpp
// Fewer trades, bigger moves
InpRiskPerTradePct = 0.5;
InpMinRR = 3.0;  // Higher RR
InpEnableDCA = true;
InpMaxDcaAddons = 3;
InpEnableTrailing = true;
InpMinBreakPts = 150;  // Stricter
InpOrder_TTL_Bars = 8;
```

### Example 3: Conservative
```cpp
// Capital protection
InpRiskPerTradePct = 0.2;
InpDailyMddMax = 5.0;
InpEnableDCA = false;
InpLotMax = 2.0;
InpBasketSLPct = 0.8;  // Early basket SL
```

---

---

## 🆕 v2.0 New Parameters

### 📌 News Filter

```cpp
input group "═══════ News Filter ═══════"
input bool   InpEnableNewsFilter = true;
input string InpNewsFilePath     = "news.csv";      // CSV file path
input int    InpNewsBeforeMin    = 20;             // Block X min before
input int    InpNewsAfterMin     = 20;             // Block X min after
input string InpNewsImpactFilter = "HIGH_MED";     // HIGH, HIGH_MED, ALL
```

**Giải Thích**:
- **InpEnableNewsFilter**: Bật/tắt news filter
- **InpNewsFilePath**: Đường dẫn file CSV (trong MQL5/Files/)
- **InpNewsBeforeMin**: Block entries X phút trước news
- **InpNewsAfterMin**: Block entries X phút sau news
- **InpNewsImpactFilter**: 
  - `"HIGH"` - Chỉ filter HIGH impact
  - `"HIGH_MED"` - Filter HIGH và MEDIUM
  - `"ALL"` - Filter tất cả news

**news.csv Format**:
```csv
timestamp,impact,currency,title
2025-10-16 13:30:00,HIGH,USD,FOMC Interest Rate Decision
2025-10-16 14:00:00,HIGH,USD,Fed Press Conference
2025-10-17 08:30:00,MEDIUM,USD,Retail Sales
```

---

### 📌 Volatility Regime

```cpp
input group "═══════ Volatility Regime ═══════"
input bool InpRegimeEnable     = true;
input int  InpATRPeriod        = 14;
input int  InpATRDaysLookback  = 180;          // Days for percentile
input int  InpRegimeLowPct     = 30;           // P30 threshold
input int  InpRegimeHighPct    = 70;           // P70 threshold
```

**Giải Thích**:
- **InpRegimeEnable**: Bật/tắt regime detection
- **InpATRPeriod**: ATR period (14 recommended)
- **InpATRDaysLookback**: Lookback window (180 days = ~6 months)
- **InpRegimeLowPct**: Percentile cho LOW regime (30 = P30)
- **InpRegimeHighPct**: Percentile cho HIGH regime (70 = P70)

**Cơ Chế**:
```
ATR(14) hiện tại so với phân phối 180 ngày:
  ATR <= P30 → REGIME_LOW
  P30 < ATR < P70 → REGIME_MID
  ATR >= P70 → REGIME_HIGH
```

---

### 📌 ATR-Scaled Execution

```cpp
input group "═══════ ATR-Scaled Execution ═══════"
input double InpEntryBufATRMult     = 0.12;    // Buffer as × ATR
input double InpMinStopATRMult      = 1.0;     // Min stop as × ATR

input double InpTriggerBodyATR_Low  = 0.25;    // LOW regime trigger
input double InpTriggerBodyATR_Mid  = 0.30;    // MID regime trigger
input double InpTriggerBodyATR_High = 0.35;    // HIGH regime trigger
```

**Giải Thích**:
- Entry Buffer = ATR × `InpEntryBufATRMult`
- Min Stop = ATR × `InpMinStopATRMult` (×1.3 trong HIGH regime)
- Trigger thresholds tự động chọn theo regime

**Ví Dụ**:
```
LOW Regime (ATR = 4.0):
  Buffer: 4.0 × 0.12 = 0.48 points
  MinStop: 4.0 × 1.0 = 4.0 points
  Trigger: 4.0 × 0.25 = 1.0 point

HIGH Regime (ATR = 9.0):
  Buffer: 9.0 × 0.12 = 1.08 points
  MinStop: 9.0 × 1.0 × 1.3 = 11.7 points
  Trigger: 9.0 × 0.35 = 3.15 points
```

---

### 📌 Extended Arbiter Scoring

```cpp
input group "═══════ Extended Scoring ═══════"
input int InpScoreEnter      = 100;    // Min score to enter
input int InpScoreCounterMin = 120;    // Min score for counter-trend
```

**Giải Thích**:
- **InpScoreEnter**: Threshold tối thiểu để entry (mặc định 100)
- **InpScoreCounterMin**: Threshold cao hơn cho counter-trend trades (120)

**Rationale**:
```
Normal trend trade:
  Score >= 100 → Enter

Counter-trend trade:
  Score >= 120 → Enter (stricter)
  Score < 120 → Reject (too risky)
```

---

### 📌 Risk Overlays

```cpp
input group "═══════ Risk Overlays ═══════"
input int InpMaxTradesPerDay     = 6;      // Max trades per day
input int InpMaxConsecLoss       = 3;      // Max consecutive losses
input int InpCoolDownMinAfterLoss= 60;     // Cooldown minutes
```

**Giải Thích**:
- **InpMaxTradesPerDay**: Giới hạn số lệnh mỗi ngày (reset 6h GMT+7)
- **InpMaxConsecLoss**: Số loss liên tiếp trước khi cooldown
- **InpCoolDownMinAfterLoss**: Thời gian nghỉ sau khi hit max loss streak

**Ví Dụ**:
```
MaxConsecLoss = 3
CoolDown = 60 min

Scenario:
  08:00 - LOSS #1
  10:00 - LOSS #2
  12:00 - LOSS #3 → COOLDOWN until 13:00
  
  12:30 - New signal → BLOCKED (in cooldown)
  13:05 - New signal → BLOCKED (streak=3, need win)
  14:00 - WIN → Reset streak, resume trading
```

---

### 📌 Adaptive DCA Levels (by Regime)

```cpp
input group "═══════ Adaptive DCA ═══════"
// LOW Regime
input double InpDcaLevel1_R_Low  = 0.75;
input double InpDcaSize1_Low     = 0.50;
input double InpDcaLevel2_R_Low  = 1.50;
input double InpDcaSize2_Low     = 0.33;

// MID Regime
input double InpDcaLevel1_R_Mid  = 0.90;
input double InpDcaSize1_Mid     = 0.45;
input double InpDcaLevel2_R_Mid  = 1.60;
input double InpDcaSize2_Mid     = 0.30;

// HIGH Regime
input double InpDcaLevel1_R_High = 1.00;
input double InpDcaSize1_High    = 0.33;
input bool   InpDcaLevel2_HighVol= false;   // Disable L2 in HIGH
```

**Mapping Table**:

|| LOW | MID | HIGH |
||-----|-----|------|
|| **L1 Trigger** | +0.75R | +0.90R | +1.00R |
|| **L1 Size** | 0.50× | 0.45× | 0.33× |
|| **L2 Trigger** | +1.50R | +1.60R | Disabled |
|| **L2 Size** | 0.33× | 0.30× | - |

---

### 📌 Adaptive Trailing (by Regime)

```cpp
input group "═══════ Adaptive Trailing ═══════"
// Start Thresholds
input double InpTrailStartR_Low  = 1.0;
input double InpTrailStartR_Mid  = 1.2;
input double InpTrailStartR_High = 1.5;

// Step Sizes
input double InpTrailStepR_Low   = 0.6;
input double InpTrailStepR_Mid   = 0.5;
input double InpTrailStepR_High  = 0.3;

// ATR Multipliers
input double InpTrailATRMult_Low = 2.0;
input double InpTrailATRMult_Mid = 2.5;
input double InpTrailATRMult_High= 3.0;
```

**Mapping Table**:

|| LOW | MID | HIGH |
||-----|-----|------|
|| **Start** | +1.0R | +1.2R | +1.5R |
|| **Step** | 0.6R | 0.5R | 0.3R |
|| **Distance** | 2.0× ATR | 2.5× ATR | 3.0× ATR |

---

## 6️⃣ v2.0 Configuration Presets

### 🟢 Conservative (M30)
```cpp
// Risk
InpRiskPerTradePct = 0.5;
InpDailyMddMax = 5.0;
InpMaxTradesPerDay = 4;
InpMaxConsecLoss = 2;

// News & Regime
InpEnableNewsFilter = true;
InpRegimeEnable = true;

// Scoring
InpScoreEnter = 110;  // Higher threshold
InpScoreCounterMin = 140;

// ATR-Scaled
InpEntryBufATRMult = 0.15;  // Wider buffer
InpMinStopATRMult = 1.2;    // Wider stop

// DCA: Disabled in HIGH, conservative in others
// Trailing: Later start, wider distance
```

### 🟡 Balanced (M30) - Recommended
```cpp
// Risk
InpRiskPerTradePct = 0.4;
InpDailyMddMax = 8.0;
InpMaxTradesPerDay = 6;
InpMaxConsecLoss = 3;
InpCoolDownMinAfterLoss = 60;

// News & Regime
InpEnableNewsFilter = true;
InpNewsImpactFilter = "HIGH_MED";
InpRegimeEnable = true;
InpATRDaysLookback = 180;

// Scoring
InpScoreEnter = 100;
InpScoreCounterMin = 120;

// ATR-Scaled
InpEntryBufATRMult = 0.12;
InpMinStopATRMult = 1.0;
InpTriggerBodyATR_Low = 0.25;
InpTriggerBodyATR_Mid = 0.30;
InpTriggerBodyATR_High = 0.35;

// DCA: Adaptive by regime
InpDcaLevel1_R_Low = 0.75;
InpDcaLevel1_R_Mid = 0.90;
InpDcaLevel1_R_High = 1.00;
InpDcaLevel2_HighVol = false;  // Disable L2 in HIGH

// Trailing: Adaptive by regime
InpTrailStartR_Low = 1.0;
InpTrailStartR_Mid = 1.2;
InpTrailStartR_High = 1.5;
```

### 🔴 Aggressive (M30)
```cpp
// Risk
InpRiskPerTradePct = 0.6;
InpDailyMddMax = 10.0;
InpMaxTradesPerDay = 8;
InpMaxConsecLoss = 4;
InpCoolDownMinAfterLoss = 30;  // Shorter cooldown

// News: Only HIGH impact
InpEnableNewsFilter = true;
InpNewsImpactFilter = "HIGH";  // Trade through MEDIUM news

// Scoring
InpScoreEnter = 90;  // Lower threshold (more trades)
InpScoreCounterMin = 110;

// ATR-Scaled
InpEntryBufATRMult = 0.10;  // Tighter buffer
InpMinStopATRMult = 0.9;    // Tighter stop

// DCA: More aggressive
InpDcaLevel1_R_Low = 0.50;  // Earlier
InpDcaSize1_Low = 0.618;    // Larger (Fibonacci)
InpDcaLevel2_HighVol = true;  // Enable L2 even in HIGH

// Trailing: Earlier, tighter
InpTrailStartR_Low = 0.75;
InpTrailStepR_High = 0.25;  // More frequent
```

---

## 7️⃣ Recommended Settings by Market

### XAUUSD M30 (Primary Focus)
```cpp
// Base
InpRiskPerTradePct = 0.4;
InpMinRR = 2.0;
InpDailyMddMax = 8.0;

// News
InpEnableNewsFilter = true;
InpNewsImpactFilter = "HIGH_MED";
InpNewsBeforeMin = 20;
InpNewsAfterMin = 20;

// Regime
InpRegimeEnable = true;
InpATRPeriod = 14;
InpATRDaysLookback = 180;

// Execution
InpEntryBufATRMult = 0.12;
InpMinStopATRMult = 1.0;
InpTriggerBodyATR_Mid = 0.30;

// Risk Overlays
InpMaxTradesPerDay = 6;
InpMaxConsecLoss = 3;
InpCoolDownMinAfterLoss = 60;

// Scoring
InpScoreEnter = 100;
InpScoreCounterMin = 120;
```

### XAUUSD M15 (More Trades)
```cpp
// Adjusted for faster timeframe
InpATRDaysLookback = 120;  // Shorter history
InpMaxTradesPerDay = 8;    // More opportunities
InpOrder_TTL_Bars: 12/16/20 (by regime)
InpScoreEnter = 105;       // Slightly stricter
```

---

## 8️⃣ Parameter Tuning Guide

### For Higher Win Rate
```
Increase:
  - InpScoreEnter (100 → 110)
  - InpScoreCounterMin (120 → 140)
  - InpTriggerBodyATR_* (stricter triggers)
  - InpNewsBeforeMin (20 → 30)

Enable:
  - InpEnableNewsFilter = true
  - InpRegimeEnable = true

Result:
  + Fewer but higher quality trades
  + Better win rate
  - Fewer trading opportunities
```

### For More Profits (Risk Adjusted)
```
Optimize:
  - InpDcaLevel1_R_Low = 0.60 (earlier DCA)
  - InpDcaSize1_Low = 0.55 (larger DCA)
  - InpTrailStepR_High = 0.25 (more frequent trailing)

Result:
  + Maximize winning trades
  + Higher profit per trade
  ~ Similar win rate
```

### For Lower Drawdown
```
Increase:
  - InpMaxConsecLoss (3 → 2)
  - InpCoolDownMinAfterLoss (60 → 120)
  - InpMinStopATRMult (1.0 → 1.2)

Decrease:
  - InpMaxTradesPerDay (6 → 4)
  - InpRiskPerTradePct (0.4 → 0.3)

Result:
  + Lower max drawdown
  + Safer trading
  - Lower total profits
```

---

## 9️⃣ Optimization Workflow

### Step 1: Baseline Test
```
Run v1.2 với default settings
Record: WR, PF, MDD, Trades/Day
```

### Step 2: Enable News Filter
```
InpEnableNewsFilter = true
Test và so sánh metrics
Expected: WR +1-2%, Trades/Day -10-15%
```

### Step 3: Enable Regime
```
InpRegimeEnable = true
Test với adaptive parameters
Expected: WR +2-3%, MDD -10-20%
```

### Step 4: Fine-tune Scoring
```
Adjust:
  - InpScoreEnter
  - InpScoreCounterMin
  - Trigger thresholds

Test various combinations
```

### Step 5: Optimize Risk Overlays
```
Test different:
  - MaxTradesPerDay (4-8)
  - MaxConsecLoss (2-4)
  - CoolDown (30-120 min)

Find optimal balance
```

---

## 🎓 Đọc Tiếp

- [01_SYSTEM_OVERVIEW.md](01_SYSTEM_OVERVIEW.md) - System overview
- [09_EXAMPLES.md](09_EXAMPLES.md) - Real configuration examples
- [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md) - Multi-session guide chi tiết
- [TIMEZONE_CONVERSION.md](TIMEZONE_CONVERSION.md) - Timezone conversion guide

