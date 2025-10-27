//+------------------------------------------------------------------+
//|                                                 risk_manager.mqh |
//|                   Risk Management - DCA, BE, Trailing, MDD       |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

//+------------------------------------------------------------------+
//| Position Tracking Structure                                      |
//+------------------------------------------------------------------+
struct PositionDCA {
    ulong    ticket;
    double   entryPrice;
    double   sl;              // Current SL (can change)
    double   originalSL;      // Original SL (NEVER changes for R calc)
    double   tp;
    double   originalLot;
    int      direction;       // 1=BUY, -1=SELL
    int      dcaCount;
    bool     movedToBE;
    bool     dca1Added;
    bool     dca2Added;
    double   lastTrailR;
};

//+------------------------------------------------------------------+
//| CRiskManager Class                                                |
//+------------------------------------------------------------------+
class CRiskManager {
private:
    string   m_symbol;
    
    // Lot sizing
    double   m_lotBase;
    double   m_lotMax;
    double   m_equityPerLotInc;
    double   m_lotIncrement;
    
    // DCA parameters
    bool     m_enableDCA;
    double   m_dcaLevel1_R;
    double   m_dcaLevel2_R;
    double   m_dcaSize1_Mult;
    double   m_dcaSize2_Mult;
    int      m_maxDcaAddons;
    bool     m_dcaCheckEquity;
    double   m_dcaMinEquityPct;
    
    // Breakeven
    bool     m_enableBE;
    double   m_beLevel_R;
    
    // Trailing
    bool     m_enableTrailing;
    double   m_trailStartR;
    double   m_trailStepR;
    double   m_trailATRMult;
    int      m_atrHandle;
    
    // Daily MDD
    bool     m_useDailyMDD;
    double   m_dailyMddMax;
    bool     m_useEquityMDD;
    int      m_dailyResetHour;
    double   m_startDayBalance;
    bool     m_tradingHalted;
    datetime m_lastDayCheck;
    
    // Basket
    double   m_basketTPPct;
    double   m_basketSLPct;
    
    // Position tracking
    PositionDCA m_positions[];
    
public:
    CRiskManager();
    ~CRiskManager();
    
    bool Init(string symbol,
              double lotBase, double lotMax, double equityPerLotInc, double lotIncrement,
              bool enableDCA, double dcaLevel1_R, double dcaLevel2_R,
              double dcaSize1_Mult, double dcaSize2_Mult, int maxDcaAddons,
              bool dcaCheckEquity, double dcaMinEquityPct,
              bool enableBE, double beLevel_R,
              bool enableTrailing, double trailStartR, double trailStepR, double trailATRMult,
              bool useDailyMDD, double dailyMddMax, bool useEquityMDD, int dailyResetHour,
              double basketTPPct, double basketSLPct);
    
    // Lot calculation
    double CalcLotsByRisk(double riskPct, double slPoints);
    double GetMaxLotPerSide();
    void UpdateMaxLotPerSide();
    
    // Position management
    void TrackPosition(ulong ticket, double entry, double sl, double tp, double lots);
    void ManageOpenPositions();
    double CalcProfitInR(ulong ticket);
    
    // DCA
    bool AddDCAPosition(int direction, double lots);
    bool CheckEquityHealth();
    
    // Breakeven & Trailing
    bool MoveSLToBE(ulong ticket);
    bool TrailSL(ulong ticket);
    bool UpdateSL(ulong ticket, double newSL);
    
    // Daily MDD
    bool CheckDailyMDD();
    void ResetDailyTracking();
    bool IsTradingHalted() { return m_tradingHalted; }
    
    // Basket
    void CheckBasketTPSL();
    double GetBasketFloatingPL();
    double GetBasketFloatingPLPct();
    void CloseAllPositions(string reason);
    
    // Helpers
    double GetATR();
    double GetCurrentEquity();
    double GetSideLots(int direction);
    int GetPositionDirection(ulong ticket);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() {
    m_atrHandle = INVALID_HANDLE;
    m_tradingHalted = false;
    m_startDayBalance = 0;
    m_lastDayCheck = 0;
    ArrayResize(m_positions, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CRiskManager::~CRiskManager() {
    if(m_atrHandle != INVALID_HANDLE) {
        IndicatorRelease(m_atrHandle);
    }
}

//+------------------------------------------------------------------+
//| Initialize risk manager                                          |
//+------------------------------------------------------------------+
bool CRiskManager::Init(string symbol,
                        double lotBase, double lotMax, double equityPerLotInc, double lotIncrement,
                        bool enableDCA, double dcaLevel1_R, double dcaLevel2_R,
                        double dcaSize1_Mult, double dcaSize2_Mult, int maxDcaAddons,
                        bool dcaCheckEquity, double dcaMinEquityPct,
                        bool enableBE, double beLevel_R,
                        bool enableTrailing, double trailStartR, double trailStepR, double trailATRMult,
                        bool useDailyMDD, double dailyMddMax, bool useEquityMDD, int dailyResetHour,
                        double basketTPPct, double basketSLPct) {
    
    m_symbol = symbol;
    
    // Lot sizing
    m_lotBase = lotBase;
    m_lotMax = lotMax;
    m_equityPerLotInc = equityPerLotInc;
    m_lotIncrement = lotIncrement;
    
    // DCA
    m_enableDCA = enableDCA;
    m_dcaLevel1_R = dcaLevel1_R;
    m_dcaLevel2_R = dcaLevel2_R;
    m_dcaSize1_Mult = dcaSize1_Mult;
    m_dcaSize2_Mult = dcaSize2_Mult;
    m_maxDcaAddons = maxDcaAddons;
    m_dcaCheckEquity = dcaCheckEquity;
    m_dcaMinEquityPct = dcaMinEquityPct;
    
    // Breakeven
    m_enableBE = enableBE;
    m_beLevel_R = beLevel_R;
    
    // Trailing
    m_enableTrailing = enableTrailing;
    m_trailStartR = trailStartR;
    m_trailStepR = trailStepR;
    m_trailATRMult = trailATRMult;
    
    // Daily MDD
    m_useDailyMDD = useDailyMDD;
    m_dailyMddMax = dailyMddMax;
    m_useEquityMDD = useEquityMDD;
    m_dailyResetHour = dailyResetHour;
    m_startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    // Basket
    m_basketTPPct = basketTPPct;
    m_basketSLPct = basketSLPct;
    
    // Create ATR handle
    m_atrHandle = iATR(m_symbol, PERIOD_CURRENT, 14);
    if(m_atrHandle == INVALID_HANDLE) {
        Print("❌ CRiskManager: Failed to create ATR handle");
        return false;
    }
    
    Print("✅ CRiskManager initialized");
    Print("   DCA: ", m_enableDCA ? "ON" : "OFF", 
          " | BE: ", m_enableBE ? "ON" : "OFF",
          " | Trail: ", m_enableTrailing ? "ON" : "OFF");
    Print("   Daily MDD: ", m_useDailyMDD ? "ON" : "OFF", " (", m_dailyMddMax, "%)");
    
    return true;
}

//+------------------------------------------------------------------+
//| Calculate lots by risk percentage                                |
//+------------------------------------------------------------------+
double CRiskManager::CalcLotsByRisk(double riskPct, double slPoints) {
    double equity = GetCurrentEquity();
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double baseValue = m_useEquityMDD ? equity : balance;
    
    // Calculate risk amount
    double riskValue = baseValue * (riskPct / 100.0);
    
    // Get symbol info
    double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    
    // Calculate value per point per lot
    double valuePerPoint = tickValue * (_Point / tickSize);
    
    // Calculate lots
    double denominator = slPoints * valuePerPoint;
    if(denominator <= 0) return 0;
    
    double lotsRaw = riskValue / denominator;
    double lots = NormalizeDouble(lotsRaw, 2);
    
    // DEBUG LOGS
    Print("═══════════════════════════════════════");
    Print("💰 LOT CALCULATION:");
    Print("   Balance: $", DoubleToString(balance, 2));
    Print("   Risk %: ", riskPct, "% = $", DoubleToString(riskValue, 2));
    Print("   SL Points: ", (int)slPoints, " (", (int)(slPoints/10), " pips)");
    Print("   Tick Value: $", DoubleToString(tickValue, 2));
    Print("   Tick Size: ", DoubleToString(tickSize, 5));
    Print("   _Point: ", DoubleToString(_Point, 5));
    Print("   Value/Point: $", DoubleToString(valuePerPoint, 4));
    Print("   Risk Value: $", DoubleToString(riskValue, 2));
    Print("   Denominator: ", DoubleToString(denominator, 2));
    Print("   Lots Raw: ", DoubleToString(lotsRaw, 4));
    Print("   Lots Final: ", DoubleToString(lots, 2));
    Print("   SL Value: $", DoubleToString(slPoints * valuePerPoint * lots, 2));
    Print("═══════════════════════════════════════");
    
    // Apply limits
    double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    double maxLotPerSide = GetMaxLotPerSide();
    
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);
    lots = MathMin(lots, maxLotPerSide);
    
    return lots;
}

//+------------------------------------------------------------------+
//| Get max lot per side (dynamic)                                   |
//+------------------------------------------------------------------+
double CRiskManager::GetMaxLotPerSide() {
    double equity = GetCurrentEquity();
    double maxLot = m_lotBase + MathFloor(equity / m_equityPerLotInc) * m_lotIncrement;
    maxLot = MathMin(maxLot, m_lotMax);
    return maxLot;
}

//+------------------------------------------------------------------+
//| Update max lot per side                                          |
//+------------------------------------------------------------------+
void CRiskManager::UpdateMaxLotPerSide() {
    double newMaxLot = GetMaxLotPerSide();
    Print("📊 MaxLotPerSide updated: ", newMaxLot);
}

//+------------------------------------------------------------------+
//| Track position                                                    |
//+------------------------------------------------------------------+
void CRiskManager::TrackPosition(ulong ticket, double entry, double sl, double tp, double lots) {
    // Check if already tracked
    for(int i = 0; i < ArraySize(m_positions); i++) {
        if(m_positions[i].ticket == ticket) {
            return; // Already tracked
        }
    }
    
    // Add new position
    int size = ArraySize(m_positions);
    ArrayResize(m_positions, size + 1);
    
    // Determine direction
    if(PositionSelectByTicket(ticket)) {
        long posType = PositionGetInteger(POSITION_TYPE);
        m_positions[size].direction = (posType == POSITION_TYPE_BUY) ? 1 : -1;
    }
    
    m_positions[size].ticket = ticket;
    m_positions[size].entryPrice = entry;
    m_positions[size].sl = sl;
    m_positions[size].originalSL = sl; // CRITICAL: Save original SL
    m_positions[size].tp = tp;
    m_positions[size].originalLot = lots;
    m_positions[size].dcaCount = 0;
    m_positions[size].movedToBE = false;
    m_positions[size].dca1Added = false;
    m_positions[size].dca2Added = false;
    m_positions[size].lastTrailR = 0.0;
    
    Print("📝 Position tracked: #", ticket, " | Entry: ", entry, " | Lots: ", lots);
}

//+------------------------------------------------------------------+
//| Calculate profit in R units                                      |
//+------------------------------------------------------------------+
double CRiskManager::CalcProfitInR(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return 0;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    long posType = PositionGetInteger(POSITION_TYPE);
    
    // Find ORIGINAL SL (critical!)
    double originalSL = 0;
    for(int i = 0; i < ArraySize(m_positions); i++) {
        if(m_positions[i].ticket == ticket) {
            originalSL = m_positions[i].originalSL;
            break;
        }
    }
    
    if(originalSL == 0) return 0;
    
    double profit = 0;
    double risk = 0;
    
    if(posType == POSITION_TYPE_BUY) {
        risk = openPrice - originalSL;
        profit = currentPrice - openPrice;
    } else {
        risk = originalSL - openPrice;
        profit = openPrice - currentPrice;
    }
    
    if(risk <= 0) return 0;
    
    return profit / risk;
}

//+------------------------------------------------------------------+
//| Manage open positions (DCA, BE, Trailing)                        |
//+------------------------------------------------------------------+
void CRiskManager::ManageOpenPositions() {
    // Check Daily MDD
    if(!CheckDailyMDD()) return;
    
    // Check Basket TP/SL
    CheckBasketTPSL();
    
    // Manage each position
    for(int i = ArraySize(m_positions) - 1; i >= 0; i--) {
        ulong ticket = m_positions[i].ticket;
        
        // Check if position still exists
        if(!PositionSelectByTicket(ticket)) {
            ArrayRemove(m_positions, i, 1);
            continue;
        }
        
        double profitR = CalcProfitInR(ticket);
        int direction = m_positions[i].direction;
        
        // TRAILING STOP
        if(m_enableTrailing) {
            if(profitR >= m_trailStartR) {
                if(profitR >= m_positions[i].lastTrailR + m_trailStepR) {
                    if(TrailSL(ticket)) {
                        m_positions[i].lastTrailR = profitR;
                    }
                }
            }
        }
        
        // BREAKEVEN
        if(m_enableBE && profitR >= m_beLevel_R && !m_positions[i].movedToBE) {
            if(MoveSLToBE(ticket)) {
                m_positions[i].movedToBE = true;
            }
        }
        
        // DCA LEVEL 1
        if(m_enableDCA) {
            if(profitR >= m_dcaLevel1_R && !m_positions[i].dca1Added) {
                if(CheckEquityHealth()) {
                    double addLots = m_positions[i].originalLot * m_dcaSize1_Mult;
                    
                    if(GetSideLots(direction) + addLots <= GetMaxLotPerSide()) {
                        if(AddDCAPosition(direction, addLots)) {
                            m_positions[i].dca1Added = true;
                            m_positions[i].dcaCount++;
                            Print("✅ DCA #1 added: ", addLots, " lots at +", 
                                  DoubleToString(profitR, 2), "R");
                        }
                    }
                }
            }
            
            // DCA LEVEL 2
            if(profitR >= m_dcaLevel2_R && !m_positions[i].dca2Added && m_maxDcaAddons >= 2) {
                if(CheckEquityHealth()) {
                    double addLots = m_positions[i].originalLot * m_dcaSize2_Mult;
                    
                    if(GetSideLots(direction) + addLots <= GetMaxLotPerSide()) {
                        if(AddDCAPosition(direction, addLots)) {
                            m_positions[i].dca2Added = true;
                            m_positions[i].dcaCount++;
                            Print("✅ DCA #2 added: ", addLots, " lots at +",
                                  DoubleToString(profitR, 2), "R");
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Add DCA position                                                  |
//+------------------------------------------------------------------+
bool CRiskManager::AddDCAPosition(int direction, double lots) {
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
    
    if(direction == 1) {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    } else {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
    
    // Copy SL/TP from existing position (same direction)
    for(int i = 0; i < ArraySize(m_positions); i++) {
        if(m_positions[i].direction == direction) {
            if(PositionSelectByTicket(m_positions[i].ticket)) {
                request.sl = PositionGetDouble(POSITION_SL);
                request.tp = PositionGetDouble(POSITION_TP);
                break;
            }
        }
    }
    
    bool sent = OrderSend(request, result);
    
    if(sent && result.retcode == TRADE_RETCODE_DONE) {
        Print("✅ DCA position opened: #", result.order);
        return true;
    } else {
        Print("❌ DCA failed: ", result.retcode);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Check equity health for DCA                                      |
//+------------------------------------------------------------------+
bool CRiskManager::CheckEquityHealth() {
    if(!m_dcaCheckEquity) return true;
    
    double currentEquity = GetCurrentEquity();
    double minEquity = m_startDayBalance * (m_dcaMinEquityPct / 100.0);
    
    if(currentEquity < minEquity) {
        Print("⚠️ DCA blocked: Equity too low");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Move SL to breakeven                                             |
//+------------------------------------------------------------------+
bool CRiskManager::MoveSLToBE(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentSL = PositionGetDouble(POSITION_SL);
    int direction = GetPositionDirection(ticket);
    
    // Check if already at BE or better
    if(direction == 1 && currentSL >= openPrice) return false;
    if(direction == -1 && currentSL <= openPrice) return false;
    
    // Move to BE
    if(UpdateSL(ticket, openPrice)) {
        Print("🎯 Breakeven: #", ticket, " SL → ", openPrice);
        
        // Update ALL positions in same direction
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong otherTicket = PositionGetTicket(i);
            if(otherTicket == ticket) continue;
            
            if(PositionSelectByTicket(otherTicket)) {
                if(PositionGetString(POSITION_SYMBOL) == m_symbol) {
                    long posType = PositionGetInteger(POSITION_TYPE);
                    int otherDir = (posType == POSITION_TYPE_BUY) ? 1 : -1;
                    
                    if(otherDir == direction) {
                        double otherEntry = PositionGetDouble(POSITION_PRICE_OPEN);
                        UpdateSL(otherTicket, otherEntry);
                    }
                }
            }
        }
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Trail stop loss                                                  |
//+------------------------------------------------------------------+
bool CRiskManager::TrailSL(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    double atr = GetATR();
    if(atr <= 0) return false;
    
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentSL = PositionGetDouble(POSITION_SL);
    long posType = PositionGetInteger(POSITION_TYPE);
    
    double trailDistance = atr * m_trailATRMult;
    double newSL = 0;
    
    if(posType == POSITION_TYPE_BUY) {
        newSL = currentPrice - trailDistance;
        if(newSL <= currentSL) return false; // Not better
    } else {
        newSL = currentPrice + trailDistance;
        if(newSL >= currentSL) return false; // Not better
    }
    
    // Update SL
    if(UpdateSL(ticket, newSL)) {
        Print("📈 Trailing: #", ticket, " SL → ", newSL);
        
        // Update ALL positions in same direction
        int direction = GetPositionDirection(ticket);
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong otherTicket = PositionGetTicket(i);
            if(otherTicket == ticket) continue;
            
            if(PositionSelectByTicket(otherTicket)) {
                if(PositionGetString(POSITION_SYMBOL) == m_symbol) {
                    int otherDir = GetPositionDirection(otherTicket);
                    if(otherDir == direction) {
                        UpdateSL(otherTicket, newSL);
                    }
                }
            }
        }
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update SL for position                                           |
//+------------------------------------------------------------------+
bool CRiskManager::UpdateSL(ulong ticket, double newSL) {
    if(!PositionSelectByTicket(ticket)) return false;
    
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    // Skip if same
    if(MathAbs(newSL - currentSL) < _Point) return false;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = m_symbol;
    request.sl = NormalizeDouble(newSL, _Digits);
    request.tp = currentTP;
    
    bool sent = OrderSend(request, result);
    
    if(sent && result.retcode == TRADE_RETCODE_DONE) {
        // Update tracking
        for(int i = 0; i < ArraySize(m_positions); i++) {
            if(m_positions[i].ticket == ticket) {
                m_positions[i].sl = newSL;
                break;
            }
        }
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check daily MDD                                                  |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyMDD() {
    if(!m_useDailyMDD) return true;
    
    ResetDailyTracking();
    
    if(m_tradingHalted) return false;
    
    // Calculate daily P/L
    double current = m_useEquityMDD ? GetCurrentEquity() : AccountInfoDouble(ACCOUNT_BALANCE);
    double start = m_startDayBalance;
    
    if(start <= 0) return true;
    
    double dailyPL = ((current - start) / start) * 100.0;
    
    if(dailyPL <= -m_dailyMddMax) {
        Print("═══════════════════════════════════════");
        Print("🛑 DAILY MDD EXCEEDED: ", DoubleToString(dailyPL, 2), "%");
        Print("🛑 CLOSING ALL POSITIONS");
        Print("═══════════════════════════════════════");
        
        CloseAllPositions("Daily MDD");
        m_tradingHalted = true;
        
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Reset daily tracking                                             |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyTracking() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    datetime currentDay = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    // Calculate local hour (GMT+7)
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (dt.hour + delta + 24) % 24;
    
    if(m_lastDayCheck != currentDay && hour_localvn >= m_dailyResetHour) {
        m_startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_lastDayCheck = currentDay;
        m_tradingHalted = false;
        
        UpdateMaxLotPerSide();
        
        Print("📅 Daily reset at ", m_dailyResetHour, "h GMT+7");
        Print("   Start balance: $", DoubleToString(m_startDayBalance, 2));
    }
}

//+------------------------------------------------------------------+
//| Check basket TP/SL                                               |
//+------------------------------------------------------------------+
void CRiskManager::CheckBasketTPSL() {
    if(m_basketTPPct <= 0 && m_basketSLPct <= 0) return;
    
    double plPct = GetBasketFloatingPLPct();
    
    // Basket TP
    if(m_basketTPPct > 0 && plPct >= m_basketTPPct) {
        Print("🎯 Basket TP hit: ", DoubleToString(plPct, 2), "%");
        CloseAllPositions("Basket TP");
        return;
    }
    
    // Basket SL
    if(m_basketSLPct > 0 && plPct <= -m_basketSLPct) {
        Print("🛑 Basket SL hit: ", DoubleToString(plPct, 2), "%");
        CloseAllPositions("Basket SL");
        return;
    }
}

//+------------------------------------------------------------------+
//| Get basket floating P/L                                          |
//+------------------------------------------------------------------+
double CRiskManager::GetBasketFloatingPL() {
    double totalPL = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol) {
                totalPL += PositionGetDouble(POSITION_PROFIT);
            }
        }
    }
    return totalPL;
}

//+------------------------------------------------------------------+
//| Get basket floating P/L percentage                               |
//+------------------------------------------------------------------+
double CRiskManager::GetBasketFloatingPLPct() {
    double totalPL = GetBasketFloatingPL();
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(balance <= 0) return 0;
    return (totalPL / balance) * 100.0;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
void CRiskManager::CloseAllPositions(string reason) {
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
                request.magic = 20251013;
                request.comment = reason;
                
                long posType = PositionGetInteger(POSITION_TYPE);
                if(posType == POSITION_TYPE_BUY) {
                    request.type = ORDER_TYPE_SELL;
                    request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
                } else {
                    request.type = ORDER_TYPE_BUY;
                    request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
                }
                
                bool sent = OrderSend(request, result);
                if(sent) {
                    Print("🔒 Closed position #", ticket, " | Reason: ", reason);
                }
            }
        }
    }
    
    // Clear tracking
    ArrayResize(m_positions, 0);
}

//+------------------------------------------------------------------+
//| Get current equity                                               |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentEquity() {
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Get total lots for direction                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetSideLots(int direction) {
    double totalLots = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) == m_symbol) {
                long posType = PositionGetInteger(POSITION_TYPE);
                int posDir = (posType == POSITION_TYPE_BUY) ? 1 : -1;
                
                if(posDir == direction) {
                    totalLots += PositionGetDouble(POSITION_VOLUME);
                }
            }
        }
    }
    
    return totalLots;
}

//+------------------------------------------------------------------+
//| Get position direction                                           |
//+------------------------------------------------------------------+
int CRiskManager::GetPositionDirection(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return 0;
    long posType = PositionGetInteger(POSITION_TYPE);
    return (posType == POSITION_TYPE_BUY) ? 1 : -1;
}

//+------------------------------------------------------------------+
//| Get ATR value                                                     |
//+------------------------------------------------------------------+
double CRiskManager::GetATR() {
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) <= 0) {
        return 0;
    }
    return atr[0];
}

