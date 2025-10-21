//+------------------------------------------------------------------+
//|                                                stats_manager.mqh |
//|                         Statistics Tracking - Pattern Performance|
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

//+------------------------------------------------------------------+
//| Trade Record                                                      |
//+------------------------------------------------------------------+
struct TradeRecord {
    ulong    ticket;
    datetime openTime;
    datetime closeTime;
    int      direction;        // 1=BUY, -1=SELL
    double   openPrice;
    double   closePrice;
    double   lots;
    double   profit;
    int      patternType;      // PATTERN_TYPE enum
    bool     isWin;
    double   rr;
    int      slPips;
    int      tpPips;
};

//+------------------------------------------------------------------+
//| Pattern Statistics                                               |
//+------------------------------------------------------------------+
struct PatternStats {
    int      totalTrades;
    int      wins;
    int      losses;
    double   winRate;
    double   totalProfit;
    double   avgProfit;
    double   avgWin;
    double   avgLoss;
    double   profitFactor;
    double   avgRR;
};

//+------------------------------------------------------------------+
//| CStatsManager Class                                               |
//+------------------------------------------------------------------+
class CStatsManager {
private:
    string   m_symbol;
    int      m_maxHistory;
    TradeRecord m_trades[];
    
public:
    CStatsManager();
    ~CStatsManager();
    
    bool Init(string symbol, int maxHistory);
    
    void RecordTrade(ulong ticket, int direction, double openPrice, double lots,
                    int patternType, double slPrice, double tpPrice);
    
    void UpdateClosedTrade(ulong ticket, double closePrice, double profit);
    
    PatternStats GetOverallStats();
    PatternStats GetPatternStats(int patternType);
    
    string GetPatternName(int patternType);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CStatsManager::CStatsManager() {
    ArrayResize(m_trades, 0);
    m_maxHistory = 500;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CStatsManager::~CStatsManager() {
}

//+------------------------------------------------------------------+
//| Initialize stats manager                                         |
//+------------------------------------------------------------------+
bool CStatsManager::Init(string symbol, int maxHistory) {
    m_symbol = symbol;
    m_maxHistory = maxHistory;
    
    Print("✅ CStatsManager initialized | Max history: ", m_maxHistory);
    return true;
}

//+------------------------------------------------------------------+
//| Record new trade                                                 |
//+------------------------------------------------------------------+
void CStatsManager::RecordTrade(ulong ticket, int direction, double openPrice, double lots,
                                int patternType, double slPrice, double tpPrice) {
    int size = ArraySize(m_trades);
    
    // Check if already recorded
    for(int i = 0; i < size; i++) {
        if(m_trades[i].ticket == ticket) {
            return; // Already recorded
        }
    }
    
    // Remove oldest if at max
    if(size >= m_maxHistory) {
        ArrayRemove(m_trades, 0, 1);
        size--;
    }
    
    ArrayResize(m_trades, size + 1);
    
    m_trades[size].ticket = ticket;
    m_trades[size].openTime = TimeCurrent();
    m_trades[size].closeTime = 0;
    m_trades[size].direction = direction;
    m_trades[size].openPrice = openPrice;
    m_trades[size].closePrice = 0;
    m_trades[size].lots = lots;
    m_trades[size].profit = 0;
    m_trades[size].patternType = patternType;
    m_trades[size].isWin = false;
    
    // Calculate SL/TP in pips
    if(direction == 1) {
        m_trades[size].slPips = (int)((openPrice - slPrice) / (_Point * 10));
        m_trades[size].tpPips = (int)((tpPrice - openPrice) / (_Point * 10));
    } else {
        m_trades[size].slPips = (int)((slPrice - openPrice) / (_Point * 10));
        m_trades[size].tpPips = (int)((openPrice - tpPrice) / (_Point * 10));
    }
    
    m_trades[size].rr = (m_trades[size].slPips > 0) ? 
                       ((double)m_trades[size].tpPips / m_trades[size].slPips) : 0;
    
    Print("📝 Trade recorded: #", ticket, " | Pattern: ", GetPatternName(patternType));
}

//+------------------------------------------------------------------+
//| Update closed trade                                              |
//+------------------------------------------------------------------+
void CStatsManager::UpdateClosedTrade(ulong ticket, double closePrice, double profit) {
    for(int i = ArraySize(m_trades) - 1; i >= 0; i--) {
        if(m_trades[i].ticket == ticket && m_trades[i].closeTime == 0) {
            m_trades[i].closeTime = TimeCurrent();
            m_trades[i].closePrice = closePrice;
            m_trades[i].profit = profit;
            m_trades[i].isWin = (profit > 0);
            
            string result = m_trades[i].isWin ? "WIN ✅" : "LOSS ❌";
            Print("📊 Trade closed: #", ticket, " | ", result,
                  " | Profit: $", DoubleToString(profit, 2));
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Get overall statistics                                           |
//+------------------------------------------------------------------+
PatternStats CStatsManager::GetOverallStats() {
    PatternStats stats;
    stats.totalTrades = 0;
    stats.wins = 0;
    stats.losses = 0;
    stats.totalProfit = 0;
    stats.winRate = 0;
    stats.avgProfit = 0;
    stats.avgWin = 0;
    stats.avgLoss = 0;
    stats.profitFactor = 0;
    stats.avgRR = 0;
    
    double totalWinProfit = 0;
    double totalLossProfit = 0;
    double totalRR = 0;
    int closedTrades = 0;
    
    for(int i = 0; i < ArraySize(m_trades); i++) {
        if(m_trades[i].closeTime > 0) {
            closedTrades++;
            stats.totalProfit += m_trades[i].profit;
            totalRR += m_trades[i].rr;
            
            if(m_trades[i].isWin) {
                stats.wins++;
                totalWinProfit += m_trades[i].profit;
            } else {
                stats.losses++;
                totalLossProfit += MathAbs(m_trades[i].profit);
            }
        }
    }
    
    stats.totalTrades = closedTrades;
    
    if(closedTrades > 0) {
        stats.winRate = ((double)stats.wins / closedTrades) * 100.0;
        stats.avgProfit = stats.totalProfit / closedTrades;
        stats.avgRR = totalRR / closedTrades;
    }
    
    if(stats.wins > 0) {
        stats.avgWin = totalWinProfit / stats.wins;
    }
    
    if(stats.losses > 0) {
        stats.avgLoss = totalLossProfit / stats.losses;
    }
    
    if(totalLossProfit > 0) {
        stats.profitFactor = totalWinProfit / totalLossProfit;
    }
    
    return stats;
}

//+------------------------------------------------------------------+
//| Get pattern statistics                                           |
//+------------------------------------------------------------------+
PatternStats CStatsManager::GetPatternStats(int patternType) {
    PatternStats stats;
    stats.totalTrades = 0;
    stats.wins = 0;
    stats.losses = 0;
    stats.totalProfit = 0;
    stats.winRate = 0;
    stats.avgProfit = 0;
    stats.avgWin = 0;
    stats.avgLoss = 0;
    stats.profitFactor = 0;
    stats.avgRR = 0;
    
    double totalWinProfit = 0;
    double totalLossProfit = 0;
    double totalRR = 0;
    
    for(int i = 0; i < ArraySize(m_trades); i++) {
        if(m_trades[i].closeTime > 0 && m_trades[i].patternType == patternType) {
            stats.totalTrades++;
            stats.totalProfit += m_trades[i].profit;
            totalRR += m_trades[i].rr;
            
            if(m_trades[i].isWin) {
                stats.wins++;
                totalWinProfit += m_trades[i].profit;
            } else {
                stats.losses++;
                totalLossProfit += MathAbs(m_trades[i].profit);
            }
        }
    }
    
    if(stats.totalTrades > 0) {
        stats.winRate = ((double)stats.wins / stats.totalTrades) * 100.0;
        stats.avgProfit = stats.totalProfit / stats.totalTrades;
        stats.avgRR = totalRR / stats.totalTrades;
    }
    
    if(stats.wins > 0) {
        stats.avgWin = totalWinProfit / stats.wins;
    }
    
    if(stats.losses > 0) {
        stats.avgLoss = totalLossProfit / stats.losses;
    }
    
    if(totalLossProfit > 0) {
        stats.profitFactor = totalWinProfit / totalLossProfit;
    }
    
    return stats;
}

//+------------------------------------------------------------------+
//| Get pattern name                                                 |
//+------------------------------------------------------------------+
string CStatsManager::GetPatternName(int patternType) {
    switch(patternType) {
        case 0: return "BOS+OB";
        case 1: return "BOS+FVG";
        case 2: return "Sweep+OB";
        case 3: return "Sweep+FVG";
        case 4: return "Momentum";
        case 5: return "Confluence";
        case 6: return "Other";
        default: return "Unknown";
    }
}

