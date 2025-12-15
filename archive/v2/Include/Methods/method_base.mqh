//+------------------------------------------------------------------+
//|                                                    method_base.mqh |
//|                    Base Class for Trading Methods                |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

#include "..\Common\signal_structs.mqh"
#include "method_config.mqh"

//+------------------------------------------------------------------+
//| CMethodBase - Base class for all trading methods                 |
//+------------------------------------------------------------------+
class CMethodBase {
protected:
    string   m_methodName;           // "SMC", "ICT", etc.
    string   m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    bool     m_configRegistered;    // Config đã register chưa?
    
public:
    CMethodBase();
    virtual ~CMethodBase();
    
    // Virtual methods - must be implemented by derived classes
    virtual bool Init(string symbol, ENUM_TIMEFRAMES tf) { return false; }  // Override in derived class
    virtual MethodSignal Scan(const RiskGateResult &riskGate) { 
        MethodSignal empty; empty.valid = false; return empty; 
    }
    virtual bool CalculateEntry(MethodSignal &signal, const RiskGateResult &riskGate) { return false; }
    virtual PositionPlan CreatePositionPlan(const MethodSignal &signal) {
        PositionPlan empty; 
        empty.dcaPlan.enabled = false;
        empty.bePlan.enabled = false;
        empty.trailPlan.enabled = false;
        return empty;
    }
    virtual double Score(const MethodSignal &signal) { return 0.0; }
    
    // Config methods - must be implemented by derived classes
    virtual MethodConfig GetConfig() {
        MethodConfig empty;
        empty.methodName = m_methodName;
        empty.enabled = false;
        empty.showInEA = false;
        return empty;
    }
    virtual bool RegisterConfig() {
        if(m_configRegistered) return true;
        MethodConfig cfg = GetConfig();
        if(cfg.methodName == "") return false;
        m_configRegistered = g_MethodConfigManager.RegisterConfig(cfg);
        return m_configRegistered;
    }
    virtual bool UnregisterConfig() {
        if(!m_configRegistered) return true;
        bool result = g_MethodConfigManager.UnregisterConfig(m_methodName);
        if(result) m_configRegistered = false;
        return result;
    }
    
    // Helper
    string GetMethodName() { return m_methodName; }
    bool IsConfigRegistered() { return m_configRegistered; }
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMethodBase::CMethodBase() {
    m_methodName = "BASE";
    m_symbol = "";
    m_timeframe = PERIOD_CURRENT;
    m_configRegistered = false;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CMethodBase::~CMethodBase() {
    // Base destructor
}

//+------------------------------------------------------------------+

