//+------------------------------------------------------------------+
//|                                                 risk_manager.mqh |
//|                              Risk Management & Position Control  |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Risk Manager Class - Position sizing, DCA, MDD protection       |
//+------------------------------------------------------------------+
class CRiskManager {
private:
    string   m_symbol;
    
    // Risk parameters
    double   m_riskPerTradePct;   // % of equity per trade
    double   m_lotBase;           // Base lot size (starting)
    double   m_lotMax;            // Max lot size (cap)
    double   m_equityPerLotInc;   // Equity per lot increment
    double   m_lotIncrement;      // Lot increment per equity step
    double   m_maxLotPerSide;     // Dynamic calculated (current max lot)
    int      m_maxDcaAddons;
    double   m_dailyMddMax;       // Max daily drawdown %
    
    // DCA parameters
    double   m_dcaLevel1_R;       // +0.75R
    double   m_dcaLevel2_R;       // +1.5R
    double   m_dcaSize1_Mult;     // 0.5x
    double   m_dcaSize2_Mult;     // 0.33x
    
    // BE and Trail parameters
    double   m_beLevel_R;         // +1R for breakeven
    
    // [NEW] Feature toggles
    bool     m_enableDCA;
    bool     m_enableBE;
    bool     m_enableTrailing;
    bool     m_useDailyMDD;
    bool     m_useEquityMDD;      // Use equity instead of balance
    
    // [NEW] Dynamic lot sizing
    bool     m_useEquityBasedLot;
    double   m_maxLotPctEquity;   // % of equity for max lot
    
    // [NEW] Trailing parameters
    double   m_trailStartR;        // Start trailing at +XR
    double   m_trailStepR;         // Move SL every +XR
    double   m_trailATRMult;       // Trail distance = ATR × mult
    
    // [NEW] DCA confluence filter
    bool     m_dcaRequireConfluence;
    bool     m_dcaCheckEquity;
    double   m_dcaMinEquityPct;   // Min equity % vs start balance
    
    // Daily tracking (GMT+7)
    double   m_startDayBalance;
    double   m_initialBalance;    // Balance at 6h GMT+7
    datetime m_lastDayCheck;
    int      m_dailyResetHour;    // 6h GMT+7
    bool     m_tradingHalted;
    
    // Basket Manager
    bool     m_enableBasketTP;
    bool     m_enableBasketSL;
    double   m_basketTPPct;       // 0.3% balance
    double   m_basketSLPct;       // 1.2% balance
    int      m_endOfDayHour;      // Hour to close all (GMT+7)
    bool     m_enableEODClose;
    
    // DCA tracking per position
    struct PositionDCA {
        ulong    ticket;
        double   entryPrice;
        double   sl;            // Current SL
        double   originalSL;    // [NEW] ORIGINAL SL for R calculation (never changes)
        double   tp;
        double   originalLot;
        int      dcaCount;
        bool     movedToBE;
        bool     dca1Added;
        bool     dca2Added;
        double   lastTrailR;    // [NEW] Track last trail level to avoid too frequent updates
    };
    PositionDCA m_positions[];
    
public:
    CRiskManager();
    ~CRiskManager();
    
    bool Init(string symbol, double riskPct, double maxLotBase, int maxDCA, double dailyMDD,
              double basketTPPct, double basketSLPct, int endOfDayHour, int dailyResetHour,
              // [NEW] Add these parameters
              bool enableDCA, bool enableBE, bool enableTrailing, 
              bool useDailyMDD, bool useEquityMDD,
              bool useEquityBasedLot, double maxLotPctEquity,
              double trailStartR, double trailStepR, double trailATRMult,
              bool dcaRequireConfluence, bool dcaCheckEquity, double dcaMinEquityPct);
    
    void SetDCALevels(double level1R, double level2R, 
                      double size1Mult, double size2Mult,
                      double beLevel);
    
    void SetLotSizingParams(double lotBase, double lotMax, 
                           double equityPerLotInc, double lotIncrement);
    
    double CalcLotsByRisk(double riskPct, double slPoints);
    double GetMaxLotPerSide() { return m_maxLotPerSide; }
    double GetInitialBalance() { return m_initialBalance; }
    double GetDailyPL();
    
    bool   CheckDailyMDD();
    void   ResetDailyTracking();
    bool   IsTradingHalted() { return m_tradingHalted; }
    
    void   TrackPosition(ulong ticket, double entry, double sl, double tp, double lots);
    void   ManageOpenPositions();
    void   CheckBasketTPSL();
    void   CheckEndOfDay();
    
    // Dashboard info getters
    double GetBasketFloatingPL();
    double GetBasketFloatingPLPct();
    int    GetTotalPositions();
    
private:
    void   UpdateMaxLotPerSide();
    double GetCurrentEquity();
    int    CountSidePositions(int direction);
    double GetSideLots(int direction);
    double CalcProfitInR(ulong ticket);
    bool   MoveSLToBE(ulong ticket);
    bool   AddDCAPosition(int direction, double lots, double currentPrice);
    void   CloseAllPositions(string reason);
    int    GetLocalHour();
    
    // [NEW] Trailing stop methods
    double GetATR();
    double CalcTrailLevel(ulong ticket, double profitR);
    bool   TrailSL(ulong ticket);
    bool   CheckDCAConfluence(int direction);
    bool   CheckEquityHealth();
    double GetEffectiveMaxLot();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() {
    m_riskPerTradePct = 0.5;
    m_lotBase = 0.1;
    m_lotMax = 5.0;
    m_equityPerLotInc = 1000.0;
    m_lotIncrement = 0.1;
    m_maxLotPerSide = 0.1;
    m_maxDcaAddons = 2;
    m_dailyMddMax = 8.0;
    
    m_dcaLevel1_R = 0.75;
    m_dcaLevel2_R = 1.5;
    m_dcaSize1_Mult = 0.5;
    m_dcaSize2_Mult = 0.33;
    
    m_beLevel_R = 1.0;
    
    // [NEW] Feature toggles defaults
    m_enableDCA = true;
    m_enableBE = true;
    m_enableTrailing = true;
    m_useDailyMDD = true;
    m_useEquityMDD = false;
    
    // [NEW] Dynamic lot sizing defaults
    m_useEquityBasedLot = false;
    m_maxLotPctEquity = 10.0;
    
    // [NEW] Trailing defaults
    m_trailStartR = 1.0;
    m_trailStepR = 0.5;
    m_trailATRMult = 2.0;
    
    // [NEW] DCA filters defaults
    m_dcaRequireConfluence = false;
    m_dcaCheckEquity = true;
    m_dcaMinEquityPct = 95.0;
    
    m_dailyResetHour = 6;  // 6h GMT+7
    m_tradingHalted = false;
    m_lastDayCheck = 0;
    m_startDayBalance = 0;
    m_initialBalance = 0;
    
    m_enableBasketTP = true;
    m_enableBasketSL = true;
    m_basketTPPct = 0.3;
    m_basketSLPct = 1.2;
    m_endOfDayHour = 23;
    m_enableEODClose = false;
    
    ArrayResize(m_positions, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager() {
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                          |
//+------------------------------------------------------------------+
bool CRiskManager::Init(string symbol, double riskPct, double maxLotBase, int maxDCA, double dailyMDD,
                        double basketTPPct, double basketSLPct, int endOfDayHour, int dailyResetHour,
                        // [NEW] Add these parameters
                        bool enableDCA, bool enableBE, bool enableTrailing, 
                        bool useDailyMDD, bool useEquityMDD,
                        bool useEquityBasedLot, double maxLotPctEquity,
                        double trailStartR, double trailStepR, double trailATRMult,
                        bool dcaRequireConfluence, bool dcaCheckEquity, double dcaMinEquityPct) {
    
    m_symbol = symbol;
    m_riskPerTradePct = riskPct;
    m_lotBase = maxLotBase;  // [FIX] Correct variable name
    m_maxDcaAddons = maxDCA;
    m_dailyMddMax = dailyMDD;
    
    m_basketTPPct = basketTPPct;
    m_basketSLPct = basketSLPct;
    m_endOfDayHour = endOfDayHour;
    m_dailyResetHour = dailyResetHour;
    m_enableBasketTP = (basketTPPct > 0);
    m_enableBasketSL = (basketSLPct > 0);
    m_enableEODClose = (endOfDayHour > 0);
    
    // [NEW] Feature toggles
    m_enableDCA = enableDCA;
    m_enableBE = enableBE;
    m_enableTrailing = enableTrailing;
    m_useDailyMDD = useDailyMDD;
    m_useEquityMDD = useEquityMDD;
    
    // [NEW] Dynamic lot sizing
    m_useEquityBasedLot = useEquityBasedLot;
    m_maxLotPctEquity = maxLotPctEquity;
    
    // [NEW] Trailing parameters
    m_trailStartR = trailStartR;
    m_trailStepR = trailStepR;
    m_trailATRMult = trailATRMult;
    
    // [NEW] DCA filters
    m_dcaRequireConfluence = dcaRequireConfluence;
    m_dcaCheckEquity = dcaCheckEquity;
    m_dcaMinEquityPct = dcaMinEquityPct;
    
    ResetDailyTracking();
    return true;
}

//+------------------------------------------------------------------+
//| Set DCA Levels                                                    |
//+------------------------------------------------------------------+
void CRiskManager::SetDCALevels(double level1R, double level2R, 
                                double size1Mult, double size2Mult,
                                double beLevel) {
    m_dcaLevel1_R = level1R;
    m_dcaLevel2_R = level2R;
    m_dcaSize1_Mult = size1Mult;
    m_dcaSize2_Mult = size2Mult;
    m_beLevel_R = beLevel;
}

//+------------------------------------------------------------------+
//| Set Lot Sizing Parameters                                        |
//+------------------------------------------------------------------+
void CRiskManager::SetLotSizingParams(double lotBase, double lotMax, 
                                      double equityPerLotInc, double lotIncrement) {
    m_lotBase = lotBase;
    m_lotMax = lotMax;
    m_equityPerLotInc = equityPerLotInc;
    m_lotIncrement = lotIncrement;
    
    Print("═══════════════════════════════════════");
    Print("📊 Lot Sizing Configuration:");
    Print("   Base Lot: ", m_lotBase);
    Print("   Max Lot: ", m_lotMax);
    Print("   Equity per increment: $", m_equityPerLotInc);
    Print("   Lot increment: ", m_lotIncrement);
    Print("═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Get current equity                                               |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentEquity() {
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//| Formula: Lots = (Balance × Risk%) ÷ (SL_Pips × Value_Per_Pip)  |
//| [ENHANCED] Full diagnostic logging to debug lot = 0.01 issue    |
//+------------------------------------------------------------------+
double CRiskManager::CalcLotsByRisk(double riskPct, double slPoints) {
    // ═══════════════════════════════════════════════════════════
    // STEP 1: Get account values
    // ═══════════════════════════════════════════════════════════
    double equity = GetCurrentEquity();
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double baseValue = m_useEquityMDD ? equity : balance;
    
    Print("═══════════════════════════════════════════════════════");
    Print("🔍 ENHANCED LOT DIAGNOSTIC - START");
    Print("═══════════════════════════════════════════════════════");
    Print("STEP 1: ACCOUNT VALUES");
    Print("   Equity: $", DoubleToString(equity, 2));
    Print("   Balance: $", DoubleToString(balance, 2));
    Print("   Using: ", m_useEquityMDD ? "Equity" : "Balance");
    Print("   → BaseValue: $", DoubleToString(baseValue, 2));
    
    // [FIX] Check if balance/equity is valid
    if(baseValue <= 0) {
        Print("   ❌ CRITICAL ERROR: BaseValue <= 0!");
        Print("   Returning minLot 0.01");
        Print("═══════════════════════════════════════════════════════");
        return 0.01;
    }
    
    // ═══════════════════════════════════════════════════════════
    // STEP 2: Calculate risk amount
    // ═══════════════════════════════════════════════════════════
    double riskValue = baseValue * (riskPct / 100.0);
    
    Print("───────────────────────────────────────────────────────");
    Print("STEP 2: RISK CALCULATION");
    Print("   Risk%: ", riskPct, "%");
    Print("   Formula: $", DoubleToString(baseValue, 2), " × ", riskPct, "%");
    Print("   → Risk Amount: $", DoubleToString(riskValue, 2));
    
    if(riskValue <= 0) {
        Print("   ❌ ERROR: Risk amount <= 0!");
        Print("═══════════════════════════════════════════════════════");
        return 0.01;
    }
    
    // ═══════════════════════════════════════════════════════════
    // STEP 3: Get symbol information
    // ═══════════════════════════════════════════════════════════
    double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    double contractSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
    
    Print("───────────────────────────────────────────────────────");
    Print("STEP 3: SYMBOL INFORMATION");
    Print("   Symbol: ", m_symbol);
    Print("   _Point: ", _Point);
    Print("   _Digits: ", _Digits);
    Print("   TICK_VALUE: $", DoubleToString(tickValue, 4), " (for ? lot)");
    Print("   TICK_SIZE: ", DoubleToString(tickSize, 5));
    Print("   CONTRACT_SIZE: ", contractSize);
    Print("   VOLUME_MIN: ", minLot);
    Print("   VOLUME_MAX: ", maxLot);
    Print("   VOLUME_STEP: ", lotStep);
    Print("   SL Distance: ", (int)slPoints, " points = ", DoubleToString(slPoints/10, 1), " pips");
    
    // [FIX] Validation
    if(tickSize == 0) {
        Print("   ❌ CRITICAL ERROR: TICK_SIZE = 0!");
        Print("   Check symbol: ", m_symbol, " - May not be loaded");
        Print("═══════════════════════════════════════════════════════");
        return 0.01;
    }
    if(slPoints == 0) {
        Print("   ❌ ERROR: SL Points = 0!");
        Print("   Check SL calculation in executor");
        Print("═══════════════════════════════════════════════════════");
        return 0.01;
    }
    if(contractSize == 0) {
        Print("   ❌ WARNING: CONTRACT_SIZE = 0! Using default calculation");
    }
    
    // ═══════════════════════════════════════════════════════════
    // STEP 4: Calculate value per point per lot
    // ═══════════════════════════════════════════════════════════
    double valuePerPointPerLot = tickValue * (_Point / tickSize);
    
    Print("───────────────────────────────────────────────────────");
    Print("STEP 4: POINT VALUE CALCULATION");
    Print("   Formula: TickValue × (_Point / TickSize)");
    Print("   = $", DoubleToString(tickValue, 4), 
          " × (", _Point, " / ", DoubleToString(tickSize, 5), ")");
    Print("   = $", DoubleToString(tickValue, 4),
          " × ", DoubleToString(_Point/tickSize, 2));
    Print("   = $", DoubleToString(valuePerPointPerLot, 6), " per point per lot");
    
    // [DIAGNOSTIC] Check if value seems reasonable
    if(valuePerPointPerLot <= 0) {
        Print("   ❌ CRITICAL ERROR: Value per point <= 0!");
        Print("═══════════════════════════════════════════════════════");
        return 0.01;
    }
    if(valuePerPointPerLot < 0.001) {
        Print("   ⚠️ WARNING: Value very small (", valuePerPointPerLot, ")");
        Print("   This may cause lots to be huge - check formula!");
    }
    if(valuePerPointPerLot > 100) {
        Print("   ⚠️ WARNING: Value very large (", valuePerPointPerLot, ")");
        Print("   This may cause lots to be tiny!");
        Print("   Likely TICK_VALUE is for 1.0 lot, not 0.01 lot");
    }
    
    // ═══════════════════════════════════════════════════════════
    // STEP 5: Calculate lots
    // ═══════════════════════════════════════════════════════════
    double denominator = slPoints * valuePerPointPerLot;
    
    Print("───────────────────────────────────────────────────────");
    Print("STEP 5: LOT CALCULATION");
    Print("   Denominator = SL × ValuePerPoint");
    Print("   = ", (int)slPoints, " pts × $", DoubleToString(valuePerPointPerLot, 6));
    Print("   = $", DoubleToString(denominator, 2));
    
    if(denominator <= 0) {
        Print("   ❌ CRITICAL ERROR: Denominator <= 0!");
        Print("═══════════════════════════════════════════════════════");
        return 0.01;
    }
    
    double lotsRaw = riskValue / denominator;
    
    Print("   Raw Lots = Risk$ ÷ Denominator");
    Print("   = $", DoubleToString(riskValue, 2), " ÷ $", DoubleToString(denominator, 2));
    Print("   = ", DoubleToString(lotsRaw, 6), " lots");
    
    double lots = NormalizeDouble(lotsRaw, 2);
    Print("   Normalized (2 decimals): ", lots);
    
    // ═══════════════════════════════════════════════════════════
    // STEP 6: Apply limits
    // ═══════════════════════════════════════════════════════════
    Print("───────────────────────────────────────────────────────");
    Print("STEP 6: APPLY LIMITS");
    Print("   Broker MinLot: ", minLot);
    Print("   Broker MaxLot: ", maxLot);
    
    bool wasAdjusted = false;
    
    if(lots < minLot) {
        Print("   ⬆️ Below MinLot: ", lots, " → ", minLot);
        Print("   ⚠️⚠️⚠️ CAPPED TO MINIMUM! This means:");
        Print("      - Balance too small, OR");
        Print("      - Risk% too small, OR");
        Print("      - SL too large, OR");
        Print("      - Point value calculation WRONG");
        lots = minLot;
        wasAdjusted = true;
    }
    if(lots > maxLot) {
        Print("   ⬇️ Above Broker MaxLot: ", lots, " → ", maxLot);
        lots = maxLot;
        wasAdjusted = true;
    }
    
    Print("   Current MaxLotPerSide: ", m_maxLotPerSide, 
          " (Base: ", m_lotBase, " + Growth)");
    
    if(lots > m_maxLotPerSide) {
        Print("   ⚠️ CAPPED to MaxLotPerSide: ", lots, " → ", m_maxLotPerSide);
        lots = m_maxLotPerSide;
        wasAdjusted = true;
    }
    
    Print("───────────────────────────────────────────────────────");
    Print("   ✅ FINAL LOTS: ", lots);
    
    // [CRITICAL DIAGNOSTIC] If lot = 0.01 and raw was higher
    if(lots == minLot && lotsRaw > minLot && wasAdjusted) {
        Print("───────────────────────────────────────────────────────");
        Print("⚠️⚠️⚠️ LOT WAS CAPPED TO MINIMUM!");
        Print("   Raw calculated: ", DoubleToString(lotsRaw, 6));
        Print("   Final: ", lots);
        Print("   → Need to increase:");
        Print("      1. Risk% (current: ", riskPct, "%), OR");
        Print("      2. Balance (current: $", DoubleToString(baseValue, 2), "), OR");
        Print("      3. Decrease SL (current: ", (int)slPoints, " pts)");
        Print("   → OR check if point value calculation is WRONG!");
    }
    
    Print("═══════════════════════════════════════════════════════");
    
    return lots;
}

//+------------------------------------------------------------------+
//| Get local hour in GMT+7 timezone                                 |
//+------------------------------------------------------------------+
int CRiskManager::GetLocalHour() {
    datetime t = TimeCurrent();
    MqlDateTime s;
    TimeToStruct(t, s);
    
    // Calculate proper timezone offset: VN_GMT - Server_GMT
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    return hour_localvn;
}

//+------------------------------------------------------------------+
//| Reset daily tracking at 6h GMT+7                                |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyTracking() {
    int currentHour = GetLocalHour();
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    datetime currentDay = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    // Check if new day AND past reset hour
    if(m_lastDayCheck != currentDay) {
        if(currentHour >= m_dailyResetHour) {
            m_startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
            m_initialBalance = m_startDayBalance;
            m_lastDayCheck = currentDay;
            m_tradingHalted = false;
            
            // Update dynamic max lot
            UpdateMaxLotPerSide();
            
            Print("═══════════════════════════════════════");
            Print("DAILY RESET at ", m_dailyResetHour, "h GMT+7");
            Print("Initial Balance: $", m_initialBalance);
            Print("Max Lot Per Side: ", m_maxLotPerSide);
            Print("═══════════════════════════════════════");
        }
    }
}

//+------------------------------------------------------------------+
//| Update dynamic MaxLotPerSide based on EQUITY growth             |
//+------------------------------------------------------------------+
void CRiskManager::UpdateMaxLotPerSide() {
    double currentEquity = GetCurrentEquity();
    
    // [NEW] Calculate based on equity increments
    // Formula: MaxLot = LotBase + floor(Equity / EquityPerLotInc) * LotIncrement
    int increments = (int)MathFloor(currentEquity / m_equityPerLotInc);
    m_maxLotPerSide = m_lotBase + (increments * m_lotIncrement);
    
    // Apply cap
    if(m_maxLotPerSide > m_lotMax) {
        m_maxLotPerSide = m_lotMax;
    }
    
    // Ensure minimum
    if(m_maxLotPerSide < m_lotBase) {
        m_maxLotPerSide = m_lotBase;
    }
    
    // [DEBUG] Log when maxLot changes
    static double lastMaxLot = 0;
    if(m_maxLotPerSide != lastMaxLot) {
        Print("📈 MaxLotPerSide updated: ", lastMaxLot, " → ", m_maxLotPerSide, 
              " (Equity: $", DoubleToString(currentEquity, 2), 
              ", Increments: ", increments, ")");
        lastMaxLot = m_maxLotPerSide;
    }
}

//+------------------------------------------------------------------+
//| Get daily P/L percentage                                         |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyPL() {
    // [FIX] Prevent divide by zero
    if(m_startDayBalance <= 0) {
        m_startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        if(m_startDayBalance <= 0) return 0;
    }
    
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double pl = ((currentBalance - m_startDayBalance) / m_startDayBalance) * 100.0;
    
    return pl;
}

//+------------------------------------------------------------------+
//| Check daily MDD and halt trading if exceeded                     |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyMDD() {
    // [NEW] Can be disabled
    if(!m_useDailyMDD) return true;
    
    ResetDailyTracking(); // Check if new day
    
    if(m_tradingHalted) return false;
    
    // [CHANGE] Use equity or balance based on setting
    double current = m_useEquityMDD ? GetCurrentEquity() : AccountInfoDouble(ACCOUNT_BALANCE);
    double start = m_useEquityMDD ? m_startDayBalance : m_startDayBalance;
    
    // [FIX] Prevent divide by zero
    if(start <= 0) {
        start = AccountInfoDouble(ACCOUNT_BALANCE);
        m_startDayBalance = start;
        if(start <= 0) return true; // Cannot calculate, allow trading
    }
    
    double dailyPL = ((current - start) / start) * 100.0;
    
    if(dailyPL <= -m_dailyMddMax) {
        Print("═══════════════════════════════════════");
        Print("⚠️ DAILY MDD EXCEEDED: ", DoubleToString(dailyPL, 2), "%");
        Print("   Start: $", DoubleToString(start, 2));
        Print("   Current: $", DoubleToString(current, 2));
        Print("   Loss: $", DoubleToString(current - start, 2));
        Print("═══════════════════════════════════════");
        Print("🛑 CLOSING ALL POSITIONS AND HALTING TRADING");
        Print("═══════════════════════════════════════");
        
        m_tradingHalted = true;
        
        // Close all positions
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)) {
                if(PositionGetString(POSITION_SYMBOL) == m_symbol) {
                    MqlTradeRequest request;
                    MqlTradeResult result;
                    ZeroMemory(request);
                    ZeroMemory(result);
                    
                    request.action = TRADE_ACTION_DEAL;
                    request.position = ticket;
                    request.symbol = m_symbol;
                    request.volume = PositionGetDouble(POSITION_VOLUME);
                    request.deviation = 20;
                    
                    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                        request.type = ORDER_TYPE_SELL;
                        request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                    } else {
                        request.type = ORDER_TYPE_BUY;
                        request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
                    }
                    
                    if(!OrderSend(request, result)) {
                        Print("❌ Failed to close position on MDD: ", result.retcode);
                    } else {
                        Print("✅ Closed position #", ticket);
                    }
                }
            }
        }
        
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Count positions in specified direction                           |
//+------------------------------------------------------------------+
int CRiskManager::CountSidePositions(int direction) {
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == m_symbol) {
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            if((direction == 1 && posType == POSITION_TYPE_BUY) ||
               (direction == -1 && posType == POSITION_TYPE_SELL)) {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Get total lots in specified direction                            |
//+------------------------------------------------------------------+
double CRiskManager::GetSideLots(int direction) {
    double totalLots = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == m_symbol) {
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            if((direction == 1 && posType == POSITION_TYPE_BUY) ||
               (direction == -1 && posType == POSITION_TYPE_SELL)) {
                totalLots += PositionGetDouble(POSITION_VOLUME);
            }
        }
    }
    return totalLots;
}

//+------------------------------------------------------------------+
//| Track new position for DCA/BE management                         |
//+------------------------------------------------------------------+
void CRiskManager::TrackPosition(ulong ticket, double entry, double sl, double tp, double lots) {
    // [FIX] Check if already tracking this position
    for(int i = 0; i < ArraySize(m_positions); i++) {
        if(m_positions[i].ticket == ticket) {
            // Already tracked, skip
            return;
        }
    }
    
    int size = ArraySize(m_positions);
    ArrayResize(m_positions, size + 1);
    
    m_positions[size].ticket = ticket;
    m_positions[size].entryPrice = entry;
    m_positions[size].sl = sl;
    m_positions[size].originalSL = sl;     // [FIX] Save ORIGINAL SL (never changes)
    m_positions[size].tp = tp;
    m_positions[size].originalLot = lots;
    m_positions[size].dcaCount = 0;
    m_positions[size].movedToBE = false;
    m_positions[size].dca1Added = false;
    m_positions[size].dca2Added = false;
    m_positions[size].lastTrailR = 0.0;  // [NEW] Initialize trailing tracker
    
    // [DEBUG] Log ORIGINAL SL for verification
    double initialRisk = MathAbs(entry - sl) / _Point;
    Print("📊 Tracking position #", ticket, 
          " | Lots: ", lots, 
          " | Entry: ", entry,
          " | ORIGINAL SL: ", sl, 
          " | Initial Risk: ", (int)initialRisk, " pts",
          " | TP: ", tp);
}

//+------------------------------------------------------------------+
//| Get ATR value for trailing calculation                          |
//+------------------------------------------------------------------+
double CRiskManager::GetATR() {
    int atrHandle = iATR(m_symbol, PERIOD_CURRENT, 14);
    if(atrHandle == INVALID_HANDLE) return 0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(atrHandle, 0, 0, 2, atr) > 0) {
        IndicatorRelease(atrHandle);
        return atr[0];
    }
    
    IndicatorRelease(atrHandle);
    return 0;
}

//+------------------------------------------------------------------+
//| Calculate trailing stop level                                    |
//+------------------------------------------------------------------+
double CRiskManager::CalcTrailLevel(ulong ticket, double profitR) {
    if(!PositionSelectByTicket(ticket)) return 0;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    int posType = (int)PositionGetInteger(POSITION_TYPE);
    
    double atr = GetATR();
    if(atr == 0) return currentSL; // Keep current if can't get ATR
    
    double trailDistance = atr * m_trailATRMult;
    double newSL = currentSL;
    
    if(posType == POSITION_TYPE_BUY) {
        // Trail up: newSL = currentPrice - trailDistance
        double candidateSL = currentPrice - trailDistance;
        if(candidateSL > currentSL) {
            newSL = candidateSL;
        }
    } else {
        // Trail down: newSL = currentPrice + trailDistance
        double candidateSL = currentPrice + trailDistance;
        if(candidateSL < currentSL) {
            newSL = candidateSL;
        }
    }
    
    return NormalizeDouble(newSL, _Digits);
}

//+------------------------------------------------------------------+
//| Move SL using trailing logic                                     |
//+------------------------------------------------------------------+
bool CRiskManager::TrailSL(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    double profitR = CalcProfitInR(ticket);
    
    // Only trail if profit >= trail start level
    if(profitR < m_trailStartR) return false;
    
    double newSL = CalcTrailLevel(ticket, profitR);
    double currentSL = PositionGetDouble(POSITION_SL);
    double tp = PositionGetDouble(POSITION_TP);
    int posType = (int)PositionGetInteger(POSITION_TYPE);
    int direction = (posType == POSITION_TYPE_BUY) ? 1 : -1;
    
    // Check if newSL is better than current
    bool shouldUpdate = false;
    if(posType == POSITION_TYPE_BUY && newSL > currentSL) {
        shouldUpdate = true;
    } else if(posType == POSITION_TYPE_SELL && newSL < currentSL) {
        shouldUpdate = true;
    }
    
    if(!shouldUpdate) return false;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = m_symbol;
    request.sl = newSL;
    request.tp = tp;
    
    if(OrderSend(request, result)) {
        double pointsMoved = MathAbs(newSL - currentSL) / _Point;
        Print("📈 Trailing SL: #", ticket, 
              " | New SL: ", newSL, 
              " | Moved: ", (int)pointsMoved, " pts",
              " | Profit: ", DoubleToString(profitR, 2), "R");
        
        // [FIX] Update ALL positions in same direction (including DCA) with same SL
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong otherTicket = PositionGetTicket(i);
            if(otherTicket == ticket) continue; // Skip original position
            if(!PositionSelectByTicket(otherTicket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
            
            int otherType = (int)PositionGetInteger(POSITION_TYPE);
            if((direction == 1 && otherType == POSITION_TYPE_BUY) ||
               (direction == -1 && otherType == POSITION_TYPE_SELL)) {
                
                double otherTP = PositionGetDouble(POSITION_TP);
                double otherCurrentSL = PositionGetDouble(POSITION_SL);
                
                // Only update if new SL is better than current SL of DCA position
                bool shouldUpdateDCA = false;
                if(direction == 1 && newSL > otherCurrentSL) shouldUpdateDCA = true;
                if(direction == -1 && newSL < otherCurrentSL) shouldUpdateDCA = true;
                
                if(shouldUpdateDCA) {
                    MqlTradeRequest req2;
                    MqlTradeResult res2;
                    ZeroMemory(req2);
                    ZeroMemory(res2);
                    
                    req2.action = TRADE_ACTION_SLTP;
                    req2.position = otherTicket;
                    req2.symbol = m_symbol;
                    req2.sl = newSL; // Use same SL for all positions
                    req2.tp = otherTP;
                    
                    if(OrderSend(req2, res2)) {
                        Print("   📈 DCA position #", otherTicket, " SL also trailed to ", newSL);
                    }
                }
            }
        }
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if should add DCA based on confluence                      |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDCAConfluence(int direction) {
    // [NEW] Optional confluence check
    if(!m_dcaRequireConfluence) return true; // Skip check if disabled
    
    // TODO: Hook into detector to check for new BOS/FVG/OB
    // For now, return true (will be implemented in integration)
    // This requires passing detector instance to RiskManager
    
    return true; // Placeholder
}

//+------------------------------------------------------------------+
//| Check equity health before DCA                                   |
//+------------------------------------------------------------------+
bool CRiskManager::CheckEquityHealth() {
    if(!m_dcaCheckEquity) return true; // Skip if disabled
    
    double currentEquity = GetCurrentEquity();
    // [FIX] Handle zero start balance
    if(m_startDayBalance <= 0) {
        m_startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    }
    double minEquity = m_startDayBalance * (m_dcaMinEquityPct / 100.0);
    
    if(currentEquity < minEquity) {
        Print("⚠️ DCA Blocked: Equity $", DoubleToString(currentEquity, 2),
              " < ", DoubleToString(m_dcaMinEquityPct, 0), "% of start ($", 
              DoubleToString(minEquity, 2), ")");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Get effective max lot (dynamic or static)                        |
//+------------------------------------------------------------------+
double CRiskManager::GetEffectiveMaxLot() {
    if(!m_useEquityBasedLot) return m_maxLotPerSide;
    
    double equity = GetCurrentEquity();
    double tickValuePerLot = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double contractSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_CONTRACT_SIZE);
    double currentPrice = (SymbolInfoDouble(m_symbol, SYMBOL_BID) + 
                          SymbolInfoDouble(m_symbol, SYMBOL_ASK)) / 2.0;
    
    double maxExposure = equity * (m_maxLotPctEquity / 100.0);
    // [FIX] Prevent divide by zero
    double denominator = contractSize * currentPrice / 100.0;
    if(denominator <= 0) return m_maxLotPerSide; // Fallback to static
    
    double dynamicMax = maxExposure / denominator;
    dynamicMax = NormalizeDouble(dynamicMax, 2);
    
    return MathMin(dynamicMax, m_maxLotPerSide);
}

//+------------------------------------------------------------------+
//| Calculate profit in R (risk units)                               |
//| [CRITICAL FIX] Dùng ORIGINAL SL để tính R, không dùng current SL |
//+------------------------------------------------------------------+
double CRiskManager::CalcProfitInR(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return 0;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    int posType = (int)PositionGetInteger(POSITION_TYPE);
    
    // [CRITICAL FIX] Tìm ORIGINAL SL từ tracked positions
    // Vấn đề: Nếu dùng current SL, sau khi BE/Trail thì risk thay đổi
    // → profitR tính sai → DCA không trigger!
    double originalSL = 0;
    bool foundTracked = false;
    
    for(int i = 0; i < ArraySize(m_positions); i++) {
        if(m_positions[i].ticket == ticket) {
            originalSL = m_positions[i].originalSL;  // [FIX] Use stored ORIGINAL SL
            foundTracked = true;
            break;
        }
    }
    
    // Nếu không tìm thấy trong tracked array (orphan DCA)
    // → Dùng current SL làm "best effort"
    if(!foundTracked) {
        originalSL = PositionGetDouble(POSITION_SL);
        // NOTE: Orphan DCA sẽ có profitR based on current SL
        // Đây là acceptable vì orphan thường đã có profit
    }
    
    double risk = 0;
    double profit = 0;
    
    if(posType == POSITION_TYPE_BUY) {
        risk = openPrice - originalSL;      // [FIX] Use ORIGINAL SL (immutable)
        profit = currentPrice - openPrice;
    } else {
        risk = originalSL - openPrice;      // [FIX] Use ORIGINAL SL (immutable)
        profit = openPrice - currentPrice;
    }
    
    // [DEBUG] Log calculation để debug DCA trigger
    static datetime lastDebugLog = 0;
    if(TimeCurrent() - lastDebugLog > 10 && profit > 0) {  // Log mỗi 10s khi có profit
        lastDebugLog = TimeCurrent();
        double currentSL = PositionGetDouble(POSITION_SL);
        Print("🔍 Profit in R - Ticket #", ticket, 
              " | Entry: ", openPrice,
              " | Current: ", currentPrice,
              " | Original SL: ", originalSL,
              " | Current SL: ", currentSL,
              " | Risk: ", (int)(risk/_Point), " pts",
              " | Profit: ", (int)(profit/_Point), " pts",
              " | R = ", DoubleToString(profit/risk, 2), "R");
    }
    
    if(risk <= 0) return 0;
    
    return profit / risk;
}

//+------------------------------------------------------------------+
//| Move stop loss to breakeven                                      |
//+------------------------------------------------------------------+
bool CRiskManager::MoveSLToBE(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    double tp = PositionGetDouble(POSITION_TP);
    int posType = (int)PositionGetInteger(POSITION_TYPE);
    int direction = (posType == POSITION_TYPE_BUY) ? 1 : -1;
    
    // Check if already at BE or better
    if(posType == POSITION_TYPE_BUY && currentSL >= openPrice) return true;
    if(posType == POSITION_TYPE_SELL && currentSL <= openPrice) return true;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = m_symbol;
    request.sl = NormalizeDouble(openPrice, _Digits);
    request.tp = tp;
    
    if(OrderSend(request, result)) {
        Print("✅ Position #", ticket, " moved to breakeven");
        
        // [FIX] Update ALL positions in same direction (including DCA)
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong otherTicket = PositionGetTicket(i);
            if(otherTicket == ticket) continue; // Skip original position
            if(!PositionSelectByTicket(otherTicket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
            
            int otherType = (int)PositionGetInteger(POSITION_TYPE);
            if((direction == 1 && otherType == POSITION_TYPE_BUY) ||
               (direction == -1 && otherType == POSITION_TYPE_SELL)) {
                
                double otherTP = PositionGetDouble(POSITION_TP);
                double otherOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                
                MqlTradeRequest req2;
                MqlTradeResult res2;
                ZeroMemory(req2);
                ZeroMemory(res2);
                
                req2.action = TRADE_ACTION_SLTP;
                req2.position = otherTicket;
                req2.symbol = m_symbol;
                req2.sl = NormalizeDouble(otherOpenPrice, _Digits); // Move to its own BE
                req2.tp = otherTP;
                
                if(OrderSend(req2, res2)) {
                    Print("   ✅ DCA position #", otherTicket, " also moved to BE");
                }
            }
        }
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Add DCA position                                                  |
//+------------------------------------------------------------------+
bool CRiskManager::AddDCAPosition(int direction, double lots, double currentPrice) {
    // Check if we can add more lots
    double currentLots = GetSideLots(direction);
    if(currentLots + lots > m_maxLotPerSide) {
        // Don't spam log here - caller will log once
        return false;
    }
    
    // [FIX] Get SL/TP from existing position in same direction
    double sl = 0;
    double tp = 0;
    bool foundReference = false;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == m_symbol) {
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            if((direction == 1 && posType == POSITION_TYPE_BUY) ||
               (direction == -1 && posType == POSITION_TYPE_SELL)) {
                sl = PositionGetDouble(POSITION_SL);
                tp = PositionGetDouble(POSITION_TP);
                foundReference = true;
                break;
            }
        }
    }
    
    if(!foundReference) {
        Print("❌ DCA failed: No reference position found");
        return false;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = m_symbol;
    request.volume = NormalizeDouble(lots, 2);
    request.deviation = 20;
    request.magic = 20251013;
    request.comment = "DCA Add-on";
    request.sl = sl;  // [FIX] Copy SL from original position
    request.tp = tp;  // [FIX] Copy TP from original position
    
    if(direction == 1) {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    } else {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
    
    if(OrderSend(request, result)) {
        // Success - log details
        Print("✅ DCA position opened: ", lots, " lots | SL: ", sl, " | TP: ", tp);
        return true;
    }
    
    // Failed - log error details
    Print("⚠ DCA OrderSend failed: ", result.retcode, " - ", result.comment);
    return false;
}

//+------------------------------------------------------------------+
//| Get basket floating P/L in dollars                               |
//+------------------------------------------------------------------+
double CRiskManager::GetBasketFloatingPL() {
    double totalPL = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == m_symbol) {
            totalPL += PositionGetDouble(POSITION_PROFIT);
        }
    }
    return totalPL;
}

//+------------------------------------------------------------------+
//| Get basket floating P/L in % of balance                         |
//+------------------------------------------------------------------+
double CRiskManager::GetBasketFloatingPLPct() {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(balance <= 0) return 0;
    
    double pl = GetBasketFloatingPL();
    return (pl / balance) * 100.0;
}

//+------------------------------------------------------------------+
//| Get total positions count                                        |
//+------------------------------------------------------------------+
int CRiskManager::GetTotalPositions() {
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetSymbol(i) == m_symbol) {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Close all positions with reason                                  |
//+------------------------------------------------------------------+
void CRiskManager::CloseAllPositions(string reason) {
    Print("═══════════════════════════════════════");
    Print("CLOSING ALL POSITIONS: ", reason);
    Print("═══════════════════════════════════════");
    
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol) {
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);
                
                request.action = TRADE_ACTION_DEAL;
                request.position = ticket;
                request.symbol = m_symbol;
                request.volume = PositionGetDouble(POSITION_VOLUME);
                request.deviation = 20;
                
                if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                    request.type = ORDER_TYPE_SELL;
                    request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                } else {
                    request.type = ORDER_TYPE_BUY;
                    request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
                }
                
                if(!OrderSend(request, result)) {
                    Print("Failed to close position ", ticket, ": ", result.retcode);
                } else {
                    Print("Closed position ", ticket, " - Reason: ", reason);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check basket TP/SL based on %Balance                            |
//+------------------------------------------------------------------+
void CRiskManager::CheckBasketTPSL() {
    double plPct = GetBasketFloatingPLPct();
    
    // Check Basket TP
    if(m_enableBasketTP && plPct >= m_basketTPPct) {
        Print("Basket TP Hit: ", plPct, "% (Target: ", m_basketTPPct, "%)");
        CloseAllPositions(StringFormat("Basket TP %.2f%%", plPct));
        return;
    }
    
    // Check Basket SL
    if(m_enableBasketSL && plPct <= -m_basketSLPct) {
        Print("Basket SL Hit: ", plPct, "% (Limit: -", m_basketSLPct, "%)");
        CloseAllPositions(StringFormat("Basket SL %.2f%%", plPct));
        return;
    }
}

//+------------------------------------------------------------------+
//| Check and close all positions at end of day                     |
//+------------------------------------------------------------------+
void CRiskManager::CheckEndOfDay() {
    if(!m_enableEODClose) return;
    
    int currentHour = GetLocalHour();
    
    if(currentHour >= m_endOfDayHour) {
        int positions = GetTotalPositions();
        if(positions > 0) {
            CloseAllPositions(StringFormat("End of Day - %dh GMT+7", m_endOfDayHour));
        }
    }
}

//+------------------------------------------------------------------+
//| Manage open positions - BE, Trail, DCA                           |
//+------------------------------------------------------------------+
void CRiskManager::ManageOpenPositions() {
    // Check daily tracking and update dynamic lot
    ResetDailyTracking();
    UpdateMaxLotPerSide();
    
    // Check basket TP/SL
    CheckBasketTPSL();
    
    // Check end of day
    CheckEndOfDay();
    
    // Check daily MDD
    if(!CheckDailyMDD()) return;
    
    // ═══════════════════════════════════════════════════════════════
    // PART 1: Manage TRACKED positions (ORIGINAL positions)
    // ═══════════════════════════════════════════════════════════════
    for(int i = ArraySize(m_positions) - 1; i >= 0; i--) {
        ulong ticket = m_positions[i].ticket;
        
        // Check if position still exists
        if(!PositionSelectByTicket(ticket)) {
            ArrayRemove(m_positions, i, 1);
            continue;
        }
        
        // Calculate profit in R
        double profitR = CalcProfitInR(ticket);
        int posType = (int)PositionGetInteger(POSITION_TYPE);
        int direction = (posType == POSITION_TYPE_BUY) ? 1 : -1;
        
        // === [NEW] TRAILING STOP (Always active if enabled) ===
        if(m_enableTrailing) {
            if(profitR >= m_trailStartR) {
                // Check if should move SL based on step
                double lastTrailR = m_positions[i].lastTrailR;
                if(profitR >= lastTrailR + m_trailStepR) {
                    if(TrailSL(ticket)) {
                        m_positions[i].lastTrailR = profitR;
                    }
                }
            }
        }
        
        // === BREAKEVEN (if enabled) ===
        if(m_enableBE) {
            if(profitR >= m_beLevel_R && !m_positions[i].movedToBE) {
                if(MoveSLToBE(ticket)) {
                    m_positions[i].movedToBE = true;
                    Print("🎯 Breakeven: #", ticket, " at +", DoubleToString(profitR, 2), "R");
                }
            }
        }
        
        // === DCA (if enabled) ===
        if(m_enableDCA) {
            // [NEW] Check equity health before DCA
            if(!CheckEquityHealth()) continue;
            
            // [NEW] Check confluence if required
            if(!CheckDCAConfluence(direction)) continue;
            
            // DCA Add-on #1 at configured level
            if(profitR >= m_dcaLevel1_R && !m_positions[i].dca1Added && 
               m_positions[i].dcaCount < m_maxDcaAddons) {
                
                double addLots = m_positions[i].originalLot * m_dcaSize1_Mult;
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                
                // Check total lot limit
                if(GetSideLots(direction) + addLots <= GetEffectiveMaxLot()) {
                    if(AddDCAPosition(direction, addLots, currentPrice)) {
                        m_positions[i].dca1Added = true;
                        m_positions[i].dcaCount++;
                        Print("➕ DCA #1: ", addLots, " lots at +", 
                              DoubleToString(profitR, 2), "R");
                    }
                } else {
                    m_positions[i].dca1Added = true;
                    Print("✗ DCA #1 skipped: would exceed MaxLot");
                }
            }
            
            // DCA Add-on #2 at configured level
            if(profitR >= m_dcaLevel2_R && !m_positions[i].dca2Added && 
               m_positions[i].dcaCount < m_maxDcaAddons) {
                
                double addLots = m_positions[i].originalLot * m_dcaSize2_Mult;
                double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
                
                if(GetSideLots(direction) + addLots <= GetEffectiveMaxLot()) {
                    if(AddDCAPosition(direction, addLots, currentPrice)) {
                        m_positions[i].dca2Added = true;
                        m_positions[i].dcaCount++;
                        Print("➕ DCA #2: ", addLots, " lots at +", 
                              DoubleToString(profitR, 2), "R");
                    }
                } else {
                    m_positions[i].dca2Added = true;
                    Print("✗ DCA #2 skipped: would exceed MaxLot");
                }
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PART 2: Manage ORPHANED DCA positions (khi original đã close)
    // ═══════════════════════════════════════════════════════════════
    // [FIX] Nếu có positions còn lại nhưng KHÔNG có trong tracked array
    // → Đây là DCA positions mồ côi → Vẫn cần trail/manage
    
    static datetime lastOrphanCheck = 0;
    datetime currentTime = TimeCurrent();
    
    // Check orphan positions mỗi 5 giây để tránh spam
    if(currentTime - lastOrphanCheck >= 5) {
        lastOrphanCheck = currentTime;
        
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetString(POSITION_SYMBOL) != m_symbol) continue;
            
            // Check if this position is already tracked
            bool isTracked = false;
            for(int j = 0; j < ArraySize(m_positions); j++) {
                if(m_positions[j].ticket == ticket) {
                    isTracked = true;
                    break;
                }
            }
            
            // Nếu KHÔNG tracked → Đây là orphan (DCA without original)
            if(!isTracked) {
                string comment = PositionGetString(POSITION_COMMENT);
                
                // Confirm đây là DCA position
                if(StringFind(comment, "DCA Add-on") >= 0) {
                    double profitR = CalcProfitInR(ticket);
                    int posType = (int)PositionGetInteger(POSITION_TYPE);
                    int direction = (posType == POSITION_TYPE_BUY) ? 1 : -1;
                    
                    // === TRAILING for ORPHAN DCA ===
                    if(m_enableTrailing && profitR >= m_trailStartR) {
                        // Simple trail without step tracking (vì không có struct)
                        double currentSL = PositionGetDouble(POSITION_SL);
                        double newSL = CalcTrailLevel(ticket, profitR);
                        
                        bool shouldUpdate = false;
                        if(posType == POSITION_TYPE_BUY && newSL > currentSL) {
                            shouldUpdate = true;
                        } else if(posType == POSITION_TYPE_SELL && newSL < currentSL) {
                            shouldUpdate = true;
                        }
                        
                        if(shouldUpdate) {
                            MqlTradeRequest req;
                            MqlTradeResult res;
                            ZeroMemory(req);
                            ZeroMemory(res);
                            
                            req.action = TRADE_ACTION_SLTP;
                            req.position = ticket;
                            req.symbol = m_symbol;
                            req.sl = newSL;
                            req.tp = PositionGetDouble(POSITION_TP);
                            
                            if(OrderSend(req, res)) {
                                double pointsMoved = MathAbs(newSL - currentSL) / _Point;
                                Print("📈 Orphan DCA Trailing: #", ticket, 
                                      " | New SL: ", newSL,
                                      " | Moved: ", (int)pointsMoved, " pts",
                                      " | Profit: ", DoubleToString(profitR, 2), "R");
                            }
                        }
                    }
                    
                    // === BREAKEVEN for ORPHAN DCA ===
                    if(m_enableBE && profitR >= m_beLevel_R) {
                        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                        double currentSL = PositionGetDouble(POSITION_SL);
                        
                        // Check if not at BE yet
                        bool needsBE = false;
                        if(posType == POSITION_TYPE_BUY && currentSL < openPrice) {
                            needsBE = true;
                        } else if(posType == POSITION_TYPE_SELL && currentSL > openPrice) {
                            needsBE = true;
                        }
                        
                        if(needsBE) {
                            MqlTradeRequest req;
                            MqlTradeResult res;
                            ZeroMemory(req);
                            ZeroMemory(res);
                            
                            req.action = TRADE_ACTION_SLTP;
                            req.position = ticket;
                            req.symbol = m_symbol;
                            req.sl = NormalizeDouble(openPrice, _Digits);
                            req.tp = PositionGetDouble(POSITION_TP);
                            
                            if(OrderSend(req, res)) {
                                Print("🎯 Orphan DCA Breakeven: #", ticket, " at +", 
                                      DoubleToString(profitR, 2), "R");
                            }
                        }
                    }
                }
            }
        }
    }
}

