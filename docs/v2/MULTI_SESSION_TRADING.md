# Multi-Session Trading - Hướng Dẫn Chi Tiết

## 📍 Tổng Quan

Bot hỗ trợ **2 chế độ giao dịch theo thời gian**:
1. **FULL DAY MODE**: Giao dịch liên tục 7h→23h GMT+7
2. **MULTI-SESSION MODE**: Giao dịch trong 3 khung giờ cụ thể (có thể bật/tắt từng khung)

---

## 🎯 2 Trading Modes

### Mode 1: FULL DAY (Default)

**Mô tả**: Trade liên tục trong 1 khung giờ dài

```
Timeline GMT+7:
00:00 ════════════════════════════════ Closed
07:00 ────────────────────────────────┐
      │  TRADING (Continuous)          │
      │  - Scan signals                │
      │  - Place orders                │
      │  - Manage positions            │
23:00 ────────────────────────────────┘
00:00 ════════════════════════════════ Closed (next day)

Duration: 16 hours continuous
```

**Use Case**:
- Catch tất cả opportunities
- Không bỏ lỡ signals
- Simple setup
- Suitable cho: Conservative traders, full automation

---

### Mode 2: MULTI-SESSION

**Mô tả**: Trade chỉ trong các khung giờ "vàng" (high liquidity)

```
Timeline GMT+7:
00:00 ════════════════════════════════ Closed
07:00 ────────────────────────────────┐
      │ WINDOW 1: ASIA SESSION         │
11:00 ────────────────────────────────┘
      ⊘ Break (11:00-12:00)
12:00 ────────────────────────────────┐
      │ WINDOW 2: LONDON SESSION       │
16:00 ────────────────────────────────┘
      ⊘ Break (16:00-18:00)
18:00 ────────────────────────────────┐
      │ WINDOW 3: NY SESSION           │
23:00 ────────────────────────────────┘
00:00 ════════════════════════════════ Closed

Total Trading: 4h + 4h + 5h = 13 hours (vs 16h full day)
Breaks: 1h + 2h = 3 hours rest
```

**Use Case**:
- Focus vào high-liquidity sessions
- Tránh choppy periods (lunch, overlap gaps)
- Better win rate (trade quality > quantity)
- Suitable cho: Active traders, specific session preference

---

## ⚙️ Configuration Parameters

### Input Parameters (EA)

```cpp
//+------------------------------------------------------------------+
//| Session Management - Multi-Mode                                  |
//+------------------------------------------------------------------+
input group "═══════ Session Mode ═══════"

// Mode selection
enum TRADING_SESSION_MODE {
    SESSION_FULL_DAY = 0,      // 7h-23h continuous
    SESSION_MULTI_WINDOW = 1   // 3 separate windows
};

input TRADING_SESSION_MODE InpSessionMode = SESSION_FULL_DAY;

//+------------------------------------------------------------------+
//| Full Day Mode Settings                                           |
//+------------------------------------------------------------------+
input group "═══════ Full Day Mode ═══════"
input int  InpFullDayStart = 7;   // Start hour (GMT+7)
input int  InpFullDayEnd   = 23;  // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Multi-Session Mode Settings                                      |
//+------------------------------------------------------------------+
input group "═══════ Multi-Session Mode ═══════"

// Window 1: Asia Session (Morning)
input bool InpWindow1_Enable = true;   // Enable Window 1
input int  InpWindow1_Start  = 7;      // Start hour (GMT+7)
input int  InpWindow1_End    = 11;     // End hour (GMT+7)

// Window 2: London Session (Afternoon)
input bool InpWindow2_Enable = true;   // Enable Window 2
input int  InpWindow2_Start  = 12;     // Start hour (GMT+7)
input int  InpWindow2_End    = 16;     // End hour (GMT+7)

// Window 3: NY Session (Evening)
input bool InpWindow3_Enable = true;   // Enable Window 3
input int  InpWindow3_Start  = 18;     // Start hour (GMT+7)
input int  InpWindow3_End    = 23;     // End hour (GMT+7)
```

---

## 🔧 Implementation

### Update Executor Class

```cpp
class CExecutor {
private:
    // Existing
    int m_sessStartHour;
    int m_sessEndHour;
    
    // [NEW] Multi-session support
    TRADING_SESSION_MODE m_sessionMode;
    
    struct TradingWindow {
        bool enabled;
        int  startHour;
        int  endHour;
        string name;
    };
    TradingWindow m_windows[3];
    
public:
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              // Full day params
              int sessStart, int sessEnd,
              // Multi-session params
              TRADING_SESSION_MODE mode,
              bool w1Enable, int w1Start, int w1End,
              bool w2Enable, int w2Start, int w2End,
              bool w3Enable, int w3Start, int w3End,
              // ... other params ...
              ) {
        
        m_symbol = symbol;
        m_timeframe = tf;
        m_sessionMode = mode;
        
        // Full day settings
        m_sessStartHour = sessStart;
        m_sessEndHour = sessEnd;
        
        // Multi-session settings
        m_windows[0].enabled = w1Enable;
        m_windows[0].startHour = w1Start;
        m_windows[0].endHour = w1End;
        m_windows[0].name = "Asia";
        
        m_windows[1].enabled = w2Enable;
        m_windows[1].startHour = w2Start;
        m_windows[1].endHour = w2End;
        m_windows[1].name = "London";
        
        m_windows[2].enabled = w3Enable;
        m_windows[2].startHour = w3Start;
        m_windows[2].endHour = w3End;
        m_windows[2].name = "NY";
        
        // Log configuration
        Print("═══════════════════════════════════════");
        Print("📅 SESSION CONFIGURATION:");
        Print("   Mode: ", m_sessionMode == SESSION_FULL_DAY ? 
              "FULL DAY" : "MULTI-WINDOW");
        
        if(m_sessionMode == SESSION_FULL_DAY) {
            Print("   Hours: ", m_sessStartHour, ":00 - ", 
                  m_sessEndHour, ":00 GMT+7");
            Print("   Duration: ", m_sessEndHour - m_sessStartHour, " hours");
        } else {
            Print("   Windows:");
            for(int i = 0; i < 3; i++) {
                Print("   - ", m_windows[i].name, ": ", 
                      m_windows[i].enabled ? "✅ ON" : "⊘ OFF",
                      " (", m_windows[i].startHour, ":00-",
                      m_windows[i].endHour, ":00)");
            }
        }
        Print("═══════════════════════════════════════");
        
        return true;
    }
    
    // ═══════════════════════════════════════════════════════
    // UPDATED: SessionOpen() with Multi-Window Support
    // ═══════════════════════════════════════════════════════
    bool SessionOpen() {
        MqlDateTime s;
        TimeToStruct(TimeCurrent(), s);
        
        // Calculate VN time (GMT+7) using existing formula
        int server_gmt = (int)(TimeGMTOffset() / 3600);
        int vn_gmt = 7;
        int delta = vn_gmt - server_gmt;
        int hour_localvn = (s.hour + delta + 24) % 24;
        
        bool inSession = false;
        string sessionName = "CLOSED";
        
        // ═══════════════════════════════════════════════════
        // MODE 1: FULL DAY (Simple check)
        // ═══════════════════════════════════════════════════
        if(m_sessionMode == SESSION_FULL_DAY) {
            inSession = (hour_localvn >= m_sessStartHour && 
                        hour_localvn < m_sessEndHour);
            
            if(inSession) {
                sessionName = "FULL DAY";
            }
        }
        // ═══════════════════════════════════════════════════
        // MODE 2: MULTI-WINDOW (Check each window)
        // ═══════════════════════════════════════════════════
        else if(m_sessionMode == SESSION_MULTI_WINDOW) {
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
        
        // ═══════════════════════════════════════════════════
        // LOG (once per hour for verification)
        // ═══════════════════════════════════════════════════
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
    
    // ═══════════════════════════════════════════════════════
    // NEW: Get Current Active Window Name
    // ═══════════════════════════════════════════════════════
    string GetActiveWindow() {
        if(m_sessionMode == SESSION_FULL_DAY) {
            return "Full Day";
        }
        
        MqlDateTime s;
        TimeToStruct(TimeCurrent(), s);
        
        int server_gmt = (int)(TimeGMTOffset() / 3600);
        int vn_gmt = 7;
        int delta = vn_gmt - server_gmt;
        int hour_localvn = (s.hour + delta + 24) % 24;
        
        for(int i = 0; i < 3; i++) {
            if(!m_windows[i].enabled) continue;
            
            if(hour_localvn >= m_windows[i].startHour && 
               hour_localvn < m_windows[i].endHour) {
                return m_windows[i].name;
            }
        }
        
        return "Closed";
    }
    
    // ═══════════════════════════════════════════════════════
    // NEW: Get Next Window Info
    // ═══════════════════════════════════════════════════════
    string GetNextWindowInfo() {
        if(m_sessionMode == SESSION_FULL_DAY) {
            return "N/A";
        }
        
        MqlDateTime s;
        TimeToStruct(TimeCurrent(), s);
        
        int server_gmt = (int)(TimeGMTOffset() / 3600);
        int vn_gmt = 7;
        int delta = vn_gmt - server_gmt;
        int hour_localvn = (s.hour + delta + 24) % 24;
        
        // Find next enabled window
        for(int i = 0; i < 3; i++) {
            if(!m_windows[i].enabled) continue;
            
            if(hour_localvn < m_windows[i].startHour) {
                int hoursUntil = m_windows[i].startHour - hour_localvn;
                return StringFormat("%s opens in %d hour(s)", 
                                   m_windows[i].name, hoursUntil);
            }
        }
        
        // All windows passed for today
        if(m_windows[0].enabled) {
            return StringFormat("Next: %s at %02d:00 tomorrow", 
                               m_windows[0].name, 
                               m_windows[0].startHour);
        }
        
        return "No windows enabled";
    }
};
```

---

## 📊 Ví Dụ Chi Tiết

### Ví Dụ 1: Full Day Mode

**Config**:
```cpp
InpSessionMode = SESSION_FULL_DAY;
InpFullDayStart = 7;   // 07:00 GMT+7
InpFullDayEnd = 23;    // 23:00 GMT+7
```

**Timeline**:
```
GMT+7 Time      Status          Action
══════════════════════════════════════════════════════════
06:59           CLOSED          ⊘ No trading
07:00           IN SESSION ✅   ✓ Start scanning
08:00           IN SESSION ✅   ✓ Trading
12:00           IN SESSION ✅   ✓ Trading (no break)
16:00           IN SESSION ✅   ✓ Trading
20:00           IN SESSION ✅   ✓ Trading
22:59           IN SESSION ✅   ✓ Trading
23:00           CLOSED ❌       ⊘ Stop new entries
                                ✓ Still manage existing positions
```

**Log Output**:
```
🕐 Session Check | Server: 02:00 | VN Time: 07:00 | Mode: FULL DAY | Session: FULL DAY | Status: IN ✅
🕐 Session Check | Server: 08:00 | VN Time: 13:00 | Mode: FULL DAY | Session: FULL DAY | Status: IN ✅
🕐 Session Check | Server: 16:00 | VN Time: 23:00 | Mode: FULL DAY | Session: FULL DAY | Status: IN ✅
🕐 Session Check | Server: 17:00 | VN Time: 00:00 | Mode: FULL DAY | Session: CLOSED | Status: OUT ❌
```

---

### Ví Dụ 2: Multi-Session Mode (All Windows Enabled)

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

**Timeline**:
```
GMT+7 Time      Window          Status          Action
═══════════════════════════════════════════════════════════════
06:59           -               CLOSED          ⊘ No trading
──────────────────────────────────────────────────────────────
07:00           Asia            IN ✅           ✓ Scan & trade
08:00           Asia            IN ✅           ✓ Trading
09:00           Asia            IN ✅           ✓ Trading
10:00           Asia            IN ✅           ✓ Trading
10:59           Asia            IN ✅           ✓ Trading
──────────────────────────────────────────────────────────────
11:00           -               BREAK 🔴        ⊘ No new entries
11:30           -               BREAK 🔴        ✓ Manage positions only
──────────────────────────────────────────────────────────────
12:00           London          IN ✅           ✓ Scan & trade
13:00           London          IN ✅           ✓ Trading
14:00           London          IN ✅           ✓ Trading
15:00           London          IN ✅           ✓ Trading
15:59           London          IN ✅           ✓ Trading
──────────────────────────────────────────────────────────────
16:00           -               BREAK 🔴        ⊘ No new entries
16:30           -               BREAK 🔴        ✓ Manage positions only
17:00           -               BREAK 🔴        ✓ Manage positions only
17:30           -               BREAK 🔴        ✓ Manage positions only
──────────────────────────────────────────────────────────────
18:00           NY              IN ✅           ✓ Scan & trade
19:00           NY              IN ✅           ✓ Trading
20:00           NY              IN ✅           ✓ Trading
21:00           NY              IN ✅           ✓ Trading
22:00           NY              IN ✅           ✓ Trading
22:59           NY              IN ✅           ✓ Trading
──────────────────────────────────────────────────────────────
23:00           -               CLOSED ❌       ⊘ No new entries
00:00           -               CLOSED ❌       ✓ Manage positions only
```

**Log Output**:
```
🕐 Session Check | Server: 00:00 | VN Time: 07:00 | Mode: MULTI-WINDOW | Session: Asia | Status: IN ✅
🕐 Session Check | Server: 04:00 | VN Time: 11:00 | Mode: MULTI-WINDOW | Session: CLOSED | Status: OUT ❌
🕐 Session Check | Server: 05:00 | VN Time: 12:00 | Mode: MULTI-WINDOW | Session: London | Status: IN ✅
🕐 Session Check | Server: 09:00 | VN Time: 16:00 | Mode: MULTI-WINDOW | Session: CLOSED | Status: OUT ❌
🕐 Session Check | Server: 11:00 | VN Time: 18:00 | Mode: MULTI-WINDOW | Session: NY | Status: IN ✅
🕐 Session Check | Server: 16:00 | VN Time: 23:00 | Mode: MULTI-WINDOW | Session: CLOSED | Status: OUT ❌
```

---

### Ví Dụ 3: Selective Windows (Chỉ London + NY)

**Config**:
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;

InpWindow1_Enable = false;  // ⊘ Skip Asia session
InpWindow1_Start = 7;
InpWindow1_End = 11;

InpWindow2_Enable = true;   // ✓ London only
InpWindow2_Start = 12;
InpWindow2_End = 16;

InpWindow3_Enable = true;   // ✓ NY only
InpWindow3_Start = 18;
InpWindow3_End = 23;
```

**Timeline**:
```
GMT+7 Time      Status
════════════════════════════════════════
06:00-11:59     CLOSED ❌ (Window 1 disabled)
12:00-15:59     IN SESSION ✅ (London)
16:00-17:59     CLOSED ❌ (Break)
18:00-22:59     IN SESSION ✅ (NY)
23:00-06:59     CLOSED ❌
```

**Use Case**: Focus chỉ vào London + NY (high volatility), bỏ qua Asia morning.

---

## 🎯 Session Behavior Details

### Trong Session (IN)
```cpp
✅ Scan for signals (BOS, Sweep, OB, FVG)
✅ Build & score candidates
✅ Place new orders
✅ Manage existing positions (BE, Trail, DCA)
✅ Manage pending orders (TTL)
✅ Update dashboard
```

### Ngoài Session (BREAK/CLOSED)
```cpp
⊘ NO new signal detection
⊘ NO new candidates
⊘ NO new orders
✅ Still manage existing positions (critical!)
✅ Still manage pending orders
✅ Update dashboard (show status)
```

---

## 💡 Real-World Examples

### Scenario 1: Trade Placed in Window 1, Close in Window 2

```
Timeline:
──────────────────────────────────────────────────────
09:00 (Window 1: Asia)
  → Signal detected: BOS + Sweep + OB
  → Order placed: BUY @ 2650.00, SL 2648.00, TP 2654.00
  → Status: PENDING ORDER

09:30
  → Order FILLED @ 2650.00
  → Position OPEN (0.10 lots)
  → Profit: $0

11:00 (Window 1 ENDS - Enter BREAK)
  → SessionOpen() = FALSE ❌
  → Stop scanning signals
  → Position still OPEN
  → ManagePositions() still runs ✅

11:30 (BREAK Period)
  → Price: 2651.00 (profit +1.00 = +0.10R)
  → ManagePositions() continues
  → No BE yet (need +1R)

12:00 (Window 2: London STARTS)
  → SessionOpen() = TRUE ✅
  → Resume scanning
  → Position still being managed

14:00 (Window 2: London)
  → Price: 2660.00 (profit +10.00 = +1.0R)
  → ✅ BREAKEVEN triggered
  → SL moved to 2650.00
  → ✅ DCA #1 triggered (+0.75R earlier)

15:00
  → Price: 2665.00 (profit +15.00 = +1.5R)
  → ✅ DCA #2 triggered
  → ✅ Trailing SL active

16:00 (Window 2 ENDS - Enter BREAK)
  → Stop new entries
  → Position still managed

18:30 (Window 3: NY)
  → Price hits TP @ 2654.00
  → Position CLOSED ✅
  → Profit realized
──────────────────────────────────────────────────────
```

**Key Point**: Position được manage **LIÊN TỤC** kể cả trong BREAK periods!

---

### Scenario 2: Miss Entry During Break

```
Timeline:
──────────────────────────────────────────────────────
10:30 (Window 1: Asia)
  → BOS detected
  → Waiting for OB pullback

11:00 (Window 1 ENDS)
  → SessionOpen() = FALSE
  → Stop scanning

11:15 (BREAK)
  → Perfect OB pullback happens!
  → BUT: SessionOpen() = FALSE
  → ❌ SIGNAL MISSED (không place order)

12:00 (Window 2 STARTS)
  → SessionOpen() = TRUE
  → Price already moved away
  → Setup expired
──────────────────────────────────────────────────────
```

**Note**: Đây là trade-off của Multi-Session mode. Accept để tránh noise trong break periods.

---

## 📊 Comparison: Full Day vs Multi-Session

### Full Day Mode

**Pros**:
- ✅ Catch all opportunities (16h coverage)
- ✅ No missed signals
- ✅ Simple logic
- ✅ Maximum trades per day

**Cons**:
- ⚠️ May trade during low liquidity (lunch time)
- ⚠️ More noise/false signals
- ⚠️ Lower average win rate

**Best For**:
- Conservative traders (don't want to miss)
- Full automation
- Testing new strategies

---

### Multi-Session Mode

**Pros**:
- ✅ Trade only in high-liquidity periods
- ✅ Higher win rate (better quality)
- ✅ Avoid choppy/ranging periods
- ✅ Flexible (can disable windows)

**Cons**:
- ⚠️ Miss some opportunities (13h vs 16h)
- ⚠️ Signals during breaks ignored
- ⚠️ More complex configuration

**Best For**:
- Active traders (specific session preference)
- Quality over quantity approach
- Known market patterns (e.g., London best for XAUUSD)

---

## 🧪 Testing Recommendations

### Phase 1: Backtest Both Modes (3 months data)

```
Test A: FULL DAY MODE
  InpSessionMode = SESSION_FULL_DAY
  InpFullDayStart = 7
  InpFullDayEnd = 23

Metrics:
  - Total trades
  - Win rate
  - Profit factor
  - Trades per window (analyze which hours are best)

Test B: MULTI-SESSION (All enabled)
  InpSessionMode = SESSION_MULTI_WINDOW
  All 3 windows enabled

Metrics:
  - Total trades (expect -20-30% vs Full Day)
  - Win rate (expect +3-5%)
  - Profit per window
  
Test C: MULTI-SESSION (Selective)
  Only enable best 2 windows from Test A analysis
```

---

### Phase 2: Performance by Window

**Analyze Full Day backtest để tìm best windows**:

```
Example Results (hypothetical):
──────────────────────────────────────────────────────
Window          Trades    Win%    PF      Avg Win
──────────────────────────────────────────────────────
07:00-11:00     12        58%     1.8     $120
11:00-12:00     3         40%     0.9     $80  ← Worst
12:00-16:00     18        72%     2.4     $180 ← Best
16:00-18:00     5         50%     1.2     $90
18:00-23:00     15        68%     2.2     $150
──────────────────────────────────────────────────────

Decision:
  → Disable 11:00-12:00 (lunch, low quality)
  → Disable 16:00-18:00 (transition, choppy)
  → Keep: 07-11, 12-16, 18-23
```

---

## 🎛️ Preset Configurations

### Preset 1: Full Coverage (Default)
```cpp
InpSessionMode = SESSION_FULL_DAY;
InpFullDayStart = 7;
InpFullDayEnd = 23;

Expected:
  Trades/Day: 5-6
  Win Rate: 65%
  Coverage: Maximum
```

---

### Preset 2: High Quality Sessions
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;

// Window 1: Asia (Morning momentum)
InpWindow1_Enable = true;
InpWindow1_Start = 7;
InpWindow1_End = 11;

// Window 2: London (Best liquidity)
InpWindow2_Enable = true;
InpWindow2_Start = 12;
InpWindow2_End = 16;

// Window 3: NY (High volatility)
InpWindow3_Enable = true;
InpWindow3_Start = 18;
InpWindow3_End = 23;

Expected:
  Trades/Day: 4-5
  Win Rate: 68-70%
  Coverage: 13h (vs 16h)
```

---

### Preset 3: London + NY Only (Ultra Selective)
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;

InpWindow1_Enable = false;  // Skip Asia

InpWindow2_Enable = true;   // London only
InpWindow2_Start = 12;
InpWindow2_End = 16;

InpWindow3_Enable = true;   // NY only
InpWindow3_Start = 18;
InpWindow3_End = 23;

Expected:
  Trades/Day: 3-4
  Win Rate: 70-72%
  Coverage: 9h (focused)
```

---

### Preset 4: Custom - London Focus
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;

InpWindow1_Enable = false;  // Skip Asia

InpWindow2_Enable = true;   // Extended London
InpWindow2_Start = 11;      // Pre-London
InpWindow2_End = 17;        // Post-London

InpWindow3_Enable = false;  // Skip NY

Expected:
  Trades/Day: 2-3
  Win Rate: 72-75%
  Coverage: 6h (highly focused)
```

---

## 🔍 Dashboard Display

### Full Day Mode
```
═══════════════════════════════════════
Session Mode: FULL DAY
Active: YES ✅
Window: Full Day (7-23h GMT+7)
Current Time: 14:30 GMT+7
Status: IN SESSION
═══════════════════════════════════════
```

### Multi-Session Mode
```
═══════════════════════════════════════
Session Mode: MULTI-WINDOW
Active Window: London ✅
Time: 14:30 GMT+7
Windows:
  Asia (7-11):    CLOSED
  London (12-16): ACTIVE ✅ (30 min left)
  NY (18-23):     Opens in 3h30m
═══════════════════════════════════════
```

### During Break
```
═══════════════════════════════════════
Session Mode: MULTI-WINDOW
Active Window: BREAK 🔴
Time: 17:15 GMT+7
Status: Managing positions only
Next: NY opens in 45 minutes
Positions: 2 open
═══════════════════════════════════════
```

---

## ⚙️ Code Updates Required

### File 1: `executor.mqh`

```cpp
// Add to class definition
private:
    TRADING_SESSION_MODE m_sessionMode;
    struct TradingWindow {
        bool enabled;
        int startHour;
        int endHour;
        string name;
    };
    TradingWindow m_windows[3];

public:
    // Update Init signature
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              int fullDayStart, int fullDayEnd,
              TRADING_SESSION_MODE mode,
              bool w1Enable, int w1Start, int w1End,
              bool w2Enable, int w2Start, int w2End,
              bool w3Enable, int w3Start, int w3End,
              ...);
    
    // Updated SessionOpen()
    bool SessionOpen();
    
    // New helper functions
    string GetActiveWindow();
    string GetNextWindowInfo();
```

---

### File 2: `SMC_ICT_EA.mq5`

```cpp
//+------------------------------------------------------------------+
//| Input Parameters - Session Mode                                  |
//+------------------------------------------------------------------+
input group "═══════ Session Mode ═══════"
enum TRADING_SESSION_MODE {
    SESSION_FULL_DAY = 0,
    SESSION_MULTI_WINDOW = 1
};
input TRADING_SESSION_MODE InpSessionMode = SESSION_FULL_DAY;

//+------------------------------------------------------------------+
//| Full Day Settings                                                |
//+------------------------------------------------------------------+
input group "═══════ Full Day Mode ═══════"
input int InpFullDayStart = 7;    // Start hour (GMT+7)
input int InpFullDayEnd   = 23;   // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Multi-Session Settings                                           |
//+------------------------------------------------------------------+
input group "═══════ Window 1: Asia Session ═══════"
input bool InpWindow1_Enable = true;
input int  InpWindow1_Start  = 7;
input int  InpWindow1_End    = 11;

input group "═══════ Window 2: London Session ═══════"
input bool InpWindow2_Enable = true;
input int  InpWindow2_Start  = 12;
input int  InpWindow2_End    = 16;

input group "═══════ Window 3: NY Session ═══════"
input bool InpWindow3_Enable = true;
input int  InpWindow3_Start  = 18;
input int  InpWindow3_End    = 23;

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit() {
    // ... existing code ...
    
    g_executor = new CExecutor();
    if(!g_executor.Init(_Symbol, _Period,
                        InpFullDayStart, InpFullDayEnd,
                        InpSessionMode,
                        InpWindow1_Enable, InpWindow1_Start, InpWindow1_End,
                        InpWindow2_Enable, InpWindow2_Start, InpWindow2_End,
                        InpWindow3_Enable, InpWindow3_Start, InpWindow3_End,
                        // ... other params ...
                        )) {
        Print("ERROR: Failed to initialize executor");
        return INIT_FAILED;
    }
    
    // ... rest of init ...
}
```

---

## 📊 Expected Performance Impact

### Backtest Results (Hypothetical - Need Real Data)

| Mode | Config | Trades/Day | Win% | PF | Avg Win | Max DD |
|------|--------|-----------|------|----|---------| -------|
| **Full Day** | 7-23h | 5.2 | 65% | 2.0 | $165 | -8% |
| **Multi-Session** | All 3 windows | 4.1 | 68% | 2.2 | $180 | -7% |
| **London+NY** | Win 2+3 only | 3.2 | 71% | 2.4 | $195 | -6% |
| **London Only** | Win 2 only | 1.8 | 74% | 2.6 | $210 | -5% |

**Insights**:
- Fewer trades = Higher win rate (quality > quantity)
- London session appears strongest
- Multi-session reduces drawdown
- Trade-off: Opportunity cost vs Quality

---

## ⚠️ Lưu Ý Quan Trọng

### 1. Position Management Luôn Chạy

```cpp
void OnTick() {
    if(!g_executor.SessionOpen()) {
        // ✅ CRITICAL: Still manage positions!
        g_riskMgr.ManageOpenPositions();
        g_executor.ManagePendingOrders();
        return;  // Skip new entries only
    }
    
    // ... normal trading flow ...
}
```

**Tại sao?**
- Position có thể mở trong Window 1, đóng trong Window 3
- BE/Trail/DCA cần chạy liên tục
- Pending orders cần check TTL

---

### 2. Window Validation

```cpp
// Bot sẽ validate config trong OnInit()
bool ValidateWindows() {
    for(int i = 0; i < 3; i++) {
        if(!m_windows[i].enabled) continue;
        
        // Check valid hours
        if(m_windows[i].startHour < 0 || m_windows[i].startHour > 23) {
            Print("❌ Window ", i+1, " invalid start hour: ", 
                  m_windows[i].startHour);
            return false;
        }
        
        if(m_windows[i].endHour < 0 || m_windows[i].endHour > 24) {
            Print("❌ Window ", i+1, " invalid end hour: ", 
                  m_windows[i].endHour);
            return false;
        }
        
        // Check start < end
        if(m_windows[i].startHour >= m_windows[i].endHour) {
            Print("❌ Window ", i+1, " start >= end: ",
                  m_windows[i].startHour, " >= ", m_windows[i].endHour);
            return false;
        }
    }
    
    // Check overlaps
    for(int i = 0; i < 3; i++) {
        if(!m_windows[i].enabled) continue;
        
        for(int j = i+1; j < 3; j++) {
            if(!m_windows[j].enabled) continue;
            
            // Check if windows overlap
            if(!(m_windows[i].endHour <= m_windows[j].startHour ||
                 m_windows[j].endHour <= m_windows[i].startHour)) {
                Print("⚠️ Warning: Window ", i+1, " and ", j+1, " overlap");
                Print("   Window ", i+1, ": ", m_windows[i].startHour, 
                      "-", m_windows[i].endHour);
                Print("   Window ", j+1, ": ", m_windows[j].startHour,
                      "-", m_windows[j].endHour);
            }
        }
    }
    
    return true;
}
```

---

### 3. Dashboard Enhancement

```cpp
// Update dashboard to show session info
void UpdateDashboard(...) {
    string sessionInfo = "";
    
    if(InpSessionMode == SESSION_FULL_DAY) {
        sessionInfo = StringFormat("Full Day (%d-%d)", 
                                  InpFullDayStart, InpFullDayEnd);
    } else {
        string activeWindow = g_executor.GetActiveWindow();
        string nextWindow = g_executor.GetNextWindowInfo();
        
        sessionInfo = StringFormat("Mode: Multi | Active: %s\nNext: %s",
                                  activeWindow, nextWindow);
    }
    
    // Display on chart
    // ... existing dashboard code ...
}
```

---

## 🎓 Best Practices

### 1. Start with Full Day
```
Week 1-2: Test FULL DAY mode
  → Collect data on which hours perform best
  → Analyze win rate by hour
  → Identify low-quality periods
```

### 2. Analyze Performance by Hour
```
Use Stats Manager to track:
  - Trades per hour
  - Win rate per hour  
  - Avg profit per hour
  → Identify optimal windows
```

### 3. Switch to Multi-Session Based on Data
```
If data shows:
  - Hours 11-12: Low win rate (50%)
  - Hours 16-18: Choppy, many false signals
  
→ Switch to Multi-Session:
  Enable: 7-11, 12-16, 18-23
  Skip: 11-12, 16-18
```

### 4. Seasonal Adjustment
```
Summer (Low volatility):
  → Use FULL DAY (catch all opportunities)

Winter (High volatility):
  → Use MULTI-SESSION (focus on quality)
```

---

## 📋 Configuration Templates

### Template 1: Conservative (Max Coverage)
```ini
InpSessionMode = SESSION_FULL_DAY
InpFullDayStart = 7
InpFullDayEnd = 23
```

### Template 2: Balanced (3 Windows)
```ini
InpSessionMode = SESSION_MULTI_WINDOW
InpWindow1_Enable = true   # Asia 7-11
InpWindow2_Enable = true   # London 12-16
InpWindow3_Enable = true   # NY 18-23
```

### Template 3: Quality Focus (London+NY)
```ini
InpSessionMode = SESSION_MULTI_WINDOW
InpWindow1_Enable = false  # Skip Asia
InpWindow2_Enable = true   # London 12-16
InpWindow3_Enable = true   # NY 18-23
```

### Template 4: Custom Testing
```ini
InpSessionMode = SESSION_MULTI_WINDOW
InpWindow1_Enable = true
InpWindow1_Start = 8       # Custom start
InpWindow1_End = 10        # Custom end
InpWindow2_Enable = false
InpWindow3_Enable = false
# Test single window performance
```

---

## 🔗 File Liên Quan

- `Include/executor.mqh` - SessionOpen() implementation
- `Experts/SMC_ICT_EA.mq5` - Input parameters
- [TIMEZONE_CONVERSION.md](TIMEZONE_CONVERSION.md) - Timezone logic
- [04_EXECUTOR.md](04_EXECUTOR.md) - Executor details
- [07_CONFIGURATION.md](07_CONFIGURATION.md) - Parameter guide

---

**Version**: v1.2+ (Multi-Session Support)  
**Date**: October 2025  
**Status**: Documentation Complete ✅



