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

## 🎓 Đọc Tiếp

- [04_EXECUTOR.md](04_EXECUTOR.md) - Cách thực thi entry
- [09_EXAMPLES.md](09_EXAMPLES.md) - Real trade examples với scoring

