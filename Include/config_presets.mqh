//+------------------------------------------------------------------+
//|                                              config_presets.mqh  |
//|                              Configuration Preset Profiles       |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property version   "1.20"
#property strict

// Pre-defined configuration profiles for different trading styles

//+------------------------------------------------------------------+
//| Preset 1: Conservative (Low Risk)                               |
//+------------------------------------------------------------------+
struct ConservativePreset {
    // Risk
    static double RiskPerTrade() { return 0.2; }
    static double MaxLotPerSide() { return 2.0; }
    static double DailyMDD() { return 5.0; }
    
    // DCA
    static bool EnableDCA() { return false; } // OFF for conservative
    static int MaxDcaAddons() { return 1; }
    static double DcaLevel1() { return 1.0; }
    static double DcaSize1() { return 0.3; }
    
    // Trailing
    static double TrailStartR() { return 0.75; }
    static double TrailStepR() { return 0.25; }
    static double TrailATRMult() { return 2.5; }
};

//+------------------------------------------------------------------+
//| Preset 2: Balanced (Recommended)                                |
//+------------------------------------------------------------------+
struct BalancedPreset {
    // Risk
    static double RiskPerTrade() { return 0.3; }
    static double MaxLotPerSide() { return 3.0; }
    static double DailyMDD() { return 8.0; }
    
    // DCA
    static bool EnableDCA() { return true; }
    static int MaxDcaAddons() { return 2; }
    static double DcaLevel1() { return 0.75; }
    static double DcaLevel2() { return 1.5; }
    static double DcaSize1() { return 0.5; }
    static double DcaSize2() { return 0.33; }
    
    // Trailing
    static double TrailStartR() { return 1.0; }
    static double TrailStepR() { return 0.5; }
    static double TrailATRMult() { return 2.0; }
};

//+------------------------------------------------------------------+
//| Preset 3: Aggressive (High Risk)                                |
//+------------------------------------------------------------------+
struct AggressivePreset {
    // Risk
    static double RiskPerTrade() { return 0.5; }
    static bool UseEquityBasedLot() { return true; }
    static double MaxLotPctEquity() { return 15.0; }
    static double DailyMDD() { return 12.0; }
    
    // DCA
    static bool EnableDCA() { return true; }
    static int MaxDcaAddons() { return 3; }
    static double DcaLevel1() { return 0.5; }
    static double DcaLevel2() { return 1.0; }
    static double DcaLevel3() { return 1.5; }
    static double DcaSize1() { return 0.618; }
    static double DcaSize2() { return 0.382; }
    static double DcaSize3() { return 0.236; }
    
    // Trailing
    static double TrailStartR() { return 0.75; }
    static double TrailStepR() { return 0.3; }
    static double TrailATRMult() { return 1.5; }
};

// Usage in EA: 
// InpRiskPerTradePct = BalancedPreset::RiskPerTrade();

