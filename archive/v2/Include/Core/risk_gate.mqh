//+------------------------------------------------------------------+
//|                                                     risk_gate.mqh |
//|                    Layer 0: Risk Gate - First Check              |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

#include "..\Common\signal_structs.mqh"

//+------------------------------------------------------------------+
//| CRiskGate Class - Risk Check First                               |
//+------------------------------------------------------------------+
class CRiskGate {
private:
    string   m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    int      m_atrHandle;
    
    // Risk parameters
    double   m_riskPct;          // Risk per trade (%)
    double   m_dailyMddMax;      // Daily MDD limit (%)
    bool     m_useDailyMDD;
    bool     m_useEquityMDD;
    int      m_dailyResetHour;   // GMT+7
    
    // Session parameters
    bool     m_sessionOpen;
    int      m_sessStartHour;
    int      m_sessEndHour;
    
    // Spread parameters
    int      m_spreadMaxPts;
    double   m_spreadATRpct;
    
    // Daily MDD tracking
    double   m_startDayBalance;
    bool     m_tradingHalted;
    datetime m_lastDayCheck;
    
    // Lot sizing
    double   m_lotBase;
    double   m_lotMax;
    double   m_equityPerLotInc;
    double   m_lotIncrement;
    
public:
    CRiskGate();
    ~CRiskGate();
    
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              double riskPct, double dailyMddMax, bool useDailyMDD, 
              bool useEquityMDD, int dailyResetHour,
              bool sessionOpen, int sessStartHour, int sessEndHour,
              int spreadMaxPts, double spreadATRpct,
              double lotBase, double lotMax, double equityPerLotInc, double lotIncrement);
    
    // Main check function
    RiskGateResult Check();
    
    // Individual checks
    bool IsTradingHalted();
    bool IsSessionOpen();
    
    // Calculations
    double GetMaxLotSize();
    
    // Daily MDD
    void CheckDailyMDD();
    void ResetDailyTracking();
    
private:
    int GetLocalHour();
    double GetATR();
    double CalculateMaxLotSize(double riskAmount, double maxRiskPips);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskGate::CRiskGate() {
    m_atrHandle = INVALID_HANDLE;
    m_tradingHalted = false;
    m_startDayBalance = 0;
    m_lastDayCheck = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskGate::~CRiskGate() {
    if(m_atrHandle != INVALID_HANDLE) {
        IndicatorRelease(m_atrHandle);
    }
}

//+------------------------------------------------------------------+
//| Initialize Risk Gate                                             |
//+------------------------------------------------------------------+
bool CRiskGate::Init(string symbol, ENUM_TIMEFRAMES tf,
                     double riskPct, double dailyMddMax, bool useDailyMDD,
                     bool useEquityMDD, int dailyResetHour,
                     bool sessionOpen, int sessStartHour, int sessEndHour,
                     int spreadMaxPts, double spreadATRpct,
                     double lotBase, double lotMax, double equityPerLotInc, double lotIncrement) {
    
    m_symbol = symbol;
    m_timeframe = tf;
    m_riskPct = riskPct;
    m_dailyMddMax = dailyMddMax;
    m_useDailyMDD = useDailyMDD;
    m_useEquityMDD = useEquityMDD;
    m_dailyResetHour = dailyResetHour;
    m_sessionOpen = sessionOpen;
    m_sessStartHour = sessStartHour;
    m_sessEndHour = sessEndHour;
    m_spreadMaxPts = spreadMaxPts;
    m_spreadATRpct = spreadATRpct;
    m_lotBase = lotBase;
    m_lotMax = lotMax;
    m_equityPerLotInc = equityPerLotInc;
    m_lotIncrement = lotIncrement;
    
    // Initialize ATR
    m_atrHandle = iATR(symbol, tf, 14);
    if(m_atrHandle == INVALID_HANDLE) {
        Print("❌ ERROR: Failed to create ATR indicator");
        return false;
    }
    
    // Initialize daily tracking
    ResetDailyTracking();
    
    Print("✅ Risk Gate initialized");
    return true;
}

//+------------------------------------------------------------------+
//| Main Check Function - Returns RiskGateResult                     |
//+------------------------------------------------------------------+
RiskGateResult CRiskGate::Check() {
    RiskGateResult result;
    result.canTrade = false;
    result.maxRiskPips = 0;
    result.maxLotSize = 0;
    result.tradingHalted = false;
    result.reason = "";
    
    // ═══════════════════════════════════════════════════════════
    // Check 1: Daily MDD
    // ═══════════════════════════════════════════════════════════
    if(m_useDailyMDD) {
        CheckDailyMDD();
        if(IsTradingHalted()) {
            result.tradingHalted = true;
            result.reason = "Daily MDD limit reached";
            return result;
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // Check 2: Session
    // ═══════════════════════════════════════════════════════════
    if(!IsSessionOpen()) {
        result.reason = "Outside trading session";
        return result;
    }
    
    // ═══════════════════════════════════════════════════════════
    // Calculate max lot (lot cap only - no risk pips here)
    // ═══════════════════════════════════════════════════════════
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (m_riskPct / 100.0);
    
    // maxRiskPips intentionally kept = 0 (RiskGate không tính risk pips)
    result.maxLotSize = CalculateMaxLotSize(riskAmount, 0);
    
    // Cap to max lot
    if(result.maxLotSize > m_lotMax) {
        result.maxLotSize = m_lotMax;
    }
    
    result.canTrade = true;
    result.reason = "OK";
    
    return result;
}

//+------------------------------------------------------------------+
//| Check Daily MDD                                                  |
//+------------------------------------------------------------------+
void CRiskGate::CheckDailyMDD() {
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    
    int localHour = dt.hour; // GMT+7 assumed
    
    // Reset daily tracking
    if(localHour == m_dailyResetHour && m_lastDayCheck != now) {
        ResetDailyTracking();
        m_lastDayCheck = now;
    }
    
    // Check MDD
    double currentValue = m_useEquityMDD ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
    double drawdown = m_startDayBalance - currentValue;
    double drawdownPct = (drawdown / m_startDayBalance) * 100.0;
    
    if(drawdownPct >= m_dailyMddMax) {
        m_tradingHalted = true;
        Print("⚠️ Trading HALTED: Daily MDD ", DoubleToString(drawdownPct, 2), "% >= ", DoubleToString(m_dailyMddMax, 2), "%");
    }
}

//+------------------------------------------------------------------+
//| Reset Daily Tracking                                             |
//+------------------------------------------------------------------+
void CRiskGate::ResetDailyTracking() {
    m_startDayBalance = m_useEquityMDD ? AccountInfoDouble(ACCOUNT_EQUITY) : AccountInfoDouble(ACCOUNT_BALANCE);
    m_tradingHalted = false;
    Print("📊 Daily tracking reset. Start balance: $", DoubleToString(m_startDayBalance, 2));
}

//+------------------------------------------------------------------+
//| Is Trading Halted                                                 |
//+------------------------------------------------------------------+
bool CRiskGate::IsTradingHalted() {
    return m_tradingHalted;
}

//+------------------------------------------------------------------+
//| Is Session Open                                                   |
//+------------------------------------------------------------------+
bool CRiskGate::IsSessionOpen() {
    if(!m_sessionOpen) return true; // Always open if not using session filter
    
    int localHour = GetLocalHour();
    return (localHour >= m_sessStartHour && localHour < m_sessEndHour);
}

//+------------------------------------------------------------------+
//| Get Max Lot Size (lot cap only)                                  |
//+------------------------------------------------------------------+
double CRiskGate::GetMaxLotSize() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (m_riskPct / 100.0);
    return CalculateMaxLotSize(riskAmount, 0);
}

//+------------------------------------------------------------------+
//| Get Local Hour (GMT+7)                                           |
//+------------------------------------------------------------------+
int CRiskGate::GetLocalHour() {
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    return dt.hour; // Assuming broker time is GMT+7
}

//+------------------------------------------------------------------+
//| Get ATR                                                           |
//+------------------------------------------------------------------+
double CRiskGate::GetATR() {
    if(m_atrHandle == INVALID_HANDLE) return 0;
    
    double atr[1];
    if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) <= 0) {
        return 0;
    }
    
    return atr[0];
}

//+------------------------------------------------------------------+
//| Calculate Max Lot Size (dynamic by equity)                        |
//+------------------------------------------------------------------+
double CRiskGate::CalculateMaxLotSize(double riskAmount, double maxRiskPips) {
    // Dynamic lot sizing based on equity
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double baseLot = m_lotBase;
    
    // Calculate increment based on equity
    int increments = (int)MathFloor(equity / m_equityPerLotInc);
    double dynamicLot = baseLot + (increments * m_lotIncrement);
    
    // Cap to max
    if(dynamicLot > m_lotMax) {
        dynamicLot = m_lotMax;
    }
    
    return dynamicLot;
}

//+------------------------------------------------------------------+

