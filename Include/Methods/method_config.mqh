//+------------------------------------------------------------------+
//|                                                 method_config.mqh |
//|                    Method Configuration - Import/Export          |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

#include "method_base.mqh"

//+------------------------------------------------------------------+
//| Config Parameter Type Enum                                       |
//+------------------------------------------------------------------+
enum ENUM_CONFIG_PARAM_TYPE {
    CONFIG_PARAM_INT = 0,        // Integer parameter
    CONFIG_PARAM_DOUBLE = 1,     // Double parameter
    CONFIG_PARAM_BOOL = 2,       // Boolean parameter
    CONFIG_PARAM_STRING = 3      // String parameter
};

//+------------------------------------------------------------------+
//| Config Parameter Structure                                       |
//+------------------------------------------------------------------+
struct MethodConfigParam {
    string   name;               // Parameter name (ví dụ: "FractalK")
    string   defaultValue;       // Default value (ví dụ: "5")
    ENUM_CONFIG_PARAM_TYPE type; // Parameter type
    string   description;        // Description (ví dụ: "Fractal depth for swing detection")
};

//+------------------------------------------------------------------+
//| Method Configuration Structure                                   |
//| Mỗi method có thể export/import config để hiển thị trong EA     |
//+------------------------------------------------------------------+
struct MethodConfig {
    string   methodName;         // "SMC", "ICT", "Custom"
    bool     enabled;            // Method có enabled không?
    string   description;        // Mô tả method
    
    // ⭐ Config parameters (method-specific) - Using struct array
    MethodConfigParam params[]; // Array of config parameters
    
    // Display settings
    bool     showInEA;           // Hiển thị trong EA input panel?
    string   groupName;          // Group name trong EA (ví dụ: "═══════ SMC Method ═══════")
    int      priority;           // Priority (0 = highest, 100 = lowest)
};

//+------------------------------------------------------------------+
//| Method Config Manager - Import/Export Config                    |
//+------------------------------------------------------------------+
class CMethodConfigManager {
private:
    MethodConfig m_configs[];    // Array of method configs
    int         m_count;         // Number of registered methods
    
public:
    CMethodConfigManager();
    ~CMethodConfigManager();
    
    // Register method config (gọi từ method Init)
    bool RegisterConfig(const MethodConfig &config);
    
    // Unregister method config (gọi khi method disabled)
    bool UnregisterConfig(string methodName);
    
    // Get config for method
    MethodConfig GetConfig(string methodName);
    
    // Get all configs (for EA input panel)
    MethodConfig GetAllConfigs();
    
    // Check if method is enabled
    bool IsMethodEnabled(string methodName);
    
    // Export config to string (for save/load)
    string ExportConfig(string methodName);
    
    // Import config from string (for load)
    bool ImportConfig(string configString);
    
    // Generate EA input parameters (for EA file generation)
    string GenerateEAInputs();
    
private:
    int FindMethodIndex(string methodName);
    string ParseParamValue(string paramString, int fieldIndex);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CMethodConfigManager::CMethodConfigManager() {
    m_count = 0;
    ArrayResize(m_configs, 0);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CMethodConfigManager::~CMethodConfigManager() {
    ArrayFree(m_configs);
}

//+------------------------------------------------------------------+
//| Register Method Config                                            |
//+------------------------------------------------------------------+
bool CMethodConfigManager::RegisterConfig(const MethodConfig &config) {
    // Check if already exists
    int idx = FindMethodIndex(config.methodName);
    if(idx >= 0) {
        // Update existing
        m_configs[idx] = config;
        return true;
    }
    
    // Add new
    int newSize = m_count + 1;
    ArrayResize(m_configs, newSize);
    m_configs[m_count] = config;
    m_count = newSize;
    
    Print("✅ Method config registered: ", config.methodName);
    return true;
}

//+------------------------------------------------------------------+
//| Unregister Method Config                                          |
//+------------------------------------------------------------------+
bool CMethodConfigManager::UnregisterConfig(string methodName) {
    int idx = FindMethodIndex(methodName);
    if(idx < 0) return false;
    
    // Remove from array
    for(int i = idx; i < m_count - 1; i++) {
        m_configs[i] = m_configs[i + 1];
    }
    m_count--;
    ArrayResize(m_configs, m_count);
    
    Print("✅ Method config unregistered: ", methodName);
    return true;
}

//+------------------------------------------------------------------+
//| Get Config for Method                                             |
//+------------------------------------------------------------------+
MethodConfig CMethodConfigManager::GetConfig(string methodName) {
    MethodConfig empty;
    empty.methodName = "";
    empty.enabled = false;
    
    int idx = FindMethodIndex(methodName);
    if(idx < 0) return empty;
    
    return m_configs[idx];
}

//+------------------------------------------------------------------+
//| Check if Method is Enabled                                        |
//+------------------------------------------------------------------+
bool CMethodConfigManager::IsMethodEnabled(string methodName) {
    int idx = FindMethodIndex(methodName);
    if(idx < 0) return false;
    
    return m_configs[idx].enabled && m_configs[idx].showInEA;
}

//+------------------------------------------------------------------+
//| Find Method Index                                                 |
//+------------------------------------------------------------------+
int CMethodConfigManager::FindMethodIndex(string methodName) {
    for(int i = 0; i < m_count; i++) {
        if(m_configs[i].methodName == methodName) {
            return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Export Config to String                                           |
//+------------------------------------------------------------------+
string CMethodConfigManager::ExportConfig(string methodName) {
    int idx = FindMethodIndex(methodName);
    if(idx < 0) return "";
    
    MethodConfig cfg = m_configs[idx];
    string result = cfg.methodName + "|" + 
                   (cfg.enabled ? "1" : "0") + "|" +
                   cfg.description + "|" +
                   cfg.groupName + "|" +
                   IntegerToString(cfg.priority);
    
    // Add params (format: name|value|type|description)
    for(int i = 0; i < ArraySize(cfg.params); i++) {
        string typeStr = "";
        switch(cfg.params[i].type) {
            case CONFIG_PARAM_INT: typeStr = "int"; break;
            case CONFIG_PARAM_DOUBLE: typeStr = "double"; break;
            case CONFIG_PARAM_BOOL: typeStr = "bool"; break;
            case CONFIG_PARAM_STRING: typeStr = "string"; break;
        }
        result += "|" + cfg.params[i].name + "|" + 
                 cfg.params[i].defaultValue + "|" + 
                 typeStr + "|" + 
                 cfg.params[i].description;
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Generate EA Input Parameters (for EA file)                      |
//+------------------------------------------------------------------+
string CMethodConfigManager::GenerateEAInputs() {
    string result = "";
    
    // Sort by priority
    // (Simple implementation - can be improved)
    
    for(int i = 0; i < m_count; i++) {
        if(!m_configs[i].showInEA || !m_configs[i].enabled) continue;
        
        MethodConfig cfg = m_configs[i];
        
        // Group header
        result += "//+------------------------------------------------------------------+\n";
        result += "//| " + cfg.groupName + "\n";
        result += "//+------------------------------------------------------------------+\n";
        result += "input group \"" + cfg.groupName + "\"\n";
        result += "input bool Inp" + cfg.methodName + "_Enable = true;  // Enable " + cfg.methodName + " Method\n";
        result += "sinput string InpNote_" + cfg.methodName + " = \"" + cfg.description + "\";\n";
        result += "\n";
        
        // Generate params using struct
        for(int j = 0; j < ArraySize(cfg.params); j++) {
            MethodConfigParam param = cfg.params[j];
            
            // Generate input statement based on enum type
            switch(param.type) {
                case CONFIG_PARAM_INT:
                    result += "input int Inp" + cfg.methodName + "_" + param.name + " = " + param.defaultValue + ";  // " + param.description + "\n";
                    break;
                case CONFIG_PARAM_DOUBLE:
                    result += "input double Inp" + cfg.methodName + "_" + param.name + " = " + param.defaultValue + ";  // " + param.description + "\n";
                    break;
                case CONFIG_PARAM_BOOL:
                    result += "input bool Inp" + cfg.methodName + "_" + param.name + " = " + param.defaultValue + ";  // " + param.description + "\n";
                    break;
                case CONFIG_PARAM_STRING:
                    result += "input string Inp" + cfg.methodName + "_" + param.name + " = \"" + param.defaultValue + "\";  // " + param.description + "\n";
                    break;
            }
        }
        
        result += "\n";
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Import Config from String (backward compatibility)               |
//+------------------------------------------------------------------+
bool CMethodConfigManager::ImportConfig(string configString) {
    string parts[];
    int count = StringSplit(configString, '|', parts);
    if(count < 5) return false;
    
    MethodConfig cfg;
    cfg.methodName = parts[0];
    cfg.enabled = (parts[1] == "1");
    cfg.description = parts[2];
    cfg.groupName = parts[3];
    cfg.priority = (int)StringToInteger(parts[4]);
    cfg.showInEA = true;
    
    // Parse params (backward compatibility with old string format)
    int paramCount = (count - 5) / 4; // Each param has 4 fields: name|value|type|description
    if(paramCount > 0) {
        ArrayResize(cfg.params, paramCount);
        for(int i = 0; i < paramCount; i++) {
            int baseIdx = 5 + i * 4;
            if(baseIdx + 3 < count) {
                cfg.params[i].name = parts[baseIdx];
                cfg.params[i].defaultValue = parts[baseIdx + 1];
                string typeStr = parts[baseIdx + 2];
                cfg.params[i].description = parts[baseIdx + 3];
                
                // Convert string type to enum
                if(typeStr == "int") cfg.params[i].type = CONFIG_PARAM_INT;
                else if(typeStr == "double") cfg.params[i].type = CONFIG_PARAM_DOUBLE;
                else if(typeStr == "bool") cfg.params[i].type = CONFIG_PARAM_BOOL;
                else if(typeStr == "string") cfg.params[i].type = CONFIG_PARAM_STRING;
            }
        }
    }
    
    return RegisterConfig(cfg);
}

//+------------------------------------------------------------------+
//| Global Config Manager Instance                                    |
//+------------------------------------------------------------------+
CMethodConfigManager g_MethodConfigManager;

//+------------------------------------------------------------------+

