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
input int    InpSessStartHour = 7;                   // Start (VN time)
input int    InpSessEndHour   = 23;                  // End (VN time)
input int    InpSpreadMaxPts  = 500;                 // Max spread (pts)
input double InpSpreadATRpct  = 0.08;                // Spread ATR% guard
```

#### Giải Thích:
- **InpTZ**: Timezone cho session timing
- **InpSessStartHour/EndHour**: Trading hours (GMT+7)
- **InpSpreadMaxPts**: Static max spread
- **InpSpreadATRpct**: Dynamic spread = max(500, 8% of ATR)

#### Ví Dụ:
```
ATR = 8.0 points
Dynamic Max = max(500, 8.0/0.0001 × 0.08) = max(500, 640) = 640 pts

Current Spread = 450 pts
→ Spread OK ✅

Current Spread = 700 pts
→ Spread TOO WIDE ❌
```

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

## 🎓 Đọc Tiếp

- [01_SYSTEM_OVERVIEW.md](01_SYSTEM_OVERVIEW.md) - System overview
- [09_EXAMPLES.md](09_EXAMPLES.md) - Real configuration examples

