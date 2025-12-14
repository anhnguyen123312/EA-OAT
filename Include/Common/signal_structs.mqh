//+------------------------------------------------------------------+
//|                                            signal_structs.mqh |
//|                    Common Signal Structures - All Layers      |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

//+------------------------------------------------------------------+
//| ═══════════════════════════════════════════════════════════════ |
//| ALL SIGNAL STRUCTURES - Centralized Data Layer                  |
//| ═══════════════════════════════════════════════════════════════ |
//| Tất cả structures được định nghĩa ở đây để các Layer chỉ      |
//| giao tiếp qua data, không import/require từ Layer khác          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Entry Method Types                                               |
//+------------------------------------------------------------------+
enum ENTRY_TYPE {
    ENTRY_STOP = 0,    // Buy/Sell Stop
    ENTRY_LIMIT = 1,   // Buy/Sell Limit
    ENTRY_MARKET = 2   // Market execution
};

//+------------------------------------------------------------------+
//| Pattern Types                                                    |
//+------------------------------------------------------------------+
enum PATTERN_TYPE {
    PATTERN_BOS_OB = 0,        // BOS + Order Block
    PATTERN_BOS_FVG = 1,       // BOS + FVG
    PATTERN_SWEEP_OB = 2,      // Sweep + OB
    PATTERN_SWEEP_FVG = 3,     // Sweep + FVG
    PATTERN_MOMO = 4,          // Momentum only
    PATTERN_CONFLUENCE = 5,    // BOS + Sweep + (OB/FVG)
    PATTERN_OTHER = 6
};

//+------------------------------------------------------------------+
//| Detection Layer Signal Structures                               |
//+------------------------------------------------------------------+

// BOS (Break of Structure) Signal
struct BOSSignal {
    bool     valid;
    int      direction;         // 1=bullish, -1=bearish
    datetime detectedTime;
    double   breakLevel;        // Price level broken
    int      barsAge;
    int      ttl;
    // v2.1 additions
    int      retestCount;       // Number of retests
    datetime lastRetestTime;    // Last retest timestamp
    bool     hasRetest;         // At least 1 retest
    double   retestStrength;    // 0-1 quality score
};

// Liquidity Sweep Signal
struct SweepSignal {
    bool     detected;
    int      side;              // 1=buy-side high, -1=sell-side low
    double   level;             // Fractal price level
    datetime time;
    int      distanceBars;      // Distance to fractal
    bool     valid;
    double   proximityATR;      // v2.0: Distance / ATR
};

// Order Block Structure
struct OrderBlock {
    bool     valid;
    int      direction;         // 1=demand, -1=supply
    double   priceTop;
    double   priceBottom;
    datetime createdTime;
    int      touches;           // Number of touches
    bool     weak;              // Volume < 1.3x avg
    bool     isBreaker;         // Invalidated → Breaker Block
    long     volume;            // Candle volume
    // v2.1 additions
    bool     hasSweepNearby;    // Has sweep validation
    double   sweepLevel;        // Sweep price
    int      sweepDistancePts;  // Distance in points
    double   sweepQuality;      // 0-1 quality score
    double   size;              // Actual OB size (high - low)
};

// Fair Value Gap Signal
struct FVGSignal {
    bool     valid;
    int      direction;         // 1=bullish, -1=bearish
    double   priceTop;
    double   priceBottom;
    datetime createdTime;
    int      state;             // 0=Valid, 1=Mitigated, 2=Completed
    double   fillPct;           // % filled
    double   initialSize;       // Original gap size
    // v2.1 additions
    bool     mtfOverlap;        // HTF confirmation
    double   htfFVGTop;         // HTF FVG top
    double   htfFVGBottom;      // HTF FVG bottom
    double   overlapRatio;      // LTF size / HTF size
    ENUM_TIMEFRAMES htfPeriod;  // Which HTF
};

// Momentum Signal
struct MomentumSignal {
    bool     valid;
    int      direction;         // 1=bullish, -1=bearish
    int      consecutiveBars;
    datetime detectedTime;
    int      ttl;
};

// Swing Point Structure
struct Swing {
    int      index;
    double   price;
    datetime time;
    bool     valid;
};

//+------------------------------------------------------------------+
//| Arbitration Layer Structures                                     |
//+------------------------------------------------------------------+

// Entry Configuration
struct EntryConfig {
    ENTRY_TYPE type;
    double price;
    string reason;
};

// Trade Candidate Structure
struct Candidate {
    bool     valid;
    int      direction;         // 1=long, -1=short
    double   score;             // Priority score
    
    // Signal flags
    bool     hasBOS;
    bool     hasSweep;
    bool     hasOB;
    bool     hasFVG;
    bool     hasMomo;
    
    // POI (Point of Interest)
    double   poiTop;
    double   poiBottom;
    
    // BOS details
    double   bosLevel;
    
    // Sweep details
    double   sweepLevel;
    int      sweepDistanceBars;
    double   sweepProximityATR;
    
    // OB details
    int      obTouches;
    bool     obWeak;
    bool     obStrong;
    bool     obIsBreaker;
    // v2.1 OB Sweep
    bool     obHasSweep;
    double   obSweepLevel;
    int      obSweepDistance;
    double   obSweepQuality;
    
    // FVG details
    int      fvgState;          // 0=Valid, 1=Mitigated, 2=Completed
    double   fvgBottom;
    double   fvgTop;
    // v2.1 FVG MTF
    bool     fvgMTFOverlap;
    double   fvgHTFTop;
    double   fvgHTFBottom;
    double   fvgOverlapRatio;
    ENUM_TIMEFRAMES fvgHTFPeriod;
    
    // BOS Retest (v2.1)
    int      bosRetestCount;
    bool     bosHasRetest;
    double   bosRetestStrength;
    
    // Momentum details
    bool     momoAgainstSmc;
    
    // MTF details
    int      mtfBias;
    
    // Entry details
    double   entryPrice;
    double   slPrice;
    double   tpPrice;
    double   rrRatio;
};

//+------------------------------------------------------------------+
//| Risk Gate Result (Layer 0)                                      |
//+------------------------------------------------------------------+
struct RiskGateResult {
    bool     canTrade;          // Có được trade không?
    double   maxRiskPips;       // Số pip tối đa (từ risk %)
    double   maxLotSize;         // Lot size tối đa
    bool     tradingHalted;      // Bị halt (MDD)?
    string   reason;             // Lý do nếu canTrade = false
};

//+------------------------------------------------------------------+
//| DCA Plan Structure                                              |
//+------------------------------------------------------------------+
struct DCAPlan {
    bool     enabled;            // Có enable DCA không?
    int      maxLevels;          // Số level DCA tối đa (0, 1, 2, ...)
    
    // Level 1
    double   level1_triggerR;    // Trigger tại +XR (ví dụ: 0.75R)
    double   level1_lotMultiplier; // Lot size = original × multiplier (ví dụ: 0.5)
    
    // Level 2
    double   level2_triggerR;    // Trigger tại +XR (ví dụ: 1.5R)
    double   level2_lotMultiplier; // Lot size = original × multiplier (ví dụ: 0.33)
    
    // Level 3 (optional)
    double   level3_triggerR;
    double   level3_lotMultiplier;
    
    // Entry method cho DCA
    int      dcaEntryType;        // ENTRY_TYPE (LIMIT, STOP, MARKET) - use int to avoid dependency
    string   dcaEntryReason;     // "At current price", "At pullback", etc.
};

//+------------------------------------------------------------------+
//| Breakeven Plan Structure                                        |
//+------------------------------------------------------------------+
struct BEPlan {
    bool     enabled;            // Có enable BE không?
    double   triggerR;           // Trigger tại +XR (ví dụ: 1.0R)
    bool     moveAllPositions;   // Move tất cả positions cùng side?
    string   reason;             // "Standard BE", "Aggressive BE", etc.
};

//+------------------------------------------------------------------+
//| Trailing Stop Plan Structure                                    |
//+------------------------------------------------------------------+
struct TrailPlan {
    bool     enabled;            // Có enable trailing không?
    double   startR;             // Bắt đầu tại +XR (ví dụ: 1.0R)
    double   stepR;              // Move mỗi +XR (ví dụ: 0.5R)
    double   distanceATR;        // Distance = X × ATR (ví dụ: 2.0)
    bool     lockProfit;         // Lock profit khi trail?
    string   strategy;           // "Conservative", "Aggressive", "Dynamic"
};

//+------------------------------------------------------------------+
//| Position Plan Structure (Complete Position Management Plan)     |
//+------------------------------------------------------------------+
struct PositionPlan {
    DCAPlan  dcaPlan;            // Kế hoạch DCA
    BEPlan   bePlan;             // Kế hoạch Breakeven
    TrailPlan trailPlan;         // Kế hoạch Trailing
    
    // Method-specific settings
    string   methodName;         // "SMC", "ICT", etc.
    string   strategy;            // "Conservative", "Aggressive", etc.
    bool     syncSL;             // Sync SL cho tất cả positions?
    bool     basketTP;           // Có dùng basket TP không?
    bool     basketSL;           // Có dùng basket SL không?
};

//+------------------------------------------------------------------+
//| Method Signal Structure (Output từ Detection Layer)            |
//+------------------------------------------------------------------+
struct MethodSignal {
    bool         valid;              // Signal có hợp lệ không?
    string       methodName;         // "SMC", "ICT", etc.
    int          direction;          // 1=BUY, -1=SELL
    double       score;              // Điểm chất lượng (0-1000)
    
    // Entry calculation (tự tính trong method)
    double       entryPrice;         // Entry price
    double       slPrice;            // Stop Loss
    double       tpPrice;            // Take Profit
    double       rr;                 // Risk:Reward ratio
    
    // Entry method
    int          entryType;          // ENTRY_TYPE (LIMIT, STOP, MARKET) - use int to avoid dependency
    string       entryReason;        // "OB bottom", "FVG zone", etc.
    
    // ⭐ Kế hoạch quản lý position (tự tính trong method)
    PositionPlan positionPlan;       // DCA, BE, Trail plans
    
    // Signal details (method-specific)
    string       details;            // JSON string với thông tin chi tiết
};

//+------------------------------------------------------------------+
//| Execution Order Structure (Input cho Execution Layer)          |
//+------------------------------------------------------------------+
struct ExecutionOrder {
    int         direction;      // 1=BUY, -1=SELL
    double      entryPrice;
    double      slPrice;
    double      tpPrice;
    double      lots;
    int         entryType;      // ENTRY_TYPE (LIMIT, STOP, MARKET) - use int to avoid dependency
    string      comment;
    PositionPlan positionPlan;  // ⭐ Kế hoạch quản lý position
    ulong       ticket;          // Ticket sau khi place order
};

//+------------------------------------------------------------------+
//| Analytics Layer Data Structures                                 |
//+------------------------------------------------------------------+

// Pattern Statistics (from StatsManager)
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

// Risk Manager Data (for Dashboard)
struct RiskManagerData {
    double   maxLotPerSide;
    double   basketFloatingPL;
    double   basketFloatingPLPct;
};

// Stats Manager Data (for Dashboard)
struct StatsManagerData {
    PatternStats overall;
    PatternStats patterns[7];  // One for each PATTERN_TYPE
};

//+------------------------------------------------------------------+

