//+------------------------------------------------------------------+
//|                                                      arbiter.mqh |
//|                   Arbitration Layer - Build & Score Candidates   |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA v2.1"
#property version   "2.10"
#property strict

#include "detectors.mqh"

//+------------------------------------------------------------------+
//| Pattern Types                                                     |
//+------------------------------------------------------------------+
enum PATTERN_TYPE {
    PATTERN_BOS_OB = 0,        // BOS + Order Block
    PATTERN_BOS_FVG = 1,       // BOS + FVG
    PATTERN_SWEEP_OB = 2,      // Sweep + OB
    PATTERN_SWEEP_FVG = 3,     // Sweep + FVG
    PATTERN_MOMO = 4,          // Momentum only
    PATTERN_CONFLUENCE = 5,    // BOS + Sweep + (OB/FVG)
    PATTERN_OTHER = 6
};

//+------------------------------------------------------------------+
//| Entry Method Types (v2.1)                                        |
//+------------------------------------------------------------------+
enum ENTRY_TYPE {
    ENTRY_STOP = 0,    // Buy/Sell Stop
    ENTRY_LIMIT = 1,   // Buy/Sell Limit
    ENTRY_MARKET = 2   // Market execution
};

//+------------------------------------------------------------------+
//| Entry Configuration (v2.1)                                       |
//+------------------------------------------------------------------+
struct EntryConfig {
    ENTRY_TYPE type;
    double price;
    string reason;
};

//+------------------------------------------------------------------+
//| Trade Candidate Structure                                        |
//+------------------------------------------------------------------+
struct Candidate {
    bool     valid;
    int      direction;         // 1=long, -1=short
    double   score;             // Priority score
    
    // Signal flags
    bool     hasBOS;
    bool     hasSweep;
    bool     hasOB;
    bool     hasFVG;
    bool     hasMomo;
    
    // POI (Point of Interest)
    double   poiTop;
    double   poiBottom;
    
    // BOS details
    double   bosLevel;
    
    // Sweep details
    double   sweepLevel;
    int      sweepDistanceBars;
    double   sweepProximityATR;
    
    // OB details
    int      obTouches;
    bool     obWeak;
    bool     obStrong;
    bool     obIsBreaker;
    // v2.1 OB Sweep
    bool     obHasSweep;
    double   obSweepLevel;
    int      obSweepDistance;
    double   obSweepQuality;
    
    // FVG details
    int      fvgState;          // 0=Valid, 1=Mitigated, 2=Completed
    double   fvgBottom;
    double   fvgTop;
    // v2.1 FVG MTF
    bool     fvgMTFOverlap;
    double   fvgHTFTop;
    double   fvgHTFBottom;
    double   fvgOverlapRatio;
    ENUM_TIMEFRAMES fvgHTFPeriod;
    
    // BOS Retest (v2.1)
    int      bosRetestCount;
    bool     bosHasRetest;
    double   bosRetestStrength;
    
    // Momentum details
    bool     momoAgainstSmc;
    
    // MTF details
    int      mtfBias;
    
    // Entry details
    double   entryPrice;
    double   slPrice;
    double   tpPrice;
    double   rrRatio;
};

//+------------------------------------------------------------------+
//| CArbiter Class                                                    |
//+------------------------------------------------------------------+
class CArbiter {
private:
    double   m_minRR;
    int      m_obMaxTouches;
    
public:
    CArbiter();
    ~CArbiter();
    
    bool Init(double minRR, int obMaxTouches);
    
    Candidate BuildCandidate(const BOSSignal &bos, const SweepSignal &sweep, 
                            const OrderBlock &ob, const FVGSignal &fvg, 
                            const MomentumSignal &momo, int mtfBias,
                            bool sessionOpen, bool spreadOK);
    
    double ScoreCandidate(Candidate &c);
    int GetPatternType(const Candidate &c);
    EntryConfig DetermineEntryMethod(const Candidate &c);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CArbiter::CArbiter() {
    m_minRR = 2.0;
    m_obMaxTouches = 3;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CArbiter::~CArbiter() {
}

//+------------------------------------------------------------------+
//| Initialize arbiter                                                |
//+------------------------------------------------------------------+
bool CArbiter::Init(double minRR, int obMaxTouches) {
    m_minRR = minRR;
    m_obMaxTouches = obMaxTouches;
    
    Print("✅ CArbiter initialized | MinRR: ", m_minRR);
    return true;
}

//+------------------------------------------------------------------+
//| Build Candidate from signals                                     |
//+------------------------------------------------------------------+
Candidate CArbiter::BuildCandidate(const BOSSignal &bos, const SweepSignal &sweep,
                                  const OrderBlock &ob, const FVGSignal &fvg,
                                  const MomentumSignal &momo, int mtfBias,
                                  bool sessionOpen, bool spreadOK) {
    Candidate c;
    c.valid = false;
    c.score = 0;
    c.direction = 0;
    c.hasBOS = false;
    c.hasSweep = false;
    c.hasOB = false;
    c.hasFVG = false;
    c.hasMomo = false;
    c.momoAgainstSmc = false;
    c.mtfBias = mtfBias;
    
    // v2.1 fields
    c.obHasSweep = false;
    c.obSweepQuality = 0.0;
    c.fvgMTFOverlap = false;
    c.fvgOverlapRatio = 0.0;
    c.bosRetestCount = 0;
    c.bosHasRetest = false;
    c.bosRetestStrength = 0.0;
    
    // Pre-filters
    if(!sessionOpen || !spreadOK) return c;
    
    // Determine direction from BOS or Momentum
    if(bos.valid) {
        c.direction = bos.direction;
        c.hasBOS = true;
        c.bosLevel = bos.breakLevel;
        // v2.1: Copy retest info
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
        
        // v2.1: OB Sweep validation
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
        
        // v2.1: FVG MTF overlap
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
    
    // Validate candidate paths
    // Path A: BOS + (OB or FVG)
    bool pathA = c.hasBOS && (c.hasOB || c.hasFVG);
    // Path B: Sweep + (OB or FVG) + Momentum (without BOS)
    bool pathB = c.hasSweep && (c.hasOB || c.hasFVG) && c.hasMomo && !c.momoAgainstSmc;
    
    c.valid = (pathA || pathB);
    
    return c;
}

//+------------------------------------------------------------------+
//| Score Candidate (v2.1 Enhanced)                                  |
//+------------------------------------------------------------------+
double CArbiter::ScoreCandidate(Candidate &c) {
    if(!c.valid) return 0.0;
    
    double score = 0.0;
    
    // ═══════════════════════════════════════════════════════════════
    // BASE SCORE
    // ═══════════════════════════════════════════════════════════════
    if(c.hasBOS && (c.hasOB || c.hasFVG)) {
        score += 100.0; // Minimum valid setup
    }
    
    // ═══════════════════════════════════════════════════════════════
    // COMPONENT BONUSES (v2.1 Enhanced)
    // ═══════════════════════════════════════════════════════════════
    if(c.hasBOS) score += 40.0;
    if(c.hasOB) score += 35.0;
    if(c.hasFVG && c.fvgState == 0) score += 30.0; // Fresh FVG
    if(c.hasSweep) score += 25.0;
    
    // ═══════════════════════════════════════════════════════════════
    // v2.1 ADVANCED BONUSES (ENABLED)
    // ═══════════════════════════════════════════════════════════════
    
    // OB SWEEP VALIDATION
    if(c.hasOB && c.obHasSweep) {
        if(c.obSweepQuality >= 0.8) {
            score += 25.0;
            Print("✨✨ OB with perfect sweep (+25)");
            
            // Sweep INSIDE OB zone (ultimate setup)
            if(c.obSweepDistance == 0) {
                score += 10.0;
                Print("⭐ Sweep INSIDE OB (+10)");
            }
        } else if(c.obSweepQuality >= 0.5) {
            score += 15.0;
            Print("✨ OB with good sweep (+15)");
        } else {
            score += 10.0;
            Print("✨ OB with sweep (+10)");
        }
    } else if(c.hasOB && !c.obHasSweep) {
        score -= 10.0;
        Print("⚠️ OB without sweep validation (-10)");
    }
    
    // FVG MTF OVERLAP
    if(c.hasFVG && c.fvgMTFOverlap) {
        if(c.fvgOverlapRatio >= 0.7) {
            score += 30.0;
            Print("✨✨ FVG perfect MTF overlap (+30)");
            
            // H4 bonus
            if(c.fvgHTFPeriod == PERIOD_H4) {
                score += 10.0;
                Print("⭐ H4 FVG confluence (+10)");
            }
        } else if(c.fvgOverlapRatio >= 0.4) {
            score += 20.0;
            Print("✨ FVG good MTF overlap (+20)");
        } else {
            score += 15.0;
            Print("✨ FVG MTF overlap (+15)");
        }
    } else if(c.hasFVG && !c.fvgMTFOverlap) {
        score -= 5.0;
        Print("⚠️ FVG without HTF support (-5)");
    }
    
    // BOS RETEST SCORING
    if(c.hasBOS) {
        if(c.bosRetestCount >= 2) {
            score += 20.0;
            Print("✨✨ BOS with 2+ retest (+20)");
            
            // OB at retest zone
            if(c.hasOB) {
                score += 10.0;
                Print("⭐ OB at retest zone (+10)");
            }
        } else if(c.bosRetestCount == 1) {
            score += 12.0;
            Print("✨ BOS with retest (+12)");
        } else {
            // No retest = direct breakout (higher risk)
            score -= 8.0;
            Print("⚠️ BOS no retest (-8)");
            
            // Require momentum confirmation
            if(!c.hasMomo) {
                score -= 10.0;
                Print("⚠️ No momentum confirmation (-10)");
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // OTHER BONUSES (v2.1)
    // ═══════════════════════════════════════════════════════════════
    
    // Momentum aligned
    if(c.hasMomo && !c.momoAgainstSmc) {
        score += 10.0;
    }
    
    // Sweep nearby bonus
    if(c.hasSweep && c.sweepDistanceBars <= 10) {
        score += 15.0;
        Print("✨ Sweep nearby ≤10 bars (+15)");
    }
    
    // MTF alignment
    if(c.mtfBias != 0) {
        if(c.mtfBias == c.direction) {
            score += 25.0;
            Print("✨ MTF aligned (+25)");
        } else {
            score -= 40.0;
            Print("⚠️ MTF counter-trend (-40)");
        }
    }
    
    // Strong OB bonus
    if(c.hasOB && c.obStrong) {
        score += 10.0;
        Print("✨ Strong OB (+10)");
    }
    
    // Fresh POI
    if((c.hasOB && c.obTouches == 0) || (c.hasFVG && c.fvgState == 0)) {
        score += 10.0;
        Print("✨ Fresh POI (+10)");
    }
    
    // ═══════════════════════════════════════════════════════════════
    // PENALTIES (v2.1)
    // ═══════════════════════════════════════════════════════════════
    
    // Momentum AGAINST SMC - DISQUALIFY
    if(c.hasMomo && c.momoAgainstSmc) {
        Print("❌ Momentum against SMC - DISQUALIFIED");
        return 0.0;
    }
    
    // OB too many touches
    if(c.hasOB && c.obTouches >= m_obMaxTouches) {
        score *= 0.5;
        Print("⚠️ OB max touches - score halved");
    }
    
    // FVG Completed but OB valid
    if(c.hasFVG && c.fvgState == 2 && c.hasOB) {
        score -= 20.0;
        Print("⚠️ FVG completed (-20)");
    }
    
    // Weak OB
    if(c.hasOB && c.obWeak && !c.obStrong) {
        score -= 10.0;
        Print("⚠️ Weak OB (-10)");
    }
    
    // Breaker block
    if(c.hasOB && c.obIsBreaker) {
        score -= 10.0;
        Print("⚠️ Breaker block (-10)");
    }
    
    // Mitigated FVG
    if(c.hasFVG && c.fvgState == 1) {
        score -= 10.0;
        Print("⚠️ FVG mitigated (-10)");
    }
    
    return score;
}

//+------------------------------------------------------------------+
//| Determine Entry Method (v2.1)                                    |
//+------------------------------------------------------------------+
EntryConfig CArbiter::DetermineEntryMethod(const Candidate &c) {
    EntryConfig entry;
    entry.type = ENTRY_STOP;
    entry.price = 0;
    entry.reason = "";
    
    // PRIORITY 1: FVG → LIMIT (best RR)
    if(c.hasFVG && c.fvgState == 0) {
        entry.type = ENTRY_LIMIT;
        if(c.direction == 1) {
            entry.price = c.fvgBottom;
        } else {
            entry.price = c.fvgTop;
        }
        entry.reason = "FVG Limit Entry (Optimal RR)";
        return entry;
    }
    
    // PRIORITY 2: OB with Retest → LIMIT
    if(c.hasOB && c.hasBOS && c.bosRetestCount >= 1) {
        entry.type = ENTRY_LIMIT;
        if(c.direction == 1) {
            entry.price = c.poiBottom;
        } else {
            entry.price = c.poiTop;
        }
        entry.reason = "OB Retest Limit Entry";
        return entry;
    }
    
    // PRIORITY 3: Sweep + BOS → STOP (momentum)
    if(c.hasSweep && c.hasBOS) {
        entry.type = ENTRY_STOP;
        entry.reason = "Sweep+BOS Stop Entry (Momentum)";
        return entry;
    }
    
    // PRIORITY 4: BOS only (CHOCH) → STOP
    if(c.hasBOS && !c.hasOB && !c.hasFVG) {
        entry.type = ENTRY_STOP;
        entry.reason = "CHOCH Stop Entry";
        return entry;
    }
    
    // DEFAULT: OB → LIMIT
    if(c.hasOB) {
        entry.type = ENTRY_LIMIT;
        if(c.direction == 1) {
            entry.price = c.poiBottom;
        } else {
            entry.price = c.poiTop;
        }
        entry.reason = "OB Limit Entry (Default)";
        return entry;
    }
    
    // FALLBACK: STOP order
    entry.type = ENTRY_STOP;
    entry.reason = "Fallback Stop Entry";
    return entry;
}

//+------------------------------------------------------------------+
//| Get Pattern Type                                                 |
//+------------------------------------------------------------------+
int CArbiter::GetPatternType(const Candidate &c) {
    // Confluence: BOS + Sweep + (OB or FVG)
    if(c.hasBOS && c.hasSweep && (c.hasOB || c.hasFVG)) {
        return PATTERN_CONFLUENCE;
    }
    
    // BOS + OB
    if(c.hasBOS && c.hasOB && !c.hasFVG) {
        return PATTERN_BOS_OB;
    }
    
    // BOS + FVG
    if(c.hasBOS && c.hasFVG && !c.hasOB) {
        return PATTERN_BOS_FVG;
    }
    
    // Sweep + OB
    if(c.hasSweep && c.hasOB && !c.hasFVG) {
        return PATTERN_SWEEP_OB;
    }
    
    // Sweep + FVG
    if(c.hasSweep && c.hasFVG && !c.hasOB) {
        return PATTERN_SWEEP_FVG;
    }
    
    // Momentum only
    if(c.hasMomo && !c.hasBOS) {
        return PATTERN_MOMO;
    }
    
    return PATTERN_OTHER;
}

