//+------------------------------------------------------------------+
//|                                                   draw_debug.mqh |
//|                              Chart Drawing & Visualization       |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property version   "1.00"
#property strict

// Forward declarations
class CRiskManager;
class CExecutor;
class CDetector;

//+------------------------------------------------------------------+
//| Drawing Class - Chart visualization for debugging               |
//+------------------------------------------------------------------+
class CDrawDebug {
private:
    string   m_prefix;
    int      m_objectCounter;
    
public:
    CDrawDebug();
    ~CDrawDebug();
    
    void Init(string prefix);
    void CleanupOldObjects();
    
    void DrawOB(double top, double bottom, int direction, datetime startTime, string tag);
    void DrawFVG(double top, double bottom, int direction, int state, datetime startTime, string tag);
    void MarkBOS(int barIndex, int direction, double level, string tag);
    void MarkSweep(double level, int side, datetime time, string tag);
    void DrawLabel(string text, int x, int y, color clr, string tag);
    void UpdateDashboard(string stateText, CRiskManager *riskMgr, CExecutor *executor, 
                         CDetector *detector, BOSSignal &lastBOS, SweepSignal &lastSweep, 
                         OrderBlock &lastOB, FVGSignal &lastFVG, double lastScore);
    
private:
    string GenerateObjectName(string type);
    color GetColorByDirection(int direction);
    color GetColorByState(int state);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDrawDebug::CDrawDebug() {
    m_prefix = "SMC_";
    m_objectCounter = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CDrawDebug::~CDrawDebug() {
}

//+------------------------------------------------------------------+
//| Initialize with prefix                                           |
//+------------------------------------------------------------------+
void CDrawDebug::Init(string prefix) {
    m_prefix = prefix + "_";
}

//+------------------------------------------------------------------+
//| Generate unique object name                                      |
//+------------------------------------------------------------------+
string CDrawDebug::GenerateObjectName(string type) {
    m_objectCounter++;
    return m_prefix + type + "_" + IntegerToString(m_objectCounter) + "_" + IntegerToString(GetTickCount());
}

//+------------------------------------------------------------------+
//| Get color based on direction                                     |
//+------------------------------------------------------------------+
color CDrawDebug::GetColorByDirection(int direction) {
    if(direction == 1) return clrDodgerBlue;      // Bullish
    if(direction == -1) return clrOrangeRed;      // Bearish
    return clrGray;
}

//+------------------------------------------------------------------+
//| Get color based on FVG state                                     |
//+------------------------------------------------------------------+
color CDrawDebug::GetColorByState(int state) {
    if(state == 0) return clrLimeGreen;           // Valid
    if(state == 1) return clrYellow;              // Mitigated
    if(state == 2) return clrGray;                // Completed
    return clrGray;
}

//+------------------------------------------------------------------+
//| Cleanup old objects                                              |
//+------------------------------------------------------------------+
void CDrawDebug::CleanupOldObjects() {
    datetime currentTime = TimeCurrent();
    int totalObjects = ObjectsTotal(0);
    
    for(int i = totalObjects - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        
        // Only cleanup our objects
        if(StringFind(objName, m_prefix) == 0) {
            // Check if object is older than 24 hours
            datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
            if(currentTime - objTime > 86400) { // 24 hours
                ObjectDelete(0, objName);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Order Block rectangle                                       |
//+------------------------------------------------------------------+
void CDrawDebug::DrawOB(double top, double bottom, int direction, datetime startTime, string tag) {
    string objName = GenerateObjectName("OB_" + tag);
    
    datetime endTime = startTime + PeriodSeconds(PERIOD_CURRENT) * 120; // Extend 120 bars
    
    if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, GetColorByDirection(direction));
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        ObjectSetInteger(0, objName, OBJPROP_FILL, true);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
        
        // Add text label
        string labelName = objName + "_Label";
        double labelPrice = (top + bottom) / 2;
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, labelPrice)) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "OB " + (direction == 1 ? "Demand" : "Supply"));
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, GetColorByDirection(direction));
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Fair Value Gap rectangle                                    |
//+------------------------------------------------------------------+
void CDrawDebug::DrawFVG(double top, double bottom, int direction, int state, datetime startTime, string tag) {
    string objName = GenerateObjectName("FVG_" + tag);
    
    datetime endTime = startTime + PeriodSeconds(PERIOD_CURRENT) * 60; // Extend 60 bars
    
    if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom)) {
        color clr = GetColorByState(state);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        ObjectSetInteger(0, objName, OBJPROP_FILL, false);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
        
        // Add text label
        string labelName = objName + "_Label";
        double labelPrice = (top + bottom) / 2;
        string stateText = (state == 0) ? "Valid" : (state == 1) ? "Mitigated" : "Completed";
        
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, labelPrice)) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "FVG " + (direction == 1 ? "Bull" : "Bear") + " [" + stateText + "]");
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Mark BOS with arrow                                              |
//+------------------------------------------------------------------+
void CDrawDebug::MarkBOS(int barIndex, int direction, double level, string tag) {
    string objName = GenerateObjectName("BOS_" + tag);
    
    datetime time = iTime(_Symbol, PERIOD_CURRENT, barIndex);
    
    int arrowCode = (direction == 1) ? 233 : 234; // Up/Down arrows
    
    if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, level)) {
        ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, GetColorByDirection(direction));
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        
        // Add text label
        string labelName = objName + "_Label";
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time, level)) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "BOS " + (direction == 1 ? "↑" : "↓"));
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, GetColorByDirection(direction));
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Mark liquidity sweep                                             |
//+------------------------------------------------------------------+
void CDrawDebug::MarkSweep(double level, int side, datetime time, string tag) {
    string objName = GenerateObjectName("SWEEP_" + tag);
    
    // Draw horizontal line at sweep level
    datetime endTime = time + PeriodSeconds(PERIOD_CURRENT) * 50;
    
    if(ObjectCreate(0, objName, OBJ_TREND, 0, time, level, endTime, level)) {
        color clr = (side == 1) ? clrYellow : clrOrange; // Buy-side / Sell-side
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASHDOT);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        
        // Add text label
        string labelName = objName + "_Label";
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time, level)) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "SWEEP " + (side == 1 ? "High" : "Low"));
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw text label at position                                      |
//+------------------------------------------------------------------+
void CDrawDebug::DrawLabel(string text, int x, int y, color clr, string tag) {
    string objName = m_prefix + "Label_" + tag;
    
    // Delete if exists
    ObjectDelete(0, objName);
    
    if(ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetString(0, objName, OBJPROP_TEXT, text);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, objName, OBJPROP_FONT, "Courier New");
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    }
}

//+------------------------------------------------------------------+
//| Update dashboard with current state - FULL INFO                 |
//+------------------------------------------------------------------+
void CDrawDebug::UpdateDashboard(string stateText, CRiskManager *riskMgr, CExecutor *executor, 
                                 CDetector *detector, BOSSignal &lastBOS, SweepSignal &lastSweep, 
                                 OrderBlock &lastOB, FVGSignal &lastFVG, double lastScore) {
    // Create white background panel
    string bgName = m_prefix + "Dashboard_BG";
    ObjectDelete(0, bgName);
    
    if(ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, 5);
        ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, 15);
        ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 420);
        ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 550);
        ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrWhite);
        ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
        ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrBlack);
        ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
        ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
    }
    
    // Build dashboard text
    string dashboard = "┌─────────────────────────────────────────────┐\n";
    dashboard += "│ OAT V4 - ICT/SMC + Momentum EA              │\n";
    dashboard += "├─────────────────────────────────────────────┤\n";
    dashboard += "│ STATE: " + stateText;
    // Pad to align
    int padLen = 40 - StringLen(stateText);
    for(int i = 0; i < padLen; i++) dashboard += " ";
    dashboard += "│\n";
    
    // Account Info
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double initBalance = (riskMgr != NULL) ? riskMgr.GetInitialBalance() : balance;
    double maxLot = (riskMgr != NULL) ? riskMgr.GetMaxLotPerSide() : 0;
    
    dashboard += "├─────────────────────────────────────────────┤\n";
    dashboard += StringFormat("│ Balance:    $%10.2f | MaxLot: %.2f   │\n", balance, maxLot);
    dashboard += StringFormat("│ Init Bal:   $%10.2f (Today 6h)       │\n", initBalance);
    dashboard += StringFormat("│ Equity:     $%10.2f                  │\n", equity);
    
    // Floating P/L
    double floatingPL = (riskMgr != NULL) ? riskMgr.GetBasketFloatingPL() : 0;
    double floatingPct = (riskMgr != NULL) ? riskMgr.GetBasketFloatingPLPct() : 0;
    color plColor = (floatingPL >= 0) ? clrGreen : clrRed;
    
    dashboard += StringFormat("│ Floating PL: $%9.2f (%+.2f%%)         │\n", floatingPL, floatingPct);
    
    // Daily P/L
    double dailyPL = (riskMgr != NULL) ? riskMgr.GetDailyPL() : 0;
    dashboard += StringFormat("│ Daily P/L:         %+.2f%%               │\n", dailyPL);
    
    // Session & Time
    dashboard += "├─────────────────────────────────────────────┤\n";
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    bool sessionOpen = (executor != NULL) ? executor.SessionOpen() : false;
    bool spreadOK = (executor != NULL) ? executor.SpreadOK() : false;
    
    dashboard += StringFormat("│ Time (GMT+7): %02d:%02d | Session: %s      │\n", 
                              dt.hour, dt.min, (sessionOpen ? "OPEN " : "CLOSED"));
    dashboard += StringFormat("│ Spread: %s                              │\n", 
                              (spreadOK ? "OK    " : "WIDE  "));
    
    // Trading Status
    bool halted = (riskMgr != NULL) ? riskMgr.IsTradingHalted() : false;
    dashboard += StringFormat("│ Trading: %s                             │\n", 
                              (halted ? "HALTED " : "ACTIVE "));
    
    // Active Structures
    dashboard += "├─────────────────────────────────────────────┤\n";
    dashboard += "│ ACTIVE STRUCTURES:                          │\n";
    
    if(lastBOS.valid) {
        dashboard += StringFormat("│ ├─ BOS %s @ %.2f                      │\n", 
                                  (lastBOS.direction == 1 ? "UP  " : "DOWN"),
                                  lastBOS.breakLevel);
    } else {
        dashboard += "│ ├─ BOS: None                                │\n";
    }
    
    if(lastSweep.detected) {
        dashboard += StringFormat("│ ├─ SWEEP %s @ %.2f                   │\n", 
                                  (lastSweep.side == 1 ? "HIGH" : "LOW "),
                                  lastSweep.level);
    } else {
        dashboard += "│ ├─ SWEEP: None                              │\n";
    }
    
    if(lastOB.valid) {
        dashboard += StringFormat("│ ├─ OB %s: %.2f-%.2f               │\n", 
                                  (lastOB.direction == 1 ? "LONG " : "SHORT"),
                                  lastOB.priceBottom, lastOB.priceTop);
    } else {
        dashboard += "│ ├─ OB: None                                 │\n";
    }
    
    if(lastFVG.valid) {
        string fvgState = (lastFVG.state == 0) ? "ACT" : (lastFVG.state == 1) ? "MIG" : "COM";
        dashboard += StringFormat("│ └─ FVG %s: %.2f-%.2f [%s]         │\n", 
                                  (lastFVG.direction == 1 ? "LONG " : "SHORT"),
                                  lastFVG.priceBottom, lastFVG.priceTop, fvgState);
    } else {
        dashboard += "│ └─ FVG: None                                │\n";
    }
    
    // Signal Score
    dashboard += "├─────────────────────────────────────────────┤\n";
    if(lastScore >= 100.0) {
        dashboard += StringFormat("│ SIGNAL: VALID | Score: %.1f ★         │\n", lastScore);
    } else if(lastScore > 0) {
        dashboard += StringFormat("│ SIGNAL: LOW   | Score: %.1f            │\n", lastScore);
    } else {
        dashboard += "│ SIGNAL: NONE                                │\n";
    }
    
    // Positions
    dashboard += "├─────────────────────────────────────────────┤\n";
    dashboard += "│ POSITIONS:                                  │\n";
    
    int totalPos = PositionsTotal();
    int longPos = 0, shortPos = 0;
    double longLots = 0, shortLots = 0;
    
    for(int i = 0; i < totalPos; i++) {
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
    
    dashboard += StringFormat("│ ├─ LONG:  %d orders | %.2f lots            │\n", longPos, longLots);
    dashboard += StringFormat("│ └─ SHORT: %d orders | %.2f lots            │\n", shortPos, shortLots);
    
    // Risk Limits
    dashboard += "├─────────────────────────────────────────────┤\n";
    dashboard += "│ BASKET LIMITS:                              │\n";
    dashboard += StringFormat("│ ├─ TP: +%.2f%% | Current: %+.2f%%         │\n", 0.3, floatingPct);
    dashboard += StringFormat("│ ├─ SL: -%.2f%% | Daily: %.2f%%           │\n", 1.2, dailyPL);
    dashboard += StringFormat("│ └─ Daily Limit: -%.1f%% | Today: %.2f%%   │\n", 8.0, dailyPL);
    
    dashboard += "└─────────────────────────────────────────────┘";
    
    // Draw dashboard text
    string objName = m_prefix + "Dashboard";
    ObjectDelete(0, objName);
    
    if(ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 15);
        ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 25);
        ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetString(0, objName, OBJPROP_TEXT, dashboard);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clrBlack);  // Black text on white background
        ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 8);
        ObjectSetString(0, objName, OBJPROP_FONT, "Courier New");
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, objName, OBJPROP_BACK, false);  // Foreground
    }
}

