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
    double   m_maxLotBase;        // Base max lot (1.0)
    double   m_maxLotPerSide;     // Dynamic calculated
    int      m_maxDcaAddons;
    double   m_dailyMddMax;       // Max daily drawdown %
    
    // DCA parameters
    double   m_dcaLevel1_R;       // +0.75R
    double   m_dcaLevel2_R;       // +1.5R
    double   m_dcaSize1_Mult;     // 0.5x
    double   m_dcaSize2_Mult;     // 0.33x
    
    // BE and Trail parameters
    double   m_beLevel_R;         // +1R for breakeven
    
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
    
    void Init(string symbol, double riskPct, double maxLotBase, int maxDCA, double dailyMDD,
              double basketTPPct, double basketSLPct, int endOfDayHour, int dailyResetHour);
    
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
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CRiskManager::CRiskManager() {
    m_riskPerTradePct = 0.3;
    m_maxLotBase = 1.0;
    m_maxLotPerSide = 1.0;
    m_maxDcaAddons = 2;
    m_dailyMddMax = 8.0;
    
    m_dcaLevel1_R = 0.75;
    m_dcaLevel2_R = 1.5;
    m_dcaSize1_Mult = 0.5;
    m_dcaSize2_Mult = 0.33;
    
    m_beLevel_R = 1.0;
    
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
void CRiskManager::Init(string symbol, double riskPct, double maxLotBase, int maxDCA, double dailyMDD,
                        double basketTPPct, double basketSLPct, int endOfDayHour, int dailyResetHour) {
    m_symbol = symbol;
    m_riskPerTradePct = riskPct;
    m_maxLotBase = maxLotBase;
    m_maxDcaAddons = maxDCA;
    m_dailyMddMax = dailyMDD;
    
    m_basketTPPct = basketTPPct;
    m_basketSLPct = basketSLPct;
    m_endOfDayHour = endOfDayHour;
    m_dailyResetHour = dailyResetHour;
    m_enableBasketTP = (basketTPPct > 0);
    m_enableBasketSL = (basketSLPct > 0);
    m_enableEODClose = (endOfDayHour > 0);
    
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
//| Update dynamic MaxLotPerSide based on balance growth            |
//+------------------------------------------------------------------+
void CRiskManager::UpdateMaxLotPerSide() {
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double balanceGrowth = currentBalance - m_initialBalance;
    
    // Formula: MaxLot = Base + floor(BalanceGrowth / 1000) * 0.1
    int increments = (int)MathFloor(balanceGrowth / 1000.0);
    m_maxLotPerSide = m_maxLotBase + (increments * 0.1);
    
    // Ensure minimum
    if(m_maxLotPerSide < m_maxLotBase) {
        m_maxLotPerSide = m_maxLotBase;
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

