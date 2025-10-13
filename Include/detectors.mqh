//+------------------------------------------------------------------+
//|                                                    detectors.mqh |
//|                              SMC/ICT Detection Library for MT5   |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property version   "1.00"
#property strict

//--- Detection structures
struct Swing {
    int    index;
    double price;
    datetime time;
};

struct BOSSignal {
    int      direction;      // 1=bullish, -1=bearish, 0=none
    datetime detectedTime;
    double   breakLevel;
    int      barsAge;
    int      ttl;
    bool     valid;
};

struct SweepSignal {
    bool     detected;
    int      side;           // 1=buy-side (high), -1=sell-side (low)
    double   level;
    datetime time;
    int      barsAge;
    int      ttl;
    bool     valid;
};

struct OrderBlock {
    bool     valid;
    int      direction;      // 1=demand (bullish), -1=supply (bearish)
    double   priceTop;
    double   priceBottom;
    int      touches;
    datetime createdTime;
    int      barsAge;
    int      ttl;
};

struct FVGSignal {
    bool     valid;
    int      direction;      // 1=bullish FVG, -1=bearish FVG
    double   priceTop;
    double   priceBottom;
    double   fillPct;
    int      state;          // 0=Valid, 1=Mitigated, 2=Completed
    datetime createdTime;
    int      barsAge;
    int      ttl;
};

struct MomentumSignal {
    bool     valid;
    int      direction;
    int      consecutiveBars;
    datetime detectedTime;
    int      barsAge;
    int      ttl;
    bool     failedConfirm;
};

//+------------------------------------------------------------------+
//| Detector Class - Main Detection Engine                          |
//+------------------------------------------------------------------+
class CDetector {
private:
    // Handles
    int      m_atrHandle;
    
    // Parameters
    string   m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
    // Cached data
    double   m_atr[];
    double   m_high[];
    double   m_low[];
    double   m_open[];
    double   m_close[];
    
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
    
public:
    CDetector();
    ~CDetector();
    
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              int fractalK, int lookbackSwing, double minBodyATR, int minBreakPts, int bos_ttl,
              int lookbackLiq, double minWickPct, int sweep_ttl,
              int ob_maxTouches, int ob_bufferInv, int ob_ttl,
              int fvg_minPts, double fvg_fillMin, double fvg_mitigate, double fvg_complete, int fvg_bufferInv, int fvg_ttl, int fvg_keepSide,
              double momo_minDisp, int momo_failBars, int momo_ttl);
    
    void UpdateSeries();
    
    // Detection methods
    BOSSignal     DetectBOS();
    SweepSignal   DetectSweep();
    OrderBlock    FindOB(int direction);
    FVGSignal     FindFVG(int direction);
    MomentumSignal DetectMomentum();
    
private:
    bool IsSwingHigh(int index, int K);
    bool IsSwingLow(int index, int K);
    Swing FindLastSwingHigh(int lookback);
    Swing FindLastSwingLow(int lookback);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CDetector::CDetector() {
    m_atrHandle = INVALID_HANDLE;
    ArraySetAsSeries(m_atr, true);
    ArraySetAsSeries(m_high, true);
    ArraySetAsSeries(m_low, true);
    ArraySetAsSeries(m_open, true);
    ArraySetAsSeries(m_close, true);
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
//| Initialize detector with parameters                              |
//+------------------------------------------------------------------+
bool CDetector::Init(string symbol, ENUM_TIMEFRAMES tf,
                     int fractalK, int lookbackSwing, double minBodyATR, int minBreakPts, int bos_ttl,
                     int lookbackLiq, double minWickPct, int sweep_ttl,
                     int ob_maxTouches, int ob_bufferInv, int ob_ttl,
                     int fvg_minPts, double fvg_fillMin, double fvg_mitigate, double fvg_complete, int fvg_bufferInv, int fvg_ttl, int fvg_keepSide,
                     double momo_minDisp, int momo_failBars, int momo_ttl) {
    m_symbol = symbol;
    m_timeframe = tf;
    
    // BOS params
    m_fractalK = fractalK;
    m_lookbackSwing = lookbackSwing;
    m_minBodyATR = minBodyATR;
    m_minBreakPts = minBreakPts;
    m_bos_TTL = bos_ttl;
    
    // Sweep params
    m_lookbackLiq = lookbackLiq;
    m_minWickPct = minWickPct;
    m_sweep_TTL = sweep_ttl;
    
    // OB params
    m_ob_MaxTouches = ob_maxTouches;
    m_ob_BufferInvPts = ob_bufferInv;
    m_ob_TTL = ob_ttl;
    
    // FVG params
    m_fvg_MinPts = fvg_minPts;
    m_fvg_FillMinPct = fvg_fillMin;
    m_fvg_MitigatePct = fvg_mitigate;
    m_fvg_CompletePct = fvg_complete;
    m_fvg_BufferInvPt = fvg_bufferInv;
    m_fvg_TTL = fvg_ttl;
    m_fvg_KeepSide = fvg_keepSide;
    
    // Momentum params
    m_momo_MinDispATR = momo_minDisp;
    m_momo_FailBars = momo_failBars;
    m_momo_TTL = momo_ttl;
    
    // Create ATR handle
    m_atrHandle = iATR(m_symbol, m_timeframe, 14);
    if(m_atrHandle == INVALID_HANDLE) {
        Print("Failed to create ATR indicator handle");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Update price series                                              |
//+------------------------------------------------------------------+
void CDetector::UpdateSeries() {
    // Copy price data
    int bars = MathMax(200, m_lookbackSwing + 50);
    CopyHigh(m_symbol, m_timeframe, 0, bars, m_high);
    CopyLow(m_symbol, m_timeframe, 0, bars, m_low);
    CopyOpen(m_symbol, m_timeframe, 0, bars, m_open);
    CopyClose(m_symbol, m_timeframe, 0, bars, m_close);
    CopyBuffer(m_atrHandle, 0, 0, 60, m_atr);
}

//+------------------------------------------------------------------+
//| Check if index is a swing high                                   |
//+------------------------------------------------------------------+
bool CDetector::IsSwingHigh(int index, int K) {
    if(index < K || index >= ArraySize(m_high) - K) return false;
    
    double h = m_high[index];
    for(int k = 1; k <= K; k++) {
        if(h <= m_high[index - k] || h <= m_high[index + k])
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Check if index is a swing low                                    |
//+------------------------------------------------------------------+
bool CDetector::IsSwingLow(int index, int K) {
    if(index < K || index >= ArraySize(m_low) - K) return false;
    
    double l = m_low[index];
    for(int k = 1; k <= K; k++) {
        if(l >= m_low[index - k] || l >= m_low[index + k])
            return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Find last swing high within lookback                             |
//+------------------------------------------------------------------+
Swing CDetector::FindLastSwingHigh(int lookback) {
    Swing sw;
    sw.index = -1;
    sw.price = 0;
    sw.time = 0;
    
    for(int i = m_fractalK + 1; i < lookback && i < ArraySize(m_high); i++) {
        if(IsSwingHigh(i, m_fractalK)) {
            sw.index = i;
            sw.price = m_high[i];
            sw.time = iTime(m_symbol, m_timeframe, i);
            break;
        }
    }
    return sw;
}

//+------------------------------------------------------------------+
//| Find last swing low within lookback                              |
//+------------------------------------------------------------------+
Swing CDetector::FindLastSwingLow(int lookback) {
    Swing sw;
    sw.index = -1;
    sw.price = 0;
    sw.time = 0;
    
    for(int i = m_fractalK + 1; i < lookback && i < ArraySize(m_low); i++) {
        if(IsSwingLow(i, m_fractalK)) {
            sw.index = i;
            sw.price = m_low[i];
            sw.time = iTime(m_symbol, m_timeframe, i);
            break;
        }
    }
    return sw;
}

//+------------------------------------------------------------------+
//| Detect Break of Structure (BOS/CHOCH)                            |
//+------------------------------------------------------------------+
BOSSignal CDetector::DetectBOS() {
    BOSSignal bos;
    bos.direction = 0;
    bos.valid = false;
    bos.barsAge = 0;
    bos.ttl = m_bos_TTL;
    
    if(ArraySize(m_close) < m_lookbackSwing || ArraySize(m_atr) == 0) return bos;
    
    double currentClose = m_close[0];
    double currentOpen = m_open[0];
    double bodySize = MathAbs(currentClose - currentOpen);
    double atrValue = m_atr[0];
    
    // Check for bullish BOS
    Swing lastSwingHigh = FindLastSwingHigh(m_lookbackSwing);
    if(lastSwingHigh.index > 0) {
        double breakDistance = (currentClose - lastSwingHigh.price) / _Point;
        if(currentClose > lastSwingHigh.price && 
           breakDistance >= m_minBreakPts &&
           bodySize >= m_minBodyATR * atrValue) {
            bos.direction = 1;
            bos.breakLevel = lastSwingHigh.price;
            bos.detectedTime = TimeCurrent();
            bos.valid = true;
            return bos;
        }
    }
    
    // Check for bearish BOS
    Swing lastSwingLow = FindLastSwingLow(m_lookbackSwing);
    if(lastSwingLow.index > 0) {
        double breakDistance = (lastSwingLow.price - currentClose) / _Point;
        if(currentClose < lastSwingLow.price && 
           breakDistance >= m_minBreakPts &&
           bodySize >= m_minBodyATR * atrValue) {
            bos.direction = -1;
            bos.breakLevel = lastSwingLow.price;
            bos.detectedTime = TimeCurrent();
            bos.valid = true;
            return bos;
        }
    }
    
    return bos;
}

//+------------------------------------------------------------------+
//| Detect Liquidity Sweep                                           |
//+------------------------------------------------------------------+
SweepSignal CDetector::DetectSweep() {
    SweepSignal sweep;
    sweep.detected = false;
    sweep.valid = false;
    sweep.side = 0;
    sweep.barsAge = 0;
    sweep.ttl = m_sweep_TTL;
    
    if(ArraySize(m_high) < m_lookbackLiq + 4) return sweep;
    
    // Find max high and min low in lookback (starting from bar 4)
    double maxHigh = m_high[4];
    double minLow = m_low[4];
    for(int i = 5; i <= m_lookbackLiq + 4; i++) {
        if(m_high[i] > maxHigh) maxHigh = m_high[i];
        if(m_low[i] < minLow) minLow = m_low[i];
    }
    
    // Scan bars 0-3 for recent sweep
    for(int bar = 0; bar <= 3; bar++) {
        double currentHigh = m_high[bar];
        double currentLow = m_low[bar];
        double currentClose = m_close[bar];
        double currentOpen = m_open[bar];
        double candleRange = currentHigh - currentLow;
        
        if(candleRange <= 0) continue;
        
        // Check for buy-side sweep (high sweep)
        double upperWick = currentHigh - MathMax(currentClose, currentOpen);
        double upperWickPct = (upperWick / candleRange) * 100.0;
        
        if(currentHigh > maxHigh && 
           (currentClose <= maxHigh || upperWickPct >= m_minWickPct)) {
            sweep.detected = true;
            sweep.valid = true;
            sweep.side = 1; // buy-side
            sweep.level = currentHigh;
            sweep.time = iTime(m_symbol, m_timeframe, bar);
            return sweep;
        }
        
        // Check for sell-side sweep (low sweep)
        double lowerWick = MathMin(currentClose, currentOpen) - currentLow;
        double lowerWickPct = (lowerWick / candleRange) * 100.0;
        
        if(currentLow < minLow && 
           (currentClose >= minLow || lowerWickPct >= m_minWickPct)) {
            sweep.detected = true;
            sweep.valid = true;
            sweep.side = -1; // sell-side
            sweep.level = currentLow;
            sweep.time = iTime(m_symbol, m_timeframe, bar);
            return sweep;
        }
    }
    
    return sweep;
}

//+------------------------------------------------------------------+
//| Find Order Block in specified direction                          |
//+------------------------------------------------------------------+
OrderBlock CDetector::FindOB(int direction) {
    OrderBlock ob;
    ob.valid = false;
    ob.direction = direction;
    ob.touches = 0;
    ob.barsAge = 0;
    ob.ttl = m_ob_TTL;
    
    if(direction == 0 || ArraySize(m_close) < 80) return ob;
    
    // Find last opposite color candle before displacement
    if(direction == -1) {
        // Looking for bearish OB (supply) - last bullish candle before drop
        for(int i = 5; i < 80 && i < ArraySize(m_close); i++) {
            if(m_close[i] > m_open[i]) { // Bullish candle
                // Check if followed by displacement down
                if(i > 1 && m_close[i-1] < m_low[i+1]) {
                    ob.valid = true;
                    ob.priceBottom = m_open[i];
                    ob.priceTop = m_high[i];
                    ob.createdTime = iTime(m_symbol, m_timeframe, i);
                    
                    // Count touches
                    for(int j = i - 1; j >= 0; j--) {
                        if(m_low[j] <= ob.priceTop && m_high[j] >= ob.priceBottom) {
                            ob.touches++;
                        }
                    }
                    break;
                }
            }
        }
    } else if(direction == 1) {
        // Looking for bullish OB (demand) - last bearish candle before rally
        for(int i = 5; i < 80 && i < ArraySize(m_close); i++) {
            if(m_close[i] < m_open[i]) { // Bearish candle
                // Check if followed by displacement up
                if(i > 1 && m_close[i-1] > m_high[i+1]) {
                    ob.valid = true;
                    ob.priceBottom = m_low[i];
                    ob.priceTop = m_close[i];
                    ob.createdTime = iTime(m_symbol, m_timeframe, i);
                    
                    // Count touches
                    for(int j = i - 1; j >= 0; j--) {
                        if(m_low[j] <= ob.priceTop && m_high[j] >= ob.priceBottom) {
                            ob.touches++;
                        }
                    }
                    break;
                }
            }
        }
    }
    
    // Invalidate if too many touches
    if(ob.touches >= m_ob_MaxTouches) {
        ob.valid = false;
    }
    
    // Check for invalidation by close beyond buffer
    if(ob.valid) {
        double buffer = m_ob_BufferInvPts * _Point;
        if(direction == -1 && m_close[0] > ob.priceTop + buffer) {
            ob.valid = false;
        } else if(direction == 1 && m_close[0] < ob.priceBottom - buffer) {
            ob.valid = false;
        }
    }
    
    return ob;
}

//+------------------------------------------------------------------+
//| Find Fair Value Gap in specified direction                       |
//+------------------------------------------------------------------+
FVGSignal CDetector::FindFVG(int direction) {
    FVGSignal fvg;
    fvg.valid = false;
    fvg.direction = direction;
    fvg.fillPct = 0;
    fvg.state = 0;
    fvg.barsAge = 0;
    fvg.ttl = m_fvg_TTL;
    
    if(direction == 0 || ArraySize(m_high) < 10) return fvg;
    
    double minGapSize = m_fvg_MinPts * _Point;
    
    // Scan recent candles for FVG
    for(int i = 2; i < 60 && i < ArraySize(m_high) - 2; i++) {
        if(direction == 1) {
            // Bullish FVG: Low[i] > High[i+2]
            double gapSize = m_low[i] - m_high[i+2];
            if(gapSize >= minGapSize) {
                fvg.valid = true;
                fvg.priceBottom = m_high[i+2];
                fvg.priceTop = m_low[i];
                fvg.createdTime = iTime(m_symbol, m_timeframe, i);
                
                // Calculate fill percentage
                double gapFilled = 0;
                for(int j = i - 1; j >= 0; j--) {
                    if(m_low[j] <= fvg.priceTop) {
                        double fillLevel = MathMin(m_low[j], fvg.priceTop);
                        gapFilled = MathMax(gapFilled, fvg.priceTop - fillLevel);
                    }
                }
                fvg.fillPct = (gapFilled / gapSize) * 100.0;
                
                // Determine state
                if(fvg.fillPct < m_fvg_MitigatePct) {
                    fvg.state = 0; // Valid
                } else if(fvg.fillPct < m_fvg_CompletePct) {
                    fvg.state = 1; // Mitigated
                } else {
                    fvg.state = 2; // Completed
                    fvg.valid = false;
                }
                break;
            }
        } else if(direction == -1) {
            // Bearish FVG: High[i] < Low[i+2]
            double gapSize = m_low[i+2] - m_high[i];
            if(gapSize >= minGapSize) {
                fvg.valid = true;
                fvg.priceBottom = m_high[i];
                fvg.priceTop = m_low[i+2];
                fvg.createdTime = iTime(m_symbol, m_timeframe, i);
                
                // Calculate fill percentage
                double gapFilled = 0;
                for(int j = i - 1; j >= 0; j--) {
                    if(m_high[j] >= fvg.priceBottom) {
                        double fillLevel = MathMax(m_high[j], fvg.priceBottom);
                        gapFilled = MathMax(gapFilled, fillLevel - fvg.priceBottom);
                    }
                }
                fvg.fillPct = (gapFilled / gapSize) * 100.0;
                
                // Determine state
                if(fvg.fillPct < m_fvg_MitigatePct) {
                    fvg.state = 0; // Valid
                } else if(fvg.fillPct < m_fvg_CompletePct) {
                    fvg.state = 1; // Mitigated
                } else {
                    fvg.state = 2; // Completed
                    fvg.valid = false;
                }
                break;
            }
        }
    }
    
    // Check for invalidation by close beyond opposite edge
    if(fvg.valid) {
        double buffer = m_fvg_BufferInvPt * _Point;
        if(direction == 1 && m_close[0] < fvg.priceBottom - buffer) {
            fvg.valid = false;
        } else if(direction == -1 && m_close[0] > fvg.priceTop + buffer) {
            fvg.valid = false;
        }
    }
    
    return fvg;
}

//+------------------------------------------------------------------+
//| Detect Momentum Breakout                                         |
//+------------------------------------------------------------------+
MomentumSignal CDetector::DetectMomentum() {
    MomentumSignal momo;
    momo.valid = false;
    momo.direction = 0;
    momo.consecutiveBars = 0;
    momo.barsAge = 0;
    momo.ttl = m_momo_TTL;
    momo.failedConfirm = false;
    
    if(ArraySize(m_close) < 10 || ArraySize(m_atr) == 0) return momo;
    
    double atrValue = m_atr[0];
    double minBodySize = m_momo_MinDispATR * atrValue;
    
    // Check for consecutive bullish bars
    int bullishCount = 0;
    for(int i = 0; i < 5 && i < ArraySize(m_close); i++) {
        double body = m_close[i] - m_open[i];
        if(body >= minBodySize) {
            bullishCount++;
        } else {
            break;
        }
    }
    
    if(bullishCount >= 2) {
        // Check if broke minor swing (K=2)
        Swing minorSwing;
        minorSwing.index = -1;
        for(int i = 3; i < 20 && i < ArraySize(m_high); i++) {
            if(IsSwingHigh(i, 2)) {
                minorSwing.index = i;
                minorSwing.price = m_high[i];
                break;
            }
        }
        
        if(minorSwing.index > 0 && m_close[0] > minorSwing.price) {
            momo.valid = true;
            momo.direction = 1;
            momo.consecutiveBars = bullishCount;
            momo.detectedTime = TimeCurrent();
            return momo;
        }
    }
    
    // Check for consecutive bearish bars
    int bearishCount = 0;
    for(int i = 0; i < 5 && i < ArraySize(m_close); i++) {
        double body = m_open[i] - m_close[i];
        if(body >= minBodySize) {
            bearishCount++;
        } else {
            break;
        }
    }
    
    if(bearishCount >= 2) {
        // Check if broke minor swing (K=2)
        Swing minorSwing;
        minorSwing.index = -1;
        for(int i = 3; i < 20 && i < ArraySize(m_low); i++) {
            if(IsSwingLow(i, 2)) {
                minorSwing.index = i;
                minorSwing.price = m_low[i];
                break;
            }
        }
        
        if(minorSwing.index > 0 && m_close[0] < minorSwing.price) {
            momo.valid = true;
            momo.direction = -1;
            momo.consecutiveBars = bearishCount;
            momo.detectedTime = TimeCurrent();
            return momo;
        }
    }
    
    return momo;
}

