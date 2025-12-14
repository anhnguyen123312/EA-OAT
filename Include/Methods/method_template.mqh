//+------------------------------------------------------------------+
//|                                                method_template.mqh |
//|                    Template for New Trading Method                |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

#include "method_base.mqh"
#include "method_config.mqh"

//+------------------------------------------------------------------+
//| ═══════════════════════════════════════════════════════════════ |
//| TEMPLATE: Custom Method - Copy & Modify                          |
//| ═══════════════════════════════════════════════════════════════ |
//| Hướng dẫn tạo method mới:                                        |
//| 1. Copy file này và rename thành custom_method.mqh               |
//| 2. Rename class CCustomMethod thành tên method của bạn          |
//| 3. Implement tất cả virtual methods                             |
//| 4. Register config trong Init()                                  |
//| 5. Unregister config trong destructor                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CCustomMethod - Template Trading Method                          |
//+------------------------------------------------------------------+
class CCustomMethod : public CMethodBase {
private:
    // Custom method parameters (add your own)
    int      m_param1;
    double   m_param2;
    bool     m_param3;
    
    // Custom detectors/calculators (add your own)
    // CDetectorCustom* m_detector;
    // CCalculatorCustom* m_calculator;
    
public:
    CCustomMethod();
    ~CCustomMethod();
    
    // ═══════════════════════════════════════════════════════════
    // REQUIRED: Implement Init() - Initialize method
    // ═══════════════════════════════════════════════════════════
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              int param1, double param2, bool param3);
    
    // ═══════════════════════════════════════════════════════════
    // REQUIRED: Implement Scan() - Main detection function
    // ═══════════════════════════════════════════════════════════
    MethodSignal Scan(const RiskGateResult &riskGate) override;
    
    // ═══════════════════════════════════════════════════════════
    // REQUIRED: Implement CreatePositionPlan() - Risk management
    // ═══════════════════════════════════════════════════════════
    PositionPlan CreatePositionPlan(const MethodSignal &signal) override;
    
    // ═══════════════════════════════════════════════════════════
    // REQUIRED: Implement Score() - Signal scoring
    // ═══════════════════════════════════════════════════════════
    double Score(const MethodSignal &signal) override;
    
    // ═══════════════════════════════════════════════════════════
    // REQUIRED: Implement GetConfig() - Config for EA input
    // ═══════════════════════════════════════════════════════════
    MethodConfig GetConfig() override;
    
private:
    // Custom helper methods (add your own)
    void UpdateSeries();
    bool DetectCustomSignal();
    bool CalculateEntrySLTP(double &entry, double &sl, double &tp, double &rr);
    double GetATR();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CCustomMethod::CCustomMethod() {
    m_methodName = "Custom";
    m_param1 = 0;
    m_param2 = 0.0;
    m_param3 = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CCustomMethod::~CCustomMethod() {
    // Unregister config khi method bị destroy
    UnregisterConfig();
}

//+------------------------------------------------------------------+
//| Initialize Custom Method                                          |
//+------------------------------------------------------------------+
bool CCustomMethod::Init(string symbol, ENUM_TIMEFRAMES tf,
                         int param1, double param2, bool param3) {
    m_symbol = symbol;
    m_timeframe = tf;
    m_param1 = param1;
    m_param2 = param2;
    m_param3 = param3;
    
    // ═══════════════════════════════════════════════════════════
    // REQUIRED: Register config để hiển thị trong EA
    // ═══════════════════════════════════════════════════════════
    if(!RegisterConfig()) {
        Print("❌ CCustomMethod: Failed to register config");
        return false;
    }
    
    Print("✅ CCustomMethod initialized");
    return true;
}

//+------------------------------------------------------------------+
//| Scan for Custom Signals                                           |
//+------------------------------------------------------------------+
MethodSignal CCustomMethod::Scan(const RiskGateResult &riskGate) {
    MethodSignal signal;
    signal.valid = false;
    signal.methodName = "Custom";
    signal.score = 0;
    signal.direction = 0;
    
    // ═══════════════════════════════════════════════════════════
    // STEP 1: Check Risk Gate
    // ═══════════════════════════════════════════════════════════
    if(!riskGate.canTrade) {
        return signal;
    }
    
    // ═══════════════════════════════════════════════════════════
    // STEP 2: Update price series
    // ═══════════════════════════════════════════════════════════
    UpdateSeries();
    
    // ═══════════════════════════════════════════════════════════
    // STEP 3: Detect custom signals (implement your logic)
    // ═══════════════════════════════════════════════════════════
    if(!DetectCustomSignal()) {
        return signal;
    }
    
    // ═══════════════════════════════════════════════════════════
    // STEP 4: Calculate Entry/SL/TP
    // ═══════════════════════════════════════════════════════════
    double entry, sl, tp, rr;
    if(!CalculateEntrySLTP(entry, sl, tp, rr)) {
        return signal;
    }
    
    // ═══════════════════════════════════════════════════════════
    // STEP 5: Validate RR
    // ═══════════════════════════════════════════════════════════
    // (Check against riskGate.maxRiskPips if needed)
    
    // ═══════════════════════════════════════════════════════════
    // STEP 6: Build signal
    // ═══════════════════════════════════════════════════════════
    signal.direction = 1; // or -1, based on your detection
    signal.entryPrice = entry;
    signal.slPrice = sl;
    signal.tpPrice = tp;
    signal.rr = rr;
    signal.entryType = ENTRY_LIMIT; // or ENTRY_STOP, ENTRY_MARKET
    signal.entryReason = "Custom method entry";
    signal.score = Score(signal);
    
    // ═══════════════════════════════════════════════════════════
    // STEP 7: Create Position Plan
    // ═══════════════════════════════════════════════════════════
    signal.positionPlan = CreatePositionPlan(signal);
    
    // ═══════════════════════════════════════════════════════════
    // STEP 8: Validate signal
    // ═══════════════════════════════════════════════════════════
    if(signal.score >= 100.0 && signal.rr >= 2.0) {
        signal.valid = true;
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Create Position Plan                                              |
//+------------------------------------------------------------------+
PositionPlan CCustomMethod::CreatePositionPlan(const MethodSignal &signal) {
    PositionPlan plan;
    plan.methodName = "Custom";
    plan.strategy = "Balanced";
    
    // ═══════════════════════════════════════════════════════════
    // DCA Plan (customize theo method của bạn)
    // ═══════════════════════════════════════════════════════════
    plan.dcaPlan.enabled = true;
    plan.dcaPlan.maxLevels = 2;
    plan.dcaPlan.level1_triggerR = 0.75;
    plan.dcaPlan.level1_lotMultiplier = 0.5;
    plan.dcaPlan.level2_triggerR = 1.5;
    plan.dcaPlan.level2_lotMultiplier = 0.33;
    plan.dcaPlan.dcaEntryType = ENTRY_MARKET;
    plan.dcaPlan.dcaEntryReason = "At current price when trigger";
    
    // ═══════════════════════════════════════════════════════════
    // BE Plan (customize theo method của bạn)
    // ═══════════════════════════════════════════════════════════
    plan.bePlan.enabled = true;
    plan.bePlan.triggerR = 1.0;
    plan.bePlan.moveAllPositions = true;
    plan.bePlan.reason = "Standard BE";
    
    // ═══════════════════════════════════════════════════════════
    // Trail Plan (customize theo method của bạn)
    // ═══════════════════════════════════════════════════════════
    plan.trailPlan.enabled = true;
    plan.trailPlan.startR = 1.0;
    plan.trailPlan.stepR = 0.5;
    plan.trailPlan.distanceATR = 2.0;
    plan.trailPlan.lockProfit = true;
    plan.trailPlan.strategy = "ATR-based";
    
    plan.syncSL = true;
    plan.basketTP = false;
    plan.basketSL = false;
    
    return plan;
}

//+------------------------------------------------------------------+
//| Score Signal                                                      |
//+------------------------------------------------------------------+
double CCustomMethod::Score(const MethodSignal &signal) {
    double score = 0.0;
    
    // ═══════════════════════════════════════════════════════════
    // Implement scoring logic của bạn
    // ═══════════════════════════════════════════════════════════
    // Example:
    // if(signal có pattern A) score += 100;
    // if(signal có pattern B) score += 50;
    // if(signal.rr >= 3.0) score += 30;
    
    return score;
}

//+------------------------------------------------------------------+
//| Get Config for EA Input                                           |
//+------------------------------------------------------------------+
MethodConfig CCustomMethod::GetConfig() {
    MethodConfig cfg;
    cfg.methodName = "Custom";
    cfg.enabled = true;
    cfg.description = "Custom trading method - modify this template";
    cfg.groupName = "═══════ Custom Method ═══════";
    cfg.priority = 50;
    cfg.showInEA = true;
    
    // ═══════════════════════════════════════════════════════════
    // Define config parameters (sẽ hiển thị trong EA input)
    // Format: "paramName|value|type|description"
    // ═══════════════════════════════════════════════════════════
    ArrayResize(cfg.params, 3);
    cfg.params[0] = "Param1|10|int|Custom parameter 1";
    cfg.params[1] = "Param2|1.5|double|Custom parameter 2";
    cfg.params[2] = "Param3|true|bool|Enable custom feature";
    
    return cfg;
}

//+------------------------------------------------------------------+
//| Update Price Series                                               |
//+------------------------------------------------------------------+
void CCustomMethod::UpdateSeries() {
    // Implement price series update
    // Example: CopyArray, iHigh, iLow, etc.
}

//+------------------------------------------------------------------+
//| Detect Custom Signal                                              |
//+------------------------------------------------------------------+
bool CCustomMethod::DetectCustomSignal() {
    // Implement custom detection logic
    return false;
}

//+------------------------------------------------------------------+
//| Calculate Entry/SL/TP                                             |
//+------------------------------------------------------------------+
bool CCustomMethod::CalculateEntrySLTP(double &entry, double &sl, double &tp, double &rr) {
    // Implement Entry/SL/TP calculation
    entry = 0;
    sl = 0;
    tp = 0;
    rr = 0;
    return false;
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                     |
//+------------------------------------------------------------------+
double CCustomMethod::GetATR() {
    // Implement ATR calculation
    return 0;
}

//+------------------------------------------------------------------+

