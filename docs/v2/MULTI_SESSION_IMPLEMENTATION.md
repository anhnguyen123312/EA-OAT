# Multi-Session Trading - Implementation Guide

## 📍 Overview

Hướng dẫn chi tiết **từng bước** để implement Multi-Session Trading feature vào bot.

**Related**: [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md) - User guide

---

## 🎯 Implementation Checklist

### Phase 1: Core Structure (30 min)
- [ ] Update `executor.mqh` - Add enum & struct
- [ ] Update `executor.mqh` - Add member variables
- [ ] Update `executor.mqh` - Update Init() signature

### Phase 2: Logic Implementation (1 hour)
- [ ] Update `executor.mqh` - Rewrite SessionOpen()
- [ ] Update `executor.mqh` - Add GetActiveWindow()
- [ ] Update `executor.mqh` - Add GetNextWindowInfo()
- [ ] Update `executor.mqh` - Add ValidateWindows()

### Phase 3: EA Integration (30 min)
- [ ] Update `SMC_ICT_EA.mq5` - Add input parameters
- [ ] Update `SMC_ICT_EA.mq5` - Update OnInit()
- [ ] Update `SMC_ICT_EA.mq5` - Update dashboard

### Phase 4: Testing (2 hours)
- [ ] Compile & fix errors
- [ ] Visual test on chart
- [ ] Test Full Day mode
- [ ] Test Multi-Window mode
- [ ] Test selective windows
- [ ] Verify timezone conversion
- [ ] Backtest comparison

**Total Time**: ~4 hours

---

## 📝 Step-by-Step Implementation

### STEP 1: Update `executor.mqh` - Add Enum & Struct

**Location**: Lines 8-10 (after #property)

```cpp
//+------------------------------------------------------------------+
//|                                                     executor.mqh |
//|                              Trade Execution & Session Management|
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property version   "1.00"
#property strict

#include "arbiter.mqh"

// ═══════════════════════════════════════════════════════════════════
// [NEW] Session Mode Enumerations
// ═══════════════════════════════════════════════════════════════════
enum TRADING_SESSION_MODE {
    SESSION_FULL_DAY = 0,      // Continuous trading
    SESSION_MULTI_WINDOW = 1   // Multiple windows with breaks
};

// ═══════════════════════════════════════════════════════════════════
// [NEW] Trading Window Structure
// ═══════════════════════════════════════════════════════════════════
struct TradingWindow {
    bool   enabled;      // Window enabled?
    int    startHour;    // Start hour (GMT+7)
    int    endHour;      // End hour (GMT+7)
    string name;         // Window name (e.g., "Asia", "London", "NY")
};

//+------------------------------------------------------------------+
//| Executor Class - Entry execution and session management         |
//+------------------------------------------------------------------+
class CExecutor {
```

---

### STEP 2: Update `executor.mqh` - Add Member Variables

**Location**: Lines 16-31 (in private section of CExecutor class)

```cpp
class CExecutor {
private:
    string   m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
    // ═══════════════════════════════════════════════════════════
    // Session parameters (UPDATED)
    // ═══════════════════════════════════════════════════════════
    
    // [EXISTING] Full day mode
    int      m_sessStartHour;
    int      m_sessEndHour;
    
    // [NEW] Session mode
    TRADING_SESSION_MODE m_sessionMode;
    
    // [NEW] Multi-window mode
    TradingWindow m_windows[3];  // Array of 3 windows
    
    // [EXISTING] Other parameters
    int      m_spreadMaxPts;
    double   m_spreadATRpct;
    int      m_timezoneOffset;
    // ... rest of existing variables ...
```

---

### STEP 3: Update `executor.mqh` - Update Init() Signature

**Location**: Lines 54-57 (public section, Init declaration)

```cpp
public:
    CExecutor();
    ~CExecutor();
    
    // ═══════════════════════════════════════════════════════════
    // [UPDATED] Init with multi-session support
    // ═══════════════════════════════════════════════════════════
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              // Full day parameters
              int fullDayStart, int fullDayEnd,
              // Session mode
              TRADING_SESSION_MODE sessionMode,
              // Window 1 parameters
              bool w1Enable, int w1Start, int w1End,
              // Window 2 parameters
              bool w2Enable, int w2Start, int w2End,
              // Window 3 parameters
              bool w3Enable, int w3Start, int w3End,
              // Other parameters (existing)
              int spreadMax, double spreadATRpct,
              int triggerBody, int entryBuffer, int minStop, int orderTTL, double minRR,
              bool useFixedSL, int fixedSL_Pips, bool fixedTP_Enable, int fixedTP_Pips);
    
    bool SessionOpen();
    bool SpreadOK();
    bool IsRolloverTime();
    
    // [NEW] Session info getters
    string GetActiveWindow();
    string GetNextWindowInfo();
    int    GetCurrentSessionType();  // 0=closed, 1=Asia, 2=London, 3=NY
```

---

### STEP 4: Update `executor.mqh` - Rewrite Init() Implementation

**Location**: Lines 100-130 (Init function body)

```cpp
//+------------------------------------------------------------------+
//| Initialize executor parameters                                   |
//+------------------------------------------------------------------+
bool CExecutor::Init(string symbol, ENUM_TIMEFRAMES tf,
                     int fullDayStart, int fullDayEnd,
                     TRADING_SESSION_MODE sessionMode,
                     bool w1Enable, int w1Start, int w1End,
                     bool w2Enable, int w2Start, int w2End,
                     bool w3Enable, int w3Start, int w3End,
                     int spreadMax, double spreadATRpct,
                     int triggerBody, int entryBuffer, int minStop, int orderTTL, double minRR,
                     bool useFixedSL, int fixedSL_Pips, bool fixedTP_Enable, int fixedTP_Pips) {
    
    m_symbol = symbol;
    m_timeframe = tf;
    
    // ═══════════════════════════════════════════════════════════
    // Session Configuration
    // ═══════════════════════════════════════════════════════════
    m_sessionMode = sessionMode;
    
    // Full day settings
    m_sessStartHour = fullDayStart;
    m_sessEndHour = fullDayEnd;
    
    // Multi-window settings
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
    
    // ═══════════════════════════════════════════════════════════
    // Validate Configuration
    // ═══════════════════════════════════════════════════════════
    if(!ValidateWindows()) {
        Print("❌ Invalid window configuration");
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════
    // Log Configuration
    // ═══════════════════════════════════════════════════════════
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
    
    // ═══════════════════════════════════════════════════════════
    // Other Parameters (EXISTING CODE)
    // ═══════════════════════════════════════════════════════════
    m_spreadMaxPts = spreadMax;
    m_spreadATRpct = spreadATRpct;
    m_triggerBodyATR = triggerBody;
    m_entryBufferPts = entryBuffer;
    m_minStopPts = minStop;
    m_orderTTL_Bars = orderTTL;
    m_minRR = minRR;
    
    m_useFixedSL = useFixedSL;
    m_fixedSL_Pips = fixedSL_Pips;
    m_fixedTP_Enable = fixedTP_Enable;
    m_fixedTP_Pips = fixedTP_Pips;
    
    // Create ATR handle
    m_atrHandle = iATR(m_symbol, m_timeframe, 14);
    if(m_atrHandle == INVALID_HANDLE) {
        Print("Executor: Failed to create ATR indicator handle");
        return false;
    }
    
    return true;
}
```

---

### STEP 5: Update `executor.mqh` - Rewrite SessionOpen()

**Location**: Lines 135-157 (replace entire SessionOpen function)

```cpp
//+------------------------------------------------------------------+
//| Check if current time is within trading session                  |
//| Supports both FULL DAY and MULTI-WINDOW modes                   |
//+------------------------------------------------------------------+
bool CExecutor::SessionOpen() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s); // Server time
    
    // ═══════════════════════════════════════════════════════════
    // Calculate VN time (GMT+7) using timezone conversion
    // ═══════════════════════════════════════════════════════════
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    bool inSession = false;
    string sessionName = "CLOSED";
    
    // ═══════════════════════════════════════════════════════════
    // MODE 1: FULL DAY - Simple range check
    // ═══════════════════════════════════════════════════════════
    if(m_sessionMode == SESSION_FULL_DAY) {
        inSession = (hour_localvn >= m_sessStartHour && 
                    hour_localvn < m_sessEndHour);
        
        if(inSession) {
            sessionName = "FULL DAY";
        }
    }
    // ═══════════════════════════════════════════════════════════
    // MODE 2: MULTI-WINDOW - Check each window
    // ═══════════════════════════════════════════════════════════
    else if(m_sessionMode == SESSION_MULTI_WINDOW) {
        for(int i = 0; i < 3; i++) {
            // Skip disabled windows
            if(!m_windows[i].enabled) continue;
            
            // Check if current hour is in this window
            if(hour_localvn >= m_windows[i].startHour &&
               hour_localvn < m_windows[i].endHour) {
                inSession = true;
                sessionName = m_windows[i].name;
                break;  // Found active window, stop checking
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════
    // LOG (once per hour for verification)
    // ═══════════════════════════════════════════════════════════
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

---

### STEP 6: Add New Helper Functions to `executor.mqh`

**Location**: After SessionOpen() function

```cpp
//+------------------------------------------------------------------+
//| Get name of currently active window                              |
//+------------------------------------------------------------------+
string CExecutor::GetActiveWindow() {
    if(m_sessionMode == SESSION_FULL_DAY) {
        return "Full Day";
    }
    
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s);
    
    // Calculate VN time
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    // Check which window is active
    for(int i = 0; i < 3; i++) {
        if(!m_windows[i].enabled) continue;
        
        if(hour_localvn >= m_windows[i].startHour &&
           hour_localvn < m_windows[i].endHour) {
            return m_windows[i].name;
        }
    }
    
    return "Break/Closed";
}

//+------------------------------------------------------------------+
//| Get info about next trading window                               |
//+------------------------------------------------------------------+
string CExecutor::GetNextWindowInfo() {
    if(m_sessionMode == SESSION_FULL_DAY) {
        return "N/A (Full Day Mode)";
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
        
        // Check if this window is in future today
        if(hour_localvn < m_windows[i].startHour) {
            int hoursUntil = m_windows[i].startHour - hour_localvn;
            return StringFormat("%s opens in %dh", 
                               m_windows[i].name, hoursUntil);
        }
    }
    
    // All windows passed for today, show tomorrow's first window
    for(int i = 0; i < 3; i++) {
        if(m_windows[i].enabled) {
            return StringFormat("Next: %s at %02d:00 tomorrow", 
                               m_windows[i].name, 
                               m_windows[i].startHour);
        }
    }
    
    return "No windows enabled";
}

//+------------------------------------------------------------------+
//| Get current session type (for statistics)                        |
//+------------------------------------------------------------------+
int CExecutor::GetCurrentSessionType() {
    if(m_sessionMode == SESSION_FULL_DAY) {
        return 0;  // Full day = type 0
    }
    
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s);
    
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    // Check which window
    for(int i = 0; i < 3; i++) {
        if(!m_windows[i].enabled) continue;
        
        if(hour_localvn >= m_windows[i].startHour &&
           hour_localvn < m_windows[i].endHour) {
            return i + 1;  // 1=Asia, 2=London, 3=NY
        }
    }
    
    return -1;  // Not in any window
}

//+------------------------------------------------------------------+
//| Validate window configuration (prevent errors)                   |
//+------------------------------------------------------------------+
bool CExecutor::ValidateWindows() {
    // If Full Day mode, no need to validate windows
    if(m_sessionMode == SESSION_FULL_DAY) {
        // Just check full day hours
        if(m_sessStartHour < 0 || m_sessStartHour > 23) {
            Print("❌ Invalid full day start hour: ", m_sessStartHour);
            return false;
        }
        if(m_sessEndHour < 0 || m_sessEndHour > 24) {
            Print("❌ Invalid full day end hour: ", m_sessEndHour);
            return false;
        }
        if(m_sessStartHour >= m_sessEndHour) {
            Print("❌ Full day start >= end");
            return false;
        }
        return true;
    }
    
    // ═══════════════════════════════════════════════════════════
    // Multi-Window Mode Validation
    // ═══════════════════════════════════════════════════════════
    
    // Check if at least 1 window is enabled
    bool hasEnabledWindow = false;
    for(int i = 0; i < 3; i++) {
        if(m_windows[i].enabled) {
            hasEnabledWindow = true;
            break;
        }
    }
    
    if(!hasEnabledWindow) {
        Print("⚠️ WARNING: No windows enabled in MULTI-WINDOW mode!");
        Print("   Bot will not trade. Enable at least 1 window.");
        return false;
    }
    
    // Validate each enabled window
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
    
    // ═══════════════════════════════════════════════════════════
    // Check for overlaps (WARNING only, not error)
    // ═══════════════════════════════════════════════════════════
    for(int i = 0; i < 3; i++) {
        if(!m_windows[i].enabled) continue;
        
        for(int j = i+1; j < 3; j++) {
            if(!m_windows[j].enabled) continue;
            
            // Check overlap: windows should NOT overlap
            if(!(m_windows[i].endHour <= m_windows[j].startHour ||
                 m_windows[j].endHour <= m_windows[i].startHour)) {
                
                Print("⚠️ WARNING: Window ", i+1, " and ", j+1, " overlap!");
                Print("   Window ", i+1, " (", m_windows[i].name, "): ", 
                      m_windows[i].startHour, "-", m_windows[i].endHour);
                Print("   Window ", j+1, " (", m_windows[j].name, "): ",
                      m_windows[j].startHour, "-", m_windows[j].endHour);
                Print("   This may cause unexpected behavior");
            }
        }
    }
    
    return true;
}
```

---

### STEP 7: Update `SMC_ICT_EA.mq5` - Add Input Parameters

**Location**: Lines 26-32 (after Unit Convention, replace Session & Market section)

```cpp
//+------------------------------------------------------------------+
//| Input Parameters - Session Mode                                  |
//+------------------------------------------------------------------+
input group "═══════ Session Mode ═══════"
enum TRADING_SESSION_MODE {
    SESSION_FULL_DAY = 0,      // Continuous 7-23h
    SESSION_MULTI_WINDOW = 1   // 3 separate windows
};
input TRADING_SESSION_MODE InpSessionMode = SESSION_FULL_DAY;

//+------------------------------------------------------------------+
//| Full Day Mode Settings                                           |
//+------------------------------------------------------------------+
input group "═══════ Full Day Mode ═══════"
input int InpFullDayStart = 7;    // Start hour (GMT+7)
input int InpFullDayEnd   = 23;   // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Multi-Session Mode - Window 1 (Asia)                             |
//+------------------------------------------------------------------+
input group "═══════ Window 1: Asia (7-11h) ═══════"
input bool InpWindow1_Enable = true;   // Enable Window 1
input int  InpWindow1_Start  = 7;      // Start hour (GMT+7)
input int  InpWindow1_End    = 11;     // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Multi-Session Mode - Window 2 (London)                           |
//+------------------------------------------------------------------+
input group "═══════ Window 2: London (12-16h) ═══════"
input bool InpWindow2_Enable = true;   // Enable Window 2
input int  InpWindow2_Start  = 12;     // Start hour (GMT+7)
input int  InpWindow2_End    = 16;     // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Multi-Session Mode - Window 3 (NY)                               |
//+------------------------------------------------------------------+
input group "═══════ Window 3: NY (18-23h) ═══════"
input bool InpWindow3_Enable = true;   // Enable Window 3
input int  InpWindow3_Start  = 18;     // Start hour (GMT+7)
input int  InpWindow3_End    = 23;     // End hour (GMT+7)

//+------------------------------------------------------------------+
//| Market Filters                                                   |
//+------------------------------------------------------------------+
input group "═══════ Market Filters ═══════"
input int    InpSpreadMaxPts  = 500;   // Max spread (points)
input double InpSpreadATRpct  = 0.08;  // Spread ATR% guard
```

---

### STEP 8: Update `SMC_ICT_EA.mq5` - Update OnInit()

**Location**: Lines 270-278 (executor initialization)

```cpp
int OnInit() {
    // ... existing code ...
    
    // ═══════════════════════════════════════════════════════════
    // Initialize Executor (UPDATED signature)
    // ═══════════════════════════════════════════════════════════
    g_executor = new CExecutor();
    if(!g_executor.Init(_Symbol, _Period,
                        // Full day parameters
                        InpFullDayStart, InpFullDayEnd,
                        // Session mode
                        InpSessionMode,
                        // Window 1
                        InpWindow1_Enable, InpWindow1_Start, InpWindow1_End,
                        // Window 2
                        InpWindow2_Enable, InpWindow2_Start, InpWindow2_End,
                        // Window 3
                        InpWindow3_Enable, InpWindow3_Start, InpWindow3_End,
                        // Other parameters (EXISTING)
                        InpSpreadMaxPts, InpSpreadATRpct,
                        InpTriggerBodyATR, InpEntryBufferPts, InpMinStopPts, 
                        InpOrder_TTL_Bars, InpMinRR,
                        InpUseFixedSL, InpFixedSL_Pips, 
                        InpFixedTP_Enable, InpFixedTP_Pips)) {
        Print("ERROR: Failed to initialize executor");
        return INIT_FAILED;
    }
    
    // ... rest of init code ...
}
```

---

### STEP 9: Update Dashboard Display (Optional)

**Location**: `draw_debug.mqh` (if you want to show session info on chart)

```cpp
void UpdateDashboard(...) {
    // ... existing dashboard code ...
    
    // [NEW] Show session mode info
    string sessionInfo = "";
    
    if(InpSessionMode == SESSION_FULL_DAY) {
        sessionInfo = StringFormat("Session: Full Day (%d-%dh)", 
                                  InpFullDayStart, InpFullDayEnd);
    } else {
        string activeWindow = g_executor.GetActiveWindow();
        string nextWindow = g_executor.GetNextWindowInfo();
        
        sessionInfo = StringFormat("Session: %s\nNext: %s",
                                  activeWindow, nextWindow);
    }
    
    // Display on chart
    ObjectSetString(0, "DashboardSession", OBJPROP_TEXT, sessionInfo);
    // ... existing code ...
}
```

---

## 🧪 Testing Procedure

### Test 1: Compilation
```
1. Save all files
2. Compile executor.mqh
3. Compile SMC_ICT_EA.mq5
4. Check for errors
```

### Test 2: Full Day Mode (Baseline)
```
1. Set InpSessionMode = SESSION_FULL_DAY
2. InpFullDayStart = 7
3. InpFullDayEnd = 23
4. Attach to chart
5. Check log: Should show "Mode: FULL DAY"
6. Verify: SessionOpen() returns TRUE during 7-23h GMT+7
```

### Test 3: Multi-Window Mode (All Enabled)
```
1. Set InpSessionMode = SESSION_MULTI_WINDOW
2. Enable all 3 windows (default settings)
3. Attach to chart
4. Check log: Should show "Mode: MULTI-WINDOW"
5. Verify: SessionOpen() returns TRUE only in windows
6. Check 11:00, 16:00: Should show "OUT ❌"
```

### Test 4: Selective Windows
```
1. InpSessionMode = SESSION_MULTI_WINDOW
2. InpWindow1_Enable = false  // Disable Asia
3. InpWindow2_Enable = true   // London only
4. InpWindow3_Enable = true   // NY only
5. Verify: No trading 7-11h
6. Verify: Trading 12-16h, 18-23h only
```

### Test 5: Timezone Conversion
```
Test với các brokers khác nhau:
1. GMT+0: Verify conversion
2. GMT+2: Verify conversion
3. GMT+3: Verify conversion

Check log hourly để confirm VN time đúng
```

### Test 6: Position Management During Breaks
```
1. Use MULTI-WINDOW mode
2. Place trade at 10:00 (Window 1)
3. Wait until 11:00 (Break period)
4. Verify:
   - SessionOpen() = FALSE
   - ManageOpenPositions() still runs
   - Position still tracked
   - BE/Trail/DCA still work
5. Wait until 12:00 (Window 2)
6. Verify: Trading resumes
```

---

## 🐛 Common Issues & Solutions

### Issue 1: "No windows enabled" Error

**Cause**: All windows disabled in MULTI-WINDOW mode

**Solution**:
```cpp
// Check in OnInit()
if(InpSessionMode == SESSION_MULTI_WINDOW) {
    if(!InpWindow1_Enable && !InpWindow2_Enable && !InpWindow3_Enable) {
        Print("❌ ERROR: No windows enabled!");
        Print("   Enable at least 1 window or switch to FULL DAY mode");
        return INIT_FAILED;
    }
}
```

---

### Issue 2: Bot Không Trade

**Debugging**:
```cpp
// Add debug logs
Print("Session Mode: ", InpSessionMode);
Print("Current VN Hour: ", hour_localvn);
Print("SessionOpen(): ", SessionOpen() ? "TRUE" : "FALSE");

if(InpSessionMode == SESSION_MULTI_WINDOW) {
    for(int i = 0; i < 3; i++) {
        Print("Window ", i+1, " (", m_windows[i].name, "): ",
              m_windows[i].enabled ? "ON" : "OFF",
              " Range: ", m_windows[i].startHour, "-", m_windows[i].endHour,
              " Current in range: ", 
              (hour_localvn >= m_windows[i].startHour && 
               hour_localvn < m_windows[i].endHour) ? "YES" : "NO");
    }
}
```

---

### Issue 3: Windows Overlap Warning

**Example**:
```
Window 1: 7-12 (overlaps với Window 2: 11-16)
→ Hour 11: Thuộc cả 2 windows!
```

**Solution**: Adjust windows để không overlap
```cpp
InpWindow1_End = 11;  // End at 11 (not 12)
InpWindow2_Start = 12; // Start at 12 (not 11)
```

---

### Issue 4: Positions Not Managed During Break

**Wrong Code**:
```cpp
void OnTick() {
    if(!g_executor.SessionOpen()) {
        return;  // ❌ WRONG! Positions abandoned!
    }
    // ...
}
```

**Correct Code**:
```cpp
void OnTick() {
    if(!g_executor.SessionOpen()) {
        // ✅ CORRECT: Still manage positions!
        g_riskMgr.ManageOpenPositions();
        g_executor.ManagePendingOrders();
        return;
    }
    // ... normal flow ...
}
```

---

## 📊 Backtest Validation

### Metrics to Compare

```cpp
struct BacktestMetrics {
    string mode;              // "FULL_DAY" or "MULTI_WINDOW"
    int totalTrades;
    double winRate;
    double profitFactor;
    double maxDD;
    double totalProfit;
    int tradesPerDay;
    
    // By window (Multi-Window only)
    int tradesWindow1;        // Asia
    int tradesWindow2;        // London
    int tradesWindow3;        // NY
    double winRateWindow1;
    double winRateWindow2;
    double winRateWindow3;
};
```

### Expected Results

```
Full Day Mode (Baseline):
  Trades/Day: 5.2
  Win Rate: 65%
  Profit Factor: 2.0
  Max DD: -8%

Multi-Window (All):
  Trades/Day: 4.1
  Win Rate: 68%
  Profit Factor: 2.2
  Max DD: -7%
  
Multi-Window (London+NY):
  Trades/Day: 3.2
  Win Rate: 71%
  Profit Factor: 2.4
  Max DD: -6%
```

---

## 📋 Implementation Summary

### Files to Modify

1. ✅ **executor.mqh**:
   - Add enum `TRADING_SESSION_MODE`
   - Add struct `TradingWindow`
   - Add member variables
   - Update `Init()` signature & implementation
   - Rewrite `SessionOpen()`
   - Add `GetActiveWindow()`
   - Add `GetNextWindowInfo()`
   - Add `GetCurrentSessionType()`
   - Add `ValidateWindows()`

2. ✅ **SMC_ICT_EA.mq5**:
   - Add input parameters (session mode + 3 windows)
   - Update `OnInit()` executor initialization
   - Optional: Update dashboard display

3. ✅ **draw_debug.mqh** (Optional):
   - Show active window on dashboard
   - Show next window countdown

### Lines Changed

```
executor.mqh:    ~150 lines modified/added
SMC_ICT_EA.mq5:  ~50 lines modified/added
draw_debug.mqh:  ~20 lines modified/added (optional)

Total:           ~220 lines
```

### Estimated Time

- Code changes: 2 hours
- Testing: 2 hours
- Debugging: 1 hour
- **Total**: 5 hours

---

## 🎓 Next Steps After Implementation

1. **Basic Testing** (1 day):
   - Visual verification on chart
   - Check logs hourly
   - Verify both modes work

2. **Backtest Comparison** (2 days):
   - Run Full Day mode (3 months)
   - Run Multi-Window (3 months)
   - Compare metrics
   - Analyze performance by window

3. **Optimization** (3 days):
   - Identify best-performing windows
   - Test various window combinations
   - Fine-tune start/end times
   - Create optimal presets

4. **Forward Test** (1 week):
   - Demo account
   - Monitor real-time behavior
   - Validate timezone conversion
   - Confirm position management during breaks

---

## 📚 Related Documentation

- [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md) - User guide
- [TIMEZONE_CONVERSION.md](TIMEZONE_CONVERSION.md) - Timezone logic
- [04_EXECUTOR.md](04_EXECUTOR.md) - Session management details
- [07_CONFIGURATION.md](07_CONFIGURATION.md) - Parameter guide
- [08_MAIN_FLOW.md](08_MAIN_FLOW.md) - Flow with multi-session

---

**Status**: Ready for Implementation ✅  
**Complexity**: Low-Medium  
**Risk**: Low (backward compatible with FULL_DAY default)  
**Time**: ~5 hours total

