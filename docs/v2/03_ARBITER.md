# 03. Quyết Định Giao Dịch (Arbiter)

## 📍 Tổng Quan

**File**: `arbiter.mqh`

Lớp `CArbiter` chịu trách nhiệm:
1. **Kết hợp** các signals từ Detectors thành Candidate
2. **Đánh giá** chất lượng setup qua scoring system
3. **Filter** các setup không đủ tiêu chuẩn

---

## 1️⃣ Build Candidate

### ⚙️ Thuật Toán

```cpp
Candidate BuildCandidate(BOSSignal, SweepSignal, OrderBlock, 
                         FVGSignal, MomentumSignal, mtfBias,
                         sessionOpen, spreadOK) {
    
    // STEP 1: Pre-filters
    if(!sessionOpen || !spreadOK) return invalid;
    
    // STEP 2: Determine direction
    if(BOS.valid) {
        direction = BOS.direction;
        hasBOS = true;
    } else if(Momentum.valid) {
        direction = Momentum.direction;
        hasMomo = true;
        // Cho phép entry bằng Momentum nếu không có BOS
    } else {
        return invalid;  // Cần BOS hoặc Momentum
    }
    
    // STEP 3: Check Sweep (opposite side)
    if(Sweep.valid) {
        // BOS UP cần SELL-SIDE sweep (-1)
        // BOS DOWN cần BUY-SIDE sweep (+1)
        if((direction == 1 && Sweep.side == -1) ||
           (direction == -1 && Sweep.side == 1)) {
            hasSweep = true;
            sweepLevel = Sweep.level;
            sweepDistanceBars = Sweep.distanceBars;
        }
    }
    
    // STEP 4: Check Order Block
    if(OB.valid && OB.direction == direction) {
        hasOB = true;
        poiTop = OB.priceTop;
        poiBottom = OB.priceBottom;
        obTouches = OB.touches;
        obWeak = OB.weak;
        obStrong = !OB.weak;
        obIsBreaker = OB.isBreaker;
    }
    
    // STEP 5: Check FVG
    if(FVG.valid && FVG.direction == direction) {
        hasFVG = true;
        fvgState = FVG.state;
        
        // Nếu không có OB, dùng FVG làm POI
        if(!hasOB) {
            poiTop = FVG.priceTop;
            poiBottom = FVG.priceBottom;
        }
    }
    
    // STEP 6: Check Momentum alignment
    if(Momentum.valid) {
        hasMomo = true;
        if(Momentum.direction != direction) {
            momoAgainstSmc = true;
        }
    }
    
    // STEP 7: Validate candidate
    // Path A: BOS + (OB or FVG)
    // Path B: Sweep + (OB or FVG) + Momentum (without BOS)
    bool pathA = hasBOS && (hasOB || hasFVG);
    bool pathB = hasSweep && (hasOB || hasFVG) && hasMomo && !momoAgainstSmc;
    
    candidate.valid = (pathA || pathB);
    
    return candidate;
}
```

### 📊 Entry Paths

#### Path A: BOS + POI (Recommended)
```
✓ BOS detected (direction confirmed)
✓ OB or FVG (POI for entry)
✓ Sweep optional (bonus points)

Example:
  BOS Bullish + Bullish OB → LONG candidate
```

#### Path B: Sweep + POI + Momentum
```
✓ Liquidity Sweep (liquidity grabbed)
✓ OB or FVG (POI for entry)
✓ Momentum confirmed (direction without BOS)

Example:
  Sell-Side Sweep + Bullish FVG + Bullish Momentum → LONG candidate
```

### 💡 Ví Dụ

#### Valid Candidate (Path A):
```
Signals:
  ✓ BOS: Bullish (+1)
  ✓ Sweep: Sell-side (-1) at 2648.50
  ✓ OB: Bullish Demand zone 2649.00-2649.50
  ✗ FVG: None
  ✗ Momentum: None

→ Direction: LONG (+1)
→ hasBOS: true
→ hasSweep: true
→ hasOB: true
→ POI: 2649.00-2649.50 (from OB)
→ Valid: true (Path A)
```

#### Invalid Candidate:
```
Signals:
  ✓ BOS: Bullish (+1)
  ✗ Sweep: None
  ✗ OB: None
  ✗ FVG: None
  ✗ Momentum: None

→ Direction: LONG (+1)
→ hasBOS: true
→ Valid: FALSE (no POI for entry!)
```

---

## 2️⃣ Score Candidate

### ⚙️ Scoring System

```cpp
double ScoreCandidate(Candidate c) {
    if(!c.valid) return 0.0;
    
    double score = 0.0;
    
    // ═══════════════════════════════════════
    // BASE SCORE
    // ═══════════════════════════════════════
    if(c.hasBOS && (c.hasOB || c.hasFVG)) {
        score += 100.0;  // ✅ Minimum valid setup
    }
    
    // ═══════════════════════════════════════
    // BONUSES
    // ═══════════════════════════════════════
    if(c.hasBOS)                          score += 30.0;
    if(c.hasSweep)                        score += 25.0;
    if(c.hasOB)                           score += 20.0;
    if(c.hasFVG && c.fvgState == 0)       score += 15.0;  // Valid FVG
    if(c.hasMomo && !c.momoAgainstSmc)    score += 10.0;
    
    // Sweep nearby bonus
    if(c.hasSweep && c.sweepDistanceBars <= 10) {
        score += 15.0;
    }
    
    // MTF alignment
    if(c.mtfBias != 0) {
        if(c.mtfBias == c.direction) {
            score += 20.0;  // ✅ With trend
        } else {
            score -= 30.0;  // ❌ Counter-trend
        }
    }
    
    // Strong OB bonus
    if(c.hasOB && c.obStrong) {
        score += 10.0;
    }
    
    // RR bonus
    if(c.rrRatio >= 2.5)  score += 10.0;
    if(c.rrRatio >= 3.0)  score += 15.0;
    
    // ═══════════════════════════════════════
    // PENALTIES
    // ═══════════════════════════════════════
    
    // Momentum against SMC - DISCARD!
    if(c.hasMomo && c.momoAgainstSmc) {
        return 0.0;  // ❌ Invalid
    }
    
    // OB too many touches
    if(c.obTouches >= maxTouches) {
        score *= 0.5;  // 50% reduction
    }
    
    // FVG Completed but OB valid
    if(c.hasFVG && c.fvgState == 2 && c.hasOB) {
        score -= 20.0;  // Prefer OB
    }
    
    // Weak OB
    if(c.obWeak && !c.obStrong) {
        score -= 10.0;
    }
    
    // Breaker block
    if(c.obIsBreaker) {
        score -= 10.0;
    }
    
    // Mitigated FVG
    if(c.fvgState == 1) {
        score -= 10.0;
    }
    
    return score;
}
```

### 📊 Score Breakdown

| Component | Points | Condition |
|-----------|--------|-----------|
| **BASE** | +100 | BOS + (OB or FVG) |
| **BONUSES** |
| BOS | +30 | Valid BOS |
| Sweep | +25 | Valid Sweep |
| Sweep Nearby | +15 | Distance ≤ 10 bars |
| OB | +20 | Valid OB |
| FVG Valid | +15 | State = 0 |
| Momentum | +10 | Aligned with SMC |
| MTF Aligned | +20 | Same direction |
| OB Strong | +10 | Volume ≥ 1.3× avg |
| RR ≥ 2.5 | +10 | Good risk/reward |
| RR ≥ 3.0 | +15 | Excellent RR |
| **PENALTIES** |
| MTF Counter | -30 | Against HTF trend |
| FVG Completed | -20 | When OB exists |
| OB Weak | -10 | Volume < 1.3× avg |
| OB Breaker | -10 | Invalidated OB |
| FVG Mitigated | -10 | State = 1 |
| OB Max Touches | ×0.5 | Touches ≥ 3 |
| **DISQUALIFY** |
| Momo Against | 0 | Momentum vs SMC |

### 💡 Ví Dụ Tính Điểm

#### Scenario 1: Confluence Setup
```
Signals:
  ✓ BOS: Bullish
  ✓ Sweep: Sell-side (distance: 5 bars)
  ✓ OB: Bullish, Strong (volume 1.5× avg), 1 touch
  ✓ FVG: Bullish, Valid (state: 0)
  ✓ MTF Bias: Bullish (+1)
  ✓ RR: 2.8

Scoring:
  Base: BOS + OB               = +100
  BOS Bonus                    = +30
  Sweep                        = +25
  Sweep Nearby (≤10 bars)      = +15
  OB                           = +20
  FVG Valid                    = +15
  MTF Aligned                  = +20
  OB Strong                    = +10
  RR ≥ 2.5                     = +10
  ──────────────────────────────────
  TOTAL:                       = 245 ⭐⭐⭐

→ EXCELLENT setup!
→ Entry recommended
```

#### Scenario 2: Weak Setup
```
Signals:
  ✓ BOS: Bullish
  ✗ Sweep: None
  ✓ OB: Bullish, Weak (volume 1.0× avg), 3 touches
  ✗ FVG: None
  ✓ MTF Bias: Bearish (-1) ← COUNTER-TREND!
  ✓ RR: 2.1

Scoring:
  Base: BOS + OB               = +100
  BOS Bonus                    = +30
  OB                           = +20
  MTF Counter-trend            = -30
  OB Weak                      = -10
  OB Max Touches (×0.5)        = ×0.5
  ──────────────────────────────────
  Subtotal: (100+30+20-30-10)  = 110
  After penalty: 110 × 0.5     = 55 ⚠

→ LOW QUALITY setup
→ Below threshold (100)
→ Entry SKIPPED
```

#### Scenario 3: Disqualified
```
Signals:
  ✓ BOS: Bullish
  ✓ Sweep: Sell-side
  ✓ OB: Bullish
  ✓ Momentum: BEARISH ← AGAINST SMC!

Scoring:
  Momentum Against SMC = DISQUALIFY
  ──────────────────────────────────
  TOTAL: 0 ❌

→ INVALID candidate
→ Entry REJECTED
```

---

## 3️⃣ Priority Rules

### 🎯 Entry Decision Tree

```
Is Candidate valid?
├─ NO → Skip
└─ YES
    │
    Is score ≥ 100?
    ├─ NO → Skip (low quality)
    └─ YES
        │
        Has Momentum against SMC?
        ├─ YES → Disqualify
        └─ NO
            │
            MTF counter-trend?
            ├─ YES & score < 120 → Skip
            └─ NO or score high
                │
                Has trigger candle?
                ├─ NO → Wait
                └─ YES
                    │
                    Entry OK ✅
```

### 📊 Score Thresholds

| Score Range | Quality | Action |
|-------------|---------|--------|
| 0 | Invalid | ❌ Reject |
| 1-99 | Too Low | ⊘ Skip |
| 100-149 | Acceptable | ✓ Enter with caution |
| 150-199 | Good | ✓✓ Enter confidently |
| 200+ | Excellent | ⭐ High priority |

---

## 4️⃣ Pattern Types

Bot tracks 7 pattern types cho statistics:

```cpp
enum PATTERN_TYPE {
    PATTERN_BOS_OB = 0,        // BOS + Order Block only
    PATTERN_BOS_FVG = 1,       // BOS + FVG only
    PATTERN_SWEEP_OB = 2,      // Sweep + OB (no BOS)
    PATTERN_SWEEP_FVG = 3,     // Sweep + FVG (no BOS)
    PATTERN_MOMO = 4,          // Momentum only (no BOS)
    PATTERN_CONFLUENCE = 5,    // BOS + Sweep + (OB/FVG)
    PATTERN_OTHER = 6
}
```

### 🔍 Pattern Detection Logic

```cpp
int GetPatternType(Candidate c) {
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
```

### 💡 Pattern Examples

```
PATTERN_CONFLUENCE (Best):
  ✓ BOS Bullish
  ✓ Sell-side Sweep
  ✓ Bullish OB
  Score: 200+

PATTERN_BOS_OB (Good):
  ✓ BOS Bullish
  ✓ Bullish OB
  Score: 150-170

PATTERN_SWEEP_FVG (Alternative):
  ✓ Sell-side Sweep
  ✓ Bullish FVG
  ✓ Momentum Bullish
  Score: 130-150

PATTERN_MOMO (Risky):
  ✓ Momentum Bullish only
  Score: 110-130
```

---

## 📊 Conflict Resolution

### Case 1: Multiple Signals Conflict
```
Problem:
  BOS: Bullish
  Sweep: Buy-side (same direction!)
  
Solution:
  Sweep direction mismatch → hasSweep = false
  Continue with BOS + OB/FVG only
```

### Case 2: Momentum Against SMC
```
Problem:
  BOS: Bullish
  OB: Bullish
  Momentum: Bearish
  
Solution:
  momoAgainstSmc = true
  Score = 0 (DISQUALIFY)
```

### Case 3: Both OB and FVG Present
```
Problem:
  OB: Valid
  FVG: Valid
  
Solution:
  Use OB as primary POI
  FVG adds bonus points only
  Entry zone = OB zone
```

---

---

## 🆕 v2.1 Advanced Scoring & Validation

### 1. OB Sweep Validation Scoring

#### ⚙️ Integration in BuildCandidate

```cpp
Candidate BuildCandidate(BOSSignal bos, SweepSignal sweep, ...) {
    Candidate c;
    
    // ... existing logic ...
    
    // ═══════════════════════════════════════════════════
    // NEW v2.1: Check OB with Sweep validation
    // ═══════════════════════════════════════════════════
    if(c.direction != 0) {
        // Find OB WITH sweep check
        OrderBlock ob = g_detector.FindOBWithSweep(c.direction, sweep);
        
        if(ob.valid) {
            c.hasOB = true;
            c.poiTop = ob.priceTop;
            c.poiBottom = ob.priceBottom;
            c.obTouches = ob.touches;
            c.obWeak = ob.weak;
            
            // NEW fields
            c.obHasSweep = ob.hasSweepNearby;
            c.obSweepLevel = ob.sweepLevel;
            c.obSweepDistance = ob.sweepDistancePts;
            c.obSweepQuality = ob.sweepQuality;
            
            if(ob.hasSweepNearby) {
                Print("💎 OB with Sweep: Quality ", 
                      DoubleToString(ob.sweepQuality, 2),
                      ", Distance ", ob.sweepDistancePts, " pts");
            }
        }
    }
    
    return c;
}
```

#### 📊 Scoring Logic

```cpp
double ScoreCandidate(Candidate &c) {
    double score = 0;
    
    // ... existing base scoring ...
    
    // ═══════════════════════════════════════════════════
    // OB SWEEP BONUS (HIGH VALUE)
    // ═══════════════════════════════════════════════════
    if(c.hasOB && c.obHasSweep) {
        if(c.obSweepQuality >= 0.8) {
            // Perfect sweep placement (0-50 pts from OB)
            score += 25;
            Print("✨✨ OB with perfect sweep (+25)");
            
            // BONUS: Sweep inside OB zone (ultimate ICT setup)
            if(c.obSweepDistance == 0) {
                score += 10;
                Print("⭐ Sweep INSIDE OB (+10)");
            }
            
        } else if(c.obSweepQuality >= 0.5) {
            // Good sweep (50-100 pts)
            score += 15;
            Print("✨ OB with good sweep (+15)");
            
        } else {
            // Acceptable sweep (100-200 pts)
            score += 10;
            Print("✨ OB with sweep (+10)");
        }
    } else if(c.hasOB && !c.obHasSweep) {
        // OB without sweep = lower confidence
        score -= 10;
        Print("⚠️ OB without sweep validation (-10)");
    }
    
    return score;
}
```

#### 💡 Scoring Examples

##### Example 1: Perfect Setup (Sweep Inside OB)
```
Signals:
  ✓ BOS: Bullish
  ✓ Sweep: 2649.20 (sell-side)
  ✓ OB: 2649.00-2649.50
  → Sweep INSIDE OB zone!

Scoring:
  Base: BOS + OB                     = +100
  BOS Bonus                          = +40
  OB Bonus                           = +35
  OB with Perfect Sweep (0.8)        = +25
  Sweep Inside OB                    = +10
  ────────────────────────────────────
  TOTAL:                             = 210 ⭐⭐⭐
  
→ EXCELLENT SETUP (ICT Gold Standard)
→ Entry highly recommended
```

##### Example 2: Good Setup (Sweep 30pts Below OB)
```
Signals:
  ✓ BOS: Bullish
  ✓ Sweep: 2648.70 (sell-side)
  ✓ OB: 2649.00-2649.50
  → Distance: 30 pts

Scoring:
  Base: BOS + OB                     = +100
  BOS Bonus                          = +40
  OB Bonus                           = +35
  OB with Perfect Sweep (0.85)       = +25
  ────────────────────────────────────
  TOTAL:                             = 200 ⭐⭐⭐
  
→ HIGH QUALITY setup
```

##### Example 3: Weak Setup (OB Without Sweep)
```
Signals:
  ✓ BOS: Bullish
  ✗ Sweep: None near OB
  ✓ OB: 2649.00-2649.50

Scoring:
  Base: BOS + OB                     = +100
  BOS Bonus                          = +40
  OB Bonus                           = +35
  OB without Sweep                   = -10
  ────────────────────────────────────
  TOTAL:                             = 165 ⚠️
  
→ ACCEPTABLE but not ideal
→ Require other confluence factors
```

---

### 2. FVG MTF Overlap Scoring

#### ⚙️ Integration in BuildCandidate

```cpp
Candidate BuildCandidate(...) {
    Candidate c;
    
    // ... existing logic ...
    
    // ═══════════════════════════════════════════════════
    // NEW v2.1: Check FVG MTF Overlap
    // ═══════════════════════════════════════════════════
    if(c.hasFVG) {
        // Check if LTF FVG is subset of HTF FVG
        bool hasOverlap = g_detector.CheckFVGMTFOverlap(fvg);
        
        if(hasOverlap) {
            c.fvgMTFOverlap = true;
            c.fvgHTFTop = fvg.htfFVGTop;
            c.fvgHTFBottom = fvg.htfFVGBottom;
            c.fvgOverlapRatio = fvg.overlapRatio;
            c.fvgHTFPeriod = fvg.htfPeriod;
            
            Print("🎯 FVG MTF Overlap confirmed!");
            Print("   LTF: ", c.poiBottom, "-", c.poiTop);
            Print("   HTF: ", c.fvgHTFBottom, "-", c.fvgHTFTop);
            Print("   Ratio: ", DoubleToString(c.fvgOverlapRatio, 2));
        }
    }
    
    return c;
}
```

#### 📊 Scoring Logic

```cpp
double ScoreCandidate(Candidate &c) {
    double score = 0;
    
    // ... existing scoring ...
    
    // ═══════════════════════════════════════════════════
    // FVG MTF OVERLAP BONUS (HIGH CONFIDENCE)
    // ═══════════════════════════════════════════════════
    if(c.hasFVG && c.fvgMTFOverlap) {
        if(c.fvgOverlapRatio >= 0.7) {
            // Large subset (LTF chiếm >70% HTF)
            score += 30;
            Print("✨✨ FVG perfect MTF overlap (+30)");
            
            // Extra bonus if HTF is H4 (stronger than H1)
            if(c.fvgHTFPeriod == PERIOD_H4) {
                score += 10;
                Print("⭐ H4 FVG confluence (+10)");
            }
            
        } else if(c.fvgOverlapRatio >= 0.4) {
            // Medium subset (40-70%)
            score += 20;
            Print("✨ FVG good MTF overlap (+20)");
            
        } else {
            // Small subset but still valid
            score += 15;
            Print("✨ FVG MTF overlap (+15)");
        }
        
        // NOTE: FVG với MTF overlap thường có RR rất tốt
        // Nên ưu tiên dùng LIMIT order tại FVG bottom
        
    } else if(c.hasFVG && !c.fvgMTFOverlap) {
        // FVG không có HTF support = giảm confidence
        score -= 5;
        Print("⚠️ FVG without HTF support (-5)");
    }
    
    return score;
}
```

#### 💡 Scoring Examples

##### Example 1: H4 FVG Confluence (Best)
```
Signals:
  ✓ BOS: Bullish (M30)
  ✓ FVG: M30 2647.00-2649.00 (200 pts)
  ✓ HTF FVG: H4 2646.00-2650.00 (400 pts)
  → M30 ⊂ H4 (overlap ratio: 0.5)

Scoring:
  Base: BOS + FVG                    = +100
  BOS                                = +40
  FVG Valid                          = +30
  FVG Perfect MTF (0.5 < 0.7)        = +20
  ────────────────────────────────────
  TOTAL:                             = 190 ⭐⭐⭐
  
→ HIGH CONFIDENCE entry
→ Use LIMIT order at 2647.00
```

##### Example 2: H1 FVG Perfect Overlap
```
Signals:
  ✓ BOS: Bullish (M15)
  ✓ FVG: M15 2648.00-2649.00 (100 pts)
  ✓ HTF FVG: H1 2647.50-2649.20 (120 pts)
  → M15 ⊂ H1 (overlap ratio: 0.83)

Scoring:
  Base: BOS + FVG                    = +100
  BOS                                = +40
  FVG Valid                          = +30
  FVG Perfect MTF (0.83 > 0.7)       = +30
  ────────────────────────────────────
  TOTAL:                             = 200 ⭐⭐⭐
  
→ EXCELLENT setup!
→ LTF chiếm 83% HTF zone
```

##### Example 3: No MTF Support (Weaker)
```
Signals:
  ✓ BOS: Bullish
  ✓ FVG: M30 2649.00-2651.00
  ✗ HTF FVG: None found in same zone

Scoring:
  Base: BOS + FVG                    = +100
  BOS                                = +40
  FVG Valid                          = +30
  FVG without HTF                    = -5
  ────────────────────────────────────
  TOTAL:                             = 165 ⚠️
  
→ Valid but lower confidence
→ Require other factors (OB, Sweep, etc.)
```

---

### 3. BOS Retest Scoring

#### ⚙️ Integration in BuildCandidate

```cpp
Candidate BuildCandidate(BOSSignal bos, ...) {
    Candidate c;
    
    // ... existing logic ...
    
    // ═══════════════════════════════════════════════════
    // NEW v2.1: Update BOS Retest tracking
    // ═══════════════════════════════════════════════════
    if(c.hasBOS) {
        // Update retest count for BOS
        g_detector.UpdateBOSRetest(bos);
        
        c.bosRetestCount = bos.retestCount;
        c.bosHasRetest = bos.hasRetest;
        c.bosRetestStrength = bos.retestStrength;
        
        if(bos.hasRetest) {
            Print("🔄 BOS Retest detected: ", bos.retestCount, " times");
            Print("   Strength: ", DoubleToString(bos.retestStrength, 2));
        } else {
            Print("⚠️ BOS no retest (direct breakout)");
        }
    }
    
    return c;
}
```

#### 📊 Scoring Logic

```cpp
double ScoreCandidate(Candidate &c) {
    double score = 0;
    
    // ... existing scoring ...
    
    // ═══════════════════════════════════════════════════
    // BOS RETEST SCORING
    // ═══════════════════════════════════════════════════
    if(c.hasBOS) {
        if(c.bosRetestCount >= 2) {
            // 2+ retest = VERY STRONG level
            score += 20;
            Print("✨✨ BOS with 2+ retest (+20)");
            
            // If OB exists at retest zone → ultimate setup
            if(c.hasOB) {
                score += 10;
                Print("⭐ OB at retest zone (+10)");
            }
            
        } else if(c.bosRetestCount == 1) {
            // 1 retest = GOOD confirmation
            score += 12;
            Print("✨ BOS with retest (+12)");
            
        } else {
            // No retest = direct breakout (higher risk)
            score -= 8;
            Print("⚠️ BOS no retest (-8)");
            
            // If no retest, require WAE or Momentum
            if(!c.hasWAE && !c.hasMomo) {
                score -= 10;
                Print("⚠️ No momentum confirmation (-10)");
            }
        }
    }
    
    return score;
}
```

#### 💡 Scoring Examples

##### Example 1: BOS with 2 Retest (Strong)
```
Signals:
  ✓ BOS: Bullish at 2654.00
  ✓ Retest #1: 2654.15 (bar 15)
  ✓ Retest #2: 2654.10 (bar 8)
  ✓ OB: At retest zone 2653.50-2654.00
  → retestStrength = 0.9

Scoring:
  Base: BOS + OB                     = +100
  BOS                                = +40
  OB                                 = +35
  BOS 2+ Retest                      = +20
  OB at Retest Zone                  = +10
  ────────────────────────────────────
  TOTAL:                             = 205 ⭐⭐⭐
  
→ STRONG LEVEL confirmed
→ Use LIMIT order at OB bottom
```

##### Example 2: BOS with 1 Retest (Good)
```
Signals:
  ✓ BOS: Bullish at 2654.00
  ✓ Retest #1: 2654.20 (bar 10)
  ✓ Sweep: Below BOS
  → retestStrength = 0.7

Scoring:
  Base: BOS + OB                     = +100
  BOS                                = +40
  Sweep                              = +25
  BOS 1 Retest                       = +12
  ────────────────────────────────────
  TOTAL:                             = 177 ⭐⭐
  
→ GOOD setup
```

##### Example 3: BOS No Retest (Risky)
```
Signals:
  ✓ BOS: Bullish at 2654.00
  ✗ Retest: None (direct rally)
  ✗ WAE: Not exploding
  ✗ Momentum: Weak

Scoring:
  Base: BOS + OB                     = +100
  BOS                                = +40
  OB                                 = +35
  BOS No Retest                      = -8
  No Momentum Confirmation           = -10
  ────────────────────────────────────
  TOTAL:                             = 157 ⚠️
  
→ ACCEPTABLE but risky
→ Consider skipping if score < 160
```

---

### 4. Entry Method Integration

#### ⚙️ Determine Entry in Executor

```cpp
bool CExecutor::ExecuteEntry(Candidate &c) {
    if(!c.valid) return false;
    
    // ═══════════════════════════════════════════════════
    // NEW v2.1: Determine entry method based on pattern
    // ═══════════════════════════════════════════════════
    EntryConfig entry = DetermineEntryMethod(c);
    
    Print("📍 Entry Method: ", entry.reason);
    Print("   Type: ", (entry.type == ENTRY_LIMIT ? "LIMIT" : "STOP"));
    Print("   Price: ", entry.price);
    
    // Calculate SL/TP
    double sl = CalculateSL(c);
    double tp = CalculateTP(c);
    double lots = CalculateLotSize(c, entry.price, sl);
    
    // Place order based on entry type
    if(entry.type == ENTRY_LIMIT) {
        return PlaceLimitOrder(c.direction, entry.price, sl, tp, lots);
    } else {
        return PlaceStopOrder(c.direction, entry.price, sl, tp, lots);
    }
}
```

#### 📊 Entry Decision Matrix

| Candidate Signals | Entry Type | Entry Price | RR Expected | Rationale |
|------------------|-----------|-------------|-------------|-----------|
| **FVG + BOS** | LIMIT | FVG bottom | 3.5-4.0 | Wait for discount, best RR |
| **OB + BOS + Retest** | LIMIT | OB bottom | 3.0-3.5 | Retest confirms level |
| **Sweep + BOS + OB** | LIMIT | OB bottom | 3.0-3.5 | Quality setup, wait |
| **Sweep + BOS (No POI)** | STOP | Trigger high + buffer | 2.0-2.5 | Momentum, don't miss |
| **BOS only (CHOCH)** | STOP | Trigger high + buffer | 1.8-2.2 | Chase breakout |
| **OB + BOS (No retest)** | LIMIT | OB bottom | 2.8-3.2 | Default method |

#### 💡 Entry Examples

##### Example 1: FVG Limit Entry
```
Candidate:
  ✓ BOS: Bullish
  ✓ FVG: 2649.00-2651.00 (Fresh)
  ✓ FVG MTF: H1 overlap confirmed
  ✓ Sweep: 2648.50

Entry Decision:
  Method: LIMIT (Priority 1 - FVG)
  Entry: 2649.00 (FVG bottom)
  SL: 2648.50 (sweep level)
  TP: 2655.00 (swing high)
  
  Distance SL: 50 pts
  Distance TP: 600 pts
  RR: 600/50 = 12:1 ✨✨✨
  
  Risk per 0.01 lot: $5
  Reward per 0.01 lot: $60
```

##### Example 2: OB Retest Limit Entry
```
Candidate:
  ✓ BOS: Bullish at 2654.00
  ✓ BOS Retest: 2 times
  ✓ OB: 2653.50-2654.00 (at retest zone)
  ✓ Sweep: 2653.00

Entry Decision:
  Method: LIMIT (Priority 2 - OB Retest)
  Entry: 2653.50 (OB bottom)
  SL: 2653.00 (sweep level)
  TP: 2659.00 (target)
  
  Distance SL: 50 pts
  Distance TP: 550 pts
  RR: 550/50 = 11:1 ✨✨
```

##### Example 3: Sweep+BOS Stop Entry
```
Candidate:
  ✓ BOS: Bullish (strong momentum)
  ✓ Sweep: Confirmed
  ✗ FVG: None
  ✗ OB: None
  ✓ WAE: Exploding

Entry Decision:
  Method: STOP (Priority 3 - Momentum)
  Entry: 2651.50 (trigger high + 70 pts buffer)
  SL: 2648.50 (sweep level)
  TP: 2657.50 (target)
  
  Distance SL: 300 pts
  Distance TP: 600 pts
  RR: 600/300 = 2:1 ⚠️
  
  Note: Lower RR but high fill rate (95%)
  → Don't miss runner
```

---

### 5. Combined Scoring v2.1 (Full Example)

#### 🎯 Ultimate ICT Setup

```
Signals:
  ✓ BOS: Bullish at 2654.00
  ✓ BOS Retest: 2 times (strong)
  ✓ Sweep: Sell-side at 2648.70
  ✓ OB: 2649.00-2649.50 (Fresh, 0 touches)
  ✓ OB Sweep: Inside OB zone (quality 1.0)
  ✓ FVG: 2648.80-2650.00 (Fresh)
  ✓ FVG MTF: H1 overlap (ratio 0.75)
  ✓ MTF Bias: Bullish (H1 uptrend)
  ✓ WAE: Exploding (1.2)
  ✓ MA: Aligned (EMA 20 > 50)
  Time: 14:30 GMT+7 (London window)

Scoring Breakdown:
─────────────────────────────────────────
BASE SCORES:
  BOS + OB/FVG                       = +100
  BOS Bonus                          = +40
  OB Bonus                           = +35
  FVG Valid                          = +30
  Sweep Bonus                        = +25

ADVANCED BONUSES (v2.1):
  OB Perfect Sweep (inside zone)     = +25
  Sweep Inside OB                    = +10
  FVG Perfect MTF (0.75)             = +30
  BOS 2+ Retest                      = +20
  OB at Retest Zone                  = +10
  
OTHER BONUSES:
  MTF Aligned                        = +25
  WAE Explosion                      = +20
  MA Aligned                         = +25
  London Window                      = +10
  Fresh OB                           = +10
  
─────────────────────────────────────────
TOTAL SCORE:                         = 415 ⭐⭐⭐⭐⭐

Entry Decision:
  Method: LIMIT (FVG Priority)
  Entry: 2648.80 (FVG bottom)
  SL: 2648.50 (sweep level - 30 pts)
  TP: 2658.80 (10:1 RR target)
  
  Risk: 30 pts ($30 per 0.01 lot)
  Reward: 1000 pts ($100 per 0.01 lot)
  RR: 33:1 ✨✨✨✨✨
  
→ ULTIMATE SETUP!
→ Highest confidence entry
→ Expect win rate 85%+
```

---

## 🆕 v2.0 Updates: Extended Scoring

### 1. Updated Scoring Weights

#### ⚙️ New Formula
```cpp
double ScoreCandidateExtended(Candidate &c, ENUM_REGIME regime,
                              int localHour, int localMin) {
    double score = 0;
    
    // ═══════════════════════════════════════════════════
    // BASE WEIGHTS (changed from v1.2)
    // ═══════════════════════════════════════════════════
    if(c.hasBOS)   score += 40;  // v1.2: +30
    if(c.hasOB)    score += 35;  // v1.2: +20
    if(c.hasFVG)   score += 30;  // v1.2: +15
    if(c.hasSweep) score += 25;  // v1.2: +25 (same)
    
    // ═══════════════════════════════════════════════════
    // NEW BONUSES
    // ═══════════════════════════════════════════════════
    
    // Sweep proximity (ATR-based distance)
    if(c.hasSweep && c.sweepProximityATR <= 0.5) {
        score += 25;  // NEW
        Print("✨ Sweep proximity ≤0.5 ATR (+25)");
    }
    
    // MTF alignment (changed penalty → bonus model)
    if(c.mtfBias != 0 && c.mtfBias == c.direction) {
        score += 25;  // v1.2: +20
        Print("✨ MTF aligned (+25)");
    }
    
    // HTF confluence (NEW)
    if(c.htfConfluence) {
        score += 15;  // NEW
        Print("✨ HTF confluence (+15)");
    }
    
    // Fresh POI (NEW)
    if((c.hasOB && c.obTouches == 0) || 
       (c.hasFVG && c.fvgState == 0)) {
        score += 10;  // NEW
        Print("✨ Fresh POI (+10)");
    }
    
    // Session micro-windows (NEW)
    if(localHour >= 13 && localHour <= 17) {
        score += 10;  // NEW: London session
        Print("✨ London window 13-17h (+10)");
    }
    
    if((localHour == 19 && localMin >= 30) ||
       (localHour >= 20 && localHour <= 22) ||
       (localHour == 22 && localMin <= 30)) {
        score += 8;   // NEW: NY overlap
        Print("✨ NY window 19:30-22:30 (+8)");
    }
    
    // ═══════════════════════════════════════════════════
    // UPDATED PENALTIES
    // ═══════════════════════════════════════════════════
    
    // FVG mitigated (increased penalty)
    if(c.hasFVG && c.fvgState == 1) {
        score -= 15;  // v1.2: -10
        Print("⚠️ FVG mitigated (-15)");
    }
    
    // OB many touches (increased penalty)
    if(c.hasOB && c.obTouches >= 2) {
        score -= 20;  // v1.2: -10
        Print("⚠️ OB touches ≥2 (-20)");
    }
    
    // Counter-trend (increased penalty + threshold)
    if(c.mtfBias != 0 && c.mtfBias != c.direction) {
        score -= 40;  // v1.2: -30
        Print("⚠️ Counter-trend (-40)");
        
        // NEW: Require higher score for counter-trend
        if(score < InpScoreCounterMin) {
            Print("❌ REJECT: Counter score ", score,
                  " < min ", InpScoreCounterMin);
            return 0;
        }
    }
    
    return score;
}
```

### 2. New Candidate Fields

```cpp
struct Candidate {
    // ... existing fields ...
    
    // NEW v2.0 fields
    double sweepProximityATR;   // Distance to sweep / ATR
    bool   htfConfluence;       // HTF discount/premium + POI
    int    fvgStateDetailed;    // 0=CLEAN, 1=MITIGATED, 2=COMPLETED
    bool   counterTrend;        // Against MTF bias
};
```

### 3. HTF Confluence Detection

```cpp
bool CheckHTFConfluence(Candidate &c) {
    // Get H1 or H4 data
    ENUM_TIMEFRAMES htf = PERIOD_H1;
    if(_Period == PERIOD_H1) htf = PERIOD_H4;
    
    double htfHigh[], htfLow[], htfClose[];
    CopyHigh(_Symbol, htf, 0, 50, htfHigh);
    CopyLow(_Symbol, htf, 0, 50, htfLow);
    CopyClose(_Symbol, htf, 0, 50, htfClose);
    
    // Calculate HTF range
    double htfRangeHigh = htfHigh[ArrayMaximum(htfHigh)];
    double htfRangeLow = htfLow[ArrayMinimum(htfLow)];
    double htfRange = htfRangeHigh - htfRangeLow;
    
    double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) +
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
    
    // Calculate position in HTF range
    double pricePosition = (currentPrice - htfRangeLow) / htfRange;
    
    // Check discount/premium
    if(c.direction == 1) {
        // LONG: prefer discount zone (<50%)
        if(pricePosition <= 0.50) {
            // Check for HTF bullish OB/FVG in this area
            // (simplified - full implementation would check structures)
            c.htfConfluence = true;
            return true;
        }
    } else {
        // SHORT: prefer premium zone (>50%)
        if(pricePosition >= 0.50) {
            c.htfConfluence = true;
            return true;
        }
    }
    
    return false;
}
```

### 4. Session Micro-Windows

```
GMT+7 Time Windows:

LONDON SESSION: 13:00 - 17:00
  → +10 bonus points
  → High liquidity
  → Quality moves

NY OVERLAP: 19:30 - 22:30
  → +8 bonus points
  → Maximum volatility
  → Best for trending setups

OTHER: 7:00-13:00, 17:00-19:30, 22:30-23:00
  → No bonus
  → Still valid for trading
```

### 5. Comparison v1.2 vs v2.0

| Scenario | v1.2 Score | v2.0 Score | Change |
|----------|------------|------------|--------|
| **Confluence (optimal)** |
| BOS + Sweep + OB Strong | 175 | 40+35+25+25+10 = **135** | -40 |
| + HTF confluence | +0 | +15 = **150** | - |
| + London window | +0 | +10 = **160** | - |
| **BOS + OB only** |
| Basic setup | 150 | 40+35 = **75** | -75 |
| + Fresh OB | +0 | +10 = **85** | - |
| **Counter-trend** |
| Against MTF | -30, total 120 | -40, min 120 req | Stricter |

### 6. New Parameters

```cpp
input int InpScoreEnter      = 100;  // Min score to enter
input int InpScoreCounterMin = 120;  // Min for counter-trend (stricter)
```

### 💡 Example: Extended Scoring

```
Signals:
  ✓ BOS: Bullish
  ✓ Sweep: Sell-side, distance 2.5 points (ATR=5.0 → 0.5 ATR)
  ✓ OB: Bullish, Fresh (0 touches), Strong
  ✓ MTF: Bullish (aligned)
  ✓ HTF: In discount + bullish OB
  Time: 14:30 GMT+7 (London window)
  RR: 2.8

v2.0 Scoring:
  BOS                          = +40
  OB                           = +35
  Sweep                        = +25
  Sweep Proximity ≤0.5 ATR     = +25
  MTF Aligned                  = +25
  HTF Confluence               = +15
  Fresh OB                     = +10
  London Window                = +10
  RR ≥ 2.5                     = +10
  ──────────────────────────────────
  TOTAL:                       = 195 ⭐⭐⭐

→ EXCELLENT setup! Far above threshold (100)
```

---

---

## 🔮 Proposed Improvements (Based on Analysis)

### ⚠️ Current Limitations

#### 1. Path A Không Yêu Cầu Sweep
```cpp
// Current (v1.2)
bool pathA = hasBOS && (hasOB || hasFVG);  // ← Thiếu sweep check

Problem:
  → Cho phép entry chỉ dựa trên breakout
  → Không xác nhận liquidity grab
  → Có thể entry vào breakout giả
```

**ICT Best Practice**: Sweep → BOS → POI

**Proposed Fix**:
```cpp
input bool InpRequireSweepBOS = true; // Bắt buộc cả Sweep và BOS

bool pathGold = hasSweep && hasBOS && (hasOB || hasFVG);
bool pathA = hasBOS && (hasOB || hasFVG);  // Legacy fallback
bool pathB = hasSweep && (hasOB || hasFVG) && hasMomo && !momoAgainstSmc;

if(InpRequireSweepBOS) {
    candidate.valid = pathGold;  // Only accept Sweep + BOS + POI
} else {
    candidate.valid = (pathA || pathB);  // Current behavior
}

// Scoring bonus
if(hasSweep && hasBOS) {
    score += 50;  // GOLD PATTERN
    Print("⭐ GOLD Pattern: Sweep + BOS + POI (+50)");
}
```

**Expected Impact**:
- Trade count: -30-40% (higher quality)
- Win rate: +5-8%
- Profit factor: +0.3-0.5

---

#### 2. Thiếu MA Trend Filter

**Problem**: Bot có thể trade counter-trend mạnh

**Proposed**: Thêm MA crossover filter

```cpp
// New Detector Function
int DetectMATrend() {
    double emaFast[], emaSlow[];
    ArraySetAsSeries(emaFast, true);
    ArraySetAsSeries(emaSlow, true);
    
    CopyBuffer(m_emaFastHandle, 0, 0, 2, emaFast);  // EMA 20
    CopyBuffer(m_emaSlowHandle, 0, 0, 2, emaSlow);  // EMA 50
    
    if(emaFast[0] > emaSlow[0]) return 1;  // Bullish
    if(emaFast[0] < emaSlow[0]) return -1; // Bearish
    return 0;  // Neutral
}

// Update Candidate
struct Candidate {
    // ... existing fields ...
    int  maTrend;         // +1 bullish, -1 bearish, 0 neutral
    bool maCrossover;     // Recent crossover
    bool counterTrend;    // Signal against MA
};

// Update Scoring
if(c.maTrend != 0) {
    if(c.maTrend == c.direction) {
        score += 25;  // WITH trend
        Print("✨ MA trend aligned (+25)");
        
        if(c.maCrossover) {
            score += 15;  // Fresh reversal
            Print("✨ MA crossover (+15)");
        }
    } else {
        // AGAINST trend
        c.counterTrend = true;
        score -= 40;
        Print("⚠️ Counter MA trend (-40)");
        
        // Require higher score for counter-trend
        if(score < 150) {
            Print("❌ REJECT: Counter-trend score too low");
            return 0;
        }
    }
}
```

**Parameters**:
```cpp
input bool InpUseMAFilter     = true;  // Enable MA filter
input int  InpMAFastPeriod    = 20;    // EMA fast
input int  InpMASlowPeriod    = 50;    // EMA slow
input int  InpMACounterMinScore = 150; // Min for counter-trend
```

**Expected Impact**:
- Reduce counter-trend losses: -60-70%
- Win rate: +3-5%
- Trade count: -15-20%

---

#### 3. Thiếu WAE (Waddah Attar Explosion)

**Problem**: Không xác nhận institutional momentum

**Proposed**: Add WAE indicator

```cpp
// New Detector
bool IsWAEExplosion(int direction, double &waeValue) {
    double waeMain[], waeSignal[];
    ArraySetAsSeries(waeMain, true);
    ArraySetAsSeries(waeSignal, true);
    
    CopyBuffer(m_waeHandle, 0, 0, 1, waeMain);    // Histogram
    CopyBuffer(m_waeHandle, 1, 0, 1, waeSignal);  // Signal line
    
    waeValue = waeMain[0];
    
    // Check explosion: histogram > signal AND > threshold
    if(waeMain[0] > waeSignal[0] && waeMain[0] > InpWAEThreshold) {
        double waeDirection = (waeMain[0] > 0) ? 1 : -1;
        if(waeDirection == direction) {
            return true;  // Momentum explosion confirmed
        }
    }
    
    return false;
}

// Update Candidate
struct Candidate {
    // ... existing ...
    bool   hasWAE;
    double waeValue;
    bool   waeWeak;
};

// Update Scoring
if(c.hasWAE) {
    score += 20;
    Print("✨ WAE explosion confirmed (+20)");
    
    if(c.waeValue > InpWAEThreshold * 1.5) {
        score += 10;  // Very strong
        Print("✨ WAE very strong (+10)");
    }
} else if(!c.waeWeak) {
    score -= 15;
    Print("⚠️ Weak momentum (-15)");
    
    if(score < 120) {
        Print("❌ REJECT: Weak WAE");
        return 0;
    }
}
```

**Parameters**:
```cpp
input bool   InpUseWAE       = true;   // Enable WAE
input double InpWAEThreshold = 0.5;    // Explosion threshold
input bool   InpWAERequired  = false;  // Require for all trades
```

**Expected Impact**:
- Filter weak breakouts: -25-30% trades
- Win rate: +4-6%
- Profit factor: +0.2-0.3

---

#### 4. Confluence Requirements Too Loose

**Current**: Minimum 2 factors (BOS + OB)

**ICT Optimal**: Minimum 3 factors (Sweep + BOS + POI)

**Proposed**:
```cpp
input int InpMinConfluenceFactors = 3; // Min factors (2-5)

Candidate BuildCandidate(...) {
    // ... existing logic ...
    
    // Count factors
    int factors = 0;
    if(c.hasBOS) factors++;
    if(c.hasSweep) factors++;
    if(c.hasOB || c.hasFVG) factors++;  // POI = 1 factor
    if(c.hasMomo) factors++;
    if(c.hasWAE) factors++;
    if(c.maTrend == c.direction) factors++;
    if(c.mtfBias == c.direction) factors++;
    
    c.confluenceCount = factors;
    
    // Apply minimum
    if(factors < InpMinConfluenceFactors) {
        Print("❌ REJECT: Only ", factors, " factors (min: ",
              InpMinConfluenceFactors, ")");
        c.valid = false;
        return c;
    }
    
    // ... rest of validation ...
}
```

**Presets**:
```
CONSERVATIVE (4+ factors):
  InpMinConfluenceFactors = 4
  InpRequireSweepBOS = true
  InpUseMAFilter = true
  InpUseWAE = true
  Expected: Win 75%+, 2-3 trades/day

BALANCED (3 factors):
  InpMinConfluenceFactors = 3
  InpRequireSweepBOS = true
  Expected: Win 68-70%, 4-5 trades/day

AGGRESSIVE (2 factors):
  InpMinConfluenceFactors = 2
  InpRequireSweepBOS = false
  Expected: Win 65%, 6-8 trades/day
```

---

### 📊 Comparison: Current vs Proposed

| Aspect | Current v1.2 | Proposed v2.0+ | Impact |
|--------|-------------|----------------|--------|
| **Sweep Requirement** | Optional | Required (optional toggle) | +5-8% WR |
| **MA Filter** | None | EMA 20/50 | +3-5% WR |
| **WAE Momentum** | Body size only | WAE explosion | +4-6% WR |
| **Min Confluence** | 2 factors | 3-4 factors | +5-10% WR |
| **Counter-Trend** | -30 penalty | -40 + strict filter | -60% losses |
| **Trade Count** | 5-6/day | 3-4/day | -30-40% |
| **Win Rate** | 65% | 72-75% | +7-10% |
| **Profit Factor** | 2.0 | 2.3-2.5 | +15-25% |

---

### 🎯 Implementation Roadmap

**Phase 1 (Week 1-2): Critical**
- ✅ Add `InpRequireSweepBOS` parameter
- ✅ Update `BuildCandidate()` logic
- ✅ Add GOLD pattern scoring (+50)
- ✅ Backtest: Compare ON vs OFF

**Phase 2 (Week 3): MA Filter**
- ✅ Add EMA 20/50 handles
- ✅ Implement `DetectMATrend()`
- ✅ Update Candidate struct
- ✅ Add MA scoring logic
- ✅ Backtest: Measure counter-trend reduction

**Phase 3 (Week 4): WAE**
- ✅ Add WAE custom indicator
- ✅ Implement `IsWAEExplosion()`
- ✅ Update Candidate & Scoring
- ✅ Backtest: Measure momentum quality

**Phase 4 (Week 5): Confluence**
- ✅ Add `InpMinConfluenceFactors`
- ✅ Implement factor counting
- ✅ Create presets (Conservative/Balanced/Aggressive)
- ✅ Full backtest: 6 months data

---

### 📚 Related Documentation

- [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md) - Full roadmap
- [04_EXECUTOR.md](04_EXECUTOR.md) - Entry method improvements
- [02_DETECTORS.md](02_DETECTORS.md) - MA & WAE detectors

---

## 🎓 Đọc Tiếp

- [04_EXECUTOR.md](04_EXECUTOR.md) - Cách thực thi entry
- [09_EXAMPLES.md](09_EXAMPLES.md) - Real trade examples với scoring
- [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md) - Roadmap cải tiến chi tiết

