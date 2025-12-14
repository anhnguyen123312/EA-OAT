# 00. Layer 0: Risk Gate - Kiểm Tra Rủi Ro Đầu Tiên

## 📍 Tổng Quan

**Layer 0: Risk Gate** là lớp kiểm tra **đầu tiên** trong kiến trúc 6 layers của bot EA. Layer này quyết định **có được phép trade hay không** và tính toán **giới hạn rủi ro** trước khi các layer khác (Detection, Arbitration, Execution) hoạt động.

**Mục đích chính:**
- ✅ Bảo vệ vốn bằng cách kiểm tra các điều kiện rủi ro trước khi trade
- ✅ Tính toán giới hạn lot size và risk pips dựa trên balance/equity
- ✅ Kiểm tra session, spread, rollover time

**Vị trí trong kiến trúc:**
```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 0: RISK GATE (risk_gate.mqh)                        │
│  ├─ CanTrade() → true/false                                │
│  ├─ GetMaxRiskPips() → số pip tối đa                       │
│  └─ GetMaxLotSize() → lot size tối đa + remaining lots    │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (nếu CanTrade() = true)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: DETECTION (modular - chia theo Phương pháp)      │
│  ...                                                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 1. Chức Năng Chính

### 1.1. RiskGateResult Structure

**File**: `Include/Common/signal_structs.mqh`

```cpp
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
    double   remainingRiskPips; // Số pip còn lại = maxRiskPips - filledRiskPips - pendingRiskPips
    double   remainingLotSize;  // Số lot còn lại = maxLotSize - filledLotSize - pendingLotSize
};
```

**Giải thích:**
- `canTrade`: `true` nếu tất cả điều kiện OK, `false` nếu có bất kỳ điều kiện nào fail
- `maxRiskPips`: Số pip tối đa có thể risk (tính từ risk% và balance)
- `maxLotSize`: Lot size tối đa (dynamic theo equity hoặc fixed)
- `reason`: Lý do cụ thể nếu `canTrade = false` (ví dụ: "Daily MDD limit reached", "Outside trading session", "Spread too wide")
- **`filledRiskPips`**: Tổng số pip đã risk trong các positions đã filled
- **`filledLotSize`**: Tổng số lot đã vào lệnh (filled positions)
- **`pendingRiskPips`**: Tổng số pip đang risk trong các pending orders
- **`pendingLotSize`**: Tổng số lot đang trong pending orders
- **`remainingRiskPips`**: Số pip còn lại có thể risk = `maxRiskPips - filledRiskPips - pendingRiskPips`
- **`remainingLotSize`**: Số lot còn lại = `maxLotSize - filledLotSize - pendingLotSize`

**Lưu ý:** Methods nên sử dụng `remainingRiskPips` và `remainingLotSize` thay vì `maxRiskPips` và `maxLotSize` để đảm bảo không vượt quá giới hạn khi đã có positions/orders.

---

### 1.2. Main Check Function

**File**: `Include/Core/risk_gate.mqh`

```cpp
RiskGateResult CRiskGate::Check() {
    RiskGateResult result;
    result.canTrade = false;
    result.maxRiskPips = 0;
    result.maxLotSize = 0;
    result.tradingHalted = false;
    result.reason = "";
    
    // ═══════════════════════════════════════════════════════════
    // Check 1: Daily MDD
    // ═══════════════════════════════════════════════════════════
    if(m_useDailyMDD) {
        CheckDailyMDD();
        if(IsTradingHalted()) {
            result.tradingHalted = true;
            result.reason = "Daily MDD limit reached";
            return result;
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // Check 2: Session
    // ═══════════════════════════════════════════════════════════
    if(!IsSessionOpen()) {
        result.reason = "Outside trading session";
        return result;
    }
    
    // ═══════════════════════════════════════════════════════════
    // Check 3: Spread
    // ═══════════════════════════════════════════════════════════
    if(!IsSpreadOK()) {
        result.reason = "Spread too wide";
        return result;
    }
    
    // ═══════════════════════════════════════════════════════════
    // Check 4: Rollover
    // ═══════════════════════════════════════════════════════════
    if(IsRolloverTime()) {
        result.reason = "Rollover time";
        return result;
    }
    
    // ═══════════════════════════════════════════════════════════
    // Calculate max risk
    // ═══════════════════════════════════════════════════════════
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (m_riskPct / 100.0);
    double atr = GetATR();
    
    // Max risk in pips (dựa vào ATR hoặc fixed)
    result.maxRiskPips = CalculateMaxRiskPips(riskAmount, atr);
    result.maxLotSize = CalculateMaxLotSize(riskAmount, result.maxRiskPips);
    
    // Cap to max lot
    if(result.maxLotSize > m_lotMax) {
        result.maxLotSize = m_lotMax;
    }
    
    result.canTrade = true;
    result.reason = "OK";
    
    return result;
}
```

**Quy trình kiểm tra:**
1. **Daily MDD** → Nếu vượt limit → HALT, return ngay
2. **Session** → Nếu ngoài giờ → BLOCK, return ngay
3. **Spread** → Nếu quá rộng → BLOCK, return ngay
4. **Rollover** → Nếu trong thời gian rollover → BLOCK, return ngay
5. **Tính toán** → Nếu tất cả OK → Tính `maxRiskPips` và `maxLotSize`, return `canTrade = true`

---

## 🎯 2. Các Tính Năng Chi Tiết

---

### 2.2. Session Check (Kiểm Tra Thời Gian Giao Dịch)

#### Mô Tả
Kiểm tra xem có đang trong giờ trading session hay không. Hỗ trợ **timezone conversion tự động** (GMT+7) và **2 chế độ session** với khả năng **bật/tắt linh hoạt** từng khung giờ.

#### Cấu Hình
```cpp
// Session parameters
bool     m_sessionOpen;      // Enable session filter?
int      m_sessStartHour;    // Start hour (GMT+7)
int      m_sessEndHour;      // End hour (GMT+7)

// Multi-Window mode
TRADING_SESSION_MODE m_sessionMode;  // FULL_DAY hoặc MULTI_WINDOW
TradingWindow m_windows[3];         // 3 windows với enable/disable riêng
```

#### Timezone Conversion (GMT+7)

**Cơ chế tự động convert** broker time sang **GMT+7** (Vietnam Time):

```cpp
int CRiskGate::GetLocalHour() {
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    
    // ═══════════════════════════════════════════════════════════
    // TIMEZONE CONVERSION: Server Time → GMT+7 (VN Time)
    // ═══════════════════════════════════════════════════════════
    int server_gmt = (int)(TimeGMTOffset() / 3600);  // Broker GMT offset
    int vn_gmt = 7;                                   // Target: GMT+7
    int delta = vn_gmt - server_gmt;                 // Chênh lệch
    
    // Convert: Server Hour → VN Hour
    int hour_localvn = (dt.hour + delta + 24) % 24;
    
    return hour_localvn;
}
```

**Công thức:**
```
VN_Hour = (Server_Hour + Delta + 24) % 24

Trong đó:
  Delta = VN_GMT - Server_GMT
  VN_GMT = 7 (cố định)
  Server_GMT = TimeGMTOffset() / 3600
```

**Ví dụ Conversion:**

| Broker GMT | Server Time | Delta | VN Time (GMT+7) | Trong Session 7-23? |
|------------|-------------|-------|-----------------|---------------------|
| GMT+0      | 14:00       | +7    | 21:00           | ✅ YES             |
| GMT+0      | 17:00       | +7    | 00:00           | ❌ NO              |
| GMT+2      | 16:00       | +5    | 21:00           | ✅ YES             |
| GMT+2      | 19:00       | +5    | 00:00           | ❌ NO              |
| GMT+3      | 10:00       | +4    | 14:00           | ✅ YES             |
| GMT+3      | 20:00       | +4    | 00:00           | ❌ NO              |

**Chi tiết**: Xem [TIMEZONE_CONVERSION.md](TIMEZONE_CONVERSION.md)

#### Logic Kiểm Tra Session

```cpp
bool CRiskGate::IsSessionOpen() {
    // ═══════════════════════════════════════════════════════════
    // Nếu không enable session filter → luôn mở
    // ═══════════════════════════════════════════════════════════
    if(!m_sessionOpen) return true;
    
    // ═══════════════════════════════════════════════════════════
    // Convert timezone: Server Time → GMT+7
    // ═══════════════════════════════════════════════════════════
    int localHour = GetLocalHour();  // Đã convert sang GMT+7
    
    // ═══════════════════════════════════════════════════════════
    // MODE 1: FULL DAY (Simple - 1 khung giờ liên tục)
    // ═══════════════════════════════════════════════════════════
    if(m_sessionMode == SESSION_FULL_DAY) {
        return (localHour >= m_sessStartHour && localHour < m_sessEndHour);
    }
    
    // ═══════════════════════════════════════════════════════════
    // MODE 2: MULTI-WINDOW (Flexible - nhiều khung giờ, On/Off riêng)
    // ═══════════════════════════════════════════════════════════
    else {
        // Check Window 1: Asia (7-11 GMT+7)
        if(m_windows[0].enabled &&
           localHour >= m_windows[0].startHour &&
           localHour < m_windows[0].endHour) {
            return true;
        }
        
        // Check Window 2: London (12-16 GMT+7)
        if(m_windows[1].enabled &&
           localHour >= m_windows[1].startHour &&
           localHour < m_windows[1].endHour) {
            return true;
        }
        
        // Check Window 3: NY (18-23 GMT+7)
        if(m_windows[2].enabled &&
           localHour >= m_windows[2].startHour &&
           localHour < m_windows[2].endHour) {
            return true;
        }
        
        return false;  // Không trong bất kỳ window nào
    }
}
```

#### Hai Chế Độ Session

**Mode 1: FULL DAY** (Simple - Trade liên tục)
```
07:00 ══════════════════════════════════════════ 23:00
      │──────────── 16 hours continuous ─────────│
      └─ Trade liên tục, không có break ─────────┘

Cấu hình:
  InpSessionMode = SESSION_FULL_DAY
  InpFullDayStart = 7   (07:00 GMT+7)
  InpFullDayEnd = 23    (23:00 GMT+7)
  
Ưu điểm:
  ✅ Đơn giản, không cần cấu hình nhiều
  ✅ Catch tất cả opportunities
  ✅ Phù hợp: Conservative traders, full automation
```

**Mode 2: MULTI-WINDOW** (Flexible - On/Off từng khung giờ)
```
07:00 ════ 11:00    12:00 ════ 16:00    18:00 ════════ 23:00
      │ Win1 │ BREAK │ Win2 │ BREAK │      Win3       │
      │ 4h   │  1h   │ 4h   │  2h   │       5h        │
      └──────┴───────┴──────┴───────┴─────────────────┘
      Total: 13 hours trading, 3 hours break

Cấu hình:
  InpSessionMode = SESSION_MULTI_WINDOW
  
  // Window 1: Asia
  InpWindow1_Enable = true   // ⭐ BẬT/TẮT linh hoạt
  InpWindow1_Start = 7       (07:00 GMT+7)
  InpWindow1_End = 11        (11:00 GMT+7)
  
  // Window 2: London
  InpWindow2_Enable = true   // ⭐ BẬT/TẮT linh hoạt
  InpWindow2_Start = 12       (12:00 GMT+7)
  InpWindow2_End = 16        (16:00 GMT+7)
  
  // Window 3: NY
  InpWindow3_Enable = true   // ⭐ BẬT/TẮT linh hoạt
  InpWindow3_Start = 18      (18:00 GMT+7)
  InpWindow3_End = 23        (23:00 GMT+7)

Ưu điểm:
  ✅ Focus vào high-liquidity sessions
  ✅ Tránh choppy periods (lunch, overlap gaps)
  ✅ Better win rate (trade quality > quantity)
  ✅ Linh hoạt: Bật/tắt từng window riêng biệt
  ✅ Phù hợp: Active traders, specific session preference
```

#### Ví Dụ Cấu Hình Linh Hoạt

**Scenario 1: Chỉ Trade London + NY (Bỏ Asia)**
```cpp
InpSessionMode = SESSION_MULTI_WINDOW

InpWindow1_Enable = false  // ❌ Tắt Asia
InpWindow2_Enable = true   // ✅ Bật London
InpWindow3_Enable = true   // ✅ Bật NY

→ Chỉ trade 12-16 và 18-23 GMT+7
```

**Scenario 2: Chỉ Trade NY Session**
```cpp
InpSessionMode = SESSION_MULTI_WINDOW

InpWindow1_Enable = false  // ❌ Tắt Asia
InpWindow2_Enable = false  // ❌ Tắt London
InpWindow3_Enable = true   // ✅ Chỉ bật NY

→ Chỉ trade 18-23 GMT+7
```

**Scenario 3: Trade Full Time (24/7)**
```cpp
InpSessionMode = SESSION_FULL_DAY
InpFullDayStart = 0
InpFullDayEnd = 24

→ Trade 24/7 (không khuyến nghị)
```

**Chi tiết**: Xem [TRADING_SCHEDULE.md](../business/TRADING_SCHEDULE.md) và [TIMEZONE_CONVERSION.md](TIMEZONE_CONVERSION.md)

---


### 2.5. Max Risk Pips Calculation (Tính Toán Số Pip Tối Đa)

#### Mô Tả
Tính toán số pip tối đa có thể risk dựa trên risk% và balance.

#### Logic Tính Toán
```cpp
double CRiskGate::CalculateMaxRiskPips(double riskAmount, double atr) {
    // Simple calculation: riskAmount / (lot size × pip value)
    // For XAUUSD: 1 lot = $10 per pip
    double pipValue = 10.0; // $10 per pip per lot for XAUUSD
    double maxLot = m_lotMax;
    
    // Max risk in pips = riskAmount / (maxLot × pipValue)
    double maxRiskPips = riskAmount / (maxLot * pipValue);
    
    // Cap based on ATR (reasonable SL)
    double maxSLPips = (atr * 3.5) / (SymbolInfoDouble(m_symbol, SYMBOL_POINT) * 10.0); // Convert to pips
    
    if(maxRiskPips > maxSLPips) {
        maxRiskPips = maxSLPips;
    }
    
    return maxRiskPips;
}
```

#### Công Thức
```
Risk Amount = Balance × (Risk% / 100)
Max Risk Pips = Risk Amount / (MaxLot × PipValue)

Cap: Max Risk Pips ≤ (ATR × 3.5) / Point × 10
```

#### Ví Dụ
```
Balance: $10,000
Risk: 0.5%
MaxLot: 3.0
ATR: 5.0 points (0.5 pips)

Risk Amount = $10,000 × 0.5% = $50
Max Risk Pips = $50 / (3.0 × $10) = 1.67 pips

Cap: (5.0 × 3.5) / (0.001 × 10) = 17.5 / 0.01 = 1750 pips
→ Max Risk Pips = min(1.67, 1750) = 1.67 pips
```

**Lưu ý**: Cap dựa trên ATR để đảm bảo SL hợp lý (không quá nhỏ).

---

### 2.6. Max Lot Size Calculation (Tính Toán Lot Size Tối Đa & Còn Lại)

#### Mô Tả
Tính toán **lot size tối đa** dựa trên equity (dynamic lot sizing) và **lot size còn lại** có thể sử dụng cho lệnh mới. Thông tin này được **liên kết với EXECUTION layer** để đảm bảo không vượt quá giới hạn.

#### Logic Tính Toán Max Lot Size

```cpp
double CRiskGate::CalculateMaxLotSize(double riskAmount, double maxRiskPips) {
    // Dynamic lot sizing based on equity
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double baseLot = m_lotBase;
    
    // Calculate increment based on equity
    int increments = (int)MathFloor(equity / m_equityPerLotInc);
    double dynamicLot = baseLot + (increments * m_lotIncrement);
    
    // Cap to max
    if(dynamicLot > m_lotMax) {
        dynamicLot = m_lotMax;
    }
    
    return dynamicLot;
}
```

#### Công Thức
```
MaxLotSize = LotBase + floor(Equity / EquityPerLotInc) × LotIncrement

Cap: MaxLotSize ≤ LotMax
```

#### Ví Dụ Tính Max Lot Size
```
LotBase: 0.1
EquityPerLotInc: $1,000
LotIncrement: 0.1
LotMax: 5.0

Equity $5,000:
  MaxLotSize = 0.1 + floor(5000/1000) × 0.1
             = 0.1 + 5 × 0.1
             = 0.6

Equity $10,000:
  MaxLotSize = 0.1 + floor(10000/1000) × 0.1
             = 0.1 + 10 × 0.1
             = 1.1

Equity $50,000:
  MaxLotSize = 0.1 + floor(50000/1000) × 0.1
             = 0.1 + 50 × 0.1
             = 5.1 → Capped to 5.0
```

#### Tính Toán Lot Size Còn Lại (Remaining Lots)

**Mục đích**: Tính số lot **còn lại** có thể sử dụng cho lệnh mới, sau khi trừ đi lot size **hiện có** của các positions cùng direction.

**Công thức:**
```
RemainingLotSize = MaxLotSize - CurrentSideLots

Trong đó:
  MaxLotSize = Lot size tối đa (từ Risk Gate)
  CurrentSideLots = Tổng lot size hiện có (cùng direction)
```

**Logic trong EXECUTION Layer:**

```cpp
// ═══════════════════════════════════════════════════════════
// LAYER 3: EXECUTION - Sử dụng thông tin từ Risk Gate
// ═══════════════════════════════════════════════════════════

// 1. Lấy MaxLotSize từ Risk Gate
RiskGateResult riskResult = g_riskGate.Check();
double maxLotSize = riskResult.maxLotSize;  // Ví dụ: 3.0 lots

// 2. Tính CurrentSideLots (từ Risk Manager hoặc tự tính)
double currentBuyLots = GetSideLots(1);     // Tổng BUY lots hiện có
double currentSellLots = GetSideLots(-1);   // Tổng SELL lots hiện có

// 3. Tính RemainingLotSize cho direction cụ thể
int direction = candidate.direction;  // 1=BUY, -1=SELL
double currentSideLots = (direction == 1) ? currentBuyLots : currentSellLots;
double remainingLotSize = maxLotSize - currentSideLots;

// 4. Áp dụng vào lot size của lệnh mới
double requestedLots = CalcLotsByRisk(riskPct, slPoints);
double finalLots = MathMin(requestedLots, remainingLotSize);  // ⭐ Không vượt quá còn lại

// 5. Place order với finalLots
PlaceOrder(direction, entry, sl, tp, finalLots, comment);
```

**Ví Dụ Chi Tiết:**

**Scenario 1: Chưa có positions**
```
MaxLotSize: 3.0 lots (từ Risk Gate)
CurrentBuyLots: 0.0 lots
CurrentSellLots: 0.0 lots

New BUY order:
  RemainingLotSize = 3.0 - 0.0 = 3.0 lots ✅
  RequestedLots = 0.5 lots (từ risk calculation)
  FinalLots = min(0.5, 3.0) = 0.5 lots ✅
  → Place order: 0.5 lots BUY
```

**Scenario 2: Đã có positions**
```
MaxLotSize: 3.0 lots (từ Risk Gate)
CurrentBuyLots: 1.5 lots (đã có 3 positions: 0.5 + 0.5 + 0.5)
CurrentSellLots: 0.8 lots (đã có 2 positions: 0.3 + 0.5)

New BUY order:
  RemainingLotSize = 3.0 - 1.5 = 1.5 lots ✅
  RequestedLots = 0.8 lots (từ risk calculation)
  FinalLots = min(0.8, 1.5) = 0.8 lots ✅
  → Place order: 0.8 lots BUY
  
  Sau khi place:
    CurrentBuyLots = 1.5 + 0.8 = 2.3 lots
    RemainingLotSize = 3.0 - 2.3 = 0.7 lots (cho lệnh tiếp theo)
```

**Scenario 3: Gần đạt limit**
```
MaxLotSize: 3.0 lots (từ Risk Gate)
CurrentBuyLots: 2.8 lots (đã có nhiều positions)
CurrentSellLots: 0.0 lots

New BUY order:
  RemainingLotSize = 3.0 - 2.8 = 0.2 lots ⚠️
  RequestedLots = 0.5 lots (từ risk calculation)
  FinalLots = min(0.5, 0.2) = 0.2 lots ⚠️
  → Place order: 0.2 lots BUY (giảm lot size để không vượt limit)
  
  Hoặc: Reject order nếu FinalLots < MinLot (0.01)
```

**Scenario 4: Đã đạt limit**
```
MaxLotSize: 3.0 lots (từ Risk Gate)
CurrentBuyLots: 3.0 lots (đã đạt limit)
CurrentSellLots: 0.0 lots

New BUY order:
  RemainingLotSize = 3.0 - 3.0 = 0.0 lots ❌
  → REJECT order (không còn lot size để trade)
  
  Log: "⚠️ Cannot place BUY order: MaxLotSize reached (3.0/3.0 lots)"
```

#### Liên Kết Với EXECUTION Layer

**Flow hoàn chỉnh:**

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 0: RISK GATE                                        │
│  ├─ GetMaxLotSize() → 3.0 lots                             │
│  └─ Return trong RiskGateResult.maxLotSize                │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: EXECUTION                                        │
│  ├─ Get RiskGateResult.maxLotSize → 3.0 lots               │
│  ├─ Get CurrentSideLots() → 1.5 lots (BUY)                 │
│  ├─ Calculate: RemainingLotSize = 3.0 - 1.5 = 1.5 lots    │
│  ├─ Calculate: RequestedLots = 0.8 lots (từ risk)          │
│  ├─ FinalLots = min(0.8, 1.5) = 0.8 lots                   │
│  └─ PlaceOrder(direction, entry, sl, tp, 0.8, comment)    │
└─────────────────────────────────────────────────────────────┘
```

**Code Integration:**

```cpp
// Trong EXECUTION Layer (executor.mqh)
bool CExecutor::PlaceOrder(const ExecutionOrder &order) {
    // ═══════════════════════════════════════════════════════════
    // 1. Lấy MaxLotSize từ Risk Gate (Layer 0)
    // ═══════════════════════════════════════════════════════════
    RiskGateResult riskResult = g_riskGate.Check();
    if(!riskResult.canTrade) {
        Print("❌ Cannot place order: ", riskResult.reason);
        return false;
    }
    
    double maxLotSize = riskResult.maxLotSize;  // Từ Risk Gate
    
    // ═══════════════════════════════════════════════════════════
    // 2. Tính CurrentSideLots (từ Risk Manager)
    // ═══════════════════════════════════════════════════════════
    double currentSideLots = g_riskMgr->GetSideLots(order.direction);
    
    // ═══════════════════════════════════════════════════════════
    // 3. Tính RemainingLotSize
    // ═══════════════════════════════════════════════════════════
    double remainingLotSize = maxLotSize - currentSideLots;
    
    if(remainingLotSize <= 0) {
        Print("⚠️ Cannot place order: MaxLotSize reached (", 
              DoubleToString(currentSideLots, 2), "/", 
              DoubleToString(maxLotSize, 2), " lots)");
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════
    // 4. Áp dụng RemainingLotSize vào order.lots
    // ═══════════════════════════════════════════════════════════
    double finalLots = MathMin(order.lots, remainingLotSize);
    
    // ═══════════════════════════════════════════════════════════
    // 5. Place order với finalLots
    // ═══════════════════════════════════════════════════════════
    Print("📊 Lot Size Check:");
    Print("   MaxLotSize: ", DoubleToString(maxLotSize, 2), " lots");
    Print("   CurrentSideLots: ", DoubleToString(currentSideLots, 2), " lots");
    Print("   RemainingLotSize: ", DoubleToString(remainingLotSize, 2), " lots");
    Print("   RequestedLots: ", DoubleToString(order.lots, 2), " lots");
    Print("   FinalLots: ", DoubleToString(finalLots, 2), " lots");
    
    // ... place order với finalLots ...
}
```

**Chi tiết**: Xem [RISK_MANAGEMENT_RULES.md](../business/RISK_MANAGEMENT_RULES.md) và [04_EXECUTOR.md](04_EXECUTOR.md)

---

## 🎯 3. Initialization (Khởi Tạo)

### 3.1. Constructor

```cpp
CRiskGate::CRiskGate() {
    m_atrHandle = INVALID_HANDLE;
    m_tradingHalted = false;
    m_startDayBalance = 0;
    m_lastDayCheck = 0;
}
```

### 3.2. Init Function

```cpp
bool CRiskGate::Init(string symbol, ENUM_TIMEFRAMES tf,
                     double riskPct, double dailyMddMax, bool useDailyMDD, 
                     bool useEquityMDD, int dailyResetHour,
                     bool sessionOpen, int sessStartHour, int sessEndHour,
                     int spreadMaxPts, double spreadATRpct,
                     double lotBase, double lotMax, double equityPerLotInc, double lotIncrement) {
    
    m_symbol = symbol;
    m_timeframe = tf;
    m_riskPct = riskPct;
    m_dailyMddMax = dailyMddMax;
    m_useDailyMDD = useDailyMDD;
    m_useEquityMDD = useEquityMDD;
    m_dailyResetHour = dailyResetHour;
    m_sessionOpen = sessionOpen;
    m_sessStartHour = sessStartHour;
    m_sessEndHour = sessEndHour;
    m_spreadMaxPts = spreadMaxPts;
    m_spreadATRpct = spreadATRpct;
    m_lotBase = lotBase;
    m_lotMax = lotMax;
    m_equityPerLotInc = equityPerLotInc;
    m_lotIncrement = lotIncrement;
    
    // Initialize ATR
    m_atrHandle = iATR(symbol, tf, 14);
    if(m_atrHandle == INVALID_HANDLE) {
        Print("❌ ERROR: Failed to create ATR indicator");
        return false;
    }
    
    // Initialize daily tracking
    ResetDailyTracking();
    
    Print("✅ Risk Gate initialized");
    return true;
}
```

**Parameters:**
- `symbol`: Symbol để trade (ví dụ: "XAUUSD")
- `tf`: Timeframe (ví dụ: PERIOD_M30)
- `riskPct`: Risk per trade (%) (ví dụ: 0.5)
- `dailyMddMax`: Daily MDD limit (%) (ví dụ: 8.0)
- `useDailyMDD`: Enable daily MDD check (ví dụ: true)
- `useEquityMDD`: Use equity thay vì balance (ví dụ: true)
- `dailyResetHour`: Hour để reset daily tracking (ví dụ: 6 = 6h GMT+7)
- `sessionOpen`: Enable session filter (ví dụ: true)
- `sessStartHour`: Session start hour (ví dụ: 7 = 7h GMT+7)
- `sessEndHour`: Session end hour (ví dụ: 23 = 23h GMT+7)
- `spreadMaxPts`: Max spread (points) (ví dụ: 500)
- `spreadATRpct`: Spread ATR% guard (ví dụ: 0.08)
- `lotBase`: Base lot size (ví dụ: 0.1)
- `lotMax`: Max lot size cap (ví dụ: 5.0)
- `equityPerLotInc`: Equity per lot increment ($) (ví dụ: 1000.0)
- `lotIncrement`: Lot increment per step (ví dụ: 0.1)

---

## 🎯 4. Helper Functions

### 4.1. Get Local Hour (GMT+7 Conversion)

**Mô tả**: Convert broker time sang **GMT+7** (Vietnam Time) để kiểm tra session đúng giờ địa phương.

```cpp
int CRiskGate::GetLocalHour() {
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);
    
    // ═══════════════════════════════════════════════════════════
    // TIMEZONE CONVERSION: Server Time → GMT+7 (VN Time)
    // ═══════════════════════════════════════════════════════════
    int server_gmt = (int)(TimeGMTOffset() / 3600);  // Broker GMT offset
    int vn_gmt = 7;                                   // Target: GMT+7
    int delta = vn_gmt - server_gmt;                 // Chênh lệch
    
    // Convert: Server Hour → VN Hour
    int hour_localvn = (dt.hour + delta + 24) % 24;
    
    return hour_localvn;
}
```

**Công thức:**
```
VN_Hour = (Server_Hour + Delta + 24) % 24

Trong đó:
  Delta = VN_GMT - Server_GMT
  VN_GMT = 7 (cố định)
  Server_GMT = TimeGMTOffset() / 3600
```

**Ví dụ Conversion:**

| Broker GMT | Server Time | Delta | VN Time (GMT+7) | Calculation |
|------------|-------------|-------|-----------------|-------------|
| GMT+0      | 14:00       | +7    | 21:00           | (14+7)%24=21 |
| GMT+0      | 17:00       | +7    | 00:00           | (17+7)%24=0  |
| GMT+2      | 16:00       | +5    | 21:00           | (16+5)%24=21 |
| GMT+2      | 19:00       | +5    | 00:00           | (19+5)%24=0  |
| GMT+3      | 10:00       | +4    | 14:00           | (10+4)%24=14 |
| GMT+3      | 20:00       | +4    | 00:00           | (20+4)%24=0  |

**Lưu ý quan trọng:**
- ✅ **Tự động detect** broker GMT offset qua `TimeGMTOffset()`
- ✅ **Không cần hardcode** broker timezone
- ✅ **Hoạt động với mọi broker** (GMT+0, GMT+2, GMT+3, etc.)
- ✅ **Modulo 24** để wrap-around qua midnight (25→1, 26→2, etc.)
- ✅ **+24** trong công thức để tránh số âm

**Chi tiết**: Xem [TIMEZONE_CONVERSION.md](TIMEZONE_CONVERSION.md)

### 4.2. Get ATR

```cpp
double CRiskGate::GetATR() {
    if(m_atrHandle == INVALID_HANDLE) return 0;
    
    double atr[1];
    if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) <= 0) {
        return 0;
    }
    
    return atr[0];
}
```

**ATR Period**: 14 (mặc định)

---

## 🎯 5. Integration với Main Flow

### 5.1. Trong OnInit()

```cpp
int OnInit() {
    // ... other initialization ...
    
    // Initialize Risk Gate (Layer 0)
    g_riskGate = new CRiskGate();
    g_riskGate.Init(
        _Symbol, _Period,
        InpRiskPerTradePct, InpDailyMddMax, InpUseDailyMDD, 
        InpUseEquityMDD, InpDailyResetHour,
        true, InpFullDayStart, InpFullDayEnd,  // Session
        InpSpreadMaxPts, InpSpreadATRpct,
        InpLotBase, InpLotMax, InpEquityPerLotInc, InpLotIncrement
    );
    
    // ... other initialization ...
}
```

### 5.2. Trong OnTick()

```cpp
void OnTick() {
    // ═══════════════════════════════════════════════════════════
    // LAYER 0: Risk Gate Check (FIRST)
    // ═══════════════════════════════════════════════════════════
    RiskGateResult riskResult = g_riskGate.Check();
    
    if(!riskResult.canTrade) {
        // Log reason nếu cần
        if(riskResult.reason != "OK") {
            Print("⚠️ Risk Gate BLOCKED: ", riskResult.reason);
        }
        return; // Exit early, không chạy Detection/Arbitration/Execution
    }
    
    // ═══════════════════════════════════════════════════════════
    // LAYER 1: Detection (chỉ chạy nếu Risk Gate OK)
    // ═══════════════════════════════════════════════════════════
    // ... run detectors ...
    
    // ═══════════════════════════════════════════════════════════
    // LAYER 2: Arbitration (chỉ chạy nếu có signals)
    // ═══════════════════════════════════════════════════════════
    // ... build candidates ...
    
    // ═══════════════════════════════════════════════════════════
    // LAYER 3: Execution (chỉ chạy nếu có valid candidate)
    // ═══════════════════════════════════════════════════════════
    // ... place orders ...
    
    // Sử dụng riskResult.maxRiskPips và riskResult.maxLotSize
    // để giới hạn lot size và SL distance
}
```

**Quy trình:**
1. **Risk Gate Check** → Nếu `canTrade = false` → Return ngay, không chạy các layer khác
2. **Detection** → Chỉ chạy nếu `canTrade = true`
3. **Arbitration** → Chỉ chạy nếu có signals
4. **Execution** → Chỉ chạy nếu có valid candidate
5. **Sử dụng** `maxRiskPips` và `maxLotSize` để giới hạn lot size và SL distance

---

## 🎯 6. Configuration Examples

### 6.1. Conservative Profile

```cpp
// Risk
InpRiskPerTradePct = 0.2;      // 0.2% risk per trade
InpDailyMddMax = 5.0;          // 5% daily MDD limit
InpUseDailyMDD = true;
InpUseEquityMDD = true;

// Session
InpSessionMode = SESSION_FULL_DAY;
InpFullDayStart = 7;
InpFullDayEnd = 23;

// Spread
InpSpreadMaxPts = 400;         // Stricter spread
InpSpreadATRpct = 0.06;        // 6% of ATR

// Lot Sizing
InpLotBase = 0.05;             // Smaller base
InpLotMax = 2.0;               // Lower max
InpEquityPerLotInc = 2000.0;   // Slower growth
InpLotIncrement = 0.05;
```

### 6.2. Balanced Profile (Recommended)

```cpp
// Risk
InpRiskPerTradePct = 0.5;      // 0.5% risk per trade
InpDailyMddMax = 8.0;          // 8% daily MDD limit
InpUseDailyMDD = true;
InpUseEquityMDD = true;

// Session
InpSessionMode = SESSION_FULL_DAY;
InpFullDayStart = 7;
InpFullDayEnd = 23;

// Spread
InpSpreadMaxPts = 500;         // 50 pips XAUUSD
InpSpreadATRpct = 0.08;        // 8% of ATR

// Lot Sizing
InpLotBase = 0.1;              // Base lot
InpLotMax = 5.0;               // Max lot cap
InpEquityPerLotInc = 1000.0;   // $1000 per increment
InpLotIncrement = 0.1;
```

### 6.3. Aggressive Profile

```cpp
// Risk
InpRiskPerTradePct = 1.0;      // 1% risk per trade
InpDailyMddMax = 12.0;         // 12% daily MDD limit
InpUseDailyMDD = true;
InpUseEquityMDD = true;

// Session
InpSessionMode = SESSION_MULTI_WINDOW;
// Window 1: 7-11, Window 2: 12-16, Window 3: 18-23

// Spread
InpSpreadMaxPts = 600;         // Wider spread allowed
InpSpreadATRpct = 0.10;        // 10% of ATR

// Lot Sizing
InpLotBase = 0.2;              // Larger base
InpLotMax = 10.0;              // Higher max
InpEquityPerLotInc = 500.0;    // Faster growth
InpLotIncrement = 0.2;
```

---

## 🎯 7. Error Handling & Logging

### 7.1. Logging

**Success:**
```
✅ Risk Gate initialized
📊 Daily tracking reset. Start balance: $10000.00
```

**Warnings:**
```
⚠️ Trading HALTED: Daily MDD 9.00% >= 8.00%
⚠️ Risk Gate BLOCKED: Spread too wide
⚠️ Risk Gate BLOCKED: Outside trading session
```

**Errors:**
```
❌ ERROR: Failed to create ATR indicator
```

### 7.2. Error Handling

- **ATR Handle Invalid**: Return `false` trong `Init()`, EA không khởi động
- **Daily MDD Reset Failed**: Log warning, tiếp tục với giá trị cũ
- **Spread Check Failed**: Return `canTrade = false`, reason = "Spread too wide"

---

## 🎯 8. Best Practices

### 8.1. Daily MDD

- ✅ **Enable** cho tài khoản live
- ✅ **Use Equity** thay vì Balance (chính xác hơn)
- ✅ **Reset Hour**: 6h GMT+7 (trước khi session mở)
- ✅ **Limit**: 5-8% cho conservative, 8-12% cho aggressive

### 8.2. Session Management

- ✅ **Full Day** cho automation đầy đủ
- ✅ **Multi-Window** cho focus vào high-liquidity sessions
- ✅ **Timezone**: Đảm bảo convert đúng GMT+7

### 8.3. Spread Filter

- ✅ **Static Max**: 500 points (50 pips) cho XAUUSD
- ✅ **Dynamic ATR%**: 8% of ATR (tự động adjust theo volatility)
- ✅ **Check cả hai**: Block nếu vượt bất kỳ limit nào

### 8.4. Lot Sizing

- ✅ **Dynamic**: Tăng theo equity để tận dụng vốn
- ✅ **Cap**: Giới hạn max lot để tránh over-leverage
- ✅ **Base**: Bắt đầu từ lot nhỏ (0.05-0.1)

---

## 🎯 9. Testing Checklist

- [ ] Risk Gate initialized successfully
- [ ] Daily MDD check hoạt động đúng
- [ ] Daily reset tại đúng giờ
- [ ] Session check hoạt động (Full Day và Multi-Window)
- [ ] Spread check hoạt động (static và dynamic)
- [ ] Rollover check hoạt động
- [ ] Max risk pips calculation đúng
- [ ] Max lot size calculation đúng (dynamic)
- [ ] Lot size cap hoạt động
- [ ] Error handling khi ATR handle invalid
- [ ] Logging đầy đủ
- [ ] Integration với main flow đúng

---

## 🔗 Tài Liệu Liên Quan

- [REFACTOR_PROPOSAL.md](REFACTOR_PROPOSAL.md) - Kiến trúc 6 layers
- [RISK_MANAGEMENT_RULES.md](../business/RISK_MANAGEMENT_RULES.md) - Business rules về risk
- [TRADING_SCHEDULE.md](../business/TRADING_SCHEDULE.md) - Session management
- [07_CONFIGURATION.md](../business/07_CONFIGURATION.md) - Configuration parameters
- [08_MAIN_FLOW.md](08_MAIN_FLOW.md) - Main flow integration

---

## 📝 Tóm Tắt

### ✅ Chức Năng Chính:
1. **Daily MDD Protection** → Halt trading nếu vượt limit
2. **Session Check** → Block ngoài giờ trading
3. **Spread Check** → Block nếu spread quá rộng
4. **Rollover Check** → Block trong thời gian rollover
5. **Max Risk Calculation** → Tính toán giới hạn risk pips và lot size

### ✅ Output:
- `RiskGateResult` struct với:
  - `canTrade`: true/false
  - `maxRiskPips`: Số pip tối đa
  - `maxLotSize`: Lot size tối đa
  - `tradingHalted`: Halt status
  - `reason`: Lý do nếu block

### ✅ Integration:
- **Layer 0** chạy **đầu tiên** trong OnTick()
- Nếu `canTrade = false` → Return ngay, không chạy các layer khác
- Nếu `canTrade = true` → Tiếp tục với Detection/Arbitration/Execution

---

**Cập nhật lần cuối**: 2025-12-14  
**Phiên bản**: v2.1  
**File**: `Include/Core/risk_gate.mqh`

