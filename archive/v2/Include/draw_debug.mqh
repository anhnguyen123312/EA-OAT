//+------------------------------------------------------------------+
//|                                                   draw_debug.mqh |
//|                     Dashboard & Chart Visualization               |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

//+------------------------------------------------------------------+
//| Include Common Signal Structures                                 |
//| Analytics Layer chỉ làm nhiệm vụ visualization,                 |
//| giao tiếp với các Layer khác qua data structures                 |
//+------------------------------------------------------------------+
#include "Common\signal_structs.mqh"

//+------------------------------------------------------------------+
//| CDrawDebug Class                                                  |
//+------------------------------------------------------------------+
class CDrawDebug {
private:
    string   m_prefix;
    
public:
    CDrawDebug();
    ~CDrawDebug();
    
    bool Init(string prefix);
    
    // Dashboard
    void UpdateDashboard(string stateText, const RiskManagerData &riskData,
                        string sessionInfo, double score,
                        const BOSSignal &lastBOS, const SweepSignal &lastSweep,
                        const OrderBlock &lastOB, const FVGSignal &lastFVG,
                        const StatsManagerData &statsData);
    
    // Chart markers
    void MarkBOS(int barIndex, int direction, double level, string tag);
    void MarkSweep(double level, int side, datetime time, string tag);
    void DrawOB(double top, double bottom, int direction, datetime startTime, string tag);
    void DrawFVG(double top, double bottom, int direction, int state, datetime startTime, string tag);
    
    // Cleanup
    void CleanupOldObjects();
    
private:
    void CreateLabel(string name, int x, int y, string text, color clr, string font, int size);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDrawDebug::CDrawDebug() {
    m_prefix = "SMC";
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CDrawDebug::~CDrawDebug() {
}

//+------------------------------------------------------------------+
//| Initialize drawer                                                 |
//+------------------------------------------------------------------+
bool CDrawDebug::Init(string prefix) {
    m_prefix = prefix;
    Print("✅ CDrawDebug initialized | Prefix: ", m_prefix);
    return true;
}

//+------------------------------------------------------------------+
//| Update dashboard                                                  |
//+------------------------------------------------------------------+
void CDrawDebug::UpdateDashboard(string stateText, const RiskManagerData &riskData,
                                string sessionInfo, double score,
                                const BOSSignal &lastBOS, const SweepSignal &lastSweep,
                                const OrderBlock &lastOB, const FVGSignal &lastFVG,
                                const StatsManagerData &statsData) {
    
    // Build dashboard text (NO BACKGROUND - transparent)
    string dashboard = "";
    dashboard += "══════════════════════════════════\n";
    dashboard += "  SMC/ICT EA v2.1\n";
    dashboard += "══════════════════════════════════\n";
    
    // State
    dashboard += "STATE: " + stateText + "\n";
    
    // Debug: Log text building (first time only)
    static bool loggedBuild = false;
    if(!loggedBuild) {
        Print("📝 Building dashboard text... State: ", stateText);
        loggedBuild = true;
    }
    
    // Account info
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double maxLot = riskData.maxLotPerSide;
    
    dashboard += "──────────────────────────────────\n";
    dashboard += StringFormat("Balance: $%.2f | MaxLot: %.2f\n", balance, maxLot);
    dashboard += StringFormat("Equity:  $%.2f\n", equity);
    
    // Floating P/L
    double floatingPL = riskData.basketFloatingPL;
    double floatingPct = riskData.basketFloatingPLPct;
    dashboard += StringFormat("Floating: $%.2f (%+.2f%%)\n", floatingPL, floatingPct);
    
    // Session info
    dashboard += "──────────────────────────────────\n";
    dashboard += "Session: " + sessionInfo + "\n";
    
    // Active structures (simplified)
    dashboard += "──────────────────────────────────\n";
    dashboard += "SIGNALS:\n";
    
    if(lastBOS.valid) {
        dashboard += StringFormat("BOS %s @ %.2f", 
                                 (lastBOS.direction == 1 ? "UP" : "DN"), 
                                 lastBOS.breakLevel);
        if(lastBOS.hasRetest) dashboard += StringFormat(" [%dR]", lastBOS.retestCount);
        dashboard += "\n";
    } else {
        dashboard += "BOS: None\n";
    }
    
    if(lastSweep.detected) {
        dashboard += StringFormat("Sweep %s @ %.2f\n",
                                 (lastSweep.side == 1 ? "HIGH" : "LOW"),
                                 lastSweep.level);
    } else {
        dashboard += "Sweep: None\n";
    }
    
    if(lastOB.valid) {
        dashboard += StringFormat("OB %s: %.2f-%.2f",
                                 (lastOB.direction == 1 ? "LONG" : "SHORT"),
                                 lastOB.priceBottom, lastOB.priceTop);
        if(lastOB.hasSweepNearby) dashboard += " [SW]";
        dashboard += "\n";
    } else {
        dashboard += "OB: None\n";
    }
    
    if(lastFVG.valid) {
        string stateStr = (lastFVG.state == 0) ? "ACT" : ((lastFVG.state == 1) ? "MIT" : "CPL");
        dashboard += StringFormat("FVG %s: %.2f-%.2f [%s]",
                                 (lastFVG.direction == 1 ? "LONG" : "SHORT"),
                                 lastFVG.priceBottom, lastFVG.priceTop, stateStr);
        if(lastFVG.mtfOverlap) dashboard += " [MTF]";
        dashboard += "\n";
    } else {
        dashboard += "FVG: None\n";
    }
    
    // Signal score
    dashboard += "──────────────────────────────────\n";
    if(score >= 100.0) {
        dashboard += StringFormat("SIGNAL: VALID | Score: %.1f", score);
        if(score >= 200) dashboard += " ***";
        else if(score >= 150) dashboard += " **";
        else dashboard += " *";
        dashboard += "\n";
    } else {
        dashboard += "SIGNAL: None\n";
    }
    
    // Positions
    dashboard += "──────────────────────────────────\n";
    dashboard += "POSITIONS:\n";
    
    int longPos = 0, shortPos = 0;
    double longLots = 0, shortLots = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
                long type = PositionGetInteger(POSITION_TYPE);
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
    }
    
    dashboard += StringFormat("LONG:  %d (%.2f lots)\n", longPos, longLots);
    dashboard += StringFormat("SHORT: %d (%.2f lots)\n", shortPos, shortLots);
    
    // Performance stats
    PatternStats overall = statsData.overall;
    
    dashboard += "──────────────────────────────────\n";
    dashboard += "STATS:\n";
    dashboard += StringFormat("Total: %d | Win: %d | Loss: %d\n",
                             overall.totalTrades, overall.wins, overall.losses);
    dashboard += StringFormat("Win Rate: %.1f%% | PF: %.2f\n",
                             overall.winRate, overall.profitFactor);
    dashboard += StringFormat("Profit: $%.2f\n", overall.totalProfit);
    
    // Top patterns only (if have trades)
    if(overall.totalTrades > 0) {
        dashboard += "──────────────────────────────────\n";
        dashboard += "TOP PATTERNS:\n";
        
        PatternStats conf = statsData.patterns[5];
        if(conf.totalTrades > 0) {
            dashboard += StringFormat("Confluence: %d (%dW/%dL) %.1f%%\n",
                                     conf.totalTrades, conf.wins, conf.losses, conf.winRate);
        }
        
        PatternStats bosOB = statsData.patterns[0];
        if(bosOB.totalTrades > 0) {
            dashboard += StringFormat("BOS+OB: %d (%dW/%dL) %.1f%%\n",
                                         bosOB.totalTrades, bosOB.wins, bosOB.losses, bosOB.winRate);
            }
        }
    }
    
    dashboard += "══════════════════════════════════";
    
    // Check if in tester mode
    bool isTester = MQLInfoInteger(MQL_TESTER);
    
    // METHOD 1: Use Comment() - Always visible, top-left corner
    Comment(dashboard);
    
    // METHOD 2: Also create object for live mode (better positioning)
    if(!isTester) {
        string objName = m_prefix + "_Dashboard";
        
        // Delete and recreate
        ObjectDelete(0, objName);
        
        if(ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0)) {
            ObjectSetInteger(0, objName, OBJPROP_CORNER, 0);
            ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 15);
            ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 20);
            ObjectSetString(0, objName, OBJPROP_TEXT, dashboard);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
            ObjectSetString(0, objName, OBJPROP_FONT, "Courier New");
            ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
            
            static bool loggedOnce = false;
            if(!loggedOnce) {
                Print("✅ Dashboard object created (LIVE mode)");
                loggedOnce = true;
            }
        }
    } else {
        // In tester, Comment() is used
        static bool loggedTester = false;
        if(!loggedTester) {
            Print("✅ Dashboard using Comment() for BACKTEST mode");
            loggedTester = true;
        }
    }
    
    // Debug log
    static datetime lastDashLog = 0;
    int logInterval = isTester ? 300 : 30;
    
    if(TimeCurrent() - lastDashLog >= logInterval) {
        Print("📊 Dashboard: ", stateText, " | Score: ", DoubleToString(score, 1));
        lastDashLog = TimeCurrent();
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create label                                                      |
//+------------------------------------------------------------------+
void CDrawDebug::CreateLabel(string name, int x, int y, string text, color clr, string font, int size) {
    string objName = m_prefix + "_" + name;
    
    if(ObjectFind(0, objName) < 0) {
        ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    }
    
    ObjectSetInteger(0, objName, OBJPROP_CORNER, 0); // CORNER_LEFT_UPPER
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetString(0, objName, OBJPROP_FONT, font);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, size);
}

//+------------------------------------------------------------------+
//| Mark BOS on chart                                                |
//+------------------------------------------------------------------+
void CDrawDebug::MarkBOS(int barIndex, int direction, double level, string tag) {
    string objName = m_prefix + "_BOS_" + tag;
    datetime time = iTime(_Symbol, PERIOD_CURRENT, barIndex);
    
    int arrowCode = (direction == 1) ? 233 : 234;
    
    if(ObjectCreate(0, objName, OBJ_ARROW, 0, time, level)) {
        ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, objName, OBJPROP_COLOR, 
                        direction == 1 ? clrDodgerBlue : clrOrangeRed);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    }
}

//+------------------------------------------------------------------+
//| Mark Sweep on chart                                              |
//+------------------------------------------------------------------+
void CDrawDebug::MarkSweep(double level, int side, datetime time, string tag) {
    string objName = m_prefix + "_SWEEP_" + tag;
    datetime endTime = time + PeriodSeconds(PERIOD_CURRENT) * 50;
    
    if(ObjectCreate(0, objName, OBJ_TREND, 0, time, level, endTime, level)) {
        color clr = (side == 1) ? clrYellow : clrOrange;
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASHDOT);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
    }
}

//+------------------------------------------------------------------+
//| Draw Order Block rectangle                                       |
//+------------------------------------------------------------------+
void CDrawDebug::DrawOB(double top, double bottom, int direction, datetime startTime, string tag) {
    string objName = m_prefix + "_OB_" + tag;
    datetime endTime = startTime + PeriodSeconds(PERIOD_CURRENT) * 120;
    
    if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom)) {
        color clr = (direction == 1) ? clrDodgerBlue : clrOrangeRed;
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        ObjectSetInteger(0, objName, OBJPROP_FILL, true);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    }
}

//+------------------------------------------------------------------+
//| Draw FVG rectangle                                               |
//+------------------------------------------------------------------+
void CDrawDebug::DrawFVG(double top, double bottom, int direction, int state, 
                        datetime startTime, string tag) {
    string objName = m_prefix + "_FVG_" + tag;
    datetime endTime = startTime + PeriodSeconds(PERIOD_CURRENT) * 60;
    
    color clr;
    if(state == 0) clr = clrLimeGreen;       // Valid
    else if(state == 1) clr = clrYellow;     // Mitigated
    else clr = clrGray;                      // Completed
    
    if(ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, top, endTime, bottom)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        ObjectSetInteger(0, objName, OBJPROP_FILL, false);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    }
}

//+------------------------------------------------------------------+
//| Cleanup old objects                                              |
//+------------------------------------------------------------------+
void CDrawDebug::CleanupOldObjects() {
    datetime oldTime = TimeCurrent() - 86400; // 24 hours ago
    
    for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string objName = ObjectName(0, i, 0, -1);
        
        if(StringFind(objName, m_prefix) == 0) {
            datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
            if(objTime < oldTime && objTime > 0) {
                ObjectDelete(0, objName);
            }
        }
    }
}

