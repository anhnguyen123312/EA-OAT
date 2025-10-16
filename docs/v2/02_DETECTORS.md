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

## 🎓 Đọc Tiếp

- [03_ARBITER.md](03_ARBITER.md) - Cách kết hợp signals thành candidates
- [09_EXAMPLES.md](09_EXAMPLES.md) - Ví dụ thực tế các setup

