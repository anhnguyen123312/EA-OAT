//+------------------------------------------------------------------+
//|                                            SMC_ICT_INDICATOR.mq5 |
//|                              SMC/ICT Visualization Indicator     |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

#include "include/detectors.mqh"
#include "include/draw_debug.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input group "═══════ BOS Detection ═══════"
input int      InpFractalK        = 3;       // Fractal K
input int      InpLookbackSwing   = 50;      // Lookback bars
input double   InpMinBodyATR      = 0.6;     // Min body (ATR)
input int      InpMinBreakPts     = 50;      // Min break (points)

input group "═══════ Liquidity Sweep ═══════"
input int      InpLookbackLiq     = 30;      // Lookback bars
input double   InpMinWickPct      = 35.0;    // Min wick %

input group "═══════ Order Block ═══════"
input int      InpOB_MaxTouches   = 3;       // Max touches
input int      InpOB_BufferInvPts = 50;      // Buffer (points)
input int      InpOB_TTL          = 120;     // TTL (bars)

input group "═══════ Fair Value Gap ═══════"
input int      InpFVG_MinPts      = 150;     // Min size (points)
input double   InpFVG_MitigatePct = 35.0;    // Mitigation %
input double   InpFVG_CompletePct = 85.0;    // Completion %
input int      InpFVG_TTL         = 60;      // TTL (bars)

input group "═══════ Display Options ═══════"
input bool     InpShowBOS         = true;    // Show BOS
input bool     InpShowSweep       = true;    // Show Sweeps
input bool     InpShowOB          = true;    // Show Order Blocks
input bool     InpShowFVG         = true;    // Show FVG
input bool     InpShowInfo        = true;    // Show Info Panel

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CDetector      *g_detector = NULL;
CDrawDebug     *g_drawer = NULL;
datetime       g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit() {
    Print("SMC/ICT Indicator - Initialization");
    
    g_detector = new CDetector();
    if(!g_detector.Init(_Symbol, _Period,
                        InpFractalK, InpLookbackSwing, InpMinBodyATR, InpMinBreakPts, 40,
                        InpLookbackLiq, InpMinWickPct, 20,
                        InpOB_MaxTouches, InpOB_BufferInvPts, InpOB_TTL,
                        InpFVG_MinPts, 25.0, InpFVG_MitigatePct, InpFVG_CompletePct, 50, InpFVG_TTL, 6,
                        0.7, 4, 20)) {
        Print("ERROR: Failed to initialize detector");
        return INIT_FAILED;
    }
    
    g_drawer = new CDrawDebug();
    g_drawer.Init("IND");
    
    g_lastBarTime = iTime(_Symbol, _Period, 0);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    if(g_detector != NULL) delete g_detector;
    if(g_drawer != NULL) delete g_drawer;
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
    
    // Check for new bar
    datetime currentBarTime = iTime(_Symbol, _Period, 0);
    bool newBar = (currentBarTime != g_lastBarTime);
    
    if(!newBar) return rates_total;
    
    g_lastBarTime = currentBarTime;
    
    // Update series
    g_detector.UpdateSeries();
    
    // Detect and draw BOS
    if(InpShowBOS) {
        BOSSignal bos = g_detector.DetectBOS();
        if(bos.valid) {
            g_drawer.MarkBOS(0, bos.direction, bos.breakLevel, 
                           TimeToString(currentBarTime));
        }
    }
    
    // Detect and draw Sweeps
    if(InpShowSweep) {
        SweepSignal sweep = g_detector.DetectSweep();
        if(sweep.detected) {
            g_drawer.MarkSweep(sweep.level, sweep.side, sweep.time, 
                             TimeToString(currentBarTime));
        }
    }
    
    // Detect and draw Order Blocks (both directions)
    if(InpShowOB) {
        OrderBlock obBull = g_detector.FindOB(1);
        if(obBull.valid) {
            g_drawer.DrawOB(obBull.priceTop, obBull.priceBottom, 
                          obBull.direction, obBull.createdTime, 
                          "Bull_" + TimeToString(currentBarTime));
        }
        
        OrderBlock obBear = g_detector.FindOB(-1);
        if(obBear.valid) {
            g_drawer.DrawOB(obBear.priceTop, obBear.priceBottom, 
                          obBear.direction, obBear.createdTime, 
                          "Bear_" + TimeToString(currentBarTime));
        }
    }
    
    // Detect and draw FVGs (both directions)
    if(InpShowFVG) {
        FVGSignal fvgBull = g_detector.FindFVG(1);
        if(fvgBull.valid) {
            g_drawer.DrawFVG(fvgBull.priceTop, fvgBull.priceBottom, 
                           fvgBull.direction, fvgBull.state, 
                           fvgBull.createdTime, 
                           "Bull_" + TimeToString(currentBarTime));
        }
        
        FVGSignal fvgBear = g_detector.FindFVG(-1);
        if(fvgBear.valid) {
            g_drawer.DrawFVG(fvgBear.priceTop, fvgBear.priceBottom, 
                           fvgBear.direction, fvgBear.state, 
                           fvgBear.createdTime, 
                           "Bear_" + TimeToString(currentBarTime));
        }
    }
    
    // Update info panel
    if(InpShowInfo) {
        string info = "SMC/ICT Structures Detected:\n";
        info += "══════════════════════════\n";
        
        BOSSignal bos = g_detector.DetectBOS();
        if(bos.valid) {
            info += "BOS: " + (bos.direction == 1 ? "BULLISH ↑" : "BEARISH ↓") + "\n";
        } else {
            info += "BOS: None\n";
        }
        
        SweepSignal sweep = g_detector.DetectSweep();
        if(sweep.detected) {
            info += "Sweep: " + (sweep.side == 1 ? "High" : "Low") + "\n";
        } else {
            info += "Sweep: None\n";
        }
        
        OrderBlock ob1 = g_detector.FindOB(1);
        OrderBlock ob2 = g_detector.FindOB(-1);
        int obCount = (ob1.valid ? 1 : 0) + (ob2.valid ? 1 : 0);
        info += "Order Blocks: " + IntegerToString(obCount) + "\n";
        
        FVGSignal fvg1 = g_detector.FindFVG(1);
        FVGSignal fvg2 = g_detector.FindFVG(-1);
        int fvgCount = (fvg1.valid ? 1 : 0) + (fvg2.valid ? 1 : 0);
        info += "FVGs: " + IntegerToString(fvgCount) + "\n";
        
        Comment(info);
    }
    
    return rates_total;
}

