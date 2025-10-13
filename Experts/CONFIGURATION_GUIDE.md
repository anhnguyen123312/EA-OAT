# SMC/ICT EA - Configuration Guide

This guide provides detailed explanations for all EA parameters and recommended settings for different scenarios.

## 📋 Table of Contents

1. [Quick Start Profiles](#quick-start-profiles)
2. [Parameter Explanations](#parameter-explanations)
3. [Advanced Configurations](#advanced-configurations)
4. [Broker-Specific Settings](#broker-specific-settings)
5. [Optimization Guidelines](#optimization-guidelines)

---

## Quick Start Profiles

### Conservative (Low Risk)

```
// Risk Management
InpRiskPerTradePct = 0.2        // 0.2% per trade
InpMinRR = 2.5                   // Higher RR requirement
InpMaxLotPerSide = 2.0           // Lower position limits
InpMaxDcaAddons = 1              // Limited DCA
InpDailyMddMax = 5.0             // Tight daily stop

// Detection (Stricter)
InpMinBodyATR = 0.7              // Stronger moves only
InpMinBreakPts = 70              // Clearer breaks
InpOB_MaxTouches = 2             // Fresh OBs only
InpFVG_MinPts = 180              // Larger FVGs
```

### Balanced (Recommended)

```
// Risk Management
InpRiskPerTradePct = 0.3         // 0.3% per trade
InpMinRR = 2.0                   // Standard RR
InpMaxLotPerSide = 3.0           // Reasonable limits
InpMaxDcaAddons = 2              // Full DCA capability
InpDailyMddMax = 8.0             // Standard protection

// Detection (Standard)
InpMinBodyATR = 0.6              // Moderate confirmation
InpMinBreakPts = 50              // Standard breaks
InpOB_MaxTouches = 3             // Allow retests
InpFVG_MinPts = 150              // Standard FVGs
```

### Aggressive (Higher Risk)

```
// Risk Management
InpRiskPerTradePct = 0.5         // 0.5% per trade
InpMinRR = 1.8                   // Lower RR acceptable
InpMaxLotPerSide = 5.0           // Higher position limits
InpMaxDcaAddons = 2              // Full DCA
InpDailyMddMax = 12.0            // Higher daily tolerance

// Detection (Looser)
InpMinBodyATR = 0.5              // Accept smaller moves
InpMinBreakPts = 40              // Smaller breaks OK
InpOB_MaxTouches = 4             // More retests allowed
InpFVG_MinPts = 120              // Smaller FVGs
```

---

## Parameter Explanations

### Unit Convention

#### `InpPointsPerPip` (Default: 10)

**What it does:** Defines how many points equal one pip for your broker.

**Values:**
- `10` - Most brokers (5-digit quotes: 1.1234**5**)
- `100` - Some brokers (4-digit quotes: 1.12**34**)

**How to check:** Open a quote window - if XAUUSD shows 2005.**12**, use 10. If it shows 2005.**1**, use 100.

---

### Session & Market

#### `InpSessStartHour` (Default: 8)

**What it does:** Hour when EA starts looking for trades (in GMT+7 timezone).

**Recommended:**
- `8` - Asian session open
- `14` - London session
- `19` - New York session

**Note:** EA will manage existing positions outside session but won't open new ones.

#### `InpSessEndHour` (Default: 23)

**What it does:** Hour when EA stops looking for new trades.

**Recommended:**
- `23` - Full day coverage
- `17` - London session only
- `11` - Asian session only

#### `InpSpreadMaxPts` (Default: 35)

**What it does:** Maximum spread (in points) allowed for trade entry.

**Calculation:** 35 points = 3.5 pips (with InpPointsPerPip=10)

**Adjust for:**
- **Tight spread brokers:** 25-30 points
- **Normal spread:** 35-40 points
- **Wide spread brokers:** 50+ points (not recommended)

---

### Risk Management

#### `InpRiskPerTradePct` (Default: 0.3)

**What it does:** Percentage of account equity risked per trade.

**Examples:**
- $10,000 account × 0.3% = $30 risk per trade
- $10,000 account × 0.5% = $50 risk per trade

**Recommendations:**
- **Conservative:** 0.1-0.2%
- **Moderate:** 0.3-0.4%
- **Aggressive:** 0.5-1.0%
- **Never exceed:** 2.0%

#### `InpMinRR` (Default: 2.0)

**What it does:** Minimum Risk:Reward ratio required to place trade.

**Meaning:**
- `2.0` = Take profit must be 2× stop loss distance
- `2.5` = TP must be 2.5× SL distance
- `3.0` = TP must be 3× SL distance

**Impact:**
- **Higher values:** Fewer trades, better quality
- **Lower values:** More trades, lower average win

**Sweet spot:** 2.0-2.5 for XAUUSD M15

#### `InpMaxLotPerSide` (Default: 3.0)

**What it does:** Maximum total lot size allowed in one direction (includes DCA add-ons).

**Purpose:** Prevents over-exposure to one direction.

**Example:**
- Initial trade: 0.10 lots
- DCA #1: 0.05 lots
- DCA #2: 0.03 lots
- Total: 0.18 lots (well under 3.0 limit)

**Set based on:**
- Account size
- Broker margin requirements
- Personal risk tolerance

#### `InpMaxDcaAddons` (Default: 2)

**What it does:** Maximum number of DCA (add-on) positions allowed.

**DCA Schedule:**
- **Add-on #1:** +0.75R profit, 0.5× original size
- **Add-on #2:** +1.5R profit, 0.33× original size

**Values:**
- `0` - No DCA (single position only)
- `1` - One add-on at +0.75R
- `2` - Full DCA (both add-ons)

#### `InpDailyMddMax` (Default: 8.0)

**What it does:** Maximum daily drawdown percentage before EA closes all positions and halts trading.

**Protection mechanism:**
- Tracks daily P/L from session start
- Closes all positions when loss ≥ threshold
- Blocks new trades for remainder of day
- Resets at start of next trading day

**Recommendations:**
- **Tight control:** 5.0%
- **Moderate:** 8.0%
- **Loose:** 12.0%
- **Max recommended:** 15.0%

---

### BOS/CHOCH Detection

#### `InpFractalK` (Default: 3)

**What it does:** Number of bars on each side to confirm a swing high/low.

**Example:**
- K=3: High must be higher than 3 bars before AND 3 bars after
- K=2: High must be higher than 2 bars before AND 2 bars after

**Impact:**
- **Lower K (2):** More swings detected, faster signals, more noise
- **Higher K (4):** Fewer swings, stronger confirmation, slower

**Optimal:** 3 for M15

#### `InpLookbackSwing` (Default: 50)

**What it does:** How many bars to look back when searching for last swing high/low.

**Purpose:** Determines the "structure" we're breaking.

**Adjust for:**
- **Trending markets:** 30-40 bars (shorter lookback)
- **Ranging markets:** 50-70 bars (longer lookback)
- **Higher timeframes:** Increase proportionally

#### `InpMinBodyATR` (Default: 0.6)

**What it does:** Minimum candle body size as multiple of ATR(14) to confirm BOS.

**Meaning:**
- `0.6` = Body must be ≥ 60% of ATR
- `0.8` = Body must be ≥ 80% of ATR (stronger confirmation)

**Purpose:** Filters out weak, choppy breaks.

**Recommendations:**
- **Volatile markets:** 0.7-0.9
- **Normal markets:** 0.6
- **Quiet markets:** 0.5

#### `InpMinBreakPts` (Default: 50)

**What it does:** Minimum distance (in points) price must break beyond swing to confirm BOS.

**Calculation:** 50 points = 5 pips (with InpPointsPerPip=10)

**Purpose:** Prevents false breaks from tiny movements.

**Adjust for:**
- **XAUUSD:** 40-70 points
- **Lower volatility pairs:** 20-30 points
- **Higher volatility:** 70-100 points

#### `InpBOS_TTL` (Default: 40)

**What it does:** How many bars a BOS signal remains valid (Time To Live).

**Purpose:** Prevents EA from acting on stale structure breaks.

**Adjust for:**
- **M15:** 30-50 bars
- **M30:** 20-30 bars
- **H1:** 15-25 bars

---

### Liquidity Sweep

#### `InpLookbackLiq` (Default: 30)

**What it does:** How many bars to look back for highest high / lowest low.

**Purpose:** Defines what liquidity levels we're "sweeping."

**Impact:**
- **Shorter (20):** Recent liquidity only
- **Longer (50):** Includes older levels

**Optimal:** 20-40 for M15

#### `InpMinWickPct` (Default: 35.0)

**What it does:** Minimum percentage of candle range that must be wick to confirm sweep.

**Meaning:**
- `35.0` = Upper/lower wick must be ≥35% of total candle range

**Purpose:** Confirms rejection from liquidity level.

**Adjust:**
- **Strict:** 40-50% (fewer, cleaner sweeps)
- **Loose:** 25-30% (more sweeps detected)

#### `InpSweep_TTL` (Default: 20)

**What it does:** How many bars a sweep signal remains valid.

**Purpose:** Sweeps should be acted on quickly.

**Recommendations:**
- **M15:** 15-25 bars
- **M30:** 10-20 bars

---

### Order Block

#### `InpOB_MaxTouches` (Default: 3)

**What it does:** Maximum times price can touch OB before it's considered invalid.

**Trading logic:**
- Fresh OBs (0-1 touches) are strongest
- Tested OBs (2-3 touches) still valid but weaker
- Overused OBs (4+ touches) are invalid

**Adjust:**
- **Fresh OBs only:** 2
- **Allow retests:** 3-4
- **Very permissive:** 5 (not recommended)

#### `InpOB_BufferInvPts` (Default: 50)

**What it does:** How many points price must close beyond OB boundary to invalidate it.

**Purpose:** Small wicks through OB don't invalidate - only decisive closes.

**Calculation:** 50 points = 5 pips

**Adjust:**
- **Strict:** 30-40 points
- **Moderate:** 50 points
- **Loose:** 70-80 points

#### `InpOB_TTL` (Default: 120)

**What it does:** How many bars an OB remains valid before expiring.

**Purpose:** Old order blocks lose relevance.

**Recommendations:**
- **M15:** 100-150 bars
- **M30:** 60-100 bars
- **H1:** 40-80 bars

---

### Fair Value Gap

#### `InpFVG_MinPts` (Default: 150)

**What it does:** Minimum gap size (in points) to qualify as FVG.

**Calculation:** 150 points = 15 pips = $15 on 1 lot

**Purpose:** Filters out tiny insignificant gaps.

**Adjust for XAUUSD:**
- **Tight:** 180-200 points (large gaps only)
- **Standard:** 150 points
- **Loose:** 120 points (more FVGs)

#### `InpFVG_MitigatePct` (Default: 35.0)

**What it does:** Percentage of gap filled to change state from "Valid" to "Mitigated."

**States:**
- **Valid:** 0-34% filled - Best for entry
- **Mitigated:** 35-84% filled - Still valid but weaker
- **Completed:** 85%+ filled - No longer valid

**Adjust:**
- **Strict:** 25% (mark mitigated earlier)
- **Standard:** 35%
- **Loose:** 45% (allow more fill)

#### `InpFVG_CompletePct` (Default: 85.0)

**What it does:** Percentage filled to mark FVG as "Completed" (invalid).

**Recommendations:**
- **Strict:** 75-80% (invalidate earlier)
- **Standard:** 85%
- **Loose:** 90-95% (very permissive)

#### `InpFVG_TTL` (Default: 60)

**What it does:** How many bars FVG remains valid.

**Purpose:** FVGs lose significance over time.

**Recommendations:**
- **M15:** 50-80 bars
- **M30:** 30-50 bars

---

### Momentum (Optional)

#### `InpMomo_MinDispATR` (Default: 0.7)

**What it does:** Minimum body size (as ATR multiple) for consecutive bars to confirm momentum.

**Purpose:** Confirms strong directional move.

**Adjust:**
- **Volatile markets:** 0.8-1.0
- **Normal:** 0.7
- **Quiet:** 0.6

#### `InpMomo_FailBars` (Default: 4)

**What it does:** Number of bars without continued momentum to invalidate signal.

**Purpose:** Momentum should continue or signal is false.

#### `InpMomo_TTL` (Default: 20)

**What it does:** How many bars momentum signal remains valid.

---

### Execution

#### `InpTriggerBodyATR` (Default: 40)

**What it does:** Minimum trigger candle body size (as % of ATR, × 100).

**Meaning:**
- `40` = 0.40 × ATR(14)
- `50` = 0.50 × ATR(14)

**Purpose:** Confirms entry momentum at POI.

**Adjust:**
- **Strict:** 50-60 (stronger triggers only)
- **Standard:** 40
- **Loose:** 30 (more triggers)

#### `InpEntryBufferPts` (Default: 70)

**What it does:** Distance in points to place stop order beyond trigger candle high/low.

**Calculation:** 70 points = 7 pips

**Purpose:**
- Ensures order isn't triggered immediately
- Confirms continuation beyond trigger

**Adjust:**
- **Tight:** 50 points (earlier entry, more risk)
- **Standard:** 70 points
- **Safe:** 100 points (later entry, cleaner)

#### `InpMinStopPts` (Default: 300)

**What it does:** Minimum stop loss distance in points.

**Calculation:** 300 points = 30 pips = $30 per lot

**Purpose:** Prevents SL too close to price (gets stopped easily).

**Adjust for XAUUSD:**
- **Tight:** 250-300 points (during low volatility)
- **Standard:** 300-400 points
- **Wide:** 400-500 points (during high volatility)

#### `InpOrder_TTL_Bars` (Default: 5)

**What it does:** Number of bars before pending order is cancelled if not filled.

**Purpose:** Prevents old pending orders from filling at stale prices.

**Recommendations:**
- **Tight:** 3-4 bars
- **Standard:** 5 bars
- **Loose:** 7-10 bars

---

## Advanced Configurations

### Scalping Mode (Not Recommended)

```
InpMinRR = 1.5
InpMinStopPts = 200
InpEntryBufferPts = 40
InpOrder_TTL_Bars = 3
InpFVG_MinPts = 100
```

⚠️ **Warning:** Scalping on XAUUSD M15 contradicts SMC principles.

### Swing Trading Mode

```
// Use M30 or H1 timeframe
InpLookbackSwing = 80
InpMinRR = 3.0
InpMinStopPts = 500
InpOB_TTL = 200
InpFVG_TTL = 100
```

### High Volatility Adjustment

```
InpMinBodyATR = 0.8
InpMinBreakPts = 80
InpMinStopPts = 400
InpSpreadMaxPts = 50
InpDailyMddMax = 10.0
```

### Low Volatility Adjustment

```
InpMinBodyATR = 0.5
InpMinBreakPts = 40
InpMinStopPts = 250
InpFVG_MinPts = 120
```

---

## Broker-Specific Settings

### ECN Brokers (Low Spread)

```
InpSpreadMaxPts = 25
InpEntryBufferPts = 50
```

### Market Maker Brokers (Higher Spread)

```
InpSpreadMaxPts = 50
InpEntryBufferPts = 80
InpMinStopPts = 350
```

### Brokers with 4-Digit Quotes

```
InpPointsPerPip = 100  // CRITICAL!
InpMinBreakPts = 500   // 10x all point values
InpMinStopPts = 3000
InpEntryBufferPts = 700
// etc...
```

---

## Optimization Guidelines

### What to Optimize

**Primary (Most Impact):**
1. `InpMinBodyATR` (0.5 to 0.8, step 0.1)
2. `InpMinRR` (1.8 to 3.0, step 0.2)
3. `InpFVG_MinPts` (120 to 180, step 20)
4. `InpOB_MaxTouches` (2 to 4, step 1)

**Secondary:**
5. `InpFractalK` (2 to 4, step 1)
6. `InpMinBreakPts` (40 to 80, step 10)
7. `InpLookbackSwing` (40 to 70, step 10)

**DO NOT Optimize:**
- `InpRiskPerTradePct` (keep constant)
- `InpDailyMddMax` (keep constant)
- `InpSessStartHour/EndHour` (keep constant)

### Optimization Process

1. **Forward Testing:** Use 70% train / 30% test split
2. **Metric:** Optimize for **Profit Factor** or **Sharpe Ratio**, NOT net profit
3. **Walk-Forward:** 6-month optimize, 2-month forward test
4. **Validation:** Must work across multiple years

### Red Flags

- Win rate > 70% (likely curve-fitted)
- Profit Factor > 4.0 (likely curve-fitted)
- Parameters in extreme ranges
- Only works in one year

---

## Seasonal Adjustments

### Q1 (Jan-Mar) - High Volatility
```
InpMinStopPts = 400
InpSpreadMaxPts = 40
```

### Q2/Q3 (Apr-Sep) - Normal
```
// Use default settings
```

### Q4 (Oct-Dec) - Variable
```
InpDailyMddMax = 10.0  // More protection
```

---

## Final Recommendations

1. **Start with default settings** (Balanced profile)
2. **Test on demo** for at least 2 weeks
3. **Monitor daily MDD** - adjust if frequently hit
4. **Check logs** - verify structures are being detected
5. **Optimize cautiously** - small parameter changes only
6. **Keep risk low** - 0.3% or less per trade
7. **Review weekly** - adjust based on market conditions

---

**Questions?** Refer to `README.md` or MQL5 documentation.

