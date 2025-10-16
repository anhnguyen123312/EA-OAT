# 06. Thống Kê & Dashboard

## 📍 Tổng Quan

**Files**: `stats_manager.mqh`, `draw_debug.mqh`

Hai module này cung cấp:
1. **Stats Tracking** - Theo dõi hiệu suất theo pattern
2. **Real-time Dashboard** - Hiển thị trạng thái bot
3. **Chart Visualization** - Vẽ BOS, Sweep, OB, FVG

---

## 1️⃣ Stats Manager

### 🎯 Mục Đích
Track và phân tích performance của từng pattern type.

### 📊 Pattern Types

```cpp
enum PATTERN_TYPE {
    PATTERN_BOS_OB = 0,        // BOS + Order Block
    PATTERN_BOS_FVG = 1,       // BOS + FVG
    PATTERN_SWEEP_OB = 2,      // Sweep + OB
    PATTERN_SWEEP_FVG = 3,     // Sweep + FVG
    PATTERN_MOMO = 4,          // Momentum Only
    PATTERN_CONFLUENCE = 5,    // BOS + Sweep + (OB/FVG)
    PATTERN_OTHER = 6
}
```

### 📝 Trade Record Structure

```cpp
struct TradeRecord {
    ulong    ticket;
    datetime openTime;
    datetime closeTime;
    int      direction;        // 1=BUY, -1=SELL
    double   openPrice;
    double   closePrice;
    double   lots;
    double   profit;
    int      patternType;
    bool     isWin;
    double   rr;               // Actual R:R achieved
    int      slPips;
    int      tpPips;
}
```

### ⚙️ Recording Trades

```cpp
void RecordTrade(ulong ticket, int direction, double openPrice,
                 double lots, int patternType, double slPrice, 
                 double tpPrice) {
    
    int size = ArraySize(trades);
    if(size >= maxHistory) {
        ArrayRemove(trades, 0, 1); // Remove oldest
    }
    
    ArrayResize(trades, size + 1);
    
    trades[size].ticket = ticket;
    trades[size].openTime = TimeCurrent();
    trades[size].direction = direction;
    trades[size].openPrice = openPrice;
    trades[size].lots = lots;
    trades[size].patternType = patternType;
    
    // Calculate SL/TP in pips
    if(direction == 1) {
        slPips = (int)((openPrice - slPrice) / (_Point × 10));
        tpPips = (int)((tpPrice - openPrice) / (_Point × 10));
    } else {
        slPips = (int)((slPrice - openPrice) / (_Point × 10));
        tpPips = (int)((openPrice - tpPrice) / (_Point × 10));
    }
    
    trades[size].slPips = slPips;
    trades[size].tpPips = tpPips;
    trades[size].rr = (slPips > 0) ? ((double)tpPips / slPips) : 0;
    
    Print("📝 Trade recorded: #", ticket, " | Pattern: ",
          GetPatternName(patternType));
}
```

### ⚙️ Updating Closed Trades

```cpp
void UpdateClosedTrade(ulong ticket, double closePrice, double profit) {
    for(int i = ArraySize(trades) - 1; i >= 0; i--) {
        if(trades[i].ticket == ticket) {
            trades[i].closeTime = TimeCurrent();
            trades[i].closePrice = closePrice;
            trades[i].profit = profit;
            trades[i].isWin = (profit > 0);
            
            // Recalculate stats
            CalculateStats();
            
            string result = trades[i].isWin ? "WIN ✅" : "LOSS ❌";
            Print("📊 Trade closed: #", ticket, " | ", result,
                  " | Profit: $", DoubleToString(profit, 2));
            break;
        }
    }
}
```

### 📊 Pattern Statistics

```cpp
struct PatternStats {
    int      totalTrades;
    int      wins;
    int      losses;
    double   winRate;
    double   totalProfit;
    double   avgProfit;
    double   avgWin;
    double   avgLoss;
    double   profitFactor;
    double   avgRR;
}

void UpdatePatternStats(int patternType) {
    PatternStats stats;
    stats.totalTrades = 0;
    stats.wins = 0;
    stats.losses = 0;
    stats.totalProfit = 0;
    double totalWinProfit = 0;
    double totalLossProfit = 0;
    
    // Scan all closed trades
    for(int i = 0; i < ArraySize(trades); i++) {
        if(trades[i].closeTime > 0 && 
           trades[i].patternType == patternType) {
            
            stats.totalTrades++;
            stats.totalProfit += trades[i].profit;
            
            if(trades[i].isWin) {
                stats.wins++;
                totalWinProfit += trades[i].profit;
            } else {
                stats.losses++;
                totalLossProfit += MathAbs(trades[i].profit);
            }
        }
    }
    
    // Calculate metrics
    if(stats.totalTrades > 0) {
        stats.winRate = ((double)stats.wins / stats.totalTrades) × 100.0;
        stats.avgProfit = stats.totalProfit / stats.totalTrades;
    }
    
    if(stats.wins > 0) {
        stats.avgWin = totalWinProfit / stats.wins;
    }
    
    if(stats.losses > 0) {
        stats.avgLoss = totalLossProfit / stats.losses;
    }
    
    if(totalLossProfit > 0) {
        stats.profitFactor = totalWinProfit / totalLossProfit;
    }
    
    return stats;
}
```

### 💡 Ví Dụ Stats

```
PATTERN_CONFLUENCE Statistics:
──────────────────────────────────────
Total Trades: 15
Wins: 12
Losses: 3
Win Rate: 80.0%

Total Profit: $456.00
Avg Profit: $30.40 per trade

Avg Win: $50.00
Avg Loss: -$28.00
Profit Factor: 2.14

Avg RR: 2.3
```

---

## 2️⃣ Dashboard Display

### 🎯 Mục Đích
Hiển thị real-time trạng thái bot trên chart.

### 📊 Dashboard Layout

```
╔═══ SMC/ICT EA v1.2 - DASHBOARD ═══╗
│ STATE: SIGNAL DETECTED              │
├─────────────────────────────────────┤
│ Balance:    $10,000.00 | MaxLot: 3.0│
│ Init Bal:   $10,000.00 (Today 6h)   │
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
│ ╔═══════════ PERFORMANCE STATS ═══════════╗│
│ ║ Total: 45 | Win: 32 | Loss: 13       ║│
│ ║ Win Rate: 71.1% | PF: 2.35           ║│
│ ║ Total Profit: $4,523.00              ║│
│ ╚═════════════════════════════════════════╝│
│                                             │
│ 📊 WIN/LOSS BY PATTERN:                    │
│ ├─ BOS+OB:    12 trades | 9W/3L | WR:75.0% │
│ ├─ BOS+FVG:   8 trades | 6W/2L | WR:75.0%  │
│ ├─ Sweep+OB:  5 trades | 3W/2L | WR:60.0%  │
│ ├─ Sweep+FVG: 4 trades | 3W/1L | WR:75.0%  │
│ ├─ Momentum:  6 trades | 4W/2L | WR:66.7%  │
│ └─ Confluence:10 trades | 8W/2L | WR:80.0% │
└─────────────────────────────────────────────┘
```

### ⚙️ Update Dashboard Code

```cpp
void UpdateDashboard(string stateText, CRiskManager *riskMgr,
                     CExecutor *executor, CDetector *detector,
                     BOSSignal &lastBOS, SweepSignal &lastSweep,
                     OrderBlock &lastOB, FVGSignal &lastFVG,
                     double lastScore, CStatsManager *stats) {
    
    // Create background panel
    CreateRectangleLabel("Dashboard_BG", 10, 60, 520, 700,
                        C'250,250,250', CORNER_LEFT_UPPER);
    
    // Build dashboard text
    string dashboard = "";
    dashboard += "┌─────────────────────────────────────────────┐\n";
    dashboard += "│ OAT V4 - ICT/SMC + Momentum EA              │\n";
    dashboard += "├─────────────────────────────────────────────┤\n";
    
    // Add state
    dashboard += "│ STATE: " + stateText;
    int padLen = 40 - StringLen(stateText);
    for(int i = 0; i < padLen; i++) dashboard += " ";
    dashboard += "│\n";
    
    // Account info
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double maxLot = riskMgr.GetMaxLotPerSide();
    
    dashboard += "├─────────────────────────────────────────────┤\n";
    dashboard += StringFormat("│ Balance:    $%10.2f | MaxLot: %.2f   │\n",
                             balance, maxLot);
    dashboard += StringFormat("│ Equity:     $%10.2f                  │\n",
                             equity);
    
    // Floating P/L
    double floatingPL = riskMgr.GetBasketFloatingPL();
    double floatingPct = riskMgr.GetBasketFloatingPLPct();
    dashboard += StringFormat("│ Floating PL: $%9.2f (%+.2f%%)         │\n",
                             floatingPL, floatingPct);
    
    // Active structures
    dashboard += "├─────────────────────────────────────────────┤\n";
    dashboard += "│ ACTIVE STRUCTURES:                          │\n";
    
    if(lastBOS.valid) {
        dashboard += StringFormat("│ ├─ BOS %s @ %.2f                      │\n",
                                 (lastBOS.direction == 1 ? "UP  " : "DOWN"),
                                 lastBOS.breakLevel);
    } else {
        dashboard += "│ ├─ BOS: None                                │\n";
    }
    
    // Signal score
    if(lastScore >= 100.0) {
        dashboard += StringFormat("│ SIGNAL: VALID | Score: %.1f ★         │\n",
                                 lastScore);
    } else {
        dashboard += "│ SIGNAL: NONE                                │\n";
    }
    
    // Positions
    dashboard += "├─────────────────────────────────────────────┤\n";
    dashboard += "│ POSITIONS:                                  │\n";
    
    int longPos = 0, shortPos = 0;
    double longLots = 0, shortLots = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == _Symbol) {
            int type = (int)PositionGetInteger(POSITION_TYPE);
            double lots = PositionGetDouble(POSITION_VOLUME);
            if(type == POSITION_TYPE_BUY) {
                longPos++;
                longLots += lots;
            } else {
                shortPos++;
                shortLots += lots;
            }
        }
    }
    
    dashboard += StringFormat("│ ├─ LONG:  %d orders | %.2f lots            │\n",
                             longPos, longLots);
    dashboard += StringFormat("│ └─ SHORT: %d orders | %.2f lots            │\n",
                             shortPos, shortLots);
    
    // Performance stats
    if(stats != NULL) {
        PatternStats overall = stats.GetOverallStats();
        
        dashboard += "├─────────────────────────────────────────────┤\n";
        dashboard += "│ ╔═══════════ PERFORMANCE STATS ═══════════╗ │\n";
        dashboard += StringFormat("│ ║ Total: %3d | Win: %3d | Loss: %3d       ║ │\n",
                                 overall.totalTrades, overall.wins, overall.losses);
        dashboard += StringFormat("│ ║ Win Rate: %5.1f%% | PF: %.2f             ║ │\n",
                                 overall.winRate, overall.profitFactor);
        dashboard += "│ ╚═════════════════════════════════════════╝ │\n";
        
        // Pattern breakdown
        dashboard += "│ 📊 WIN/LOSS BY PATTERN:                    │\n";
        
        PatternStats conf = stats.GetPatternStats(PATTERN_CONFLUENCE);
        if(conf.totalTrades > 0) {
            dashboard += StringFormat("│ └─ Confluence:%2d trades | %2dW/%2dL | WR:%5.1f%% │\n",
                                     conf.totalTrades, conf.wins, conf.losses, conf.winRate);
        }
    }
    
    dashboard += "└─────────────────────────────────────────────┘";
    
    // Draw text on chart
    CreateLabel("Dashboard", 25, 75, dashboard, 
               C'0,0,0', "Consolas", 10);
    
    ChartRedraw();
}
```

---

## 3️⃣ Chart Visualization

### 🎯 BOS Marker

```cpp
void MarkBOS(int barIndex, int direction, double level, string tag) {
    string objName = "BOS_" + tag;
    datetime time = iTime(_Symbol, PERIOD_CURRENT, barIndex);
    
    int arrowCode = (direction == 1) ? 233 : 234; // ↑/↓
    
    if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, level)) {
        ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, objName, OBJPROP_COLOR,
                        direction == 1 ? clrDodgerBlue : clrOrangeRed);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    }
}
```

### 🎯 Sweep Marker

```cpp
void MarkSweep(double level, int side, datetime time, string tag) {
    string objName = "SWEEP_" + tag;
    datetime endTime = time + PeriodSeconds(PERIOD_CURRENT) × 50;
    
    if(ObjectCreate(0, objName, OBJ_TREND, 0, time, level, endTime, level)) {
        color clr = (side == 1) ? clrYellow : clrOrange;
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASHDOT);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    }
}
```

### 🎯 Order Block Rectangle

```cpp
void DrawOB(double top, double bottom, int direction,
            datetime startTime, string tag) {
    string objName = "OB_" + tag;
    datetime endTime = startTime + PeriodSeconds(PERIOD_CURRENT) × 120;
    
    if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                   startTime, top, endTime, bottom)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR,
                        direction == 1 ? clrDodgerBlue : clrOrangeRed);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        ObjectSetInteger(0, objName, OBJPROP_FILL, true);
    }
}
```

### 🎯 FVG Rectangle

```cpp
void DrawFVG(double top, double bottom, int direction, int state,
             datetime startTime, string tag) {
    string objName = "FVG_" + tag;
    datetime endTime = startTime + PeriodSeconds(PERIOD_CURRENT) × 60;
    
    color clr;
    if(state == 0) clr = clrLimeGreen;       // Valid
    else if(state == 1) clr = clrYellow;     // Mitigated
    else clr = clrGray;                      // Completed
    
    if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                   startTime, top, endTime, bottom)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    }
}
```

---

## 💡 Usage Examples

### Example 1: Tracking Performance

```cpp
// In OnTrade() when order fills:
void OnTrade() {
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            // Get details
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            double lots = PositionGetDouble(POSITION_VOLUME);
            int direction = (int)PositionGetInteger(POSITION_TYPE);
            
            // Determine pattern
            int patternType = GetPatternType(g_lastCandidate);
            
            // Record in stats
            g_stats.RecordTrade(ticket, direction, entry, lots,
                               patternType, sl, tp);
        }
    }
}

// When position closes:
void OnTrade() {
    if(HistorySelect(TimeCurrent() - 86400, TimeCurrent())) {
        for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
            // Get deal info
            ulong dealTicket = HistoryDealGetTicket(i);
            double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
            double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
            
            // Update stats
            g_stats.UpdateClosedTrade(posTicket, closePrice, profit);
        }
    }
}
```

### Example 2: Dashboard States

```
State 1: SCANNING
  → Waiting for signals
  → No active structures

State 2: BOS DETECTED - Waiting
  → BOS found but no POI yet
  → Score < 100

State 3: SIGNAL DETECTED
  → Valid candidate
  → Score >= 100
  → Looking for trigger

State 4: TRADING HALTED - MDD
  → Daily MDD exceeded
  → All positions closed
  → Waiting for next day

State 5: SPREAD TOO WIDE
  → Spread exceeds limit
  → No new entries
  → Managing existing only

State 6: OUTSIDE SESSION
  → Not in trading hours
  → Managing existing only
```

---

## 🎓 Key Points

### ✅ Best Practices
1. **Track all trades** - Don't skip any
2. **Update stats immediately** - When position closes
3. **Show real-time data** - Dashboard updates every tick
4. **Color code visually** - Green/Red for easy reading
5. **Log pattern performance** - For optimization

### 📊 Metrics to Monitor
1. **Win Rate by Pattern** - Which setups work best?
2. **Profit Factor** - Wins vs losses ratio
3. **Avg R:R Achieved** - Actual vs expected
4. **Daily P/L** - For MDD monitoring
5. **Floating P/L** - Current exposure

### 🎨 Visualization Tips
1. Use distinct colors for each structure type
2. Cleanup old objects (>24h) to reduce clutter
3. Make dashboard easily readable (contrasting colors)
4. Update dashboard on every state change
5. Log important events for debugging

---

## 🎓 Đọc Tiếp

- [07_CONFIGURATION.md](07_CONFIGURATION.md) - Dashboard & visualization settings
- [09_EXAMPLES.md](09_EXAMPLES.md) - Real stats examples

