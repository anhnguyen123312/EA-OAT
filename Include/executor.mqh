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
              int triggerBody, int entryBuffer, int minStop, int orderTTL, double minRR);
    
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
                     int triggerBody, int entryBuffer, int minStop, int orderTTL, double minRR) {
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
    datetime t = TimeCurrent();
    MqlDateTime s;
    TimeToStruct(t, s);
    
    // Calculate proper timezone offset: VN_GMT - Server_GMT
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    return (hour_localvn >= m_sessStartHour && hour_localvn < m_sessEndHour);
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                    |
//+------------------------------------------------------------------+
bool CExecutor::SpreadOK() {
    long spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);
    double atr = GetATR();
    
    // Dynamic spread filter: accept up to max(fixed threshold, ATR% guard)
    if(atr > 0) {
        long dynamicMax = (long)MathMax(m_spreadMaxPts, m_spreadATRpct * atr / _Point);
        return (spread <= dynamicMax);
    }
    
    return (spread <= m_spreadMaxPts);
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
    
    // Spec ner.md: body >= max( (TriggerBodyATR/100)×ATR, 30 pts )
    double minBodySize = MathMax((m_triggerBodyATR / 100.0) * atr, 30.0 * _Point);
    
    // Scan bars 0-3 for trigger candle
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
                return true;
            }
            // For buy setup, need bullish trigger
            else if(direction == 1 && close > open) {
                triggerHigh = high;
                triggerLow = low;
                return true;
            }
        }
    }
    
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
        
        // SL at sweep level or POI bottom - buffer, must be >= minStop
        if(c.hasSweep) {
            sl = c.sweepLevel - buffer;
        } else if(c.hasOB || c.hasFVG) {
            sl = c.poiBottom - buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop distance (soft limit, don't force >= ATR)
        double slDistance = entry - sl;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            sl = entry - minStopDistance;
        }
        
        // Calculate TP based on RR
        double risk = entry - sl;
        tp = entry + (risk * m_minRR);
        
        // Could also use opposite liquidity level if available
        // For now using RR-based TP
        
    } else if(c.direction == -1) {
        // SELL setup
        entry = triggerLow - buffer;
        
        // SL at sweep level or POI top + buffer, must be >= minStop
        if(c.hasSweep) {
            sl = c.sweepLevel + buffer;
        } else if(c.hasOB || c.hasFVG) {
            sl = c.poiTop + buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop distance (soft limit, don't force >= ATR)
        double slDistance = sl - entry;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            sl = entry + minStopDistance;
        }
        
        // Calculate TP based on RR
        double risk = sl - entry;
        tp = entry - (risk * m_minRR);
        
    } else {
        return false;
    }
    
    // Normalize prices
    entry = NormalizeDouble(entry, _Digits);
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    
    // Calculate actual RR
    if(c.direction == 1) {
        rr = (tp - entry) / (entry - sl);
    } else {
        rr = (entry - tp) / (sl - entry);
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

