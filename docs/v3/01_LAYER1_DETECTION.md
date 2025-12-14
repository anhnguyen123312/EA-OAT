# 🔍 Layer 1: Detection Layer - Modular Methods

## 📍 Tổng Quan

**Layer 1** là **Detection Layer** - lớp phát hiện tín hiệu trading theo từng **Phương pháp** (Method). Mỗi phương pháp là một module độc lập, tự chứa toàn bộ logic detection, calculation và risk management strategy.

### 🎯 Nguyên Tắc Thiết Kế

1. **Modular** - Mỗi phương pháp là một folder riêng, không phụ thuộc lẫn nhau
2. **Self-contained** - Mỗi phương pháp tự detect, tự tính Entry/SL/TP, tự score, tự tạo PositionPlan
3. **Extensible** - Thêm phương pháp mới chỉ cần tạo folder mới, không sửa code core
4. **Complete Output** - Mỗi phương pháp output đầy đủ: Entry, SL, TP, BE plan, DCA plan, Trail plan
5. **Config System** - Mỗi phương pháp có thể export/import config để hiển thị trong EA input panel

---

## 📁 Cấu Trúc Thư Mục

```
Include/
├─ Methods/                          [Base classes & interfaces]
│  ├─ method_base.mqh               [Base class - interface contract]
│  ├─ method_config.mqh             [Config system - import/export] ⭐
│  └─ method_template.mqh           [Template cho method mới] ⭐
│
├─ SMC/                              [SMC Method - Complete Module] ⭐
│  ├─ smc_method.mqh                 [SMC Main - Entry point]
│  ├─ smc_detectors.mqh              [SMC Detectors - BOS, Sweep, OB, FVG]
│  ├─ smc_calculator.mqh             [SMC Calculator - Entry/SL/TP calculation]
│  ├─ smc_scorer.mqh                 [SMC Scorer - Signal scoring]
│  └─ smc_risk_plan.mqh              [SMC Risk Plan - BE/DCA/Trail strategy]
│
├─ ICT/                              [ICT Method - Complete Module] ⭐
│  ├─ ict_method.mqh                 [ICT Main - Entry point]
│  ├─ ict_detectors.mqh              [ICT Detectors - FVG, OB, Momentum]
│  ├─ ict_calculator.mqh             [ICT Calculator - Entry/SL/TP calculation]
│  ├─ ict_scorer.mqh                 [ICT Scorer - Signal scoring]
│  └─ ict_risk_plan.mqh              [ICT Risk Plan - BE/DCA/Trail strategy]
│
└─ Custom/                           [Custom Method - Template] ⭐
   ├─ custom_method.mqh              [Custom Main - Entry point]
   ├─ custom_detectors.mqh           [Custom Detectors]
   ├─ custom_calculator.mqh          [Custom Calculator]
   ├─ custom_scorer.mqh              [Custom Scorer]
   └─ custom_risk_plan.mqh           [Custom Risk Plan]
```

### 📋 Giải Thích Cấu Trúc

**Mỗi phương pháp (SMC, ICT, Custom) là một folder độc lập chứa:**

1. **`*_method.mqh`** - Main entry point, kế thừa `CMethodBase`, implement interface
2. **`*_detectors.mqh`** - Tất cả detectors của phương pháp (BOS, Sweep, OB, FVG, Momentum, etc.)
3. **`*_calculator.mqh`** - Logic tính Entry, SL, TP dựa trên structure/pattern
4. **`*_scorer.mqh`** - Logic chấm điểm signal (score từ 0-1000+)
5. **`*_risk_plan.mqh`** - Strategy quản lý position: BE plan, DCA plan, Trail plan

**Lợi ích:**
- ✅ Mỗi phương pháp tự chứa, không phụ thuộc phương pháp khác
- ✅ Dễ thêm/xóa phương pháp (chỉ cần thêm/xóa folder)
- ✅ Dễ maintain (sửa SMC không ảnh hưởng ICT)
- ✅ Code rõ ràng, dễ đọc (mỗi file một nhiệm vụ)
- ✅ Config tự động hiển thị/ẩn khi import/unimport method

---

## 🏗️ Kiến Trúc Mỗi Phương Pháp

### 📊 Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  SMC Method (smc_method.mqh)                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Scan(RiskGateResult) → MethodSignal                  │  │
│  │  ├─ 1. Check Risk Gate (Layer 0)                      │  │
│  │  ├─ 2. Update price series                             │  │
│  │  ├─ 3. Run detectors (smc_detectors.mqh)             │  │
│  │  │    ├─ DetectBOS()                                  │  │
│  │  │    ├─ DetectSweep()                                │  │
│  │  │    ├─ FindOB()                                     │  │
│  │  │    └─ FindFVG()                                    │  │
│  │  ├─ 4. Build candidate (combine signals)              │  │
│  │  ├─ 5. Score candidate (smc_scorer.mqh)              │  │
│  │  ├─ 6. Calculate Entry/SL/TP (smc_calculator.mqh)    │  │
│  │  └─ 7. Create PositionPlan (smc_risk_plan.mqh)       │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
              MethodSignal (complete output)
                          │
                          ▼
              Layer 2 (Arbitration)
```

### 🔄 Interface Contract

**Mỗi phương pháp PHẢI implement interface từ `CMethodBase`:**

```cpp
class CMethodBase {
public:
    // Initialize method
    virtual bool Init(string symbol, ENUM_TIMEFRAMES tf, ...params) = 0;
    
    // Main scan function - output MethodSignal
    virtual MethodSignal Scan(const RiskGateResult &riskGate) = 0;
    
    // Create position management plan
    virtual PositionPlan CreatePositionPlan(const MethodSignal &signal) = 0;
    
    // Score signal (optional, can use signal.score)
    virtual double Score(const MethodSignal &signal) = 0;
    
    // ⭐ Config methods (NEW)
    virtual MethodConfig GetConfig() = 0;
    virtual bool RegisterConfig() = 0;
    virtual bool UnregisterConfig() = 0;
};
```

---

## ⚙️ Config System - Import/Export Method Config

### 📋 Tổng Quan

Mỗi method có thể **export config** để hiển thị trong EA input panel. Khi method được **import** (include vào EA), config sẽ tự động hiển thị. Khi method bị **xóa** (uninclude), config sẽ tự động ẩn.

### 🏗️ Cấu Trúc Config

**File:** `Include/Methods/method_config.mqh`

**Struct:** `MethodConfig`
```cpp
// ⭐ Config Parameter Type Enum
enum ENUM_CONFIG_PARAM_TYPE {
    CONFIG_PARAM_INT = 0,        // Integer parameter
    CONFIG_PARAM_DOUBLE = 1,     // Double parameter
    CONFIG_PARAM_BOOL = 2,       // Boolean parameter
    CONFIG_PARAM_STRING = 3      // String parameter
};

// ⭐ Config Parameter Structure
struct MethodConfigParam {
    string   name;               // Parameter name (ví dụ: "FractalK")
    string   defaultValue;       // Default value (ví dụ: "5")
    ENUM_CONFIG_PARAM_TYPE type; // Parameter type (enum)
    string   description;        // Description (ví dụ: "Fractal depth for swing detection")
};

// Method Configuration Structure
struct MethodConfig {
    string   methodName;         // "SMC", "ICT", "Custom"
    bool     enabled;            // Method có enabled không?
    string   description;        // Mô tả method
    
    // ⭐ Config parameters (method-specific) - Using struct array
    MethodConfigParam params[];  // Array of config parameters
    
    // Display settings
    bool     showInEA;           // Hiển thị trong EA input panel?
    string   groupName;          // Group name trong EA
    int      priority;           // Priority (0 = highest)
};
```

### 📝 Config Parameter Format (Enum-based)

**Sử dụng Enum và Struct thay vì string format:**

**Ví dụ:**
```cpp
MethodConfigParam param1;
param1.name = "FractalK";
param1.defaultValue = "5";
param1.type = CONFIG_PARAM_INT;
param1.description = "Fractal depth for swing detection";

MethodConfigParam param2;
param2.name = "MinBodyATR";
param2.defaultValue = "0.8";
param2.type = CONFIG_PARAM_DOUBLE;
param2.description = "Min candle body (× ATR)";

MethodConfigParam param3;
param3.name = "TrackRetest";
param3.defaultValue = "true";
param3.type = CONFIG_PARAM_BOOL;
param3.description = "Track BOS retest";
```

### 🔄 Register Config trong Method

**Mỗi method PHẢI implement `GetConfig()` và gọi `RegisterConfig()` trong `Init()`:**

```cpp
class CSMCMethod : public CMethodBase {
public:
    bool Init(...) {
        // ... initialization code ...
        
        // ⭐ REQUIRED: Register config
        if(!RegisterConfig()) {
            Print("❌ Failed to register config");
            return false;
        }
        
        return true;
    }
    
    MethodConfig GetConfig() override {
        MethodConfig cfg;
        cfg.methodName = "SMC";
        cfg.enabled = true;
        cfg.description = "SMC Method - BOS+OB+FVG+Sweep";
        cfg.groupName = "═══════ SMC Method ═══════";
        cfg.priority = 10;
        cfg.showInEA = true;
        
        // ⭐ Define parameters using struct (Enum-based)
        ArrayResize(cfg.params, 5);
        
        // Param 1: FractalK
        cfg.params[0].name = "FractalK";
        cfg.params[0].defaultValue = "5";
        cfg.params[0].type = CONFIG_PARAM_INT;
        cfg.params[0].description = "Fractal depth for swing detection";
        
        // Param 2: MinBodyATR
        cfg.params[1].name = "MinBodyATR";
        cfg.params[1].defaultValue = "0.8";
        cfg.params[1].type = CONFIG_PARAM_DOUBLE;
        cfg.params[1].description = "Min candle body (× ATR)";
        
        // Param 3: TrackRetest
        cfg.params[2].name = "TrackRetest";
        cfg.params[2].defaultValue = "true";
        cfg.params[2].type = CONFIG_PARAM_BOOL;
        cfg.params[2].description = "Track BOS retest";
        
        // ... more params ...
        
        return cfg;
    }
    
    ~CSMCMethod() {
        // ⭐ REQUIRED: Unregister config khi destroy
        UnregisterConfig();
    }
};
```

### 📊 Config Manager

**Global instance:** `g_MethodConfigManager`

**Methods:**
- `RegisterConfig(config)` - Register method config
- `UnregisterConfig(methodName)` - Unregister method config
- `GetConfig(methodName)` - Get config for method
- `IsMethodEnabled(methodName)` - Check if method enabled
- `ExportConfig(methodName)` - Export config to string
- `ImportConfig(configString)` - Import config from string
- `GenerateEAInputs()` - Generate EA input code

### 🔌 Integration với EA

**EA sẽ tự động generate input parameters từ registered configs:**

```cpp
// Main EA (V2-oat.mq5)
// ⭐ Import method như một class
#include "..\Include\SMC\smc_method.mqh"      // ✅ Import → Config hiện
#include "..\Include\ICT\ict_method.mqh"      // ✅ Import → Config hiện
// #include "..\Include\Custom\custom_method.mqh"  // ❌ Comment → Config ẩn

// ⭐ Declare method instances (như class objects)
CSMCMethod smc;
CICTMethod ict;

// OnInit()
int OnInit() {
    // Initialize methods (tự động register config)
    if(!smc.Init(_Symbol, PERIOD_CURRENT, ...params)) {
        Print("❌ Failed to initialize SMC");
        return INIT_FAILED;
    }
    
    if(!ict.Init(_Symbol, PERIOD_CURRENT, ...params)) {
        Print("❌ Failed to initialize ICT");
        return INIT_FAILED;
    }
    
    // Config sẽ tự động hiển thị trong EA input panel
    return INIT_SUCCEEDED;
}

// OnTick()
void OnTick() {
    RiskGateResult riskGate = g_RiskGate.Check();
    
    // Scan methods (như gọi method của class)
    MethodSignal smcSignal = smc.Scan(riskGate);
    MethodSignal ictSignal = ict.Scan(riskGate);
    
    // ... process signals ...
}
```

**Lưu ý:**
- Method được import như một **class** (không phải function)
- Mỗi method là một **instance** riêng biệt
- Config được register tự động khi gọi `Init()`
- Config được unregister tự động khi method bị destroy

**EA Input Panel sẽ hiển thị:**
```
═══════ SMC Method ═══════
input bool InpSMC_Enable = true;
input int InpSMC_FractalK = 5;
input double InpSMC_MinBodyATR = 0.8;
...

═══════ ICT Method ═══════
input bool InpICT_Enable = true;
...
```

### ✅ Auto Show/Hide Config

**Khi method được import:**
- Method gọi `RegisterConfig()` trong `Init()`
- Config được thêm vào `g_MethodConfigManager`
- EA input panel tự động hiển thị config

**Khi method bị xóa (uninclude):**
- Method gọi `UnregisterConfig()` trong destructor
- Config được xóa khỏi `g_MethodConfigManager`
- EA input panel tự động ẩn config

**Lưu ý:** EA cần rebuild để input panel cập nhật (MT5 không tự động refresh input panel).

---

## 🔌 Integration Format - Chuẩn Cho Method Mới

### 📋 Tổng Quan

Để method mới **integration được với Layer 0 và Layer 2**, method PHẢI tuân theo format chuẩn sau:

### ✅ Required Interface

**Mỗi method PHẢI implement interface từ `CMethodBase`:**

```cpp
class CMethodBase {
public:
    // ⭐ REQUIRED: Initialize method
    virtual bool Init(string symbol, ENUM_TIMEFRAMES tf, ...params) = 0;
    
    // ⭐ REQUIRED: Main scan function - output MethodSignal
    virtual MethodSignal Scan(const RiskGateResult &riskGate) = 0;
    
    // ⭐ REQUIRED: Create position management plan
    virtual PositionPlan CreatePositionPlan(const MethodSignal &signal) = 0;
    
    // ⭐ REQUIRED: Score signal
    virtual double Score(const MethodSignal &signal) = 0;
    
    // ⭐ REQUIRED: Get config for EA input
    virtual MethodConfig GetConfig() = 0;
    
    // ⭐ REQUIRED: Register/Unregister config
    virtual bool RegisterConfig() = 0;
    virtual bool UnregisterConfig() = 0;
};
```

### 🔄 Integration với Layer 0 (Risk Gate)

**Input:** `RiskGateResult` struct

```cpp
struct RiskGateResult {
    bool     canTrade;          // ⭐ Có được trade không?
    double   maxRiskPips;       // ⭐ Số pip tối đa có thể risk
    double   maxLotSize;         // ⭐ Lot size tối đa
    string   reason;             // Lý do nếu canTrade = false
    
    // ⭐ Position tracking (NEW)
    double   filledRiskPips;    // Số pip đã vào lệnh (filled positions)
    double   filledLotSize;     // Số lot đã vào lệnh (filled positions)
    double   pendingRiskPips;    // Số pip đang trong lệnh chờ (pending orders)
    double   pendingLotSize;    // Số lot đang trong lệnh chờ (pending orders)
    
    // Calculated remaining
    double   remainingRiskPips; // Số pip còn lại = maxRiskPips - filledRiskPips - pendingRiskPips
    double   remainingLotSize;  // Số lot còn lại = maxLotSize - filledLotSize - pendingLotSize
};
```

**Method PHẢI:**
1. ✅ Check `riskGate.canTrade` trước khi scan
2. ✅ Validate lot size không vượt quá `riskGate.remainingLotSize` (còn lại sau khi trừ filled + pending)
3. ✅ Validate risk không vượt quá `riskGate.remainingRiskPips` (còn lại sau khi trừ filled + pending)
4. ✅ Return `MethodSignal.valid = false` nếu không pass checks

**Lưu ý:** 
- Sử dụng `remainingLotSize` và `remainingRiskPips` thay vì `maxLotSize` và `maxRiskPips`
- Điều này đảm bảo method không vượt quá giới hạn khi đã có positions/orders

**Example:**
```cpp
MethodSignal CSMCMethod::Scan(const RiskGateResult &riskGate) {
    MethodSignal signal;
    signal.valid = false;
    
    // ⭐ REQUIRED: Check Risk Gate
    if(!riskGate.canTrade) {
        return signal;  // Early return
    }
    
    // ... detection logic ...
    
    // ⭐ REQUIRED: Validate lot size (sử dụng remaining)
    double calculatedLot = CalculateLotSize(...);
    if(calculatedLot > riskGate.remainingLotSize) {
        calculatedLot = riskGate.remainingLotSize;
    }
    if(calculatedLot <= 0) {
        return signal;  // Không còn lot available
    }
    
    // ⭐ REQUIRED: Validate risk (sử dụng remaining)
    double riskPips = MathAbs(entry - sl) / _Point;
    if(riskPips > riskGate.remainingRiskPips) {
        return signal;  // Risk quá lớn hoặc không còn risk available
    }
    
    // ... build signal ...
    
    return signal;
}
```

### 🔄 Integration với Layer 2 (Arbitration)

**Output:** `MethodSignal` struct

```cpp
struct MethodSignal {
    bool         valid;              // ⭐ Signal có hợp lệ không?
    string       methodName;         // ⭐ "SMC", "ICT", etc.
    ENUM_ORDER_TYPE orderType;       // ⭐ ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, ORDER_SELL_LIMIT, ORDER_BUY_STOP, ORDER_SELL_STOP, ORDER_BUY_STOP_LIMIT, ORDER_SELL_STOP_LIMIT (Mỗi lệnh chỉ là 1 loại)
    double       score;              // ⭐ Điểm chất lượng (0-1000+)
    
    // ⭐ REQUIRED: Entry calculation
    double       entryPrice;         // Entry price
    double       slPrice;            // Stop Loss
    double       tpPrice;            // Take Profit
    double       rr;                 // Risk:Reward ratio
    
    // ⭐ REQUIRED: Entry method (simplified - backward compatibility)
    ENTRY_TYPE   entryType;          // ⭐ ENTRY_TYPE (LIMIT, STOP, MARKET) - Simplified version
    string       entryReason;        // "OB bottom", "FVG zone", etc.
    
    // ⭐ REQUIRED: Position management plan
    PositionPlan positionPlan;       // DCA, BE, Trail plans
    
    // Optional: Signal details
    string       details;            // JSON string với thông tin chi tiết
};
```

**Method PHẢI:**
1. ✅ Set `valid = true` chỉ khi signal hợp lệ
2. ✅ Set `methodName` = tên method (ví dụ: "SMC")
3. ✅ Set `orderType` = `ORDER_BUY`, `ORDER_SELL`, `ORDER_BUY_LIMIT`, `ORDER_SELL_LIMIT`, `ORDER_BUY_STOP`, `ORDER_SELL_STOP`, `ORDER_BUY_STOP_LIMIT`, `ORDER_SELL_STOP_LIMIT` (Mỗi lệnh chỉ là 1 loại)
4. ✅ Set `score` ≥ 100 (minimum threshold)
5. ✅ Calculate `entryPrice`, `slPrice`, `tpPrice`, `rr`
6. ✅ Set `entryType` = `ENTRY_LIMIT`, `ENTRY_STOP`, hoặc `ENTRY_MARKET` và `entryReason` (simplified version)
7. ✅ Create `positionPlan` với đầy đủ BE/DCA/Trail plans

**Example:**
```cpp
MethodSignal CSMCMethod::Scan(const RiskGateResult &riskGate) {
    MethodSignal signal;
    signal.valid = false;
    signal.methodName = "SMC";
    signal.score = 0;
    
    // ... detection logic ...
    
    // ⭐ REQUIRED: Calculate Entry/SL/TP
    double entry, sl, tp, rr;
    if(!CalculateEntrySLTP(candidate, riskGate, entry, sl, tp, rr)) {
        return signal;
    }
    
    // ⭐ REQUIRED: Score signal
    double score = ScoreCandidate(candidate);
    if(score < 100.0) {
        return signal;  // Score quá thấp
    }
    
    // ⭐ REQUIRED: Build signal
    signal.orderType = ORDER_BUY_LIMIT;  // or ORDER_SELL_LIMIT, ORDER_BUY, ORDER_SELL, ORDER_BUY_STOP, ORDER_SELL_STOP, ORDER_BUY_STOP_LIMIT, ORDER_SELL_STOP_LIMIT
    signal.entryPrice = entry;
    signal.slPrice = sl;
    signal.tpPrice = tp;
    signal.rr = rr;
    signal.entryType = ENTRY_LIMIT;  // Simplified version
    signal.entryReason = "OB Retest Limit Entry";
    signal.score = score;
    
    // ⭐ REQUIRED: Create Position Plan
    signal.positionPlan = CreatePositionPlan(signal);
    
    // ⭐ REQUIRED: Validate signal
    if(score >= 100.0 && rr >= 2.0) {
        signal.valid = true;
    }
    
    return signal;
}
```

### 📋 Checklist Integration

**Để method mới integration được với Layer 0 và 2, PHẢI:**

#### ✅ Layer 0 Integration

- [ ] Method check `riskGate.canTrade` trước khi scan
- [ ] Method validate lot size ≤ `riskGate.maxLotSize`
- [ ] Method validate risk ≤ `riskGate.maxRiskPips`
- [ ] Method return `valid = false` nếu không pass checks

#### ✅ Layer 2 Integration

- [ ] Method output `MethodSignal` với đầy đủ fields
- [ ] Method set `valid = true` chỉ khi signal hợp lệ
- [ ] Method set `score ≥ 100` (minimum threshold)
- [ ] Method calculate `entryPrice`, `slPrice`, `tpPrice`, `rr`
- [ ] Method set `entryType` và `entryReason`
- [ ] Method create `positionPlan` với BE/DCA/Trail plans

#### ✅ Config Integration

- [ ] Method implement `GetConfig()` với đầy đủ parameters
- [ ] Method sử dụng `MethodConfigParam` struct với Enum type
- [ ] Method gọi `RegisterConfig()` trong `Init()`
- [ ] Method gọi `UnregisterConfig()` trong destructor
- [ ] Config parameters sử dụng Enum: `CONFIG_PARAM_INT`, `CONFIG_PARAM_DOUBLE`, `CONFIG_PARAM_BOOL`, `CONFIG_PARAM_STRING`

---

## 📖 Hướng Dẫn Tạo Method Mới - Step by Step

### 🎯 Tổng Quan

Hướng dẫn này sẽ giúp bạn tạo một **trading method mới** từ đầu, tuân theo format chuẩn để integration với Layer 0 (Risk Gate) và Layer 2 (Arbitration).

### 📋 Bước 1: Chuẩn Bị

**1.1. Tạo folder cho method mới:**

```
Include/
└─ YourMethod/                    [Tên method của bạn]
   ├─ your_method.mqh            [Main class]
   ├─ your_detectors.mqh          [Detectors]
   ├─ your_calculator.mqh         [Calculator]
   ├─ your_scorer.mqh             [Scorer]
   └─ your_risk_plan.mqh          [Risk plan]
```

**1.2. Copy template file:**

```bash
# Copy template
Include/Methods/method_template.mqh → Include/YourMethod/your_method.mqh
```

**1.3. Đặt tên method:**

- Method name: `"YourMethod"` (ví dụ: "PriceAction", "TrendFollowing")
- Class name: `CYourMethod` (ví dụ: `CPriceActionMethod`, `CTrendFollowingMethod`)
- File name: `your_method.mqh` (ví dụ: `price_action_method.mqh`)

---

### 📝 Bước 2: Setup Class Structure

**2.1. Rename class:**

```cpp
// Trong file your_method.mqh
// Đổi từ:
class CCustomMethod : public CMethodBase {

// Thành:
class CYourMethod : public CMethodBase {
```

**2.2. Update constructor:**

```cpp
CYourMethod::CYourMethod() {
    m_methodName = "YourMethod";  // ⭐ Đổi tên method
    // ... initialize your parameters ...
}
```

**2.3. Define method parameters:**

```cpp
class CYourMethod : public CMethodBase {
private:
    // ⭐ Thêm parameters của method
    int      m_lookbackPeriod;
    double   m_threshold;
    bool     m_useFilter;
    
    // ⭐ Thêm detectors/calculators nếu cần
    // CDetectorYourMethod* m_detector;
    
public:
    // ... methods ...
};
```

---

### 🔧 Bước 3: Implement Init() Method

**3.1. Update Init() signature:**

```cpp
bool CYourMethod::Init(string symbol, ENUM_TIMEFRAMES tf,
                      int lookbackPeriod, double threshold, bool useFilter) {
    m_symbol = symbol;
    m_timeframe = tf;
    m_lookbackPeriod = lookbackPeriod;
    m_threshold = threshold;
    m_useFilter = useFilter;
    
    // ⭐ REQUIRED: Initialize detectors/calculators nếu có
    // m_detector = new CDetectorYourMethod();
    // if(!m_detector.Init(...)) return false;
    
    // ⭐ REQUIRED: Register config để hiển thị trong EA
    if(!RegisterConfig()) {
        Print("❌ CYourMethod: Failed to register config");
        return false;
    }
    
    Print("✅ CYourMethod initialized");
    return true;
}
```

**3.2. Implement GetConfig():**

```cpp
MethodConfig CYourMethod::GetConfig() {
    MethodConfig cfg;
    cfg.methodName = "YourMethod";  // ⭐ Tên method
    cfg.enabled = true;
    cfg.description = "Your Method Description - What does it do?";
    cfg.groupName = "═══════ Your Method ═══════";  // ⭐ Group name trong EA
    cfg.priority = 50;  // Priority (0 = highest, 100 = lowest)
    cfg.showInEA = true;
    
    // ⭐ REQUIRED: Define config parameters (Enum-based)
    ArrayResize(cfg.params, 3);
    
    // Param 1: LookbackPeriod
    cfg.params[0].name = "LookbackPeriod";
    cfg.params[0].defaultValue = "20";
    cfg.params[0].type = CONFIG_PARAM_INT;
    cfg.params[0].description = "Lookback period for signal detection";
    
    // Param 2: Threshold
    cfg.params[1].name = "Threshold";
    cfg.params[1].defaultValue = "1.5";
    cfg.params[1].type = CONFIG_PARAM_DOUBLE;
    cfg.params[1].description = "Signal threshold";
    
    // Param 3: UseFilter
    cfg.params[2].name = "UseFilter";
    cfg.params[2].defaultValue = "true";
    cfg.params[2].type = CONFIG_PARAM_BOOL;
    cfg.params[2].description = "Enable signal filter";
    
    return cfg;
}
```

**3.3. Update destructor:**

```cpp
CYourMethod::~CYourMethod() {
    // ⭐ REQUIRED: Unregister config khi destroy
    UnregisterConfig();
    
    // Cleanup detectors/calculators nếu có
    // if(CheckPointer(m_detector) == POINTER_DYNAMIC) {
    //     delete m_detector;
    // }
}
```

---

### 🔍 Bước 4: Implement Scan() Method

**Scan() là method chính, PHẢI tuân theo flow sau:**

```cpp
MethodSignal CYourMethod::Scan(const RiskGateResult &riskGate) {
    MethodSignal signal;
    signal.valid = false;
    signal.methodName = "YourMethod";
    signal.score = 0;
    signal.orderType = ORDER_BUY;  // Default, sẽ update sau
    
    // ═══════════════════════════════════════════════════════
    // STEP 1: Check Risk Gate (Layer 0 Integration) ⭐
    // ═══════════════════════════════════════════════════════
    if(!riskGate.canTrade) {
        return signal;  // Early return nếu không được trade
    }
    
    // ═══════════════════════════════════════════════════════
    // STEP 2: Update price series
    // ═══════════════════════════════════════════════════════
    UpdateSeries();
    
    // ═══════════════════════════════════════════════════════
    // STEP 3: Detect signals (implement your logic)
    // ═══════════════════════════════════════════════════════
    if(!DetectYourSignal()) {
        return signal;  // Không có signal
    }
    
    // ═══════════════════════════════════════════════════════
    // STEP 4: Calculate Entry/SL/TP
    // ═══════════════════════════════════════════════════════
    double entry, sl, tp, rr;
    if(!CalculateEntrySLTP(entry, sl, tp, rr)) {
        return signal;  // Không tính được Entry/SL/TP
    }
    
    // ═══════════════════════════════════════════════════════
    // STEP 5: Validate Risk (Layer 0 Integration) ⭐
    // ═══════════════════════════════════════════════════════
    double riskPips = MathAbs(entry - sl) / _Point;
    if(riskPips > riskGate.remainingRiskPips) {
        return signal;  // Risk quá lớn hoặc không còn risk available
    }
    
    // Validate lot size
    double calculatedLot = CalculateLotSize(riskPips, riskGate);
    if(calculatedLot > riskGate.remainingLotSize || calculatedLot <= 0) {
        return signal;  // Không còn lot available
    }
    
    // ═══════════════════════════════════════════════════════
    // STEP 6: Build signal (Layer 2 Integration) ⭐
    // ═══════════════════════════════════════════════════════
    signal.orderType = ORDER_BUY_LIMIT;  // or ORDER_SELL_LIMIT, ORDER_BUY, ORDER_SELL, ORDER_BUY_STOP, ORDER_SELL_STOP, ORDER_BUY_STOP_LIMIT, ORDER_SELL_STOP_LIMIT
    signal.entryPrice = entry;
    signal.slPrice = sl;
    signal.tpPrice = tp;
    signal.rr = rr;
    signal.entryType = ENTRY_LIMIT;  // or ENTRY_STOP, ENTRY_MARKET (simplified version)
    signal.entryReason = "Your method entry reason";
    
    // ═══════════════════════════════════════════════════════
    // STEP 7: Score signal
    // ═══════════════════════════════════════════════════════
    signal.score = Score(signal);
    if(signal.score < 100.0) {
        return signal;  // Score quá thấp
    }
    
    // ═══════════════════════════════════════════════════════
    // STEP 8: Create Position Plan
    // ═══════════════════════════════════════════════════════
    signal.positionPlan = CreatePositionPlan(signal);
    
    // ═══════════════════════════════════════════════════════
    // STEP 9: Validate signal (Layer 2 Integration) ⭐
    // ═══════════════════════════════════════════════════════
    if(signal.score >= 100.0 && signal.rr >= 2.0) {
        signal.valid = true;  // ⭐ Chỉ set valid = true khi signal hợp lệ
    }
    
    return signal;
}
```

**Lưu ý quan trọng:**
- ✅ **PHẢI** check `riskGate.canTrade` trước
- ✅ **PHẢI** validate risk ≤ `riskGate.maxRiskPips`
- ✅ **PHẢI** set `valid = true` chỉ khi signal hợp lệ
- ✅ **PHẢI** set `score ≥ 100` (minimum threshold)
- ✅ **PHẢI** calculate đầy đủ `entryPrice`, `slPrice`, `tpPrice`, `rr`

---

### 🧮 Bước 5: Implement Helper Methods

**5.1. UpdateSeries() - Update price data:**

```cpp
void CYourMethod::UpdateSeries() {
    // Copy price arrays
    // Example:
    // ArraySetAsSeries(m_high, true);
    // CopyHigh(m_symbol, m_timeframe, 0, 100, m_high);
    // CopyLow(m_symbol, m_timeframe, 0, 100, m_low);
    // CopyClose(m_symbol, m_timeframe, 0, 100, m_close);
}
```

**5.2. DetectYourSignal() - Detection logic:**

```cpp
bool CYourMethod::DetectYourSignal() {
    // ⭐ Implement detection logic của bạn
    // Example:
    // - Check indicators
    // - Check patterns
    // - Check structure
    // - Check conditions
    
    // Return true nếu có signal, false nếu không
    return false;
}
```

**5.3. CalculateEntrySLTP() - Entry/SL/TP calculation:**

```cpp
bool CYourMethod::CalculateEntrySLTP(double &entry, double &sl, double &tp, double &rr) {
    // ⭐ Implement Entry/SL/TP calculation
    // Example:
    // entry = CalculateEntryPrice();
    // sl = CalculateStopLoss(entry);
    // tp = CalculateTakeProfit(entry);
    
    // Calculate RR
    double risk = MathAbs(entry - sl);
    double reward = MathAbs(tp - entry);
    if(risk > 0) {
        rr = reward / risk;
    } else {
        rr = 0;
    }
    
    // Validate
    if(entry == 0 || sl == 0 || tp == 0 || rr < 1.0) {
        return false;
    }
    
    return true;
}
```

**5.4. GetATR() - Helper function:**

```cpp
double CYourMethod::GetATR() {
    // Get ATR value
    // Example:
    // int atrHandle = iATR(m_symbol, m_timeframe, 14);
    // double atr[];
    // ArraySetAsSeries(atr, true);
    // CopyBuffer(atrHandle, 0, 0, 1, atr);
    // return atr[0];
    return 0;
}
```

---

### 📊 Bước 6: Implement Score() Method

**6.1. Scoring logic:**

```cpp
double CYourMethod::Score(const MethodSignal &signal) {
    double score = 0.0;
    
    // ⭐ Implement scoring logic của bạn
    // Example scoring system:
    
    // Base score
    if(signal có pattern chính) {
        score += 100.0;
    }
    
    // Component bonuses
    if(signal có component A) score += 40.0;
    if(signal có component B) score += 30.0;
    if(signal có component C) score += 25.0;
    
    // Quality bonuses
    if(signal.rr >= 3.0) score += 30.0;
    else if(signal.rr >= 2.0) score += 20.0;
    
    // Penalties
    if(signal có issue) score -= 20.0;
    
    return score;
}
```

**Lưu ý:**
- Score tối thiểu để signal valid: **≥ 100**
- Score càng cao → Signal càng tốt
- Penalties có thể làm score < 100 → Signal không valid

---

### 💰 Bước 7: Implement CreatePositionPlan() Method

**7.1. Position Plan structure:**

```cpp
PositionPlan CYourMethod::CreatePositionPlan(const MethodSignal &signal) {
    PositionPlan plan;
    plan.methodName = "YourMethod";
    plan.strategy = "Balanced";  // or "Conservative", "Aggressive"
    
    // ═══════════════════════════════════════════════════════
    // DCA Plan - Tạo DCA Orders Array ⭐
    // ═══════════════════════════════════════════════════════
    plan.dcaPlan.enabled = true;  // or false nếu không dùng DCA
    plan.dcaPlan.maxLevels = 2;   // Số level DCA (0, 1, 2, 3)
    
    // ⭐ Tạo DCA Orders Array (format như JSON)
    ArrayResize(plan.dcaPlan.dcaOrders, 2);
    
    // DCA Level 1
    plan.dcaPlan.dcaOrders[0].level = 1;
    plan.dcaPlan.dcaOrders[0].orderType = signal.orderType;  // Same order type (ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, etc.)
    plan.dcaPlan.dcaOrders[0].entryType = ENTRY_MARKET;  // Simplified version
    plan.dcaPlan.dcaOrders[0].reason = signal.entryReason;  // "OB + FVG"
    plan.dcaPlan.dcaOrders[0].entryPrice = signal.entryPrice;  // 4250 (hoặc tính lại)
    plan.dcaPlan.dcaOrders[0].slPrice = signal.slPrice;  // Sync với original (4245)
    plan.dcaPlan.dcaOrders[0].tpPrice = signal.tpPrice;  // Sync với original (4270)
    plan.dcaPlan.dcaOrders[0].lotMultiplier = 0.5;  // 0.5× original lot
    plan.dcaPlan.dcaOrders[0].triggerR = 0.75;  // Trigger tại +0.75R
    
    // DCA Level 2
    plan.dcaPlan.dcaOrders[1].level = 2;
    plan.dcaPlan.dcaOrders[1].orderType = signal.orderType;  // Same order type
    plan.dcaPlan.dcaOrders[1].entryType = ENTRY_MARKET;  // Simplified version
    plan.dcaPlan.dcaOrders[1].reason = signal.entryReason;
    plan.dcaPlan.dcaOrders[1].entryPrice = signal.entryPrice + (signal.entryPrice - signal.slPrice) * 0.5;  // 4255
    plan.dcaPlan.dcaOrders[1].slPrice = signal.slPrice;  // Sync (4245)
    plan.dcaPlan.dcaOrders[1].tpPrice = signal.tpPrice;  // Sync (4270)
    plan.dcaPlan.dcaOrders[1].lotMultiplier = 0.33;  // 0.33× original lot
    plan.dcaPlan.dcaOrders[1].triggerR = 1.5;  // Trigger tại +1.5R
    
    // Backward compatibility (for old code)
    plan.dcaPlan.level1_triggerR = 0.75;
    plan.dcaPlan.level1_lotMultiplier = 0.5;
    plan.dcaPlan.level2_triggerR = 1.5;
    plan.dcaPlan.level2_lotMultiplier = 0.33;
    plan.dcaPlan.dcaEntryType = ENTRY_MARKET;
    plan.dcaPlan.dcaEntryReason = "At current price when trigger";
    
    // ═══════════════════════════════════════════════════════
    // BE Plan - Format như JSON ⭐
    // ═══════════════════════════════════════════════════════
    plan.bePlan.enabled = true;
    plan.bePlan.triggerR = 1.0;                // BE tại +1.0R
    // BE price = entryPrice + (entryPrice - slPrice) = 4250 + 5 = 4260 (như JSON "BE": 4260)
    plan.bePlan.moveAllPositions = true;       // Move tất cả positions
    plan.bePlan.reason = "Standard BE";
    
    // ═══════════════════════════════════════════════════════
    // Trail Plan - Format như JSON ⭐
    // ═══════════════════════════════════════════════════════
    plan.trailPlan.enabled = true;
    plan.trailPlan.startPrice = signal.entryPrice + (signal.entryPrice - signal.slPrice);  // 4260 (BE price)
    plan.trailPlan.startR = 1.0;               // Start tại +1.0R
    plan.trailPlan.stepPips = 30;              // ⭐ Move mỗi 30 pips (như JSON "PIPS": 30)
    plan.trailPlan.stepR = 0.5;                // Move mỗi +0.5R (alternative)
    plan.trailPlan.distanceATR = 2.0;           // Distance = 2×ATR
    plan.trailPlan.lockProfit = true;
    plan.trailPlan.strategy = "ATR-based";
    
    // ═══════════════════════════════════════════════════════
    // Basket Management
    // ═══════════════════════════════════════════════════════
    plan.syncSL = true;    // Sync SL cho tất cả positions
    plan.basketTP = false;  // Dùng basket TP?
    plan.basketSL = false;  // Dùng basket SL?
    
    return plan;
}
```

**Lưu ý:**
- Mỗi method tự quyết định strategy (Conservative/Aggressive/Balanced)
- DCA có thể 0, 1, 2, hoặc 3 levels
- BE và Trail có thể enable/disable

---

### 🔌 Bước 8: Integration với EA

**8.1. Include method vào EA (như một class):**

```cpp
// Trong EA file (V2-oat.mq5 hoặc oat.mq5)
// ⭐ Import method như một class
#include "..\Include\YourMethod\your_method.mqh"

// ⭐ Declare method instance (như class object)
CYourMethod yourMethod;

// OnInit()
int OnInit() {
    // ... other initialization ...
    
    // ⭐ Initialize method (tự động register config)
    if(!yourMethod.Init(_Symbol, PERIOD_CURRENT,
                       20,    // lookbackPeriod
                       1.5,   // threshold
                       true)) { // useFilter
        Print("❌ Failed to initialize YourMethod");
        return INIT_FAILED;
    }
    
    // Config sẽ tự động hiển thị trong EA input panel
    return INIT_SUCCEEDED;
}
```

**Lưu ý:**
- Method được import như một **class**, không phải function
- Mỗi method là một **instance** riêng biệt
- Có thể có nhiều instances của cùng một method (nếu cần)

**8.2. Scan method trong OnTick() (như gọi method của class):**

```cpp
void OnTick() {
    // ... other code ...
    
    // Get Risk Gate result (với position tracking)
    RiskGateResult riskGate = g_RiskGate.Check();
    // riskGate.remainingRiskPips = maxRiskPips - filledRiskPips - pendingRiskPips
    // riskGate.remainingLotSize = maxLotSize - filledLotSize - pendingLotSize
    
    // ⭐ Scan method (như gọi method của class)
    MethodSignal signal = yourMethod.Scan(riskGate);
    
    if(signal.valid) {
        // ⭐ Validate sử dụng remaining (không phải max)
        if(signal.rr >= 2.0 && 
           CalculateRiskPips(signal) <= riskGate.remainingRiskPips &&
           CalculateLotSize(signal) <= riskGate.remainingLotSize) {
            // Pass to Layer 2 (Arbitration)
            // arbiter.CollectSignals(signal);
        }
    }
}
```

**8.3. Config tự động hiển thị:**

Khi method được include và `Init()` được gọi, config sẽ tự động hiển thị trong EA input panel:

```
═══════ Your Method ═══════
input bool InpYourMethod_Enable = true;
input int InpYourMethod_LookbackPeriod = 20;
input double InpYourMethod_Threshold = 1.5;
input bool InpYourMethod_UseFilter = true;
```

---

### ✅ Bước 9: Testing Checklist

**9.1. Compile check:**
- [ ] Code compile không có lỗi
- [ ] Không có warnings quan trọng

**9.2. Integration check:**
- [ ] Method check `riskGate.canTrade` trước khi scan
- [ ] Method validate risk ≤ `riskGate.maxRiskPips`
- [ ] Method output `MethodSignal` với đầy đủ fields
- [ ] Method set `valid = true` chỉ khi signal hợp lệ
- [ ] Method set `score ≥ 100` (minimum threshold)

**9.3. Config check:**
- [ ] Method implement `GetConfig()` đầy đủ
- [ ] Method gọi `RegisterConfig()` trong `Init()`
- [ ] Method gọi `UnregisterConfig()` trong destructor
- [ ] Config hiển thị trong EA input panel

**9.4. Functionality check:**
- [ ] Method detect signals đúng
- [ ] Method calculate Entry/SL/TP đúng
- [ ] Method score signals đúng
- [ ] Method create PositionPlan đầy đủ

**9.5. Edge cases check:**
- [ ] Method handle không có signal (return `valid = false`)
- [ ] Method handle risk quá lớn (return `valid = false`)
- [ ] Method handle score quá thấp (return `valid = false`)
- [ ] Method handle invalid Entry/SL/TP (return `valid = false`)

---

### 📝 Bước 10: Documentation

**10.1. Comment code:**

```cpp
// ═══════════════════════════════════════════════════════════
// Your Method - Description
// ═══════════════════════════════════════════════════════════
// Method này detect signals dựa trên:
// - Pattern A
// - Pattern B
// - Condition C
//+------------------------------------------------------------------+
```

**10.2. Update docs:**

- Ghi lại method description
- Ghi lại parameters và ý nghĩa
- Ghi lại detection logic
- Ghi lại scoring system
- Ghi lại position management strategy

---

### 🎯 Ví Dụ Hoàn Chỉnh

**Xem file template:** `Include/Methods/method_template.mqh`

**Template đã có:**
- ✅ Interface contract đầy đủ
- ✅ Integration với Layer 0 (Risk Gate check)
- ✅ Integration với Layer 2 (MethodSignal output)
- ✅ Config registration/unregistration
- ✅ Position plan structure
- ✅ Scoring structure
- ✅ Helper methods structure

**Cách sử dụng:**
1. Copy `method_template.mqh` → `your_method.mqh`
2. Follow các bước trên để implement
3. Test và verify integration
4. Deploy vào production

---

### ❓ FAQ

**Q: Method có thể không dùng DCA không?**
A: Có, set `plan.dcaPlan.enabled = false` và `plan.dcaPlan.maxLevels = 0`

**Q: Method có thể không dùng BE/Trail không?**
A: Có, set `plan.bePlan.enabled = false` hoặc `plan.trailPlan.enabled = false`

**Q: Score tối thiểu là bao nhiêu?**
A: **≥ 100** để signal được coi là valid

**Q: Config không hiển thị trong EA?**
A: Check:
- Method có gọi `RegisterConfig()` trong `Init()` không?
- EA có include method file không?
- EA có rebuild sau khi thêm method không?

**Q: Method không detect được signal?**
A: Check:
- `DetectYourSignal()` có return `true` không?
- Detection logic có đúng không?
- Price series có được update không?

---

### 🔗 Related Files

- `Include/Methods/method_base.mqh` - Base class interface
- `Include/Methods/method_config.mqh` - Config system
- `Include/Methods/method_template.mqh` - Template file
- `Include/Common/signal_structs.mqh` - Signal structures
- `docs/v3/00_RISK_GATE.md` - Layer 0 documentation

---

## 📦 Output Structure: MethodSignal

**Mỗi phương pháp output `MethodSignal` struct:**

```cpp
struct MethodSignal {
    bool valid;                    // Signal có hợp lệ không
    string methodName;             // "SMC", "ICT", "Custom"
    
    // Entry information
    ENUM_ORDER_TYPE orderType;     // ⭐ ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, ORDER_SELL_LIMIT, ORDER_BUY_STOP, ORDER_SELL_STOP, ORDER_BUY_STOP_LIMIT, ORDER_SELL_STOP_LIMIT (Mỗi lệnh chỉ là 1 loại)
    double entryPrice;             // Entry price
    ENTRY_TYPE entryType;          // ⭐ LIMIT, STOP, MARKET (simplified version)
    string entryReason;            // "FVG Limit Entry", "OB Retest", etc.
    
    // Risk management
    double slPrice;                // Stop Loss price
    double tpPrice;                // Take Profit price
    double rr;                     // Risk/Reward ratio
    
    // Signal quality
    double score;                  // Signal score (0-1000+)
    string pattern;                // "BOS+OB", "Sweep+FVG", etc.
    
    // Position management plan
    PositionPlan positionPlan;     // BE/DCA/Trail strategy
};
```

### 📋 PositionPlan Structure

**Mỗi phương pháp tự quyết định strategy quản lý position:**

```cpp
struct PositionPlan {
    string methodName;             // "SMC", "ICT"
    string strategy;               // "Conservative", "Aggressive", "Balanced"
    
    // DCA Plan
    DCAPlan dcaPlan;               // DCA levels, triggers, lot multipliers
    
    // Breakeven Plan
    BEPlan bePlan;                 // BE trigger (R), move all positions
    
    // Trailing Stop Plan
    TrailPlan trailPlan;           // Trail start (R), step (R), distance (ATR)
    
    // Basket management
    bool syncSL;                   // Sync SL cho tất cả positions
    bool basketTP;                 // Dùng basket TP
    bool basketSL;                 // Dùng basket SL
};
```

---

## 🔧 Methods Overview

### 📋 Available Methods

**1. SMC Method** - Smart Money Concept
- **Focus**: BOS + OB/FVG + Sweep
- **Strategy**: Conservative (DCA 2 levels, BE +1R, Trail 2×ATR)
- **Chi tiết**: Xem [`docs/v3/01_LAYER1_DETECTION_SMC.md`](01_LAYER1_DETECTION_SMC.md)

**2. ICT Method** - Inner Circle Trader
- **Focus**: FVG + OB + Momentum
- **Strategy**: Aggressive (DCA 3 levels, BE +0.75R, Trail 1.5×ATR)
- **Chi tiết**: Xem [`docs/v3/01_LAYER1_DETECTION_ICT.md`](01_LAYER1_DETECTION_ICT.md)

**3. Custom Method** - Template
- **Focus**: User-defined
- **Strategy**: User-defined
- **Chi tiết**: Xem phần "Custom Method - Template" bên dưới

### 📊 So Sánh Methods

| Feature | SMC | ICT |
|---------|-----|-----|
| **Core Pattern** | BOS + OB/FVG | FVG + OB |
| **DCA Levels** | 2 (Conservative) | 3 (Aggressive) |
| **BE Trigger** | +1.0R | +0.75R (Early) |
| **Trail Start** | +1.0R | +0.75R |
| **Trail Step** | +0.5R | +0.25R (Tight) |
| **Trail Distance** | 2.0×ATR | 1.5×ATR (Tight) |
| **Basket TP** | No | Yes |
| **SL Distance** | 2.0×ATR (cap 3.5×) | 1.5×ATR (cap 2.5×) |
| **Min SL** | 1000 points | 800 points |

**Chi tiết đầy đủ:** Xem các file riêng cho từng method.

---

## 🔧 Custom Method - Template

### 📁 File Structure

```
Custom/
├─ custom_method.mqh       [Main class - CCustomMethod]
├─ custom_detectors.mqh    [CDetectorCustom - Custom detectors]
├─ custom_calculator.mqh   [CCalculatorCustom - Custom calculation]
├─ custom_scorer.mqh       [CScorerCustom - Custom scoring]
└─ custom_risk_plan.mqh    [CRiskPlanCustom - Custom risk plan]
```

### 📝 Template Structure

**Mỗi file trong Custom/ là template, có thể copy và modify:**

1. **`custom_method.mqh`**: Copy từ `smc_method.mqh`, modify logic
2. **`custom_detectors.mqh`**: Implement custom detectors
3. **`custom_calculator.mqh`**: Implement custom Entry/SL/TP logic
4. **`custom_scorer.mqh`**: Implement custom scoring
5. **`custom_risk_plan.mqh`**: Implement custom BE/DCA/Trail strategy

**Template file:** `Include/Methods/method_template.mqh` - Copy và modify

---

## 🔄 Integration với Layer 0 (Risk Gate)

**Layer 1 nhận input từ Layer 0:**

```cpp
struct RiskGateResult {
    bool canTrade;              // Có được trade không
    double maxRiskPips;         // Số pip tối đa có thể risk
    double maxLotSize;          // Lot size tối đa
    double currentEquity;       // Equity hiện tại
    double dailyMDD;            // Daily MDD (%)
    bool sessionActive;         // Session có active không
};
```

**Layer 1 sử dụng `RiskGateResult` để:**
- Validate có thể trade không (`canTrade`)
- Limit lot size theo `maxLotSize`
- Validate risk không vượt quá `maxRiskPips`
- Check session active

---

## 🔄 Integration với Layer 2 (Arbitration)

**Layer 1 output `MethodSignal[]` array cho Layer 2:**

```cpp
// Main EA (OnTick)
MethodSignal signals[];

// Scan tất cả methods
CSMCMethod smc;
CICTMethod ict;
CCustomMethod custom;

// Collect signals
int count = 0;
MethodSignal smcSignal = smc.Scan(riskGate);
if(smcSignal.valid) signals[count++] = smcSignal;

MethodSignal ictSignal = ict.Scan(riskGate);
if(ictSignal.valid) signals[count++] = ictSignal;

MethodSignal customSignal = custom.Scan(riskGate);
if(customSignal.valid) signals[count++] = customSignal;

// Pass to Layer 2 (Arbitration)
arbiter.CollectSignals(signals);
```

**Layer 2 sẽ:**
- Rank signals theo score
- Select best signal
- Determine entry method
- Format execution order

---

## 📋 Checklist Implementation

### ✅ SMC Method

- [ ] `smc_method.mqh` - Main class, implement `CMethodBase`
- [ ] `smc_detectors.mqh` - BOS, Sweep, OB, FVG detectors
- [ ] `smc_calculator.mqh` - Entry/SL/TP calculation
- [ ] `smc_scorer.mqh` - Scoring logic (v2.1 enhanced)
- [ ] `smc_risk_plan.mqh` - BE/DCA/Trail strategy
- [ ] `GetConfig()` - Config definition
- [ ] `RegisterConfig()` - Config registration
- [ ] Test: Scan() output valid MethodSignal
- [ ] Test: PositionPlan có đầy đủ BE/DCA/Trail
- [ ] Test: Score ≥ 100 mới valid

### ✅ ICT Method

- [ ] `ict_method.mqh` - Main class, implement `CMethodBase`
- [ ] `ict_detectors.mqh` - FVG, OB, Momentum detectors
- [ ] `ict_calculator.mqh` - Entry/SL/TP calculation
- [ ] `ict_scorer.mqh` - Scoring logic
- [ ] `ict_risk_plan.mqh` - BE/DCA/Trail strategy
- [ ] `GetConfig()` - Config definition
- [ ] `RegisterConfig()` - Config registration
- [ ] Test: Scan() output valid MethodSignal
- [ ] Test: PositionPlan có đầy đủ BE/DCA/Trail

### ✅ Custom Method (Template)

- [ ] `custom_method.mqh` - Template class
- [ ] `custom_detectors.mqh` - Template detectors
- [ ] `custom_calculator.mqh` - Template calculator
- [ ] `custom_scorer.mqh` - Template scorer
- [ ] `custom_risk_plan.mqh` - Template risk plan
- [ ] `GetConfig()` - Config definition
- [ ] `RegisterConfig()` - Config registration
- [ ] Documentation: Hướng dẫn tạo method mới

---

## 🎯 Lợi Ích Cấu Trúc Mới

### ✅ Modularity

- Mỗi phương pháp độc lập, không phụ thuộc lẫn nhau
- Dễ thêm/xóa phương pháp (chỉ cần thêm/xóa folder)
- Dễ maintain (sửa SMC không ảnh hưởng ICT)

### ✅ Self-contained

- Mỗi phương pháp tự detect, tự tính, tự score
- Không cần arbiter.mqh để tính Entry/SL/TP
- Không cần executor.mqh để quyết định BE/DCA/Trail

### ✅ Extensibility

- Thêm method mới: Copy Custom/ folder, modify logic
- Không cần sửa code core (arbiter, executor, main EA)
- Dễ test từng method riêng lẻ

### ✅ Clear Responsibility

- Mỗi file một nhiệm vụ rõ ràng
- Detectors chỉ detect, không tính toán
- Calculator chỉ tính toán, không detect
- Risk plan chỉ tạo plan, không execute

### ✅ Config System

- Config tự động hiển thị khi import method
- Config tự động ẩn khi unimport method
- Không cần sửa EA file khi thêm/xóa method

---

## 📝 Notes

1. **Mỗi phương pháp tự quyết định strategy** - SMC có thể dùng DCA 2 levels, ICT có thể dùng 3 levels
2. **Entry/SL/TP calculation là method-specific** - SMC dùng structure-based, ICT có thể dùng khác
3. **Scoring system là method-specific** - Mỗi method có cách chấm điểm riêng
4. **PositionPlan là method-specific** - Mỗi method tự quyết định BE/DCA/Trail strategy
5. **Layer 2 (Arbitration) chỉ chọn signal tốt nhất** - Không tính toán Entry/SL/TP nữa
6. **Config system tự động** - Import method → Config hiện, Unimport → Config ẩn

---

## 🔗 Related Docs

### Layer 1 Documentation

- **`docs/v3/01_LAYER1_DETECTION.md`** - Layer 1 Overview (file này)

### Other Layers

- `docs/v3/REFACTOR_PROPOSAL.md` - Tổng quan kiến trúc
- `docs/v3/00_RISK_GATE.md` - Layer 0 (Risk Gate)

### Reference Docs

- `docs/v2/code_logic/02_DETECTORS.md` - Detectors hiện tại (reference)
- `docs/v2/code_logic/03_ARBITER.md` - Arbiter hiện tại (reference)
## 📤 Output Format - MethodSignal to Layer 2

### 🎯 Order Types (MT5 Order Types - Mỗi lệnh chỉ là 1 loại)

**Enum:** `ENUM_ORDER_TYPE`

```cpp
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
```

**Lưu ý quan trọng:**
- ✅ **Mỗi lệnh chỉ là 1 loại** - Không kết hợp nhiều loại
- ✅ **ORDER_BUY/ORDER_SELL**: Market order - thực hiện ngay
- ✅ **ORDER_BUY_LIMIT/ORDER_SELL_LIMIT**: Limit order - chờ hồi về
- ✅ **ORDER_BUY_STOP/ORDER_SELL_STOP**: Stop order - chờ phá vỡ
- ✅ **ORDER_BUY_STOP_LIMIT/ORDER_SELL_STOP_LIMIT**: Stop Limit order - kết hợp Stop và Limit

### 🎯 Format JSON (Reference)

**Layer 1 output MethodSignal với format tương tự JSON sau:**

```json
{
    "name": "SMC",
    "type": "ORDER_BUY_LIMIT",  // ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, ORDER_SELL_LIMIT, ORDER_BUY_STOP, ORDER_SELL_STOP, ORDER_BUY_STOP_LIMIT, ORDER_SELL_STOP_LIMIT
    "reason": "OB + FVG",
    "EN": 4250,     // Entry price
    "SL": 4245,     // Stop Loss
    "TP": 4270,     // Take Profit
    "DCA": [
        {
            "type": "BUY",
            "reason": "OB + FVG",
            "EN": 4250,
            "SL": 4245,
            "TP": 4270
        },
        {
            "type": "BUY",
            "reason": "OB + FVG",
            "EN": 4255,
            "SL": 4245,
            "TP": 4270
        }
    ],
    "BE": 4260,     // Breakeven price
    "TRAIL": {
        "Start": 4260,  // Khi bắt đầu BE
        "PIPS": 30      // Cứ 30 PIP kéo 1 lần
    }
}
```

### 📊 MethodSignal Structure (Mapped to JSON)

**MethodSignal struct tương ứng với JSON format:**

```cpp
struct MethodSignal {
    // Main order
    string       methodName;      // "SMC" (name)
    ENUM_ORDER_TYPE orderType;    // ⭐ ORDER_BUY, ORDER_SELL, ORDER_BUY_LIMIT, ORDER_SELL_LIMIT, ORDER_BUY_STOP, ORDER_SELL_STOP, ORDER_BUY_STOP_LIMIT, ORDER_SELL_STOP_LIMIT (Mỗi lệnh chỉ là 1 loại)
    string       entryReason;      // "OB + FVG" (reason)
    double       entryPrice;       // 4250 (EN)
    double       slPrice;          // 4245 (SL)
    double       tpPrice;          // 4270 (TP)
    
    // DCA orders array
    PositionPlan positionPlan;     // Contains DCA array
    // positionPlan.dcaPlan.dcaOrders[] = [
    //   {level: 1, entryPrice: 4250, ...},
    //   {level: 2, entryPrice: 4255, ...}
    // ]
    
    // BE & Trail
    // positionPlan.bePlan.triggerR → BE price = 4260
    // positionPlan.trailPlan.startPrice = 4260, stepPips = 30
};
```

### 🔄 Flow: Layer 1 → Layer 2 → Execution

**1. Layer 1 (Detection) → MethodSignal:**

```cpp
MethodSignal signal = smc.Scan(riskGate);
// signal.methodName = "SMC"
// signal.orderType = ORDER_BUY_LIMIT (hoặc ORDER_BUY, ORDER_SELL_LIMIT, ORDER_BUY_STOP, ORDER_SELL_STOP, etc.)
// signal.entryPrice = 4250
// signal.slPrice = 4245
// signal.tpPrice = 4270
// signal.positionPlan.dcaPlan.dcaOrders[] = [DCA1, DCA2]
// signal.positionPlan.bePlan.triggerR = 1.0 → BE = 4260
// signal.positionPlan.trailPlan.startPrice = 4260, stepPips = 30
```

**2. Layer 2 (Arbitration) → PendingOrder Array:**

```cpp
// Layer 2 nhận MethodSignal và tạo PendingOrder array
PendingOrder pendingOrders[];

// Original order
PendingOrder original;
original.orderID = "SMC_20250121_001";  // ⭐ Unique ID
original.methodName = "SMC";
original.orderType = ORDER_BUY_LIMIT;  // ⭐ Enum từ MT5 (Mỗi lệnh chỉ là 1 loại)
original.entryPrice = 4250;
original.slPrice = 4245;
original.tpPrice = 4270;
original.isDCA = false;
original.dcaLevel = 0;
original.status = ORDER_STATUS_PENDING;
pendingOrders[0] = original;

// DCA orders
for(int i = 0; i < ArraySize(signal.positionPlan.dcaPlan.dcaOrders); i++) {
    DCAOrder dca = signal.positionPlan.dcaPlan.dcaOrders[i];
    PendingOrder dcaOrder;
    dcaOrder.orderID = "SMC_20250121_001_DCA" + IntegerToString(i+1);  // ⭐ ID với suffix
    dcaOrder.methodName = "SMC";
    dcaOrder.orderType = dca.orderType;
    dcaOrder.entryPrice = dca.entryPrice;
    dcaOrder.slPrice = dca.slPrice;
    dcaOrder.tpPrice = dca.tpPrice;
    dcaOrder.isDCA = true;
    dcaOrder.dcaLevel = dca.level;
    dcaOrder.parentOrderID = original.orderID;  // ⭐ Link to parent
    dcaOrder.status = ORDER_STATUS_PENDING;
    pendingOrders[ArraySize(pendingOrders)] = dcaOrder;
}
```

**3. Execution Layer → ExecutionOrder Array:**

```cpp
// Khi order được filled, chuyển từ PendingOrder → ExecutionOrder
ExecutionOrder executionOrders[];

for(int i = 0; i < ArraySize(pendingOrders); i++) {
    if(pendingOrders[i].status == ORDER_STATUS_FILLED) {
        ExecutionOrder exec;
        exec.orderID = pendingOrders[i].orderID;  // ⭐ Same ID
        exec.createdTime = pendingOrders[i].createdTime;
        exec.filledTime = TimeCurrent();  // ⭐ Filled time
        exec.methodName = pendingOrders[i].methodName;
        exec.orderType = pendingOrders[i].orderType;
        exec.entryPrice = pendingOrders[i].entryPrice;
        exec.slPrice = pendingOrders[i].slPrice;
        exec.tpPrice = pendingOrders[i].tpPrice;
        exec.lots = pendingOrders[i].lots;
        exec.isDCA = pendingOrders[i].isDCA;
        exec.dcaLevel = pendingOrders[i].dcaLevel;
        exec.parentOrderID = pendingOrders[i].parentOrderID;
        exec.ticket = pendingOrders[i].ticket;  // ⭐ MT5 ticket
        exec.isOpen = true;
        executionOrders[ArraySize(executionOrders)] = exec;
    }
}
```

### 🆔 ID Tracking System

**Format ID:**
- **Original order**: `"{MethodName}_{Date}_{Sequence}"`
  - Ví dụ: `"SMC_20250121_001"`
- **DCA order**: `"{ParentID}_DCA{Level}"`
  - Ví dụ: `"SMC_20250121_001_DCA1"`, `"SMC_20250121_001_DCA2"`

**Tracking:**
- ✅ Mỗi order có unique ID
- ✅ DCA orders link đến parent order qua `parentOrderID`
- ✅ ExecutionOrder giữ nguyên ID từ PendingOrder
- ✅ Có thể query orders theo ID, methodName, parentOrderID

### 📋 Example: Complete Flow

**Step 1: Layer 1 tạo MethodSignal**
```cpp
MethodSignal signal;
signal.methodName = "SMC";
signal.orderType = ORDER_BUY_LIMIT;  // ⭐ Enum từ MT5 (Mỗi lệnh chỉ là 1 loại)
signal.entryPrice = 4250;
signal.slPrice = 4245;
signal.tpPrice = 4270;
// ... DCA, BE, Trail plans ...
```

**Step 2: Layer 2 tạo PendingOrder array**
```cpp
PendingOrder pending[];
// Original: "SMC_20250121_001"
// DCA1: "SMC_20250121_001_DCA1"
// DCA2: "SMC_20250121_001_DCA2"
```

**Step 3: Execution place orders**
```cpp
// Place original order → ticket = 12345
// pending[0].ticket = 12345
// pending[0].status = ORDER_STATUS_PENDING
```

**Step 4: Order filled → chuyển sang ExecutionOrder**
```cpp
// pending[0].status = ORDER_STATUS_FILLED
// → Create ExecutionOrder với ID "SMC_20250121_001"
// executionOrders[0].orderID = "SMC_20250121_001"
// executionOrders[0].ticket = 12345
// executionOrders[0].isOpen = true
```

**Step 5: DCA trigger → place DCA order**
```cpp
// Price hit +0.75R → Trigger DCA1
// Place DCA1 order → ticket = 12346
// pending[1].ticket = 12346
// pending[1].status = ORDER_STATUS_PENDING
```

**Step 6: DCA filled → chuyển sang ExecutionOrder**
```cpp
// pending[1].status = ORDER_STATUS_FILLED
// → Create ExecutionOrder với ID "SMC_20250121_001_DCA1"
// executionOrders[1].orderID = "SMC_20250121_001_DCA1"
// executionOrders[1].parentOrderID = "SMC_20250121_001"
// executionOrders[1].ticket = 12346
```

### ✅ Benefits

- ✅ **ID Tracking**: Mỗi order có unique ID để tracking
- ✅ **Parent-Child Link**: DCA orders link đến parent order
- ✅ **Status Tracking**: Pending → Filled → Execution
- ✅ **Query Support**: Query orders theo ID, method, parent
- ✅ **Complete History**: Track từ pending → execution → closed

---