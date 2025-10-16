# 04. Thực Thi Lệnh (Executor)

## 📍 Tổng Quan

**File**: `executor.mqh`

Lớp `CExecutor` chịu trách nhiệm:
1. **Session Management** - Kiểm tra giờ giao dịch
2. **Spread Filter** - Lọc spread quá rộng
3. **Trigger Detection** - Tìm candle xác nhận entry
4. **Entry Calculation** - Tính Entry/SL/TP
5. **Order Placement** - Đặt lệnh stop order
6. **Order Management** - Quản lý TTL của pending orders

---

## 1️⃣ Session Management

### 🎯 Mục Đích
Chỉ trade trong giờ được cấu hình, tránh các khung giờ không thanh khoản.

Bot hỗ trợ **2 chế độ**:
1. **FULL DAY**: 7-23h continuous
2. **MULTI-WINDOW**: 3 khung giờ riêng biệt (có thể ON/OFF từng khung)

Chi tiết đầy đủ: **[MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md)**

---

### ⚙️ Cơ Chế

#### Mode 1: Full Day (Simple)

```cpp
bool SessionOpen() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s);
    
    // Calculate timezone offset (GMT+7)
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    // Simple range check
    bool inSession = (hour_localvn >= m_sessStartHour && 
                      hour_localvn < m_sessEndHour);
    
    // Log once per hour
    static int lastLogHour = -1;
    if(s.hour != lastLogHour) {
        Print("🕐 Session Check | Server: ", s.hour, ":00",
              " | VN Time: ", hour_localvn, ":00",
              " | Mode: FULL DAY",
              " | Status: ", inSession ? "IN ✅" : "CLOSED ❌");
        lastLogHour = s.hour;
    }
    
    return inSession;
}
```

**Config**:
```cpp
InpSessionMode = SESSION_FULL_DAY;
InpFullDayStart = 7;   // 07:00 GMT+7
InpFullDayEnd = 23;    // 23:00 GMT+7
```

---

#### Mode 2: Multi-Window (Flexible)

```cpp
bool SessionOpen() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s);
    
    // Calculate VN time (same formula)
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    bool inSession = false;
    string sessionName = "CLOSED";
    
    if(m_sessionMode == SESSION_FULL_DAY) {
        // Full day logic
        inSession = (hour_localvn >= m_sessStartHour && 
                    hour_localvn < m_sessEndHour);
        if(inSession) sessionName = "FULL DAY";
        
    } else if(m_sessionMode == SESSION_MULTI_WINDOW) {
        // Check each window
        for(int i = 0; i < 3; i++) {
            if(!m_windows[i].enabled) continue;
            
            if(hour_localvn >= m_windows[i].startHour &&
               hour_localvn < m_windows[i].endHour) {
                inSession = true;
                sessionName = m_windows[i].name;
                break;
            }
        }
    }
    
    // Log once per hour
    static int lastLogHour = -1;
    if(s.hour != lastLogHour) {
        Print("🕐 Session Check | Server: ", s.hour, ":00",
              " | VN Time: ", hour_localvn, ":00",
              " | Mode: ", m_sessionMode == SESSION_FULL_DAY ? 
                          "FULL DAY" : "MULTI-WINDOW",
              " | Session: ", sessionName,
              " | Status: ", inSession ? "IN ✅" : "OUT ❌");
        lastLogHour = s.hour;
    }
    
    return inSession;
}
```

**Config**:
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;

// Window 1: Asia
InpWindow1_Enable = true;
InpWindow1_Start = 7;
InpWindow1_End = 11;

// Window 2: London
InpWindow2_Enable = true;
InpWindow2_Start = 12;
InpWindow2_End = 16;

// Window 3: NY
InpWindow3_Enable = true;
InpWindow3_Start = 18;
InpWindow3_End = 23;
```

---

### 📊 Timeline Comparison

#### Full Day Mode
```
GMT+7:  00  01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20  21  22  23
        ════════════════════════════│═══════════════════════════════════════════════════════════════│════
Status: ─────── CLOSED ─────────────┤────────────────── IN SESSION ──────────────────────────────┤ CLOSED
                                    └─ 7h                                                     23h ─┘
Duration: 16 hours continuous
```

#### Multi-Window Mode
```
GMT+7:  00  01  02  03  04  05  06  07  08  09  10  11  12  13  14  15  16  17  18  19  20  21  22  23
        ════════════════════════════│═══════│⊘│═════│⊘⊘│═══════════════│════
Status: ─────── CLOSED ─────────────┤ Win1  │ │ W2  │   │     Win3      │ CLOSED
                                    └ Asia ─┘ │ Lon │   └───── NY ─────┘
                                      7-11    │12-16│      18-23
                                              └BREAK┘
Windows: 3 separate sessions
Breaks: 2 periods (11-12h, 16-18h)
Duration: 4h + 4h + 5h = 13 hours total
```

---

### 💡 Example Logs

**Full Day**:
```
═══════════════════════════════════════
📅 SESSION CONFIGURATION:
   Mode: FULL DAY
   Hours: 7:00 - 23:00 GMT+7
   Duration: 16 hours
═══════════════════════════════════════

🕐 Session Check | Server: 02:00 | VN Time: 07:00 | Mode: FULL DAY | Session: FULL DAY | Status: IN ✅
🕐 Session Check | Server: 05:00 | VN Time: 12:00 | Mode: FULL DAY | Session: FULL DAY | Status: IN ✅
🕐 Session Check | Server: 11:00 | VN Time: 18:00 | Mode: FULL DAY | Session: FULL DAY | Status: IN ✅
```

**Multi-Window**:
```
═══════════════════════════════════════
📅 SESSION CONFIGURATION:
   Mode: Multi-Window
   Windows:
   - Asia: ✅ ON (7:00-11:00)
   - London: ✅ ON (12:00-16:00)
   - NY: ✅ ON (18:00-23:00)
═══════════════════════════════════════

🕐 Session Check | Server: 02:00 | VN Time: 07:00 | Mode: MULTI-WINDOW | Session: Asia | Status: IN ✅
🕐 Session Check | Server: 06:00 | VN Time: 11:00 | Mode: MULTI-WINDOW | Session: CLOSED | Status: OUT ❌
🕐 Session Check | Server: 07:00 | VN Time: 12:00 | Mode: MULTI-WINDOW | Session: London | Status: IN ✅
🕐 Session Check | Server: 11:00 | VN Time: 16:00 | Mode: MULTI-WINDOW | Session: CLOSED | Status: OUT ❌
🕐 Session Check | Server: 13:00 | VN Time: 18:00 | Mode: MULTI-WINDOW | Session: NY | Status: IN ✅
```

### 📊 Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpTZ` | "Asia/Ho_Chi_Minh" | Timezone reference |
| `InpSessStartHour` | 7 | Start hour (GMT+7) |
| `InpSessEndHour` | 23 | End hour (GMT+7) |

### 💡 Ví Dụ

```
Server Time: 02:00 (GMT+0)
Server GMT Offset: +0
VN GMT: +7
Delta: +7

Local VN Time: (2 + 7) % 24 = 9:00

Session Config: 7:00 - 23:00
Status: IN SESSION ✅
```

### ⚠️ Quan Trọng
```
Nếu server GMT+2:
  Server: 04:00
  Delta: 7 - 2 = +5
  VN Time: (4 + 5) % 24 = 9:00 ✓

Nếu server GMT+3:
  Server: 05:00
  Delta: 7 - 3 = +4
  VN Time: (5 + 4) % 24 = 9:00 ✓

→ Công thức hoạt động với mọi server!
```

---

## 2️⃣ Spread Filter

### 🎯 Mục Đích
Tránh entry khi spread quá rộng, gây slippage lớn.

### ⚙️ Cơ Chế

```cpp
bool SpreadOK() {
    long spread = SymbolInfoInteger(Symbol, SYMBOL_SPREAD);
    double atr = GetATR();
    
    // Dynamic spread filter: max(static, 8% of ATR)
    if(atr > 0) {
        long dynamicMax = (long)MathMax(SpreadMaxPts, 
                                        0.08 * atr / _Point);
        
        if(spread > dynamicMax) {
            Print("⚠️ Spread too wide: ", spread, " pts (max: ", 
                  dynamicMax, " pts)");
            return false;
        }
        return true;
    }
    
    // Fallback to static if can't get ATR
    if(spread > SpreadMaxPts) {
        Print("⚠️ Spread too wide: ", spread, " pts (max: ", 
              SpreadMaxPts, " pts)");
        return false;
    }
    return true;
}
```

### 📊 Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpSpreadMaxPts` | 500 | Static max (points) |
| `InpSpreadATRpct` | 0.08 | Dynamic % of ATR |

### 💡 Ví Dụ

```
Scenario 1: Normal Market
──────────────────────────────────────
ATR: 5.0 points
Dynamic Max = max(500, 5.0/0.0001 × 0.08)
            = max(500, 4000)
            = 4000 points

Current Spread: 450 points
Result: OK ✅ (450 < 4000)

Scenario 2: High Volatility
──────────────────────────────────────
ATR: 15.0 points
Dynamic Max = max(500, 15.0/0.0001 × 0.08)
            = max(500, 12000)
            = 12000 points

Current Spread: 800 points
Result: OK ✅ (800 < 12000)

Scenario 3: Wide Spread
──────────────────────────────────────
ATR: 5.0 points
Dynamic Max = 4000 points

Current Spread: 5500 points
Result: TOO WIDE ❌
```

---

## 3️⃣ Rollover Protection

### 🎯 Mục Đích
Tránh trade trong rollover time (00:00 ±5 min) khi spread spike.

### ⚙️ Cơ Chế

```cpp
bool IsRolloverTime() {
    datetime t = TimeCurrent();
    MqlDateTime s;
    TimeToStruct(t, s);
    
    // Minutes from midnight
    int minutesFromMidnight = s.hour * 60 + s.min;
    
    // Within 5 min of midnight?
    if(minutesFromMidnight < 5 ||        // 00:00 - 00:05
       minutesFromMidnight > 1435) {     // 23:55 - 24:00
        return true;
    }
    
    return false;
}
```

### 💡 Ví Dụ

```
Time: 23:57
Minutes: 23 × 60 + 57 = 1437
1437 > 1435 → IsRollover = true ❌

Time: 00:02
Minutes: 0 × 60 + 2 = 2
2 < 5 → IsRollover = true ❌

Time: 00:06
Minutes: 0 × 60 + 6 = 6
6 >= 5 AND 6 <= 1435 → IsRollover = false ✅
```

---

## 4️⃣ Trigger Candle Detection

### 🎯 Mục Đích
Tìm candle confirmation trước khi entry, đảm bảo momentum vẫn còn.

### ⚙️ Cơ Chế

```cpp
bool GetTriggerCandle(int direction, 
                      double &triggerHigh, double &triggerLow) {
    double atr = GetATR();
    if(atr <= 0) return false;
    
    // Min body size: 30% of ATR or min 30 points (3 pips)
    double minBodySize = MathMax((TriggerBodyATR / 100.0) * atr,
                                 30.0 * _Point);
    
    // Scan bars 0-3 (recent candles)
    for(int i = 0; i <= 3; i++) {
        double open = iOpen(Symbol, Timeframe, i);
        double close = iClose(Symbol, Timeframe, i);
        double high = iHigh(Symbol, Timeframe, i);
        double low = iLow(Symbol, Timeframe, i);
        double bodySize = MathAbs(close - open);
        
        if(bodySize >= minBodySize) {
            // For SELL setup, need bearish trigger
            if(direction == -1 && close < open) {
                triggerHigh = high;
                triggerLow = low;
                Print("🎯 Trigger SELL: Bar ", i, 
                      " | Body: ", (int)(bodySize/_Point), " pts");
                return true;
            }
            // For BUY setup, need bullish trigger
            else if(direction == 1 && close > open) {
                triggerHigh = high;
                triggerLow = low;
                Print("🎯 Trigger BUY: Bar ", i,
                      " | Body: ", (int)(bodySize/_Point), " pts");
                return true;
            }
        }
    }
    
    Print("❌ No trigger candle found (scanned bars 0-3)");
    return false;
}
```

### 📊 Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpTriggerBodyATR` | 30 | Min body (0.30 ATR × 100) |

### 💡 Ví Dụ

```
Setup: LONG (direction = 1)
ATR: 5.0 points
Min Body = max(0.30 × 5.0, 0.30) = max(1.5, 0.30) = 1.5 points

Scan Bars:
──────────────────────────────────────
Bar 0: Open 2650.00, Close 2649.95 (bearish)
  Body = 0.05 → Skip (bearish & small)

Bar 1: Open 2649.90, Close 2650.80 (bullish)
  Body = 0.90 → Skip (< 1.5 min)

Bar 2: Open 2649.50, Close 2651.20 (bullish)
  Body = 1.70 → FOUND! ✅
  triggerHigh = 2651.30
  triggerLow = 2649.40

→ Use Bar 2 as trigger
```

---

## 5️⃣ Entry Calculation

### 🎯 Mục Đích
Tính toán Entry, SL, TP dựa trên setup và config.

### ⚙️ Thuật Toán

```cpp
bool CalculateEntry(Candidate c, double triggerHigh, double triggerLow,
                    double &entry, double &sl, double &tp, double &rr) {
    if(!c.valid) return false;
    
    double buffer = EntryBufferPts * _Point;
    double atr = GetATR();
    
    if(c.direction == 1) {  // BUY SETUP
        // ═══════════════════════════════════════════════
        // STEP 1: Calculate Entry
        // ═══════════════════════════════════════════════
        entry = triggerHigh + buffer;
        
        // ═══════════════════════════════════════════════
        // STEP 2: Calculate METHOD-based SL
        // ═══════════════════════════════════════════════
        double methodSL = 0;
        
        if(c.hasSweep) {
            methodSL = c.sweepLevel - buffer;
        } else if(c.hasOB || c.hasFVG) {
            methodSL = c.poiBottom - buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop distance
        double slDistance = entry - methodSL;
        double minStopDistance = MinStopPts * _Point;
        if(slDistance < minStopDistance) {
            methodSL = entry - minStopDistance;
        }
        
        // ═══════════════════════════════════════════════
        // STEP 3: Calculate METHOD-based TP
        // ═══════════════════════════════════════════════
        double methodRisk = entry - methodSL;
        double methodTP = entry + (methodRisk * MinRR);
        
        // ═══════════════════════════════════════════════
        // STEP 4: Apply FIXED SL if enabled
        // ═══════════════════════════════════════════════
        if(UseFixedSL) {
            double fixedSL_Distance = FixedSL_Pips * 10 * _Point;
            sl = entry - fixedSL_Distance;
            Print("📌 FIXED SL: ", FixedSL_Pips, " pips (override)");
        } else {
            sl = methodSL;
            Print("🎯 METHOD SL: ", (int)((entry-sl)/_Point/10), 
                  " pips (from structure)");
        }
        
        // ═══════════════════════════════════════════════
        // STEP 5: TP (always use METHOD, not affected by Fixed SL)
        // ═══════════════════════════════════════════════
        if(FixedTP_Enable) {
            double fixedTP_Distance = FixedTP_Pips * 10 * _Point;
            tp = entry + fixedTP_Distance;
            Print("📌 FIXED TP: ", FixedTP_Pips, " pips (absolute)");
        } else {
            tp = methodTP;
            Print("🎯 METHOD TP: ", (int)((tp-entry)/_Point/10),
                  " pips (from method RR)");
        }
        
    } else if(c.direction == -1) {  // SELL SETUP
        // Similar logic, opposite direction
        entry = triggerLow - buffer;
        
        if(c.hasSweep) {
            methodSL = c.sweepLevel + buffer;
        } else if(c.hasOB || c.hasFVG) {
            methodSL = c.poiTop + buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop
        double slDistance = methodSL - entry;
        if(slDistance < MinStopPts * _Point) {
            methodSL = entry + MinStopPts * _Point;
        }
        
        double methodRisk = methodSL - entry;
        double methodTP = entry - (methodRisk * MinRR);
        
        // Apply Fixed SL/TP if enabled
        if(UseFixedSL) {
            sl = entry + FixedSL_Pips * 10 * _Point;
        } else {
            sl = methodSL;
        }
        
        if(FixedTP_Enable) {
            tp = entry - FixedTP_Pips * 10 * _Point;
        } else {
            tp = methodTP;
        }
    }
    
    // ═══════════════════════════════════════════════
    // STEP 6: Normalize prices
    // ═══════════════════════════════════════════════
    entry = NormalizeDouble(entry, _Digits);
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    
    // ═══════════════════════════════════════════════
    // STEP 7: Calculate actual RR
    // ═══════════════════════════════════════════════
    if(c.direction == 1) {
        double denominator = entry - sl;
        if(MathAbs(denominator) < _Point) {
            Print("❌ Invalid: Entry/SL too close");
            return false;
        }
        rr = (tp - entry) / denominator;
    } else {
        double denominator = sl - entry;
        if(MathAbs(denominator) < _Point) {
            Print("❌ Invalid: Entry/SL too close");
            return false;
        }
        rr = (entry - tp) / denominator;
    }
    
    // ═══════════════════════════════════════════════
    // STEP 8: Check minimum RR
    // ═══════════════════════════════════════════════
    if(rr < MinRR) {
        Print("❌ RR too low: ", DoubleToString(rr, 2), 
              " (min: ", MinRR, ")");
        return false;
    }
    
    return true;
}
```

### 📊 Parameters

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpEntryBufferPts` | 70 | Entry buffer (points) |
| `InpMinStopPts` | 300 | Min stop distance (pts) |
| `InpMinRR` | 2.0 | Minimum R:R ratio |
| `InpUseFixedSL` | false | Use fixed SL mode |
| `InpFixedSL_Pips` | 100 | Fixed SL (pips) |
| `InpFixedTP_Enable` | false | Use fixed TP |
| `InpFixedTP_Pips` | 200 | Fixed TP (pips) |

### 💡 Ví Dụ

#### Example 1: Method-Based SL/TP
```
Setup: BUY
Trigger: High 2650.10, Low 2649.85
Sweep Level: 2648.50
OB: 2649.00 - 2649.50

Calculation:
──────────────────────────────────────
Entry = 2650.10 + 0.07 = 2650.17

Method SL = 2648.50 - 0.07 = 2648.43
  (from sweep level)

Check Min Stop: 2650.17 - 2648.43 = 1.74 (174 pts)
  174 >= 300? NO
  Adjust: SL = 2650.17 - 3.00 = 2647.17

Method Risk = 2650.17 - 2647.17 = 3.00

Method TP = 2650.17 + (3.00 × 2.0) = 2656.17

Fixed SL? NO → Use Method SL: 2647.17
Fixed TP? NO → Use Method TP: 2656.17

RR = (2656.17 - 2650.17) / (2650.17 - 2647.17)
   = 6.00 / 3.00
   = 2.0 ✅
```

#### Example 2: Fixed SL/TP Mode
```
Setup: BUY
Trigger: High 2650.10
Config:
  UseFixedSL: true
  FixedSL_Pips: 100
  FixedTP_Enable: true
  FixedTP_Pips: 200

Calculation:
──────────────────────────────────────
Entry = 2650.17

Fixed SL = 2650.17 - (100 × 0.10) = 2640.17
  (override method)

Fixed TP = 2650.17 + (200 × 0.10) = 2670.17
  (absolute)

RR = (2670.17 - 2650.17) / (2650.17 - 2640.17)
   = 20.00 / 10.00
   = 2.0 ✅
```

---

## 6️⃣ Order Placement

### ⚙️ Cơ Chế

```cpp
bool PlaceStopOrder(int direction, double entry, double sl, double tp,
                    double lots, string comment) {
    if(!SessionOpen() || !SpreadOK() || IsRolloverTime()) {
        return false;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = Symbol;
    request.volume = NormalizeDouble(lots, 2);
    request.price = entry;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 20;
    request.magic = 20251013;
    request.comment = comment;
    
    if(direction == 1) {
        request.type = ORDER_TYPE_BUY_STOP;
        double ask = SymbolInfoDouble(Symbol, SYMBOL_ASK);
        if(entry <= ask) {
            Print("Buy stop entry too close to current price");
            return false;
        }
    } else if(direction == -1) {
        request.type = ORDER_TYPE_SELL_STOP;
        double bid = SymbolInfoDouble(Symbol, SYMBOL_BID);
        if(entry >= bid) {
            Print("Sell stop entry too close to current price");
            return false;
        }
    } else {
        return false;
    }
    
    bool sent = OrderSend(request, result);
    
    if(sent && result.retcode == TRADE_RETCODE_DONE) {
        Print("Order placed successfully: ", result.order);
        SetOrderTTL(result.order);
        return true;
    } else {
        Print("Order failed: ", result.retcode, " - ", result.comment);
        return false;
    }
}
```

### 💡 Ví Dụ

```
Direction: BUY (1)
Entry: 2650.17
SL: 2648.43
TP: 2653.65
Lots: 3.0

Pre-checks:
  SessionOpen: true ✓
  SpreadOK: true ✓
  IsRollover: false ✓

Order Type: ORDER_TYPE_BUY_STOP
Current Ask: 2649.85
Entry > Ask? 2650.17 > 2649.85? YES ✓

OrderSend():
  → Success!
  → Order #12345 placed
  → Set TTL: 16 bars
```

---

## 7️⃣ Pending Order TTL Management

### 🎯 Mục Đích
Tự động cancel pending orders nếu không fill trong thời gian quy định.

### ⚙️ Cơ Chế

```cpp
void ManagePendingOrders() {
    datetime currentTime = TimeCurrent();
    int currentBar = iBars(Symbol, Timeframe);
    
    for(int i = ArraySize(pendingOrders) - 1; i >= 0; i--) {
        // Check if order still exists
        if(!OrderSelect(pendingOrders[i].ticket)) {
            // Order filled or cancelled, remove from tracking
            ArrayRemove(pendingOrders, i, 1);
            continue;
        }
        
        // Calculate bars age
        datetime orderTime = pendingOrders[i].placedTime;
        int orderBar = iBarShift(Symbol, Timeframe, orderTime);
        int currentBar = 0;
        pendingOrders[i].barsAge = orderBar - currentBar;
        
        // Check TTL
        if(pendingOrders[i].barsAge >= Order_TTL_Bars) {
            // Cancel order
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);
            
            request.action = TRADE_ACTION_REMOVE;
            request.order = pendingOrders[i].ticket;
            
            if(OrderSend(request, result)) {
                Print("Order ", pendingOrders[i].ticket,
                      " cancelled due to TTL");
            }
            
            ArrayRemove(pendingOrders, i, 1);
        }
    }
}
```

### 📊 Parameter

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| `InpOrder_TTL_Bars` | 16 | TTL in bars (M15 = 4-8h) |

### 💡 Ví Dụ

```
Order #12345 placed at bar 100
Current bar: 116
Age: 116 - 100 = 16 bars

TTL: 16 bars
Age >= TTL? 16 >= 16? YES

→ Cancel order #12345
→ Remove from tracking
→ Log: "Order 12345 cancelled due to TTL"
```

---

## 📊 Complete Flow Example

```
SCENARIO: BUY Setup
──────────────────────────────────────

1. PRE-CHECKS
   ✓ SessionOpen: true (9:00 GMT+7)
   ✓ SpreadOK: 450 pts < 4000 max
   ✓ IsRollover: false
   
2. TRIGGER DETECTION
   Scan bars 0-3:
     Bar 2: Bullish, body 1.7 pts (>1.5 min)
     → triggerHigh: 2651.30
     → triggerLow: 2649.40
   
3. ENTRY CALCULATION
   Candidate:
     direction: 1 (LONG)
     hasSweep: true
     sweepLevel: 2648.50
   
   Entry: 2651.30 + 0.07 = 2651.37
   
   Method SL: 2648.50 - 0.07 = 2648.43
   Check Min Stop: 2651.37 - 2648.43 = 2.94 (294 pts)
   294 >= 300? NO → Adjust: 2651.37 - 3.00 = 2648.37
   
   Method TP: 2651.37 + (3.00 × 2.0) = 2657.37
   
   Fixed SL? NO → Use 2648.37
   Fixed TP? NO → Use 2657.37
   
   RR: 6.00 / 3.00 = 2.0 ✅
   
4. ORDER PLACEMENT
   Type: BUY_STOP
   Price: 2651.37
   SL: 2648.37
   TP: 2657.37
   Lots: 3.0
   Comment: "SMC_BUY_RR2.0"
   
   Current Ask: 2650.85
   Entry > Ask? YES ✓
   
   → OrderSend() SUCCESS
   → Order #12345 placed
   → TTL set: 16 bars

5. TRACKING
   pendingOrders[0]:
     ticket: 12345
     placedTime: 2025-10-16 09:00
     barsAge: 0
```

---

## 🎓 Key Points

### ✅ Best Practices
1. **Always check pre-conditions** before placing order
2. **Use trigger candles** for confirmation
3. **Ensure minimum stop distance** for safety
4. **Track TTL** to avoid stale orders
5. **Log all decisions** for debugging

### ⚠️ Common Issues
1. **Entry too close to current price** → Order rejected
2. **SL/TP not normalized** → Order rejected
3. **Spread check missed** → Bad fills
4. **Session check skipped** → Trade at bad times
5. **TTL not tracked** → Orders never expire

### 📈 Optimization Tips
1. Adjust `TriggerBodyATR` for different markets
2. Use dynamic spread filter in volatile conditions
3. Set appropriate TTL based on timeframe
4. Consider Fixed SL mode for consistent risk
5. Monitor order placement success rate

---

---

## 🆕 v2.0 Updates

### 1. News Embargo Filter

#### 🎯 Mục Đích
Skip new entries trước/sau high-impact news events để tránh volatility spike.

#### ⚙️ Implementation
```cpp
bool IsWithinNewsWindow(datetime currentTime) {
    if(!InpEnableNewsFilter) return false;
    
    // Convert to UTC (news.csv uses UTC)
    datetime currentUTC = currentTime - TimeGMTOffset();
    
    for(int i = 0; i < newsCount; i++) {
        if(!ImpactAllowed(news[i].impact)) continue;
        
        datetime eventTime = news[i].timestamp;
        int beforeSec = InpNewsBeforeMin * 60;
        int afterSec = InpNewsAfterMin * 60;
        
        if(currentUTC >= eventTime - beforeSec && 
           currentUTC <= eventTime + afterSec) {
            Print("⚠️ NEWS WINDOW: ", news[i].title);
            return true;
        }
    }
    return false;
}
```

#### 📊 Parameters
```cpp
input bool   InpEnableNewsFilter = true;
input int    InpNewsBeforeMin    = 20;     // Skip 20min before
input int    InpNewsAfterMin     = 20;     // Skip 20min after
input string InpNewsImpactFilter = "HIGH_MED"; // HIGH, HIGH_MED, ALL
```

#### 💡 Ví Dụ
```
FOMC Meeting: 2025-10-16 13:30:00 UTC

Window:
  Before: 13:10:00 UTC
  After:  13:50:00 UTC

Behavior:
  13:05 → Trade OK ✅
  13:15 → NEWS WINDOW ❌ (skip new entries)
  13:35 → NEWS WINDOW ❌ (event time)
  13:45 → NEWS WINDOW ❌ (still in window)
  13:55 → Trade OK ✅
```

---

### 2. Volatility Regime Detection

#### 🎯 Mục Đích
Detect LOW/MID/HIGH volatility để adjust execution parameters.

#### ⚙️ Cơ Chế: ATR Percentile
```cpp
enum ENUM_REGIME {
    REGIME_LOW,     // ATR <= P30
    REGIME_MID,     // P30 < ATR < P70
    REGIME_HIGH     // ATR >= P70
};

ENUM_REGIME GetATRPercentileRegime() {
    double atr_now = iATR(_Symbol, _Period, 14, 0);
    
    // Get 180 days of ATR data
    int bars = 180 * 48;  // M30: 48 bars/day
    double atrs[];
    ArrayResize(atrs, bars);
    
    for(int i = 0; i < bars; i++) {
        atrs[i] = iATR(_Symbol, _Period, 14, i);
    }
    
    // Calculate P30 and P70
    ArraySort(atrs);
    double p30 = atrs[(int)(bars * 0.30)];
    double p70 = atrs[(int)(bars * 0.70)];
    
    if(atr_now <= p30) return REGIME_LOW;
    if(atr_now >= p70) return REGIME_HIGH;
    return REGIME_MID;
}
```

#### 📊 Parameters
```cpp
input bool InpRegimeEnable     = true;
input int  InpATRPeriod        = 14;
input int  InpATRDaysLookback  = 180;
input int  InpRegimeLowPct     = 30;   // P30
input int  InpRegimeHighPct    = 70;   // P70
```

#### 💡 Ví Dụ
```
Historical ATR (180 days):
  Min: 3.0
  P30: 4.5
  P70: 7.5
  Max: 12.0

Current ATR: 4.0
→ 4.0 <= 4.5 → REGIME_LOW

Current ATR: 6.0
→ 4.5 < 6.0 < 7.5 → REGIME_MID

Current ATR: 8.5
→ 8.5 >= 7.5 → REGIME_HIGH
```

---

### 3. ATR-Scaled Execution

#### 🎯 Trigger Body by Regime
```cpp
double GetTriggerBodyThreshold(ENUM_REGIME regime) {
    double atr = GetATR();
    
    switch(regime) {
        case REGIME_LOW:  return 0.25 * atr;  // Easier entry
        case REGIME_MID:  return 0.30 * atr;  // Default
        case REGIME_HIGH: return 0.35 * atr;  // Stricter entry
    }
}
```

#### 🎯 Entry Buffer (ATR-scaled)
```cpp
// OLD: Fixed 70 points
double buffer = 70 * _Point;

// NEW: ATR-scaled
double atr = GetATR();
double buffer = atr * InpEntryBufATRMult;

// Example: ATR=5.0, Mult=0.12 → Buffer=0.6 (60 points)
```

#### 🎯 Min Stop (ATR-scaled + Regime)
```cpp
double GetMinStopDistance(ENUM_REGIME regime) {
    double atr = GetATR();
    double minStop = atr * InpMinStopATRMult;
    
    // Scale up in high volatility
    if(regime == REGIME_HIGH) {
        minStop *= 1.3;
    }
    
    return minStop;
}
```

#### 🎯 Order TTL (Adaptive)
```cpp
int GetOrderTTL(ENUM_REGIME regime, bool inMicroWindow) {
    int ttl;
    
    switch(regime) {
        case REGIME_LOW:  ttl = 24; break;
        case REGIME_MID:  ttl = 16; break;
        case REGIME_HIGH: ttl = 10; break;
    }
    
    // Boost in micro-windows (London/NY)
    if(inMicroWindow) {
        ttl += 4;
    }
    
    return ttl;
}
```

#### 📊 New Parameters
```cpp
input double InpTriggerBodyATR_Low  = 0.25;
input double InpTriggerBodyATR_Mid  = 0.30;
input double InpTriggerBodyATR_High = 0.35;

input double InpEntryBufATRMult     = 0.12;
input double InpMinStopATRMult      = 1.0;
```

#### 📊 Regime Impact Table

| Component | LOW | MID | HIGH |
|-----------|-----|-----|------|
| Trigger Body | 0.25 ATR | 0.30 ATR | 0.35 ATR |
| Entry Buffer | 0.12 ATR | 0.10 ATR | 0.07 ATR |
| Min Stop | 1.0 ATR | 1.0 ATR | 1.3 ATR |
| Order TTL | 24 bars | 16 bars | 10 bars |

#### 💡 Ví Dụ

```
REGIME_LOW (ATR = 4.0):
  Trigger: 0.25 × 4.0 = 1.0 point (easy entry)
  Buffer: 0.12 × 4.0 = 0.48 point
  MinStop: 1.0 × 4.0 = 4.0 points
  TTL: 24 bars (more time to fill)

REGIME_HIGH (ATR = 9.0):
  Trigger: 0.35 × 9.0 = 3.15 points (strict entry)
  Buffer: 0.07 × 9.0 = 0.63 point
  MinStop: 1.3 × 9.0 = 11.7 points (wider stop)
  TTL: 10 bars (quick action needed)
```

---

## 🔮 Proposed Improvements: Limit Order Entry

### ⚠️ Current Limitation: Chase Breakout with Stop Orders

#### Problem Analysis

**Current Method**: Buy/Sell Stop Orders
```
BUY Setup Example:
  OB: 2649.00 - 2649.50
  Trigger High: 2650.20
  Entry Buffer: 0.70 points
  
  → Entry: 2650.90 (Stop Order above trigger)
  → SL: 2648.50 (below sweep)
  → Risk: 2.40 points per trade

Issues:
  ❌ Entry FAR from POI (1.90 points away from OB)
  ❌ Large stoploss distance (2.40 points)
  ❌ Lower RR ratio
  ❌ Chasing breakout momentum
```

**ICT Best Practice**: Enter AT the POI (Order Block/FVG)
```
ICT Method:
  → Entry: 2649.00 (Limit at OB bottom)
  → SL: 2648.50 (same)
  → Risk: 0.50 points per trade
  
Benefits:
  ✅ Entry AT discount zone
  ✅ Tight stoploss (4.8× better)
  ✅ Higher RR ratio
  ✅ Wait for pullback
```

---

### 📊 Proposed Solution: Limit Order Option

#### New Entry Methods Enum

```cpp
enum ENTRY_METHOD {
    ENTRY_STOP_ONLY = 0,   // Current: Chase breakout
    ENTRY_LIMIT_ONLY = 1,  // NEW: Wait at POI
    ENTRY_DUAL = 2         // NEW: Split 60% Limit + 40% Stop
};

input ENTRY_METHOD InpEntryMethod = ENTRY_LIMIT_ONLY;
input int InpLimitOrderTTL = 24;  // Longer TTL for limit orders
```

---

#### Implementation: PlaceLimitOrder()

```cpp
bool CExecutor::PlaceLimitOrder(int direction, Candidate &c, 
                                double sl, double tp, double lots, 
                                string comment) {
    if(!SessionOpen() || !SpreadOK() || IsRolloverTime()) {
        return false;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = m_symbol;
    request.volume = NormalizeDouble(lots, 2);
    request.sl = sl;
    request.tp = tp;
    request.deviation = 20;
    request.magic = 20251013;
    request.comment = comment;
    
    // ════════════════════════════════════════════════════════
    // CALCULATE ENTRY PRICE (at POI)
    // ════════════════════════════════════════════════════════
    double entryPrice = 0;
    double currentPrice = 0;
    
    if(direction == 1) {
        // BUY: Enter at OB bottom or FVG bottom
        if(c.hasOB) {
            entryPrice = c.poiBottom;  // OB demand zone bottom
            Print("📍 Limit BUY entry at OB bottom: ", entryPrice);
        } else if(c.hasFVG) {
            entryPrice = c.fvgBottom;  // FVG bottom edge
            Print("📍 Limit BUY entry at FVG bottom: ", entryPrice);
        } else {
            Print("❌ No POI for limit entry");
            return false;
        }
        
        // Validate: Entry must be BELOW current price (for limit)
        currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
        if(entryPrice >= currentPrice) {
            Print("❌ Limit entry ", entryPrice, " >= current ", 
                  currentPrice, " (invalid for BUY LIMIT)");
            return false;
        }
        
        // Set order type
        request.type = ORDER_TYPE_BUY_LIMIT;
        request.price = entryPrice;
        
    } else if(direction == -1) {
        // SELL: Enter at OB top or FVG top
        if(c.hasOB) {
            entryPrice = c.poiTop;  // OB supply zone top
            Print("📍 Limit SELL entry at OB top: ", entryPrice);
        } else if(c.hasFVG) {
            entryPrice = c.fvgTop;  // FVG top edge
            Print("📍 Limit SELL entry at FVG top: ", entryPrice);
        } else {
            Print("❌ No POI for limit entry");
            return false;
        }
        
        // Validate: Entry must be ABOVE current price (for limit)
        currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        if(entryPrice <= currentPrice) {
            Print("❌ Limit entry ", entryPrice, " <= current ", 
                  currentPrice, " (invalid for SELL LIMIT)");
            return false;
        }
        
        // Set order type
        request.type = ORDER_TYPE_SELL_LIMIT;
        request.price = entryPrice;
        
    } else {
        return false;
    }
    
    // ════════════════════════════════════════════════════════
    // SEND ORDER
    // ════════════════════════════════════════════════════════
    bool sent = OrderSend(request, result);
    
    if(sent && result.retcode == TRADE_RETCODE_DONE) {
        Print("✅ Limit order placed: ", result.order);
        Print("   Entry: ", entryPrice, " (", 
              direction == 1 ? "BUY LIMIT" : "SELL LIMIT", ")");
        Print("   Current: ", currentPrice);
        Print("   Distance: ", (int)(MathAbs(entryPrice - currentPrice) / _Point), " pts");
        
        // Set longer TTL for limit orders
        SetOrderTTL(result.order, InpLimitOrderTTL);
        return true;
    } else {
        Print("❌ Limit order failed: ", result.retcode, " - ", result.comment);
        return false;
    }
}
```

---

#### Update CalculateEntry() for Limit

```cpp
bool CExecutor::CalculateEntry(const Candidate &c, double triggerHigh, double triggerLow,
                               double &entry, double &sl, double &tp, double &rr) {
    if(!c.valid) return false;
    
    double buffer = m_entryBufferPts * _Point;
    double atr = GetATR();
    
    // ════════════════════════════════════════════════════════
    // DETERMINE ENTRY METHOD
    // ════════════════════════════════════════════════════════
    bool useLimitEntry = (InpEntryMethod == ENTRY_LIMIT_ONLY || 
                          InpEntryMethod == ENTRY_DUAL);
    
    if(c.direction == 1) {
        // ════════════════════════════════════════════════════
        // BUY SETUP
        // ════════════════════════════════════════════════════
        
        // Entry calculation
        if(useLimitEntry && (c.hasOB || c.hasFVG)) {
            // LIMIT ORDER: Entry at POI
            if(c.hasOB) {
                entry = c.poiBottom;  // OB bottom
                Print("💡 Limit entry at OB: ", entry);
            } else {
                entry = c.fvgBottom;  // FVG bottom
                Print("💡 Limit entry at FVG: ", entry);
            }
        } else {
            // STOP ORDER: Entry above trigger (original method)
            entry = triggerHigh + buffer;
            Print("💡 Stop entry above trigger: ", entry);
        }
        
        // SL calculation (same logic)
        double methodSL = 0;
        if(c.hasSweep) {
            methodSL = c.sweepLevel - buffer;
        } else if(c.hasOB || c.hasFVG) {
            methodSL = c.poiBottom - buffer;
        } else {
            return false;
        }
        
        // Ensure minimum stop distance
        double slDistance = entry - methodSL;
        double minStopDistance = m_minStopPts * _Point;
        if(slDistance < minStopDistance) {
            methodSL = entry - minStopDistance;
        }
        
        // Apply Fixed SL if enabled
        if(m_useFixedSL) {
            double fixedSL_Distance = m_fixedSL_Pips * 10 * _Point;
            sl = entry - fixedSL_Distance;
        } else {
            sl = methodSL;
        }
        
        // Calculate TP (same logic)
        double methodRisk = entry - sl;
        double methodTP = entry + (methodRisk * m_minRR);
        
        if(m_fixedTP_Enable) {
            double fixedTP_Distance = m_fixedTP_Pips * 10 * _Point;
            tp = entry + fixedTP_Distance;
        } else {
            tp = methodTP;
        }
        
    } else if(c.direction == -1) {
        // ════════════════════════════════════════════════════
        // SELL SETUP (symmetric logic)
        // ════════════════════════════════════════════════════
        
        if(useLimitEntry && (c.hasOB || c.hasFVG)) {
            // LIMIT ORDER: Entry at POI
            if(c.hasOB) {
                entry = c.poiTop;  // OB top
            } else {
                entry = c.fvgTop;  // FVG top
            }
        } else {
            // STOP ORDER: Entry below trigger
            entry = triggerLow - buffer;
        }
        
        // ... same SL/TP logic as BUY (mirrored) ...
        
    } else {
        return false;
    }
    
    // Normalize & calculate RR
    entry = NormalizeDouble(entry, _Digits);
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);
    
    if(c.direction == 1) {
        double denominator = entry - sl;
        if(MathAbs(denominator) < _Point) return false;
        rr = (tp - entry) / denominator;
    } else {
        double denominator = sl - entry;
        if(MathAbs(denominator) < _Point) return false;
        rr = (entry - tp) / denominator;
    }
    
    if(rr < m_minRR) return false;
    
    return true;
}
```

---

#### Update Main EA OnTick()

```cpp
void OnTick() {
    // ... existing pre-checks, detectors, scoring ...
    
    if(g_lastCandidate.valid && score >= 100.0) {
        double triggerHigh, triggerLow;
        
        // For STOP orders, still need trigger candle
        bool needTrigger = (InpEntryMethod == ENTRY_STOP_ONLY);
        
        if(!needTrigger || 
           g_executor.GetTriggerCandle(g_lastCandidate.direction, 
                                       triggerHigh, triggerLow)) {
            
            // Calculate entry/SL/TP
            double entry, sl, tp, rr;
            if(g_executor.CalculateEntry(g_lastCandidate, 
                                        triggerHigh, triggerLow,
                                        entry, sl, tp, rr)) {
                
                // Calculate lots
                double slDistance = MathAbs(entry - sl) / _Point;
                double lots = g_riskMgr.CalcLotsByRisk(InpRiskPerTradePct, 
                                                       slDistance);
                
                // ... existing checks ...
                
                // ════════════════════════════════════════════════
                // PLACE ORDER (method-based)
                // ════════════════════════════════════════════════
                bool orderPlaced = false;
                
                if(InpEntryMethod == ENTRY_LIMIT_ONLY) {
                    // Limit only
                    orderPlaced = g_executor.PlaceLimitOrder(
                        g_lastCandidate.direction, g_lastCandidate,
                        sl, tp, lots, comment
                    );
                    
                } else if(InpEntryMethod == ENTRY_STOP_ONLY) {
                    // Stop only (current method)
                    orderPlaced = g_executor.PlaceStopOrder(
                        g_lastCandidate.direction, entry, 
                        sl, tp, lots, comment
                    );
                    
                } else if(InpEntryMethod == ENTRY_DUAL) {
                    // DUAL: Split lot
                    double lotLimit = NormalizeDouble(lots * 0.6, 2);  // 60%
                    double lotStop = NormalizeDouble(lots * 0.4, 2);   // 40%
                    
                    // Place both orders
                    bool limitOK = g_executor.PlaceLimitOrder(
                        g_lastCandidate.direction, g_lastCandidate,
                        sl, tp, lotLimit, comment + "_Limit"
                    );
                    
                    bool stopOK = g_executor.PlaceStopOrder(
                        g_lastCandidate.direction, entry,
                        sl, tp, lotStop, comment + "_Stop"
                    );
                    
                    orderPlaced = (limitOK || stopOK);
                }
                
                if(orderPlaced) {
                    g_totalTrades++;
                    g_lastOrderTime = currentBarTime;
                    // ... logging ...
                }
            }
        }
    }
    
    // ... continue with ManagePositions ...
}
```

---

### 📊 Comparison: Stop vs Limit Entry

| Aspect | STOP Order (Current) | LIMIT Order (Proposed) | DUAL (Hybrid) |
|--------|---------------------|------------------------|---------------|
| **Entry Location** | Above trigger | At POI (OB/FVG) | Both |
| **Risk** | 2-3 points | 0.5-1.0 point | 1.5-2 points |
| **RR** | 2.0-2.5 | 3.0-4.0 | 2.5-3.0 |
| **Fill Rate** | 95-100% | 60-70% | 80-85% |
| **Miss Runners** | 0% | 30-40% | 15-20% |
| **Avg Win** | Lower | Higher | Medium |
| **Complexity** | Simple | Medium | High |

---

### 💡 Example Comparison

```
Setup: BOS Bullish + Sweep 2648.50 + OB 2649.00-2649.50
Current Price: 2650.50
Trigger High: 2650.80

════════════════════════════════════════════════════════════════
METHOD 1: STOP ORDER (Current)
════════════════════════════════════════════════════════════════
Entry:  2651.50 (trigger + buffer)
SL:     2648.00 (sweep - buffer)
Risk:   3.50 points ($350 per 0.01 lot)

If TP = 2658.50:
Reward: 7.00 points
RR:     7.00 / 3.50 = 2.0

════════════════════════════════════════════════════════════════
METHOD 2: LIMIT ORDER (Proposed)
════════════════════════════════════════════════════════════════
Entry:  2649.00 (OB bottom)
SL:     2648.00 (sweep - buffer)
Risk:   1.00 point ($100 per 0.01 lot)

If TP = 2658.50:
Reward: 9.50 points
RR:     9.50 / 1.00 = 9.5 ⭐

════════════════════════════════════════════════════════════════
RISK COMPARISON
════════════════════════════════════════════════════════════════
Stop Method:  Risk $350 to make $700 (2:1)
Limit Method: Risk $100 to make $950 (9.5:1) ← 3.5× BETTER!

BUT: Price may NOT pull back to 2649.00
     → Miss trade if continues up immediately
     
════════════════════════════════════════════════════════════════
METHOD 3: DUAL (Best of both)
════════════════════════════════════════════════════════════════
Order 1: BUY LIMIT 0.06 lots @ 2649.00 (60%)
Order 2: BUY STOP  0.04 lots @ 2651.50 (40%)

Scenario A: Pulls back to 2649.00 then goes up
  → Both fill → 0.10 lots total
  → Avg entry: 2649.80
  → Better than pure STOP

Scenario B: Goes straight up without pullback
  → Only STOP fills (0.04 lots)
  → Catch at least partial move
  → Better than pure LIMIT (miss completely)
```

---

### 🎯 Recommended Settings by Style

#### Conservative (Max RR)
```cpp
InpEntryMethod = ENTRY_LIMIT_ONLY;
InpLimitOrderTTL = 32;  // Wait longer for pullback

Expected:
  Win Rate: 70-75% (higher quality fills)
  Trades: 3-4/day (miss some runners)
  Avg RR: 3.5-4.0
```

#### Balanced (Hybrid)
```cpp
InpEntryMethod = ENTRY_DUAL;
InpLimitOrderTTL = 24;

Expected:
  Win Rate: 68-70%
  Trades: 4-5/day
  Avg RR: 2.8-3.2
```

#### Aggressive (Catch All)
```cpp
InpEntryMethod = ENTRY_STOP_ONLY;  // Current behavior

Expected:
  Win Rate: 65%
  Trades: 5-6/day
  Avg RR: 2.0-2.5
```

---

### ⚠️ Risks & Mitigation

#### Risk 1: Miss Strong Runners
```
Problem: Price doesn't pull back to POI

Mitigation:
  → Use DUAL mode (partial fill guaranteed)
  → Set reasonable TTL (24-32 bars)
  → Accept trade-off: Better RR vs Lower fill rate
```

#### Risk 2: Limit Order Not Filled
```
Problem: Order expires before price reaches POI

Mitigation:
  → Longer TTL for limit orders (24+ bars vs 16 for stops)
  → Cancel and replace if setup still valid after TTL
  → Track "missed opportunities" in stats
```

#### Risk 3: Partial Fills in DUAL Mode
```
Problem: Only 1 of 2 orders fills

Mitigation:
  → Track as separate position (already handled by RiskManager)
  → Apply BE/Trail to whichever fills
  → Both use same SL/TP levels
```

---

### 🧪 Testing Plan

#### Phase 1: Backtest Comparison (3 months)
```
Test A: STOP only (baseline)
Test B: LIMIT only
Test C: DUAL mode

Metrics:
  - Win rate
  - Fill rate
  - Avg RR
  - Total profit
  - Max DD
  - Missed opportunities
```

#### Phase 2: Forward Test (Demo 2 weeks)
```
Run DUAL mode to validate:
  - Limit order fill behavior
  - Slippage on limit fills
  - System stability
  - Real-world RR improvement
```

---

### 📚 Related Documentation

- [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md#12-thêm-limit-order-entry-option) - Full implementation plan
- [03_ARBITER.md](03_ARBITER.md) - POI identification for limit entry
- [05_RISK_MANAGER.md](05_RISK_MANAGER.md) - Position tracking for dual orders

---

## 🎓 Đọc Tiếp

- [05_RISK_MANAGER.md](05_RISK_MANAGER.md) - Position management after fill
- [09_EXAMPLES.md](09_EXAMPLES.md) - Complete execution examples
- [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md) - Full improvement roadmap

