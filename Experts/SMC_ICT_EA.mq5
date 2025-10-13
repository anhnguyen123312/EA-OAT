//+------------------------------------------------------------------+
//|                                                   SMC_ICT_EA.mq5 |
//|                              SMC/ICT Trading System for XAUUSD   |
//|                              Spec v1.0 - Full Implementation     |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property link      ""
#property version   "1.00"
#property strict

#include <detectors.mqh>
#include <arbiter.mqh>
#include <executor.mqh>
#include <risk_manager.mqh>
#include <draw_debug.mqh>

//+------------------------------------------------------------------+
//| Input Parameters - Unit Convention                              |
//+------------------------------------------------------------------+
input group "═══════ Unit Convention ═══════"
input int      InpPointsPerPip = 10;         // Points per pip (10 or 100 depending on broker)

//+------------------------------------------------------------------+
//| Input Parameters - Session & Market                             |
//+------------------------------------------------------------------+
input group "═══════ Session & Market ═══════"
input string   InpTZ              = "Asia/Ho_Chi_Minh";  // Timezone (GMT+7)
input int      InpSessStartHour   = 6;                   // Session start hour
input int      InpSessEndHour     = 5;                  // Session end hour
input int      InpSpreadMaxPts    = 500;                 // Max spread (points)

//+------------------------------------------------------------------+
//| Input Parameters - Risk & DCA                                   |
//+------------------------------------------------------------------+
input group "═══════ Risk Management ═══════"
input double   InpRiskPerTradePct = 3;     // Risk per trade (% equity)
input double   InpMinRR           = 2.0;     // Minimum R:R ratio
input double   InpMaxLotPerSide   = 3.0;     // Max lots per side
input int      InpMaxDcaAddons    = 2;       // Max DCA add-ons
input double   InpDailyMddMax     = 8.0;     // Daily MDD limit (%)

//+------------------------------------------------------------------+
//| Input Parameters - BOS Detection                                |
//+------------------------------------------------------------------+
input group "═══════ BOS/CHOCH Detection ═══════"
input int      InpFractalK        = 3;       // Fractal K for swings
input int      InpLookbackSwing   = 50;      // Lookback for swing detection (bars)
input double   InpMinBodyATR      = 0.6;     // Min body size (ATR multiple)
input int      InpMinBreakPts     = 50;      // Min break distance (points)
input int      InpBOS_TTL         = 40;      // BOS TTL (bars)

//+------------------------------------------------------------------+
//| Input Parameters - Liquidity Sweep                              |
//+------------------------------------------------------------------+
input group "═══════ Liquidity Sweep ═══════"
input int      InpLookbackLiq     = 30;      // Lookback for liquidity (bars)
input double   InpMinWickPct      = 35.0;    // Min wick percentage
input int      InpSweep_TTL       = 20;      // Sweep TTL (bars)

//+------------------------------------------------------------------+
//| Input Parameters - Order Block                                  |
//+------------------------------------------------------------------+
input group "═══════ Order Block ═══════"
input int      InpOB_MaxTouches   = 3;       // Max touches before invalid
input int      InpOB_BufferInvPts = 50;      // Buffer for invalidation (points)
input int      InpOB_TTL          = 120;     // OB TTL (bars)

//+------------------------------------------------------------------+
//| Input Parameters - Fair Value Gap                               |
//+------------------------------------------------------------------+
input group "═══════ Fair Value Gap ═══════"
input int      InpFVG_MinPts      = 150;     // Min FVG size (points)
input double   InpFVG_FillMinPct  = 25.0;    // Min fill to track (%)
input double   InpFVG_MitigatePct = 35.0;    // Mitigation threshold (%)
input double   InpFVG_CompletePct = 85.0;    // Completion threshold (%)
input int      InpFVG_BufferInvPt = 50;      // Buffer for invalidation (points)
input int      InpFVG_TTL         = 60;      // FVG TTL (bars)
input int      InpK_FVG_KeepSide  = 6;       // Max FVGs to keep per side

//+------------------------------------------------------------------+
//| Input Parameters - Momentum (Optional)                          |
//+------------------------------------------------------------------+
input group "═══════ Momentum Breakout ═══════"
input double   InpMomo_MinDispATR = 0.7;     // Min displacement (ATR multiple)
input int      InpMomo_FailBars   = 4;       // Bars to confirm or fail
input int      InpMomo_TTL        = 20;      // Momentum TTL (bars)

//+------------------------------------------------------------------+
//| Input Parameters - Execution                                    |
//+------------------------------------------------------------------+
input group "═══════ Execution ═══════"
input int      InpTriggerBodyATR  = 40;      // Trigger body size (0.40 ATR, x100)
input int      InpEntryBufferPts  = 70;      // Entry buffer (points)
input int      InpMinStopPts      = 300;     // Min stop distance (points)
input int      InpOrder_TTL_Bars  = 20;      // Pending order TTL (bars)

//+------------------------------------------------------------------+
//| Input Parameters - Visualization                                |
//+------------------------------------------------------------------+
input group "═══════ Visualization ═══════"
input bool     InpShowDebugDraw   = true;    // Show debug drawings
input bool     InpShowDashboard   = true;    // Show dashboard

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CDetector      *g_detector = NULL;
CArbiter       *g_arbiter = NULL;
CExecutor      *g_executor = NULL;
CRiskManager   *g_riskMgr = NULL;
CDrawDebug     *g_drawer = NULL;

// State tracking
BOSSignal      g_lastBOS;
SweepSignal    g_lastSweep;
OrderBlock     g_lastOB;
FVGSignal      g_lastFVG;
MomentumSignal g_lastMomo;
Candidate      g_lastCandidate;

datetime       g_lastBarTime = 0;
int            g_totalTrades = 0;

//+------------------------------------------------------------------+
//| Macros for unit conversion                                       |
//+------------------------------------------------------------------+
#define PIP(p)           ((p) * InpPointsPerPip * _Point)
#define POINTS(n)        ((n) * _Point)
#define PRICE_UNIT(n)    ((n) * 1000 * _Point)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    Print("═══════════════════════════════════════════════");
    Print("  SMC/ICT EA v1.0 - Initialization");
    Print("═══════════════════════════════════════════════");
    Print("Symbol: ", _Symbol);
    Print("Timeframe: ", EnumToString(_Period));
    Print("Risk per trade: ", InpRiskPerTradePct, "%");
    Print("Min R:R: ", InpMinRR);
    Print("Daily MDD limit: ", InpDailyMddMax, "%");
    Print("═══════════════════════════════════════════════");
    
    // Initialize components
    g_detector = new CDetector();
    if(!g_detector.Init(_Symbol, _Period,
                        InpFractalK, InpLookbackSwing, InpMinBodyATR, InpMinBreakPts, InpBOS_TTL,
                        InpLookbackLiq, InpMinWickPct, InpSweep_TTL,
                        InpOB_MaxTouches, InpOB_BufferInvPts, InpOB_TTL,
                        InpFVG_MinPts, InpFVG_FillMinPct, InpFVG_MitigatePct, InpFVG_CompletePct, 
                        InpFVG_BufferInvPt, InpFVG_TTL, InpK_FVG_KeepSide,
                        InpMomo_MinDispATR, InpMomo_FailBars, InpMomo_TTL)) {
        Print("ERROR: Failed to initialize detector");
        return INIT_FAILED;
    }
    
    g_arbiter = new CArbiter();
    g_arbiter.Init(InpMinRR, InpOB_MaxTouches);
    
    g_executor = new CExecutor();
    if(!g_executor.Init(_Symbol, _Period,
                        InpSessStartHour, InpSessEndHour, InpSpreadMaxPts,
                        InpTriggerBodyATR, InpEntryBufferPts, InpMinStopPts, 
                        InpOrder_TTL_Bars, InpMinRR)) {
        Print("ERROR: Failed to initialize executor");
        return INIT_FAILED;
    }
    
    g_riskMgr = new CRiskManager();
    g_riskMgr.Init(_Symbol, InpRiskPerTradePct, InpMaxLotPerSide, InpMaxDcaAddons, InpDailyMddMax);
    
    if(InpShowDebugDraw || InpShowDashboard) {
        g_drawer = new CDrawDebug();
        g_drawer.Init("SMC");
    }
    
    // Initialize state
    g_lastBOS.valid = false;
    g_lastSweep.valid = false;
    g_lastOB.valid = false;
    g_lastFVG.valid = false;
    g_lastMomo.valid = false;
    g_lastCandidate.valid = false;
    
    g_lastBarTime = iTime(_Symbol, _Period, 0);
    
    Print("Initialization completed successfully");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("EA deinitialization - Reason: ", reason);
    
    // Cleanup
    if(g_detector != NULL) delete g_detector;
    if(g_arbiter != NULL) delete g_arbiter;
    if(g_executor != NULL) delete g_executor;
    if(g_riskMgr != NULL) delete g_riskMgr;
    if(g_drawer != NULL) delete g_drawer;
    
    Print("Cleanup completed");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    // Check for new bar
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    bool newBar = (currentBarTime != g_lastBarTime);
    if(newBar) {
        g_lastBarTime = currentBarTime;
    }
    
    // 1. Pre-checks - Session, Spread, MDD
    if(!g_executor.SessionOpen()) {
        // Still manage existing positions even outside session
        g_riskMgr.ManageOpenPositions();
        g_executor.ManagePendingOrders();
        return;
    }
    
    if(!g_executor.SpreadOK()) {
        if(InpShowDashboard && g_drawer != NULL) {
            g_drawer.UpdateDashboard("Spread too wide - waiting...");
        }
        g_riskMgr.ManageOpenPositions();
        g_executor.ManagePendingOrders();
        return;
    }
    
    if(g_riskMgr.IsTradingHalted()) {
        if(InpShowDashboard && g_drawer != NULL) {
            g_drawer.UpdateDashboard("TRADING HALTED - Daily MDD exceeded");
        }
        return;
    }
    
    if(g_executor.IsRolloverTime()) {
        return; // Don't trade during rollover
    }
    
    // 2. Update price series
    g_detector.UpdateSeries();
    
    // 3. Run detectors (on new bar or first check)
    if(newBar || !g_lastBOS.valid) {
        g_lastBOS = g_detector.DetectBOS();
        if(g_lastBOS.valid && InpShowDebugDraw && g_drawer != NULL) {
            g_drawer.MarkBOS(0, g_lastBOS.direction, g_lastBOS.breakLevel, 
                           TimeToString(TimeCurrent()));
        }
    }
    
    if(newBar || !g_lastSweep.valid) {
        g_lastSweep = g_detector.DetectSweep();
        if(g_lastSweep.detected && InpShowDebugDraw && g_drawer != NULL) {
            g_drawer.MarkSweep(g_lastSweep.level, g_lastSweep.side, 
                             g_lastSweep.time, TimeToString(TimeCurrent()));
        }
    }
    
    // Get OB and FVG based on BOS direction
    if(g_lastBOS.valid) {
        g_lastOB = g_detector.FindOB(g_lastBOS.direction);
        if(g_lastOB.valid && InpShowDebugDraw && g_drawer != NULL && newBar) {
            g_drawer.DrawOB(g_lastOB.priceTop, g_lastOB.priceBottom, 
                          g_lastOB.direction, g_lastOB.createdTime, 
                          TimeToString(TimeCurrent()));
        }
        
        g_lastFVG = g_detector.FindFVG(g_lastBOS.direction);
        if(g_lastFVG.valid && InpShowDebugDraw && g_drawer != NULL && newBar) {
            g_drawer.DrawFVG(g_lastFVG.priceTop, g_lastFVG.priceBottom, 
                           g_lastFVG.direction, g_lastFVG.state, 
                           g_lastFVG.createdTime, TimeToString(TimeCurrent()));
        }
    }
    
    if(newBar) {
        g_lastMomo = g_detector.DetectMomentum();
    }
    
    // 4. Build candidate using arbiter
    g_lastCandidate = g_arbiter.BuildCandidate(g_lastBOS, g_lastSweep, g_lastOB, 
                                               g_lastFVG, g_lastMomo,
                                               g_executor.SessionOpen(), 
                                               g_executor.SpreadOK());
    
    // 5. Score and validate candidate
    if(g_lastCandidate.valid) {
        double score = g_arbiter.ScoreCandidate(g_lastCandidate);
        g_lastCandidate.score = score;
        
        // Check if score meets threshold
        if(score >= 100.0) {
            // We have a valid high-priority setup
            
            // 6. Look for trigger candle
            double triggerHigh, triggerLow;
            if(g_executor.GetTriggerCandle(g_lastCandidate.direction, triggerHigh, triggerLow)) {
                
                // 7. Calculate entry, SL, TP
                double entry, sl, tp, rr;
                if(g_executor.CalculateEntry(g_lastCandidate, triggerHigh, triggerLow,
                                            entry, sl, tp, rr)) {
                    
                    // 8. Calculate position size
                    double slDistance = MathAbs(entry - sl) / _Point;
                    double lots = g_riskMgr.CalcLotsByRisk(InpRiskPerTradePct, slDistance);
                    
                    // Check if we already have positions in this direction (use correct MT5 API)
                    int existingPositions = 0;
                    for(int i = 0; i < PositionsTotal(); i++) {
                        ulong ticket = PositionGetTicket(i);
                        if(ticket == 0) continue;
                        if(!PositionSelectByTicket(ticket)) continue;
                        
                        string sym = PositionGetString(POSITION_SYMBOL);
                        if(sym != _Symbol) continue;
                        
                        long posType = PositionGetInteger(POSITION_TYPE);
                        if((g_lastCandidate.direction == 1 && posType == POSITION_TYPE_BUY) ||
                           (g_lastCandidate.direction == -1 && posType == POSITION_TYPE_SELL)) {
                            existingPositions++;
                        }
                    }
                    
                    // Only place if we don't already have a position in this direction
                    if(existingPositions == 0) {
                        string comment = StringFormat("SMC_%s_RR%.1f", 
                                                     g_lastCandidate.direction == 1 ? "BUY" : "SELL",
                                                     rr);
                        
                        // 9. Place stop order
                        if(g_executor.PlaceStopOrder(g_lastCandidate.direction, entry, sl, tp, 
                                                    lots, comment)) {
                            g_totalTrades++;
                            Print("═══════════════════════════════════════");
                            Print("TRADE #", g_totalTrades, " PLACED");
                            Print("Direction: ", g_lastCandidate.direction == 1 ? "BUY" : "SELL");
                            Print("Entry: ", entry);
                            Print("SL: ", sl);
                            Print("TP: ", tp);
                            Print("R:R: ", DoubleToString(rr, 2));
                            Print("Lots: ", lots);
                            Print("Score: ", score);
                            Print("═══════════════════════════════════════");
                            
                            // Track position for DCA/BE management
                            // Note: Will be tracked when order fills
                        }
                    }
                }
            }
        }
    }
    
    // 10. Manage existing positions (BE, Trail, DCA)
    g_riskMgr.ManageOpenPositions();
    
    // 11. Manage pending orders (TTL)
    g_executor.ManagePendingOrders();
    
    // 12. Update dashboard
    if(InpShowDashboard && g_drawer != NULL && newBar) {
        string status = "SCANNING";
        if(g_lastCandidate.valid && g_lastCandidate.score >= 100.0) {
            status = "SIGNAL DETECTED - Score: " + DoubleToString(g_lastCandidate.score, 1);
        } else if(g_lastBOS.valid) {
            status = "BOS DETECTED - Waiting for setup";
        }
        
        g_drawer.UpdateDashboard(status);
        
        // Cleanup old objects periodically
        if(g_totalTrades % 10 == 0) {
            g_drawer.CleanupOldObjects();
        }
    }
}

//+------------------------------------------------------------------+
//| Trade event handler                                              |
//+------------------------------------------------------------------+
void OnTrade() {
    // Track filled positions for DCA management
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol) {
                double entry = PositionGetDouble(POSITION_PRICE_OPEN);
                double sl = PositionGetDouble(POSITION_SL);
                double tp = PositionGetDouble(POSITION_TP);
                double lots = PositionGetDouble(POSITION_VOLUME);
                
                g_riskMgr.TrackPosition(ticket, entry, sl, tp, lots);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Timer event handler                                              |
//+------------------------------------------------------------------+
void OnTimer() {
    // Periodic cleanup and checks can be done here if needed
}

