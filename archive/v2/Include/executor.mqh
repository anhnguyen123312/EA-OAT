//+------------------------------------------------------------------+
//|                                                     executor.mqh |
//|                   Execution Layer - Session, Trigger, Entry      |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

//+------------------------------------------------------------------+
//| Include Common Signal Structures                                 |
//| Execution Layer chỉ làm nhiệm vụ execute,                       |
//| giao tiếp với Arbitration Layer qua Candidate structure          |
//+------------------------------------------------------------------+
#include "Common\signal_structs.mqh"
// Note: risk_gate.mqh forward declared - no include to avoid circular dependency

//+------------------------------------------------------------------+
//| Session Mode Enumerations                                        |
//+------------------------------------------------------------------+
enum TRADING_SESSION_MODE {
    SESSION_FULL_DAY = 0,      // Continuous trading
    SESSION_MULTI_WINDOW = 1   // Multiple windows with breaks
};

//+------------------------------------------------------------------+
//| Trading Window Structure                                         |
//+------------------------------------------------------------------+
struct TradingWindow {
    bool   enabled;      // Window enabled?
    int    startHour;    // Start hour (GMT+7)
    int    endHour;      // End hour (GMT+7)
    string name;         // Window name
};

//+------------------------------------------------------------------+
//| Pending Order Tracking                                           |
//+------------------------------------------------------------------+
struct PendingOrderInfo {
    ulong    ticket;
    datetime placedTime;
    int      barsAge;
    int      ttl;
};

//+------------------------------------------------------------------+
//| CExecutor Class                                                   |
//+------------------------------------------------------------------+
class CExecutor {
private:
    string   m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    int      m_atrHandle;
    
    // Session parameters
    TRADING_SESSION_MODE m_sessionMode;
    int      m_sessStartHour;   // Full day start
    int      m_sessEndHour;     // Full day end
    TradingWindow m_windows[3]; // Multi-window mode
    
    // Market filters
    int      m_spreadMaxPts;
    double   m_spreadATRpct;
    
    // Execution parameters
    double   m_triggerBodyATR;
    int      m_entryBufferPts;
    int      m_minStopPts;
    int      m_orderTTL_Bars;
    double   m_minRR;
    
    // Fixed SL/TP mode
    bool     m_useFixedSL;
    int      m_fixedSL_Pips;
    bool     m_fixedTP_Enable;
    int      m_fixedTP_Pips;
    
    // Pending orders tracking
    PendingOrderInfo m_pendingOrders[];
    
    // ═══════════════════════════════════════════════════════════
    // NEW: Position Plan Tracking (v2.1 Refactor)
    // ═══════════════════════════════════════════════════════════
    PositionPlan m_positionPlans[];  // Map ticket → PositionPlan
    ulong        m_ticketMap[];      // Ticket array (parallel to m_positionPlans)
    int          m_dcaAdded[];       // Track DCA levels added (bit flags: bit0=level1, bit1=level2, bit2=level3)
    bool         m_beMoved[];        // Track BE moved
    double       m_lastTrailR[];     // Track last trail R
    
public:
    CExecutor();
    ~CExecutor();
    
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              int fullDayStart, int fullDayEnd,
              TRADING_SESSION_MODE sessionMode,
              bool w1Enable, int w1Start, int w1End,
              bool w2Enable, int w2Start, int w2End,
              bool w3Enable, int w3Start, int w3End,
              int spreadMax, double spreadATRpct,
              double triggerBody, int entryBuffer, int minStop, int orderTTL, double minRR,
              bool useFixedSL, int fixedSL_Pips, bool fixedTP_Enable, int fixedTP_Pips);
    
    // Session management
    bool SessionOpen();
    bool SpreadOK();
    bool IsRolloverTime();
    string GetActiveWindow();
    
    // Trigger & Entry
    bool GetTriggerCandle(int direction, double &triggerHigh, double &triggerLow);
    bool CalculateEntry(const Candidate &c, double triggerHigh, double triggerLow,
                       double &entry, double &sl, double &tp, double &rr);
    
    // Order placement
    bool PlaceStopOrder(int direction, double entry, double sl, double tp, 
                       double lots, string comment);
    bool PlaceLimitOrder(int direction, const Candidate &c, double sl, double tp,
                        double lots, string comment);
    
    // Order management
    void ManagePendingOrders();
    void SetOrderTTL(ulong ticket, int ttl);
    
    // Helper
    double GetATR();
    double FindTPTarget(const Candidate &c, double entry);
    
    // ═══════════════════════════════════════════════════════════
    // NEW: Execution Order Support (v2.1 Refactor)
    // ═══════════════════════════════════════════════════════════
    bool PlaceOrder(const ExecutionOrder &order);
    void SavePositionPlan(ulong ticket, const PositionPlan &plan);
    PositionPlan GetPositionPlan(ulong ticket);
    void ManagePositions();  // Execute PositionPlans
    void ExecutePositionPlan(ulong ticket, const PositionPlan &plan);
    void ExecuteDCAPlan(ulong ticket, const DCAPlan &plan);
    void ExecuteBEPlan(ulong ticket, const BEPlan &plan);
    void ExecuteTrailPlan(ulong ticket, const TrailPlan &plan);
    
    // Helpers for position plan execution
    double CalcProfitInR(ulong ticket);
    bool IsDCAAdded(ulong ticket, int level);
    void MarkDCAAdded(ulong ticket, int level);
    bool IsBEMoved(ulong ticket);
    void MarkBEMoved(ulong ticket);
    double GetLastTrailR(ulong ticket);
    void SetLastTrailR(ulong ticket, double r);
    double GetOriginalLot(ulong ticket);
    int GetPositionDirection(ulong ticket);
    
private:
    int GetLocalHour();
    bool ValidateWindows();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CExecutor::CExecutor() {
    m_atrHandle = INVALID_HANDLE;
    ArrayResize(m_pendingOrders, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CExecutor::~CExecutor() {
    if(m_atrHandle != INVALID_HANDLE) {
        IndicatorRelease(m_atrHandle);
    }
}

//+------------------------------------------------------------------+
//| Initialize executor                                               |
//+------------------------------------------------------------------+
bool CExecutor::Init(string symbol, ENUM_TIMEFRAMES tf,
                     int fullDayStart, int fullDayEnd,
                     TRADING_SESSION_MODE sessionMode,
                     bool w1Enable, int w1Start, int w1End,
                     bool w2Enable, int w2Start, int w2End,
                     bool w3Enable, int w3Start, int w3End,
                     int spreadMax, double spreadATRpct,
                     double triggerBody, int entryBuffer, int minStop, int orderTTL, double minRR,
                     bool useFixedSL, int fixedSL_Pips, bool fixedTP_Enable, int fixedTP_Pips) {
    
    m_symbol = symbol;
    m_timeframe = tf;
    
    // Session configuration
    m_sessionMode = sessionMode;
    m_sessStartHour = fullDayStart;
    m_sessEndHour = fullDayEnd;
    
    // Multi-window settings
    m_windows[0].enabled = w1Enable;
    m_windows[0].startHour = w1Start;
    m_windows[0].endHour = w1End;
    m_windows[0].name = "Asia";
    
    m_windows[1].enabled = w2Enable;
    m_windows[1].startHour = w2Start;
    m_windows[1].endHour = w2End;
    m_windows[1].name = "London";
    
    m_windows[2].enabled = w3Enable;
    m_windows[2].startHour = w3Start;
    m_windows[2].endHour = w3End;
    m_windows[2].name = "NY";
    
    // Validate configuration
    if(!ValidateWindows()) {
        Print("❌ Invalid window configuration");
        return false;
    }
    
    // Market filters
    m_spreadMaxPts = spreadMax;
    m_spreadATRpct = spreadATRpct;
    
    // Execution parameters
    m_triggerBodyATR = triggerBody / 100.0; // Convert to decimal
    m_entryBufferPts = entryBuffer;
    m_minStopPts = minStop;
    m_orderTTL_Bars = orderTTL;
    m_minRR = minRR;
    
    // Fixed SL/TP
    m_useFixedSL = useFixedSL;
    m_fixedSL_Pips = fixedSL_Pips;
    m_fixedTP_Enable = fixedTP_Enable;
    m_fixedTP_Pips = fixedTP_Pips;
    
    // Create ATR handle
    m_atrHandle = iATR(m_symbol, m_timeframe, 14);
    if(m_atrHandle == INVALID_HANDLE) {
        Print("❌ CExecutor: Failed to create ATR handle");
        return false;
    }
    
    // Log configuration
    Print("═══════════════════════════════════════");
    Print("📅 SESSION CONFIGURATION:");
    Print("   Mode: ", m_sessionMode == SESSION_FULL_DAY ? "FULL DAY" : "MULTI-WINDOW");
    
    if(m_sessionMode == SESSION_FULL_DAY) {
        Print("   Hours: ", m_sessStartHour, ":00 - ", m_sessEndHour, ":00 GMT+7");
        Print("   Duration: ", m_sessEndHour - m_sessStartHour, " hours");
    } else {
        Print("   Windows:");
        for(int i = 0; i < 3; i++) {
            Print("   - ", m_windows[i].name, ": ", 
                  m_windows[i].enabled ? "✅ ON" : "⊘ OFF",
                  " (", m_windows[i].startHour, ":00-", m_windows[i].endHour, ":00)");
        }
    }
    Print("═══════════════════════════════════════");
    
    Print("✅ CExecutor initialized");
    return true;
}

//+------------------------------------------------------------------+
//| Validate window configuration                                    |
//+------------------------------------------------------------------+
bool CExecutor::ValidateWindows() {
    if(m_sessionMode == SESSION_FULL_DAY) {
        if(m_sessStartHour < 0 || m_sessStartHour > 23 ||
           m_sessEndHour < 0 || m_sessEndHour > 24 ||
           m_sessStartHour >= m_sessEndHour) {
            return false;
        }
        return true;
    }
    
    // Multi-window validation
    bool hasEnabledWindow = false;
    for(int i = 0; i < 3; i++) {
        if(m_windows[i].enabled) {
            hasEnabledWindow = true;
            
            if(m_windows[i].startHour < 0 || m_windows[i].startHour > 23 ||
               m_windows[i].endHour < 0 || m_windows[i].endHour > 24 ||
               m_windows[i].startHour >= m_windows[i].endHour) {
                return false;
            }
        }
    }
    
    if(!hasEnabledWindow) {
        Print("⚠️ WARNING: No windows enabled in MULTI-WINDOW mode!");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get local hour (GMT+7)                                           |
//+------------------------------------------------------------------+
int CExecutor::GetLocalHour() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s);
    
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    return hour_localvn;
}

//+------------------------------------------------------------------+
//| Check if session is open                                         |
//+------------------------------------------------------------------+
bool CExecutor::SessionOpen() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s);
    
    // Calculate VN time (GMT+7)
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    bool inSession = false;
    string sessionName = "CLOSED";
    
    if(m_sessionMode == SESSION_FULL_DAY) {
        inSession = (hour_localvn >= m_sessStartHour && hour_localvn < m_sessEndHour);
        if(inSession) sessionName = "FULL DAY";
    }
    else if(m_sessionMode == SESSION_MULTI_WINDOW) {
        for(int i = 0; i < 3; i++) {
            if(!m_windows[i].enabled) continue;
            
            if(hour_localvn >= m_windows[i].startHour &&
               hour_localvn < m_windows[i].endHour) {
                inSession = true;
                sessionName = m_windows[i].name;
                break;
            }
        }
    }
    
    // Log once per hour
    static int lastLogHour = -1;
    if(s.hour != lastLogHour) {
        Print("🕐 Session Check | Server: ", s.hour, ":00",
              " | VN Time: ", hour_localvn, ":00",
              " | Mode: ", m_sessionMode == SESSION_FULL_DAY ? "FULL DAY" : "MULTI-WINDOW",
              " | Session: ", sessionName,
              " | Status: ", inSession ? "IN ✅" : "OUT ❌");
        lastLogHour = s.hour;
    }
    
    return inSession;
}

//+------------------------------------------------------------------+
//| Get active window name                                           |
//+------------------------------------------------------------------+
string CExecutor::GetActiveWindow() {
    if(m_sessionMode == SESSION_FULL_DAY) {
        return "Full Day";
    }
    
    int hour_localvn = GetLocalHour();
    
    for(int i = 0; i < 3; i++) {
        if(!m_windows[i].enabled) continue;
        
        if(hour_localvn >= m_windows[i].startHour &&
           hour_localvn < m_windows[i].endHour) {
            return m_windows[i].name;
        }
    }
    
    return "Break/Closed";
}

//+------------------------------------------------------------------+
//| Check spread                                                      |
//+------------------------------------------------------------------+
bool CExecutor::SpreadOK() {
    long spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
    double atr = GetATR();
    
    // Dynamic spread filter
    if(atr > 0) {
        long dynamicMax = (long)MathMax(m_spreadMaxPts, 
                                        m_spreadATRpct * atr / _Point);
        
        if(spread > dynamicMax) {
            return false;
        }
        return true;
    }
    
    // Fallback to static
    if(spread > m_spreadMaxPts) {
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Check if rollover time                                           |
//+------------------------------------------------------------------+
bool CExecutor::IsRolloverTime() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s);
    
    int minutesFromMidnight = s.hour * 60 + s.min;
    
    // Within 5 min of midnight
    if(minutesFromMidnight < 5 || minutesFromMidnight > 1435) {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get trigger candle                                               |
//+------------------------------------------------------------------+
bool CExecutor::GetTriggerCandle(int direction, double &triggerHigh, double &triggerLow) {
    double atr = GetATR();
    if(atr <= 0) return false;
    
    double minBodySize = MathMax(m_triggerBodyATR * atr, 30.0 * _Point);
    
    // Scan bars 0-3
    for(int i = 0; i <= 3; i++) {
        double open = iOpen(m_symbol, m_timeframe, i);
        double close = iClose(m_symbol, m_timeframe, i);
        double high = iHigh(m_symbol, m_timeframe, i);
        double low = iLow(m_symbol, m_timeframe, i);
        double bodySize = MathAbs(close - open);
        
        if(bodySize >= minBodySize) {
            if(direction == -1 && close < open) {
                // Bearish trigger for SELL
                triggerHigh = high;
                triggerLow = low;
                return true;
            }
            else if(direction == 1 && close > open) {
                // Bullish trigger for BUY
                triggerHigh = high;
                triggerLow = low;
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Entry, SL, TP                                          |
//+------------------------------------------------------------------+
bool CExecutor::CalculateEntry(const Candidate &c, double triggerHigh, double triggerLow,
                               double &entry, double &sl, double &tp, double &rr) {
    if(!c.valid) return false;
    
    double buffer = m_entryBufferPts * _Point;
    double atr = GetATR();
    
    if(c.direction == 1) {
        // BUY SETUP
        entry = triggerHigh + buffer;
        
        // ═══════════════════════════════════════════════════════════
        // SL CALCULATION (ICT Research Algorithm)
        // ═══════════════════════════════════════════════════════════
        
        // Step 1: Structure-based SL (OB low, Swing low, Sweep level)
        double structureSL = 0;
        if(c.hasSweep) {
            structureSL = c.sweepLevel - buffer;
        } else if(c.hasOB) {
            structureSL = c.poiBottom - buffer;
        } else if(c.hasFVG) {
            structureSL = c.fvgBottom - buffer;
        }
        
        // ⭐ CRITICAL FIX (per fix-sl.md): Enforce minimum structure distance
        double minStructureDist = (m_minStopPts / 2.0) * _Point;  // 50 pips (half of MinStop)
        if(structureSL > 0 && MathAbs(entry - structureSL) < minStructureDist) {
            Print("⚠️ Structure SL too close to entry!");
            Print("   Entry:    ", entry);
            Print("   Struct SL:", structureSL);
            Print("   Distance: ", (int)(MathAbs(entry - structureSL) / _Point), " pts (", 
                  DoubleToString((entry - structureSL) / _Point / 10, 1), " pips)");
            Print("   Minimum:  ", (int)(minStructureDist / _Point), " pts (", 
                  (int)(minStructureDist / _Point / 10), " pips)");
            Print("   → Structure SL DISABLED, will use ATR-based instead");
            
            // Force use ATR-based SL instead
            structureSL = 0;  // Disable structure SL
        }
        
        // Step 2: ATR-based SL (2.0× ATR per research)
        double atrSL = entry - (2.0 * atr);
        
        // Step 3: Preliminary SL = MIN(structure, ATR)
        double preliminarySL = (structureSL > 0) ? MathMin(structureSL, atrSL) : atrSL;
        
        // Step 4: ATR Cap (3.5× ATR max per research)
        double maxCapSL = entry - (3.5 * atr);
        
        // Step 5: Apply cap (SL không được xa hơn cap)
        double methodSL = MathMax(preliminarySL, maxCapSL);
        
        // Step 6: Ensure minimum stop distance
        double slDistance = entry - methodSL;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            methodSL = entry - minStopDistance;
            Print("⚠️ SL adjusted to MinStop: ", m_minStopPts, " points (", 
                  m_minStopPts/10, " pips)");
        }
        
        // ═══════════════════════════════════════════════════════════
        // DETAILED SL DEBUG LOG (per fix-sl.md)
        // ═══════════════════════════════════════════════════════════
        Print("═══════════════════════════════════");
        Print("SL CALCULATION DEBUG (BUY):");
        Print("═══════════════════════════════════");
        Print("Entry:       ", entry);
        if(c.hasSweep) Print("Sweep Level: ", c.sweepLevel);
        if(c.hasOB) Print("OB Bottom:   ", c.poiBottom);
        if(c.hasFVG) Print("FVG Bottom:  ", c.fvgBottom);
        Print("Buffer:      ", (int)(buffer / _Point), " pts");
        Print("──────────────────────────────────");
        Print("Structure SL:", structureSL, " (", structureSL > 0 ? (int)((entry-structureSL)/_Point) : 0, " pts)");
        Print("ATR SL:      ", atrSL, " (", (int)((entry-atrSL)/_Point), " pts)");
        Print("Preliminary: ", preliminarySL);
        Print("After Cap:   ", methodSL);
        Print("──────────────────────────────────");
        Print("MinStop Check:");
        Print("  slDistance: ", (int)((entry - methodSL) / _Point), " pts");
        Print("  minStopDistance: ", m_minStopPts, " pts");
        Print("  Pass? ", (entry - methodSL) >= minStopDistance ? "YES" : "NO");
        if((entry - methodSL) < minStopDistance) {
            Print("  → ADJUSTED to MinStop");
        }
        Print("──────────────────────────────────");
        
        // Step 7: Apply FIXED SL if enabled (WITH VALIDATION - FIX bug-fix-sl.md)
        if(m_useFixedSL) {
            double fixedSL_Distance = m_fixedSL_Pips * 10 * _Point;
            
            // ✅ CRITICAL FIX: Validate Fixed SL >= MinStop
            if(fixedSL_Distance < minStopDistance) {
                Print("❌ CRITICAL: Fixed SL too small!");
                Print("   Fixed SL: ", (int)(fixedSL_Distance/_Point), " pts (", 
                      m_fixedSL_Pips, " pips)");
                Print("   MinStop:  ", m_minStopPts, " pts (", m_minStopPts/10, " pips)");
                Print("   → Using MinStop instead");
                sl = entry - minStopDistance;  // ✅ Use MinStop
            } else {
                sl = entry - fixedSL_Distance;  // ✅ Use Fixed SL
            }
            
            Print("📌 FIXED SL: ", m_fixedSL_Pips, " pips = ", 
                  (int)((entry-sl)/_Point), " points");
        } else {
            sl = methodSL;
            Print("🎯 METHOD SL: ", (int)((entry-sl)/_Point), " points = ",
                  (int)((entry-sl)/_Point/10), " pips");
        }
        
        Print("──────────────────────────────────");
        Print("Final SL: ", sl);
        Print("SL Distance: ", (int)((entry-sl)/_Point), " pts = ", (int)((entry-sl)/_Point/10), " pips");
        Print("═══════════════════════════════════");
        
        // Calculate DYNAMIC TP from structure
        double structureTP = FindTPTarget(c, entry);
        
        // Apply FIXED TP if enabled (override structure)
        if(m_fixedTP_Enable) {
            double fixedTP_Distance = m_fixedTP_Pips * 10 * _Point;
            tp = entry + fixedTP_Distance;
            Print("📌 FIXED TP: ", m_fixedTP_Pips, " pips = ",
                  (int)((tp-entry)/_Point), " points");
        } else {
            // Use structure TP
            if(structureTP > entry) {
                tp = structureTP;
                Print("🎯 STRUCTURE TP: ", (int)((tp-entry)/_Point), " points = ",
                      (int)((tp-entry)/_Point/10), " pips (from scoring)");
            } else {
                // Fallback: MinRR-based TP using ACTUAL risk
                double actualRisk = entry - sl;
                tp = entry + (actualRisk * m_minRR);
                Print("⚠️ FALLBACK TP: ", (int)((tp-entry)/_Point), " points = ",
                      (int)((tp-entry)/_Point/10), " pips (", m_minRR, "×risk)");
            }
        }
    }
    else if(c.direction == -1) {
        // SELL SETUP
        entry = triggerLow - buffer;
        
        // ═══════════════════════════════════════════════════════════
        // SL CALCULATION (ICT Research Algorithm)
        // ═══════════════════════════════════════════════════════════
        
        // Step 1: Structure-based SL (OB high, Swing high, Sweep level)
        double structureSL = 0;
        if(c.hasSweep) {
            structureSL = c.sweepLevel + buffer;
        } else if(c.hasOB) {
            structureSL = c.poiTop + buffer;
        } else if(c.hasFVG) {
            structureSL = c.fvgTop + buffer;
        }
        
        // ⭐ CRITICAL FIX (per fix-sl.md): Enforce minimum structure distance
        double minStructureDist = (m_minStopPts / 2.0) * _Point;  // 50 pips (half of MinStop)
        if(structureSL > 0 && MathAbs(structureSL - entry) < minStructureDist) {
            Print("⚠️ Structure SL too close to entry!");
            Print("   Entry:    ", entry);
            Print("   Struct SL:", structureSL);
            Print("   Distance: ", (int)(MathAbs(structureSL - entry) / _Point), " pts (", 
                  DoubleToString((structureSL - entry) / _Point / 10, 1), " pips)");
            Print("   Minimum:  ", (int)(minStructureDist / _Point), " pts (", 
                  (int)(minStructureDist / _Point / 10), " pips)");
            Print("   → Structure SL DISABLED, will use ATR-based instead");
            
            // Force use ATR-based SL instead
            structureSL = 0;  // Disable structure SL
        }
        
        // Step 2: ATR-based SL (2.0× ATR per research)
        double atrSL = entry + (2.0 * atr);
        
        // Step 3: Preliminary SL = MAX(structure, ATR) for SELL
        double preliminarySL = (structureSL > 0) ? MathMax(structureSL, atrSL) : atrSL;
        
        // Step 4: ATR Cap (3.5× ATR max per research)
        double maxCapSL = entry + (3.5 * atr);
        
        // Step 5: Apply cap (SL không được xa hơn cap)
        double methodSL = MathMin(preliminarySL, maxCapSL);
        
        // Step 6: Ensure minimum stop distance
        double slDistance = methodSL - entry;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            methodSL = entry + minStopDistance;
            Print("⚠️ SL adjusted to MinStop: ", m_minStopPts, " points (", 
                  m_minStopPts/10, " pips)");
        }
        
        // ═══════════════════════════════════════════════════════════
        // DETAILED SL DEBUG LOG (per fix-sl.md)
        // ═══════════════════════════════════════════════════════════
        Print("═══════════════════════════════════");
        Print("SL CALCULATION DEBUG (SELL):");
        Print("═══════════════════════════════════");
        Print("Entry:       ", entry);
        if(c.hasSweep) Print("Sweep Level: ", c.sweepLevel);
        if(c.hasOB) Print("OB Top:      ", c.poiTop);
        if(c.hasFVG) Print("FVG Top:     ", c.fvgTop);
        Print("Buffer:      ", (int)(buffer / _Point), " pts");
        Print("──────────────────────────────────");
        Print("Structure SL:", structureSL, " (", structureSL > 0 ? (int)((structureSL-entry)/_Point) : 0, " pts)");
        Print("ATR SL:      ", atrSL, " (", (int)((atrSL-entry)/_Point), " pts)");
        Print("Preliminary: ", preliminarySL);
        Print("After Cap:   ", methodSL);
        Print("──────────────────────────────────");
        Print("MinStop Check:");
        Print("  slDistance: ", (int)((methodSL - entry) / _Point), " pts");
        Print("  minStopDistance: ", m_minStopPts, " pts");
        Print("  Pass? ", (methodSL - entry) >= minStopDistance ? "YES" : "NO");
        if((methodSL - entry) < minStopDistance) {
            Print("  → ADJUSTED to MinStop: ", entry + minStopDistance);
        }
        Print("──────────────────────────────────");
        
        // Step 7: Apply FIXED SL if enabled (WITH VALIDATION - FIX bug-fix-sl.md)
        if(m_useFixedSL) {
            double fixedSL_Distance = m_fixedSL_Pips * 10 * _Point;
            
            // ✅ CRITICAL FIX: Validate Fixed SL >= MinStop
            if(fixedSL_Distance < minStopDistance) {
                Print("❌ CRITICAL: Fixed SL too small!");
                Print("   Fixed SL: ", (int)(fixedSL_Distance/_Point), " pts (", 
                      m_fixedSL_Pips, " pips)");
                Print("   MinStop:  ", m_minStopPts, " pts (", m_minStopPts/10, " pips)");
                Print("   → Using MinStop instead");
                sl = entry + minStopDistance;  // ✅ Use MinStop
            } else {
                sl = entry + fixedSL_Distance;  // ✅ Use Fixed SL
            }
            
            Print("📌 FIXED SL: ", m_fixedSL_Pips, " pips = ", 
                  (int)((sl-entry)/_Point), " points");
        } else {
            sl = methodSL;
            Print("🎯 METHOD SL: ", (int)((sl-entry)/_Point), " points = ",
                  (int)((sl-entry)/_Point/10), " pips");
        }
        
        Print("──────────────────────────────────");
        Print("Final SL: ", sl);
        Print("SL Distance: ", (int)((sl-entry)/_Point), " pts = ", (int)((sl-entry)/_Point/10), " pips");
        Print("═══════════════════════════════════");
        
        // Calculate DYNAMIC TP from structure
        double structureTP = FindTPTarget(c, entry);
        
        // Apply FIXED TP if enabled (override structure)
        if(m_fixedTP_Enable) {
            double fixedTP_Distance = m_fixedTP_Pips * 10 * _Point;
            tp = entry - fixedTP_Distance;
        } else {
            // Use structure TP
            if(structureTP < entry) {
                tp = structureTP;
            } else {
                // Fallback: MinRR-based TP using ACTUAL risk
                double actualRisk = sl - entry;
                tp = entry - (actualRisk * m_minRR);
            }
        }
    } else {
        return false;
    }
    
    // Normalize prices
    entry = NormalizeDouble(entry, _Digits);
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL FINAL SANITY CHECK (FIX bug-fix-sl.md)
    // ═══════════════════════════════════════════════════════════════
    double finalDistance = (c.direction == 1) ? (entry - sl) : (sl - entry);
    double minStopDistance = m_minStopPts * _Point;
    
    if(finalDistance < minStopDistance) {
        Print("❌ CRITICAL: SL still too small after all checks!");
        Print("   Direction: ", c.direction == 1 ? "BUY" : "SELL");
        Print("   Entry: ", entry);
        Print("   SL:    ", sl);
        Print("   Distance: ", (int)(finalDistance/_Point), " points (", 
              DoubleToString(finalDistance/_Point/10, 1), " pips)");
        Print("   MinStop:  ", m_minStopPts, " points (", m_minStopPts/10, " pips)");
        Print("   ");
        Print("   This trade is REJECTED to prevent instant stop loss.");
        return false;  // ✅ Reject trade
    }
    
    // Additional check: SL > Spread
    double spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * _Point;
    if(finalDistance <= spread) {
        Print("❌ CRITICAL: SL <= Spread!");
        Print("   SL Distance: ", (int)(finalDistance/_Point), " pts");
        Print("   Spread:      ", (int)(spread/_Point), " pts");
        Print("   This trade would hit SL immediately. REJECTED.");
        return false;
    }
    
    // Calculate RR
    if(c.direction == 1) {
        double denominator = entry - sl;
        if(MathAbs(denominator) < _Point) return false;
        rr = (tp - entry) / denominator;
    } else {
        double denominator = sl - entry;
        if(MathAbs(denominator) < _Point) return false;
        rr = (entry - tp) / denominator;
    }
    
    // Check minimum RR
    if(rr < m_minRR) {
        Print("❌ RR too low: ", DoubleToString(rr, 2), " (min: ", m_minRR, ")");
        return false;
    }
    
    Print("✅ VALIDATION PASSED:");
    Print("   SL Distance: ", (int)(finalDistance/_Point), " pts (", 
          DoubleToString(finalDistance/_Point/10, 1), " pips)");
    Print("   Spread:      ", (int)(spread/_Point), " pts");
    Print("   RR Ratio:    ", DoubleToString(rr, 2), ":1");
    
    return true;
}

//+------------------------------------------------------------------+
//| Place Stop Order                                                  |
//+------------------------------------------------------------------+
bool CExecutor::PlaceStopOrder(int direction, double entry, double sl, double tp,
                               double lots, string comment) {
    if(!SessionOpen() || !SpreadOK() || IsRolloverTime()) {
        return false;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = m_symbol;
    request.volume = NormalizeDouble(lots, 2);
    request.price = entry;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 20;
    request.magic = 20251013;
    request.comment = comment;
    
    if(direction == 1) {
        request.type = ORDER_TYPE_BUY_STOP;
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        if(entry <= ask) {
            Print("❌ Buy stop entry too close to current price");
            return false;
        }
    } else if(direction == -1) {
        request.type = ORDER_TYPE_SELL_STOP;
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(entry >= bid) {
            Print("❌ Sell stop entry too close to current price");
            return false;
        }
    } else {
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // FIX 3: Pre-Order Validation (FIX bug-fix-sl.md)
    // ═══════════════════════════════════════════════════════════════
    double slDistance = (direction == 1) ? (entry - sl) : (sl - entry);
    double minRequired = m_minStopPts * _Point;
    
    if(slDistance < minRequired) {
        Print("❌ STOP ORDER REJECTED: SL too small");
        Print("   Direction:   ", direction == 1 ? "BUY" : "SELL");
        Print("   Entry:       ", entry);
        Print("   SL:          ", sl);
        Print("   SL Distance: ", (int)(slDistance/_Point), " points (", 
              DoubleToString(slDistance/_Point/10, 1), " pips)");
        Print("   Min Required:", m_minStopPts, " points (", m_minStopPts/10, " pips)");
        Print("   ");
        Print("   This order would result in instant stop loss. REJECTED.");
        return false;  // ✅ Prevent order placement
    }
    
    // Additional check: SL > Spread
    double spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * _Point;
    if(slDistance <= spread) {
        Print("❌ STOP ORDER REJECTED: SL <= Spread");
        Print("   SL Distance: ", (int)(slDistance/_Point), " pts");
        Print("   Spread:      ", (int)(spread/_Point), " pts");
        Print("   This order would hit SL immediately. REJECTED.");
        return false;
    }
    
    Print("✅ Pre-order validation passed:");
    Print("   SL Distance: ", (int)(slDistance/_Point), " pts (OK)");
    Print("   Spread:      ", (int)(spread/_Point), " pts");
    
    bool sent = OrderSend(request, result);
    
    if(sent && result.retcode == TRADE_RETCODE_DONE) {
        Print("✅ Stop order placed: #", result.order);
        SetOrderTTL(result.order, m_orderTTL_Bars);
        return true;
    } else {
        Print("❌ Order failed: ", result.retcode, " - ", result.comment);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Place Limit Order (v2.1)                                         |
//+------------------------------------------------------------------+
bool CExecutor::PlaceLimitOrder(int direction, const Candidate &c, double sl, double tp,
                                double lots, string comment) {
    if(!SessionOpen() || !SpreadOK() || IsRolloverTime()) {
        return false;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = m_symbol;
    request.volume = NormalizeDouble(lots, 2);
    request.sl = sl;
    request.tp = tp;
    request.deviation = 20;
    request.magic = 20251013;
    request.comment = comment;
    
    double entryPrice = 0;
    
    if(direction == 1) {
        // BUY LIMIT: Enter at OB bottom or FVG bottom
        if(c.hasOB) {
            entryPrice = c.poiBottom;
        } else if(c.hasFVG) {
            entryPrice = c.fvgBottom;
        } else {
            return false;
        }
        
        // Validate: Entry must be BELOW current price
        double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        if(entryPrice >= currentPrice) {
            Print("❌ Limit entry >= current price");
            return false;
        }
        
        request.type = ORDER_TYPE_BUY_LIMIT;
        request.price = entryPrice;
    }
    else if(direction == -1) {
        // SELL LIMIT: Enter at OB top or FVG top
        if(c.hasOB) {
            entryPrice = c.poiTop;
        } else if(c.hasFVG) {
            entryPrice = c.fvgTop;
        } else {
            return false;
        }
        
        // Validate: Entry must be ABOVE current price
        double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(entryPrice <= currentPrice) {
            Print("❌ Limit entry <= current price");
            return false;
        }
        
        request.type = ORDER_TYPE_SELL_LIMIT;
        request.price = entryPrice;
    } else {
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // FIX 3: Pre-Order Validation (FIX bug-fix-sl.md)
    // ═══════════════════════════════════════════════════════════════
    double slDistance = (direction == 1) ? (entryPrice - sl) : (sl - entryPrice);
    double minRequired = m_minStopPts * _Point;
    
    if(slDistance < minRequired) {
        Print("❌ LIMIT ORDER REJECTED: SL too small");
        Print("   Direction:   ", direction == 1 ? "BUY" : "SELL");
        Print("   Entry:       ", entryPrice);
        Print("   SL:          ", sl);
        Print("   SL Distance: ", (int)(slDistance/_Point), " points (", 
              DoubleToString(slDistance/_Point/10, 1), " pips)");
        Print("   Min Required:", m_minStopPts, " points (", m_minStopPts/10, " pips)");
        Print("   ");
        Print("   This order would result in instant stop loss. REJECTED.");
        return false;  // ✅ Prevent order placement
    }
    
    // Additional check: SL > Spread
    double spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD) * _Point;
    if(slDistance <= spread) {
        Print("❌ LIMIT ORDER REJECTED: SL <= Spread");
        Print("   SL Distance: ", (int)(slDistance/_Point), " pts");
        Print("   Spread:      ", (int)(spread/_Point), " pts");
        Print("   This order would hit SL immediately. REJECTED.");
        return false;
    }
    
    Print("✅ Pre-order validation passed:");
    Print("   SL Distance: ", (int)(slDistance/_Point), " pts (OK)");
    Print("   Spread:      ", (int)(spread/_Point), " pts");
    
    bool sent = OrderSend(request, result);
    
    if(sent && result.retcode == TRADE_RETCODE_DONE) {
        Print("✅ Limit order placed: #", result.order, " at ", entryPrice);
        SetOrderTTL(result.order, 24); // Longer TTL for limit orders
        return true;
    } else {
        Print("❌ Limit order failed: ", result.retcode);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Set order TTL                                                     |
//+------------------------------------------------------------------+
void CExecutor::SetOrderTTL(ulong ticket, int ttl) {
    int size = ArraySize(m_pendingOrders);
    ArrayResize(m_pendingOrders, size + 1);
    
    m_pendingOrders[size].ticket = ticket;
    m_pendingOrders[size].placedTime = TimeCurrent();
    m_pendingOrders[size].barsAge = 0;
    m_pendingOrders[size].ttl = ttl;
}

//+------------------------------------------------------------------+
//| Manage pending orders (TTL)                                      |
//+------------------------------------------------------------------+
void CExecutor::ManagePendingOrders() {
    for(int i = ArraySize(m_pendingOrders) - 1; i >= 0; i--) {
        ulong ticket = m_pendingOrders[i].ticket;
        
        // Check if order still exists
        bool orderExists = false;
        for(int j = 0; j < OrdersTotal(); j++) {
            if(OrderGetTicket(j) == ticket) {
                orderExists = true;
                break;
            }
        }
        
        if(!orderExists) {
            // Order filled or cancelled
            ArrayRemove(m_pendingOrders, i, 1);
            continue;
        }
        
        // Calculate bars age
        datetime orderTime = m_pendingOrders[i].placedTime;
        int orderBar = iBarShift(m_symbol, m_timeframe, orderTime);
        int currentBar = 0;
        m_pendingOrders[i].barsAge = orderBar - currentBar;
        
        // Check TTL
        if(m_pendingOrders[i].barsAge >= m_pendingOrders[i].ttl) {
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_REMOVE;
            request.order = ticket;
            
            if(OrderSend(request, result)) {
                Print("⏰ Order #", ticket, " cancelled (TTL expired)");
            }
            
            ArrayRemove(m_pendingOrders, i, 1);
        }
    }
}

//+------------------------------------------------------------------+
//| Get ATR value                                                     |
//+------------------------------------------------------------------+
double CExecutor::GetATR() {
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) <= 0) {
        return 0;
    }
    return atr[0];
}
//+------------------------------------------------------------------+
//| Find TP Target from Structure (ICT Research-Based)              |
//+------------------------------------------------------------------+
double CExecutor::FindTPTarget(const Candidate &c, double entry) {
    if(!c.valid) return 0;
    
    double high[], low[], close[], open[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    
    int bars = 200;  // Extended lookback per research
    if(CopyHigh(m_symbol, m_timeframe, 0, bars, high) <= 0) return 0;
    if(CopyLow(m_symbol, m_timeframe, 0, bars, low) <= 0) return 0;
    if(CopyClose(m_symbol, m_timeframe, 0, bars, close) <= 0) return 0;
    if(CopyOpen(m_symbol, m_timeframe, 0, bars, open) <= 0) return 0;
    
    double atr = GetATR();
    if(atr <= 0) return 0;
    
    // Target scoring arrays
    double targetPrices[];
    double targetScores[];
    ArrayResize(targetPrices, 0);
    ArrayResize(targetScores, 0);
    
    if(c.direction == 1) {
        // ═══════════════════════════════════════════════════════════
        // BUY: Find resistance structures ABOVE entry
        // ═══════════════════════════════════════════════════════════
        
        // TIER 1: Swing Highs (Weight: 9 points)
        for(int i = 5; i < bars - 3; i++) {
            bool isSwingHigh = true;
            for(int k = 1; k <= 3; k++) {
                if(i - k < 0 || i + k >= ArraySize(high)) {
                    isSwingHigh = false;
                    break;
                }
                if(high[i] <= high[i-k] || high[i] <= high[i+k]) {
                    isSwingHigh = false;
                    break;
                }
            }
            
            if(isSwingHigh && high[i] > entry) {
                double distance = (high[i] - entry) / _Point;
                
                // Reasonable distance check (2-8x ATR per research)
                double atrPoints = atr / _Point;
                if(distance >= 2.0 * atrPoints && distance <= 8.0 * atrPoints) {
                    int idx = ArraySize(targetPrices);
                    ArrayResize(targetPrices, idx + 1);
                    ArrayResize(targetScores, idx + 1);
                    
                    targetPrices[idx] = high[i];
                    
                    // Base score: 9 (swing high)
                    double score = 9.0;
                    
                    // Recency bonus (recent structures more relevant)
                    if(i <= 20) score += 2.0;  // Very recent
                    
                    targetScores[idx] = score;
                }
            }
        }
        
        // TIER 2: Bearish OB - Supply zones (Weight: 7 points)
        for(int i = 5; i < 80; i++) {
            bool isBullish = (close[i] > open[i]);
            
            if(isBullish && i >= 2) {
                // Check displacement (drop after bullish candle)
                if(close[i-1] < low[i+1]) {
                    double obBottom = close[i];
                    double distance = (obBottom - entry) / _Point;
                    double atrPoints = atr / _Point;
                    
                    if(obBottom > entry && distance >= 2.0 * atrPoints && distance <= 8.0 * atrPoints) {
                        int idx = ArraySize(targetPrices);
                        ArrayResize(targetPrices, idx + 1);
                        ArrayResize(targetScores, idx + 1);
                        
                        targetPrices[idx] = obBottom;
                        
                        // Base score: 7 (opposing OB)
                        double score = 7.0;
                        if(i <= 20) score += 2.0;
                        
                        targetScores[idx] = score;
                    }
                }
            }
        }
        
        // TIER 3: Bearish FVG (Weight: 6 points)
        for(int i = 2; i < 60; i++) {
            // Bearish FVG: high[i] < low[i+2]
            if(high[i] < low[i+2]) {
                double fvgBottom = high[i];
                double distance = (fvgBottom - entry) / _Point;
                double atrPoints = atr / _Point;
                
                if(fvgBottom > entry && distance >= 2.0 * atrPoints && distance <= 8.0 * atrPoints) {
                    int idx = ArraySize(targetPrices);
                    ArrayResize(targetPrices, idx + 1);
                    ArrayResize(targetScores, idx + 1);
                    
                    targetPrices[idx] = fvgBottom;
                    
                    // Base score: 6 (FVG boundary)
                    double score = 6.0;
                    if(i <= 20) score += 2.0;
                    
                    targetScores[idx] = score;
                }
            }
        }
        
        // TIER 1: Psychological Round Numbers (Weight: 8 points)
        double currentPrice = entry;
        for(int round = 0; round <= 10; round++) {
            double roundLevel = MathCeil(currentPrice / 10.0) * 10.0 + (round * 10.0);
            double distance = (roundLevel - entry) / _Point;
            double atrPoints = atr / _Point;
            
            if(roundLevel > entry && distance >= 2.0 * atrPoints && distance <= 8.0 * atrPoints) {
                int idx = ArraySize(targetPrices);
                ArrayResize(targetPrices, idx + 1);
                ArrayResize(targetScores, idx + 1);
                
                targetPrices[idx] = roundLevel;
                targetScores[idx] = 8.0;  // Psychological level
            }
        }
    }
    else if(c.direction == -1) {
        // ═══════════════════════════════════════════════════════════
        // SELL: Find support structures BELOW entry
        // ═══════════════════════════════════════════════════════════
        
        // TIER 1: Swing Lows (Weight: 9 points)
        for(int i = 5; i < bars - 3; i++) {
            bool isSwingLow = true;
            for(int k = 1; k <= 3; k++) {
                if(i - k < 0 || i + k >= ArraySize(low)) {
                    isSwingLow = false;
                    break;
                }
                if(low[i] >= low[i-k] || low[i] >= low[i+k]) {
                    isSwingLow = false;
                    break;
                }
            }
            
            if(isSwingLow && low[i] < entry) {
                double distance = (entry - low[i]) / _Point;
                double atrPoints = atr / _Point;
                
                if(distance >= 2.0 * atrPoints && distance <= 8.0 * atrPoints) {
                    int idx = ArraySize(targetPrices);
                    ArrayResize(targetPrices, idx + 1);
                    ArrayResize(targetScores, idx + 1);
                    
                    targetPrices[idx] = low[i];
                    
                    double score = 9.0;
                    if(i <= 20) score += 2.0;
                    
                    targetScores[idx] = score;
                }
            }
        }
        
        // TIER 2: Bullish OB - Demand zones (Weight: 7 points)
        for(int i = 5; i < 80; i++) {
            bool isBearish = (close[i] < open[i]);
            
            if(isBearish && i >= 2) {
                if(close[i-1] > high[i+1]) {
                    double obTop = close[i];
                    double distance = (entry - obTop) / _Point;
                    double atrPoints = atr / _Point;
                    
                    if(obTop < entry && distance >= 2.0 * atrPoints && distance <= 8.0 * atrPoints) {
                        int idx = ArraySize(targetPrices);
                        ArrayResize(targetPrices, idx + 1);
                        ArrayResize(targetScores, idx + 1);
                        
                        targetPrices[idx] = obTop;
                        
                        double score = 7.0;
                        if(i <= 20) score += 2.0;
                        
                        targetScores[idx] = score;
                    }
                }
            }
        }
        
        // TIER 3: Bullish FVG (Weight: 6 points)
        for(int i = 2; i < 60; i++) {
            // Bullish FVG: low[i] > high[i+2]
            if(low[i] > high[i+2]) {
                double fvgTop = low[i];
                double distance = (entry - fvgTop) / _Point;
                double atrPoints = atr / _Point;
                
                if(fvgTop < entry && distance >= 2.0 * atrPoints && distance <= 8.0 * atrPoints) {
                    int idx = ArraySize(targetPrices);
                    ArrayResize(targetPrices, idx + 1);
                    ArrayResize(targetScores, idx + 1);
                    
                    targetPrices[idx] = fvgTop;
                    
                    double score = 6.0;
                    if(i <= 20) score += 2.0;
                    
                    targetScores[idx] = score;
                }
            }
        }
        
        // TIER 1: Psychological Round Numbers (Weight: 8 points)
        double currentPrice = entry;
        for(int round = 0; round <= 10; round++) {
            double roundLevel = MathFloor(currentPrice / 10.0) * 10.0 - (round * 10.0);
            double distance = (entry - roundLevel) / _Point;
            double atrPoints = atr / _Point;
            
            if(roundLevel < entry && distance >= 2.0 * atrPoints && distance <= 8.0 * atrPoints) {
                int idx = ArraySize(targetPrices);
                ArrayResize(targetPrices, idx + 1);
                ArrayResize(targetScores, idx + 1);
                
                targetPrices[idx] = roundLevel;
                targetScores[idx] = 8.0;
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // SCORING & SELECTION (per research)
    // ═══════════════════════════════════════════════════════════
    
    if(ArraySize(targetPrices) == 0) {
        // FALLBACK: ATR-based (per research)
        if(c.direction == 1) {
            return entry + (4.0 * atr);  // 4x ATR fallback
        } else {
            return entry - (4.0 * atr);
        }
    }
    
    // Find highest scoring target (minimum score: 8 per research)
    double bestTarget = 0;
    double bestScore = 0;
    
    for(int i = 0; i < ArraySize(targetScores); i++) {
        if(targetScores[i] >= 8.0 && targetScores[i] > bestScore) {
            bestScore = targetScores[i];
            bestTarget = targetPrices[i];
        }
    }
    
    // If no target meets threshold, use fallback
    if(bestTarget == 0) {
        if(c.direction == 1) {
            bestTarget = entry + (4.0 * atr);
        } else {
            bestTarget = entry - (4.0 * atr);
        }
    }
    
    return NormalizeDouble(bestTarget, _Digits);
}

//+------------------------------------------------------------------+
//| Place Order from ExecutionOrder (NEW - v2.1 Refactor)            |
//+------------------------------------------------------------------+
bool CExecutor::PlaceOrder(const ExecutionOrder &order) {
    // Validate
    if(order.lots <= 0 || order.entryPrice <= 0) {
        Print("❌ Invalid ExecutionOrder");
        return false;
    }
    
    bool success = false;
    ulong ticket = 0;
    
    // Place based on entry type
    if(order.entryType == ENTRY_LIMIT) {
        if(order.direction == 1) {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_PENDING;
            request.type = ORDER_TYPE_BUY_LIMIT;
            request.symbol = m_symbol;
            request.volume = order.lots;
            request.price = order.entryPrice;
            request.sl = order.slPrice;
            request.tp = order.tpPrice;
            request.comment = order.comment;
            request.magic = 123456;
            
            if(OrderSend(request, result)) {
                success = true;
                ticket = result.order;
            }
        } else {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_PENDING;
            request.type = ORDER_TYPE_SELL_LIMIT;
            request.symbol = m_symbol;
            request.volume = order.lots;
            request.price = order.entryPrice;
            request.sl = order.slPrice;
            request.tp = order.tpPrice;
            request.comment = order.comment;
            request.magic = 123456;
            
            if(OrderSend(request, result)) {
                success = true;
                ticket = result.order;
            }
        }
    } else if(order.entryType == ENTRY_STOP) {
        // Use existing PlaceStopOrder method
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        request.action = TRADE_ACTION_PENDING;
        request.type = (order.direction == 1) ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
        request.symbol = m_symbol;
        request.volume = order.lots;
        request.price = order.entryPrice;
        request.sl = order.slPrice;
        request.tp = order.tpPrice;
        request.comment = order.comment;
        request.magic = 123456;
        
        if(OrderSend(request, result)) {
            success = true;
            ticket = result.order;
        }
    } else {
        // MARKET order
        MqlTradeRequest request = {};
        MqlTradeResult result = {};
        request.action = TRADE_ACTION_DEAL;
        request.type = (order.direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
        request.symbol = m_symbol;
        request.volume = order.lots;
        request.price = (order.direction == 1) ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);
        request.sl = order.slPrice;
        request.tp = order.tpPrice;
        request.comment = order.comment;
        request.magic = 123456;
        
        if(OrderSend(request, result)) {
            success = true;
            ticket = result.order;
        }
    }
    
    if(success && ticket > 0) {
        // Save PositionPlan
        SavePositionPlan(ticket, order.positionPlan);
        Print("✅ Order placed: ", order.comment, " | Ticket: ", ticket);
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Save Position Plan (NEW - v2.1 Refactor)                        |
//+------------------------------------------------------------------+
void CExecutor::SavePositionPlan(ulong ticket, const PositionPlan &plan) {
    // Find existing or add new
    int idx = -1;
    for(int i = 0; i < ArraySize(m_ticketMap); i++) {
        if(m_ticketMap[i] == ticket) {
            idx = i;
            break;
        }
    }
    
    if(idx < 0) {
        // Add new
        idx = ArraySize(m_ticketMap);
        ArrayResize(m_ticketMap, idx + 1);
        ArrayResize(m_positionPlans, idx + 1);
        ArrayResize(m_dcaAdded, idx + 1);
        ArrayResize(m_beMoved, idx + 1);
        ArrayResize(m_lastTrailR, idx + 1);
        
        // Initialize arrays
        m_dcaAdded[idx] = 0;  // Bit flags: 0 = no DCA added
        m_beMoved[idx] = false;
        m_lastTrailR[idx] = 0.0;
    }
    
    m_ticketMap[idx] = ticket;
    m_positionPlans[idx] = plan;
}

//+------------------------------------------------------------------+
//| Get Position Plan (NEW - v2.1 Refactor)                          |
//+------------------------------------------------------------------+
PositionPlan CExecutor::GetPositionPlan(ulong ticket) {
    for(int i = 0; i < ArraySize(m_ticketMap); i++) {
        if(m_ticketMap[i] == ticket) {
            return m_positionPlans[i];
        }
    }
    
    // Return default plan if not found
    PositionPlan defaultPlan;
    defaultPlan.dcaPlan.enabled = false;
    defaultPlan.bePlan.enabled = false;
    defaultPlan.trailPlan.enabled = false;
    return defaultPlan;
}

//+------------------------------------------------------------------+
//| Manage Positions - Execute PositionPlans (NEW - v2.1 Refactor)  |
//+------------------------------------------------------------------+
void CExecutor::ManagePositions() {
    // Execute PositionPlan for each open position
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol) {
                PositionPlan plan = GetPositionPlan(ticket);
                ExecutePositionPlan(ticket, plan);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Position Plan (NEW - v2.1 Refactor)                      |
//+------------------------------------------------------------------+
void CExecutor::ExecutePositionPlan(ulong ticket, const PositionPlan &plan) {
    // Execute DCA Plan
    if(plan.dcaPlan.enabled) {
        ExecuteDCAPlan(ticket, plan.dcaPlan);
    }
    
    // Execute BE Plan
    if(plan.bePlan.enabled) {
        ExecuteBEPlan(ticket, plan.bePlan);
    }
    
    // Execute Trail Plan
    if(plan.trailPlan.enabled) {
        ExecuteTrailPlan(ticket, plan.trailPlan);
    }
}

//+------------------------------------------------------------------+
//| Execute DCA Plan (NEW - v2.1 Refactor)                           |
//+------------------------------------------------------------------+
void CExecutor::ExecuteDCAPlan(ulong ticket, const DCAPlan &plan) {
    double profitR = CalcProfitInR(ticket);
    
    // Check DCA Level 1
    if(plan.maxLevels >= 1 && profitR >= plan.level1_triggerR) {
        if(!IsDCAAdded(ticket, 1)) {
            double originalLot = GetOriginalLot(ticket);
            double dcaLot = originalLot * plan.level1_lotMultiplier;
            int direction = GetPositionDirection(ticket);
            
            // Place DCA order (simplified - need to integrate with risk_manager)
            Print("📊 DCA Level 1 triggered for ticket ", ticket, " | Lot: ", dcaLot);
            MarkDCAAdded(ticket, 1);
        }
    }
    
    // Check DCA Level 2
    if(plan.maxLevels >= 2 && profitR >= plan.level2_triggerR) {
        if(!IsDCAAdded(ticket, 2)) {
            double originalLot = GetOriginalLot(ticket);
            double dcaLot = originalLot * plan.level2_lotMultiplier;
            int direction = GetPositionDirection(ticket);
            
            Print("📊 DCA Level 2 triggered for ticket ", ticket, " | Lot: ", dcaLot);
            MarkDCAAdded(ticket, 2);
        }
    }
    
    // Check DCA Level 3 (if exists)
    if(plan.maxLevels >= 3 && profitR >= plan.level3_triggerR) {
        if(!IsDCAAdded(ticket, 3)) {
            double originalLot = GetOriginalLot(ticket);
            double dcaLot = originalLot * plan.level3_lotMultiplier;
            int direction = GetPositionDirection(ticket);
            
            Print("📊 DCA Level 3 triggered for ticket ", ticket, " | Lot: ", dcaLot);
            MarkDCAAdded(ticket, 3);
        }
    }
}

//+------------------------------------------------------------------+
//| Execute BE Plan (NEW - v2.1 Refactor)                            |
//+------------------------------------------------------------------+
void CExecutor::ExecuteBEPlan(ulong ticket, const BEPlan &plan) {
    double profitR = CalcProfitInR(ticket);
    
    if(profitR >= plan.triggerR && !IsBEMoved(ticket)) {
        if(plan.moveAllPositions) {
            // Move all positions same direction
            int direction = GetPositionDirection(ticket);
            // Need to integrate with risk_manager
            Print("📊 BE triggered for all ", (direction == 1 ? "LONG" : "SHORT"), " positions");
        } else {
            // Move only this position
            if(PositionSelectByTicket(ticket)) {
                double entry = PositionGetDouble(POSITION_PRICE_OPEN);
                double tp = PositionGetDouble(POSITION_TP);
                int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
                entry = NormalizeDouble(entry, digits);
                tp = NormalizeDouble(tp, digits);
                
                // Use OrderSend with TRADE_ACTION_SLTP to modify position
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);
                
                request.action = TRADE_ACTION_SLTP;
                request.position = ticket;
                request.symbol = m_symbol;
                request.sl = entry;
                request.tp = tp;
                
                if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE) {
                    Print("✅ BE moved for ticket ", ticket);
                }
            }
        }
        MarkBEMoved(ticket);
    }
}

//+------------------------------------------------------------------+
//| Execute Trail Plan (NEW - v2.1 Refactor)                          |
//+------------------------------------------------------------------+
void CExecutor::ExecuteTrailPlan(ulong ticket, const TrailPlan &plan) {
    double profitR = CalcProfitInR(ticket);
    
    if(profitR >= plan.startR) {
        double lastTrailR = GetLastTrailR(ticket);
        
        // Check if need to trail (step check)
        if(profitR >= lastTrailR + plan.stepR) {
            // Calculate new SL based on ATR distance
            double atr = GetATR();
            double distance = plan.distanceATR * atr;
            double currentSL = PositionGetDouble(POSITION_SL);
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            int direction = GetPositionDirection(ticket);
            
            double newSL = 0;
            if(direction == 1) {
                // BUY: SL = current price - distance
                double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                newSL = currentPrice - distance;
                if(newSL > currentSL && newSL < entry) {
                    newSL = entry; // Don't go below entry
                }
            } else {
                // SELL: SL = current price + distance
                double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
                newSL = currentPrice + distance;
                if(newSL < currentSL && newSL > entry) {
                    newSL = entry; // Don't go above entry
                }
            }
            
            if(newSL > 0) {
                if(PositionSelectByTicket(ticket)) {
                    double tp = PositionGetDouble(POSITION_TP);
                    int digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
                    newSL = NormalizeDouble(newSL, digits);
                    tp = NormalizeDouble(tp, digits);
                    
                    // Use OrderSend with TRADE_ACTION_SLTP to modify position
                    MqlTradeRequest request;
                    MqlTradeResult result;
                    ZeroMemory(request);
                    ZeroMemory(result);
                    
                    request.action = TRADE_ACTION_SLTP;
                    request.position = ticket;
                    request.symbol = m_symbol;
                    request.sl = newSL;
                    request.tp = tp;
                    
                    if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE) {
                        SetLastTrailR(ticket, profitR);
                        Print("✅ Trailing stop updated for ticket ", ticket, " | New SL: ", newSL);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Helper: Calculate Profit in R (NEW - v2.1 Refactor)             |
//+------------------------------------------------------------------+
double CExecutor::CalcProfitInR(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return 0;
    
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(m_symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    
    double slDistance = MathAbs(entry - sl);
    if(slDistance <= 0) return 0;
    
    double profitDistance = MathAbs(currentPrice - entry);
    return profitDistance / slDistance;
}

//+------------------------------------------------------------------+
//| Helper: Check if DCA Added (NEW - v2.1 Refactor)                 |
//+------------------------------------------------------------------+
bool CExecutor::IsDCAAdded(ulong ticket, int level) {
    for(int i = 0; i < ArraySize(m_ticketMap); i++) {
        if(m_ticketMap[i] == ticket) {
            if(level >= 1 && level <= 3) {
                int bit = level - 1;  // bit 0, 1, or 2
                return ((m_dcaAdded[i] & (1 << bit)) != 0);
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Helper: Mark DCA Added (NEW - v2.1 Refactor)                    |
//+------------------------------------------------------------------+
void CExecutor::MarkDCAAdded(ulong ticket, int level) {
    for(int i = 0; i < ArraySize(m_ticketMap); i++) {
        if(m_ticketMap[i] == ticket) {
            if(level >= 1 && level <= 3) {
                int bit = level - 1;  // bit 0, 1, or 2
                m_dcaAdded[i] |= (1 << bit);  // Set bit
            }
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Helper: Check if BE Moved (NEW - v2.1 Refactor)                  |
//+------------------------------------------------------------------+
bool CExecutor::IsBEMoved(ulong ticket) {
    for(int i = 0; i < ArraySize(m_ticketMap); i++) {
        if(m_ticketMap[i] == ticket) {
            return m_beMoved[i];
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Helper: Mark BE Moved (NEW - v2.1 Refactor)                     |
//+------------------------------------------------------------------+
void CExecutor::MarkBEMoved(ulong ticket) {
    for(int i = 0; i < ArraySize(m_ticketMap); i++) {
        if(m_ticketMap[i] == ticket) {
            m_beMoved[i] = true;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Helper: Get Last Trail R (NEW - v2.1 Refactor)                   |
//+------------------------------------------------------------------+
double CExecutor::GetLastTrailR(ulong ticket) {
    for(int i = 0; i < ArraySize(m_ticketMap); i++) {
        if(m_ticketMap[i] == ticket) {
            return m_lastTrailR[i];
        }
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| Helper: Set Last Trail R (NEW - v2.1 Refactor)                   |
//+------------------------------------------------------------------+
void CExecutor::SetLastTrailR(ulong ticket, double r) {
    for(int i = 0; i < ArraySize(m_ticketMap); i++) {
        if(m_ticketMap[i] == ticket) {
            m_lastTrailR[i] = r;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Helper: Get Original Lot (NEW - v2.1 Refactor)                   |
//+------------------------------------------------------------------+
double CExecutor::GetOriginalLot(ulong ticket) {
    if(PositionSelectByTicket(ticket)) {
        return PositionGetDouble(POSITION_VOLUME);
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Helper: Get Position Direction (NEW - v2.1 Refactor)             |
//+------------------------------------------------------------------+
int CExecutor::GetPositionDirection(ulong ticket) {
    if(PositionSelectByTicket(ticket)) {
        long posType = PositionGetInteger(POSITION_TYPE);
        return (posType == POSITION_TYPE_BUY) ? 1 : -1;
    }
    return 0;
}

//+------------------------------------------------------------------+

