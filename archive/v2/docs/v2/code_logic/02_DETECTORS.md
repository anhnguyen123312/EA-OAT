# 02. Phát Hiện Tín Hiệu (Detectors)

## 📍 Tổng Quan

**File**: `detectors.mqh`

Lớp `CDetector` chịu trách nhiệm quét và phát hiện các cấu trúc thị trường theo phương pháp SMC/ICT:
- **BOS** (Break of Structure / CHOCH)
- **Liquidity Sweep**
- **Order Block** (Demand/Supply zones)
- **Fair Value Gap** (Imbalance)
- **Momentum Breakout**

---

## 1️⃣ BOS - Break of Structure

### 🎯 Mục Đích
Xác định trend direction và structural shift trong thị trường.

### 📝 Định Nghĩa

**Bullish BOS**: Price close **vượt trên** swing high gần nhất  
**Bearish BOS**: Price close **vượt dưới** swing low gần nhất

### ⚙️ Thuật Toán

```cpp
BOSSignal DetectBOS() {
    1. Tìm last swing high/low (dựa trên Fractal K=3)
       trong lookback window (50 bars)
    
    2. Kiểm tra điều kiện:
       ✓ Current close > swing high (bullish)
          OR current close < swing low (bearish)
       ✓ Break distance >= MinBreakPts (70 points)
       ✓ Candle body >= MinBodyATR (0.6 ATR)
    
    3. Return BOSSignal với:
       - direction: 1 (bullish) or -1 (bearish)
       - breakLevel: swing price broken
       - valid: true
       - ttl: 60 bars
}
```

### 📊 Điều Kiện Chi Tiết

| Điều Kiện | Giá Trị | Mô Tả |
|-----------|---------|-------|
| `FractalK` | 3 | Số bars left/right để xác định swing |
| `LookbackSwing` | 50 | Lookback window (bars) |
| `MinBodyATR` | 0.6 | Min body size (× ATR) |
| `MinBreakPts` | 70 | Min break distance (points) |
| `BOS_TTL` | 60 | Time to live (bars) |

### 💡 Ví Dụ

#### Bullish BOS:
```
Price action:
─────────────────────────────────────
         ┌─ Current close (2655.00)
         │  ✓ Vượt swing high
         │  ✓ Body = 0.65 ATR
         │  ✓ Distance = 80 pts
         ▼
    ─────●───── Swing High (2654.00)
      ╱ ╲
     ╱   ╲
    ●     ●
    
→ BOS Bullish detected!
→ Direction: +1
→ Break Level: 2654.00
```

#### Bearish BOS:
```
Price action:
─────────────────────────────────────
    ●     ●
     ╲   ╱
      ╲ ╱
    ─────●───── Swing Low (2645.00)
         ▲
         │  ✓ Phá xuống swing low
         │  ✓ Body = 0.70 ATR
         │  ✓ Distance = 90 pts
         └─ Current close (2644.00)

→ BOS Bearish detected!
→ Direction: -1
→ Break Level: 2645.00
```

### 🔍 Code Snippet
```cpp
// Tìm swing high
Swing FindLastSwingHigh(int lookback) {
    for(int i = K + 1; i < lookback; i++) {
        if(IsSwingHigh(i, K)) {
            return {index: i, price: high[i], time: ...};
        }
    }
    return invalid;
}

// Kiểm tra swing high
bool IsSwingHigh(int index, int K) {
    double h = high[index];
    for(int k = 1; k <= K; k++) {
        if(h <= high[index-k] || h <= high[index+k])
            return false;
    }
    return true;
}
```

---

## 2️⃣ Liquidity Sweep

### 🎯 Mục Đích
Phát hiện khi price "quét" liquidity tại các fractal high/low rồi reverse.

### 📝 Định Nghĩa

**Buy-Side Sweep**: Price wick **trên** fractal high, nhưng **close dưới**  
**Sell-Side Sweep**: Price wick **dưới** fractal low, nhưng **close trên**

### ⚙️ Thuật Toán

```cpp
SweepSignal DetectSweep() {
    1. Scan bars 0-3 (recent candles)
    
    2. For each bar:
       - Tìm fractal high/low trong lookback (40 bars)
       - Skip bars quá gần (skipBars = 1)
    
    3. Check BUY-SIDE SWEEP:
       ✓ Current high > fractal high
       ✓ Current close < fractal high
          OR upper wick >= 35% of candle range
    
    4. Check SELL-SIDE SWEEP:
       ✓ Current low < fractal low
       ✓ Current close > fractal low
          OR lower wick >= 35% of candle range
    
    5. Return first sweep found
}
```

### 📊 Điều Kiện Chi Tiết

| Điều Kiện | Giá Trị | Mô Tả |
|-----------|---------|-------|
| `LookbackLiq` | 40 | Lookback window (bars) |
| `MinWickPct` | 35% | Min wick percentage |
| `Sweep_TTL` | 24 | Time to live (bars) |
| `FractalK` | 3 | Swing detection |

### 💡 Ví Dụ

#### Sell-Side Sweep:
```
Price action:
─────────────────────────────────────
          ╱╲  ← Rejection wick
         ╱  ╲    (45% of range)
        ╱    ╲
       │ Close│ (2651.00)
       └──────┘
         │
         │ ← Swept below fractal
         ▼
    ─────●───── Fractal Low (2650.50)
    
→ SELL-SIDE SWEEP detected!
→ Level: 2650.50
→ Side: -1
→ Distance: 5 bars from fractal
```

#### Buy-Side Sweep:
```
Price action:
─────────────────────────────────────
    ─────●───── Fractal High (2655.00)
         ▲
         │ ← Swept above fractal
         │
       ┌──────┐
       │ Close│ (2654.50)
        ╲    ╱
         ╲  ╱    ← Rejection wick
          ╲╱       (40% of range)
          
→ BUY-SIDE SWEEP detected!
→ Level: 2655.00
→ Side: +1
→ Distance: 3 bars from fractal
```

### 🔍 Thuật Toán Nâng Cao

```cpp
// Multi-candle sweep detection
for(int i = 0; i <= 3; i++) {
    for(int j = i + skipBars + 1; j <= lookbackLiq; j++) {
        
        // Check if j is fractal high
        if(IsSwingHigh(j, K)) {
            double fractalHigh = high[j];
            double upperWick = high[i] - Max(close[i], open[i]);
            double upperWickPct = (upperWick / range[i]) × 100;
            
            if(high[i] > fractalHigh && 
               (close[i] < fractalHigh || upperWickPct >= 35%)) {
                // BUY-SIDE SWEEP!
                return {side: 1, level: fractalHigh, ...};
            }
        }
        
        // Check if j is fractal low (similar logic)
        ...
    }
}
```

---

## 3️⃣ Order Block (OB)

### 🎯 Mục Đích
Tìm demand/supply zones - nơi institutional orders đã được đặt.

### 📝 Định Nghĩa

**Bullish OB (Demand)**: Last **bearish** candle trước khi price rally  
**Bearish OB (Supply)**: Last **bullish** candle trước khi price drop

### ⚙️ Thuật Toán

```cpp
OrderBlock FindOB(int direction) {
    if(direction == 1) {  // Looking for BULLISH OB
        1. Scan bars 5-80
        2. Tìm bearish candle (close < open)
        3. Check displacement:
           ✓ close[i-1] > high[i+1]  (rally after OB)
        4. OB zone = [low[i], close[i]]
        5. Count touches (price quay lại zone)
        6. Check volume:
           - Volume < 1.3× avg → weak = true
           - Volume >= 1.3× avg → strong OB
        7. Check invalidation:
           - Close > priceTop + buffer → Breaker Block
    }
    
    if(direction == -1) {  // Looking for BEARISH OB
        (similar logic, opposite direction)
    }
}
```

### 📊 Điều Kiện Chi Tiết

| Điều Kiện | Giá Trị | Mô Tả |
|-----------|---------|-------|
| `OB_MaxTouches` | 3 | Max touches before invalid |
| `OB_BufferInvPts` | 70 | Buffer for invalidation (pts) |
| `OB_TTL` | 160 | Time to live (bars) |
| `OB_VolMultiplier` | 1.3 | Strong OB volume threshold |

### 💡 Ví Dụ

#### Bullish OB (Demand):
```
Price action:
─────────────────────────────────────
              ╱│ ← Rally (displacement)
             ╱ │
            ╱  │
           ╱   │
          ╱    │
    ┌────┐     │
    │ OB │     │  Bearish candle
    └────┘←────┘  (last before rally)
    2649.00
    2649.50
    
→ BULLISH OB found!
→ Zone: 2649.00 - 2649.50
→ Volume: 1.5× avg (STRONG)
→ Touches: 0
→ Valid for 160 bars
```

#### OB → Breaker Block:
```
Price action:
─────────────────────────────────────
Original BULLISH OB:
    ┌────┐
    │ OB │ Zone: 2649.00 - 2649.50
    └────┘

Price closes ABOVE priceTop + buffer:
                 ╱│ Close: 2650.30
                ╱ │ (> 2649.50 + 70pts buffer)
               ╱  │
    ──────────────●─── Invalidation!
    ┌────┐
    │ OB │ → Breaker Block
    └────┘   (flipped to BEARISH)

→ OB invalidated!
→ Converted to BEARISH Breaker Block
→ Can use as resistance
```

### 🔍 Volume Filter

```cpp
// Calculate avg volume of past 20 bars
long sumVol = 0;
int volCount = 0;
for(int k = startIdx; k < startIdx + 20; k++) {
    sumVol += volume[k];
    volCount++;
}
double avgVol = sumVol / volCount;

// Check OB strength
if(ob.volume < avgVol × 1.3) {
    ob.weak = true;  // Weak OB
} else {
    ob.weak = false; // Strong OB
}
```

---

## 4️⃣ Fair Value Gap (FVG)

### 🎯 Mục Đích
Tìm imbalance zones - gaps mà price có thể quay lại fill.

### 📝 Định Nghĩa

**Bullish FVG**: Gap giữa `low[i]` và `high[i+2]` (low > high)  
**Bearish FVG**: Gap giữa `high[i]` và `low[i+2]` (high < low)

### ⚙️ Thuật Toán

```cpp
FVGSignal FindFVG(int direction) {
    1. Scan bars 2-60
    
    2. If direction == 1 (Bullish FVG):
       ✓ low[i] > high[i+2]
       ✓ gapSize >= MinFVG_Pts (180 points)
       → FVG zone: [high[i+2], low[i]]
    
    3. If direction == -1 (Bearish FVG):
       ✓ high[i] < low[i+2]
       ✓ gapSize >= MinFVG_Pts
       → FVG zone: [high[i], low[i+2]]
    
    4. Calculate fill percentage:
       - Scan bars i-1 down to 0
       - Check how much gap has been filled
       - fillPct = (filledAmount / gapSize) × 100
    
    5. Determine state:
       - fillPct < 35%  → Valid (0)
       - fillPct < 85%  → Mitigated (1)
       - fillPct >= 85% → Completed (2)
    
    6. Check invalidation:
       - Close beyond opposite edge → invalid
}
```

### 📊 Điều Kiện Chi Tiết

| Điều Kiện | Giá Trị | Mô Tả |
|-----------|---------|-------|
| `FVG_MinPts` | 180 | Min FVG size (points) |
| `FVG_FillMinPct` | 25% | Min fill to track |
| `FVG_MitigatePct` | 35% | Mitigation threshold |
| `FVG_CompletePct` | 85% | Completion threshold |
| `FVG_BufferInvPt` | 70 | Invalidation buffer (pts) |
| `FVG_TTL` | 70 | Time to live (bars) |
| `FVG_KeepSide` | 6 | Max FVGs per side |

### 💡 Ví Dụ

#### Bullish FVG:
```
Price formation:
─────────────────────────────────────
Bar [i]:     │╲
             │ ╲
             │  ╲ low[i] = 2655.00
             │   ╲
             
    GAP!     │
    (200pts) │    ← BULLISH FVG
             │       Zone: 2653.00 - 2655.00
             
Bar [i+2]:   │   ╱
             │  ╱ high[i+2] = 2653.00
             │ ╱
             │╱

→ BULLISH FVG detected!
→ Size: 200 points (>180 min)
→ State: Valid (0% filled)
→ Can be used as entry zone
```

#### FVG States:
```
FVG Zone: 2653.00 - 2655.00 (200 pts)

STATE 0 - VALID:
    ──────────────── 2655.00 (top)
    │   FVG ZONE   │
    │   0% filled  │  ← Fresh gap
    ──────────────── 2653.00 (bottom)

STATE 1 - MITIGATED:
    ──────────────── 2655.00
    │///////////////│ ← Price touched
    │   50% filled │    40% of gap
    │               │
    ──────────────── 2653.00

STATE 2 - COMPLETED:
    ──────────────── 2655.00
    │///////////////│ ← Price filled
    │///////////////│    90% of gap
    │///////////////│
    ──────────────── 2653.00
    → FVG.valid = false
```

### 🔍 Fill Calculation

```cpp
// Calculate fill percentage
double gapFilled = 0;
for(int j = i - 1; j >= 0; j--) {
    if(low[j] <= fvg.priceTop) {
        double fillLevel = Min(low[j], fvg.priceTop);
        gapFilled = Max(gapFilled, fvg.priceTop - fillLevel);
    }
}
fvg.fillPct = (gapFilled / fvg.initialSize) × 100.0;

// Determine state
if(fillPct < 35%)      state = 0;  // Valid
else if(fillPct < 85%) state = 1;  // Mitigated
else                   state = 2;  // Completed
```

---

## 5️⃣ Momentum Breakout

### 🎯 Mục Đích
Phát hiện strong momentum moves có thể lead to quick profits.

### 📝 Định Nghĩa

**Momentum**: ≥2 consecutive large-body candles cùng direction, breaking minor swing.

### ⚙️ Thuật Toán

```cpp
MomentumSignal DetectMomentum() {
    1. Check BULLISH momentum:
       - Count consecutive bullish bars (0-4)
       - Each bar body >= MinDispATR (0.7 ATR)
       - Must have >= 2 consecutive
    
    2. If bullish count >= 2:
       - Find minor swing high (K=2) in last 20 bars
       - Check if current close > minor swing price
       → Momentum valid!
    
    3. Check BEARISH momentum:
       (similar logic, opposite direction)
    
    4. Return MomentumSignal:
       - direction: +1 or -1
       - consecutiveBars: count
       - valid: true
       - ttl: 20 bars
}
```

### 📊 Điều Kiện Chi Tiết

| Điều Kiện | Giá Trị | Mô Tả |
|-----------|---------|-------|
| `Momo_MinDispATR` | 0.7 | Min body size (× ATR) |
| `Momo_FailBars` | 4 | Bars to confirm/fail |
| `Momo_TTL` | 20 | Time to live (bars) |
| Min Consecutive | 2 | Min consecutive bars |

### 💡 Ví Dụ

#### Bullish Momentum:
```
Price action:
─────────────────────────────────────
    ───●─── Minor Swing High (2652.00)
       │
       │ ← Break!
       │
    ┌──┴──┐ Bar 2: body = 0.75 ATR
    │  ▲  │ Close: 2652.50
    └─────┘
    ┌─────┐ Bar 1: body = 0.80 ATR
    │  ▲  │ Close: 2651.20
    └─────┘
    ┌─────┐ Bar 0: body = 0.85 ATR
    │  ▲  │ Close: 2653.00
    └─────┘

→ BULLISH MOMENTUM detected!
→ Consecutive: 3 bars
→ Minor swing broken at 2652.00
→ Valid for 20 bars
```

### 🔍 Code Snippet

```cpp
// Check consecutive bullish bars
int bullishCount = 0;
for(int i = 0; i < 5; i++) {
    double body = close[i] - open[i];
    if(body >= minBodySize) {
        bullishCount++;
    } else {
        break;  // Streak broken
    }
}

if(bullishCount >= 2) {
    // Find minor swing (K=2)
    Swing minorSwing = FindSwingHigh(20, K=2);
    
    if(close[0] > minorSwing.price) {
        // MOMENTUM VALID!
        return {valid: true, direction: 1, ...};
    }
}
```

---

## 6️⃣ MTF Bias (Multi-Timeframe)

### 🎯 Mục Đích
Xác định trend của higher timeframe để filter trades.

### ⚙️ Thuật Toán

```cpp
int GetMTFBias() {
    1. Determine higher TF:
       M15/M30 → H1
       H1 → H4
       H4 → D1
    
    2. Get price data from higher TF (50 bars)
    
    3. Find last 2 swing highs & 2 swing lows (K=2)
    
    4. Determine bias:
       - Higher highs AND higher lows → Bullish (+1)
       - Lower highs AND lower lows → Bearish (-1)
       - Mixed → Neutral (0)
    
    5. Return bias for scoring
}
```

### 💡 Ví Dụ

#### Bullish HTF Bias:
```
H1 Timeframe:
─────────────────────────────────────
           ●  High2 (2660.00)
          ╱
         ╱
    ●───────  High1 (2655.00)
   ╱         ╲
  ╱           ╲
 ●             ●  Low2 (2650.00)
Low1 (2645.00)

→ Higher highs: 2655 < 2660 ✓
→ Higher lows: 2645 < 2650 ✓
→ MTF Bias: BULLISH (+1)
→ Bonus: +20 if direction matches
```

---

## 📊 Tổng Hợp Tham Số

### BOS Detection
```cpp
InpFractalK        = 3      // Fractal K
InpLookbackSwing   = 50     // Lookback (bars)
InpMinBodyATR      = 0.6    // Min body (× ATR)
InpMinBreakPts     = 70     // Min break (points)
InpBOS_TTL         = 60     // TTL (bars)
```

### Sweep Detection
```cpp
InpLookbackLiq     = 40     // Lookback (bars)
InpMinWickPct      = 35.0   // Min wick (%)
InpSweep_TTL       = 24     // TTL (bars)
```

### Order Block
```cpp
InpOB_MaxTouches   = 3      // Max touches
InpOB_BufferInvPts = 70     // Invalidation buffer (pts)
InpOB_TTL          = 160    // TTL (bars)
InpOB_VolMultiplier= 1.3    // Strong OB threshold
```

### Fair Value Gap
```cpp
InpFVG_MinPts      = 180    // Min size (points)
InpFVG_FillMinPct  = 25.0   // Min fill (%)
InpFVG_MitigatePct = 35.0   // Mitigate threshold (%)
InpFVG_CompletePct = 85.0   // Complete threshold (%)
InpFVG_BufferInvPt = 70     // Invalidation buffer (pts)
InpFVG_TTL         = 70     // TTL (bars)
InpK_FVG_KeepSide  = 6      // Max FVGs per side
```

### Momentum
```cpp
InpMomo_MinDispATR = 0.7    // Min displacement (× ATR)
InpMomo_FailBars   = 4      // Bars to confirm/fail
InpMomo_TTL        = 20     // TTL (bars)
```

---

---

## 🆕 v2.1 Advanced Detection Features

### 1. OB với Sweep Validation (High Priority)

#### 🎯 Mục Đích
Xác nhận Order Block có liquidity sweep liên quan, tăng độ tin cậy của setup.

#### 📝 Định Nghĩa

**OB với Sweep**: Order Block mà có Sweep level **BÊN TRONG** hoặc **SÁT** OB zone.

**Bullish OB với Sweep**:
- OB Demand zone: [bottom, top]
- Cần có Sell-Side Sweep level ≤ OB bottom (bên dưới hoặc trong zone)

**Bearish OB với Sweep**:
- OB Supply zone: [bottom, top]  
- Cần có Buy-Side Sweep level ≥ OB top (bên trên hoặc trong zone)

#### ⚙️ Thuật Toán

```cpp
struct OrderBlock {
    // ... existing fields ...
    
    // NEW v2.1
    bool hasSweepNearby;       // Có sweep gần OB
    double sweepLevel;         // Giá của sweep
    int sweepDistancePts;      // Khoảng cách OB - Sweep (points)
    double sweepQuality;       // Chất lượng sweep (0-1)
};

OrderBlock FindOBWithSweep(int direction, SweepSignal sweep) {
    // STEP 1: Tìm OB như bình thường
    OrderBlock ob = FindOB(direction);
    if(!ob.valid) return ob;
    
    // STEP 2: Check sweep relationship
    if(direction == 1) {
        // BULLISH OB: Cần SELL-SIDE sweep (side = -1)
        if(sweep.valid && sweep.side == -1) {
            
            // Case A: Sweep BÊN DƯỚI OB (ideal)
            if(sweep.level <= ob.priceBottom) {
                double distance = ob.priceBottom - sweep.level;
                ob.sweepDistancePts = (int)(distance / _Point);
                
                // Sweep càng gần càng tốt (< 100 points)
                if(ob.sweepDistancePts <= 100) {
                    ob.hasSweepNearby = true;
                    ob.sweepLevel = sweep.level;
                    
                    // Quality: 1.0 nếu rất gần, giảm dần
                    ob.sweepQuality = 1.0 - (ob.sweepDistancePts / 200.0);
                    ob.sweepQuality = MathMax(0.0, ob.sweepQuality);
                }
            }
            
            // Case B: Sweep TRONG OB zone (less ideal nhưng OK)
            else if(sweep.level >= ob.priceBottom && 
                    sweep.level <= ob.priceTop) {
                ob.hasSweepNearby = true;
                ob.sweepLevel = sweep.level;
                ob.sweepDistancePts = 0; // Inside zone
                ob.sweepQuality = 0.8; // Slightly lower quality
            }
        }
    }
    else if(direction == -1) {
        // BEARISH OB: Cần BUY-SIDE sweep (side = +1)
        if(sweep.valid && sweep.side == 1) {
            
            // Case A: Sweep BÊN TRÊN OB (ideal)
            if(sweep.level >= ob.priceTop) {
                double distance = sweep.level - ob.priceTop;
                ob.sweepDistancePts = (int)(distance / _Point);
                
                if(ob.sweepDistancePts <= 100) {
                    ob.hasSweepNearby = true;
                    ob.sweepLevel = sweep.level;
                    ob.sweepQuality = 1.0 - (ob.sweepDistancePts / 200.0);
                    ob.sweepQuality = MathMax(0.0, ob.sweepQuality);
                }
            }
            
            // Case B: Sweep TRONG OB zone
            else if(sweep.level <= ob.priceTop && 
                    sweep.level >= ob.priceBottom) {
                ob.hasSweepNearby = true;
                ob.sweepLevel = sweep.level;
                ob.sweepDistancePts = 0;
                ob.sweepQuality = 0.8;
            }
        }
    }
    
    return ob;
}
```

#### 💡 Ví Dụ

##### Example 1: OB với Sweep Lý Tưởng
```
Price action (BULLISH setup):
─────────────────────────────────────

Bar 50: Rally bắt đầu
        │
        │  ┌────────┐
        │  │   OB   │ 2649.00 - 2649.50
        │  │ DEMAND │
        │  └────────┘
        │      ▲
        │      │ Distance: 30 pts
        │      │
Bar 55: ●────── Sweep Level: 2648.70
        SELL-SIDE SWEEP

→ OB.hasSweepNearby = true
→ OB.sweepDistancePts = 30
→ OB.sweepQuality = 0.85
→ Bonus: +20 điểm (high confidence)
```

##### Example 2: Sweep Trong OB Zone
```
Price action (BULLISH setup):
─────────────────────────────────────
        │  ┌────────┐ 2649.50 (top)
        │  │        │
Bar 53: ●──┼ Sweep  │ 2649.20 ← INSIDE zone
        │  │        │
        │  │   OB   │
        │  └────────┘ 2649.00 (bottom)

→ OB.hasSweepNearby = true
→ OB.sweepDistancePts = 0 (inside)
→ OB.sweepQuality = 0.8
→ Bonus: +15 điểm (good but not ideal)
```

##### Example 3: Sweep Quá Xa
```
Price action (BULLISH setup):
─────────────────────────────────────
        │  ┌────────┐
        │  │   OB   │ 2649.00 - 2649.50
        │  └────────┘
        │      
        │ Distance: 150 pts (TOO FAR)
        │      
Bar 60: ●────── Sweep Level: 2647.50

→ OB.hasSweepNearby = false
→ Không bonus
→ OB vẫn valid nhưng confidence thấp hơn
```

#### 📊 Scoring Impact

```cpp
// In Arbiter scoring:
if(c.hasOB && c.obHasSweep) {
    if(c.obSweepQuality >= 0.8) {
        score += 20;
        Print("✨ OB with nearby sweep (+20)");
    } else if(c.obSweepQuality >= 0.5) {
        score += 15;
        Print("✨ OB with sweep (+15)");
    } else {
        score += 10;
        Print("✨ OB with distant sweep (+10)");
    }
}
```

---

### 2. FVG MTF Overlap (Subset Validation)

#### 🎯 Mục Đích
Xác nhận FVG trên current timeframe được support bởi FVG trên higher timeframe, tạo confluence mạnh.

#### 📝 Định Nghĩa

**FVG MTF Overlap**: FVG trên M15/M30 là **TẬP CON** của FVG trên H1/H4.

**Điều kiện Overlap (Subset)**:
- Cùng direction (bullish/bearish)
- LTF FVG zone **NẰM TRONG** HTF FVG zone
- Cho phép chênh lệch nhỏ (tolerance)

#### ⚙️ Thuật Toán

```cpp
struct FVGSignal {
    // ... existing fields ...
    
    // NEW v2.1
    bool mtfOverlap;           // HTF confirmation
    double htfFVGTop;          // HTF FVG top
    double htfFVGBottom;       // HTF FVG bottom
    double overlapRatio;       // % overlap (0-1)
    ENUM_TIMEFRAMES htfPeriod; // Which HTF
};

bool CheckFVGMTFOverlap(FVGSignal &ltfFVG) {
    // STEP 1: Determine HTF
    ENUM_TIMEFRAMES htf = PERIOD_H1;
    if(_Period == PERIOD_M15 || _Period == PERIOD_M30) {
        htf = PERIOD_H1;
    } else if(_Period == PERIOD_H1) {
        htf = PERIOD_H4;
    }
    
    // STEP 2: Get HTF data
    double htfHigh[], htfLow[], htfClose[];
    ArraySetAsSeries(htfHigh, true);
    ArraySetAsSeries(htfLow, true);
    ArraySetAsSeries(htfClose, true);
    
    CopyHigh(_Symbol, htf, 0, 60, htfHigh);
    CopyLow(_Symbol, htf, 0, 60, htfLow);
    CopyClose(_Symbol, htf, 0, 60, htfClose);
    
    // STEP 3: Scan for HTF FVG in same direction
    for(int i = 2; i < 60; i++) {
        if(ltfFVG.direction == 1) {
            // BULLISH: Check if low[i] > high[i+2]
            if(htfLow[i] > htfHigh[i+2]) {
                double htfTop = htfLow[i];
                double htfBottom = htfHigh[i+2];
                double htfSize = htfTop - htfBottom;
                
                // Validate HTF FVG size (min 200 pts for H1)
                if(htfSize >= 200 * _Point) {
                    
                    // STEP 4: Check SUBSET relationship
                    // LTF phải NẰM TRONG HTF (có tolerance)
                    double tolerance = 50 * _Point; // ±50 pts
                    
                    if(ltfFVG.priceBottom >= (htfBottom - tolerance) &&
                       ltfFVG.priceTop <= (htfTop + tolerance)) {
                        
                        // SUBSET confirmed!
                        ltfFVG.mtfOverlap = true;
                        ltfFVG.htfFVGTop = htfTop;
                        ltfFVG.htfFVGBottom = htfBottom;
                        ltfFVG.htfPeriod = htf;
                        
                        // Calculate overlap ratio
                        double ltfSize = ltfFVG.priceTop - ltfFVG.priceBottom;
                        ltfFVG.overlapRatio = ltfSize / htfSize;
                        
                        Print("🎯 FVG MTF Overlap: LTF ", 
                              ltfFVG.priceBottom, "-", ltfFVG.priceTop,
                              " ⊂ HTF ", htfBottom, "-", htfTop);
                        
                        return true;
                    }
                }
            }
        }
        else if(ltfFVG.direction == -1) {
            // BEARISH: Check if high[i] < low[i+2]
            if(htfHigh[i] < htfLow[i+2]) {
                double htfBottom = htfHigh[i];
                double htfTop = htfLow[i+2];
                double htfSize = htfTop - htfBottom;
                
                if(htfSize >= 200 * _Point) {
                    double tolerance = 50 * _Point;
                    
                    if(ltfFVG.priceBottom >= (htfBottom - tolerance) &&
                       ltfFVG.priceTop <= (htfTop + tolerance)) {
                        
                        ltfFVG.mtfOverlap = true;
                        ltfFVG.htfFVGTop = htfTop;
                        ltfFVG.htfFVGBottom = htfBottom;
                        ltfFVG.htfPeriod = htf;
                        ltfFVG.overlapRatio = 
                            (ltfFVG.priceTop - ltfFVG.priceBottom) / htfSize;
                        
                        return true;
                    }
                }
            }
        }
    }
    
    return false; // No HTF overlap found
}
```

#### 💡 Ví Dụ

##### Example 1: Perfect Subset
```
Timeframe: M30 (current)
─────────────────────────────────────

M30 FVG (Bullish):
    2649.00 ━━━━━━━━ Top
    │   LTF FVG   │
    │   200 pts   │
    2647.00 ━━━━━━━━ Bottom

H1 FVG (Bullish):
    2650.00 ════════ Top
    │              │
    │   HTF FVG   │
    │   400 pts   │  ← M30 FVG NẰM TRONG H1
    │              │
    2646.00 ════════ Bottom

→ M30 [2647.00-2649.00] ⊂ H1 [2646.00-2650.00] ✓
→ mtfOverlap = true
→ overlapRatio = 200/400 = 0.5
→ Bonus: +25 điểm (very high confidence)
```

##### Example 2: Partial Overlap (Invalid)
```
M30 FVG: 2649.00 - 2651.00
H1 FVG:  2648.00 - 2650.00

    2651.00 ━━━━  M30 Top (NGOÀI H1!)
    2650.00 ════  H1 Top
    2649.00 ━━━━  M30 Bottom
    2648.00 ════  H1 Bottom

→ M30 KHÔNG phải subset của H1 ✗
→ mtfOverlap = false
→ Không bonus
```

##### Example 3: Tolerance Pass
```
M30 FVG: 2647.00 - 2649.00
H1 FVG:  2646.90 - 2650.00

With tolerance ±50 pts:
    M30 Bottom: 2647.00
    H1 Bottom: 2646.90 (within tolerance)
    
→ PASS with tolerance ✓
→ mtfOverlap = true
→ Bonus: +20 điểm
```

#### 📊 Scoring Impact

```cpp
// In Arbiter scoring:
if(c.hasFVG && c.fvgMTFOverlap) {
    if(c.fvgOverlapRatio >= 0.7) {
        // LTF chiếm >70% HTF → rất aligned
        score += 25;
        Print("✨ FVG MTF perfect overlap (+25)");
    } else if(c.fvgOverlapRatio >= 0.4) {
        // Medium overlap
        score += 20;
        Print("✨ FVG MTF good overlap (+20)");
    } else {
        // Small subset but still valid
        score += 15;
        Print("✨ FVG MTF overlap (+15)");
    }
}
```

---

### 3. BOS Retest Tracking

#### 🎯 Mục Đích
Track số lần price retest BOS level để xác nhận độ mạnh của structure break.

#### 📝 Định Nghĩa

**BOS Retest**: Price quay lại test lại BOS breakout level sau khi break.

**Retest Valid**:
- Price phải close ở ±30 points của BOS level
- Không được invalid BOS (close beyond level)
- Mỗi retest cách nhau ít nhất 3 bars

#### ⚙️ Thuật Toán

```cpp
struct BOSSignal {
    // ... existing fields ...
    
    // NEW v2.1
    int retestCount;           // Số lần retest
    datetime lastRetestTime;   // Thời gian retest gần nhất
    bool hasRetest;            // Có ít nhất 1 retest
    double retestStrength;     // Độ mạnh (0-1)
};

void UpdateBOSRetest(BOSSignal &bos) {
    if(!bos.valid) return;
    
    double retestZoneTop, retestZoneBottom;
    double tolerance = 30 * _Point; // ±30 pts
    
    if(bos.direction == 1) {
        // BULLISH BOS: Retest zone TRÊN breakLevel
        retestZoneBottom = bos.breakLevel;
        retestZoneTop = bos.breakLevel + tolerance;
    } else {
        // BEARISH BOS: Retest zone DƯỚI breakLevel
        retestZoneTop = bos.breakLevel;
        retestZoneBottom = bos.breakLevel - tolerance;
    }
    
    // Scan recent bars for retest (bars 1-20)
    for(int i = 1; i <= 20; i++) {
        datetime barTime = iTime(_Symbol, _Period, i);
        
        // Skip if too close to last retest (min 3 bars)
        if(bos.lastRetestTime != 0 && 
           (bos.lastRetestTime - barTime) < PeriodSeconds(_Period) * 3) {
            continue;
        }
        
        double closePrice = iClose(_Symbol, _Period, i);
        
        // Check if close in retest zone
        if(closePrice >= retestZoneBottom && 
           closePrice <= retestZoneTop) {
            
            // RETEST detected!
            bos.retestCount++;
            bos.lastRetestTime = barTime;
            bos.hasRetest = true;
            
            Print("🔄 BOS Retest #", bos.retestCount, 
                  " at ", closePrice, " (bar ", i, ")");
            
            // Don't count more than 3 retests
            if(bos.retestCount >= 3) break;
        }
    }
    
    // Calculate strength based on retest count
    if(bos.retestCount == 0) {
        bos.retestStrength = 0.0; // No retest = lower confidence
    } else if(bos.retestCount == 1) {
        bos.retestStrength = 0.7; // 1 retest = good
    } else if(bos.retestCount == 2) {
        bos.retestStrength = 0.9; // 2 retest = very good
    } else {
        bos.retestStrength = 1.0; // 3+ retest = excellent
    }
}
```

#### 💡 Ví Dụ

##### Example 1: BOS với 1 Retest (Good)
```
Price action (BULLISH BOS):
─────────────────────────────────────
Bar 0:  │
        │        Rally continues
        │     ╱
        │    ╱
Bar 10: │   ● ← Retest 2654.20 (1st)
        │   │  (trong zone ±30 pts)
        │   │
Bar 15: │  ╱
        │ ╱  Initial breakout
─────────●────── BOS Level: 2654.00
      ╱ │
     ╱  │

→ retestCount = 1
→ retestStrength = 0.7
→ Bonus: +10 điểm
```

##### Example 2: BOS với 2 Retest (Very Good)
```
Price action:
─────────────────────────────────────
Bar 0:  │     Strong rally
        │   ╱
Bar 5:  │  ● ← Retest #2 (2654.10)
        │  │
Bar 10: │ ╱
        │╱
Bar 15: ● ← Retest #1 (2654.25)
        │
Bar 20: │╱ Initial break
─────────●────── BOS Level: 2654.00

→ retestCount = 2
→ retestStrength = 0.9
→ Bonus: +15 điểm (strong level)
```

##### Example 3: No Retest (Lower Confidence)
```
Price action:
─────────────────────────────────────
Bar 0:  │
        │      
        │   ╱  Direct rally
        │  ╱   (NO pullback)
        │ ╱
        │╱
─────────●────── BOS Level: 2654.00

→ retestCount = 0
→ retestStrength = 0.0
→ Không bonus (có thể là breakout yếu)
→ Yêu cầu confluence factors khác
```

#### 📊 Scoring Impact

```cpp
// In Arbiter scoring:
if(c.hasBOS) {
    if(c.bosRetestCount >= 2) {
        score += 15;
        Print("✨ BOS with 2+ retest (+15)");
    } else if(c.bosRetestCount == 1) {
        score += 10;
        Print("✨ BOS with retest (+10)");
    } else {
        // No retest = penalty
        score -= 5;
        Print("⚠️ BOS no retest (-5)");
    }
}
```

---

### 4. Entry Method Based on Pattern

#### 🎯 Mục Đích
Sử dụng entry method phù hợp với từng loại pattern để optimize RR và fill rate.

#### 📝 Entry Method Matrix

| Pattern | Entry Type | Entry Price | Rationale |
|---------|-----------|-------------|-----------|
| **CHOCH (BOS)** | STOP | Trigger candle high/low + buffer | Break momentum, chase |
| **FVG** | LIMIT | FVG bottom/top | Wait for discount/premium |
| **OB** | LIMIT | OB bottom/top | Wait for institution zone |
| **Sweep + BOS** | STOP | Above/below trigger | Strong momentum |
| **BOS with Retest** | LIMIT | Retest zone | Better entry on pullback |
| **Momentum** | STOP | Breakout level | Don't miss runner |

#### ⚙️ Thuật Toán

```cpp
enum ENTRY_TYPE {
    ENTRY_STOP = 0,    // Buy/Sell Stop
    ENTRY_LIMIT = 1,   // Buy/Sell Limit
    ENTRY_MARKET = 2   // Market execution
};

struct EntryConfig {
    ENTRY_TYPE type;
    double price;
    string reason;
};

EntryConfig DetermineEntryMethod(Candidate &c) {
    EntryConfig entry;
    
    // ═══════════════════════════════════════════════════
    // PRIORITY 1: FVG → LIMIT (best RR)
    // ═══════════════════════════════════════════════════
    if(c.hasFVG && c.fvgState == 0) { // Fresh FVG
        entry.type = ENTRY_LIMIT;
        
        if(c.direction == 1) {
            // BUY LIMIT at FVG bottom (discount)
            entry.price = c.fvgBottom;
        } else {
            // SELL LIMIT at FVG top (premium)
            entry.price = c.fvgTop;
        }
        
        entry.reason = "FVG Limit Entry (Optimal RR)";
        return entry;
    }
    
    // ═══════════════════════════════════════════════════
    // PRIORITY 2: OB with Retest → LIMIT
    // ═══════════════════════════════════════════════════
    if(c.hasOB && c.hasBOS && c.bosRetestCount >= 1) {
        entry.type = ENTRY_LIMIT;
        
        if(c.direction == 1) {
            entry.price = c.poiBottom; // OB demand bottom
        } else {
            entry.price = c.poiTop; // OB supply top
        }
        
        entry.reason = "OB Retest Limit Entry";
        return entry;
    }
    
    // ═══════════════════════════════════════════════════
    // PRIORITY 3: Sweep + BOS → STOP (momentum)
    // ═══════════════════════════════════════════════════
    if(c.hasSweep && c.hasBOS) {
        entry.type = ENTRY_STOP;
        
        double triggerHigh = iHigh(_Symbol, _Period, 0);
        double triggerLow = iLow(_Symbol, _Period, 0);
        double buffer = InpEntryBufferPts * _Point;
        
        if(c.direction == 1) {
            entry.price = triggerHigh + buffer;
        } else {
            entry.price = triggerLow - buffer;
        }
        
        entry.reason = "Sweep+BOS Stop Entry (Momentum)";
        return entry;
    }
    
    // ═══════════════════════════════════════════════════
    // PRIORITY 4: BOS only (CHOCH) → STOP
    // ═══════════════════════════════════════════════════
    if(c.hasBOS && !c.hasOB && !c.hasFVG) {
        entry.type = ENTRY_STOP;
        
        double triggerHigh = iHigh(_Symbol, _Period, 0);
        double triggerLow = iLow(_Symbol, _Period, 0);
        double buffer = InpEntryBufferPts * _Point;
        
        if(c.direction == 1) {
            entry.price = triggerHigh + buffer;
        } else {
            entry.price = triggerLow - buffer;
        }
        
        entry.reason = "CHOCH Stop Entry";
        return entry;
    }
    
    // ═══════════════════════════════════════════════════
    // DEFAULT: OB → LIMIT
    // ═══════════════════════════════════════════════════
    if(c.hasOB) {
        entry.type = ENTRY_LIMIT;
        
        if(c.direction == 1) {
            entry.price = c.poiBottom;
        } else {
            entry.price = c.poiTop;
        }
        
        entry.reason = "OB Limit Entry (Default)";
        return entry;
    }
    
    // FALLBACK: STOP order
    entry.type = ENTRY_STOP;
    entry.reason = "Fallback Stop Entry";
    return entry;
}
```

#### 💡 Ví Dụ Decision Tree

```
Setup Analysis:
───────────────────────────────────────────────────

Candidate:
  ✓ BOS: Bullish
  ✓ Sweep: Sell-side at 2648.50
  ✓ FVG: Bullish 2649.00-2651.00 (Fresh)
  ✓ OB: None

Decision Tree:
  1. Has FVG? → YES (Fresh)
     → Use LIMIT at 2649.00 (FVG bottom)
     → Reason: "FVG Limit Entry (Optimal RR)"
     → Expected RR: 3.0+

  Entry Order:
     Type: BUY LIMIT
     Price: 2649.00
     SL: 2648.50 (sweep level)
     TP: 2655.00 (swing high)
     Distance SL: 50 pts ($50 risk per 0.01 lot)
     RR: 600 pts / 50 pts = 12:1 ✨

───────────────────────────────────────────────────

Candidate 2:
  ✓ BOS: Bullish
  ✓ Sweep: Sell-side
  ✗ FVG: None
  ✓ OB: Bullish 2649.00-2649.50

Decision Tree:
  1. Has FVG? → NO
  2. Has OB + BOS? → YES
     → Check retest: 0 retest
     → Use LIMIT at 2649.00 (OB bottom)
     → Reason: "OB Limit Entry (Default)"

  Entry Order:
     Type: BUY LIMIT
     Price: 2649.00
     SL: 2648.50
     TP: 2654.00
     RR: 5.0 / 0.5 = 10:1

───────────────────────────────────────────────────

Candidate 3:
  ✓ BOS: Bullish (CHOCH)
  ✓ Sweep: Sell-side
  ✗ FVG: None
  ✗ OB: None
  ✓ Momentum: Strong

Decision Tree:
  1. Has FVG? → NO
  2. Has OB? → NO
  3. Has Sweep + BOS? → YES
     → Use STOP order (chase momentum)
     → Reason: "Sweep+BOS Stop Entry (Momentum)"

  Entry Order:
     Type: BUY STOP
     Price: 2651.50 (trigger high + buffer)
     SL: 2648.50
     TP: 2657.50
     RR: 6.0 / 3.0 = 2:1
```

#### 📊 Expected Impact

| Entry Method | Fill Rate | Avg RR | Win Rate | Use Case |
|--------------|-----------|--------|----------|----------|
| **LIMIT (FVG)** | 60-70% | 3.5-4.0 | 72-75% | Best quality, wait |
| **LIMIT (OB)** | 70-80% | 3.0-3.5 | 68-72% | Good balance |
| **STOP (Sweep+BOS)** | 95-100% | 2.0-2.5 | 65-68% | Don't miss runner |
| **STOP (CHOCH)** | 95-100% | 1.8-2.2 | 63-66% | Momentum play |

---

## 🆕 v2.0 Updates: Adaptive Detection

#### 🎯 Mục Đích
Tính khoảng cách từ sweep level đến current price theo đơn vị ATR.

#### ⚙️ Implementation
```cpp
struct SweepSignal {
    // ... existing fields ...
    
    // NEW v2.0 field
    double proximityATR;  // Distance to sweep / ATR
};

SweepSignal DetectSweep() {
    // ... existing detection logic ...
    
    if(sweep.detected) {
        // Calculate proximity in ATR units
        double atr = GetATR();
        double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) +
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
        double distance = MathAbs(currentPrice - sweep.level);
        
        sweep.proximityATR = distance / atr;
        
        Print("💧 Sweep proximity: ", 
              DoubleToString(sweep.proximityATR, 2), " ATR");
    }
    
    return sweep;
}
```

#### 💡 Usage in Scoring
```cpp
// In Arbiter scoring:
if(c.hasSweep && c.sweepProximityATR <= 0.5) {
    score += 25;  // Close to sweep → High priority
}
```

---

### 2. OB & FVG State Tracking (Enhanced)

#### 🎯 OB Freshness
```cpp
struct OrderBlock {
    // ... existing fields ...
    
    // Enhanced tracking
    int touches;        // Already tracked
    bool isFresh;       // NEW: touches == 0
    int barsAge;        // Bars since creation
};

OrderBlock FindOB(int direction) {
    // ... existing logic ...
    
    // Mark as fresh if no touches
    ob.isFresh = (ob.touches == 0);
    
    // Calculate age
    datetime now = TimeCurrent();
    ob.barsAge = iBarShift(_Symbol, _Period, ob.createdTime);
    
    return ob;
}
```

#### 🎯 FVG Detailed States
```cpp
enum ENUM_FVG_STATE {
    FVG_CLEAN = 0,        // 0% filled (fresh)
    FVG_MITIGATED = 1,    // 35-85% filled
    FVG_COMPLETED = 2     // >85% filled
};

struct FVGSignal {
    // ... existing fields ...
    
    int stateDetailed;  // Use enum for clarity
};
```

---

### 3. Adaptive Thresholds (Future Enhancement)

#### 🎯 Concept
Adjust detection thresholds based on volatility regime.

#### ⚙️ Pseudo Code
```cpp
void UpdateDetectionThresholds(ENUM_REGIME regime) {
    double atr = GetATR();
    
    switch(regime) {
        case REGIME_LOW:
            // Looser thresholds (more signals)
            m_minBreakPts = (int)(atr / _Point * 1.0);  // 1.0× ATR
            m_fvg_MinPts = (int)(atr / _Point * 2.0);   // 2.0× ATR
            m_minWickPct = 30.0;  // Lower requirement
            break;
            
        case REGIME_MID:
            // Default
            m_minBreakPts = 70;
            m_fvg_MinPts = 180;
            m_minWickPct = 35.0;
            break;
            
        case REGIME_HIGH:
            // Stricter thresholds (fewer signals)
            m_minBreakPts = (int)(atr / _Point * 1.5);  // 1.5× ATR
            m_fvg_MinPts = (int)(atr / _Point * 3.0);   // 3.0× ATR
            m_minWickPct = 40.0;  // Higher requirement
            break;
    }
    
    Print("📊 Detection thresholds updated for ", GetRegimeName(regime));
}
```

#### 💡 Benefits
```
LOW Regime (smooth moves):
  → More sensitive detection
  → Catch smaller structures
  → More trading opportunities

HIGH Regime (choppy):
  → Less sensitive detection
  → Only significant structures
  → Avoid false signals
```

---

### 4. Reusing Invalidated OBs (Advanced)

#### 🎯 Concept
Convert invalidated OBs thành Mitigation Blocks (Breaker Blocks).

#### ⚙️ Current Implementation
```cpp
// Already in code (v1.2)
if(ob.valid) {
    double buffer = m_ob_BufferInvPts * _Point;
    if((direction == -1 && m_close[0] > ob.priceTop + buffer) ||
       (direction == 1 && m_close[0] < ob.priceBottom - buffer)) {
        // Convert to breaker block
        ob.isBreaker = true;
        ob.direction = -direction;  // Flip direction
        // Keep valid for breaker use
    }
}
```

#### 💡 Enhancement for v2.0
```cpp
// Track breaker quality
struct OrderBlock {
    // ... existing ...
    
    bool isBreaker;        // Already exists
    double breakStrength;  // NEW: How strong was break?
    int touchesAsBreaker;  // NEW: Touches as breaker
};

// In scoring:
if(c.hasOB && c.obIsBreaker && c.breakStrength > 1.5) {
    score += 10;  // Strong breaker bonus
} else if(c.hasOB && c.obIsBreaker) {
    score -= 10;  // Weak breaker penalty (existing)
}
```

---

### 5. Multi-Timeframe FVG Confirmation

#### 🎯 Concept
Confirm M30 FVG với H1/H4 FVG để tăng reliability.

#### ⚙️ Implementation
```cpp
bool CheckFVGMTFConfirmation(FVGSignal &fvg) {
    // Get H1 or H4
    ENUM_TIMEFRAMES htf = PERIOD_H1;
    if(_Period == PERIOD_H1) htf = PERIOD_H4;
    
    double htfHigh[], htfLow[];
    CopyHigh(_Symbol, htf, 0, 20, htfHigh);
    CopyLow(_Symbol, htf, 0, 20, htfLow);
    
    // Check if HTF also has FVG in same zone
    for(int i = 2; i < 20; i++) {
        if(fvg.direction == 1) {
            // Bullish FVG
            double htfGap = htfLow[i] - htfHigh[i+2];
            if(htfGap > 0 && 
               htfHigh[i+2] <= fvg.priceTop && 
               htfLow[i] >= fvg.priceBottom) {
                fvg.mtfConfirmed = true;
                return true;
            }
        }
    }
    
    return false;
}
```

#### 💡 Usage
```cpp
// In Arbiter scoring:
if(c.hasFVG && c.fvgMTFConfirmed) {
    score += 15;  // HTF-confirmed FVG
}
```

---

## 📊 Summary: v1.2 vs v2.0 Detection

| Feature | v1.2 | v2.0 |
|---------|------|------|
| **BOS** | Fixed thresholds | Same (adaptive in future) |
| **Sweep** | Basic detection | + ProximityATR calculation |
| **OB** | Touches, volume | + isFresh flag, + breaker strength |
| **FVG** | State 0/1/2 | + MTF confirmation (optional) |
| **Momentum** | Basic | Same |
| **Thresholds** | Fixed points | Ready for ATR-scaling |

---

## 🔮 Proposed New Detectors

### 1. MA Trend Detector 🟡 High Priority

#### 🎯 Purpose
Xác định xu hướng tổng thể bằng MA crossover để filter counter-trend trades.

#### ⚙️ Implementation

```cpp
class CDetector {
private:
    int m_emaFastHandle;  // EMA 20
    int m_emaSlowHandle;  // EMA 50
    
public:
    bool Init(...) {
        // ... existing code ...
        
        // [NEW] Create MA handles
        m_emaFastHandle = iMA(m_symbol, m_timeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
        m_emaSlowHandle = iMA(m_symbol, m_timeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
        
        if(m_emaFastHandle == INVALID_HANDLE || m_emaSlowHandle == INVALID_HANDLE) {
            Print("❌ Failed to create MA handles");
            return false;
        }
        
        return true;
    }
    
    // ═══════════════════════════════════════════════════════
    // NEW: Detect MA Trend
    // ═══════════════════════════════════════════════════════
    int DetectMATrend() {
        double emaFast[], emaSlow[];
        ArraySetAsSeries(emaFast, true);
        ArraySetAsSeries(emaSlow, true);
        
        // Get MA values
        if(CopyBuffer(m_emaFastHandle, 0, 0, 2, emaFast) <= 0 ||
           CopyBuffer(m_emaSlowHandle, 0, 0, 2, emaSlow) <= 0) {
            Print("⚠️ Failed to copy MA buffers");
            return 0;
        }
        
        // Current trend
        if(emaFast[0] > emaSlow[0]) {
            return 1;  // Bullish trend
        } else if(emaFast[0] < emaSlow[0]) {
            return -1; // Bearish trend
        }
        
        return 0;  // Neutral/choppy
    }
    
    // ═══════════════════════════════════════════════════════
    // NEW: Detect MA Crossover
    // ═══════════════════════════════════════════════════════
    bool IsMACrossover(int &direction) {
        double emaFast[], emaSlow[];
        ArraySetAsSeries(emaFast, true);
        ArraySetAsSeries(emaSlow, true);
        
        if(CopyBuffer(m_emaFastHandle, 0, 0, 2, emaFast) <= 0 ||
           CopyBuffer(m_emaSlowHandle, 0, 0, 2, emaSlow) <= 0) {
            return false;
        }
        
        // Bullish crossover (fast crosses above slow)
        if(emaFast[0] > emaSlow[0] && emaFast[1] <= emaSlow[1]) {
            direction = 1;
            Print("✨ Bullish MA crossover detected");
            return true;
        }
        
        // Bearish crossover (fast crosses below slow)
        if(emaFast[0] < emaSlow[0] && emaFast[1] >= emaSlow[1]) {
            direction = -1;
            Print("✨ Bearish MA crossover detected");
            return true;
        }
        
        return false;
    }
    
    // ═══════════════════════════════════════════════════════
    // NEW: Get MA Distance (for strength measurement)
    // ═══════════════════════════════════════════════════════
    double GetMADistance() {
        double emaFast[], emaSlow[];
        ArraySetAsSeries(emaFast, true);
        ArraySetAsSeries(emaSlow, true);
        
        if(CopyBuffer(m_emaFastHandle, 0, 0, 1, emaFast) <= 0 ||
           CopyBuffer(m_emaSlowHandle, 0, 0, 1, emaSlow) <= 0) {
            return 0;
        }
        
        // Return distance as % of price
        double distance = MathAbs(emaFast[0] - emaSlow[0]);
        double price = (emaFast[0] + emaSlow[0]) / 2.0;
        
        return (distance / price) * 100.0;  // Distance in %
    }
};
```

#### 📊 Usage in Arbiter

```cpp
Candidate BuildCandidate(...) {
    // ... existing code ...
    
    // [NEW] Get MA trend
    int maTrend = g_detector.DetectMATrend();
    int crossDir = 0;
    bool hasCross = g_detector.IsMACrossover(crossDir);
    
    c.maTrend = maTrend;
    c.maCrossover = hasCross;
    c.counterTrend = (maTrend != 0 && maTrend != c.direction);
    
    return c;
}

double ScoreCandidate(Candidate &c) {
    double score = 0;
    // ... existing scoring ...
    
    // [NEW] MA Trend Scoring
    if(c.maTrend != 0) {
        if(c.maTrend == c.direction) {
            // WITH trend
            score += 25;
            Print("✨ MA trend aligned (+25)");
            
            if(c.maCrossover) {
                // Fresh crossover = strong signal
                score += 15;
                Print("✨ MA crossover (+15)");
            }
            
            // Check strength
            double maDistance = g_detector.GetMADistance();
            if(maDistance > 0.5) {  // Strong separation
                score += 10;
                Print("✨ Strong MA separation (+10)");
            }
            
        } else {
            // AGAINST trend
            c.counterTrend = true;
            score -= 40;
            Print("⚠️ Counter MA trend (-40)");
            
            // Strict filter for counter-trend
            if(score < InpMACounterMinScore) {
                Print("❌ REJECT: Counter-trend score ", score,
                      " < min ", InpMACounterMinScore);
                return 0;
            }
        }
    }
    
    return score;
}
```

#### 💡 Parameters

```cpp
input group "═══════ MA Trend Filter ═══════"
input bool   InpUseMAFilter        = true;   // Enable MA filter
input int    InpMAFastPeriod       = 20;     // EMA fast period
input int    InpMASlowPeriod       = 50;     // EMA slow period
input int    InpMACounterMinScore  = 150;    // Min score for counter-trend
input double InpMAStrongSeparation = 0.5;    // Strong separation threshold (%)
```

#### 📊 Expected Impact

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| **Counter-Trend Trades** | 30-40% | 10-15% | -60-70% |
| **Counter-Trend Losses** | High | Low | -60% |
| **Win Rate** | 65% | 68-70% | +3-5% |
| **Trade Count** | 5/day | 4-5/day | -15-20% |

---

### 2. WAE (Waddah Attar Explosion) Detector 🟡 High Priority

#### 🎯 Purpose
Đo lường sức mạnh momentum và volume để confirm breakout thực sự (không phải breakout giả).

#### 📝 About WAE

**Waddah Attar Explosion** là indicator kết hợp:
- **MACD** (momentum)
- **Bollinger Bands** (volatility)  
- **Volume** (participation)

**Output**:
- Histogram: Sức mạnh momentum
- Signal line: Ngưỡng "explosion"
- Color: Green (bullish) / Red (bearish)

#### ⚙️ Implementation

```cpp
class CDetector {
private:
    int m_waeHandle;
    
public:
    bool Init(...) {
        // ... existing code ...
        
        // [NEW] Create WAE handle
        m_waeHandle = iCustom(m_symbol, m_timeframe,
                              "Market\\Waddah Attar Explosion",
                              20,    // Sensitivity
                              40,    // Fast MA
                              200,   // Slow MA
                              3.0,   // BB Deviation
                              20);   // BB Period
        
        if(m_waeHandle == INVALID_HANDLE) {
            Print("⚠️ WAE indicator not found - feature disabled");
            m_waeHandle = -1;  // Mark as disabled
        } else {
            Print("✅ WAE indicator loaded");
        }
        
        return true;
    }
    
    // ═══════════════════════════════════════════════════════
    // NEW: Check WAE Explosion
    // ═══════════════════════════════════════════════════════
    bool IsWAEExplosion(int direction, double &waeValue, int &waeDir) {
        // Skip if WAE not available
        if(m_waeHandle == -1) return true; // Don't block if disabled
        
        double waeMain[], waeSignal[];
        ArraySetAsSeries(waeMain, true);
        ArraySetAsSeries(waeSignal, true);
        
        // Buffer 0: Histogram (momentum strength)
        // Buffer 1: Signal line (explosion threshold)
        if(CopyBuffer(m_waeHandle, 0, 0, 2, waeMain) <= 0 ||
           CopyBuffer(m_waeHandle, 1, 0, 2, waeSignal) <= 0) {
            Print("⚠️ Failed to copy WAE buffers");
            return false;
        }
        
        waeValue = waeMain[0];
        
        // Determine WAE direction
        waeDir = (waeMain[0] > 0) ? 1 : -1;
        
        // Check explosion conditions:
        // 1. Histogram > Signal line (above threshold)
        // 2. Histogram > User threshold
        // 3. Direction matches trade direction
        if(waeMain[0] > waeSignal[0] && 
           MathAbs(waeMain[0]) > InpWAEThreshold) {
            
            if(waeDir == direction) {
                Print("🔥 WAE explosion confirmed: ", 
                      DoubleToString(waeValue, 2),
                      " (threshold: ", InpWAEThreshold, ")");
                return true;
            } else {
                Print("⚠️ WAE explosion opposite direction");
                return false;
            }
        }
        
        // Not exploding
        return false;
    }
    
    // ═══════════════════════════════════════════════════════
    // NEW: Get WAE Strength
    // ═══════════════════════════════════════════════════════
    double GetWAEStrength() {
        if(m_waeHandle == -1) return 0;
        
        double waeMain[];
        ArraySetAsSeries(waeMain, true);
        
        if(CopyBuffer(m_waeHandle, 0, 0, 1, waeMain) <= 0) {
            return 0;
        }
        
        return MathAbs(waeMain[0]);
    }
    
    // ═══════════════════════════════════════════════════════
    // NEW: Check WAE Trend
    // ═══════════════════════════════════════════════════════
    bool IsWAETrending(int direction) {
        if(m_waeHandle == -1) return true;
        
        double waeMain[];
        ArraySetAsSeries(waeMain, true);
        
        if(CopyBuffer(m_waeHandle, 0, 0, 5, waeMain) <= 0) {
            return false;
        }
        
        // Check if last 3 bars are increasing
        if(direction == 1) {
            return (waeMain[0] > waeMain[1] && waeMain[1] > waeMain[2]);
        } else {
            return (waeMain[0] < waeMain[1] && waeMain[1] < waeMain[2]);
        }
    }
};
```

#### 📊 Usage in Arbiter

```cpp
Candidate BuildCandidate(...) {
    // ... existing code ...
    
    // [NEW] Check WAE
    double waeValue = 0;
    int waeDir = 0;
    c.hasWAE = g_detector.IsWAEExplosion(c.direction, waeValue, waeDir);
    c.waeValue = waeValue;
    c.waeDirection = waeDir;
    c.waeWeak = (MathAbs(waeValue) < InpWAEThreshold);
    c.waeTrending = g_detector.IsWAETrending(c.direction);
    
    return c;
}

double ScoreCandidate(Candidate &c) {
    double score = 0;
    // ... existing scoring ...
    
    // [NEW] WAE Scoring
    if(c.hasWAE) {
        // Explosion confirmed
        score += 20;
        Print("✨ WAE explosion (+20)");
        
        // Very strong explosion
        if(c.waeValue > InpWAEThreshold * 1.5) {
            score += 10;
            Print("✨ WAE very strong (+10)");
        }
        
        // Trending momentum (3 bars increasing)
        if(c.waeTrending) {
            score += 5;
            Print("✨ WAE trending (+5)");
        }
        
    } else if(!c.waeWeak) {
        // WAE exists but NOT exploding (weak breakout)
        score -= 15;
        Print("⚠️ Weak momentum (-15)");
        
        // Block if insufficient score
        if(score < 120) {
            Print("❌ REJECT: Weak WAE, score too low");
            return 0;
        }
    }
    
    // [NEW] If WAE required, must have explosion
    if(InpWAERequired && !c.hasWAE) {
        Print("❌ REJECT: WAE explosion required but not present");
        return 0;
    }
    
    return score;
}
```

#### 💡 Parameters

```cpp
input group "═══════ WAE Momentum Filter ═══════"
input bool   InpUseWAE         = true;   // Enable WAE filter
input double InpWAEThreshold   = 0.5;    // Explosion threshold
input bool   InpWAERequired    = false;  // Require for ALL trades
input int    InpWAESensitivity = 20;     // WAE sensitivity (lower = more sensitive)
```

#### 📊 Expected Impact

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| **Weak Breakouts** | 25-30% | 5-10% | -70-80% |
| **False Signals** | High | Low | -60% |
| **Win Rate** | 65% | 69-71% | +4-6% |
| **Profit Factor** | 2.0 | 2.2-2.3 | +0.2-0.3 |
| **Trade Count** | 5/day | 3-4/day | -25-30% |

---

### 3. Combined Usage Example

```cpp
void OnTick() {
    // ... existing pre-checks ...
    
    // ═══════════════════════════════════════════════════════
    // STEP 4: Run detectors (UPDATED)
    // ═══════════════════════════════════════════════════════
    
    if(newBar || !g_lastBOS.valid) {
        g_lastBOS = g_detector.DetectBOS();
    }
    
    if(newBar || !g_lastSweep.valid) {
        g_lastSweep = g_detector.DetectSweep();
    }
    
    if(g_lastBOS.valid) {
        g_lastOB = g_detector.FindOB(g_lastBOS.direction);
        g_lastFVG = g_detector.FindFVG(g_lastBOS.direction);
    }
    
    if(newBar) {
        g_lastMomo = g_detector.DetectMomentum();
    }
    
    // [NEW] Get MA trend
    g_maTrend = g_detector.DetectMATrend();
    int crossDir = 0;
    g_maCrossover = g_detector.IsMACrossover(crossDir);
    
    // [NEW] Get WAE status (will be checked in BuildCandidate)
    // No need to call here - done per candidate
    
    // ... continue with BuildCandidate ...
}
```

---

### 📊 Combined Impact Estimate

| Feature | Win Rate Impact | Trade Count Impact | Complexity |
|---------|----------------|-------------------|------------|
| **MA Filter** | +3-5% | -15-20% | Low |
| **WAE Momentum** | +4-6% | -25-30% | Medium |
| **Combined** | **+7-11%** | **-35-45%** | Medium |

**Expected Final Results** (with all 4 improvements):
```
Win Rate:       65% → 72-75%  (+7-10%)
Profit Factor:  2.0 → 2.3-2.5 (+15-25%)
Avg RR:         2.0 → 3.0-3.5 (+50-75%)
Trades/Day:     5 → 3-4       (-30-40%)
```

---

### 🛠️ Installation Notes

#### WAE Indicator Setup

1. **Download WAE Indicator**:
   - Search "Waddah Attar Explosion MT5" on MQL5 Market
   - Or get from: https://www.mql5.com/en/code/

2. **Install**:
   ```
   Copy to: MQL5/Indicators/Market/
   File name: Waddah Attar Explosion.ex5
   ```

3. **Verify**:
   ```cpp
   // In OnInit()
   int waeHandle = iCustom(_Symbol, _Period, 
                           "Market\\Waddah Attar Explosion");
   if(waeHandle == INVALID_HANDLE) {
       Print("WAE not found - check installation");
   }
   ```

4. **Alternative**: If WAE not available, feature will auto-disable:
   ```cpp
   if(m_waeHandle == -1) {
       Print("⚠️ WAE disabled - trading without WAE filter");
       return true; // Don't block trading
   }
   ```

---

### 📚 Related Documentation

- [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md#21-thêm-ma-trend-filter) - MA Filter plan
- [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md#22-thêm-wae-momentum-confirmation) - WAE plan
- [03_ARBITER.md](03_ARBITER.md#2-thiếu-ma-trend-filter) - MA scoring
- [03_ARBITER.md](03_ARBITER.md#3-thiếu-wae-waddah-attar-explosion) - WAE scoring

---

## 🎓 Đọc Tiếp

- [03_ARBITER.md](03_ARBITER.md) - Cách kết hợp signals thành candidates
- [09_EXAMPLES.md](09_EXAMPLES.md) - Ví dụ thực tế các setup
- [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md) - Full improvement roadmap

