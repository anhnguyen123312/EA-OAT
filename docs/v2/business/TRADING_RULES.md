# Quy Tắc Giao Dịch - Tổng Hợp

## 📍 Tổng Quan

Tài liệu này tổng hợp **TẤT CẢ các quy tắc giao dịch** của bot EA theo phương pháp SMC/ICT cho XAUUSD.

---

## 🎯 1. Quy Tắc Thời Gian Giao Dịch

### ✅ Khi Nào Được Phép Trade?

Bot chỉ giao dịch trong **thời gian session được cấu hình**:

#### Mode 1: Full Day (Mặc Định)
```
Thời gian: 07:00 - 23:00 GMT+7
- Giao dịch liên tục 16 giờ
- Không có break
- Phù hợp: Trader muốn catch tất cả opportunities
```

#### Mode 2: Multi-Session
```
Window 1 (Asia):   07:00 - 11:00 GMT+7
Window 2 (London): 12:00 - 16:00 GMT+7  
Window 3 (NY):     18:00 - 23:00 GMT+7

- Tổng: 13 giờ giao dịch
- Có break giữa các session
- Phù hợp: Focus vào high-liquidity sessions
```

### ❌ Khi Nào KHÔNG Được Trade?

1. **Ngoài giờ session** → Bot tự động skip
2. **Spread quá rộng** → Vượt ngưỡng cho phép (dynamic theo ATR)
3. **Daily MDD đạt limit** → Bot dừng giao dịch đến ngày hôm sau
4. **Rollover time** → Tránh giao dịch trong thời gian rollover
5. **News embargo** (nếu bật) → Tránh giao dịch trước/sau tin tức quan trọng

**Chi tiết**: Xem [TRADING_SCHEDULE.md](TRADING_SCHEDULE.md)

---

## 🎯 2. Quy Tắc Phát Hiện Signal

### ✅ Điều Kiện Tối Thiểu Để Có Signal

Bot cần **ÍT NHẤT** một trong hai path sau:

#### Path A: BOS + POI (Khuyến Nghị)
```
✓ BOS (Break of Structure) - Xác nhận hướng
✓ POI (Point of Interest):
  - Order Block (OB) HOẶC
  - Fair Value Gap (FVG)
```

#### Path B: Sweep + POI + Momentum
```
✓ Liquidity Sweep - Xác nhận liquidity grab
✓ POI (OB hoặc FVG)
✓ Momentum - Xác nhận hướng (khi không có BOS)
```

### ❌ Signal Bị Loại Bỏ Nếu:

1. **Momentum ngược với SMC** → Disqualify ngay (score = 0)
2. **Không có POI** → Không có điểm entry
3. **BOS và Momentum đều không có** → Không xác định được hướng

**Chi tiết**: Xem [ENTRY_RULES.md](ENTRY_RULES.md)

---

## 🎯 3. Quy Tắc Scoring & Chất Lượng

### ✅ Điểm Tối Thiểu: 100

Bot chỉ entry khi **score ≥ 100**. Dưới 100 = Skip.

### 📊 Phân Loại Chất Lượng

| Score | Chất Lượng | Hành Động |
|-------|------------|-----------|
| 0 | Invalid | ❌ Reject (disqualify) |
| 1-99 | Quá thấp | ⊘ Skip |
| 100-149 | Chấp nhận được | ✓ Entry với thận trọng |
| 150-199 | Tốt | ✓✓ Entry tự tin |
| 200+ | Xuất sắc | ⭐ Ưu tiên cao |

### ✅ Điểm Cộng (Bonuses)

| Yếu Tố | Điểm | Điều Kiện |
|--------|------|-----------|
| Base | +100 | BOS + (OB hoặc FVG) |
| BOS | +30 | Valid BOS detected |
| Sweep | +25 | Valid liquidity sweep |
| Sweep gần | +15 | Distance ≤ 10 bars |
| OB | +20 | Valid Order Block |
| FVG Valid | +15 | State = 0 (chưa fill) |
| MTF Aligned | +20 | Cùng hướng H1/H4 |
| OB Strong | +10 | Volume ≥ 1.3× avg |
| RR ≥ 2.5 | +10 | Risk/Reward tốt |
| RR ≥ 3.0 | +15 | Risk/Reward xuất sắc |

### ❌ Điểm Trừ (Penalties)

| Yếu Tố | Điểm | Điều Kiện |
|--------|------|-----------|
| MTF Counter-trend | -30 | Ngược H1/H4 |
| OB nhiều touches | ×0.5 | Touches ≥ 3 |
| OB Weak | -10 | Volume < 1.3× avg |
| OB Breaker | -10 | Invalidated OB |
| FVG Mitigated | -10 | State = 1 (đã fill một phần) |
| FVG Completed | -20 | State = 2 (khi có OB) |

### 🚫 Disqualify (Loại Bỏ Hoàn Toàn)

- **Momentum ngược SMC** → Score = 0 (không bao giờ entry)

**Chi tiết**: Xem [ENTRY_RULES.md](ENTRY_RULES.md) - Section Scoring

---

## 🎯 4. Quy Tắc Entry Vào Lệnh

### ✅ Điều Kiện Entry

Bot chỉ entry khi **TẤT CẢ** điều kiện sau đều đúng:

1. ✅ **Candidate valid** → Có đủ signal (Path A hoặc B)
2. ✅ **Score ≥ 100** → Đủ chất lượng
3. ✅ **Không có Momentum ngược SMC** → Không bị disqualify
4. ✅ **Session đang mở** → Trong giờ giao dịch
5. ✅ **Spread OK** → Spread không quá rộng
6. ✅ **Có Trigger Candle** → Có candle xác nhận
7. ✅ **RR ≥ MinRR** → Risk/Reward đủ tốt (mặc định: 2.0)

### 📊 Entry Method

Bot tự động chọn entry method dựa trên pattern:

| Pattern | Entry Method | Lý Do |
|---------|--------------|-------|
| FVG | LIMIT | Chờ price quay về FVG zone |
| OB + Retest | LIMIT | Chờ price quay về OB |
| Sweep + BOS | STOP | Breakout momentum |
| Momentum | STOP | Theo momentum |

### 💰 Tính Toán Entry/SL/TP

#### Entry Price
- **STOP Order**: Trigger High/Low + Buffer
- **LIMIT Order**: POI (OB/FVG) bottom/top

#### Stop Loss (SL)
- **Method-based**: Dựa vào structure (Sweep/OB/FVG) + ATR
- **Fixed SL**: Nếu bật Fixed SL mode
- **Minimum**: ≥ MinStopPts (mặc định: 1000 points = 100 pips)

#### Take Profit (TP)
- **Structure-based**: Tìm swing/OB/FVG target (ưu tiên)
- **Fixed TP**: Nếu bật Fixed TP mode
- **Fallback**: Entry + (Risk × MinRR)

**Chi tiết**: Xem [ENTRY_RULES.md](ENTRY_RULES.md)

---

## 🎯 5. Quy Tắc Quản Lý Vốn

### 💰 Position Sizing

#### Công Thức
```
Lots = (Balance × Risk%) ÷ (SL_Distance × Value_Per_Point)
```

#### Giới Hạn
- **Min Lot**: Theo broker (thường 0.01)
- **Max Lot**: MaxLotPerSide (mặc định: 3.0)
- **Max Lot Per Side**: Tổng lot BUY hoặc SELL không vượt quá giới hạn

#### Dynamic Lot Sizing (Tùy Chọn)
```
MaxLot = LotBase + floor(Equity / EquityPerLotInc) × LotIncrement

Ví dụ:
  Equity $5,000  → MaxLot = 0.6
  Equity $10,000 → MaxLot = 1.1
  Equity $20,000 → MaxLot = 2.1
```

### 🛡️ Daily MDD Protection

#### Quy Tắc
- **Limit**: 8% daily drawdown (mặc định)
- **Khi đạt limit**: 
  - Đóng tất cả positions
  - Dừng giao dịch đến ngày hôm sau
  - Reset vào 00:00 GMT+7

#### Tính Toán
```
Daily MDD = (Start Day Balance - Current Equity) / Start Day Balance × 100%

Nếu Daily MDD ≥ 8% → HALT TRADING
```

### 📊 Risk Per Trade

- **Mặc định**: 0.5% per trade
- **Conservative**: 0.2-0.3%
- **Aggressive**: 0.5-1.0%

**Chi tiết**: Xem [RISK_MANAGEMENT_RULES.md](RISK_MANAGEMENT_RULES.md)

---

## 🎯 6. Quy Tắc DCA (Thêm Lệnh)

### ✅ Khi Nào Thêm DCA?

Bot chỉ thêm DCA khi **TẤT CẢ** điều kiện đúng:

1. ✅ **Position đang lãi** → Profit ≥ trigger level
2. ✅ **Chưa đạt max DCA** → DCA Count < MaxDcaAddons
3. ✅ **Equity health OK** → Equity không quá thấp (nếu bật check)
4. ✅ **Không vượt MaxLot** → Tổng lot < MaxLotPerSide

### 📊 Trigger Levels

| Level | Trigger | Lot Size |
|-------|---------|----------|
| DCA #1 | +0.75R profit | 0.5× original lot |
| DCA #2 | +1.5R profit | 0.33× original lot |

### ⚠️ Quy Tắc Quan Trọng

- **R được tính dựa trên ORIGINAL SL** (không đổi dù SL đã move về BE)
- **Sync SL** cho tất cả positions cùng side
- **Check equity health** trước khi DCA (nếu bật)

**Chi tiết**: Xem [DCA_MECHANISM.md](DCA_MECHANISM.md)

---

## 🎯 7. Quy Tắc Breakeven

### ✅ Khi Nào Move SL Về BE?

- **Trigger**: Profit ≥ +1R (mặc định)
- **Action**: Move SL về entry price
- **Áp dụng**: Tất cả positions cùng side

### 📊 Ví Dụ

```
Entry: 2650.00
Original SL: 2648.50 (1R = 150 points)
Current Price: 2651.50 (+150 points = +1R)

→ Move SL: 2648.50 → 2650.00 (BE)
→ Risk eliminated!
```

---

## 🎯 8. Quy Tắc Trailing Stop

### ✅ Khi Nào Bắt Đầu Trailing?

- **Start**: Profit ≥ +1R (mặc định)
- **Step**: Move SL mỗi +0.5R (mặc định)
- **Distance**: 2× ATR từ current price (mặc định)

### 📊 Ví Dụ

```
Entry: 2650.00
Original SL: 2649.00 (1R = 100 points)
ATR: 5.0 points
Trail Distance: 2× ATR = 10 points

T1: Price = 2651.00 (+1R)
  → Start trailing
  → New SL = 2651.00 - 10 = 2650.90

T2: Price = 2651.50 (+1.5R)
  → Trail again (1.5R - 1.0R = 0.5R >= step)
  → New SL = 2651.50 - 10 = 2651.40
```

---

## 🎯 9. Quy Tắc Exit (Đóng Lệnh)

### ✅ Tự Động Đóng Khi:

1. **Đạt TP** → Take Profit hit
2. **SL hit** → Stop Loss hit
3. **Daily MDD limit** → Đóng tất cả khi đạt 8% MDD
4. **Basket TP/SL** → Nếu bật basket management

### ❌ KHÔNG Tự Động Đóng Khi:

- Chưa đạt TP/SL
- Chưa đạt Daily MDD limit
- Không có lệnh manual từ user

---

## 🎯 10. Quy Tắc Pattern Types

Bot phân loại 7 loại pattern:

| Pattern | Mô Tả |
|---------|-------|
| BOS + OB | BOS + Order Block only |
| BOS + FVG | BOS + FVG only |
| Sweep + OB | Sweep + OB (no BOS) |
| Sweep + FVG | Sweep + FVG (no BOS) |
| Momentum | Momentum only (no BOS) |
| Confluence | BOS + Sweep + (OB/FVG) ⭐ Best |
| Other | Các pattern khác |

**Confluence pattern** thường có score cao nhất và win rate tốt nhất.

---

## 📝 Tóm Tắt Quy Tắc Chính

### ✅ PHẢI CÓ:
1. Session đang mở
2. Spread OK
3. Candidate valid (Path A hoặc B)
4. Score ≥ 100
5. Trigger candle
6. RR ≥ MinRR

### ❌ KHÔNG BAO GIỜ:
1. Trade ngoài session
2. Entry khi score < 100
3. Entry khi Momentum ngược SMC
4. Entry khi Daily MDD đạt limit
5. DCA khi position đang lỗ

### ⚠️ CẨN THẬN:
1. Counter-trend MTF (cần score ≥ 120)
2. OB nhiều touches (≥ 3)
3. FVG đã mitigated
4. Spread quá rộng

---

## 🔗 Tài Liệu Liên Quan

- [ENTRY_RULES.md](ENTRY_RULES.md) - Chi tiết quy tắc entry
- [RISK_MANAGEMENT_RULES.md](RISK_MANAGEMENT_RULES.md) - Chi tiết quản lý vốn
- [DCA_MECHANISM.md](DCA_MECHANISM.md) - Chi tiết cơ chế DCA
- [TRADING_SCHEDULE.md](TRADING_SCHEDULE.md) - Chi tiết thời gian trade
- [07_CONFIGURATION.md](07_CONFIGURATION.md) - Cấu hình tham số

---

**Cập nhật lần cuối**: 2025-12-14  
**Phiên bản**: v2.1

