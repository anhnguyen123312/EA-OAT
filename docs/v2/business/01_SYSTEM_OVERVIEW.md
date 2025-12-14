# 01. Tổng Quan Hệ Thống

## 🎯 Mục Tiêu

Bot EA này được thiết kế để:
1. **Phát hiện** các setup giao dịch chất lượng cao theo phương pháp SMC/ICT
2. **Quản lý** vị thế tự động với DCA, Breakeven, và Trailing
3. **Bảo vệ** vốn với Daily MDD limit và risk management
4. **Tối ưu** lợi nhuận với dynamic lot sizing và basket management

---

## 📐 Kiến Trúc 5 Lớp

### 1️⃣ **DETECTION LAYER** (Lớp Phát Hiện)
**File**: `detectors.mqh`

```
┌─────────────────────────────────────────┐
│          DETECTION LAYER                │
│                                         │
│  ┌──────────┐  ┌──────────┐            │
│  │   BOS    │  │  SWEEP   │            │
│  │ Detector │  │ Detector │            │
│  └────┬─────┘  └────┬─────┘            │
│       │             │                   │
│  ┌────▼─────┐  ┌───▼──────┐            │
│  │    OB    │  │   FVG    │            │
│  │ Detector │  │ Detector │            │
│  └──────────┘  └──────────┘            │
│                                         │
│       ┌──────────────┐                  │
│       │  MOMENTUM    │                  │
│       │  Detector    │                  │
│       └──────────────┘                  │
└─────────────────────────────────────────┘
```

**Nhiệm vụ**:
- Quét thị trường để tìm các cấu trúc SMC/ICT
- Trả về các signal structs (BOSSignal, SweepSignal, OrderBlock, FVGSignal, MomentumSignal)
- Validate TTL (Time To Live) của mỗi signal

---

### 2️⃣ **ARBITRATION LAYER** (Lớp Quyết Định)
**File**: `arbiter.mqh`

```
┌─────────────────────────────────────────┐
│        ARBITRATION LAYER                │
│                                         │
│  Input: BOS + Sweep + OB + FVG + Momo  │
│           ↓                             │
│  ┌────────────────────┐                 │
│  │  BuildCandidate()  │                 │
│  │  - Check validity  │                 │
│  │  - Combine signals │                 │
│  └─────────┬──────────┘                 │
│            ↓                             │
│  ┌────────────────────┐                 │
│  │  ScoreCandidate()  │                 │
│  │  - Calculate score │                 │
│  │  - Apply bonuses   │                 │
│  │  - Apply penalties │                 │
│  └─────────┬──────────┘                 │
│            ↓                             │
│  Output: Candidate (score ≥ 100?)      │
└─────────────────────────────────────────┘
```

**Nhiệm vụ**:
- Kết hợp các signal thành Candidate
- Tính điểm ưu tiên (scoring)
- Filter các setup không đủ chất lượng

---

### 3️⃣ **EXECUTION LAYER** (Lớp Thực Thi)
**File**: `executor.mqh`

```
┌─────────────────────────────────────────┐
│         EXECUTION LAYER                 │
│                                         │
│  ┌──────────────────┐                   │
│  │ Session & Spread │                   │
│  │     Filters      │                   │
│  └────────┬─────────┘                   │
│           ↓                              │
│  ┌──────────────────┐                   │
│  │ GetTriggerCandle │                   │
│  │  (Confirmation)  │                   │
│  └────────┬─────────┘                   │
│           ↓                              │
│  ┌──────────────────┐                   │
│  │ CalculateEntry   │                   │
│  │  - Entry Price   │                   │
│  │  - SL (Method/   │                   │
│  │       Fixed)     │                   │
│  │  - TP            │                   │
│  └────────┬─────────┘                   │
│           ↓                              │
│  ┌──────────────────┐                   │
│  │ PlaceStopOrder   │                   │
│  └──────────────────┘                   │
└─────────────────────────────────────────┘
```

**Nhiệm vụ**:
- Kiểm tra session time & spread
- Tìm trigger candle (confirmation)
- Tính toán Entry/SL/TP
- Đặt lệnh stop order

---

### 4️⃣ **RISK MANAGEMENT LAYER** (Lớp Quản Lý Rủi Ro)
**File**: `risk_manager.mqh`

```
┌─────────────────────────────────────────┐
│      RISK MANAGEMENT LAYER              │
│                                         │
│  ┌──────────────────┐                   │
│  │ CalcLotsByRisk() │                   │
│  │ - Position sizing│                   │
│  │ - Dynamic MaxLot │                   │
│  └──────────────────┘                   │
│                                         │
│  ┌──────────────────┐                   │
│  │ ManagePositions()│                   │
│  │  ├─ Breakeven    │                   │
│  │  ├─ Trailing     │                   │
│  │  └─ DCA          │                   │
│  └──────────────────┘                   │
│                                         │
│  ┌──────────────────┐                   │
│  │ Daily MDD Check  │                   │
│  │ - Halt trading   │                   │
│  │ - Close all      │                   │
│  └──────────────────┘                   │
│                                         │
│  ┌──────────────────┐                   │
│  │ Basket TP/SL     │                   │
│  └──────────────────┘                   │
└─────────────────────────────────────────┘
```

**Nhiệm vụ**:
- Tính lot size dựa trên risk%
- Quản lý vị thế đang mở (BE, Trail, DCA)
- Kiểm tra Daily MDD limit
- Close all positions khi đạt basket TP/SL

---

### 5️⃣ **ANALYTICS LAYER** (Lớp Phân Tích)
**Files**: `stats_manager.mqh`, `draw_debug.mqh`

```
┌─────────────────────────────────────────┐
│         ANALYTICS LAYER                 │
│                                         │
│  ┌──────────────────┐                   │
│  │  Stats Manager   │                   │
│  │  - Track trades  │                   │
│  │  - Win/Loss      │                   │
│  │  - By Pattern    │                   │
│  └──────────────────┘                   │
│                                         │
│  ┌──────────────────┐                   │
│  │    Dashboard     │                   │
│  │  - Real-time     │                   │
│  │  - Visual chart  │                   │
│  └──────────────────┘                   │
└─────────────────────────────────────────┘
```

**Nhiệm vụ**:
- Track tất cả trades
- Tính toán thống kê theo pattern
- Hiển thị dashboard trên chart

---

## 🔄 Luồng Dữ Liệu (Data Flow)

```
┌─────────────┐
│   MARKET    │
│    DATA     │
└──────┬──────┘
       │
       ▼
┌─────────────────────────────────┐
│ 1. DETECTION                    │
│    - Scan for BOS, Sweep, etc.  │
└──────┬──────────────────────────┘
       │
       ▼
┌─────────────────────────────────┐
│ 2. ARBITRATION                  │
│    - Build Candidate            │
│    - Score (≥100 = valid)       │
└──────┬──────────────────────────┘
       │
       ▼ (if score ≥ 100)
┌─────────────────────────────────┐
│ 3. EXECUTION                    │
│    - Check session/spread       │
│    - Find trigger candle        │
│    - Calculate Entry/SL/TP      │
│    - Place order                │
└──────┬──────────────────────────┘
       │
       ▼ (when filled)
┌─────────────────────────────────┐
│ 4. RISK MANAGEMENT              │
│    - Track position             │
│    - Manage BE/Trail/DCA        │
│    - Check MDD & Basket         │
└──────┬──────────────────────────┘
       │
       ▼ (when closed)
┌─────────────────────────────────┐
│ 5. ANALYTICS                    │
│    - Record stats               │
│    - Update dashboard           │
└─────────────────────────────────┘
```

---

## 🧩 Các Struct Chính

### 1. **BOSSignal** (Break of Structure)
```cpp
struct BOSSignal {
    int      direction;      // 1=bullish, -1=bearish
    datetime detectedTime;
    double   breakLevel;     // Price level broken
    int      barsAge;
    int      ttl;
    bool     valid;
}
```

### 2. **SweepSignal** (Liquidity Sweep)
```cpp
struct SweepSignal {
    bool     detected;
    int      side;           // 1=buy-side high, -1=sell-side low
    double   level;          // Fractal price level
    datetime time;
    int      distanceBars;   // Distance to fractal
    bool     valid;
}
```

### 3. **OrderBlock**
```cpp
struct OrderBlock {
    bool     valid;
    int      direction;      // 1=demand, -1=supply
    double   priceTop;
    double   priceBottom;
    int      touches;        // Số lần price quay lại
    bool     weak;           // Volume < 1.3x avg
    bool     isBreaker;      // Đã bị invalidate → Breaker Block
}
```

### 4. **FVGSignal** (Fair Value Gap)
```cpp
struct FVGSignal {
    bool     valid;
    int      direction;      // 1=bullish, -1=bearish
    double   priceTop;
    double   priceBottom;
    int      state;          // 0=Valid, 1=Mitigated, 2=Completed
    double   fillPct;        // % filled
}
```

### 5. **Candidate** (Trade Setup)
```cpp
struct Candidate {
    bool     valid;
    int      direction;      // 1=long, -1=short
    double   score;          // Priority score
    
    // Signal flags
    bool     hasBOS;
    bool     hasSweep;
    bool     hasOB;
    bool     hasFVG;
    bool     hasMomo;
    
    // POI (Point of Interest)
    double   poiTop;
    double   poiBottom;
    
    // Entry details
    double   entryPrice;
    double   slPrice;
    double   tpPrice;
    double   rrRatio;
}
```

---

## ⚙️ Cơ Chế Hoạt Động

### OnInit()
1. Khởi tạo tất cả components (Detector, Arbiter, Executor, RiskManager, Stats)
2. Load parameters từ inputs
3. Set DCA levels, lot sizing params
4. Initialize dashboard

### OnTick()
```cpp
1. Check new bar
2. Pre-checks:
   - Session open?
   - Spread OK?
   - MDD halted?
   - Rollover time?
   
3. Update price series
4. Run detectors:
   - DetectBOS()
   - DetectSweep()
   - FindOB()
   - FindFVG()
   - DetectMomentum()
   
5. Build & Score Candidate
6. If score ≥ 100:
   - Find trigger candle
   - Calculate Entry/SL/TP
   - Check lot limits
   - Place order
   
7. Manage existing positions:
   - Breakeven
   - Trailing
   - DCA add-ons
   
8. Update dashboard
```

### OnTrade()
1. Detect new filled orders
2. Track position in RiskManager
3. Record in StatsManager
4. Update closed trades stats

---

## 🎨 Ví Dụ Hoạt Động

### Scenario 1: LONG Setup

```
1. DETECTION:
   ✓ BOS Bullish detected at 2650.00
   ✓ Sell-side Sweep at 2648.50
   ✓ Order Block: 2649.00 - 2649.50
   ✓ FVG: 2649.20 - 2649.80

2. ARBITRATION:
   → Candidate built: LONG
   → Score: 100 (BOS) + 30 (BOS bonus) + 25 (Sweep) + 20 (OB) = 175
   → Valid ✅

3. EXECUTION:
   → Trigger candle: Bullish body 0.35 ATR
   → Entry: 2650.20 (trigger high + buffer)
   → SL: 2648.80 (below sweep)
   → TP: 2653.00 (2:1 RR)
   → Lots: 0.15 (based on 0.5% risk)

4. RISK MANAGEMENT:
   → Track position #12345
   → At +1R (2651.60): Move to BE
   → At +0.75R (2651.25): Add DCA #1 (0.05 % so với lệnh ban đầu)
   → At +1.5R (2652.30): Add DCA #2 (0.05 % so với lệnh ban đầu)
   → Trailing: Start at +1R, step 0.5R

5. ANALYTICS:
   → Pattern: BOS+Sweep+OB (Confluence)
   → Win: +2.3R ($450)
   → Update: Confluence 12W/3L → 80% WR
```

---

## 📊 Dashboard Layout

```
╔═══ SMC/ICT EA v1.2 - DASHBOARD ═══╗
│ STATE: SIGNAL DETECTED              │
├─────────────────────────────────────┤
│ Balance:    $10,000.00 | MaxLot: 3.0│
│ Equity:     $10,250.00              │
│ Floating PL: $+250.00 (+2.50%)      │
│ Daily P/L:         +2.50%           │
├─────────────────────────────────────┤
│ Time (GMT+7): 14:35 | Session: OPEN │
│ Spread: OK                          │
│ Trading: ACTIVE                     │
├─────────────────────────────────────┤
│ ACTIVE STRUCTURES:                  │
│ ├─ BOS UP   @ 2650.00               │
│ ├─ SWEEP LOW @ 2648.50              │
│ ├─ OB LONG: 2649.00-2649.50         │
│ └─ FVG LONG: 2649.20-2649.80 [ACT]  │
├─────────────────────────────────────┤
│ SIGNAL: VALID | Score: 175.0 ★      │
├─────────────────────────────────────┤
│ POSITIONS:                          │
│ ├─ LONG:  2 orders | 0.30 lots      │
│ └─ SHORT: 0 orders | 0.00 lots      │
├─────────────────────────────────────┤
│ PERFORMANCE STATS:                  │
│ Total: 45 | Win: 32 | Loss: 13      │
│ Win Rate: 71.1% | PF: 2.35          │
│ Total Profit: $4,523.00             │
│                                     │
│ WIN/LOSS BY PATTERN:                │
│ ├─ BOS+OB:    12 trades | 9W/3L     │
│ ├─ Sweep+FVG: 8 trades | 6W/2L      │
│ └─ Confluence:10 trades | 8W/2L     │
└─────────────────────────────────────┘
```

---

## 🔐 Bảo Mật & Kiểm Soát

### 1. **One Trade Per Bar**
- Chỉ đặt 1 lệnh mỗi bar
- Tránh spam orders

### 2. **One Direction At A Time**
- Không mở LONG và SHORT cùng lúc
- Skip entry nếu đã có pending order cùng direction

### 3. **Daily MDD Protection**
- Tự động close all positions khi MDD > 8%
- Halt trading đến ngày hôm sau

### 4. **Dynamic Lot Sizing**
- MaxLot tăng theo equity
- Công thức: `MaxLot = LotBase + floor(Equity/1000) × 0.1`

### 5. **Session Filter**
- Chỉ trade trong giờ 7h-23h GMT+7
- Tránh rollover time (00:00 ±5min)

---

## 🎓 Đọc Tiếp

- [02_DETECTORS.md](02_DETECTORS.md) - Chi tiết thuật toán phát hiện
- [03_ARBITER.md](03_ARBITER.md) - Logic scoring và filtering
- [08_MAIN_FLOW.md](08_MAIN_FLOW.md) - Luồng hoạt động chi tiết

