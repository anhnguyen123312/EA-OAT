//+------------------------------------------------------------------+
//|                                                      arbiter.mqh |
//|                              Signal Prioritization & Resolution  |
//+------------------------------------------------------------------+
#property copyright "SMC/ICT EA"
#property version   "1.00"
#property strict

#include "detectors.mqh"

//+------------------------------------------------------------------+
//| Candidate structure for trade decision                          |
//+------------------------------------------------------------------+
struct Candidate {
    bool     valid;
    int      direction;          // 1=long, -1=short
    double   score;
    
    // Signal components
    bool     hasBOS;
    bool     hasSweep;
    bool     hasOB;
    bool     hasFVG;
    bool     hasMomo;
    bool     momoAgainstSmc;
    
    // POI details
    int      obTouches;
    int      fvgState;           // 0=Valid, 1=Mitigated, 2=Completed
    double   poiTop;
    double   poiBottom;
    double   sweepLevel;
    
    // Entry details
    double   entryPrice;
    double   slPrice;
    double   tpPrice;
    double   rrRatio;
};

//+------------------------------------------------------------------+
//| Arbiter Class - Signal prioritization and conflict resolution   |
//+------------------------------------------------------------------+
class CArbiter {
private:
    double   m_minRR;
    int      m_obMaxTouches;
    
public:
    CArbiter();
    ~CArbiter();
    
    void Init(double minRR, int obMaxTouches);
    double ScoreCandidate(const Candidate &c);
    Candidate BuildCandidate(const BOSSignal &bos, const SweepSignal &sweep, 
                            const OrderBlock &ob, const FVGSignal &fvg, 
                            const MomentumSignal &momo, bool sessionOpen, bool spreadOK);
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
//| Initialize arbiter parameters                                    |
//+------------------------------------------------------------------+
void CArbiter::Init(double minRR, int obMaxTouches) {
    m_minRR = minRR;
    m_obMaxTouches = obMaxTouches;
}

//+------------------------------------------------------------------+
//| Score a candidate based on priority rules                        |
//+------------------------------------------------------------------+
double CArbiter::ScoreCandidate(const Candidate &c) {
    if(!c.valid) return 0.0;
    
    double score = 0.0;
    
    // Rule 1: BOS + Sweep + (OB|FVG) same direction = highest priority
    if(c.hasBOS && c.hasSweep && (c.hasOB || c.hasFVG)) {
        score += 100.0;
    }
    
    // Rule 2: FVG completed but OB valid - prioritize OB
    if(c.hasFVG && c.fvgState == 2 && c.hasOB) {
        score -= 20.0; // Reduce FVG weight
    }
    
    // Rule 3: Momentum against SMC - discard momentum
    if(c.hasMomo && c.momoAgainstSmc) {
        return 0.0; // Invalid candidate
    }
    
    // Rule 4: OB touched >= max touches - reduce size or skip
    if(c.obTouches >= m_obMaxTouches) {
        score *= 0.5; // 50% reduction
    }
    
    // Rule 5: FVG mitigated - reduce score
    if(c.fvgState == 1) { // Mitigated
        score -= 10.0;
    }
    
    // Additional scoring factors
    if(c.hasBOS) score += 30.0;
    if(c.hasSweep) score += 25.0;
    if(c.hasOB) score += 20.0;
    if(c.hasFVG && c.fvgState == 0) score += 15.0; // Valid FVG
    if(c.hasMomo && !c.momoAgainstSmc) score += 10.0;
    
    // RR bonus
    if(c.rrRatio >= 2.5) score += 10.0;
    if(c.rrRatio >= 3.0) score += 15.0;
    
    return score;
}

//+------------------------------------------------------------------+
//| Build candidate from detection signals                           |
//+------------------------------------------------------------------+
Candidate CArbiter::BuildCandidate(const BOSSignal &bos, const SweepSignal &sweep,
                                   const OrderBlock &ob, const FVGSignal &fvg,
                                   const MomentumSignal &momo, bool sessionOpen, bool spreadOK) {
    Candidate c;
    c.valid = false;
    c.direction = 0;
    c.score = 0;
    c.hasBOS = false;
    c.hasSweep = false;
    c.hasOB = false;
    c.hasFVG = false;
    c.hasMomo = false;
    c.momoAgainstSmc = false;
    c.obTouches = 0;
    c.fvgState = 0;
    c.poiTop = 0;
    c.poiBottom = 0;
    c.sweepLevel = 0;
    c.entryPrice = 0;
    c.slPrice = 0;
    c.tpPrice = 0;
    c.rrRatio = 0;
    
    // Filter checks first
    if(!sessionOpen || !spreadOK) {
        return c; // Invalid - outside session or spread too wide
    }
    
    // Check BOS
    if(bos.valid && bos.direction != 0) {
        c.hasBOS = true;
        c.direction = bos.direction;
    } else {
        return c; // Need BOS for valid setup
    }
    
    // Check Sweep
    if(sweep.valid && sweep.detected) {
        // Sweep should be opposite to BOS direction for valid setup
        // If BOS up (1), we want sell-side sweep (-1)
        // If BOS down (-1), we want buy-side sweep (1)
        if((c.direction == 1 && sweep.side == -1) || 
           (c.direction == -1 && sweep.side == 1)) {
            c.hasSweep = true;
            c.sweepLevel = sweep.level;
        }
    }
    
    // Check OB
    if(ob.valid && ob.direction == c.direction) {
        c.hasOB = true;
        c.obTouches = ob.touches;
        c.poiTop = ob.priceTop;
        c.poiBottom = ob.priceBottom;
    }
    
    // Check FVG
    if(fvg.valid && fvg.direction == c.direction) {
        c.hasFVG = true;
        c.fvgState = fvg.state;
        
        // If no OB, use FVG as POI
        if(!c.hasOB) {
            c.poiTop = fvg.priceTop;
            c.poiBottom = fvg.priceBottom;
        }
    }
    
    // Check Momentum
    if(momo.valid) {
        c.hasMomo = true;
        // Check if momentum is against SMC direction
        if(momo.direction != c.direction) {
            c.momoAgainstSmc = true;
        }
    }
    
    // Relaxed entry conditions - two paths:
    // Path A: BOS + (OB or FVG) - no sweep required
    // Path B: Sweep + (OB or FVG) + Momentum (without BOS, but momentum confirms)
    bool pathA = c.hasBOS && (c.hasOB || c.hasFVG);
    bool pathB = c.hasSweep && (c.hasOB || c.hasFVG) && c.hasMomo && !c.momoAgainstSmc;
    
    c.valid = (pathA || pathB);
    
    return c;
}

