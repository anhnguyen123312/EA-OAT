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

### ⚙️ Cơ Chế

```cpp
bool SessionOpen() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s); // Server time
    
    // Calculate timezone offset
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    bool inSession = (hour_localvn >= SessStartHour && 
                      hour_localvn < SessEndHour);
    
    // Log once per hour
    static int lastLogHour = -1;
    if(s.hour != lastLogHour) {
        Print("Session Check | Server: ", s.hour, ":00 | VN: ", 
              hour_localvn, ":00 | Status: ", 
              inSession ? "IN SESSION ✅" : "CLOSED ❌");
        lastLogHour = s.hour;
    }
    
    return inSession;
}
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

## 🎓 Đọc Tiếp

- [05_RISK_MANAGER.md](05_RISK_MANAGER.md) - Position management after fill
- [09_EXAMPLES.md](09_EXAMPLES.md) - Complete execution examples

