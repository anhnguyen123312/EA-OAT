//+------------------------------------------------------------------+
//|                                                    detectors.mqh |
//|                        Detection Layer - BOS, Sweep, OB, FVG, Momentum |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

//+------------------------------------------------------------------+
//| Signal Structures                                                |
//+------------------------------------------------------------------+

// BOS (Break of Structure) Signal
struct BOSSignal {
    bool     valid;
    int      direction;         // 1=bullish, -1=bearish
    datetime detectedTime;
    double   breakLevel;        // Price level broken
    int      barsAge;
    int      ttl;
    // v2.1 additions
    int      retestCount;       // Number of retests
    datetime lastRetestTime;    // Last retest timestamp
    bool     hasRetest;         // At least 1 retest
    double   retestStrength;    // 0-1 quality score
};

// Liquidity Sweep Signal
struct SweepSignal {
    bool     detected;
    int      side;              // 1=buy-side high, -1=sell-side low
    double   level;             // Fractal price level
    datetime time;
    int      distanceBars;      // Distance to fractal
    bool     valid;
    double   proximityATR;      // v2.0: Distance / ATR
};

// Order Block Structure
struct OrderBlock {
    bool     valid;
    int      direction;         // 1=demand, -1=supply
    double   priceTop;
    double   priceBottom;
    datetime createdTime;
    int      touches;           // Number of touches
    bool     weak;              // Volume < 1.3x avg
    bool     isBreaker;         // Invalidated → Breaker Block
    long     volume;            // Candle volume
    // v2.1 additions
    bool     hasSweepNearby;    // Has sweep validation
    double   sweepLevel;        // Sweep price
    int      sweepDistancePts;  // Distance in points
    double   sweepQuality;      // 0-1 quality score
    double   size;              // Actual OB size (high - low)
};

// Fair Value Gap Signal
struct FVGSignal {
    bool     valid;
    int      direction;         // 1=bullish, -1=bearish
    double   priceTop;
    double   priceBottom;
    datetime createdTime;
    int      state;             // 0=Valid, 1=Mitigated, 2=Completed
    double   fillPct;           // % filled
    double   initialSize;       // Original gap size
    // v2.1 additions
    bool     mtfOverlap;        // HTF confirmation
    double   htfFVGTop;         // HTF FVG top
    double   htfFVGBottom;      // HTF FVG bottom
    double   overlapRatio;      // LTF size / HTF size
    ENUM_TIMEFRAMES htfPeriod;  // Which HTF
};

// Momentum Signal
struct MomentumSignal {
    bool     valid;
    int      direction;         // 1=bullish, -1=bearish
    int      consecutiveBars;
    datetime detectedTime;
    int      ttl;
};

// Swing Point Structure
struct Swing {
    int      index;
    double   price;
    datetime time;
    bool     valid;
};

//+------------------------------------------------------------------+
//| CDetector Class - Signal Detection                               |
//+------------------------------------------------------------------+
class CDetector {
private:
    string   m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    int      m_atrHandle;
    
    // Price arrays (Series mode)
    double   m_high[];
    double   m_low[];
    double   m_close[];
    double   m_open[];
    long     m_volume[];
    
    // Detection parameters
    int      m_fractalK;
    int      m_lookbackSwing;
    double   m_minBodyATR;
    int      m_minBreakPts;
    int      m_bos_TTL;
    
    int      m_lookbackLiq;
    double   m_minWickPct;
    int      m_sweep_TTL;
    
    int      m_ob_MaxTouches;
    int      m_ob_BufferInvPts;
    int      m_ob_TTL;
    double   m_ob_VolMultiplier;
    
    int      m_fvg_MinPts;
    double   m_fvg_FillMinPct;
    double   m_fvg_MitigatePct;
    double   m_fvg_CompletePct;
    int      m_fvg_BufferInvPt;
    int      m_fvg_TTL;
    int      m_fvg_KeepSide;
    
    double   m_momo_MinDispATR;
    int      m_momo_FailBars;
    int      m_momo_TTL;
    
    // v2.1 parameters
    int      m_bosRetestTolerance;
    int      m_bosRetestMinGap;
    int      m_obSweepMaxDist;
    double   m_fvgTolerance;
    int      m_fvgHTFMinSize;
    
    // OB dynamic sizing (from update.md)
    bool     m_ob_UseDynamicSize;
    int      m_ob_MinSizePts;
    double   m_ob_ATRMultiplier;

public:
    CDetector();
    ~CDetector();
    
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              int fractalK, int lookbackSwing, double minBodyATR, int minBreakPts, int bos_TTL,
              int lookbackLiq, double minWickPct, int sweep_TTL,
              int ob_MaxTouches, int ob_BufferInvPts, int ob_TTL, double ob_VolMultiplier,
              int fvg_MinPts, double fvg_FillMinPct, double fvg_MitigatePct, 
              double fvg_CompletePct, int fvg_BufferInvPt, int fvg_TTL, int fvg_KeepSide,
              double momo_MinDispATR, int momo_FailBars, int momo_TTL,
              int bosRetestTolerance, int bosRetestMinGap,
              int obSweepMaxDist, double fvgTolerance, int fvgHTFMinSize,
              bool ob_UseDynamicSize, int ob_MinSizePts, double ob_ATRMultiplier);
    
    void UpdateSeries();
    
    // Core detectors
    BOSSignal DetectBOS();
    SweepSignal DetectSweep();
    OrderBlock FindOB(int direction);
    FVGSignal FindFVG(int direction);
    MomentumSignal DetectMomentum();
    int GetMTFBias();
    
    // v2.1 advanced detectors
    OrderBlock FindOBWithSweep(int direction, SweepSignal &sweep);
    bool CheckFVGMTFOverlap(FVGSignal &ltfFVG);
    void UpdateBOSRetest(BOSSignal &bos);
    
    // Helpers
    double GetATR();
    
private:
    // Swing detection
    bool IsSwingHigh(int index, int K);
    bool IsSwingLow(int index, int K);
    Swing FindLastSwingHigh(int lookback, int K);
    Swing FindLastSwingLow(int lookback, int K);
    
    // Validation
    void UpdateSignalTTL(BOSSignal &signal);
    void UpdateSignalTTL(SweepSignal &signal);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDetector::CDetector() {
    m_atrHandle = INVALID_HANDLE;
    ArraySetAsSeries(m_high, true);
    ArraySetAsSeries(m_low, true);
    ArraySetAsSeries(m_close, true);
    ArraySetAsSeries(m_open, true);
    ArraySetAsSeries(m_volume, true);
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CDetector::~CDetector() {
    if(m_atrHandle != INVALID_HANDLE) {
        IndicatorRelease(m_atrHandle);
    }
}

//+------------------------------------------------------------------+
//| Initialize detector                                               |
//+------------------------------------------------------------------+
bool CDetector::Init(string symbol, ENUM_TIMEFRAMES tf,
                     int fractalK, int lookbackSwing, double minBodyATR, int minBreakPts, int bos_TTL,
                     int lookbackLiq, double minWickPct, int sweep_TTL,
                     int ob_MaxTouches, int ob_BufferInvPts, int ob_TTL, double ob_VolMultiplier,
                     int fvg_MinPts, double fvg_FillMinPct, double fvg_MitigatePct,
                     double fvg_CompletePct, int fvg_BufferInvPt, int fvg_TTL, int fvg_KeepSide,
                     double momo_MinDispATR, int momo_FailBars, int momo_TTL,
                     int bosRetestTolerance, int bosRetestMinGap,
                     int obSweepMaxDist, double fvgTolerance, int fvgHTFMinSize,
                     bool ob_UseDynamicSize, int ob_MinSizePts, double ob_ATRMultiplier) {
    
    m_symbol = symbol;
    m_timeframe = tf;
    
    // BOS parameters
    m_fractalK = fractalK;
    m_lookbackSwing = lookbackSwing;
    m_minBodyATR = minBodyATR;
    m_minBreakPts = minBreakPts;
    m_bos_TTL = bos_TTL;
    
    // Sweep parameters
    m_lookbackLiq = lookbackLiq;
    m_minWickPct = minWickPct;
    m_sweep_TTL = sweep_TTL;
    
    // OB parameters
    m_ob_MaxTouches = ob_MaxTouches;
    m_ob_BufferInvPts = ob_BufferInvPts;
    m_ob_TTL = ob_TTL;
    m_ob_VolMultiplier = ob_VolMultiplier;
    
    // FVG parameters
    m_fvg_MinPts = fvg_MinPts;
    m_fvg_FillMinPct = fvg_FillMinPct;
    m_fvg_MitigatePct = fvg_MitigatePct;
    m_fvg_CompletePct = fvg_CompletePct;
    m_fvg_BufferInvPt = fvg_BufferInvPt;
    m_fvg_TTL = fvg_TTL;
    m_fvg_KeepSide = fvg_KeepSide;
    
    // Momentum parameters
    m_momo_MinDispATR = momo_MinDispATR;
    m_momo_FailBars = momo_FailBars;
    m_momo_TTL = momo_TTL;
    
    // v2.1 parameters
    m_bosRetestTolerance = bosRetestTolerance;
    m_bosRetestMinGap = bosRetestMinGap;
    m_obSweepMaxDist = obSweepMaxDist;
    m_fvgTolerance = fvgTolerance;
    m_fvgHTFMinSize = fvgHTFMinSize;
    
    // OB dynamic sizing parameters
    m_ob_UseDynamicSize = ob_UseDynamicSize;
    m_ob_MinSizePts = ob_MinSizePts;
    m_ob_ATRMultiplier = ob_ATRMultiplier;
    
    // Create ATR indicator
    m_atrHandle = iATR(m_symbol, m_timeframe, 14);
    if(m_atrHandle == INVALID_HANDLE) {
        Print("❌ CDetector: Failed to create ATR handle");
        return false;
    }
    
    Print("✅ CDetector initialized for ", EnumToString(m_timeframe));
    return true;
}

//+------------------------------------------------------------------+
//| Update price series                                              |
//+------------------------------------------------------------------+
void CDetector::UpdateSeries() {
    int bars = 200;
    CopyHigh(m_symbol, m_timeframe, 0, bars, m_high);
    CopyLow(m_symbol, m_timeframe, 0, bars, m_low);
    CopyClose(m_symbol, m_timeframe, 0, bars, m_close);
    CopyOpen(m_symbol, m_timeframe, 0, bars, m_open);
    CopyTickVolume(m_symbol, m_timeframe, 0, bars, m_volume);
}

//+------------------------------------------------------------------+
//| Get ATR value                                                     |
//+------------------------------------------------------------------+
double CDetector::GetATR() {
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(m_atrHandle, 0, 0, 1, atr) <= 0) {
        return 0;
    }
    return atr[0];
}

//+------------------------------------------------------------------+
//| Check if bar is swing high (FIXED - No lookahead)                |
//+------------------------------------------------------------------+
bool CDetector::IsSwingHigh(int index, int K) {
    // [FIX BUG #1] Cần >= 2*K để có K bars confirmation bên phải
    // VD: K=5 → index phải >= 10 (bar 10 trở về trước)
    if(index < 2 * K) {
        return false; // Chưa đủ confirmation
    }
    
    // Boundary check
    if(index >= ArraySize(m_high)) {
        return false;
    }
    
    double h = m_high[index];
    
    // Check K bars BÊN TRÁI (bars confirmed trước đó)
    for(int k = 1; k <= K; k++) {
        if(index - k < 0) return false;
        
        // [FIX BUG #3] Dùng < thay vì <= để allow tie-cases
        if(h < m_high[index - k]) {
            return false;
        }
    }
    
    // Check K bars BÊN PHẢI (bars ĐÃ confirmed - không phải future!)
    for(int k = 1; k <= K; k++) {
        if(index + k >= ArraySize(m_high)) return false;
        
        // [FIX BUG #3] Dùng < thay vì <= để allow tie-cases
        if(h < m_high[index + k]) {
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if bar is swing low (FIXED - No lookahead)                 |
//+------------------------------------------------------------------+
bool CDetector::IsSwingLow(int index, int K) {
    // [FIX BUG #1] Same logic as IsSwingHigh
    if(index < 2 * K) {
        return false; // Chưa đủ confirmation
    }
    
    // Boundary check
    if(index >= ArraySize(m_low)) {
        return false;
    }
    
    double l = m_low[index];
    
    // Check K bars BÊN TRÁI
    for(int k = 1; k <= K; k++) {
        if(index - k < 0) return false;
        
        // [FIX BUG #3] Dùng > thay vì >= để allow tie-cases
        if(l > m_low[index - k]) {
            return false;
        }
    }
    
    // Check K bars BÊN PHẢI (confirmed)
    for(int k = 1; k <= K; k++) {
        if(index + k >= ArraySize(m_low)) return false;
        
        // [FIX BUG #3] Dùng > thay vì >= để allow tie-cases
        if(l > m_low[index + k]) {
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Find last swing high (FIXED - Proper confirmation)               |
//+------------------------------------------------------------------+
Swing CDetector::FindLastSwingHigh(int lookback, int K) {
    Swing swing;
    swing.valid = false;
    
    // [FIX BUG #2] Bắt đầu từ 2*K thay vì K+1
    // VD: K=5 → start từ bar 10 (có đủ 5 bars confirmation)
    int startIdx = 2 * K;
    
    // [GUARD] Nếu lookback quá nhỏ
    if(lookback <= startIdx) {
        return swing; // Invalid
    }
    
    // Scan từ gần đến xa (tìm swing GẦN NHẤT)
    for(int i = startIdx; i < lookback; i++) {
        if(IsSwingHigh(i, K)) {
            swing.valid = true;
            swing.index = i;
            swing.price = m_high[i];
            swing.time = iTime(m_symbol, m_timeframe, i);
            return swing; // Return NGAY swing đầu tiên tìm được
        }
    }
    
    return swing; // Không tìm thấy
}

//+------------------------------------------------------------------+
//| Find last swing low (FIXED - Proper confirmation)                |
//+------------------------------------------------------------------+
Swing CDetector::FindLastSwingLow(int lookback, int K) {
    Swing swing;
    swing.valid = false;
    
    // [FIX BUG #2] Same logic
    int startIdx = 2 * K;
    
    // [GUARD] Nếu lookback quá nhỏ
    if(lookback <= startIdx) {
        return swing; // Invalid
    }
    
    // Scan từ gần đến xa
    for(int i = startIdx; i < lookback; i++) {
        if(IsSwingLow(i, K)) {
            swing.valid = true;
            swing.index = i;
            swing.price = m_low[i];
            swing.time = iTime(m_symbol, m_timeframe, i);
            return swing; // Return NGAY swing đầu tiên
        }
    }
    
    return swing; // Không tìm thấy
}

//+------------------------------------------------------------------+
//| Detect BOS (Break of Structure)                                  |
//+------------------------------------------------------------------+
BOSSignal CDetector::DetectBOS() {
    BOSSignal signal;
    signal.valid = false;
    signal.retestCount = 0;
    signal.hasRetest = false;
    signal.retestStrength = 0.0;
    signal.lastRetestTime = 0;
    
    double atr = GetATR();
    if(atr <= 0) return signal;
    
    double minBodySize = m_minBodyATR * atr;
    double currentClose = m_close[0];
    double currentOpen = m_open[0];
    double bodySize = MathAbs(currentClose - currentOpen);
    
    // Check body size
    if(bodySize < minBodySize) return signal;
    
    // Find last swing high
    Swing swingHigh = FindLastSwingHigh(m_lookbackSwing, m_fractalK);
    if(swingHigh.valid) {
        double breakDistance = currentClose - swingHigh.price;
        if(breakDistance > 0 && breakDistance >= m_minBreakPts * _Point) {
            // BULLISH BOS
            signal.valid = true;
            signal.direction = 1;
            signal.breakLevel = swingHigh.price;
            signal.detectedTime = TimeCurrent();
            signal.barsAge = 0;
            signal.ttl = m_bos_TTL;
            return signal;
        }
    }
    
    // Find last swing low
    Swing swingLow = FindLastSwingLow(m_lookbackSwing, m_fractalK);
    if(swingLow.valid) {
        double breakDistance = swingLow.price - currentClose;
        if(breakDistance > 0 && breakDistance >= m_minBreakPts * _Point) {
            // BEARISH BOS
            signal.valid = true;
            signal.direction = -1;
            signal.breakLevel = swingLow.price;
            signal.detectedTime = TimeCurrent();
            signal.barsAge = 0;
            signal.ttl = m_bos_TTL;
            return signal;
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Detect Liquidity Sweep                                           |
//+------------------------------------------------------------------+
SweepSignal CDetector::DetectSweep() {
    SweepSignal sweep;
    sweep.detected = false;
    sweep.valid = false;
    sweep.proximityATR = 0;
    
    int skipBars = 1;
    
    // Scan recent candles (0-3)
    for(int i = 0; i <= 3; i++) {
        double candleHigh = m_high[i];
        double candleLow = m_low[i];
        double candleClose = m_close[i];
        double candleOpen = m_open[i];
        double candleRange = candleHigh - candleLow;
        
        if(candleRange <= 0) continue;
        
        // Scan for fractals
        for(int j = i + skipBars + 1; j <= m_lookbackLiq; j++) {
            // Check BUY-SIDE SWEEP (sweep fractal high)
            if(IsSwingHigh(j, m_fractalK)) {
                double fractalHigh = m_high[j];
                double upperWick = candleHigh - MathMax(candleClose, candleOpen);
                double upperWickPct = (upperWick / candleRange) * 100.0;
                
                if(candleHigh > fractalHigh && 
                   (candleClose < fractalHigh || upperWickPct >= m_minWickPct)) {
                    // BUY-SIDE SWEEP detected
                    sweep.detected = true;
                    sweep.side = 1;
                    sweep.level = fractalHigh;
                    sweep.time = iTime(m_symbol, m_timeframe, j);
                    sweep.distanceBars = j - i;
                    sweep.valid = true;
                    return sweep;
                }
            }
            
            // Check SELL-SIDE SWEEP (sweep fractal low)
            if(IsSwingLow(j, m_fractalK)) {
                double fractalLow = m_low[j];
                double lowerWick = MathMin(candleClose, candleOpen) - candleLow;
                double lowerWickPct = (lowerWick / candleRange) * 100.0;
                
                if(candleLow < fractalLow && 
                   (candleClose > fractalLow || lowerWickPct >= m_minWickPct)) {
                    // SELL-SIDE SWEEP detected
                    sweep.detected = true;
                    sweep.side = -1;
                    sweep.level = fractalLow;
                    sweep.time = iTime(m_symbol, m_timeframe, j);
                    sweep.distanceBars = j - i;
                    sweep.valid = true;
                    return sweep;
                }
            }
        }
    }
    
    return sweep;
}

//+------------------------------------------------------------------+
//| Find Order Block (FIXED - With min size validation)              |
//+------------------------------------------------------------------+
OrderBlock CDetector::FindOB(int direction) {
    OrderBlock ob;
    ob.valid = false;
    ob.hasSweepNearby = false;
    ob.sweepQuality = 0.0;
    ob.size = 0.0;
    
    int startIdx = 5;
    int endIdx = 80;
    
    // Get ATR for dynamic sizing
    double atr = GetATR();
    if(atr <= 0) return ob; // Guard
    
    // [NEW] Calculate min OB size (fixed or dynamic)
    double minOBSize = 0;
    
    if(m_ob_UseDynamicSize) {
        // Dynamic: based on ATR
        minOBSize = atr * m_ob_ATRMultiplier;
    } else {
        // Fixed: based on points
        minOBSize = m_ob_MinSizePts * _Point;
    }
    
    // Calculate avg volume
    long sumVol = 0;
    int volCount = 0;
    for(int k = startIdx; k < MathMin(startIdx + 20, ArraySize(m_volume)); k++) {
        sumVol += m_volume[k];
        volCount++;
    }
    double avgVol = (volCount > 0) ? (double)sumVol / volCount : 0;
    
    for(int i = startIdx; i < endIdx; i++) {
        bool isBearish = (m_close[i] < m_open[i]);
        bool isBullish = (m_close[i] > m_open[i]);
        
        // Looking for BULLISH OB (demand)
        if(direction == 1 && isBearish) {
            // [NEW] Check OB size BEFORE other validations
            double obSize = m_high[i] - m_low[i];
            if(obSize < minOBSize) {
                continue; // OB quá nhỏ, skip
            }
            
            // Check displacement (rally after this bearish candle)
            if(i >= 2 && m_close[i-1] > m_high[i+1]) {
                ob.valid = true;
                ob.direction = 1;
                ob.priceBottom = m_low[i];
                ob.priceTop = m_close[i];
                ob.createdTime = iTime(m_symbol, m_timeframe, i);
                ob.volume = m_volume[i];
                ob.size = obSize; // Store actual size
                
                // Check volume strength
                ob.weak = (avgVol > 0) && (m_volume[i] < avgVol * m_ob_VolMultiplier);
                ob.isBreaker = false;
                
                // Count touches
                ob.touches = 0;
                for(int t = i - 1; t >= 0; t--) {
                    if(m_low[t] <= ob.priceTop && m_low[t] >= ob.priceBottom) {
                        ob.touches++;
                        if(ob.touches >= m_ob_MaxTouches) {
                            ob.valid = false;
                            break;
                        }
                    }
                }
                
                if(ob.valid) return ob;
            }
        }
        // Looking for BEARISH OB (supply)
        else if(direction == -1 && isBullish) {
            // [NEW] Check OB size
            double obSize = m_high[i] - m_low[i];
            if(obSize < minOBSize) {
                continue; // OB quá nhỏ, skip
            }
            
            // Check displacement (drop after this bullish candle)
            if(i >= 2 && m_close[i-1] < m_low[i+1]) {
                ob.valid = true;
                ob.direction = -1;
                ob.priceBottom = m_close[i];
                ob.priceTop = m_high[i];
                ob.createdTime = iTime(m_symbol, m_timeframe, i);
                ob.volume = m_volume[i];
                ob.size = obSize; // Store actual size
                
                // Check volume strength
                ob.weak = (avgVol > 0) && (m_volume[i] < avgVol * m_ob_VolMultiplier);
                ob.isBreaker = false;
                
                // Count touches
                ob.touches = 0;
                for(int t = i - 1; t >= 0; t--) {
                    if(m_high[t] >= ob.priceBottom && m_high[t] <= ob.priceTop) {
                        ob.touches++;
                        if(ob.touches >= m_ob_MaxTouches) {
                            ob.valid = false;
                            break;
                        }
                    }
                }
                
                if(ob.valid) return ob;
            }
        }
    }
    
    return ob;
}

//+------------------------------------------------------------------+
//| Find OB with Sweep Validation (v2.1)                             |
//+------------------------------------------------------------------+
OrderBlock CDetector::FindOBWithSweep(int direction, SweepSignal &sweep) {
    // First find OB normally
    OrderBlock ob = FindOB(direction);
    if(!ob.valid) return ob;
    
    // Check sweep relationship
    if(sweep.valid && sweep.detected) {
        if(direction == 1) {
            // BULLISH OB: need SELL-SIDE sweep (side = -1)
            if(sweep.side == -1) {
                // Case A: Sweep BELOW OB
                if(sweep.level <= ob.priceBottom) {
                    double distance = ob.priceBottom - sweep.level;
                    ob.sweepDistancePts = (int)(distance / _Point);
                    
                    if(ob.sweepDistancePts <= m_obSweepMaxDist) {
                        ob.hasSweepNearby = true;
                        ob.sweepLevel = sweep.level;
                        ob.sweepQuality = MathMax(0.0, 1.0 - (ob.sweepDistancePts / 200.0));
                    }
                }
                // Case B: Sweep INSIDE OB zone
                else if(sweep.level >= ob.priceBottom && sweep.level <= ob.priceTop) {
                    ob.hasSweepNearby = true;
                    ob.sweepLevel = sweep.level;
                    ob.sweepDistancePts = 0;
                    ob.sweepQuality = 0.8;
                }
            }
        }
        else if(direction == -1) {
            // BEARISH OB: need BUY-SIDE sweep (side = +1)
            if(sweep.side == 1) {
                // Case A: Sweep ABOVE OB
                if(sweep.level >= ob.priceTop) {
                    double distance = sweep.level - ob.priceTop;
                    ob.sweepDistancePts = (int)(distance / _Point);
                    
                    if(ob.sweepDistancePts <= m_obSweepMaxDist) {
                        ob.hasSweepNearby = true;
                        ob.sweepLevel = sweep.level;
                        ob.sweepQuality = MathMax(0.0, 1.0 - (ob.sweepDistancePts / 200.0));
                    }
                }
                // Case B: Sweep INSIDE OB zone
                else if(sweep.level <= ob.priceTop && sweep.level >= ob.priceBottom) {
                    ob.hasSweepNearby = true;
                    ob.sweepLevel = sweep.level;
                    ob.sweepDistancePts = 0;
                    ob.sweepQuality = 0.8;
                }
            }
        }
    }
    
    return ob;
}

//+------------------------------------------------------------------+
//| Find Fair Value Gap                                              |
//+------------------------------------------------------------------+
FVGSignal CDetector::FindFVG(int direction) {
    FVGSignal fvg;
    fvg.valid = false;
    fvg.mtfOverlap = false;
    fvg.overlapRatio = 0.0;
    
    double minGapSize = m_fvg_MinPts * _Point;
    
    for(int i = 2; i < 60; i++) {
        if(direction == 1) {
            // BULLISH FVG: low[i] > high[i+2]
            if(m_low[i] > m_high[i+2]) {
                double gapSize = m_low[i] - m_high[i+2];
                if(gapSize >= minGapSize) {
                    fvg.valid = true;
                    fvg.direction = 1;
                    fvg.priceTop = m_low[i];
                    fvg.priceBottom = m_high[i+2];
                    fvg.createdTime = iTime(m_symbol, m_timeframe, i);
                    fvg.initialSize = gapSize;
                    
                    // Calculate fill percentage
                    double gapFilled = 0;
                    for(int j = i - 1; j >= 0; j--) {
                        if(m_low[j] <= fvg.priceTop) {
                            double fillLevel = MathMin(m_low[j], fvg.priceTop);
                            gapFilled = MathMax(gapFilled, fvg.priceTop - fillLevel);
                        }
                    }
                    fvg.fillPct = (gapFilled / fvg.initialSize) * 100.0;
                    
                    // Determine state
                    if(fvg.fillPct < m_fvg_MitigatePct) {
                        fvg.state = 0; // Valid
                    } else if(fvg.fillPct < m_fvg_CompletePct) {
                        fvg.state = 1; // Mitigated
                    } else {
                        fvg.state = 2; // Completed
                        fvg.valid = false;
                    }
                    
                    // Check invalidation
                    double buffer = m_fvg_BufferInvPt * _Point;
                    if(m_close[0] < fvg.priceBottom - buffer) {
                        fvg.valid = false;
                    }
                    
                    if(fvg.valid) return fvg;
                }
            }
        }
        else if(direction == -1) {
            // BEARISH FVG: high[i] < low[i+2]
            if(m_high[i] < m_low[i+2]) {
                double gapSize = m_low[i+2] - m_high[i];
                if(gapSize >= minGapSize) {
                    fvg.valid = true;
                    fvg.direction = -1;
                    fvg.priceTop = m_low[i+2];
                    fvg.priceBottom = m_high[i];
                    fvg.createdTime = iTime(m_symbol, m_timeframe, i);
                    fvg.initialSize = gapSize;
                    
                    // Calculate fill percentage
                    double gapFilled = 0;
                    for(int j = i - 1; j >= 0; j--) {
                        if(m_high[j] >= fvg.priceBottom) {
                            double fillLevel = MathMax(m_high[j], fvg.priceBottom);
                            gapFilled = MathMax(gapFilled, fillLevel - fvg.priceBottom);
                        }
                    }
                    fvg.fillPct = (gapFilled / fvg.initialSize) * 100.0;
                    
                    // Determine state
                    if(fvg.fillPct < m_fvg_MitigatePct) {
                        fvg.state = 0;
                    } else if(fvg.fillPct < m_fvg_CompletePct) {
                        fvg.state = 1;
                    } else {
                        fvg.state = 2;
                        fvg.valid = false;
                    }
                    
                    // Check invalidation
                    double buffer = m_fvg_BufferInvPt * _Point;
                    if(m_close[0] > fvg.priceTop + buffer) {
                        fvg.valid = false;
                    }
                    
                    if(fvg.valid) return fvg;
                }
            }
        }
    }
    
    return fvg;
}

//+------------------------------------------------------------------+
//| Check FVG MTF Overlap (v2.1)                                     |
//+------------------------------------------------------------------+
bool CDetector::CheckFVGMTFOverlap(FVGSignal &ltfFVG) {
    if(!ltfFVG.valid) return false;
    
    // Determine HTF
    ENUM_TIMEFRAMES htf = PERIOD_H1;
    if(m_timeframe == PERIOD_M15 || m_timeframe == PERIOD_M30) {
        htf = PERIOD_H1;
    } else if(m_timeframe == PERIOD_H1) {
        htf = PERIOD_H4;
    } else {
        return false; // Not supported for other timeframes
    }
    
    // Get HTF data
    double htfHigh[], htfLow[], htfClose[];
    ArraySetAsSeries(htfHigh, true);
    ArraySetAsSeries(htfLow, true);
    ArraySetAsSeries(htfClose, true);
    
    if(CopyHigh(m_symbol, htf, 0, 60, htfHigh) <= 0 ||
       CopyLow(m_symbol, htf, 0, 60, htfLow) <= 0 ||
       CopyClose(m_symbol, htf, 0, 60, htfClose) <= 0) {
        return false;
    }
    
    // Scan for HTF FVG in same direction
    for(int i = 2; i < 58; i++) {  // FIXED: i+2 must be < 60, so i < 58
        if(ltfFVG.direction == 1) {
            // BULLISH: Check if low[i] > high[i+2]
            if(htfLow[i] > htfHigh[i+2]) {
                double htfTop = htfLow[i];
                double htfBottom = htfHigh[i+2];
                double htfSize = htfTop - htfBottom;
                
                if(htfSize >= m_fvgHTFMinSize * _Point) {
                    double tolerance = m_fvgTolerance * _Point;
                    
                    // Check SUBSET relationship
                    if(ltfFVG.priceBottom >= (htfBottom - tolerance) &&
                       ltfFVG.priceTop <= (htfTop + tolerance)) {
                        // SUBSET confirmed!
                        ltfFVG.mtfOverlap = true;
                        ltfFVG.htfFVGTop = htfTop;
                        ltfFVG.htfFVGBottom = htfBottom;
                        ltfFVG.htfPeriod = htf;
                        
                        double ltfSize = ltfFVG.priceTop - ltfFVG.priceBottom;
                        ltfFVG.overlapRatio = ltfSize / htfSize;
                        
                        return true;
                    }
                }
            }
        }
        else if(ltfFVG.direction == -1) {
            // BEARISH: Check if high[i] < low[i+2]
            if(htfHigh[i] < htfLow[i+2]) {
                double htfBottom = htfHigh[i];
                double htfTop = htfLow[i+2];
                double htfSize = htfTop - htfBottom;
                
                if(htfSize >= m_fvgHTFMinSize * _Point) {
                    double tolerance = m_fvgTolerance * _Point;
                    
                    if(ltfFVG.priceBottom >= (htfBottom - tolerance) &&
                       ltfFVG.priceTop <= (htfTop + tolerance)) {
                        ltfFVG.mtfOverlap = true;
                        ltfFVG.htfFVGTop = htfTop;
                        ltfFVG.htfFVGBottom = htfBottom;
                        ltfFVG.htfPeriod = htf;
                        ltfFVG.overlapRatio = (ltfFVG.priceTop - ltfFVG.priceBottom) / htfSize;
                        
                        return true;
                    }
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Update BOS Retest Tracking (v2.1)                                |
//+------------------------------------------------------------------+
void CDetector::UpdateBOSRetest(BOSSignal &bos) {
    if(!bos.valid) return;
    
    double tolerance = m_bosRetestTolerance * _Point;
    double retestZoneTop, retestZoneBottom;
    
    if(bos.direction == 1) {
        // BULLISH BOS: Retest zone ABOVE breakLevel
        retestZoneBottom = bos.breakLevel;
        retestZoneTop = bos.breakLevel + tolerance;
    } else {
        // BEARISH BOS: Retest zone BELOW breakLevel
        retestZoneTop = bos.breakLevel;
        retestZoneBottom = bos.breakLevel - tolerance;
    }
    
    // Scan recent bars for retest (1-20)
    for(int i = 1; i <= 20; i++) {
        datetime barTime = iTime(m_symbol, m_timeframe, i);
        
        // Skip if too close to last retest
        if(bos.lastRetestTime != 0) {
            long timeDiff = bos.lastRetestTime - barTime;
            long minGapSec = PeriodSeconds(m_timeframe) * m_bosRetestMinGap;
            if(timeDiff < minGapSec) {
                continue;
            }
        }
        
        double closePrice = m_close[i];
        
        // Check if close in retest zone
        if(closePrice >= retestZoneBottom && closePrice <= retestZoneTop) {
            bos.retestCount++;
            bos.lastRetestTime = barTime;
            bos.hasRetest = true;
            
            if(bos.retestCount >= 3) break;
        }
    }
    
    // Calculate strength
    if(bos.retestCount == 0) {
        bos.retestStrength = 0.0;
    } else if(bos.retestCount == 1) {
        bos.retestStrength = 0.7;
    } else if(bos.retestCount == 2) {
        bos.retestStrength = 0.9;
    } else {
        bos.retestStrength = 1.0;
    }
}

//+------------------------------------------------------------------+
//| Detect Momentum                                                  |
//+------------------------------------------------------------------+
MomentumSignal CDetector::DetectMomentum() {
    MomentumSignal momo;
    momo.valid = false;
    
    double atr = GetATR();
    if(atr <= 0) return momo;
    
    double minBodySize = m_momo_MinDispATR * atr;
    
    // Check BULLISH momentum
    int bullishCount = 0;
    for(int i = 0; i < 5; i++) {
        double body = m_close[i] - m_open[i];
        if(body >= minBodySize) {
            bullishCount++;
        } else {
            break;
        }
    }
    
    if(bullishCount >= 2) {
        // Find minor swing high (K=2)
        Swing minorSwing = FindLastSwingHigh(20, 2);
        if(minorSwing.valid && m_close[0] > minorSwing.price) {
            momo.valid = true;
            momo.direction = 1;
            momo.consecutiveBars = bullishCount;
            momo.detectedTime = TimeCurrent();
            momo.ttl = m_momo_TTL;
            return momo;
        }
    }
    
    // Check BEARISH momentum
    int bearishCount = 0;
    for(int i = 0; i < 5; i++) {
        double body = m_open[i] - m_close[i];
        if(body >= minBodySize) {
            bearishCount++;
        } else {
            break;
        }
    }
    
    if(bearishCount >= 2) {
        // Find minor swing low (K=2)
        Swing minorSwing = FindLastSwingLow(20, 2);
        if(minorSwing.valid && m_close[0] < minorSwing.price) {
            momo.valid = true;
            momo.direction = -1;
            momo.consecutiveBars = bearishCount;
            momo.detectedTime = TimeCurrent();
            momo.ttl = m_momo_TTL;
            return momo;
        }
    }
    
    return momo;
}

//+------------------------------------------------------------------+
//| Get MTF Bias                                                      |
//+------------------------------------------------------------------+
int CDetector::GetMTFBias() {
    // Determine HTF
    ENUM_TIMEFRAMES htf = PERIOD_H1;
    if(m_timeframe == PERIOD_M15 || m_timeframe == PERIOD_M30) {
        htf = PERIOD_H1;
    } else if(m_timeframe == PERIOD_H1) {
        htf = PERIOD_H4;
    } else if(m_timeframe == PERIOD_H4) {
        htf = PERIOD_D1;
    } else {
        return 0; // Neutral
    }
    
    // Get HTF data
    double htfHigh[], htfLow[];
    ArraySetAsSeries(htfHigh, true);
    ArraySetAsSeries(htfLow, true);
    
    if(CopyHigh(m_symbol, htf, 0, 50, htfHigh) <= 0 ||
       CopyLow(m_symbol, htf, 0, 50, htfLow) <= 0) {
        return 0;
    }
    
    // Find last 2 swing highs and 2 swing lows using HTF data
    int highCount = 0;
    double high1 = 0, high2 = 0;
    int K = 2;
    
    for(int i = K + 1; i < 50 && highCount < 2; i++) {
        // Check swing high manually for HTF
        bool isSwing = true;
        for(int k = 1; k <= K; k++) {
            if(i - k < 0 || i + k >= ArraySize(htfHigh)) {
                isSwing = false;
                break;
            }
            if(htfHigh[i] <= htfHigh[i-k] || htfHigh[i] <= htfHigh[i+k]) {
                isSwing = false;
                break;
            }
        }
        
        if(isSwing) {
            if(highCount == 0) high1 = htfHigh[i];
            else if(highCount == 1) high2 = htfHigh[i];
            highCount++;
        }
    }
    
    int lowCount = 0;
    double low1 = 0, low2 = 0;
    
    for(int i = K + 1; i < 50 && lowCount < 2; i++) {
        // Check swing low manually for HTF
        bool isSwing = true;
        for(int k = 1; k <= K; k++) {
            if(i - k < 0 || i + k >= ArraySize(htfLow)) {
                isSwing = false;
                break;
            }
            if(htfLow[i] >= htfLow[i-k] || htfLow[i] >= htfLow[i+k]) {
                isSwing = false;
                break;
            }
        }
        
        if(isSwing) {
            if(lowCount == 0) low1 = htfLow[i];
            else if(lowCount == 1) low2 = htfLow[i];
            lowCount++;
        }
    }
    
    // Determine bias
    if(highCount >= 2 && lowCount >= 2) {
        bool higherHighs = (high1 > high2);
        bool higherLows = (low1 > low2);
        bool lowerHighs = (high1 < high2);
        bool lowerLows = (low1 < low2);
        
        if(higherHighs && higherLows) return 1;  // Bullish
        if(lowerHighs && lowerLows) return -1;   // Bearish
    }
    
    return 0; // Neutral
}

