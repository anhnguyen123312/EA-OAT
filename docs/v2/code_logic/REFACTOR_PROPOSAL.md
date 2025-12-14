# 🏗️ Đề Xuất Refactor Bot - Cấu Trúc Mở Rộng

## 📍 Tổng Quan

Tài liệu này mô tả **thiết kế mới** cho bot EA với cấu trúc **modular, mở rộng dễ dàng**, cho phép thêm/bỏ phương pháp trading mà không cần sửa code core.

---

## 🎯 Mục Tiêu Thiết Kế

1. ✅ **Risk Management Layer đầu tiên** - Quyết định có trade không, trade bao nhiêu pip
2. ✅ **Detection Layer modular** - Chia theo Phương pháp (SMC, ICT), mỗi phương pháp một file riêng
3. ✅ **Mỗi detector tự tính entry/sl/tp và chấm điểm**
4. ✅ **Mỗi detector output kế hoạch DCA, BE, Trail** - Lập kế hoạch quản lý position hoàn chỉnh
5. ✅ **ARBITRATION quyết định entry và format xuống EXECUTION**
6. ✅ **EXECUTION thực hiện và theo dõi lệnh theo kế hoạch**
7. ✅ **Dashboard hiển thị thông số**

**Mục tiêu chính**: 
- Thêm/bỏ phương pháp chỉ cần thêm/xóa file, không sửa code core
- Mỗi phương pháp tự quyết định cách quản lý position (DCA/BE/Trail strategy)

---

## 🏛️ Kiến Trúc Mới (6 Layers)

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 0: RISK GATE (risk_gate.mqh)                        │
│  ├─ CanTrade() → true/false                                │
│  ├─ GetMaxRiskPips() → số pip tối đa                       │
│  ├─ GetMaxLotSize() → lot size tối đa                      │
│  └─ CheckDailyMDD() → có bị halt không                    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (nếu CanTrade() = true)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: DETECTION (modular - chia theo Phương pháp)      │
│  ├─ Methods/                                                │
│  │  ├─ method_smc.mqh      → SMC Method (BOS+OB+FVG+Sweep) │
│  │  ├─ method_ict.mqh      → ICT Method (FVG+OB+Momentum)  │
│  │  └─ method_custom.mqh   → Custom Method (dễ thêm)       │
│  │                                                           │
│  └─ Detectors/ (sub-detectors cho mỗi method)               │
│     ├─ detector_bos.mqh      → BOS detector                  │
│     ├─ detector_sweep.mqh    → Sweep detector                │
│     ├─ detector_ob.mqh       → OB detector                   │
│     ├─ detector_fvg.mqh      → FVG detector                  │
│     └─ detector_momentum.mqh → Momentum detector              │
│                                                             │
│  Mỗi Method Output:                                         │
│  ├─ SignalInfo: entry, sl, tp, score                        │
│  ├─ PositionPlan: DCA plan, BE plan, Trail plan            │
│  └─ Method-specific strategy                                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (tất cả signals)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2: ARBITRATION (arbiter.mqh)                        │
│  ├─ CollectSignals() → array of SignalInfo                 │
│  ├─ RankSignals() → sắp xếp theo score                     │
│  ├─ SelectBest() → chọn signal tốt nhất                    │
│  ├─ DetermineEntryMethod() → LIMIT/STOP/MARKET             │
│  └─ FormatExecution() → ExecutionOrder struct              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (ExecutionOrder)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: EXECUTION (executor.mqh)                          │
│  ├─ ValidateOrder() → check lại lần cuối                    │
│  ├─ PlaceOrder() → đặt lệnh                                │
│  ├─ TrackOrder() → theo dõi pending                         │
│  ├─ ManagePositions() → BE, Trail, DCA                     │
│  └─ UpdateOrderStatus() → cập nhật trạng thái              │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (filled orders)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 4: RISK MANAGEMENT (risk_manager.mqh)                │
│  ├─ TrackPosition() → lưu thông tin                        │
│  ├─ ManageDCA() → thêm lệnh DCA                            │
│  ├─ ManageBE() → move SL về entry                          │
│  ├─ ManageTrailing() → trailing stop                       │
│  └─ CheckBasket() → basket TP/SL                           │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (all data)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 5: ANALYTICS (stats_manager.mqh + dashboard.mqh)     │
│  ├─ TrackTrade() → lưu trade vào stats                     │
│  ├─ UpdateDashboard() → hiển thị real-time                 │
│  └─ GenerateReport() → báo cáo                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Cấu Trúc File Mới

```
MQL5/
├─ Experts/
│  └─ V2-oat.mq5              [Main EA - OnTick orchestrator]
│
└─ Include/
   ├─ Core/
   │  ├─ risk_gate.mqh         [NEW - Risk check đầu tiên] ⭐
   │  ├─ arbiter.mqh           [Arbitration - chọn signal tốt nhất]
   │  ├─ executor.mqh          [Execution - đặt lệnh]
   │  ├─ risk_manager.mqh      [Risk - DCA, BE, Trail]
   │  ├─ stats_manager.mqh    [Statistics]
   │  └─ dashboard.mqh         [Dashboard visualization]
   │
   ├─ Methods/                 [NEW - Phương pháp trading] ⭐
   │  ├─ method_base.mqh       [Base class cho methods]
   │  ├─ method_smc.mqh        [SMC Method - BOS+OB+FVG+Sweep]
   │  ├─ method_ict.mqh        [ICT Method - FVG+OB+Momentum]
   │  └─ method_custom.mqh     [Template cho method mới]
   │
   ├─ Detectors/               [Sub-detectors cho methods] ⭐
   │  ├─ detector_base.mqh     [Base class cho detectors]
   │  ├─ detector_bos.mqh      [BOS detector]
   │  ├─ detector_sweep.mqh    [Sweep detector]
   │  ├─ detector_ob.mqh       [Order Block detector]
   │  ├─ detector_fvg.mqh      [FVG detector]
   │  └─ detector_momentum.mqh [Momentum detector]
   │
   └─ Common/
      ├─ signal_structs.mqh    [Tất cả structs chung]
      └─ utils.mqh             [Helper functions]
```

---

## 🔄 Luồng Hoạt Động Mới

### OnTick() Flow

```cpp
void OnTick() {
    // ═══════════════════════════════════════════════════════
    // STEP 0: UPDATE DASHBOARD (mỗi tick)
    // ═══════════════════════════════════════════════════════
    UpdateDashboard();
    
    // ═══════════════════════════════════════════════════════
    // STEP 1: RISK GATE - Check đầu tiên ⭐
    // ═══════════════════════════════════════════════════════
    RiskGateResult riskGate = g_riskGate.Check();
    
    if(!riskGate.canTrade) {
        // Chỉ manage positions, không scan signals
        g_executor.ManagePositions();
        return;
    }
    
    // ═══════════════════════════════════════════════════════
    // STEP 2: DETECTION - Scan tất cả methods (SMC, ICT, etc.)
    // ═══════════════════════════════════════════════════════
    MethodSignal signals[];
    ArrayResize(signals, 0);
    
    // Scan từng phương pháp độc lập
    if(g_methodSMC != NULL) {
        MethodSignal sig = g_methodSMC.Scan(riskGate);
        if(sig.valid) ArrayAdd(signals, sig);
    }
    
    if(g_methodICT != NULL) {
        MethodSignal sig = g_methodICT.Scan(riskGate);
        if(sig.valid) ArrayAdd(signals, sig);
    }
    
    // Có thể thêm methods khác: g_methodCustom, etc.
    
    // ═══════════════════════════════════════════════════════
    // STEP 3: ARBITRATION - Chọn signal tốt nhất
    // ═══════════════════════════════════════════════════════
    if(ArraySize(signals) > 0) {
        MethodSignal bestSignal = g_arbiter.SelectBest(signals);
        
        if(bestSignal.valid && bestSignal.score >= 100) {
            // ═══════════════════════════════════════════════
            // STEP 4: Format execution order (bao gồm PositionPlan)
            // ═══════════════════════════════════════════════
            ExecutionOrder order = g_arbiter.FormatExecution(bestSignal, riskGate);
            
            // ═══════════════════════════════════════════════
            // STEP 5: EXECUTION - Đặt lệnh + Lưu PositionPlan
            // ═══════════════════════════════════════════════
            if(g_executor.PlaceOrder(order)) {
                // Lưu PositionPlan để quản lý sau này
                g_executor.SavePositionPlan(order.ticket, bestSignal.positionPlan);
                Print("✅ Order placed: ", bestSignal.methodName, " | Score: ", bestSignal.score);
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════
    // STEP 6: Manage existing positions
    // ═══════════════════════════════════════════════════════
    g_executor.ManagePositions();
    g_riskMgr.ManageOpenPositions();
}
```

---

## 📋 Chi Tiết Từng Layer

### LAYER 0: RISK GATE (`risk_gate.mqh`)

**Mục đích**: Check đầu tiên, quyết định có được trade không và trade bao nhiêu.

```cpp
struct RiskGateResult {
    bool     canTrade;          // Có được trade không?
    double   maxRiskPips;       // Số pip tối đa (từ risk %)
    double   maxLotSize;         // Lot size tối đa
    bool     tradingHalted;      // Bị halt (MDD)?
    string   reason;             // Lý do nếu canTrade = false
};

class CRiskGate {
public:
    RiskGateResult Check() {
        RiskGateResult result;
        result.canTrade = false;
        
        // Check 1: Daily MDD
        if(IsTradingHalted()) {
            result.reason = "Daily MDD limit reached";
            return result;
        }
        
        // Check 2: Session
        if(!IsSessionOpen()) {
            result.reason = "Outside trading session";
            return result;
        }
        
        // Check 3: Spread
        if(!IsSpreadOK()) {
            result.reason = "Spread too wide";
            return result;
        }
        
        // Check 4: Rollover
        if(IsRolloverTime()) {
            result.reason = "Rollover time";
            return result;
        }
        
        // Calculate max risk
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double riskAmount = balance * (m_riskPct / 100.0);
        double atr = GetATR();
        
        // Max risk in pips (dựa vào ATR hoặc fixed)
        result.maxRiskPips = CalculateMaxRiskPips(riskAmount, atr);
        result.maxLotSize = CalculateMaxLotSize(riskAmount, result.maxRiskPips);
        result.canTrade = true;
        result.reason = "OK";
        
        return result;
    }
};
```

**Input từ Risk Gate xuống Detection**:
- `maxRiskPips` → Detector phải tính SL ≤ maxRiskPips
- `maxLotSize` → Detector phải tính lot ≤ maxLotSize
- `canTrade` → Chỉ scan nếu = true

---

### LAYER 1: DETECTION (Modular - Chia theo Phương pháp)

**Position Plan Structure** (`signal_structs.mqh`):

```cpp
// Kế hoạch DCA
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
    ENTRY_TYPE dcaEntryType;     // LIMIT, STOP, MARKET
    string   dcaEntryReason;     // "At current price", "At pullback", etc.
};

// Kế hoạch Breakeven
struct BEPlan {
    bool     enabled;            // Có enable BE không?
    double   triggerR;           // Trigger tại +XR (ví dụ: 1.0R)
    bool     moveAllPositions;   // Move tất cả positions cùng side?
    string   reason;             // "Standard BE", "Aggressive BE", etc.
};

// Kế hoạch Trailing Stop
struct TrailPlan {
    bool     enabled;            // Có enable trailing không?
    double   startR;             // Bắt đầu tại +XR (ví dụ: 1.0R)
    double   stepR;              // Move mỗi +XR (ví dụ: 0.5R)
    double   distanceATR;        // Distance = X × ATR (ví dụ: 2.0)
    bool     lockProfit;         // Lock profit khi trail?
    string   strategy;           // "Conservative", "Aggressive", "Dynamic"
};

// Kế hoạch quản lý position hoàn chỉnh
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
```

**Method Signal Structure**:

```cpp
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
    ENTRY_TYPE   entryType;          // LIMIT, STOP, MARKET
    string       entryReason;        // "OB bottom", "FVG zone", etc.
    
    // ⭐ Kế hoạch quản lý position (tự tính trong method)
    PositionPlan positionPlan;       // DCA, BE, Trail plans
    
    // Signal details (method-specific)
    string       details;            // JSON string với thông tin chi tiết
};

class CMethodBase {
protected:
    string   m_methodName;           // "SMC", "ICT", etc.
    string   m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
    // Sub-detectors (cho method này)
    CDetectorBase* m_detectors[];
    
public:
    virtual MethodSignal Scan(const RiskGateResult &riskGate) = 0;
    virtual bool CalculateEntry(MethodSignal &signal, const RiskGateResult &riskGate) = 0;
    virtual PositionPlan CreatePositionPlan(const MethodSignal &signal) = 0;
    virtual double Score(const MethodSignal &signal) = 0;
};
```

**Ví dụ: SMC Method** (`method_smc.mqh`):

```cpp
#include "method_base.mqh"
#include "detector_bos.mqh"
#include "detector_sweep.mqh"
#include "detector_ob.mqh"
#include "detector_fvg.mqh"

class CSMCMethod : public CMethodBase {
private:
    // SMC-specific detectors
    CBOSDetector*    m_detectorBOS;
    CSweepDetector*  m_detectorSweep;
    COBDetector*     m_detectorOB;
    CFVGDetector*    m_detectorFVG;
    
public:
    bool Init(...) { 
        m_methodName = "SMC";
        // Initialize sub-detectors
        m_detectorBOS = new CBOSDetector();
        m_detectorSweep = new CSweepDetector();
        m_detectorOB = new COBDetector();
        m_detectorFVG = new CFVGDetector();
        // ... init params ...
    }
    
    MethodSignal Scan(const RiskGateResult &riskGate) override {
        MethodSignal signal;
        signal.valid = false;
        signal.methodName = "SMC";
        
        // ═══════════════════════════════════════════════════
        // STEP 1: Detect signals (SMC requires BOS + POI)
        // ═══════════════════════════════════════════════════
        BOSSignal bos = m_detectorBOS->Detect();
        if(!bos.valid) return signal;
        
        SweepSignal sweep = m_detectorSweep->Detect();
        OrderBlock ob = m_detectorOB->Find(bos.direction);
        FVGSignal fvg = m_detectorFVG->Find(bos.direction);
        
        // SMC requires: BOS + (OB or FVG)
        if(!ob.valid && !fvg.valid) return signal;
        
        signal.direction = bos.direction;
        
        // ═══════════════════════════════════════════════════
        // STEP 2: Calculate Entry/SL/TP
        // ═══════════════════════════════════════════════════
        if(ob.valid) {
            CalculateEntryFromOB(signal, ob, riskGate);
        } else if(fvg.valid) {
            CalculateEntryFromFVG(signal, fvg, riskGate);
        }
        
        // ═══════════════════════════════════════════════════
        // STEP 3: Create Position Plan (SMC-specific strategy)
        // ═══════════════════════════════════════════════════
        signal.positionPlan = CreatePositionPlan(signal);
        
        // ═══════════════════════════════════════════════════
        // STEP 4: Score signal
        // ═══════════════════════════════════════════════════
        signal.score = Score(signal);
        
        // Validate
        if(signal.score >= 100 && signal.rr >= 2.0) {
            signal.valid = true;
        }
        
        return signal;
    }
    
    PositionPlan CreatePositionPlan(const MethodSignal &signal) override {
        PositionPlan plan;
        plan.methodName = "SMC";
        plan.strategy = "Balanced";
        
        // ═══════════════════════════════════════════════════
        // SMC DCA Plan: Conservative (2 levels)
        // ═══════════════════════════════════════════════════
        plan.dcaPlan.enabled = true;
        plan.dcaPlan.maxLevels = 2;
        
        plan.dcaPlan.level1_triggerR = 0.75;      // DCA #1 tại +0.75R
        plan.dcaPlan.level1_lotMultiplier = 0.5;  // 50% original lot
        
        plan.dcaPlan.level2_triggerR = 1.5;       // DCA #2 tại +1.5R
        plan.dcaPlan.level2_lotMultiplier = 0.33; // 33% original lot
        
        plan.dcaPlan.dcaEntryType = ENTRY_MARKET; // DCA tại market price
        plan.dcaPlan.dcaEntryReason = "At current price when trigger";
        
        // ═══════════════════════════════════════════════════
        // SMC BE Plan: Standard
        // ═══════════════════════════════════════════════════
        plan.bePlan.enabled = true;
        plan.bePlan.triggerR = 1.0;               // BE tại +1R
        plan.bePlan.moveAllPositions = true;      // Move tất cả positions
        plan.bePlan.reason = "Standard SMC BE";
        
        // ═══════════════════════════════════════════════════
        // SMC Trail Plan: ATR-based
        // ═══════════════════════════════════════════════════
        plan.trailPlan.enabled = true;
        plan.trailPlan.startR = 1.0;               // Start tại +1R
        plan.trailPlan.stepR = 0.5;                // Move mỗi +0.5R
        plan.trailPlan.distanceATR = 2.0;          // Distance = 2×ATR
        plan.trailPlan.lockProfit = true;          // Lock profit
        plan.trailPlan.strategy = "ATR-based Conservative";
        
        plan.syncSL = true;                        // Sync SL cho tất cả
        plan.basketTP = false;                     // Không dùng basket TP
        plan.basketSL = false;                     // Không dùng basket SL
        
        return plan;
    }
    
    double Score(const MethodSignal &signal) override {
        double score = 0;
        
        // Base score
        score += 100; // BOS detected
        
        // Bonus
        if(hasSweep) score += 25;
        if(hasRetest) score += 20;
        if(mtfAligned) score += 25;
        if(obHasSweep) score += 20;
        if(fvgMTFOverlap) score += 25;
        
        // Penalties
        if(obTouches >= 2) score -= 20;
        if(fvgState == 1) score -= 15;
        
        return score;
    }
};
```

**Ví dụ: ICT Method** (`method_ict.mqh`):

```cpp
class CICTMethod : public CMethodBase {
    // ICT có thể có DCA/BE/Trail strategy khác với SMC
    PositionPlan CreatePositionPlan(const MethodSignal &signal) override {
        PositionPlan plan;
        plan.methodName = "ICT";
        plan.strategy = "Aggressive";
        
        // ═══════════════════════════════════════════════════
        // ICT DCA Plan: Aggressive (3 levels)
        // ═══════════════════════════════════════════════════
        plan.dcaPlan.enabled = true;
        plan.dcaPlan.maxLevels = 3;  // ICT dùng 3 levels
        
        plan.dcaPlan.level1_triggerR = 0.5;       // Sớm hơn SMC
        plan.dcaPlan.level1_lotMultiplier = 0.6;
        
        plan.dcaPlan.level2_triggerR = 1.0;
        plan.dcaPlan.level2_lotMultiplier = 0.4;
        
        plan.dcaPlan.level3_triggerR = 1.5;       // Level 3
        plan.dcaPlan.level3_lotMultiplier = 0.3;
        
        // ═══════════════════════════════════════════════════
        // ICT BE Plan: Aggressive (sớm hơn)
        // ═══════════════════════════════════════════════════
        plan.bePlan.enabled = true;
        plan.bePlan.triggerR = 0.75;              // BE sớm hơn (0.75R)
        plan.bePlan.reason = "Aggressive ICT BE";
        
        // ═══════════════════════════════════════════════════
        // ICT Trail Plan: Tighter (lock profit sớm)
        // ═══════════════════════════════════════════════════
        plan.trailPlan.enabled = true;
        plan.trailPlan.startR = 0.75;             // Start sớm hơn
        plan.trailPlan.stepR = 0.3;                // Step nhỏ hơn
        plan.trailPlan.distanceATR = 1.5;          // Distance chặt hơn
        plan.trailPlan.strategy = "Tight Aggressive";
        
        return plan;
    }
};
```

**Lợi ích**:
- ✅ Mỗi detector độc lập, tự tính entry/sl/tp
- ✅ Dễ thêm detector mới: copy `detector_custom.mqh`, implement methods
- ✅ Dễ bỏ detector: comment out trong OnInit()
- ✅ Không cần sửa code core khi thêm/bỏ method

---

### LAYER 2: ARBITRATION (`arbiter.mqh`)

**Mục đích**: Nhận tất cả signals, chọn signal tốt nhất, format xuống EXECUTION.

```cpp
class CArbiter {
public:
    // Chọn signal tốt nhất từ array
    SignalInfo SelectBest(SignalInfo &signals[]) {
        if(ArraySize(signals) == 0) {
            SignalInfo empty;
            empty.valid = false;
            return empty;
        }
        
        // Sort by score (descending)
        ArraySort(signals, WHOLE_ARRAY, 0, MODE_DESCEND);
        
        // Return highest score
        return signals[0];
    }
    
    // Format execution order
    ExecutionOrder FormatExecution(const SignalInfo &signal, 
                                   const RiskGateResult &riskGate) {
        ExecutionOrder order;
        
        order.direction = signal.direction;
        order.entryPrice = signal.entryPrice;
        order.slPrice = signal.slPrice;
        order.tpPrice = signal.tpPrice;
        order.entryType = signal.entryType;
        
        // Calculate lot size (từ riskGate)
        double slPips = MathAbs(signal.entryPrice - signal.slPrice) / _Point / 10;
        double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (m_riskPct / 100.0);
        order.lots = CalculateLotSize(riskAmount, slPips);
        
        // Cap to maxLotSize
        if(order.lots > riskGate.maxLotSize) {
            order.lots = riskGate.maxLotSize;
        }
        
        order.comment = StringFormat("%s_%s_RR%.1f", 
                                    signal.methodName,
                                    (signal.direction == 1) ? "BUY" : "SELL",
                                    signal.rr);
        
        return order;
    }
};
```

---

### LAYER 3: EXECUTION (`executor.mqh`)

**Mục đích**: Thực hiện lệnh, theo dõi, quản lý positions theo PositionPlan.

```cpp
struct ExecutionOrder {
    int         direction;      // 1=BUY, -1=SELL
    double      entryPrice;
    double      slPrice;
    double      tpPrice;
    double      lots;
    ENTRY_TYPE  entryType;      // LIMIT, STOP, MARKET
    string      comment;
    PositionPlan positionPlan;  // ⭐ Kế hoạch quản lý position
    ulong       ticket;          // Ticket sau khi place order
};

class CExecutor {
private:
    // Map ticket → PositionPlan
    PositionPlan m_positionPlans[];
    ulong        m_ticketMap[];
    
public:
    bool PlaceOrder(const ExecutionOrder &order) {
        // Validate lần cuối
        if(!ValidateOrder(order)) return false;
        
        // Place based on entry type
        bool success = false;
        if(order.entryType == ENTRY_LIMIT) {
            success = PlaceLimitOrder(order);
        } else if(order.entryType == ENTRY_STOP) {
            success = PlaceStopOrder(order);
        } else {
            success = PlaceMarketOrder(order);
        }
        
        if(success) {
            // ⭐ Lưu PositionPlan cho ticket này
            SavePositionPlan(order.ticket, order.positionPlan);
        }
        
        return success;
    }
    
    void SavePositionPlan(ulong ticket, const PositionPlan &plan) {
        // Lưu plan để quản lý sau này
        int idx = ArraySize(m_ticketMap);
        ArrayResize(m_ticketMap, idx + 1);
        ArrayResize(m_positionPlans, idx + 1);
        
        m_ticketMap[idx] = ticket;
        m_positionPlans[idx] = plan;
    }
    
    PositionPlan GetPositionPlan(ulong ticket) {
        // Lấy plan cho ticket
        for(int i = 0; i < ArraySize(m_ticketMap); i++) {
            if(m_ticketMap[i] == ticket) {
                return m_positionPlans[i];
            }
        }
        
        // Return default plan nếu không tìm thấy
        PositionPlan defaultPlan;
        defaultPlan.dcaPlan.enabled = false;
        defaultPlan.bePlan.enabled = false;
        defaultPlan.trailPlan.enabled = false;
        return defaultPlan;
    }
    
    void ManagePositions() {
        // ⭐ Quản lý theo PositionPlan của từng position
        for(int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            
            PositionPlan plan = GetPositionPlan(ticket);
            
            // Execute plan: DCA, BE, Trail
            ExecutePositionPlan(ticket, plan);
        }
    }
    
    void ExecutePositionPlan(ulong ticket, const PositionPlan &plan) {
        // ═══════════════════════════════════════════════════
        // Execute DCA Plan
        // ═══════════════════════════════════════════════════
        if(plan.dcaPlan.enabled) {
            ExecuteDCAPlan(ticket, plan.dcaPlan);
        }
        
        // ═══════════════════════════════════════════════════
        // Execute BE Plan
        // ═══════════════════════════════════════════════════
        if(plan.bePlan.enabled) {
            ExecuteBEPlan(ticket, plan.bePlan);
        }
        
        // ═══════════════════════════════════════════════════
        // Execute Trail Plan
        // ═══════════════════════════════════════════════════
        if(plan.trailPlan.enabled) {
            ExecuteTrailPlan(ticket, plan.trailPlan);
        }
    }
    
    void ExecuteDCAPlan(ulong ticket, const DCAPlan &plan) {
        // Check profit in R
        double profitR = g_riskMgr.CalcProfitInR(ticket);
        
        // Check DCA Level 1
        if(plan.maxLevels >= 1 && profitR >= plan.level1_triggerR) {
            if(!IsDCAAdded(ticket, 1)) {
                double originalLot = GetOriginalLot(ticket);
                double dcaLot = originalLot * plan.level1_lotMultiplier;
                AddDCAPosition(ticket, dcaLot, plan.dcaEntryType);
                MarkDCAAdded(ticket, 1);
            }
        }
        
        // Check DCA Level 2
        if(plan.maxLevels >= 2 && profitR >= plan.level2_triggerR) {
            if(!IsDCAAdded(ticket, 2)) {
                double originalLot = GetOriginalLot(ticket);
                double dcaLot = originalLot * plan.level2_lotMultiplier;
                AddDCAPosition(ticket, dcaLot, plan.dcaEntryType);
                MarkDCAAdded(ticket, 2);
            }
        }
        
        // Check DCA Level 3 (nếu có)
        if(plan.maxLevels >= 3 && profitR >= plan.level3_triggerR) {
            if(!IsDCAAdded(ticket, 3)) {
                double originalLot = GetOriginalLot(ticket);
                double dcaLot = originalLot * plan.level3_lotMultiplier;
                AddDCAPosition(ticket, dcaLot, plan.dcaEntryType);
                MarkDCAAdded(ticket, 3);
            }
        }
    }
    
    void ExecuteBEPlan(ulong ticket, const BEPlan &plan) {
        double profitR = g_riskMgr.CalcProfitInR(ticket);
        
        if(profitR >= plan.triggerR && !IsBEMoved(ticket)) {
            if(plan.moveAllPositions) {
                // Move tất cả positions cùng side
                int direction = GetPositionDirection(ticket);
                g_riskMgr.MoveAllSLToBE(direction);
            } else {
                // Chỉ move position này
                g_riskMgr.MoveSLToBE(ticket);
            }
            MarkBEMoved(ticket);
        }
    }
    
    void ExecuteTrailPlan(ulong ticket, const TrailPlan &plan) {
        double profitR = g_riskMgr.CalcProfitInR(ticket);
        
        if(profitR >= plan.startR) {
            // Check if need to trail (step check)
            double lastTrailR = GetLastTrailR(ticket);
            if(profitR >= lastTrailR + plan.stepR) {
                // Calculate new SL based on ATR distance
                double atr = g_riskMgr.GetATR();
                double distance = plan.distanceATR * atr;
                g_riskMgr.TrailSL(ticket, distance);
                SetLastTrailR(ticket, profitR);
            }
        }
    }
};
```

---

## 🎯 So Sánh: Cũ vs Mới

| Aspect | Cấu Trúc Cũ | Cấu Trúc Mới |
|--------|-------------|--------------|
| **Risk Check** | Sau khi có candidate | **Đầu tiên** (Risk Gate) |
| **Detection** | 1 file lớn (`detectors.mqh`) | **Modular** (mỗi method 1 file) |
| **Entry/SL/TP** | Tính trong Executor | **Tính trong Method** |
| **DCA/BE/Trail** | Fixed trong RiskManager | **Tính trong Method (PositionPlan)** |
| **Scoring** | Trong Arbiter | **Trong Method** |
| **Thêm Method** | Sửa `detectors.mqh` | **Thêm file method mới** |
| **Bỏ Method** | Comment code | **Comment include** |
| **Strategy** | One-size-fits-all | **Method-specific (SMC vs ICT)** |
| **Dependency** | Tight coupling | **Loose coupling** |

---

## ✅ Lợi Ích Thiết Kế Mới

1. **Mở Rộng Dễ Dàng**:
   - Thêm method: Copy `detector_custom.mqh`, implement methods
   - Bỏ method: Comment `#include` trong main file
   - Không cần sửa code core

2. **Risk Management Đầu Tiên**:
   - Check trước khi scan signals → tiết kiệm CPU
   - Risk Gate quyết định max risk → detectors tự điều chỉnh

3. **Modular & Testable**:
   - Mỗi detector test độc lập
   - Dễ debug từng method
   - Dễ optimize từng method riêng

4. **Separation of Concerns**:
   - Detection: Tìm signals, tính entry/sl/tp, **lập PositionPlan**, chấm điểm
   - Arbitration: Chọn signal tốt nhất
   - Execution: Đặt lệnh, **thực thi PositionPlan**
   - Risk: Hỗ trợ Execution (lot sizing, MDD check)

5. **Method-Specific Strategy**:
   - SMC method: Conservative DCA (2 levels), Standard BE/Trail
   - ICT method: Aggressive DCA (3 levels), Early BE/Trail
   - Mỗi method tự quyết định cách quản lý position

---

## 🚀 Migration Plan

### Phase 1: Tạo Base Structure
1. Tạo `risk_gate.mqh`
2. Tạo `detector_base.mqh`
3. Tạo `signal_structs.mqh`

### Phase 2: Create Methods
1. Tạo `method_smc.mqh` → SMC method với PositionPlan
2. Tạo `method_ict.mqh` → ICT method với PositionPlan
3. Tạo sub-detectors: `detector_bos.mqh`, `detector_sweep.mqh`, etc.

### Phase 3: Update Core
1. Update `arbiter.mqh` → nhận MethodSignal[] (có PositionPlan)
2. Update `executor.mqh` → nhận ExecutionOrder + PositionPlan, thực thi plan
3. Update `risk_manager.mqh` → hỗ trợ ExecutePositionPlan()
4. Update `V2-oat.mq5` → OnTick() mới

### Phase 4: Testing
1. Test từng detector độc lập
2. Test integration
3. Backtest so sánh với version cũ

---

## ❓ Questions for Discussion

1. **Risk Gate**: Có cần thêm checks nào khác không? (News filter, volatility regime, etc.)

2. **Position Plan**: Mỗi method tự tạo plan hay có template chung?

3. **DCA Strategy**: SMC vs ICT có khác nhau nhiều không? Có cần thêm methods khác?

4. **Plan Execution**: Execution layer thực thi plan hay RiskManager thực thi?

5. **Multiple Signals**: Cho phép nhiều signals cùng lúc hay chỉ 1 signal tốt nhất?

5. **Backward Compatibility**: Có cần giữ code cũ để rollback không?

---

## 📝 Next Steps

1. **Review thiết kế** - Discuss với user
2. **Confirm structure** - Finalize file structure
3. **Start implementation** - Phase 1 → Phase 4
4. **Testing** - Verify hoạt động đúng
5. **Documentation** - Update docs

---

**Ngày tạo**: 2025-01-XX  
**Version**: 1.0  
**Status**: Proposal - Awaiting Review

