# 05. Quản Lý Rủi Ro (Risk Manager)

## 📍 Tổng Quan

**File**: `risk_manager.mqh`

Lớp `CRiskManager` quản lý:
1. **Position Sizing** - Tính lot size
2. **DCA** (Dollar Cost Averaging) - Thêm vị thế khi profit tăng
3. **Breakeven** - Di chuyển SL về entry
4. **Trailing Stop** - Di chuyển SL theo profit
5. **Daily MDD** - Bảo vệ vốn hàng ngày
6. **Basket Management** - Quản lý toàn bộ vị thế

---

## 1️⃣ Position Sizing

### ⚙️ Công Thức Lot Size

```
Lots = (Balance × Risk%) ÷ (SL_Distance × Value_Per_Point)
```

### 📊 Chi Tiết Tính Toán

```cpp
double CalcLotsByRisk(double riskPct, double slPoints) {
    // 1. Get base value
    double equity = GetCurrentEquity();
    double balance = AccountBalance();
    double baseValue = UseEquityMDD ? equity : balance;
    
    // 2. Calculate risk amount
    double riskValue = baseValue × (riskPct / 100.0);
    
    // 3. Get symbol info
    double tickValue = SymbolInfoDouble(SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(SYMBOL_TRADE_TICK_SIZE);
    
    // 4. Calculate value per point per lot
    double valuePerPoint = tickValue × (_Point / tickSize);
    
    // 5. Calculate lots
    double denominator = slPoints × valuePerPoint;
    double lotsRaw = riskValue / denominator;
    double lots = NormalizeDouble(lotsRaw, 2);
    
    // 6. Apply limits
    lots = Max(lots, SYMBOL_VOLUME_MIN);
    lots = Min(lots, SYMBOL_VOLUME_MAX);
    lots = Min(lots, MaxLotPerSide);
    
    return lots;
}
```

### 💡 Ví Dụ

```
Setup:
  Balance: $10,000
  Risk: 0.5%
  SL Distance: 1000 points (100 pips)
  XAUUSD: TickValue = $1.00, TickSize = 0.01

Calculation:
  Risk Amount = $10,000 × 0.5% = $50
  Value/Point = $1.00 × (0.0001 / 0.01) = $0.01
  Denominator = 1000 pts × $0.01 = $10
  Lots = $50 / $10 = 5.0 lots

Limits:
  MaxLotPerSide = 3.0
  Final Lots = 3.0 (capped)
```

### 📈 Dynamic Lot Sizing

```cpp
// MaxLot grows with equity
MaxLot = LotBase + floor(Equity / EquityPerLotInc) × LotIncrement

Example:
  LotBase = 0.1
  EquityPerLotInc = $1000
  LotIncrement = 0.1
  
  Equity $5,000  → MaxLot = 0.1 + floor(5000/1000) × 0.1 = 0.6
  Equity $10,000 → MaxLot = 0.1 + floor(10000/1000) × 0.1 = 1.1
  Equity $20,000 → MaxLot = 0.1 + floor(20000/1000) × 0.1 = 2.1
```

---

## 2️⃣ DCA (Dollar Cost Averaging)

### 🎯 Mục Đích
Thêm vị thế khi trade đã có profit để tối đa hóa lợi nhuận.

### ⚙️ Cơ Chế

```
ORIGINAL POSITION:
  Entry: 2650.00
  SL: 2649.00 (100 points = 1R)
  Lots: 0.30

DCA Level 1 (+0.75R):
  Trigger: 2650.75 (profit = 75 points = 0.75R)
  Add: 0.15 lots (0.5× original)
  Total: 0.45 lots

DCA Level 2 (+1.5R):
  Trigger: 2651.50 (profit = 150 points = 1.5R)
  Add: 0.10 lots (0.33× original)
  Total: 0.55 lots
```

### 📊 DCA Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `DcaLevel1_R` | 0.75 | Trigger level for 1st DCA |
| `DcaLevel2_R` | 1.5 | Trigger level for 2nd DCA |
| `DcaSize1_Mult` | 0.5 | 1st DCA = 50% of original |
| `DcaSize2_Mult` | 0.33 | 2nd DCA = 33% of original |
| `MaxDcaAddons` | 2 | Max DCA positions |

### ⚙️ Thuật Toán

```cpp
void ManageDCA(Position pos) {
    // Calculate profit in R (using ORIGINAL SL!)
    double profitR = CalcProfitInR(pos.ticket);
    
    // DCA #1
    if(profitR >= DcaLevel1_R && !pos.dca1Added) {
        if(EnableDCA && CheckEquityHealth()) {
            double addLots = pos.originalLot × DcaSize1_Mult;
            
            if(GetSideLots(direction) + addLots <= MaxLot) {
                AddDCAPosition(direction, addLots);
                pos.dca1Added = true;
                pos.dcaCount++;
            }
        }
    }
    
    // DCA #2
    if(profitR >= DcaLevel2_R && !pos.dca2Added) {
        (similar logic)
    }
}
```

### ⚠️ QUAN TRỌNG: Profit in R

```cpp
// ❌ SAI: Dùng current SL
double risk = entry - currentSL;  // SL đã move về BE!
double profitR = profit / risk;   // R sai!

// ✅ ĐÚNG: Dùng ORIGINAL SL
double risk = entry - originalSL;  // SL ban đầu (không đổi)
double profitR = profit / risk;    // R chính xác!
```

### 💡 Ví Dụ DCA

```
Trade Timeline:
──────────────────────────────────────

T0: Entry
  Price: 2650.00
  SL: 2649.00 (original SL - NEVER CHANGES for R calc)
  Lots: 0.30
  Risk: 100 points = 1R

T1: Price = 2650.75 (+75 pts = +0.75R)
  ✓ DCA Level 1 triggered!
  Add: 0.15 lots
  Total: 0.45 lots
  Current SL: 2649.00 (unchanged)

T2: Price = 2651.00 (+100 pts = +1R)
  ✓ Breakeven triggered!
  Move SL: 2649.00 → 2650.00 (entry)
  Total: 0.45 lots
  
  ⚠️ NOTE: Original SL = 2649.00 (for R calc)
           Current SL = 2650.00 (for protection)

T3: Price = 2651.50 (+150 pts = +1.5R)
  ✓ DCA Level 2 triggered!
  Add: 0.10 lots
  Total: 0.55 lots
  Current SL: 2650.00 (at BE)
  
  Profit calculation still uses:
    profitR = (2651.50 - 2650.00) / (2650.00 - 2649.00)
            = 150 pts / 100 pts
            = 1.5R ✅

T4: Price = 2652.00 (+200 pts = +2R)
  ✓ Trailing triggered!
  Move SL: 2650.00 → 2651.00
  Total: 0.55 lots
```

### 🛡️ DCA Filters

#### 1. Equity Health Check
```cpp
bool CheckEquityHealth() {
    if(!DcaCheckEquity) return true;
    
    double currentEquity = GetCurrentEquity();
    double minEquity = startDayBalance × (DcaMinEquityPct / 100);
    
    if(currentEquity < minEquity) {
        Print("DCA Blocked: Equity too low");
        return false;
    }
    return true;
}
```

#### 2. Confluence Check (Optional)
```cpp
bool CheckDCAConfluence(int direction) {
    if(!DcaRequireConfluence) return true;
    
    // Check for new BOS/Sweep/OB in same direction
    // Hook into detector to validate
    return true; // Placeholder
}
```

#### 3. Lot Limit Check
```cpp
// Don't exceed MaxLotPerSide
if(GetSideLots(direction) + addLots > MaxLotPerSide) {
    Print("DCA skipped: would exceed MaxLot");
    return false;
}
```

---

## 3️⃣ Breakeven

### 🎯 Mục Đích
Bảo vệ vốn bằng cách di chuyển SL về entry price khi đã có profit.

### ⚙️ Cơ Chế

```cpp
bool MoveSLToBE(ulong ticket) {
    // Trigger: profit >= BeLevel_R (default: 1R)
    double profitR = CalcProfitInR(ticket);
    
    if(profitR >= BeLevel_R && !pos.movedToBE) {
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        
        // Move SL to entry
        ModifyPosition(ticket, newSL: openPrice);
        
        // Update ALL positions in same direction
        for(each position in same direction) {
            MoveSLToBE(position);
        }
        
        pos.movedToBE = true;
        return true;
    }
    return false;
}
```

### 📊 Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpEnableBE` | true | Enable/disable BE |
| `InpBeLevel_R` | 1.0 | Trigger at +1R profit |

### 💡 Ví Dụ

```
Setup:
  Entry: 2650.00
  SL: 2648.50 (150 points = 1R)
  Current: 2651.50 (+150 points = +1R)

Action:
  ✓ profitR = 1.0R (>= BeLevel_R)
  → Move SL: 2648.50 → 2650.00
  → Risk eliminated!
  
Result:
  Worst case: Close at BE ($0 loss)
  Best case: Continue to TP
```

---

## 4️⃣ Trailing Stop

### 🎯 Mục Đích
Lock in profits bằng cách di chuyển SL theo giá động.

### ⚙️ Cơ Chế

```cpp
bool TrailSL(ulong ticket) {
    double profitR = CalcProfitInR(ticket);
    
    // Only trail if profit >= TrailStartR
    if(profitR < TrailStartR) return false;
    
    // Calculate new SL based on ATR
    double atr = GetATR();
    double trailDistance = atr × TrailATRMult;
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentSL = PositionGetDouble(POSITION_SL);
    
    double newSL;
    if(posType == BUY) {
        newSL = currentPrice - trailDistance;
        if(newSL <= currentSL) return false; // Not better
    } else {
        newSL = currentPrice + trailDistance;
        if(newSL >= currentSL) return false; // Not better
    }
    
    // Check if moved enough (TrailStepR)
    if(profitR >= pos.lastTrailR + TrailStepR) {
        ModifyPosition(ticket, newSL);
        pos.lastTrailR = profitR;
        
        // Update all positions in same direction
        for(each position in same direction) {
            TrailSL(position, newSL);
        }
        
        return true;
    }
    return false;
}
```

### 📊 Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpEnableTrailing` | true | Enable/disable trailing |
| `InpTrailStartR` | 1.0 | Start trailing at +1R |
| `InpTrailStepR` | 0.5 | Move SL every +0.5R |
| `InpTrailATRMult` | 2.0 | Distance = 2× ATR |

### 💡 Ví Dụ

```
Setup:
  Entry: 2650.00
  Original SL: 2649.00 (1R = 100 pts)
  ATR: 5.0 points
  Trail Distance: 2× ATR = 10 points

Timeline:
──────────────────────────────────────
T1: Price = 2651.00 (+1R)
  ✓ Start trailing (>= TrailStartR)
  New SL = 2651.00 - 10 = 2650.90
  SL: 2649.00 → 2650.90
  lastTrailR = 1.0

T2: Price = 2651.30 (+1.3R)
  Check: 1.3R - 1.0R = 0.3R (< TrailStepR 0.5)
  → Skip (not moved enough)

T3: Price = 2651.50 (+1.5R)
  Check: 1.5R - 1.0R = 0.5R (>= TrailStepR)
  ✓ Trail again!
  New SL = 2651.50 - 10 = 2651.40
  SL: 2650.90 → 2651.40
  lastTrailR = 1.5

T4: Price = 2652.00 (+2.0R)
  Check: 2.0R - 1.5R = 0.5R (>= TrailStepR)
  ✓ Trail again!
  New SL = 2652.00 - 10 = 2651.90
  SL: 2651.40 → 2651.90
  lastTrailR = 2.0

Result:
  Locked in: 90 points profit (0.9R)
```

---

## 5️⃣ Daily MDD Protection

### 🎯 Mục Đích
Dừng trading và close all positions khi daily loss vượt limit.

### ⚙️ Cơ Chế

```cpp
bool CheckDailyMDD() {
    if(!UseDailyMDD) return true;
    
    ResetDailyTracking(); // Check if new day
    
    if(tradingHalted) return false;
    
    // Calculate daily P/L
    double current = UseEquityMDD ? equity : balance;
    double start = startDayBalance;
    double dailyPL = ((current - start) / start) × 100;
    
    if(dailyPL <= -DailyMddMax) {
        Print("DAILY MDD EXCEEDED: ", dailyPL, "%");
        
        // Close all positions
        CloseAllPositions("Daily MDD");
        
        // Halt trading until next day
        tradingHalted = true;
        
        return false;
    }
    
    return true;
}
```

### 📊 Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpUseDailyMDD` | true | Enable/disable MDD |
| `InpDailyMddMax` | 8.0% | Max daily drawdown |
| `InpUseEquityMDD` | true | Use equity vs balance |
| `InpDailyResetHour` | 6 | Reset hour (GMT+7) |

### 💡 Ví Dụ

```
Day Start (6h GMT+7):
  Balance: $10,000
  startDayBalance = $10,000
  MDD Limit: -8% = -$800

Scenario 1: Hit MDD
──────────────────────────────────────
T1: 10:00 - Loss -$300
  Equity: $9,700
  Daily P/L: -3% ✓ OK

T2: 14:00 - Loss -$500 (cumulative -$800)
  Equity: $9,200
  Daily P/L: -8% ⚠️ AT LIMIT
  
T3: 15:00 - Loss -$50 more
  Equity: $9,150
  Daily P/L: -8.5% ❌ EXCEEDED!
  
  → Close all positions immediately
  → Halt trading
  → Log: "DAILY MDD EXCEEDED"

Next Day (6h GMT+7):
  Reset tracking
  startDayBalance = $9,150
  tradingHalted = false
  → Resume trading ✓
```

### 🔄 Daily Reset

```cpp
void ResetDailyTracking() {
    int currentHour = GetLocalHour(); // GMT+7
    
    // Check if new day AND past reset hour
    if(lastDayCheck != currentDay && currentHour >= DailyResetHour) {
        startDayBalance = AccountBalance();
        initialBalance = startDayBalance;
        lastDayCheck = currentDay;
        tradingHalted = false;
        
        // Update dynamic MaxLot
        UpdateMaxLotPerSide();
        
        Print("DAILY RESET at 6h GMT+7");
        Print("Initial Balance: $", initialBalance);
    }
}
```

---

## 6️⃣ Basket Management

### 🎯 Mục Đích
Quản lý toàn bộ vị thế như một basket, close all khi đạt TP/SL.

### ⚙️ Cơ Chế

```cpp
void CheckBasketTPSL() {
    double plPct = GetBasketFloatingPLPct();
    
    // Basket TP
    if(EnableBasketTP && plPct >= BasketTPPct) {
        Print("Basket TP Hit: ", plPct, "%");
        CloseAllPositions("Basket TP");
        return;
    }
    
    // Basket SL
    if(EnableBasketSL && plPct <= -BasketSLPct) {
        Print("Basket SL Hit: ", plPct, "%");
        CloseAllPositions("Basket SL");
        return;
    }
}

double GetBasketFloatingPLPct() {
    double totalPL = 0;
    for(all positions) {
        totalPL += PositionGetDouble(POSITION_PROFIT);
    }
    return (totalPL / balance) × 100;
}
```

### 📊 Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpBasketTPPct` | 0.3% | Basket TP (% balance) |
| `InpBasketSLPct` | 1.2% | Basket SL (% balance) |
| `InpEndOfDayHour` | 0 | EOD close hour (disabled) |

### 💡 Ví Dụ

```
Scenario: Multiple Positions
──────────────────────────────────────
Balance: $10,000
Basket TP: +0.3% = +$30
Basket SL: -1.2% = -$120

Positions:
  #1: +$15 (LONG)
  #2: +$20 (LONG)
  #3: -$5 (SHORT)
  
Total Floating P/L: +$30
P/L %: +0.3%

Action:
  ✓ Basket TP reached!
  → Close all 3 positions
  → Realized: +$30
```

---

## 7️⃣ Position Tracking

### 📊 PositionDCA Struct

```cpp
struct PositionDCA {
    ulong    ticket;
    double   entryPrice;
    double   sl;              // Current SL (thay đổi)
    double   originalSL;      // Original SL (NEVER changes for R calc)
    double   tp;
    double   originalLot;
    int      dcaCount;
    bool     movedToBE;
    bool     dca1Added;
    bool     dca2Added;
    double   lastTrailR;      // Track last trail level
}
```

### ⚙️ Track Position

```cpp
void TrackPosition(ulong ticket, double entry, double sl, double tp, double lots) {
    // Check if already tracked
    for(int i = 0; i < ArraySize(positions); i++) {
        if(positions[i].ticket == ticket) {
            return; // Skip duplicate
        }
    }
    
    // Add new tracking
    int size = ArraySize(positions);
    ArrayResize(positions, size + 1);
    
    positions[size].ticket = ticket;
    positions[size].entryPrice = entry;
    positions[size].sl = sl;
    positions[size].originalSL = sl;  // ⚠️ Save ORIGINAL SL!
    positions[size].tp = tp;
    positions[size].originalLot = lots;
    positions[size].dcaCount = 0;
    positions[size].movedToBE = false;
    positions[size].dca1Added = false;
    positions[size].dca2Added = false;
    positions[size].lastTrailR = 0.0;
}
```

---

---

## 🆕 v2.0 Updates: Risk Overlays & Adaptive Management

### 1. Risk Overlays

#### A. Max Trades Per Day

```cpp
static int g_todayTrades = 0;
static datetime g_lastTradeDate = 0;

bool CanOpenNewTrade() {
    // Reset counter at new day
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDay = StringToTime(
        StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day)
    );
    
    if(currentDay != g_lastTradeDate) {
        g_todayTrades = 0;
        g_lastTradeDate = currentDay;
        Print("📅 New day: Trades reset to 0");
    }
    
    // Check limit
    if(g_todayTrades >= InpMaxTradesPerDay) {
        Print("⊘ Max trades/day reached: ", g_todayTrades, "/",
              InpMaxTradesPerDay);
        return false;
    }
    
    return true;
}

void OnTradeOpened() {
    g_todayTrades++;
    Print("📊 Today's trades: ", g_todayTrades, "/", InpMaxTradesPerDay);
}
```

#### B. Max Consecutive Loss + Cooldown

```cpp
static int g_consecLoss = 0;
static datetime g_cooldownUntil = 0;

void OnTradeClose(bool isWin, double profit) {
    if(isWin) {
        g_consecLoss = 0;
        g_cooldownUntil = 0;
        Print("✅ WIN - Streak reset");
    } else {
        g_consecLoss++;
        Print("❌ LOSS #", g_consecLoss);
        
        if(g_consecLoss >= InpMaxConsecLoss) {
            // Activate cooldown
            g_cooldownUntil = TimeCurrent() + 
                             InpCoolDownMinAfterLoss * 60;
            
            Print("═══════════════════════════════════════");
            Print("🛑 MAX CONSECUTIVE LOSSES: ", g_consecLoss);
            Print("🛑 COOLDOWN until: ", TimeToString(g_cooldownUntil));
            Print("═══════════════════════════════════════");
        }
    }
}

bool CanOpenNewTrade() {
    // ... max trades check ...
    
    // Check cooldown
    if(g_cooldownUntil > 0 && TimeCurrent() < g_cooldownUntil) {
        int remainMin = (int)((g_cooldownUntil - TimeCurrent()) / 60);
        Print("⊘ In cooldown: ", remainMin, " min remaining");
        return false;
    }
    
    // Check consecutive losses
    if(g_consecLoss >= InpMaxConsecLoss) {
        Print("⊘ Max consecutive losses: ", g_consecLoss);
        return false;
    }
    
    return true;
}
```

#### 📊 New Parameters
```cpp
input int InpMaxTradesPerDay     = 6;    // Max trades per day
input int InpMaxConsecLoss       = 3;    // Max consecutive losses
input int InpCoolDownMinAfterLoss= 60;   // Cooldown minutes
```

#### 💡 Ví Dụ: Cooldown Activation
```
Timeline:
──────────────────────────────────────
08:00 - Trade #1: LOSS -$150
  consecLoss = 1

10:00 - Trade #2: LOSS -$200
  consecLoss = 2

12:00 - Trade #3: LOSS -$180
  consecLoss = 3
  → MAX REACHED!
  → cooldownUntil = 13:00 (12:00 + 60min)

12:30 - New signal detected
  CanOpenNewTrade()?
  → In cooldown: 30min remaining
  → BLOCKED ❌

13:05 - New signal detected
  CanOpenNewTrade()?
  → Cooldown expired
  → consecLoss still = 3
  → BLOCKED ❌ (need a win to reset)

14:00 - Manual trade (or wait for win)
  Trade #4: WIN +$250
  → consecLoss = 0
  → cooldownUntil = 0
  → RESUME TRADING ✅
```

---

### 2. Adaptive DCA by Regime

#### ⚙️ DCA Levels by Regime

```cpp
void SetDCAByRegime(ENUM_REGIME regime) {
    switch(regime) {
        case REGIME_LOW:
            // Aggressive DCA (low volatility)
            m_dcaLevel1_R = 0.75;
            m_dcaLevel2_R = 1.50;
            m_dcaSize1_Mult = 0.50;
            m_dcaSize2_Mult = 0.33;
            m_maxDcaAddons = 2;
            Print("📊 DCA: LOW regime (aggressive)");
            break;
            
        case REGIME_MID:
            // Moderate DCA
            m_dcaLevel1_R = 0.90;
            m_dcaLevel2_R = 1.60;
            m_dcaSize1_Mult = 0.45;
            m_dcaSize2_Mult = 0.30;
            m_maxDcaAddons = 2;
            Print("📊 DCA: MID regime (moderate)");
            break;
            
        case REGIME_HIGH:
            // Conservative DCA (high volatility)
            m_dcaLevel1_R = 1.00;
            m_dcaLevel2_R = 0;      // Disable L2
            m_dcaSize1_Mult = 0.33;
            m_dcaSize2_Mult = 0;
            m_maxDcaAddons = 1;
            Print("📊 DCA: HIGH regime (conservative, L2 disabled)");
            break;
    }
}
```

#### 📊 DCA Comparison

|| LOW Regime | MID Regime | HIGH Regime |
||------------|------------|-------------|
|| **Level 1** | +0.75R | +0.90R | +1.00R |
|| **Size 1** | 0.50× | 0.45× | 0.33× |
|| **Level 2** | +1.50R | +1.60R | Disabled |
|| **Size 2** | 0.33× | 0.30× | - |
|| **Max Addons** | 2 | 2 | 1 |

#### 💡 Rationale
```
LOW Volatility:
  → Price moves smoother
  → DCA earlier (+0.75R)
  → Larger sizes (0.50×)
  → 2 levels allowed

HIGH Volatility:
  → Price whipsaws more
  → DCA later (+1.00R)
  → Smaller sizes (0.33×)
  → Only 1 level (L2 disabled)
```

---

### 3. Adaptive Trailing by Regime

#### ⚙️ Trailing Parameters by Regime

```cpp
void UpdateTrailingByRegime(ENUM_REGIME regime) {
    // Start threshold
    switch(regime) {
        case REGIME_LOW:
            m_trailStartR = 1.0;
            m_trailStepR = 0.6;
            m_trailATRMult = 2.0;
            break;
            
        case REGIME_MID:
            m_trailStartR = 1.2;
            m_trailStepR = 0.5;
            m_trailATRMult = 2.5;
            break;
            
        case REGIME_HIGH:
            m_trailStartR = 1.5;
            m_trailStepR = 0.3;
            m_trailATRMult = 3.0;
            break;
    }
    
    Print("📊 Trailing: Start ", m_trailStartR, "R | Step ",
          m_trailStepR, "R | Distance ", m_trailATRMult, "× ATR");
}
```

#### 📊 Trailing Comparison

|| LOW | MID | HIGH |
||-----|-----|------|
|| **Start** | +1.0R | +1.2R | +1.5R |
|| **Step** | 0.6R | 0.5R | 0.3R |
|| **ATR Mult** | 2.0× | 2.5× | 3.0× |

#### 💡 Ví Dụ

```
REGIME_LOW (ATR = 4.0):
──────────────────────────────────────
Entry: 2650.00
Original SL: 2649.00 (1R = 100 pts)

Timeline:
  +1.0R (2651.00) → Start trailing
    New SL = 2651.00 - (2.0 × 4.0) = 2650.92
    
  +1.6R (2651.60) → Trail again (+0.6R step)
    New SL = 2651.60 - 8.0 = 2651.52
    
  +2.2R (2652.20) → Trail again (+0.6R step)
    New SL = 2652.20 - 8.0 = 2652.12

REGIME_HIGH (ATR = 9.0):
──────────────────────────────────────
Entry: 2650.00
Original SL: 2649.00 (1R = 100 pts)

Timeline:
  +1.5R (2651.50) → Start trailing (later!)
    New SL = 2651.50 - (3.0 × 9.0) = 2651.23
    
  +1.8R (2651.80) → Trail again (+0.3R step)
    New SL = 2651.80 - 27.0 = 2651.53
    
  +2.1R (2652.10) → Trail again (+0.3R step)
    New SL = 2652.10 - 27.0 = 2651.83

→ HIGH regime: Wider distance, more frequent updates
```

---

### 4. Implementation trong ManageOpenPositions()

```cpp
void ManageOpenPositions(ENUM_REGIME regime) {
    // Update DCA/Trailing params by regime
    SetDCAByRegime(regime);
    UpdateTrailingByRegime(regime);
    
    // ... existing checks ...
    
    for(int i = ArraySize(positions) - 1; i >= 0; i--) {
        ulong ticket = positions[i].ticket;
        if(!PositionSelectByTicket(ticket)) {
            ArrayRemove(positions, i, 1);
            continue;
        }
        
        double profitR = CalcProfitInR(ticket);
        int direction = GetPositionDirection(ticket);
        
        // === TRAILING (regime-adaptive) ===
        if(m_enableTrailing) {
            if(profitR >= m_trailStartR) {  // Threshold by regime
                if(profitR >= positions[i].lastTrailR + m_trailStepR) {
                    if(TrailSL(ticket)) {
                        positions[i].lastTrailR = profitR;
                    }
                }
            }
        }
        
        // === BREAKEVEN (unchanged) ===
        if(m_enableBE && profitR >= m_beLevel_R && 
           !positions[i].movedToBE) {
            if(MoveSLToBE(ticket)) {
                positions[i].movedToBE = true;
            }
        }
        
        // === DCA (regime-adaptive levels) ===
        if(m_enableDCA) {
            // DCA #1 (threshold by regime)
            if(profitR >= m_dcaLevel1_R && !positions[i].dca1Added) {
                if(CheckEquityHealth() && CheckDCAConfluence(direction)) {
                    double addLots = positions[i].originalLot * m_dcaSize1_Mult;
                    if(AddDCAPosition(direction, addLots)) {
                        positions[i].dca1Added = true;
                        positions[i].dcaCount++;
                    }
                }
            }
            
            // DCA #2 (may be disabled in HIGH regime)
            if(m_dcaLevel2_R > 0 &&  // Check if enabled
               profitR >= m_dcaLevel2_R && !positions[i].dca2Added) {
                if(CheckEquityHealth()) {
                    double addLots = positions[i].originalLot * m_dcaSize2_Mult;
                    if(AddDCAPosition(direction, addLots)) {
                        positions[i].dca2Added = true;
                        positions[i].dcaCount++;
                    }
                }
            }
        }
    }
}
```

---

### 5. New Parameters

```cpp
// Risk Overlays
input int InpMaxTradesPerDay     = 6;
input int InpMaxConsecLoss       = 3;
input int InpCoolDownMinAfterLoss= 60;

// Adaptive DCA (will be set by regime, these are defaults)
input double InpDcaLevel1_R_Low  = 0.75;
input double InpDcaLevel1_R_Mid  = 0.90;
input double InpDcaLevel1_R_High = 1.00;

// Adaptive Trailing (will be set by regime)
input double InpTrailStartR_Low  = 1.0;
input double InpTrailStartR_Mid  = 1.2;
input double InpTrailStartR_High = 1.5;

input double InpTrailStepR_Low   = 0.6;
input double InpTrailStepR_Mid   = 0.5;
input double InpTrailStepR_High  = 0.3;
```

---

### 6. Complete Scenario: Adaptive Risk Management

```
Scenario: Trade in HIGH regime
──────────────────────────────────────

1. REGIME DETECTION
   ATR: 9.0 points
   P70: 7.5
   → REGIME_HIGH
   
   DCA Settings:
     Level 1: +1.00R (0.33× size)
     Level 2: DISABLED
   
   Trailing Settings:
     Start: +1.5R
     Step: 0.3R
     Distance: 3.0× ATR = 27 points

2. ENTRY
   Entry: 2650.00
   SL: 2638.30 (min stop 1.3× ATR = 11.7 pts)
   Lots: 3.0
   Risk: 1R = 117 points

3. POSITION MANAGEMENT

   T1: Price = 2651.17 (+117 pts = +1.0R)
     DCA Level 1: 1.0R
     profitR < 1.00R
     → Skip DCA

   T2: Price = 2651.40 (+140 pts = +1.20R)
     profitR >= 1.00R
     ✓ DCA #1 triggered!
     Add: 3.0 × 0.33 = 1.0 lot
     Total: 4.0 lots
     
   T3: Price = 2652.25 (+225 pts = +1.92R)
     profitR >= 1.50R (trail start)
     ✓ Trailing activated!
     New SL = 2652.25 - 27 = 2651.98
     
   T4: Price = 2652.60 (+260 pts = +2.22R)
     Check: 2.22 - 1.92 = 0.30R (>= step 0.3R)
     ✓ Trail again!
     New SL = 2652.60 - 27 = 2652.33

Result:
  → 1 DCA level only (L2 disabled in HIGH)
  → Trailing started later (+1.5R vs +1.0R)
  → More frequent trail updates (0.3R vs 0.5R)
  → Wider trail distance (27 pts vs 10 pts)
```

---

### 7. Benefits of Adaptive Management

#### ✅ LOW Regime
- Early DCA (+0.75R) → Maximize position in smooth trends
- Larger DCA sizes → Bigger profits
- Tighter trailing (2× ATR) → Lock profits faster

#### ✅ MID Regime
- Balanced approach
- Standard settings
- Most common regime

#### ✅ HIGH Regime
- Late DCA (+1.0R) → Only add when clearly winning
- Single DCA only → Limit exposure
- Wider trailing (3× ATR) → Avoid being stopped by noise
- Later trail start (+1.5R) → Reduce whipsaw

---

### 8. Risk Overlay Decision Tree

```
New Signal Detected
  │
  ├─► TodayTrades >= MaxTradesPerDay?
  │   YES → Block ❌
  │   NO ↓
  │
  ├─► In Cooldown?
  │   YES → Block ❌
  │   NO ↓
  │
  ├─► ConsecLoss >= MaxConsecLoss?
  │   YES → Block ❌
  │   NO ↓
  │
  └─► CanOpenNewTrade = TRUE ✅
      → Proceed with entry
```

---

## 🎓 Đọc Tiếp

- [06_STATS_DASHBOARD.md](06_STATS_DASHBOARD.md) - Statistics & Dashboard
- [09_EXAMPLES.md](09_EXAMPLES.md) - Real risk management examples

