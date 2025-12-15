//+------------------------------------------------------------------+
//|                                                    method_smc.mqh |
//|                    SMC Method - BOS+OB+FVG+Sweep                |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

#include "method_base.mqh"
#include "..\detectors.mqh"
// ═══════════════════════════════════════════════════════════
// SMC Method - Self-contained Detection & Calculation
// ═══════════════════════════════════════════════════════════
// Method tự detect, tự tính Entry/SL/TP, tự score, tự tạo PositionPlan
// Không phụ thuộc vào arbiter.mqh hay executor.mqh

//+------------------------------------------------------------------+
//| CSMCMethod - SMC Trading Method                                  |
//+------------------------------------------------------------------+
class CSMCMethod : public CMethodBase {
private:
    CDetector* m_detector;  // SMC's own detector instance
    
    // SMC-specific parameters
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
    int      m_bosRetestTolerance;
    int      m_bosRetestMinGap;
    int      m_obSweepMaxDist;
    double   m_fvgTolerance;
    int      m_fvgHTFMinSize;
    bool     m_ob_UseDynamicSize;
    int      m_ob_MinSizePts;
    double   m_ob_ATRMultiplier;
    double   m_minRR;
    
public:
    CSMCMethod();
    ~CSMCMethod();
    
    bool Init(string symbol, ENUM_TIMEFRAMES tf,
              int fractalK, int lookbackSwing, double minBodyATR, int minBreakPts, int bos_TTL,
              int lookbackLiq, double minWickPct, int sweep_TTL,
              int ob_MaxTouches, int ob_BufferInvPts, int ob_TTL, double ob_VolMultiplier,
              int fvg_MinPts, double fvg_FillMinPct, double fvg_MitigatePct,
              double fvg_CompletePct, int fvg_BufferInvPt, int fvg_TTL, int fvg_KeepSide,
              double momo_MinDispATR, int momo_FailBars, int momo_TTL,
              int bosRetestTolerance, int bosRetestMinGap,
              int obSweepMaxDist, double fvgTolerance, int fvgHTFMinSize,
              bool ob_UseDynamicSize, int ob_MinSizePts, double ob_ATRMultiplier,
              double minRR);
    
    MethodSignal Scan(const RiskGateResult &riskGate) override;
    PositionPlan CreatePositionPlan(const MethodSignal &signal) override;
    double Score(const MethodSignal &signal) override;
    
    void UpdateSeries();
    
private:
    // Internal methods for SMC-specific logic
    Candidate BuildCandidate(const BOSSignal &bos, const SweepSignal &sweep,
                             const OrderBlock &ob, const FVGSignal &fvg,
                             const MomentumSignal &momo, int mtfBias);
    double ScoreCandidate(Candidate &c);
    bool CalculateEntrySLTP(const Candidate &c, const RiskGateResult &riskGate,
                           double &entry, double &sl, double &tp, double &rr,
                           ENTRY_TYPE &entryType, string &entryReason);
    double FindTPTarget(const Candidate &c, double entry);
    double GetATR();
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CSMCMethod::CSMCMethod() {
    m_methodName = "SMC";
    m_detector = NULL;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CSMCMethod::~CSMCMethod() {
    if(CheckPointer(m_detector) == POINTER_DYNAMIC) {
        delete m_detector;
    }
}

//+------------------------------------------------------------------+
//| Initialize SMC Method                                            |
//+------------------------------------------------------------------+
bool CSMCMethod::Init(string symbol, ENUM_TIMEFRAMES tf,
                      int fractalK, int lookbackSwing, double minBodyATR, int minBreakPts, int bos_TTL,
                      int lookbackLiq, double minWickPct, int sweep_TTL,
                      int ob_MaxTouches, int ob_BufferInvPts, int ob_TTL, double ob_VolMultiplier,
                      int fvg_MinPts, double fvg_FillMinPct, double fvg_MitigatePct,
                      double fvg_CompletePct, int fvg_BufferInvPt, int fvg_TTL, int fvg_KeepSide,
                      double momo_MinDispATR, int momo_FailBars, int momo_TTL,
                      int bosRetestTolerance, int bosRetestMinGap,
                      int obSweepMaxDist, double fvgTolerance, int fvgHTFMinSize,
                      bool ob_UseDynamicSize, int ob_MinSizePts, double ob_ATRMultiplier,
                      double minRR) {
    
    m_symbol = symbol;
    m_timeframe = tf;
    
    // Store parameters
    m_fractalK = fractalK;
    m_lookbackSwing = lookbackSwing;
    m_minBodyATR = minBodyATR;
    m_minBreakPts = minBreakPts;
    m_bos_TTL = bos_TTL;
    m_lookbackLiq = lookbackLiq;
    m_minWickPct = minWickPct;
    m_sweep_TTL = sweep_TTL;
    m_ob_MaxTouches = ob_MaxTouches;
    m_ob_BufferInvPts = ob_BufferInvPts;
    m_ob_TTL = ob_TTL;
    m_ob_VolMultiplier = ob_VolMultiplier;
    m_fvg_MinPts = fvg_MinPts;
    m_fvg_FillMinPct = fvg_FillMinPct;
    m_fvg_MitigatePct = fvg_MitigatePct;
    m_fvg_CompletePct = fvg_CompletePct;
    m_fvg_BufferInvPt = fvg_BufferInvPt;
    m_fvg_TTL = fvg_TTL;
    m_fvg_KeepSide = fvg_KeepSide;
    m_momo_MinDispATR = momo_MinDispATR;
    m_momo_FailBars = momo_FailBars;
    m_momo_TTL = momo_TTL;
    m_bosRetestTolerance = bosRetestTolerance;
    m_bosRetestMinGap = bosRetestMinGap;
    m_obSweepMaxDist = obSweepMaxDist;
    m_fvgTolerance = fvgTolerance;
    m_fvgHTFMinSize = fvgHTFMinSize;
    m_ob_UseDynamicSize = ob_UseDynamicSize;
    m_ob_MinSizePts = ob_MinSizePts;
    m_ob_ATRMultiplier = ob_ATRMultiplier;
    m_minRR = minRR;
    
    // Initialize detector
    m_detector = new CDetector();
    if(!m_detector.Init(symbol, tf,
                        fractalK, lookbackSwing, minBodyATR, minBreakPts, bos_TTL,
                        lookbackLiq, minWickPct, sweep_TTL,
                        ob_MaxTouches, ob_BufferInvPts, ob_TTL, ob_VolMultiplier,
                        fvg_MinPts, fvg_FillMinPct, fvg_MitigatePct,
                        fvg_CompletePct, fvg_BufferInvPt, fvg_TTL, fvg_KeepSide,
                        momo_MinDispATR, momo_FailBars, momo_TTL,
                        bosRetestTolerance, bosRetestMinGap,
                        obSweepMaxDist, fvgTolerance, fvgHTFMinSize,
                        ob_UseDynamicSize, ob_MinSizePts, ob_ATRMultiplier)) {
        Print("❌ CSMCMethod: Failed to initialize detector");
        return false;
    }
    
    Print("✅ CSMCMethod initialized");
    return true;
}

//+------------------------------------------------------------------+
//| Update Price Series                                               |
//+------------------------------------------------------------------+
void CSMCMethod::UpdateSeries() {
    if(CheckPointer(m_detector) == POINTER_DYNAMIC) {
        m_detector.UpdateSeries();
    }
}

//+------------------------------------------------------------------+
//| Scan for SMC Signals - Self-contained Detection & Calculation   |
//+------------------------------------------------------------------+
MethodSignal CSMCMethod::Scan(const RiskGateResult &riskGate) {
    MethodSignal signal;
    signal.valid = false;
    signal.methodName = "SMC";
    signal.score = 0;
    signal.direction = 0;
    
    if(!riskGate.canTrade) {
        return signal;
    }
    
    if(CheckPointer(m_detector) != POINTER_DYNAMIC) {
        return signal;
    }
    
    // ═══════════════════════════════════════════════════════
    // STEP 1: Detect signals (SMC requires BOS + POI)
    // ═══════════════════════════════════════════════════════
    UpdateSeries();
    
    BOSSignal bos = m_detector.DetectBOS();
    if(!bos.valid) return signal;
    
    SweepSignal sweep = m_detector.DetectSweep();
    OrderBlock ob = m_detector.FindOBWithSweep(bos.direction, sweep);
    FVGSignal fvg = m_detector.FindFVG(bos.direction);
    
    // v2.1: Check FVG MTF overlap
    if(fvg.valid) {
        m_detector.CheckFVGMTFOverlap(fvg);
    }
    
    // v2.1: Update BOS retest
    m_detector.UpdateBOSRetest(bos);
    
    MomentumSignal momo = m_detector.DetectMomentum();
    int mtfBias = m_detector.GetMTFBias();
    
    // SMC requires: BOS + (OB or FVG)
    if(!ob.valid && !fvg.valid) return signal;
    
    // ═══════════════════════════════════════════════════════
    // STEP 2: Build Candidate (SMC tự build)
    // ═══════════════════════════════════════════════════════
    Candidate candidate = BuildCandidate(bos, sweep, ob, fvg, momo, mtfBias);
    
    if(!candidate.valid) return signal;
    
    // ═══════════════════════════════════════════════════════
    // STEP 3: Score candidate (SMC tự score)
    // ═══════════════════════════════════════════════════════
    double score = ScoreCandidate(candidate);
    if(score < 100.0) return signal;
    
    // ═══════════════════════════════════════════════════════
    // STEP 4: Calculate Entry/SL/TP (SMC tự tính)
    // ═══════════════════════════════════════════════════════
    signal.direction = candidate.direction;
    signal.score = score;
    
    double entry, sl, tp, rr;
    ENTRY_TYPE entryType;
    string entryReason;
    
    if(CalculateEntrySLTP(candidate, riskGate, entry, sl, tp, rr, entryType, entryReason)) {
        signal.entryPrice = entry;
        signal.slPrice = sl;
        signal.tpPrice = tp;
        signal.rr = rr;
        signal.entryType = entryType;
        signal.entryReason = entryReason;
        
        // Validate RR
        if(rr >= m_minRR) {
            // ═══════════════════════════════════════════════════
            // STEP 5: Create Position Plan
            // ═══════════════════════════════════════════════════
            signal.positionPlan = CreatePositionPlan(signal);
            
            signal.valid = true;
        }
    }
    
    return signal;
}

//+------------------------------------------------------------------+
//| Build Candidate (SMC-specific logic)                             |
//+------------------------------------------------------------------+
Candidate CSMCMethod::BuildCandidate(const BOSSignal &bos, const SweepSignal &sweep,
                                    const OrderBlock &ob, const FVGSignal &fvg,
                                    const MomentumSignal &momo, int mtfBias) {
    Candidate c;
    c.valid = false;
    c.score = 0;
    c.direction = 0;
    
    // Determine direction from BOS or Momentum
    if(bos.valid) {
        c.direction = bos.direction;
        c.hasBOS = true;
        c.bosLevel = bos.breakLevel;
        c.bosRetestCount = bos.retestCount;
        c.bosHasRetest = bos.hasRetest;
        c.bosRetestStrength = bos.retestStrength;
    } else if(momo.valid) {
        c.direction = momo.direction;
        c.hasMomo = true;
    } else {
        return c; // Need BOS or Momentum
    }
    
    // Check Sweep (opposite side)
    if(sweep.valid && sweep.detected) {
        bool sweepMatch = (c.direction == 1 && sweep.side == -1) ||
                         (c.direction == -1 && sweep.side == 1);
        if(sweepMatch) {
            c.hasSweep = true;
            c.sweepLevel = sweep.level;
            c.sweepDistanceBars = sweep.distanceBars;
            c.sweepProximityATR = sweep.proximityATR;
        }
    }
    
    // Check Order Block
    if(ob.valid && ob.direction == c.direction) {
        c.hasOB = true;
        c.poiTop = ob.priceTop;
        c.poiBottom = ob.priceBottom;
        c.obTouches = ob.touches;
        c.obWeak = ob.weak;
        c.obStrong = !ob.weak;
        c.obIsBreaker = ob.isBreaker;
        c.obHasSweep = ob.hasSweepNearby;
        c.obSweepLevel = ob.sweepLevel;
        c.obSweepDistance = ob.sweepDistancePts;
        c.obSweepQuality = ob.sweepQuality;
    }
    
    // Check FVG
    if(fvg.valid && fvg.direction == c.direction) {
        c.hasFVG = true;
        c.fvgState = fvg.state;
        c.fvgBottom = fvg.priceBottom;
        c.fvgTop = fvg.priceTop;
        c.fvgMTFOverlap = fvg.mtfOverlap;
        c.fvgHTFTop = fvg.htfFVGTop;
        c.fvgHTFBottom = fvg.htfFVGBottom;
        c.fvgOverlapRatio = fvg.overlapRatio;
        c.fvgHTFPeriod = fvg.htfPeriod;
        
        // If no OB, use FVG as POI
        if(!c.hasOB) {
            c.poiTop = fvg.priceTop;
            c.poiBottom = fvg.priceBottom;
        }
    }
    
    // Check Momentum alignment
    if(momo.valid) {
        c.hasMomo = true;
        if(momo.direction != c.direction) {
            c.momoAgainstSmc = true;
        }
    }
    
    // MTF bias
    c.mtfBias = mtfBias;
    
    // Validate candidate paths
    // Path A: BOS + (OB or FVG)
    bool pathA = c.hasBOS && (c.hasOB || c.hasFVG);
    // Path B: Sweep + (OB or FVG) + Momentum (without BOS)
    bool pathB = c.hasSweep && (c.hasOB || c.hasFVG) && c.hasMomo && !c.momoAgainstSmc;
    
    c.valid = (pathA || pathB);
    
    return c;
}

//+------------------------------------------------------------------+
//| Create Position Plan (SMC-specific strategy)                     |
//+------------------------------------------------------------------+
PositionPlan CSMCMethod::CreatePositionPlan(const MethodSignal &signal) {
    PositionPlan plan;
    plan.methodName = "SMC";
    plan.strategy = "Balanced";
    
    // ═══════════════════════════════════════════════════════
    // SMC DCA Plan: Conservative (2 levels)
    // ═══════════════════════════════════════════════════════
    plan.dcaPlan.enabled = true;
    plan.dcaPlan.maxLevels = 2;
    
    plan.dcaPlan.level1_triggerR = 0.75;      // DCA #1 tại +0.75R
    plan.dcaPlan.level1_lotMultiplier = 0.5;  // 50% original lot
    
    plan.dcaPlan.level2_triggerR = 1.5;       // DCA #2 tại +1.5R
    plan.dcaPlan.level2_lotMultiplier = 0.33; // 33% original lot
    
    plan.dcaPlan.dcaEntryType = ENTRY_MARKET; // DCA tại market price
    plan.dcaPlan.dcaEntryReason = "At current price when trigger";
    
    // ═══════════════════════════════════════════════════════
    // SMC BE Plan: Standard
    // ═══════════════════════════════════════════════════════
    plan.bePlan.enabled = true;
    plan.bePlan.triggerR = 1.0;               // BE tại +1R
    plan.bePlan.moveAllPositions = true;      // Move tất cả positions
    plan.bePlan.reason = "Standard SMC BE";
    
    // ═══════════════════════════════════════════════════════
    // SMC Trail Plan: ATR-based
    // ═══════════════════════════════════════════════════════
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

//+------------------------------------------------------------------+
//| Score Signal                                                      |
//+------------------------------------------------------------------+
double CSMCMethod::Score(const MethodSignal &signal) {
    return signal.score;
}

//+------------------------------------------------------------------+
//| Score Candidate (SMC-specific scoring)                           |
//+------------------------------------------------------------------+
double CSMCMethod::ScoreCandidate(Candidate &c) {
    if(!c.valid) return 0.0;
    
    double score = 0.0;
    
    // Base score
    if(c.hasBOS && (c.hasOB || c.hasFVG)) {
        score += 100.0;
    }
    
    // Component bonuses
    if(c.hasBOS) score += 40.0;
    if(c.hasOB) score += 35.0;
    if(c.hasFVG && c.fvgState == 0) score += 30.0;
    if(c.hasSweep) score += 25.0;
    
    // v2.1 Advanced bonuses
    if(c.hasOB && c.obHasSweep) {
        if(c.obSweepQuality >= 0.8) score += 25.0;
        else if(c.obSweepQuality >= 0.5) score += 15.0;
        else score += 10.0;
    }
    
    if(c.hasFVG && c.fvgMTFOverlap) {
        if(c.fvgOverlapRatio >= 0.7) score += 30.0;
        else if(c.fvgOverlapRatio >= 0.4) score += 20.0;
        else score += 15.0;
    }
    
    if(c.hasBOS) {
        if(c.bosRetestCount >= 2) score += 20.0;
        else if(c.bosRetestCount == 1) score += 12.0;
        else score -= 8.0;
    }
    
    // MTF alignment
    if(c.mtfBias != 0) {
        if(c.mtfBias == c.direction) score += 25.0;
        else score -= 40.0;
    }
    
    // Penalties
    if(c.hasMomo && c.momoAgainstSmc) return 0.0; // Disqualify
    if(c.hasOB && c.obTouches >= m_ob_MaxTouches) score *= 0.5;
    if(c.hasOB && c.obWeak) score -= 10.0;
    if(c.hasFVG && c.fvgState == 1) score -= 10.0;
    
    return score;
}

//+------------------------------------------------------------------+
//| Calculate Entry/SL/TP (SMC-specific)                             |
//+------------------------------------------------------------------+
bool CSMCMethod::CalculateEntrySLTP(const Candidate &c, const RiskGateResult &riskGate,
                                   double &entry, double &sl, double &tp, double &rr,
                                   ENTRY_TYPE &entryType, string &entryReason) {
    if(!c.valid) return false;
    
    double atr = GetATR();
    if(atr <= 0) return false;
    
    double buffer = 200 * _Point; // Entry buffer (20 pips for XAUUSD)
    double minStopPts = 1000 * _Point; // Min stop (100 pips)
    
    // Determine entry method
    if(c.hasFVG && c.fvgState == 0) {
        entryType = ENTRY_LIMIT;
        entry = (c.direction == 1) ? c.fvgBottom : c.fvgTop;
        entryReason = "FVG Limit Entry";
    } else if(c.hasOB && c.hasBOS && c.bosRetestCount >= 1) {
        entryType = ENTRY_LIMIT;
        entry = (c.direction == 1) ? c.poiBottom : c.poiTop;
        entryReason = "OB Retest Limit Entry";
    } else if(c.hasSweep && c.hasBOS) {
        entryType = ENTRY_STOP;
        double triggerHigh = iHigh(m_symbol, m_timeframe, 0);
        double triggerLow = iLow(m_symbol, m_timeframe, 0);
        entry = (c.direction == 1) ? (triggerHigh + buffer) : (triggerLow - buffer);
        entryReason = "Sweep+BOS Stop Entry";
    } else if(c.hasOB) {
        entryType = ENTRY_LIMIT;
        entry = (c.direction == 1) ? c.poiBottom : c.poiTop;
        entryReason = "OB Limit Entry";
    } else {
        entryType = ENTRY_STOP;
        double triggerHigh = iHigh(m_symbol, m_timeframe, 0);
        double triggerLow = iLow(m_symbol, m_timeframe, 0);
        entry = (c.direction == 1) ? (triggerHigh + buffer) : (triggerLow - buffer);
        entryReason = "Fallback Stop Entry";
    }
    
    // Calculate SL
    double structureSL = 0;
    if(c.hasSweep) {
        structureSL = (c.direction == 1) ? (c.sweepLevel - buffer) : (c.sweepLevel + buffer);
    } else if(c.hasOB) {
        structureSL = (c.direction == 1) ? (c.poiBottom - buffer) : (c.poiTop + buffer);
    } else if(c.hasFVG) {
        structureSL = (c.direction == 1) ? (c.fvgBottom - buffer) : (c.fvgTop + buffer);
    }
    
    double atrSL = (c.direction == 1) ? (entry - 2.0 * atr) : (entry + 2.0 * atr);
    double maxCapSL = (c.direction == 1) ? (entry - 3.5 * atr) : (entry + 3.5 * atr);
    
    if(c.direction == 1) {
        double preliminarySL = (structureSL > 0) ? MathMin(structureSL, atrSL) : atrSL;
        sl = MathMax(preliminarySL, maxCapSL);
        
        // Ensure minimum stop distance
        double slDistance = entry - sl;
        if(slDistance < minStopPts) {
            sl = entry - minStopPts;
        }
    } else {
        double preliminarySL = (structureSL > 0) ? MathMax(structureSL, atrSL) : atrSL;
        sl = MathMin(preliminarySL, maxCapSL);
        
        // Ensure minimum stop distance
        double slDistance = sl - entry;
        if(slDistance < minStopPts) {
            sl = entry + minStopPts;
        }
    }
    
    // Calculate TP
    tp = FindTPTarget(c, entry);
    if(tp == 0 || (c.direction == 1 && tp <= entry) || (c.direction == -1 && tp >= entry)) {
        // Fallback: MinRR-based TP
        double actualRisk = MathAbs(entry - sl);
        tp = (c.direction == 1) ? (entry + actualRisk * m_minRR) : (entry - actualRisk * m_minRR);
    }
    
    // Calculate RR
    double risk = MathAbs(entry - sl);
    double reward = MathAbs(tp - entry);
    if(risk > 0) {
        rr = reward / risk;
    } else {
        rr = 0;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Find TP Target from Structure                                    |
//+------------------------------------------------------------------+
double CSMCMethod::FindTPTarget(const Candidate &c, double entry) {
    double tp = 0;
    
    // Priority: Swing > OB > FVG
    if(c.hasOB) {
        // TP at opposite swing or OB extension
        if(c.direction == 1) {
            tp = c.poiTop + (c.poiTop - c.poiBottom) * 0.5; // OB top + 50% OB size
        } else {
            tp = c.poiBottom - (c.poiTop - c.poiBottom) * 0.5; // OB bottom - 50% OB size
        }
    } else if(c.hasFVG) {
        if(c.direction == 1) {
            tp = c.fvgTop + (c.fvgTop - c.fvgBottom) * 0.5; // FVG top + 50% FVG size
        } else {
            tp = c.fvgBottom - (c.fvgTop - c.fvgBottom) * 0.5; // FVG bottom - 50% FVG size
        }
    }
    
    return tp;
}

//+------------------------------------------------------------------+
//| Get ATR Value                                                     |
//+------------------------------------------------------------------+
double CSMCMethod::GetATR() {
    if(CheckPointer(m_detector) != POINTER_DYNAMIC) return 0;
    return m_detector.GetATR();
}

//+------------------------------------------------------------------+

