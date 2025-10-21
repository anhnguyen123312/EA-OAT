//+------------------------------------------------------------------+
//|                                                     executor.mqh |
//|                   Execution Layer - Session, Trigger, Entry      |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

#include "arbiter.mqh"

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
        
        // Calculate METHOD-based SL
        double methodSL = 0;
        if(c.hasSweep) {
            methodSL = c.sweepLevel - buffer;
        } else if(c.hasOB || c.hasFVG) {
            methodSL = c.poiBottom - buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop distance
        double slDistance = entry - methodSL;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            methodSL = entry - minStopDistance;
        }
        
        // Calculate METHOD-based TP
        double methodRisk = entry - methodSL;
        double methodTP = entry + (methodRisk * m_minRR);
        
        // Apply FIXED SL if enabled
        if(m_useFixedSL) {
            double fixedSL_Distance = m_fixedSL_Pips * 10 * _Point;
            sl = entry - fixedSL_Distance;
        } else {
            sl = methodSL;
        }
        
        // Apply FIXED TP if enabled
        if(m_fixedTP_Enable) {
            double fixedTP_Distance = m_fixedTP_Pips * 10 * _Point;
            tp = entry + fixedTP_Distance;
        } else {
            tp = methodTP;
        }
    }
    else if(c.direction == -1) {
        // SELL SETUP
        entry = triggerLow - buffer;
        
        // Calculate METHOD-based SL
        double methodSL = 0;
        if(c.hasSweep) {
            methodSL = c.sweepLevel + buffer;
        } else if(c.hasOB || c.hasFVG) {
            methodSL = c.poiTop + buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop distance
        double slDistance = methodSL - entry;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            methodSL = entry + minStopDistance;
        }
        
        // Calculate METHOD-based TP
        double methodRisk = methodSL - entry;
        double methodTP = entry - (methodRisk * m_minRR);
        
        // Apply FIXED SL if enabled
        if(m_useFixedSL) {
            double fixedSL_Distance = m_fixedSL_Pips * 10 * _Point;
            sl = entry + fixedSL_Distance;
        } else {
            sl = methodSL;
        }
        
        // Apply FIXED TP if enabled
        if(m_fixedTP_Enable) {
            double fixedTP_Distance = m_fixedTP_Pips * 10 * _Point;
            tp = entry - fixedTP_Distance;
        } else {
            tp = methodTP;
        }
    } else {
        return false;
    }
    
    // Normalize prices
    entry = NormalizeDouble(entry, _Digits);
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    
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

