//+------------------------------------------------------------------+
//|                                                  SMC_ICT_EA.mq5 |
//|                             SMC/ICT Trading Bot v2.1              |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

#include "..\Include\detectors.mqh"
#include "..\Include\arbiter.mqh"
#include "..\Include\executor.mqh"
#include "..\Include\risk_manager.mqh"
#include "..\Include\stats_manager.mqh"
#include "..\Include\draw_debug.mqh"

//+------------------------------------------------------------------+
//| Input Parameters - Unit Convention (per fix.md)                  |
//+------------------------------------------------------------------+
input group "═══════ Unit Convention ═══════"
input int InpPointsPerPip = 10;  // Points per pip (10 or 100)
sinput string InpNote_Units = "XAUUSD: 10 points = 1 pip | Use points everywhere";
sinput string InpNote_Example = "Example: 1000 points = 100 pips | _Point = 0.001";

//+------------------------------------------------------------------+
//| Session Mode Configuration                                       |
//+------------------------------------------------------------------+
input group "═══════ Session Mode ═══════"
input TRADING_SESSION_MODE InpSessionMode = SESSION_FULL_DAY;

//+------------------------------------------------------------------+
//| Full Day Mode Settings                                           |
//+------------------------------------------------------------------+
input group "═══════ Full Day Mode ═══════"
input int InpFullDayStart = 7;    // Start hour (GMT+7)
input int InpFullDayEnd   = 23;   // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Multi-Window Mode - Window 1 (Asia)                              |
//+------------------------------------------------------------------+
input group "═══════ Window 1: Asia ═══════"
input bool InpWindow1_Enable = true;   // Enable Window 1
input int  InpWindow1_Start  = 7;      // Start hour (GMT+7)
input int  InpWindow1_End    = 11;     // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Multi-Window Mode - Window 2 (London)                            |
//+------------------------------------------------------------------+
input group "═══════ Window 2: London ═══════"
input bool InpWindow2_Enable = true;   // Enable Window 2
input int  InpWindow2_Start  = 12;     // Start hour (GMT+7)
input int  InpWindow2_End    = 16;     // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Multi-Window Mode - Window 3 (NY)                                |
//+------------------------------------------------------------------+
input group "═══════ Window 3: NY ═══════"
input bool InpWindow3_Enable = true;   // Enable Window 3
input int  InpWindow3_Start  = 18;     // Start hour (GMT+7)
input int  InpWindow3_End    = 23;     // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Market Filters                                                   |
//+------------------------------------------------------------------+
input group "═══════ Market Filters ═══════"
input int    InpSpreadMaxPts  = 500;   // Max spread (points) | ~50 pips XAUUSD
input double InpSpreadATRpct  = 0.08;  // Spread ATR% guard

//+------------------------------------------------------------------+
//| Risk Management                                                  |
//+------------------------------------------------------------------+
input group "═══════ Risk Management ═══════"
input double InpRiskPerTradePct = 0.5;   // Risk per trade (%)
input double InpMinRR           = 2.0;   // Min R:R ratio
input double InpDailyMddMax     = 8.0;   // Daily MDD limit (%)
input bool   InpUseDailyMDD     = true;  // Enable Daily MDD
input bool   InpUseEquityMDD    = true;  // Use Equity for MDD
input int    InpDailyResetHour  = 6;     // Daily reset hour (GMT+7)

//+------------------------------------------------------------------+
//| Dynamic Lot Sizing (FIXED per fix.md)                           |
//+------------------------------------------------------------------+
input group "═══════ Dynamic Lot Sizing ═══════"
input double InpLotBase         = 0.02;    // Base lot size (MINIMUM lot, always used)
input double InpLotMax          = 5.0;     // Max lot size cap
input double InpEquityPerLotInc = 1000.0;  // Equity per lot increment ($)
input double InpLotIncrement    = 0.01;    // Lot increment per step (per fix.md)
sinput string InpNote_LotSizing  = "Example: Base=0.02, Inc=$1000, Step=0.01";
sinput string InpNote_LotFormula = "Balance $1500 → 0.02 + floor(1500/1000)×0.01 = 0.03";

//+------------------------------------------------------------------+
//| SWING DETECTION (UPDATED - from update.md)                       |
//+------------------------------------------------------------------+
input group "═══════ SWING DETECTION ═══════"
input int    InpFractalK        = 5;     // Fractal Depth (K-bars left/right) - XAUUSD M30: K=5 recommended
input int    InpLookbackSwing   = 100;   // Lookback Window (bars) - M30: 100 bars = ~3 days

//+------------------------------------------------------------------+
//| BOS Detection (UPDATED - from update.md)                         |
//+------------------------------------------------------------------+
input group "═══════ BREAK OF STRUCTURE ═══════"
input double InpMinBodyATR      = 0.8;   // Min Candle Body (× ATR) - XAUUSD: 0.8 filters noise
input int    InpMinBreakPts     = 150;   // Min Break Distance (points) | ~15 pips XAUUSD
input int    InpBOS_TTL         = 60;    // BOS Time-To-Live (bars)

//+------------------------------------------------------------------+
//| BOS Retest (v2.1 - UPDATED from update.md)                       |
//+------------------------------------------------------------------+
input group "═══════ BOS Retest (v2.1) ═══════"
input bool   InpBOSTrackRetest    = true;    // Track BOS retest
input int    InpBOSRetestTolerance= 150;     // Retest zone (points) | ~15 pips XAUUSD
input int    InpBOSRetestMinGap   = 3;       // Min bars between retest

//+------------------------------------------------------------------+
//| Liquidity Sweep (UPDATED - from update.md)                       |
//+------------------------------------------------------------------+
input group "═══════ LIQUIDITY SWEEP ═══════"
input int    InpLookbackLiq     = 40;    // Lookback for Fractals (bars) - M30: 40 bars = 20h
input double InpMinWickPct      = 40.0;  // Min Wick Size (% of range) - Wick >= 40% = rejection
input int    InpSweep_TTL       = 50;    // Sweep TTL (bars)

//+------------------------------------------------------------------+
//| Order Block (UPDATED - from update.md with dynamic sizing)       |
//+------------------------------------------------------------------+
input group "═══════ ORDER BLOCK CONFIG ═══════"
input bool   InpOB_UseDynamicSize = true;     // Use ATR-Based Sizing?
input int    InpOB_MinSizePts     = 200;      // Fixed Min Size (points) | ~20 pips XAUUSD
input double InpOB_ATRMultiplier  = 0.35;     // ATR Multiplier (if dynamic=true) | ~7 pips @ ATR=20
input int    InpOB_MaxTouches     = 3;        // Max touches
input double InpOB_VolMultiplier  = 1.5;      // Min Volume (× average) - OB strength threshold
input int    InpOB_BufferInvPts   = 50;       // Invalidation Buffer (points) | ~5 pips XAUUSD
input int    InpOB_TTL            = 100;      // OB Time-To-Live (bars)

//+------------------------------------------------------------------+
//| OB Sweep Validation (v2.1 - UPDATED from update.md)              |
//+------------------------------------------------------------------+
input group "═══════ OB Sweep Validation (v2.1) ═══════"
input int    InpOBSweepMaxDist    = 500;     // Max sweep distance (points) | ~50 pips XAUUSD

//+------------------------------------------------------------------+
//| Fair Value Gap (UPDATED - from update.md)                        |
//+------------------------------------------------------------------+
input group "═══════ FAIR VALUE GAP ═══════"
input int    InpFVG_MinPts      = 100;   // Min FVG Size (points) | ~10 pips XAUUSD
input double InpFVG_FillMinPct  = 25.0;  // Min fill (%)
input double InpFVG_MitigatePct = 50.0;  // Mitigation Threshold (%) - 50% fill = partial mitigation
input double InpFVG_CompletePct = 85.0;  // Completion (%)
input int    InpFVG_BufferInvPt = 200;   // Invalidation buffer (points) | ~20 pips XAUUSD
input int    InpFVG_TTL         = 80;    // FVG Time-To-Live (bars)
input int    InpFVG_KeepSide    = 6;     // Max FVGs per side

//+------------------------------------------------------------------+
//| FVG MTF Overlap (v2.1 - UPDATED from update.md)                  |
//+------------------------------------------------------------------+
input group "═══════ FVG MTF Overlap (v2.1) ═══════"
input double InpFVGTolerance      = 200;     // Tolerance (points) | ~20 pips XAUUSD
input int    InpFVGHTFMinSize     = 800;     // HTF FVG min size (points) | ~80 pips XAUUSD

//+------------------------------------------------------------------+
//| Momentum                                                         |
//+------------------------------------------------------------------+
input group "═══════ Momentum ═══════"
input double InpMomo_MinDispATR = 0.7;   // Min displacement (ATR)
input int    InpMomo_FailBars   = 4;     // Bars to confirm/fail
input int    InpMomo_TTL        = 20;    // TTL (bars)

//+------------------------------------------------------------------+
//| Execution (UPDATED - from update.md)                             |
//+------------------------------------------------------------------+
input group "═══════ Execution ═══════"
input int    InpTriggerBodyATR  = 30;    // Trigger body (0.30 ATR)
input int    InpEntryBufferPts  = 200;   // Entry buffer (points) | ~20 pips XAUUSD
input int    InpMinStopPts      = 1000;  // Min SL distance (points) | ~100 pips XAUUSD
input int    InpOrder_TTL_Bars  = 16;    // Pending order TTL (bars)

//+------------------------------------------------------------------+
//| Fixed SL/TP Mode                                                 |
//+------------------------------------------------------------------+
input group "═══════ Fixed SL/TP Mode ═══════"
input bool   InpUseFixedSL      = false; // Use fixed SL
input int    InpFixedSL_Pips    = 100;   // Fixed SL (pips)
input bool   InpFixedTP_Enable  = false; // Use fixed TP
input int    InpFixedTP_Pips    = 200;   // Fixed TP (pips)

//+------------------------------------------------------------------+
//| DCA Configuration                                                |
//+------------------------------------------------------------------+
input group "═══════ DCA (Pyramiding) ═══════"
input bool   InpEnableDCA       = true;  // Enable DCA
input int    InpMaxDcaAddons    = 2;     // Max DCA add-ons
input double InpDcaLevel1_R     = 0.75;  // DCA #1 trigger (+XR)
input double InpDcaLevel2_R     = 1.5;   // DCA #2 trigger (+XR)
input double InpDcaSize1_Mult   = 0.5;   // DCA #1 size (× original)
input double InpDcaSize2_Mult   = 0.33;  // DCA #2 size (× original)
input bool   InpDcaCheckEquity  = true;  // Check equity health
input double InpDcaMinEquityPct = 95.0;  // Min equity %

//+------------------------------------------------------------------+
//| Breakeven                                                        |
//+------------------------------------------------------------------+
input group "═══════ Breakeven ═══════"
input bool   InpEnableBE        = true;  // Enable Breakeven
input double InpBeLevel_R       = 1.0;   // Breakeven trigger (+XR)

//+------------------------------------------------------------------+
//| Trailing Stop                                                    |
//+------------------------------------------------------------------+
input group "═══════ Trailing Stop ═══════"
input bool   InpEnableTrailing  = true;  // Enable Trailing
input double InpTrailStartR     = 1.0;   // Start at +XR
input double InpTrailStepR      = 0.5;   // Move every +XR
input double InpTrailATRMult    = 2.0;   // Distance (ATR multiple)

//+------------------------------------------------------------------+
//| Basket Management                                                |
//+------------------------------------------------------------------+
input group "═══════ Basket Management ═══════"
input double InpBasketTPPct     = 0.0;  // Basket TP (%, 0=disabled)
input double InpBasketSLPct     = 0.0;  // Basket SL (%, 0=disabled)

//+------------------------------------------------------------------+
//| Visualization                                                    |
//+------------------------------------------------------------------+
input group "═══════ Visualization ═══════"
input bool   InpShowDebugDraw   = true;  // Show debug drawings
input bool   InpShowDashboard   = true;  // Show dashboard

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CDetector*     g_detector     = NULL;
CArbiter*      g_arbiter      = NULL;
CExecutor*     g_executor     = NULL;
CRiskManager*  g_riskMgr      = NULL;
CStatsManager* g_stats        = NULL;
CDrawDebug*    g_drawer       = NULL;

// Signal cache
BOSSignal      g_lastBOS;
SweepSignal    g_lastSweep;
OrderBlock     g_lastOB;
FVGSignal      g_lastFVG;
MomentumSignal g_lastMomo;
Candidate      g_lastCandidate;

// State tracking
datetime       g_lastBarTime = 0;
datetime       g_lastOrderTime = 0;
datetime       g_lastSkipLogTime = 0;
int            g_totalTrades = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    Print("START INIT");
    Print("═══════════════════════════════════════════════════════");
    Print("SMC/ICT EA v2.1 - Initialization");
    Print("Symbol: ", _Symbol);
    Print("Timeframe: ", EnumToString(_Period));
    Print("Risk per trade: ", InpRiskPerTradePct, "%");
    Print("═══════════════════════════════════════════════════════");
    
    // ═══════════════════════════════════════════════════════════════
    // CRITICAL: Validate Fixed SL Configuration (FIX for bug-fix-sl.md)
    // ═══════════════════════════════════════════════════════════════
    if(InpUseFixedSL && InpFixedSL_Pips < 60) {
        Print("❌ ERROR: FixedSL_Pips too small: ", InpFixedSL_Pips);
        Print("   Current setting: ", InpFixedSL_Pips, " pips");
        Print("   Minimum required for XAUUSD: 60 pips");
        Print("   Recommended: 100-150 pips");
        Print("   ");
        Print("   WHY THIS IS CRITICAL:");
        Print("   - XAUUSD spread: ~35 pips (350 points)");
        Print("   - MinStopPts: ", InpMinStopPts, " points (", InpMinStopPts/10, " pips)");
        Print("   - Your FixedSL: ", InpFixedSL_Pips*10, " points (", InpFixedSL_Pips, " pips)");
        Print("   ");
        Print("   FIX OPTIONS:");
        Print("   1. Set InpFixedSL_Pips = 100 (or higher)");
        Print("   2. OR set InpUseFixedSL = false (use dynamic SL)");
        Print("   ");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // Additional validation: MinStopPts reasonable for XAUUSD
    if(InpMinStopPts < 300) {
        Print("⚠️ WARNING: MinStopPts very small for XAUUSD: ", InpMinStopPts, " points (", InpMinStopPts/10, " pips)");
        Print("   Recommended: >= 1000 points (100 pips)");
        Print("   Current spread: ~350 points (35 pips)");
    }
    
    Print("✅ Configuration validated:");
    
    // ═══════════════════════════════════════════════════════════════
    // VERSION CHECK (per fix-sl.md)
    // ═══════════════════════════════════════════════════════════════
    Print("═══════════════════════════════════");
    Print("EA VERSION CHECK");
    Print("═══════════════════════════════════");
    Print("InpMinStopPts: ", InpMinStopPts, " pts = ", InpMinStopPts/10, " pips");
    Print("InpEntryBufferPts: ", InpEntryBufferPts, " pts = ", InpEntryBufferPts/10, " pips");
    Print("──────────────────────────────────");
    if(InpMinStopPts < 1000) {
        Print("⚠️ WARNING: MinStopPts < 100 pips!");
        Print("⚠️ Recommended: 1000 pts (100 pips) for XAUUSD");
        Print("⚠️ Current setting may result in too-small SL");
    } else {
        Print("✅ MinStopPts OK: ", InpMinStopPts/10, " pips (good for XAUUSD)");
    }
    Print("═══════════════════════════════════");
    
    // ═══════════════════════════════════════════════════════════════
    // Initialize Detector
    // ═══════════════════════════════════════════════════════════════
    Print("STEP 1: Creating detector...");
    g_detector = new CDetector();
    Print("STEP 1.1: Detector created, calling Init...");
    if(!g_detector.Init(_Symbol, _Period,
                        InpFractalK, InpLookbackSwing, InpMinBodyATR, InpMinBreakPts, InpBOS_TTL,
                        InpLookbackLiq, InpMinWickPct, InpSweep_TTL,
                        InpOB_MaxTouches, InpOB_BufferInvPts, InpOB_TTL, InpOB_VolMultiplier,
                        InpFVG_MinPts, InpFVG_FillMinPct, InpFVG_MitigatePct,
                        InpFVG_CompletePct, InpFVG_BufferInvPt, InpFVG_TTL, InpFVG_KeepSide,
                        InpMomo_MinDispATR, InpMomo_FailBars, InpMomo_TTL,
                        InpBOSRetestTolerance, InpBOSRetestMinGap,
                        InpOBSweepMaxDist, InpFVGTolerance, InpFVGHTFMinSize,
                        InpOB_UseDynamicSize, InpOB_MinSizePts, InpOB_ATRMultiplier)) {
        Print("❌ ERROR: Failed to initialize detector");
        return INIT_FAILED;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Initialize Arbiter
    // ═══════════════════════════════════════════════════════════════
    g_arbiter = new CArbiter();
    if(!g_arbiter.Init(InpMinRR, InpOB_MaxTouches)) {
        Print("❌ ERROR: Failed to initialize arbiter");
        return INIT_FAILED;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Initialize Executor
    // ═══════════════════════════════════════════════════════════════
    g_executor = new CExecutor();
    if(!g_executor.Init(_Symbol, _Period,
                        InpFullDayStart, InpFullDayEnd,
                        InpSessionMode,
                        InpWindow1_Enable, InpWindow1_Start, InpWindow1_End,
                        InpWindow2_Enable, InpWindow2_Start, InpWindow2_End,
                        InpWindow3_Enable, InpWindow3_Start, InpWindow3_End,
                        InpSpreadMaxPts, InpSpreadATRpct,
                        InpTriggerBodyATR, InpEntryBufferPts, InpMinStopPts,
                        InpOrder_TTL_Bars, InpMinRR,
                        InpUseFixedSL, InpFixedSL_Pips, InpFixedTP_Enable, InpFixedTP_Pips)) {
        Print("❌ ERROR: Failed to initialize executor");
        return INIT_FAILED;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Initialize Risk Manager
    // ═══════════════════════════════════════════════════════════════
    g_riskMgr = new CRiskManager();
    if(!g_riskMgr.Init(_Symbol,
                       InpLotBase, InpLotMax, InpEquityPerLotInc, InpLotIncrement,
                       InpEnableDCA, InpDcaLevel1_R, InpDcaLevel2_R,
                       InpDcaSize1_Mult, InpDcaSize2_Mult, InpMaxDcaAddons,
                       InpDcaCheckEquity, InpDcaMinEquityPct,
                       InpEnableBE, InpBeLevel_R,
                       InpEnableTrailing, InpTrailStartR, InpTrailStepR, InpTrailATRMult,
                       InpUseDailyMDD, InpDailyMddMax, InpUseEquityMDD, InpDailyResetHour,
                       InpBasketTPPct, InpBasketSLPct)) {
        Print("❌ ERROR: Failed to initialize risk manager");
        return INIT_FAILED;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Initialize Stats
    // ═══════════════════════════════════════════════════════════════
    g_stats = new CStatsManager();
    if(!g_stats.Init(_Symbol, 500)) {
        Print("❌ ERROR: Failed to initialize stats");
        return INIT_FAILED;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Initialize Dashboard
    // ═══════════════════════════════════════════════════════════════
    Print("📊 Dashboard Settings: ShowDebugDraw=", InpShowDebugDraw, " ShowDashboard=", InpShowDashboard);
    
    if(InpShowDebugDraw || InpShowDashboard) {
        g_drawer = new CDrawDebug();
        if(CheckPointer(g_drawer) == POINTER_DYNAMIC) {
            if(!g_drawer.Init("SMC")) {
                Print("⚠️ WARNING: Failed to initialize drawer");
            } else {
                Print("✅ Dashboard initialized - will display on first tick");
            }
        } else {
            Print("❌ Failed to create drawer object");
        }
    } else {
        Print("⚠️ Dashboard DISABLED by user settings");
    }
    
    // ═══════════════════════════════════════════════════════════════
    // Initialize state
    // ═══════════════════════════════════════════════════════════════
    g_lastBOS.valid = false;
    g_lastSweep.valid = false;
    g_lastOB.valid = false;
    g_lastFVG.valid = false;
    g_lastMomo.valid = false;
    g_lastCandidate.valid = false;
    
    g_lastBarTime = iTime(_Symbol, _Period, 0);
    g_lastOrderTime = 0;
    g_totalTrades = 0;
    
    Print("═══════════════════════════════════════════════════════");
    Print("✅ Initialization completed successfully");
    Print("═══════════════════════════════════════════════════════");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Cleanup objects
    ObjectDelete(0, "SMC_Dashboard");
    ObjectDelete(0, "SMC_TestLabel");
    
    if(CheckPointer(g_detector) == POINTER_DYNAMIC) delete g_detector;
    if(CheckPointer(g_arbiter) == POINTER_DYNAMIC) delete g_arbiter;
    if(CheckPointer(g_executor) == POINTER_DYNAMIC) delete g_executor;
    if(CheckPointer(g_riskMgr) == POINTER_DYNAMIC) delete g_riskMgr;
    if(CheckPointer(g_stats) == POINTER_DYNAMIC) delete g_stats;
    if(CheckPointer(g_drawer) == POINTER_DYNAMIC) delete g_drawer;
    
    Print("EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // ═══════════════════════════════════════════════════════════════
    // STEP 0: UPDATE DASHBOARD FIRST (before any returns)
    // ═══════════════════════════════════════════════════════════════
    static int tickCount = 0;
    tickCount++;
    
    // Safe checks with null pointer validation
    bool sessionOpen = (CheckPointer(g_executor) == POINTER_DYNAMIC) ? g_executor.SessionOpen() : false;
    bool spreadOK = (CheckPointer(g_executor) == POINTER_DYNAMIC) ? g_executor.SpreadOK() : false;
    bool tradingHalted = (CheckPointer(g_riskMgr) == POINTER_DYNAMIC) ? g_riskMgr.IsTradingHalted() : false;
    
    // Determine status
    string status = "SCANNING";
    
    if(tradingHalted) {
        status = "HALTED - MDD";
    } else if(!sessionOpen) {
        status = "OUT OF SESSION";
    } else if(!spreadOK) {
        status = "SPREAD WIDE";
    } else if(g_lastCandidate.valid && g_lastCandidate.score >= 100.0) {
        status = "SIGNAL VALID";
    } else if(g_lastBOS.valid) {
        status = "BOS DETECTED";
    }
    
    // Update dashboard EVERY TICK
    if(InpShowDashboard && CheckPointer(g_drawer) == POINTER_DYNAMIC && CheckPointer(g_executor) == POINTER_DYNAMIC) {
        string sessionInfo = g_executor.GetActiveWindow();
        double score = g_lastCandidate.valid ? g_lastCandidate.score : 0;
        g_drawer.UpdateDashboard(status, g_riskMgr, sessionInfo, score,
                                g_lastBOS, g_lastSweep, g_lastOB, g_lastFVG, g_stats);
    } else {
        // Log why dashboard not updating (once)
        static bool loggedWhy = false;
        if(!loggedWhy && tickCount == 1) {
            Print("⚠️ Dashboard NOT updating:");
            Print("  InpShowDashboard=", InpShowDashboard);
            Print("  g_drawer valid=", CheckPointer(g_drawer) == POINTER_DYNAMIC);
            Print("  g_executor valid=", CheckPointer(g_executor) == POINTER_DYNAMIC);
            loggedWhy = true;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Check for new bar
    // ═══════════════════════════════════════════════════════════════
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    bool newBar = (currentBarTime != g_lastBarTime);
    if(newBar) {
        g_lastBarTime = currentBarTime;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Pre-checks (session, spread, MDD, rollover)
    // ═══════════════════════════════════════════════════════════════
    if(!sessionOpen) {
        // Still manage existing positions outside session
        if(CheckPointer(g_riskMgr) == POINTER_DYNAMIC) g_riskMgr.ManageOpenPositions();
        if(CheckPointer(g_executor) == POINTER_DYNAMIC) g_executor.ManagePendingOrders();
        return;
    }
    
    if(!spreadOK) {
        if(CheckPointer(g_riskMgr) == POINTER_DYNAMIC) g_riskMgr.ManageOpenPositions();
        if(CheckPointer(g_executor) == POINTER_DYNAMIC) g_executor.ManagePendingOrders();
        return;
    }
    
    if(tradingHalted) {
        return;
    }
    
    if(g_executor.IsRolloverTime()) {
        return;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Update price series
    // ═══════════════════════════════════════════════════════════════
    g_detector.UpdateSeries();
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Run detectors (on new bar or if invalid)
    // ═══════════════════════════════════════════════════════════════
    if(newBar || !g_lastBOS.valid) {
        g_lastBOS = g_detector.DetectBOS();
        
        // v2.1: Update BOS retest tracking
        if(g_lastBOS.valid && InpBOSTrackRetest) {
            g_detector.UpdateBOSRetest(g_lastBOS);
        }
        
        if(g_lastBOS.valid && InpShowDebugDraw && CheckPointer(g_drawer) == POINTER_DYNAMIC) {
            g_drawer.MarkBOS(0, g_lastBOS.direction, g_lastBOS.breakLevel,
                           TimeToString(TimeCurrent()));
        }
    }
    
    if(newBar || !g_lastSweep.valid) {
        g_lastSweep = g_detector.DetectSweep();
        
        if(g_lastSweep.detected && InpShowDebugDraw && CheckPointer(g_drawer) == POINTER_DYNAMIC) {
            g_drawer.MarkSweep(g_lastSweep.level, g_lastSweep.side,
                             g_lastSweep.time, TimeToString(TimeCurrent()));
        }
    }
    
    // Get OB and FVG based on BOS direction
    if(g_lastBOS.valid) {
        // v2.1: Use FindOBWithSweep for sweep validation
        g_lastOB = g_detector.FindOBWithSweep(g_lastBOS.direction, g_lastSweep);
        
        if(g_lastOB.valid && InpShowDebugDraw && CheckPointer(g_drawer) == POINTER_DYNAMIC && newBar) {
            g_drawer.DrawOB(g_lastOB.priceTop, g_lastOB.priceBottom, g_lastOB.direction,
                          g_lastOB.createdTime, TimeToString(TimeCurrent()));
        }
        
        g_lastFVG = g_detector.FindFVG(g_lastBOS.direction);
        
        // v2.1: Check FVG MTF overlap
        if(g_lastFVG.valid) {
            g_detector.CheckFVGMTFOverlap(g_lastFVG);
        }
        
        if(g_lastFVG.valid && InpShowDebugDraw && CheckPointer(g_drawer) == POINTER_DYNAMIC && newBar) {
            g_drawer.DrawFVG(g_lastFVG.priceTop, g_lastFVG.priceBottom, g_lastFVG.direction,
                           g_lastFVG.state, g_lastFVG.createdTime, TimeToString(TimeCurrent()));
        }
    }
    
    if(newBar) {
        g_lastMomo = g_detector.DetectMomentum();
    }
    
    // Get MTF bias
    int mtfBias = g_detector.GetMTFBias();
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 5: Build candidate
    // ═══════════════════════════════════════════════════════════════
    g_lastCandidate = g_arbiter.BuildCandidate(g_lastBOS, g_lastSweep, g_lastOB,
                                               g_lastFVG, g_lastMomo, mtfBias,
                                               g_executor.SessionOpen(), g_executor.SpreadOK());
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 6: Score and validate
    // ═══════════════════════════════════════════════════════════════
    if(g_lastCandidate.valid) {
        double score = g_arbiter.ScoreCandidate(g_lastCandidate);
        g_lastCandidate.score = score;
        
        if(score >= 100.0) {
            // ═══════════════════════════════════════════════════════
            // STEP 7: Look for trigger candle
            // ═══════════════════════════════════════════════════════
            double triggerHigh = 0, triggerLow = 0;
            
            // v2.1: Determine entry method
            EntryConfig entryConfig = g_arbiter.DetermineEntryMethod(g_lastCandidate);
            
            // For STOP orders, need trigger candle
            bool needTrigger = (entryConfig.type == ENTRY_STOP);
            
            // For LIMIT orders, use current price as fallback
            if(!needTrigger) {
                triggerHigh = iHigh(_Symbol, _Period, 0);
                triggerLow = iLow(_Symbol, _Period, 0);
            }
            
            if(!needTrigger || g_executor.GetTriggerCandle(g_lastCandidate.direction,
                                                          triggerHigh, triggerLow)) {
                
                // ═══════════════════════════════════════════════
                // STEP 8: Calculate entry, SL, TP
                // ═══════════════════════════════════════════════
                double entry, sl, tp, rr;
                if(g_executor.CalculateEntry(g_lastCandidate, triggerHigh, triggerLow,
                                            entry, sl, tp, rr)) {
                    
                    // ═══════════════════════════════════════════
                    // STEP 9: Calculate position size
                    // ═══════════════════════════════════════════
                    double slDistance = MathAbs(entry - sl) / _Point;
                    double lots = g_riskMgr.CalcLotsByRisk(InpRiskPerTradePct, slDistance);
                    
                    // ═══════════════════════════════════════════
                    // STEP 10: Check lot limits
                    // ═══════════════════════════════════════════
                    double maxLotAllowed = g_riskMgr.GetMaxLotPerSide();
                    if(lots > maxLotAllowed) {
                        lots = maxLotAllowed;
                        Print("⚠️ Lot capped to MaxLotPerSide: ", maxLotAllowed);
                    }
                    
                    // ═══════════════════════════════════════════
                    // STEP 11: Check existing SAME DIRECTION positions/orders
                    // ═══════════════════════════════════════════
                    int sameDirPositions = 0;
                    int sameDirPendingOrders = 0;
                    
                    // Count positions in SAME direction ONLY
                    for(int i = 0; i < PositionsTotal(); i++) {
                        ulong ticket = PositionGetTicket(i);
                        if(PositionSelectByTicket(ticket)) {
                            if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
                                long posType = PositionGetInteger(POSITION_TYPE);
                                int posDir = (posType == POSITION_TYPE_BUY) ? 1 : -1;
                                if(posDir == g_lastCandidate.direction) {
                                    sameDirPositions++;
                                }
                            }
                        }
                    }
                    
                    // Count pending orders in SAME direction ONLY
                    for(int i = 0; i < OrdersTotal(); i++) {
                        ulong ticket = OrderGetTicket(i);
                        if(OrderGetString(ORDER_SYMBOL) == _Symbol) {
                            long orderType = OrderGetInteger(ORDER_TYPE);
                            bool isSameDir = false;
                            
                            if(g_lastCandidate.direction == 1 &&
                               (orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT)) {
                                isSameDir = true;
                            }
                            if(g_lastCandidate.direction == -1 &&
                               (orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_LIMIT)) {
                                isSameDir = true;
                            }
                            
                            if(isSameDir) sameDirPendingOrders++;
                        }
                    }
                    
                    // ═══════════════════════════════════════════
                    // STEP 12: One-trade-per-bar protection (DISABLED for v2.1)
                    // Allow multiple orders per bar
                    // ═══════════════════════════════════════════
                    // bool alreadyTradedThisBar = (g_lastOrderTime == currentBarTime);
                    
                    // ═══════════════════════════════════════════
                    // STEP 13: Place order if all checks pass (SAME DIRECTION)
                    // ═══════════════════════════════════════════
                    if(sameDirPositions == 0 && sameDirPendingOrders == 0) {
                        
                        int patternType = g_arbiter.GetPatternType(g_lastCandidate);
                        string patternName = g_stats.GetPatternName(patternType);
                        
                        string comment = StringFormat("SMC_%s_%s_RR%.1f",
                                                     g_lastCandidate.direction == 1 ? "BUY" : "SELL",
                                                     patternName,
                                                     rr);
                        
                        bool orderPlaced = false;
                        
                        // v2.1: Place order based on entry method
                        if(entryConfig.type == ENTRY_LIMIT) {
                            orderPlaced = g_executor.PlaceLimitOrder(g_lastCandidate.direction,
                                                                    g_lastCandidate,
                                                                    sl, tp, lots, comment);
                        } else {
                            orderPlaced = g_executor.PlaceStopOrder(g_lastCandidate.direction,
                                                                   entry, sl, tp, lots, comment);
                        }
                        
                        if(orderPlaced) {
                            g_totalTrades++;
                            g_lastOrderTime = currentBarTime;
                            
                            Print("═══════════════════════════════════════════");
                            Print("📊 TRADE #", g_totalTrades, " PLACED");
                            Print("   Direction: ", g_lastCandidate.direction == 1 ? "BUY" : "SELL");
                            Print("   Pattern: ", patternName);
                            Print("   Entry Method: ", entryConfig.reason);
                            Print("   Entry: ", entry);
                            Print("   SL: ", sl, " | TP: ", tp);
                            Print("   R:R: ", DoubleToString(rr, 2));
                            Print("   Lots: ", lots);
                            Print("   Score: ", DoubleToString(score, 1));
                            Print("═══════════════════════════════════════════");
                        }
                    } else {
                        // Log why skipped (once per bar)
                        if(g_lastSkipLogTime != currentBarTime) {
                            g_lastSkipLogTime = currentBarTime;
                            
                            string dirStr = (g_lastCandidate.direction == 1) ? "LONG" : "SHORT";
                            
                            if(sameDirPositions > 0) {
                                Print("⊘ ", dirStr, " entry skipped: Already have ", sameDirPositions, " ", dirStr, " position(s)");
                            }
                            if(sameDirPendingOrders > 0) {
                                Print("⊘ ", dirStr, " entry skipped: Already have ", sameDirPendingOrders, " ", dirStr, " pending order(s)");
                            }
                            // One-trade-per-bar check removed in v2.1
                        }
                    }
                }
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 14: Manage existing positions (BE, Trail, DCA)
    // ═══════════════════════════════════════════════════════════════
    if(CheckPointer(g_riskMgr) == POINTER_DYNAMIC) {
        g_riskMgr.ManageOpenPositions();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 15: Manage pending orders (TTL)
    // ═══════════════════════════════════════════════════════════════
    if(CheckPointer(g_executor) == POINTER_DYNAMIC) {
        g_executor.ManagePendingOrders();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 16: Cleanup old objects periodically
    // ═══════════════════════════════════════════════════════════════
    if(newBar && g_totalTrades % 10 == 0) {
        if(CheckPointer(g_drawer) == POINTER_DYNAMIC) {
            g_drawer.CleanupOldObjects();
        }
    }
}

//+------------------------------------------------------------------+
//| Trade transaction function                                       |
//+------------------------------------------------------------------+
void OnTrade() {
    // ═══════════════════════════════════════════════════════════════
    // PART 1: Track new filled positions
    // ═══════════════════════════════════════════════════════════════
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
                string comment = PositionGetString(POSITION_COMMENT);
                
                // Skip DCA positions (already tracked via original)
                if(StringFind(comment, "DCA Add-on") >= 0) {
                    continue;
                }
                
                double entry = PositionGetDouble(POSITION_PRICE_OPEN);
                double sl = PositionGetDouble(POSITION_SL);
                double tp = PositionGetDouble(POSITION_TP);
                double lots = PositionGetDouble(POSITION_VOLUME);
                
                // Track in risk manager
                g_riskMgr.TrackPosition(ticket, entry, sl, tp, lots);
                
                // Record in stats
                long posType = PositionGetInteger(POSITION_TYPE);
                int direction = (posType == POSITION_TYPE_BUY) ? 1 : -1;
                int patternType = g_arbiter.GetPatternType(g_lastCandidate);
                
                g_stats.RecordTrade(ticket, direction, entry, lots, patternType, sl, tp);
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PART 2: Update stats for closed positions
    // ═══════════════════════════════════════════════════════════════
    if(HistorySelect(TimeCurrent() - 86400, TimeCurrent())) {
        for(int i = HistoryDealsTotal() - 1; i >= 0; i--) {
            ulong dealTicket = HistoryDealGetTicket(i);
            if(dealTicket > 0) {
                string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                if(symbol == _Symbol) {
                    long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                    if(dealEntry == DEAL_ENTRY_OUT) {
                        ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                        double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                        
                        g_stats.UpdateClosedTrade(posTicket, closePrice, profit);
                    }
                }
            }
        }
    }
}

