# 09. Ví Dụ Thực Tế (Examples)

## 📍 Tổng Quan

File này chứa các ví dụ chi tiết về:
1. **Complete Trade Scenarios** - Từ detection đến close
2. **Pattern Examples** - Các pattern types khác nhau
3. **Risk Management Examples** - DCA, BE, Trailing
4. **Edge Cases** - Các trường hợp đặc biệt

---

## 1️⃣ Complete Trade: Confluence Pattern

### 📊 Market Context
```
Symbol: XAUUSD
Timeframe: M15
Date: 2025-10-16 14:00 GMT+7
Balance: $10,000
```

### 🔍 PHASE 1: DETECTION

#### Signals Detected:
```
[14:00] BOS BULLISH detected!
  → Break Level: 2650.00 (swing high)
  → Distance: 85 points
  → Body: 0.68 ATR ✓
  → Direction: +1 (LONG)

[14:15] SWEEP LOW detected!
  → Level: 2648.50 (fractal low)
  → Side: -1 (sell-side)
  → Distance: 5 bars from fractal
  → Wick: 42% of candle range ✓

[14:15] ORDER BLOCK found!
  → Zone: 2649.00 - 2649.50
  → Direction: +1 (Demand)
  → Volume: 1.5× avg (STRONG)
  → Touches: 0
  → State: Valid ✓

[14:15] FVG detected!
  → Zone: 2649.20 - 2649.80
  → Direction: +1 (Bullish)
  → Size: 200 points
  → State: Valid (0% filled)

[14:15] MTF Bias: BULLISH
  → H1: Higher highs & higher lows
  → Bias: +1
```

### 🎯 PHASE 2: ARBITRATION

#### Build Candidate:
```cpp
Candidate:
  valid: true
  direction: +1 (LONG)
  
Signal Flags:
  hasBOS: true
  hasSweep: true
  hasOB: true
  hasFVG: true
  hasMomo: false
  
POI (from OB):
  poiTop: 2649.50
  poiBottom: 2649.00
  
Additional:
  obTouches: 0
  obStrong: true
  sweepDistanceBars: 5
  mtfBias: +1
```

#### Score Calculation:
```
Base: BOS + OB                   = +100
BOS Bonus                        = +30
Sweep                            = +25
Sweep Nearby (≤10 bars)          = +15
OB                               = +20
FVG Valid                        = +15
MTF Aligned                      = +20
OB Strong (vol 1.5× avg)         = +10
────────────────────────────────────
TOTAL SCORE:                     = 235 ⭐⭐⭐

Pattern Type: PATTERN_CONFLUENCE
Priority: EXCELLENT
```

### ⚡ PHASE 3: EXECUTION

#### Trigger Candle:
```
[14:30] Trigger BUY found!
  → Bar: 1 (previous candle)
  → Body: 0.40 ATR (>0.30 min)
  → High: 2650.10
  → Low: 2649.85
  → Close: 2650.05 (bullish)
```

#### Entry Calculation:
```
Entry = Trigger High + Buffer
      = 2650.10 + 0.07 (70 pts)
      = 2650.17

SL = Sweep Level - Buffer
   = 2648.50 - 0.07
   = 2648.43

TP = Entry + (Risk × MinRR)
   = 2650.17 + (1.74 × 2.0)
   = 2650.17 + 3.48
   = 2653.65

RR Ratio = (TP - Entry) / (Entry - SL)
         = 3.48 / 1.74
         = 2.0 ✓
```

#### Position Sizing:
```
Risk%: 0.5%
Risk Amount: $10,000 × 0.5% = $50
SL Distance: 174 points (17.4 pips)

XAUUSD:
  Tick Value: $1.00
  Tick Size: 0.01
  Value/Point: $0.01

Lots = $50 / (174 × $0.01)
     = $50 / $1.74
     = 28.74 lots (raw)
     
Limits:
  MaxLotPerSide: 3.0
  Final Lots: 3.0 ✓
```

#### Order Placement:
```
[14:30] Order placed: #12345
  Type: BUY STOP
  Entry: 2650.17
  SL: 2648.43
  TP: 2653.65
  Lots: 3.0
  Comment: "SMC_BUY_RR2.0"
  Magic: 20251013
```

### 📈 PHASE 4: RISK MANAGEMENT

#### Trade Timeline:

##### T1: Order Filled
```
[14:45] Order #12345 filled
  Fill Price: 2650.17
  → TrackPosition() called
  → originalSL saved: 2648.43
```

##### T2: DCA Level 1 (+0.75R)
```
[15:15] Price: 2651.47
  Profit: 130 points = 0.75R
  
  ✓ DCA Level 1 triggered!
  Add Lots: 3.0 × 0.5 = 1.5
  Check Limit: 3.0 + 1.5 = 4.5 vs MaxLot 5.0 ✓
  
  → DCA Position #12346 opened
  Entry: 2651.47
  SL: 2648.43 (same as original)
  TP: 2653.65 (same as original)
  Lots: 1.5
  
Total Position: 4.5 lots
```

##### T3: Breakeven (+1R)
```
[15:30] Price: 2651.91
  Profit: 174 points = 1.0R
  
  ✓ Breakeven triggered!
  
  Position #12345:
    SL: 2648.43 → 2650.17 (entry)
    
  Position #12346 (DCA):
    SL: 2648.43 → 2651.47 (its entry)
    
  → Risk eliminated!
```

##### T4: DCA Level 2 (+1.5R)
```
[16:00] Price: 2652.78
  Profit: 261 points = 1.5R
  
  ✓ DCA Level 2 triggered!
  Add Lots: 3.0 × 0.33 = 1.0
  Check Limit: 4.5 + 1.0 = 5.5 vs MaxLot 5.0 ❌
  
  → Capped to available: 5.0 - 4.5 = 0.5 lots
  
  → DCA Position #12347 opened
  Entry: 2652.78
  SL: 2650.17 (at BE)
  TP: 2653.65
  Lots: 0.5
  
Total Position: 5.0 lots (MAX)
```

##### T5: Trailing Start (+1.0R from BE)
```
[16:15] Price: 2652.65
  Profit from BE: 2652.65 - 2650.17 = 2.48 points
  Profit in R: 2.48 / 1.74 = 1.42R (>= TrailStartR 1.0)
  
  ✓ Trailing activated!
  ATR: 5.0 points
  Trail Distance: 2.0 × ATR = 10 points
  
  New SL = 2652.65 - 10 = 2652.55
  
  Update all positions:
    #12345: SL 2650.17 → 2652.55
    #12346: SL 2651.47 → 2652.55
    #12347: SL 2652.78 → 2652.78 (keep entry, better than 2652.55)
    
  lastTrailR = 1.42
```

##### T6: Continue Trailing (+1.5R from BE)
```
[16:30] Price: 2653.04
  Profit from BE: 2653.04 - 2650.17 = 2.87 points
  Profit in R: 2.87 / 1.74 = 1.65R
  
  Check: 1.65 - 1.42 = 0.23R (< TrailStepR 0.5)
  → Skip (not moved enough)
```

##### T7: Trail Again (+2.0R from BE)
```
[16:45] Price: 2653.52
  Profit in R: (2653.52 - 2650.17) / 1.74 = 1.93R
  
  Check: 1.93 - 1.42 = 0.51R (>= TrailStepR 0.5)
  
  ✓ Trail again!
  New SL = 2653.52 - 10 = 2653.42
  
  Update all positions:
    #12345: SL 2652.55 → 2653.42
    #12346: SL 2652.55 → 2653.42
    #12347: SL 2652.78 → 2653.42
    
  lastTrailR = 1.93
```

##### T8: TP Hit
```
[17:00] Price: 2653.65
  → TP reached!
  
Close all positions:
  #12345: Entry 2650.17 → 2653.65
    Profit: 3.48 × 3.0 lots = $10.44
    
  #12346: Entry 2651.47 → 2653.65
    Profit: 2.18 × 1.5 lots = $3.27
    
  #12347: Entry 2652.78 → 2653.65
    Profit: 0.87 × 0.5 lots = $0.43
    
Total Profit: $14.14
Profit %: +0.14%
```

### 📊 PHASE 5: ANALYTICS

```
Trade Summary:
──────────────────────────────────────
Ticket: #12345 (+ DCA #12346, #12347)
Pattern: CONFLUENCE
Direction: LONG
Entry: 2650.17
Close: 2653.65
Lots: 3.0 + 1.5 + 0.5 = 5.0
Duration: 2h 30min
Result: WIN ✅

Performance:
  Original Position: +2.0R
  With DCA: +2.3R (effective)
  Profit: $14.14
  ROI: +0.14%

Stats Update:
  Confluence: 13W/3L → 81.3% WR
  Overall: 46W/13L → 77.97% WR
  Profit Factor: 2.45
```

---

## 2️⃣ Example 2: BOS + OB Only

### 📊 Market Context
```
Symbol: XAUUSD
Timeframe: M15
Date: 2025-10-17 10:00 GMT+7
Balance: $10,014.14
```

### 🔍 Detection
```
BOS BEARISH:
  Break Level: 2645.00
  Direction: -1

ORDER BLOCK (Supply):
  Zone: 2646.50 - 2647.00
  Volume: 1.1× avg (Normal)
  Touches: 1

NO SWEEP
NO FVG
NO MOMENTUM

MTF Bias: NEUTRAL (0)
```

### 🎯 Scoring
```
Base: BOS + OB                   = +100
BOS Bonus                        = +30
OB                               = +20
Sweep: None                      = 0
MTF Neutral                      = 0
OB Normal (not strong)           = 0
────────────────────────────────────
TOTAL SCORE:                     = 150

Pattern: PATTERN_BOS_OB
Priority: GOOD (acceptable)
```

### ⚡ Execution
```
Trigger: Bearish candle (0.35 ATR)
Entry: 2646.43 (trigger low - buffer)
SL: 2647.57 (OB top + buffer)
TP: 2644.15 (2:1 RR)
Lots: 2.8 (based on risk calc)

Result: WIN +2.1R ($12.50)
```

---

## 3️⃣ Example 3: Failed Trade - Low Score

### 📊 Scenario
```
BOS BULLISH
OB: Weak (volume 0.9× avg)
OB Touches: 3 (at limit!)
MTF Bias: BEARISH (counter-trend!)
NO SWEEP
RR: 2.1
```

### 🎯 Scoring
```
Base: BOS + OB                   = +100
BOS Bonus                        = +30
OB                               = +20
MTF Counter-trend                = -30
OB Weak                          = -10
OB Max Touches (×0.5)            = ×0.5
────────────────────────────────────
Subtotal: 100+30+20-30-10        = 110
After penalty: 110 × 0.5         = 55 ❌

REJECTED: Score < 100
```

### ❌ Result
```
No entry placed
Entry skipped: Low quality setup
```

---

## 4️⃣ Example 4: Daily MDD Protection

### 📊 Scenario
```
Date: 2025-10-18
Start Balance (6h): $10,026.64
MDD Limit: -8% = -$802.13

Trade History:
────────────────────────────────────
08:00 - Trade #1: LOSS -$150 (-1.5%)
10:00 - Trade #2: LOSS -$200 (-2.0%)
12:00 - Trade #3: LOSS -$180 (-1.8%)
14:00 - Trade #4: LOSS -$100 (-1.0%)
16:00 - Trade #5: LOSS -$200 (-2.0%)
────────────────────────────────────
Total: -$830 (-8.28%)

Current Balance: $9,196.64
```

### 🛑 MDD Triggered
```
[16:15] Daily MDD Check
  Start Balance: $10,026.64
  Current Balance: $9,196.64
  Daily P/L: -8.28%
  MDD Limit: -8.0%
  
  ❌ DAILY MDD EXCEEDED!
  
Actions:
  1. Close all open positions (2 positions)
     #12350: LONG 2.5 lots → Closed at market
     #12351: SHORT 1.0 lot → Closed at market
     
  2. Set tradingHalted = true
  
  3. Log event:
     "⚠️ TRADING HALTED - Daily MDD -8.28%"
     "Will resume tomorrow at 6h GMT+7"
```

### 🔄 Next Day Reset
```
[2025-10-19 06:00] Daily Reset
  Previous Balance: $9,196.64
  New Start Balance: $9,196.64
  tradingHalted = false
  
  → Trading resumed ✓
  → New MDD Limit: -8% of $9,196.64 = -$735.73
```

---

## 5️⃣ Example 5: Basket TP

### 📊 Scenario
```
Balance: $10,000
Basket TP: +0.3% = +$30

Active Positions:
────────────────────────────────────
#12355: LONG 3.0 lots
  Entry: 2650.00
  Current: 2651.20
  Profit: +$12.00
  
#12356: LONG 1.5 lots (DCA)
  Entry: 2650.80
  Current: 2651.20
  Profit: +$6.00
  
#12357: SHORT 2.0 lots
  Entry: 2655.00
  Current: 2654.40
  Profit: +$12.00
────────────────────────────────────
Total Floating P/L: +$30.00 (+0.3%)
```

### ✅ Basket TP Hit
```
[15:30] Basket TP Check
  Floating P/L: +$30.00
  P/L %: +0.30%
  Basket TP: +0.30%
  
  ✓ Basket TP Hit!
  
Actions:
  Close all 3 positions at market
  
  #12355: Closed at 2651.20 → +$12.00
  #12356: Closed at 2651.20 → +$6.00
  #12357: Closed at 2654.40 → +$12.00
  
Total Realized: +$30.00 (+0.30%)
New Balance: $10,030.00
```

---

## 6️⃣ Example 6: Edge Case - Orphan DCA

### 📊 Scenario
```
Original Position #12360:
  Entry: 2650.00
  SL: 2649.00
  Lots: 3.0
  
DCA #1 Added #12361:
  Entry: 2650.75 (+0.75R)
  Lots: 1.5
  
Price hits TP for #12360
  → Original position closed
  → DCA #12361 still open (orphan!)
```

### 🔧 Orphan Management
```
Orphan Detection:
  Position #12361 not in tracked array
  Comment: "DCA Add-on"
  
  → Identified as orphan DCA
  
Management:
  1. Calculate profitR using current SL
  2. Apply Trailing if profit >= 1R
  3. Apply BE if profit >= 1R
  
Example:
  Current: 2652.00
  Entry: 2650.75
  Current SL: 2650.00 (was at BE)
  
  Profit: 1.25 points
  R (approx): 1.25 / 1.00 = 1.25R
  
  ✓ Trail SL: 2650.00 → 2651.90
  
  → Orphan DCA managed successfully!
```

---

## 7️⃣ Example 7: Fixed SL Mode

### 📊 Configuration
```
InpUseFixedSL: true
InpFixedSL_Pips: 100
InpFixedTP_Enable: true
InpFixedTP_Pips: 200
```

### 🔍 Setup Detection
```
BOS BULLISH
OB: 2649.00 - 2649.50
Sweep: 2648.50

Trigger: 2650.10
```

### ⚡ Entry Calculation
```
STEP 1: Calculate METHOD-based SL & TP
  Method SL = Sweep - buffer
            = 2648.50 - 0.07
            = 2648.43
            
  Method Risk = Entry - Method SL
              = 2650.10 - 2648.43
              = 1.67 (167 points)
              
  Method TP = Entry + (Risk × 2.0)
            = 2650.10 + 3.34
            = 2653.44

STEP 2: Apply FIXED SL (override method)
  Fixed SL = Entry - (100 pips × 10 pts)
           = 2650.10 - 10.00
           = 2640.10
  
  → Use Fixed SL: 2640.10 ✅

STEP 3: Apply FIXED TP (absolute)
  Fixed TP = Entry + (200 pips × 10 pts)
           = 2650.10 + 20.00
           = 2670.10
  
  → Use Fixed TP: 2670.10 ✅

Final Order:
  Entry: 2650.10
  SL: 2640.10 (100 pips fixed)
  TP: 2670.10 (200 pips fixed)
  RR: 2.0 (fixed)
  Lots: Based on 1000 pts SL distance
```

### ⚠️ Note
```
Fixed mode decouples SL/TP from market structure
- Pros: Consistent risk size
- Cons: May not align with support/resistance
```

---

## 📊 Summary Table

| Example | Pattern | Score | Result | Profit | Notes |
|---------|---------|-------|--------|--------|-------|
| 1. Confluence | CONFLUENCE | 235 | WIN | +$14.14 | Full DCA, Trailing |
| 2. BOS+OB | BOS_OB | 150 | WIN | +$12.50 | Simple setup |
| 3. Weak Setup | BOS_OB | 55 | SKIPPED | $0 | Below threshold |
| 4. MDD Hit | - | - | HALTED | -$830 | Protection worked |
| 5. Basket TP | Mixed | - | WIN | +$30 | Multiple positions |
| 6. Orphan DCA | - | - | Managed | - | Edge case handled |
| 7. Fixed SL | BOS_OB | - | - | - | Config override |

---

## 🎓 Key Takeaways

### ✅ Best Practices
1. **Confluence setups** (BOS + Sweep + OB/FVG) have highest win rate
2. **DCA** significantly increases profit when trade goes in favor
3. **Trailing** locks in profits while letting winners run
4. **Daily MDD** protection prevents account blowup
5. **Basket management** takes profits early when multiple positions align

### ⚠️ Watch Out For
1. **Low score setups** (<100) - skip them!
2. **Counter-trend trades** (MTF against) - high risk
3. **Weak OBs** with many touches - lower success rate
4. **Orphan DCAs** - ensure they're still managed
5. **Fixed SL mode** - may not respect market structure

### 📈 Performance Tips
1. Prioritize CONFLUENCE patterns (200+ score)
2. Use DCA cautiously - only when trade is clearly winning
3. Trail aggressively once in profit
4. Respect Daily MDD - better to stop early than blow account
5. Monitor dashboard regularly for health metrics

