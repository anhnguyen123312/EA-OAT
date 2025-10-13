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
    double   m_maxLotPerSide;
    int      m_maxDcaAddons;
    double   m_dailyMddMax;       // Max daily drawdown %
    
    // DCA parameters
    double   m_dcaLevel1_R;       // +0.75R
    double   m_dcaLevel2_R;       // +1.5R
    double   m_dcaSize1_Mult;     // 0.5x
    double   m_dcaSize2_Mult;     // 0.33x
    
    // BE and Trail parameters
    double   m_beLevel_R;         // +1R for breakeven
    
    // Daily tracking
    double   m_startDayBalance;
    datetime m_lastDayCheck;
    bool     m_tradingHalted;
    
    // DCA tracking per position
    struct PositionDCA {
        ulong    ticket;
        double   entryPrice;
        double   sl;
        double   tp;
        double   originalLot;
        int      dcaCount;
        bool     movedToBE;
        bool     dca1Added;
        bool     dca2Added;
    };
    PositionDCA m_positions[];
    
public:
    CRiskManager();
    ~CRiskManager();
    
    void Init(string symbol, double riskPct, double maxLot, int maxDCA, double dailyMDD);
    
    double CalcLotsByRisk(double riskPct, double slPoints);
    bool   CheckDailyMDD();
    void   ResetDailyTracking();
    bool   IsTradingHalted() { return m_tradingHalted; }
    
    void   TrackPosition(ulong ticket, double entry, double sl, double tp, double lots);
    void   ManageOpenPositions();
    
private:
    double GetCurrentEquity();
    double GetDailyPL();
    int    CountSidePositions(int direction);
    double GetSideLots(int direction);
    double CalcProfitInR(ulong ticket);
    bool   MoveSLToBE(ulong ticket);
    bool   AddDCAPosition(int direction, double lots, double currentPrice);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() {
    m_riskPerTradePct = 0.3;
    m_maxLotPerSide = 3.0;
    m_maxDcaAddons = 2;
    m_dailyMddMax = 8.0;
    
    m_dcaLevel1_R = 0.75;
    m_dcaLevel2_R = 1.5;
    m_dcaSize1_Mult = 0.5;
    m_dcaSize2_Mult = 0.33;
    
    m_beLevel_R = 1.0;
    
    m_tradingHalted = false;
    m_lastDayCheck = 0;
    m_startDayBalance = 0;
    
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
void CRiskManager::Init(string symbol, double riskPct, double maxLot, int maxDCA, double dailyMDD) {
    m_symbol = symbol;
    m_riskPerTradePct = riskPct;
    m_maxLotPerSide = maxLot;
    m_maxDcaAddons = maxDCA;
    m_dailyMddMax = dailyMDD;
    
    ResetDailyTracking();
}

//+------------------------------------------------------------------+
//| Get current equity                                               |
//+------------------------------------------------------------------+
double CRiskManager::GetCurrentEquity() {
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk                                 |
//+------------------------------------------------------------------+
double CRiskManager::CalcLotsByRisk(double riskPct, double slPoints) {
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = GetCurrentEquity();
    
    // Use balance for calculation
    double riskValue = balance * (riskPct / 100.0);
    
    // Get tick value
    double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickSize == 0 || slPoints == 0) return 0.01;
    
    // Calculate value per point per lot
    double valuePerPointPerLot = tickValue * (_Point / tickSize);
    
    // Calculate lots
    double lots = riskValue / (slPoints * valuePerPointPerLot);
    
    // Normalize and apply limits
    lots = NormalizeDouble(lots, 2);
    
    double minLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
    
    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;
    if(lots > m_maxLotPerSide) lots = m_maxLotPerSide;
    
    return lots;
}

//+------------------------------------------------------------------+
//| Reset daily tracking                                             |
//+------------------------------------------------------------------+
void CRiskManager::ResetDailyTracking() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    datetime currentDay = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
    
    if(m_lastDayCheck != currentDay) {
        m_startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_lastDayCheck = currentDay;
        m_tradingHalted = false;
        Print("Daily tracking reset. Start balance: ", m_startDayBalance);
    }
}

//+------------------------------------------------------------------+
//| Get daily P/L percentage                                         |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyPL() {
    if(m_startDayBalance <= 0) return 0;
    
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double pl = ((currentBalance - m_startDayBalance) / m_startDayBalance) * 100.0;
    
    return pl;
}

//+------------------------------------------------------------------+
//| Check daily MDD and halt trading if exceeded                     |
//+------------------------------------------------------------------+
bool CRiskManager::CheckDailyMDD() {
    ResetDailyTracking(); // Check if new day
    
    if(m_tradingHalted) return false;
    
    double dailyPL = GetDailyPL();
    
    if(dailyPL <= -m_dailyMddMax) {
        Print("DAILY MDD EXCEEDED: ", dailyPL, "% - Closing all positions and halting trading");
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
                        Print("Failed to close position on MDD: ", result.retcode);
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
    int size = ArraySize(m_positions);
    ArrayResize(m_positions, size + 1);
    
    m_positions[size].ticket = ticket;
    m_positions[size].entryPrice = entry;
    m_positions[size].sl = sl;
    m_positions[size].tp = tp;
    m_positions[size].originalLot = lots;
    m_positions[size].dcaCount = 0;
    m_positions[size].movedToBE = false;
    m_positions[size].dca1Added = false;
    m_positions[size].dca2Added = false;
}

//+------------------------------------------------------------------+
//| Calculate profit in R (risk units)                               |
//+------------------------------------------------------------------+
double CRiskManager::CalcProfitInR(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return 0;
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double sl = PositionGetDouble(POSITION_SL);
    int posType = (int)PositionGetInteger(POSITION_TYPE);
    
    double risk = 0;
    double profit = 0;
    
    if(posType == POSITION_TYPE_BUY) {
        risk = openPrice - sl;
        profit = currentPrice - openPrice;
    } else {
        risk = sl - openPrice;
        profit = openPrice - currentPrice;
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
        Print("Position ", ticket, " moved to breakeven");
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
        Print("Cannot add DCA: would exceed max lot per side");
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
    
    if(direction == 1) {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    } else {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    }
    
    if(OrderSend(request, result)) {
        Print("DCA position added: ", lots, " lots");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Manage open positions - BE, Trail, DCA                           |
//+------------------------------------------------------------------+
void CRiskManager::ManageOpenPositions() {
    // Check daily MDD first
    if(!CheckDailyMDD()) return;
    
    // Update position tracking
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
        
        // Move to BE at +1R
        if(profitR >= m_beLevel_R && !m_positions[i].movedToBE) {
            if(MoveSLToBE(ticket)) {
                m_positions[i].movedToBE = true;
            }
        }
        
        // DCA Add-on #1 at +0.75R
        if(profitR >= m_dcaLevel1_R && !m_positions[i].dca1Added && m_positions[i].dcaCount < m_maxDcaAddons) {
            double addLots = m_positions[i].originalLot * m_dcaSize1_Mult;
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            
            if(AddDCAPosition(direction, addLots, currentPrice)) {
                m_positions[i].dca1Added = true;
                m_positions[i].dcaCount++;
            }
        }
        
        // DCA Add-on #2 at +1.5R
        if(profitR >= m_dcaLevel2_R && !m_positions[i].dca2Added && m_positions[i].dcaCount < m_maxDcaAddons) {
            double addLots = m_positions[i].originalLot * m_dcaSize2_Mult;
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            
            if(AddDCAPosition(direction, addLots, currentPrice)) {
                m_positions[i].dca2Added = true;
                m_positions[i].dcaCount++;
            }
        }
    }
}

