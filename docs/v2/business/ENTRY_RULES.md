# Quy Tắc Entry Vào Lệnh

## 📍 Tổng Quan

Tài liệu này mô tả chi tiết **quy tắc và điều kiện entry vào lệnh** của bot EA.

---

## 🎯 1. Điều Kiện Entry (Entry Conditions)

### ✅ Checklist: Tất Cả Điều Kiện Phải Đúng

Bot chỉ entry khi **TẤT CẢ** điều kiện sau đều đúng:

```
☐ 1. Candidate Valid
   └─ Có đủ signal (Path A hoặc Path B)

☐ 2. Score ≥ 100
   └─ Đủ chất lượng setup

☐ 3. Không có Momentum ngược SMC
   └─ Không bị disqualify

☐ 4. Session đang mở
   └─ Trong giờ giao dịch được cấu hình

☐ 5. Spread OK
   └─ Spread không quá rộng (dynamic theo ATR)

☐ 6. Có Trigger Candle
   └─ Có candle xác nhận entry

☐ 7. RR ≥ MinRR
   └─ Risk/Reward đủ tốt (mặc định: 2.0)

☐ 8. Daily MDD chưa đạt limit
   └─ Chưa đạt 8% daily drawdown

☐ 9. Không có position cùng side đang block
   └─ (Nếu bật one-trade-per-side)
```

---

## 🎯 2. Entry Paths (Đường Vào Lệnh)

### Path A: BOS + POI (Khuyến Nghị) ⭐

#### Điều Kiện:
```
✓ BOS (Break of Structure) - Xác nhận hướng
✓ POI (Point of Interest):
  - Order Block (OB) HOẶC
  - Fair Value Gap (FVG)
```

#### Ví Dụ:
```
Signals:
  ✓ BOS: Bullish (+1)
  ✓ OB: Bullish Demand zone 2649.00-2649.50
  ✗ Sweep: None (optional)
  ✗ FVG: None

→ Direction: LONG (+1)
→ Valid: TRUE ✅
→ Entry Method: LIMIT (tại OB bottom)
```

### Path B: Sweep + POI + Momentum

#### Điều Kiện:
```
✓ Liquidity Sweep - Xác nhận liquidity grab
✓ POI (OB hoặc FVG)
✓ Momentum - Xác nhận hướng (khi không có BOS)
✓ Momentum KHÔNG ngược với SMC
```

#### Ví Dụ:
```
Signals:
  ✗ BOS: None
  ✓ Sweep: Sell-side (-1) at 2648.50
  ✓ FVG: Bullish 2649.20-2649.80
  ✓ Momentum: Bullish (+1)

→ Direction: LONG (+1)
→ Valid: TRUE ✅
→ Entry Method: STOP (theo momentum)
```

---

## 🎯 3. Scoring System (Hệ Thống Điểm)

### Điểm Tối Thiểu: 100

Bot chỉ entry khi **score ≥ 100**. Dưới 100 = Skip.

### 📊 Điểm Cộng (Base + Bonuses)

#### Base Score
| Component | Điểm | Điều Kiện |
|-----------|------|-----------|
| Base | +100 | BOS + (OB hoặc FVG) |

#### Bonuses
| Bonus | Điểm | Điều Kiện |
|-------|------|-----------|
| BOS | +30 | Valid BOS detected |
| Sweep | +25 | Valid liquidity sweep |
| Sweep gần | +15 | Distance ≤ 10 bars |
| OB | +20 | Valid Order Block |
| FVG Valid | +15 | State = 0 (chưa fill) |
| Momentum | +10 | Aligned with SMC |
| MTF Aligned | +20 | Cùng hướng H1/H4 |
| OB Strong | +10 | Volume ≥ 1.3× avg |
| RR ≥ 2.5 | +10 | Risk/Reward tốt |
| RR ≥ 3.0 | +15 | Risk/Reward xuất sắc |

### ❌ Điểm Trừ (Penalties)

| Penalty | Điểm | Điều Kiện |
|---------|------|-----------|
| MTF Counter-trend | -30 | Ngược H1/H4 |
| OB nhiều touches | ×0.5 | Touches ≥ 3 |
| OB Weak | -10 | Volume < 1.3× avg |
| OB Breaker | -10 | Invalidated OB |
| FVG Mitigated | -10 | State = 1 (đã fill một phần) |
| FVG Completed | -20 | State = 2 (khi có OB) |

### 🚫 Disqualify (Loại Bỏ Hoàn Toàn)

- **Momentum ngược SMC** → Score = 0 (không bao giờ entry)

### 📊 Phân Loại Chất Lượng

| Score Range | Chất Lượng | Hành Động |
|-------------|------------|-----------|
| 0 | Invalid | ❌ Reject (disqualify) |
| 1-99 | Quá thấp | ⊘ Skip |
| 100-149 | Chấp nhận được | ✓ Entry với thận trọng |
| 150-199 | Tốt | ✓✓ Entry tự tin |
| 200+ | Xuất sắc | ⭐ Ưu tiên cao |

### 💡 Ví Dụ Tính Điểm

#### Scenario 1: Confluence Setup (Score: 245) ⭐⭐⭐
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

#### Scenario 2: Weak Setup (Score: 55) ⚠
```
Signals:
  ✓ BOS: Bullish
  ✗ Sweep: None
  ✓ OB: Bullish, Weak (volume 1.0× avg), 3 touches
  ✗ FVG: None
  ✓ MTF Bias: Bearish (-1) ← COUNTER-TREND!

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

---

## 🎯 4. Entry Method (Phương Thức Entry)

Bot tự động chọn entry method dựa trên pattern:

### LIMIT Order

#### Khi Nào Dùng:
- **FVG pattern** → Chờ price quay về FVG zone
- **OB + Retest** → Chờ price quay về OB

#### Ưu Điểm:
- Entry tốt hơn (tại POI)
- RR cao hơn
- Ít bị whipsaw

#### Nhược Điểm:
- Có thể không fill
- Cần chờ pullback

### STOP Order

#### Khi Nào Dùng:
- **Sweep + BOS** → Breakout momentum
- **Momentum** → Theo momentum

#### Ưu Điểm:
- Chắc chắn fill
- Theo momentum mạnh

#### Nhược Điểm:
- Entry cao hơn
- RR thấp hơn

### 📊 Entry Method Matrix

| Pattern | Entry Method | Entry Price | Lý Do |
|---------|--------------|-------------|-------|
| FVG | LIMIT | FVG bottom/top | Chờ price quay về imbalance |
| OB + Retest | LIMIT | OB bottom/top | Chờ price quay về zone |
| Sweep + BOS | STOP | Trigger High/Low + Buffer | Breakout momentum |
| Momentum | STOP | Trigger High/Low + Buffer | Theo momentum |

---

## 🎯 5. Tính Toán Entry/SL/TP

### Entry Price

#### STOP Order:
```
Entry = Trigger High/Low ± Buffer

Ví dụ (BUY):
  Trigger High: 2650.10
  Buffer: 70 points (0.07)
  Entry = 2650.10 + 0.07 = 2650.17
```

#### LIMIT Order:
```
Entry = POI (OB/FVG) bottom/top

Ví dụ (BUY):
  OB Bottom: 2649.00
  Entry = 2649.00 (limit order)
```

### Stop Loss (SL)

#### Method-based (Mặc Định):
```
SL = Structure-based + ATR

1. Structure SL:
   - Sweep level (nếu có)
   - OB bottom/top (nếu có)
   - FVG bottom/top (nếu có)

2. ATR SL:
   - Entry ± (2.0 × ATR)

3. Final SL:
   - MIN(structure SL, ATR SL)
   - Cap: MAX(3.5 × ATR)
   - Minimum: ≥ MinStopPts (1000 points)
```

#### Fixed SL (Nếu Bật):
```
SL = Entry ± (FixedSL_Pips × 10 × _Point)

Ví dụ:
  Entry: 2650.00
  FixedSL: 10 pips
  SL = 2650.00 - (10 × 10 × 0.0001) = 2649.00
```

### Take Profit (TP)

#### Structure-based (Ưu Tiên):
```
TP = Tìm target dựa trên structure:
  - Swing high/low (9 points)
  - Order Block (7 points)
  - Fair Value Gap (6 points)
  - Psychological level (8 points)

Fallback: Entry + (Risk × MinRR)
```

#### Fixed TP (Nếu Bật):
```
TP = Entry ± (FixedTP_Pips × 10 × _Point)

Ví dụ:
  Entry: 2650.00
  FixedTP: 20 pips
  TP = 2650.00 + (20 × 10 × 0.0001) = 2652.00
```

### Risk/Reward Ratio (RR)

```
RR = (TP - Entry) / (Entry - SL)  [BUY]
RR = (Entry - TP) / (SL - Entry)  [SELL]

Minimum RR: 2.0 (mặc định)
```

---

## 🎯 6. Trigger Candle (Candle Xác Nhận)

### Điều Kiện Trigger Candle

Bot cần **trigger candle** để xác nhận entry:

```
1. Body size ≥ MinBodyATR (mặc định: 0.30 ATR)
2. Direction phù hợp:
   - BUY: Bullish candle (close > open)
   - SELL: Bearish candle (close < open)
3. Trong 4 bars gần nhất (bar 0-3)
```

### Ví Dụ

```
Setup: LONG (direction = 1)
ATR: 5.0 points
Min Body = 0.30 × 5.0 = 1.5 points

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

## 🎯 7. Entry Decision Tree

```
Signal Detected
     |
     v
Valid Candidate? --- NO ---> Skip
     |
    YES
     |
     v
Score >= 100? --- NO ---> Skip (low quality)
     |
    YES
     |
     v
Momentum Against SMC? --- YES ---> Disqualify
     |
     NO
     |
     v
Session & Spread OK? --- NO ---> Wait
     |
    YES
     |
     v
Trigger Candle Found? --- NO ---> Wait
     |
    YES
     |
     v
RR >= MinRR? --- NO ---> Skip
     |
    YES
     |
     v
   ENTRY (OK) ✅
```

---

## 🎯 8. Ví Dụ Entry Hoàn Chỉnh

### Setup: Confluence Pattern (LONG)

#### Phase 1: Detection
```
[14:00] BOS BULLISH detected!
  → Break Level: 2650.00 (swing high)
  → Distance: 85 points

[14:15] SWEEP LOW detected!
  → Level: 2648.50 (sell-side)
  → Distance: 5 bars

[14:15] ORDER BLOCK found!
  → Zone: 2649.00 - 2649.50
  → Direction: +1 (Demand)
  → Volume: 1.5× avg (STRONG)

[14:15] FVG detected!
  → Zone: 2649.20 - 2649.80
  → Direction: +1 (Bullish)
  → State: Valid (0% filled)
```

#### Phase 2: Scoring
```
Base: BOS + OB                   = +100
BOS Bonus                        = +30
Sweep                            = +25
Sweep Nearby (≤10 bars)          = +15
OB                               = +20
FVG Valid                        = +15
MTF Aligned                      = +20
OB Strong                        = +10
RR ≥ 2.5                         = +10
────────────────────────────────────
TOTAL SCORE:                     = 245 ⭐⭐⭐
```

#### Phase 3: Entry Calculation
```
Trigger Candle:
  Bar: 1 (previous candle)
  High: 2650.10
  Low: 2649.85
  Close: 2650.05 (bullish)

Entry = Trigger High + Buffer
      = 2650.10 + 0.07 (70 pts)
      = 2650.17

SL = Sweep Level - Buffer
   = 2648.50 - 0.07
   = 2648.43

TP = Structure Target (swing high)
   = 2658.80

RR = (2658.80 - 2650.17) / (2650.17 - 2648.43)
   = 8.63 / 1.74
   = 4.96 ✅ (Excellent!)
```

#### Phase 4: Position Sizing
```
Risk%: 0.5%
Risk Amount: $10,000 × 0.5% = $50
SL Distance: 174 points (17.4 pips)

Lots = $50 / (174 × $0.01)
     = $50 / $1.74
     = 28.74 lots (raw)
     
Limits:
  MaxLotPerSide: 3.0
  Final Lots: 3.0 ✓
```

#### Phase 5: Order Placement
```
Order Type: BUY STOP
Entry: 2650.17
SL: 2648.43
TP: 2658.80
Lots: 3.0
Comment: "BOS+OB+SWEEP"
```

---

## 🔗 Tài Liệu Liên Quan

- [TRADING_RULES.md](TRADING_RULES.md) - Tổng hợp quy tắc giao dịch
- [RISK_MANAGEMENT_RULES.md](RISK_MANAGEMENT_RULES.md) - Quản lý vốn
- [07_CONFIGURATION.md](07_CONFIGURATION.md) - Cấu hình tham số

---

**Cập nhật lần cuối**: 2025-12-14  
**Phiên bản**: v2.1

