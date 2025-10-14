//+------------------------------------------------------------------+
//|                                                     executor.mqh |
//|                              Trade Execution & Session Management|
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property version   "1.00"
#property strict

#include "arbiter.mqh"

//+------------------------------------------------------------------+
//| Executor Class - Entry execution and session management         |
//+------------------------------------------------------------------+
class CExecutor {
private:
    string   m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
    // Session parameters
    int      m_sessStartHour;
    int      m_sessEndHour;
    int      m_spreadMaxPts;
    double   m_spreadATRpct;      // Spread ATR% guard
    int      m_timezoneOffset;    // GMT offset for Asia/Ho_Chi_Minh
    
    // Execution parameters
    int      m_triggerBodyATR;    // x100 (e.g., 40 = 0.40 ATR)
    int      m_entryBufferPts;
    int      m_minStopPts;
    int      m_orderTTL_Bars;
    double   m_minRR;
    
    // [NEW] Fixed SL/TP mode
    bool     m_useFixedSL;
    int      m_fixedSL_Pips;
    bool     m_fixedTP_Enable;
    int      m_fixedTP_Pips;
    
    // Handles
    int      m_atrHandle;
    
    // Pending order tracking
    struct PendingOrderInfo {
        ulong    ticket;
        datetime placedTime;
        int      barsAge;
    };
    PendingOrderInfo m_pendingOrders[];
    
public:
    CExecutor();
    ~CExecutor();
    
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              int sessStart, int sessEnd, int spreadMax, double spreadATRpct,
              int triggerBody, int entryBuffer, int minStop, int orderTTL, double minRR,
              bool useFixedSL, int fixedSL_Pips, bool fixedTP_Enable, int fixedTP_Pips);
    
    bool SessionOpen();
    bool SpreadOK();
    bool IsRolloverTime();
    
    bool GetTriggerCandle(int direction, double &triggerHigh, double &triggerLow);
    bool CalculateEntry(const Candidate &c, double triggerHigh, double triggerLow,
                       double &entry, double &sl, double &tp, double &rr);
    
    bool PlaceStopOrder(int direction, double entry, double sl, double tp, double lots, string comment);
    void ManagePendingOrders();
    void SetOrderTTL(ulong ticket);
    
private:
    double GetATR();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CExecutor::CExecutor() {
    m_atrHandle = INVALID_HANDLE;
    m_timezoneOffset = 7; // GMT+7 for Asia/Ho_Chi_Minh
    m_useFixedSL = false;
    m_fixedSL_Pips = 100;
    m_fixedTP_Enable = false;
    m_fixedTP_Pips = 200;
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
//| Initialize executor parameters                                   |
//+------------------------------------------------------------------+
bool CExecutor::Init(string symbol, ENUM_TIMEFRAMES tf,
                     int sessStart, int sessEnd, int spreadMax, double spreadATRpct,
                     int triggerBody, int entryBuffer, int minStop, int orderTTL, double minRR,
                     bool useFixedSL, int fixedSL_Pips, bool fixedTP_Enable, int fixedTP_Pips) {
    m_symbol = symbol;
    m_timeframe = tf;
    m_sessStartHour = sessStart;
    m_sessEndHour = sessEnd;
    m_spreadMaxPts = spreadMax;
    m_spreadATRpct = spreadATRpct;
    m_triggerBodyATR = triggerBody;
    m_entryBufferPts = entryBuffer;
    m_minStopPts = minStop;
    m_orderTTL_Bars = orderTTL;
    m_minRR = minRR;
    
    // [NEW] Fixed SL/TP mode
    m_useFixedSL = useFixedSL;
    m_fixedSL_Pips = fixedSL_Pips;
    m_fixedTP_Enable = fixedTP_Enable;
    m_fixedTP_Pips = fixedTP_Pips;
    
    // Create ATR handle
    m_atrHandle = iATR(m_symbol, m_timeframe, 14);
    if(m_atrHandle == INVALID_HANDLE) {
        Print("Executor: Failed to create ATR indicator handle");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if current time is within trading session                  |
//+------------------------------------------------------------------+
bool CExecutor::SessionOpen() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s); // Server time
    
    // [FIX] Calculate proper timezone offset
    // VN_GMT - Server_GMT = delta to apply
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    bool inSession = (hour_localvn >= m_sessStartHour && hour_localvn < m_sessEndHour);
    
    // [DEBUG] Log once per hour for verification
    static int lastLogHour = -1;
    if(s.hour != lastLogHour) {
        Print("🕐 Session Check | Server: ", s.hour, ":00 | VN Time: ", hour_localvn, 
              ":00 | Status: ", inSession ? "IN SESSION ✅" : "CLOSED ❌");
        lastLogHour = s.hour;
    }
    
    return inSession;
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                    |
//+------------------------------------------------------------------+
bool CExecutor::SpreadOK() {
    long spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
    double atr = GetATR();
    
    // [NEW] Dynamic spread filter: accept up to max(fixed threshold, 8% of ATR)
    if(atr > 0) {
        long dynamicMax = (long)MathMax(m_spreadMaxPts, 0.08 * atr / _Point);
        
        if(spread > dynamicMax) {
            Print("⚠️ Spread too wide: ", spread, " pts (max: ", dynamicMax, " pts)");
            return false;
        }
        return true;
    }
    
    // Fallback to static if can't get ATR
    if(spread > m_spreadMaxPts) {
        Print("⚠️ Spread too wide: ", spread, " pts (max: ", m_spreadMaxPts, " pts)");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Check if it's rollover time (avoid trading ±5 min around 00:00) |
//+------------------------------------------------------------------+
bool CExecutor::IsRolloverTime() {
    datetime t = TimeCurrent();
    MqlDateTime s;
    TimeToStruct(t, s);
    
    // Check if within 5 minutes of midnight server time
    int minutesFromMidnight = s.hour * 60 + s.min;
    if(minutesFromMidnight < 5 || minutesFromMidnight > 1435) { // 23:55 = 1435 minutes
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Get ATR value                                                     |
//+------------------------------------------------------------------+
double CExecutor::GetATR() {
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(m_atrHandle, 0, 0, 2, atr) > 0) {
        return atr[0];
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Get trigger candle for entry                                     |
//+------------------------------------------------------------------+
bool CExecutor::GetTriggerCandle(int direction, double &triggerHigh, double &triggerLow) {
    double atr = GetATR();
    if(atr <= 0) return false;
    
    // [CHANGE] Lower threshold: 25% of ATR or minimum 30 points (3 pips)
    double minBodySize = MathMax((m_triggerBodyATR / 100.0) * atr, 30.0 * _Point);
    
    // [CHANGE] Scan bars 0-3 instead of just 0-1
    for(int i = 0; i <= 3; i++) {
        double open = iOpen(m_symbol, m_timeframe, i);
        double close = iClose(m_symbol, m_timeframe, i);
        double high = iHigh(m_symbol, m_timeframe, i);
        double low = iLow(m_symbol, m_timeframe, i);
        double bodySize = MathAbs(close - open);
        
        if(bodySize >= minBodySize) {
            // For sell setup, need bearish trigger
            if(direction == -1 && close < open) {
                triggerHigh = high;
                triggerLow = low;
                Print("🎯 Trigger SELL: Bar ", i, " | Body: ", (int)(bodySize/_Point), 
                      " pts (min: ", (int)(minBodySize/_Point), " pts)");
                return true;
            }
            // For buy setup, need bullish trigger
            else if(direction == 1 && close > open) {
                triggerHigh = high;
                triggerLow = low;
                Print("🎯 Trigger BUY: Bar ", i, " | Body: ", (int)(bodySize/_Point), 
                      " pts (min: ", (int)(minBodySize/_Point), " pts)");
                return true;
            }
        }
    }
    
    Print("❌ No trigger candle found (scanned bars 0-3)");
    return false;
}

//+------------------------------------------------------------------+
//| Calculate entry, SL, TP and RR for candidate                     |
//+------------------------------------------------------------------+
bool CExecutor::CalculateEntry(const Candidate &c, double triggerHigh, double triggerLow,
                               double &entry, double &sl, double &tp, double &rr) {
    if(!c.valid) return false;
    
    double buffer = m_entryBufferPts * _Point;
    double atr = GetATR();
    
    if(c.direction == 1) {
        // BUY setup
        entry = triggerHigh + buffer;
        
        // [STEP 1] Calculate METHOD-based SL & TP first
        double methodSL = 0;
        double methodTP = 0;
        
        if(c.hasSweep) {
            methodSL = c.sweepLevel - buffer;
        } else if(c.hasOB || c.hasFVG) {
            methodSL = c.poiBottom - buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop distance for method SL
        double slDistance = entry - methodSL;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            methodSL = entry - minStopDistance;
        }
        
        // Calculate method-based TP (RR-based on method SL)
        double methodRisk = entry - methodSL;
        methodTP = entry + (methodRisk * m_minRR);
        
        // [STEP 2] Apply FIXED SL if enabled (ưu tiên config)
        if(m_useFixedSL) {
            double fixedSL_Distance = m_fixedSL_Pips * 10 * _Point;
            sl = entry - fixedSL_Distance;
            Print("📌 FIXED SL: ", m_fixedSL_Pips, " pips (override method)");
        } else {
            sl = methodSL;
            Print("🎯 METHOD SL: ", (int)((entry - sl)/_Point/10), " pips (from structure)");
        }
        
        // [STEP 3] TP: Luôn dùng PHƯƠNG PHÁP (không theo RR của Fixed SL)
        if(m_fixedTP_Enable) {
            // Fixed TP absolute
            double fixedTP_Distance = m_fixedTP_Pips * 10 * _Point;
            tp = entry + fixedTP_Distance;
            Print("📌 FIXED TP: ", m_fixedTP_Pips, " pips (absolute)");
        } else {
            // TP từ phương pháp (không phụ thuộc Fixed SL)
            tp = methodTP;
            Print("🎯 METHOD TP: ", (int)((tp - entry)/_Point/10), " pips (from method RR)");
        }
        
    } else if(c.direction == -1) {
        // SELL setup
        entry = triggerLow - buffer;
        
        // [STEP 1] Calculate METHOD-based SL & TP first
        double methodSL = 0;
        double methodTP = 0;
        
        if(c.hasSweep) {
            methodSL = c.sweepLevel + buffer;
        } else if(c.hasOB || c.hasFVG) {
            methodSL = c.poiTop + buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop distance for method SL
        double slDistance = methodSL - entry;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            methodSL = entry + minStopDistance;
        }
        
        // Calculate method-based TP (RR-based on method SL)
        double methodRisk = methodSL - entry;
        methodTP = entry - (methodRisk * m_minRR);
        
        // [STEP 2] Apply FIXED SL if enabled (ưu tiên config)
        if(m_useFixedSL) {
            double fixedSL_Distance = m_fixedSL_Pips * 10 * _Point;
            sl = entry + fixedSL_Distance;
            Print("📌 FIXED SL: ", m_fixedSL_Pips, " pips (override method)");
        } else {
            sl = methodSL;
            Print("🎯 METHOD SL: ", (int)((sl - entry)/_Point/10), " pips (from structure)");
        }
        
        // [STEP 3] TP: Luôn dùng PHƯƠNG PHÁP (không theo RR của Fixed SL)
        if(m_fixedTP_Enable) {
            // Fixed TP absolute
            double fixedTP_Distance = m_fixedTP_Pips * 10 * _Point;
            tp = entry - fixedTP_Distance;
            Print("📌 FIXED TP: ", m_fixedTP_Pips, " pips (absolute)");
        } else {
            // TP từ phương pháp (không phụ thuộc Fixed SL)
            tp = methodTP;
            Print("🎯 METHOD TP: ", (int)((entry - tp)/_Point/10), " pips (from method RR)");
        }
        
    } else {
        return false;
    }
    
    // Normalize prices
    entry = NormalizeDouble(entry, _Digits);
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    
    // Calculate actual RR
    // [FIX] Prevent divide by zero
    if(c.direction == 1) {
        double denominator = entry - sl;
        if(MathAbs(denominator) < _Point) {
            Print("❌ Invalid entry/SL: too close together");
            return false;
        }
        rr = (tp - entry) / denominator;
    } else {
        double denominator = sl - entry;
        if(MathAbs(denominator) < _Point) {
            Print("❌ Invalid entry/SL: too close together");
            return false;
        }
        rr = (entry - tp) / denominator;
    }
    
    // Check if RR meets minimum
    if(rr < m_minRR) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Place stop order                                                  |
//+------------------------------------------------------------------+
bool CExecutor::PlaceStopOrder(int direction, double entry, double sl, double tp, double lots, string comment) {
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
        // Adjust entry if too close to current price
        double ask = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        if(entry <= ask) {
            Print("Buy stop entry too close to current price");
            return false;
        }
    } else if(direction == -1) {
        request.type = ORDER_TYPE_SELL_STOP;
        // Adjust entry if too close to current price
        double bid = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(entry >= bid) {
            Print("Sell stop entry too close to current price");
            return false;
        }
    } else {
        return false;
    }
    
    bool sent = OrderSend(request, result);
    
    if(sent && result.retcode == TRADE_RETCODE_DONE) {
        Print("Order placed successfully: ", result.order);
        SetOrderTTL(result.order);
        return true;
    } else {
        Print("Order failed: ", result.retcode, " - ", result.comment);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Set TTL for pending order                                        |
//+------------------------------------------------------------------+
void CExecutor::SetOrderTTL(ulong ticket) {
    int size = ArraySize(m_pendingOrders);
    ArrayResize(m_pendingOrders, size + 1);
    m_pendingOrders[size].ticket = ticket;
    m_pendingOrders[size].placedTime = TimeCurrent();
    m_pendingOrders[size].barsAge = 0;
}

//+------------------------------------------------------------------+
//| Manage pending orders - cancel if TTL expired                    |
//+------------------------------------------------------------------+
void CExecutor::ManagePendingOrders() {
    datetime currentTime = TimeCurrent();
    int currentBar = iBars(m_symbol, m_timeframe);
    
    for(int i = ArraySize(m_pendingOrders) - 1; i >= 0; i--) {
        // Check if order still exists
        if(!OrderSelect(m_pendingOrders[i].ticket)) {
            // Order was filled or cancelled, remove from tracking
            ArrayRemove(m_pendingOrders, i, 1);
            continue;
        }
        
        // Calculate bars age
        datetime orderTime = m_pendingOrders[i].placedTime;
        int orderBar = iBarShift(m_symbol, m_timeframe, orderTime);
        int currentBar = 0;
        m_pendingOrders[i].barsAge = orderBar - currentBar;
        
        // Check TTL
        if(m_pendingOrders[i].barsAge >= m_orderTTL_Bars) {
            // Cancel order
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_REMOVE;
            request.order = m_pendingOrders[i].ticket;
            
            if(OrderSend(request, result)) {
                Print("Order ", m_pendingOrders[i].ticket, " cancelled due to TTL");
            }
            
            ArrayRemove(m_pendingOrders, i, 1);
        }
    }
}

