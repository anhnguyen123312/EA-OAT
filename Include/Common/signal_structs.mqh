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
//| Order Type Enum (MT5 Order Types - Mỗi lệnh chỉ là 1 loại)      |
//+------------------------------------------------------------------+
enum ENUM_ORDER_TYPE {
    // Market Orders (Thực hiện ngay tại giá thị trường)
    ORDER_BUY = 0,              // ORDER_TYPE_BUY - Mua ngay tại giá thị trường
    ORDER_SELL = 1,             // ORDER_TYPE_SELL - Bán ngay tại giá thị trường
    
    // Limit Orders (Chờ hồi về)
    ORDER_BUY_LIMIT = 2,        // ORDER_TYPE_BUY_LIMIT - Mua khi giá giảm xuống một mức thấp hơn giá hiện tại (chờ hồi về)
    ORDER_SELL_LIMIT = 3,       // ORDER_TYPE_SELL_LIMIT - Bán khi giá tăng lên một mức cao hơn giá hiện tại (chờ hồi về)
    
    // Stop Orders (Chờ phá vỡ)
    ORDER_BUY_STOP = 4,         // ORDER_TYPE_BUY_STOP - Mua khi giá tăng vượt qua một mức cao hơn giá hiện tại (chờ phá vỡ)
    ORDER_SELL_STOP = 5,        // ORDER_TYPE_SELL_STOP - Bán khi giá giảm xuống dưới một mức thấp hơn giá hiện tại (chờ phá vỡ)
    
    // Stop Limit Orders (Kết hợp Stop và Limit)
    ORDER_BUY_STOP_LIMIT = 6,   // ORDER_TYPE_BUY_STOP_LIMIT - Đặt lệnh Buy Stop, và khi lệnh Buy Stop kích hoạt, nó sẽ đặt tiếp lệnh Buy Limit ở mức giá mong muốn
    ORDER_SELL_STOP_LIMIT = 7   // ORDER_TYPE_SELL_STOP_LIMIT - Đặt lệnh Sell Stop, và khi lệnh Sell Stop kích hoạt, nó sẽ đặt tiếp lệnh Sell Limit ở mức giá mong muốn
};

//+------------------------------------------------------------------+
//| Entry Method Types (Simplified)                                  |
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
    
    // ⭐ Position tracking (NEW)
    double   filledRiskPips;    // Số pip đã vào lệnh (filled positions)
    double   filledLotSize;     // Số lot đã vào lệnh (filled positions)
    double   pendingRiskPips;    // Số pip đang trong lệnh chờ (pending orders)
    double   pendingLotSize;    // Số lot đang trong lệnh chờ (pending orders)
    
    // Calculated remaining
    double   remainingRiskPips; // Số pip còn lại có thể risk = maxRiskPips - filledRiskPips - pendingRiskPips
    double   remainingLotSize;  // Số lot còn lại = maxLotSize - filledLotSize - pendingLotSize
};

//+------------------------------------------------------------------+
//| DCA Order Structure (Chi tiết từng DCA order)                   |
//+------------------------------------------------------------------+
struct DCAOrder {
    int      level;              // DCA level (1, 2, 3)
    ENUM_ORDER_TYPE orderType;   // ⭐ ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, etc. (Mỗi lệnh chỉ là 1 loại)
    ENTRY_TYPE entryType;        // ⭐ ENTRY_TYPE (LIMIT, STOP, MARKET) - Simplified version
    string   reason;             // "OB + FVG", "At current price", etc.
    double   entryPrice;         // Entry price
    double   slPrice;            // Stop Loss (sync với original)
    double   tpPrice;            // Take Profit (sync với original)
    double   lotMultiplier;      // Lot multiplier (0.5, 0.33, etc.)
    double   triggerR;           // Trigger tại +XR (0.75R, 1.5R, etc.)
};

//+------------------------------------------------------------------+
//| DCA Plan Structure                                              |
//+------------------------------------------------------------------+
struct DCAPlan {
    bool     enabled;            // Có enable DCA không?
    int      maxLevels;          // Số level DCA tối đa (0, 1, 2, ...)
    
    // ⭐ DCA Orders Array (chi tiết từng DCA order)
    DCAOrder dcaOrders[];        // Array of DCA orders
    
    // Level 1 (backward compatibility)
    double   level1_triggerR;    // Trigger tại +XR (ví dụ: 0.75R)
    double   level1_lotMultiplier; // Lot size = original × multiplier (ví dụ: 0.5)
    
    // Level 2 (backward compatibility)
    double   level2_triggerR;    // Trigger tại +XR (ví dụ: 1.5R)
    double   level2_lotMultiplier; // Lot size = original × multiplier (ví dụ: 0.33)
    
    // Level 3 (optional)
    double   level3_triggerR;
    double   level3_lotMultiplier;
    
    // Entry method cho DCA
    ENTRY_TYPE dcaEntryType;      // ⭐ ENTRY_TYPE (LIMIT, STOP, MARKET)
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
    double   startPrice;         // ⭐ Start price (khi bắt đầu BE, ví dụ: 4260)
    double   startR;             // Bắt đầu tại +XR (ví dụ: 1.0R)
    double   stepPips;           // ⭐ Move mỗi X pips (ví dụ: 30 pips)
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
    ENUM_ORDER_TYPE orderType;       // ⭐ ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, ORDER_SELL_LIMIT, ORDER_BUY_STOP, ORDER_SELL_STOP, ORDER_BUY_STOP_LIMIT, ORDER_SELL_STOP_LIMIT
    double       score;              // Điểm chất lượng (0-1000)
    
    // Entry calculation (tự tính trong method)
    double       entryPrice;         // Entry price (EN)
    double       slPrice;            // Stop Loss (SL)
    double       tpPrice;            // Take Profit (TP)
    double       rr;                 // Risk:Reward ratio
    
    // Entry method (simplified - backward compatibility)
    ENTRY_TYPE   entryType;          // ⭐ ENTRY_TYPE (LIMIT, STOP, MARKET) - Simplified version
    string       entryReason;        // "OB bottom", "FVG zone", etc.
    
    // ⭐ Kế hoạch quản lý position (tự tính trong method)
    PositionPlan positionPlan;       // DCA, BE, Trail plans
    
    // Signal details (method-specific)
    string       details;            // JSON string với thông tin chi tiết
};

//+------------------------------------------------------------------+
//| Order Status Enum                                                |
//+------------------------------------------------------------------+
enum ENUM_ORDER_STATUS {
    ORDER_STATUS_PENDING = 0,   // Đang chờ execution
    ORDER_STATUS_FILLED = 1,    // Đã filled
    ORDER_STATUS_CANCELLED = 2, // Đã cancel
    ORDER_STATUS_EXPIRED = 3   // Đã expire
};

//+------------------------------------------------------------------+
//| Pending Order Structure (Array chờ execution)                   |
//+------------------------------------------------------------------+
struct PendingOrder {
    // ⭐ ID tracking
    string      orderID;         // Unique ID để tracking (format: "SMC_20250121_001")
    datetime    createdTime;     // Thời gian tạo order
    
    // Order information
    string      methodName;      // "SMC", "ICT", etc.
    ENUM_ORDER_TYPE orderType;   // ⭐ ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, etc. (Mỗi lệnh chỉ là 1 loại)
    ENTRY_TYPE entryType;        // ⭐ ENTRY_TYPE (LIMIT, STOP, MARKET) - Simplified version
    string      reason;          // "OB + FVG", etc.
    double      entryPrice;      // Entry price (EN)
    double      slPrice;         // Stop Loss (SL)
    double      tpPrice;         // Take Profit (TP)
    double      lots;            // Lot size
    
    // DCA information (nếu là DCA order)
    bool        isDCA;           // Có phải DCA order không?
    int         dcaLevel;        // DCA level (1, 2, 3) - 0 = original
    string      parentOrderID;   // ID của order gốc (nếu là DCA)
    
    // Position management
    double      bePrice;         // Breakeven price (khi trigger BE)
    TrailPlan   trailPlan;       // Trailing stop plan
    
    // Status
    ENUM_ORDER_STATUS status;   // Order status
    ulong       ticket;          // MT5 ticket (sau khi place order)
    
    // Position plan reference
    PositionPlan positionPlan;   // Full position plan
};

//+------------------------------------------------------------------+
//| Execution Order Structure (Đã được execution)                  |
//+------------------------------------------------------------------+
struct ExecutionOrder {
    // ⭐ ID tracking
    string      orderID;         // Unique ID (same as PendingOrder)
    datetime    createdTime;     // Thời gian tạo order
    datetime    filledTime;      // Thời gian filled
    
    // Order information
    string      methodName;      // "SMC", "ICT", etc.
    ENUM_ORDER_TYPE orderType;   // ⭐ ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, etc. (Mỗi lệnh chỉ là 1 loại)
    ENTRY_TYPE entryType;        // ⭐ ENTRY_TYPE - Simplified version
    string      reason;          // Entry reason
    double      entryPrice;      // Entry price (filled)
    double      slPrice;         // Stop Loss
    double      tpPrice;         // Take Profit
    double      lots;            // Lot size (filled)
    
    // DCA information
    bool        isDCA;           // Có phải DCA order không?
    int         dcaLevel;        // DCA level (0 = original, 1/2/3 = DCA)
    string      parentOrderID;   // ID của order gốc
    
    // Position management
    double      bePrice;         // Breakeven price
    bool        beTriggered;      // BE đã trigger chưa?
    TrailPlan   trailPlan;       // Trailing stop plan
    double      currentSL;        // Current SL (có thể đã move)
    
    // MT5 tracking
    ulong       ticket;          // MT5 ticket
    bool        isOpen;           // Position còn mở không?
    
    // Position plan reference
    PositionPlan positionPlan;   // Full position plan
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

