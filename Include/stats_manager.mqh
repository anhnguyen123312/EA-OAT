//+------------------------------------------------------------------+
//|                                                stats_manager.mqh |
//|                              Trading Statistics Tracker          |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property version   "1.20"
#property strict

//+------------------------------------------------------------------+
//| Pattern Type Enum                                                |
//+------------------------------------------------------------------+
enum ENUM_PATTERN_TYPE {
    PATTERN_BOS_OB = 0,        // BOS + Order Block
    PATTERN_BOS_FVG = 1,       // BOS + FVG
    PATTERN_SWEEP_OB = 2,      // Sweep + OB
    PATTERN_SWEEP_FVG = 3,     // Sweep + FVG
    PATTERN_MOMO = 4,          // Momentum Only
    PATTERN_CONFLUENCE = 5,    // BOS + Sweep + OB/FVG
    PATTERN_OTHER = 6
};

//+------------------------------------------------------------------+
//| Trade Record Structure                                           |
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
    double   profitPct;
    int      patternType;      // ENUM_PATTERN_TYPE
    bool     isWin;
    double   rr;
    int      slPips;
    int      tpPips;
};

//+------------------------------------------------------------------+
//| Pattern Stats Structure                                          |
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
//| Stats Manager Class                                             |
//+------------------------------------------------------------------+
class CStatsManager {
private:
    TradeRecord m_trades[];
    PatternStats m_stats[7];  // One for each pattern type
    PatternStats m_overall;
    
    string   m_symbol;
    int      m_maxHistory;
    
public:
    CStatsManager();
    ~CStatsManager();
    
    void Init(string symbol, int maxHistory = 500);
    void RecordTrade(ulong ticket, int direction, double openPrice, double lots,
                     int patternType, double slPrice, double tpPrice);
    void UpdateClosedTrade(ulong ticket, double closePrice, double profit);
    void CalculateStats();
    
    // Getters
    PatternStats GetPatternStats(int patternType);
    PatternStats GetOverallStats();
    int GetTotalTrades();
    double GetWinRate();
    double GetProfitFactor();
    string GetPatternName(int patternType);
    
private:
    void UpdatePatternStats(int patternType);
    void UpdateOverallStats();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CStatsManager::CStatsManager() {
    m_maxHistory = 500;
    ArrayResize(m_trades, 0);
    
    // Initialize all pattern stats
    for(int i = 0; i < 7; i++) {
        m_stats[i].totalTrades = 0;
        m_stats[i].wins = 0;
        m_stats[i].losses = 0;
        m_stats[i].winRate = 0;
        m_stats[i].totalProfit = 0;
        m_stats[i].avgProfit = 0;
        m_stats[i].avgWin = 0;
        m_stats[i].avgLoss = 0;
        m_stats[i].profitFactor = 0;
        m_stats[i].avgRR = 0;
    }
    
    // Initialize overall stats
    m_overall.totalTrades = 0;
    m_overall.wins = 0;
    m_overall.losses = 0;
    m_overall.winRate = 0;
    m_overall.totalProfit = 0;
    m_overall.avgProfit = 0;
    m_overall.profitFactor = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CStatsManager::~CStatsManager() {
}

//+------------------------------------------------------------------+
//| Initialize stats manager                                         |
//+------------------------------------------------------------------+
void CStatsManager::Init(string symbol, int maxHistory = 500) {
    m_symbol = symbol;
    m_maxHistory = maxHistory;
    Print("📊 Stats Manager initialized | Max history: ", m_maxHistory, " trades");
}

//+------------------------------------------------------------------+
//| Record new trade                                                 |
//+------------------------------------------------------------------+
void CStatsManager::RecordTrade(ulong ticket, int direction, double openPrice, double lots,
                                int patternType, double slPrice, double tpPrice) {
    int size = ArraySize(m_trades);
    
    // Limit history size
    if(size >= m_maxHistory) {
        ArrayRemove(m_trades, 0, 1); // Remove oldest
        size = ArraySize(m_trades);
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
    m_trades[size].profitPct = 0;
    m_trades[size].patternType = patternType;
    m_trades[size].isWin = false;
    
    // Calculate SL/TP in pips
    int slPips = 0;
    int tpPips = 0;
    if(direction == 1) {
        slPips = (int)((openPrice - slPrice) / (_Point * 10));
        tpPips = (int)((tpPrice - openPrice) / (_Point * 10));
    } else {
        slPips = (int)((slPrice - openPrice) / (_Point * 10));
        tpPips = (int)((openPrice - tpPrice) / (_Point * 10));
    }
    m_trades[size].slPips = slPips;
    m_trades[size].tpPips = tpPips;
    m_trades[size].rr = (slPips > 0) ? ((double)tpPips / slPips) : 0;
    
    Print("📝 Trade recorded: #", ticket, " | Pattern: ", GetPatternName(patternType), 
          " | SL: ", slPips, " pips | TP: ", tpPips, " pips | RR: ", DoubleToString(m_trades[size].rr, 2));
}

//+------------------------------------------------------------------+
//| Update closed trade                                              |
//+------------------------------------------------------------------+
void CStatsManager::UpdateClosedTrade(ulong ticket, double closePrice, double profit) {
    for(int i = ArraySize(m_trades) - 1; i >= 0; i--) {
        if(m_trades[i].ticket == ticket) {
            m_trades[i].closeTime = TimeCurrent();
            m_trades[i].closePrice = closePrice;
            m_trades[i].profit = profit;
            m_trades[i].isWin = (profit > 0);
            
            // Calculate stats
            CalculateStats();
            
            string result = m_trades[i].isWin ? "WIN ✅" : "LOSS ❌";
            Print("📊 Trade closed: #", ticket, " | ", result, " | Profit: $", 
                  DoubleToString(profit, 2), " | Pattern: ", GetPatternName(m_trades[i].patternType));
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculate all statistics                                         |
//+------------------------------------------------------------------+
void CStatsManager::CalculateStats() {
    // Reset all stats
    for(int i = 0; i < 7; i++) {
        UpdatePatternStats(i);
    }
    UpdateOverallStats();
}

//+------------------------------------------------------------------+
//| Update stats for specific pattern                                |
//+------------------------------------------------------------------+
void CStatsManager::UpdatePatternStats(int patternType) {
    m_stats[patternType].totalTrades = 0;
    m_stats[patternType].wins = 0;
    m_stats[patternType].losses = 0;
    m_stats[patternType].totalProfit = 0;
    double totalWinProfit = 0;
    double totalLossProfit = 0;
    double totalRR = 0;
    int rrCount = 0;
    
    for(int i = 0; i < ArraySize(m_trades); i++) {
        if(m_trades[i].closeTime > 0 && m_trades[i].patternType == patternType) {
            m_stats[patternType].totalTrades++;
            m_stats[patternType].totalProfit += m_trades[i].profit;
            
            if(m_trades[i].isWin) {
                m_stats[patternType].wins++;
                totalWinProfit += m_trades[i].profit;
            } else {
                m_stats[patternType].losses++;
                totalLossProfit += MathAbs(m_trades[i].profit);
            }
            
            if(m_trades[i].rr > 0) {
                totalRR += m_trades[i].rr;
                rrCount++;
            }
        }
    }
    
    // Calculate rates
    if(m_stats[patternType].totalTrades > 0) {
        m_stats[patternType].winRate = ((double)m_stats[patternType].wins / m_stats[patternType].totalTrades) * 100.0;
        m_stats[patternType].avgProfit = m_stats[patternType].totalProfit / m_stats[patternType].totalTrades;
    }
    
    if(m_stats[patternType].wins > 0) {
        m_stats[patternType].avgWin = totalWinProfit / m_stats[patternType].wins;
    }
    
    if(m_stats[patternType].losses > 0) {
        m_stats[patternType].avgLoss = totalLossProfit / m_stats[patternType].losses;
    }
    
    if(totalLossProfit > 0) {
        m_stats[patternType].profitFactor = totalWinProfit / totalLossProfit;
    }
    
    if(rrCount > 0) {
        m_stats[patternType].avgRR = totalRR / rrCount;
    }
}

//+------------------------------------------------------------------+
//| Update overall statistics                                        |
//+------------------------------------------------------------------+
void CStatsManager::UpdateOverallStats() {
    m_overall.totalTrades = 0;
    m_overall.wins = 0;
    m_overall.losses = 0;
    m_overall.totalProfit = 0;
    double totalWinProfit = 0;
    double totalLossProfit = 0;
    
    for(int i = 0; i < ArraySize(m_trades); i++) {
        if(m_trades[i].closeTime > 0) {
            m_overall.totalTrades++;
            m_overall.totalProfit += m_trades[i].profit;
            
            if(m_trades[i].isWin) {
                m_overall.wins++;
                totalWinProfit += m_trades[i].profit;
            } else {
                m_overall.losses++;
                totalLossProfit += MathAbs(m_trades[i].profit);
            }
        }
    }
    
    if(m_overall.totalTrades > 0) {
        m_overall.winRate = ((double)m_overall.wins / m_overall.totalTrades) * 100.0;
        m_overall.avgProfit = m_overall.totalProfit / m_overall.totalTrades;
    }
    
    if(m_overall.wins > 0) {
        m_overall.avgWin = totalWinProfit / m_overall.wins;
    }
    
    if(m_overall.losses > 0) {
        m_overall.avgLoss = totalLossProfit / m_overall.losses;
    }
    
    if(totalLossProfit > 0) {
        m_overall.profitFactor = totalWinProfit / totalLossProfit;
    }
}

//+------------------------------------------------------------------+
//| Get pattern statistics                                           |
//+------------------------------------------------------------------+
PatternStats CStatsManager::GetPatternStats(int patternType) {
    if(patternType >= 0 && patternType < 7) {
        return m_stats[patternType];
    }
    return m_overall;
}

//+------------------------------------------------------------------+
//| Get overall statistics                                           |
//+------------------------------------------------------------------+
PatternStats CStatsManager::GetOverallStats() {
    return m_overall;
}

//+------------------------------------------------------------------+
//| Get total trades                                                 |
//+------------------------------------------------------------------+
int CStatsManager::GetTotalTrades() {
    return m_overall.totalTrades;
}

//+------------------------------------------------------------------+
//| Get win rate                                                     |
//+------------------------------------------------------------------+
double CStatsManager::GetWinRate() {
    return m_overall.winRate;
}

//+------------------------------------------------------------------+
//| Get profit factor                                                |
//+------------------------------------------------------------------+
double CStatsManager::GetProfitFactor() {
    return m_overall.profitFactor;
}

//+------------------------------------------------------------------+
//| Get pattern name as string                                       |
//+------------------------------------------------------------------+
string CStatsManager::GetPatternName(int patternType) {
    switch(patternType) {
        case PATTERN_BOS_OB:        return "BOS+OB";
        case PATTERN_BOS_FVG:       return "BOS+FVG";
        case PATTERN_SWEEP_OB:      return "Sweep+OB";
        case PATTERN_SWEEP_FVG:     return "Sweep+FVG";
        case PATTERN_MOMO:          return "Momentum";
        case PATTERN_CONFLUENCE:    return "Confluence";
        default:                    return "Other";
    }
}

