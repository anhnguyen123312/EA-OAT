# Quy Tắc Quản Lý Vốn

## 📍 Tổng Quan

Tài liệu này mô tả chi tiết **quy tắc quản lý vốn** của bot EA từ góc độ business logic.

---

## 🎯 1. Position Sizing (Tính Lot Size)

### Công Thức Cơ Bản

```
Lots = (Balance × Risk%) ÷ (SL_Distance × Value_Per_Point)
```

### Chi Tiết Tính Toán

#### Bước 1: Tính Risk Amount
```
Risk Amount = Balance × (Risk% / 100)

Ví dụ:
  Balance: $10,000
  Risk: 0.5%
  Risk Amount = $10,000 × 0.5% = $50
```

#### Bước 2: Tính Value Per Point
```
Value Per Point = TickValue × (_Point / TickSize)

Ví dụ (XAUUSD):
  TickValue: $1.00
  TickSize: 0.01
  _Point: 0.0001
  Value Per Point = $1.00 × (0.0001 / 0.01) = $0.01
```

#### Bước 3: Tính Lots
```
Lots = Risk Amount ÷ (SL_Distance × Value_Per_Point)

Ví dụ:
  Risk Amount: $50
  SL Distance: 1000 points (100 pips)
  Value Per Point: $0.01
  Lots = $50 ÷ (1000 × $0.01) = $50 ÷ $10 = 5.0 lots
```

### Giới Hạn (Limits)

| Giới Hạn | Giá Trị | Mô Tả |
|----------|---------|-------|
| Min Lot | Theo broker | Thường 0.01 |
| Max Lot | MaxLotPerSide | Mặc định: 3.0 |
| Max Lot Per Side | MaxLotPerSide | Tổng BUY hoặc SELL |

### Dynamic Lot Sizing (Tùy Chọn)

#### Công Thức
```
MaxLot = LotBase + floor(Equity / EquityPerLotInc) × LotIncrement
```

#### Ví Dụ
```
LotBase: 0.1
EquityPerLotInc: $1,000
LotIncrement: 0.1

Equity $5,000:
  MaxLot = 0.1 + floor(5000/1000) × 0.1
         = 0.1 + 5 × 0.1
         = 0.6

Equity $10,000:
  MaxLot = 0.1 + floor(10000/1000) × 0.1
         = 0.1 + 10 × 0.1
         = 1.1

Equity $20,000:
  MaxLot = 0.1 + floor(20000/1000) × 0.1
         = 0.1 + 20 × 0.1
         = 2.1
```

### Risk Per Trade (Rủi Ro Mỗi Lệnh)

| Profile | Risk% | Mô Tả |
|---------|-------|-------|
| Conservative | 0.2-0.3% | Tài khoản nhỏ, bảo vệ vốn |
| Balanced | 0.3-0.5% | Mặc định, cân bằng |
| Aggressive | 0.5-1.0% | Tài khoản lớn, chấp nhận rủi ro |

---

## 🎯 2. Daily MDD Protection (Bảo Vệ Vốn Hàng Ngày)

### Quy Tắc

- **Limit**: 8% daily drawdown (mặc định)
- **Khi đạt limit**: 
  - ✅ Đóng tất cả positions
  - ✅ Dừng giao dịch đến ngày hôm sau
  - ✅ Reset vào 00:00 GMT+7

### Tính Toán

```
Daily MDD = (Start Day Balance - Current Equity) / Start Day Balance × 100%

Nếu Daily MDD ≥ 8% → HALT TRADING
```

### Ví Dụ

```
Start Day Balance: $10,000
Current Equity: $9,100

Daily MDD = ($10,000 - $9,100) / $10,000 × 100%
          = $900 / $10,000 × 100%
          = 9%

→ 9% > 8% (limit)
→ HALT TRADING ✅
→ Đóng tất cả positions
→ Dừng đến ngày hôm sau
```

### Cấu Hình

| Profile | Daily MDD Limit | Mô Tả |
|---------|-----------------|-------|
| Conservative | 5% | Bảo vệ vốn tối đa |
| Balanced | 8% | Mặc định |
| Aggressive | 10-12% | Chấp nhận rủi ro cao hơn |

---

## 🎯 3. DCA (Dollar Cost Averaging) - Thêm Lệnh

### Quy Tắc Trigger

Bot chỉ thêm DCA khi **TẤT CẢ** điều kiện đúng:

1. ✅ **Position đang lãi** → Profit ≥ trigger level
2. ✅ **Chưa đạt max DCA** → DCA Count < MaxDcaAddons
3. ✅ **Equity health OK** → Equity không quá thấp (nếu bật check)
4. ✅ **Không vượt MaxLot** → Tổng lot < MaxLotPerSide

### Trigger Levels

| Level | Trigger | Lot Size | Mô Tả |
|-------|---------|----------|-------|
| DCA #1 | +0.75R profit | 0.5× original | Thêm khi có 75% risk profit |
| DCA #2 | +1.5R profit | 0.33× original | Thêm khi có 150% risk profit |

### Tính Toán R (Risk Unit)

```
Profit in R = (Current Price - Entry Price) / (Entry Price - ORIGINAL SL)

⚠️ QUAN TRỌNG: R được tính dựa trên ORIGINAL SL (không đổi dù SL đã move về BE)
```

### Ví Dụ DCA

#### Setup Ban Đầu:
```
Entry Price:    2650.00
Original SL:    2640.00  (risk = 10.00 = 1000 points)
TP:             2670.00
Lot:            0.10
Direction:      BUY
```

#### Timeline:

**T+0: Lệnh Ban Đầu Được Fill**
```
Entry:    2650.00
SL:       2640.00  (Risk: 10.00)
TP:       2670.00  (Reward: 20.00, RR = 2.0)
Lot:      0.10
Position: +0.10 lots @ 2650.00
```

**T+15min: Price = 2657.50**
```
Current Price: 2657.50
Profit:        7.50 (750 points)
Risk:          10.00 (original)

Profit in R = 7.50 / 10.00 = 0.75R ✅ TRIGGER DCA #1
```

**🚀 DCA #1 Executed:**
```
DCA Lot = Original Lot × 0.5
        = 0.10 × 0.5
        = 0.05 lots

DCA Entry:  2657.50 (market price)
DCA SL:     2640.00 (copy from original)
DCA TP:     2670.00 (copy from original)
```

**T+30min: Price = 2665.00**
```
Current Price: 2665.00
Profit:        15.00 (1500 points)
Risk:          10.00 (original)

Profit in R = 15.00 / 10.00 = 1.5R ✅ TRIGGER DCA #2
```

**🚀 DCA #2 Executed:**
```
DCA Lot = Original Lot × 0.33
        = 0.10 × 0.33
        = 0.033 lots (≈ 0.03)

DCA Entry:  2665.00 (market price)
DCA SL:     2640.00 (copy from original)
DCA TP:     2670.00 (copy from original)
```

### Quy Tắc Quan Trọng

1. **R tính theo ORIGINAL SL** → Không đổi dù SL đã move về BE
2. **Sync SL** → Tất cả positions cùng side có cùng SL
3. **Check equity health** → Trước khi DCA (nếu bật)
4. **Max DCA** → Không vượt quá MaxDcaAddons (mặc định: 2)

**Chi tiết**: Xem [DCA_MECHANISM.md](DCA_MECHANISM.md)

---

## 🎯 4. Breakeven (Bảo Vệ Vốn)

### Quy Tắc

- **Trigger**: Profit ≥ +1R (mặc định)
- **Action**: Move SL về entry price
- **Áp dụng**: Tất cả positions cùng side

### Ví Dụ

```
Entry: 2650.00
Original SL: 2648.50 (1R = 150 points)
Current Price: 2651.50 (+150 points = +1R)

→ Move SL: 2648.50 → 2650.00 (BE)
→ Risk eliminated! ✅
```

### Cấu Hình

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| Enable BE | true | Bật/tắt breakeven |
| BE Level | 1.0R | Trigger tại +1R profit |

---

## 🎯 5. Trailing Stop (Chốt Lời Dần)

### Quy Tắc

- **Start**: Profit ≥ +1R (mặc định)
- **Step**: Move SL mỗi +0.5R (mặc định)
- **Distance**: 2× ATR từ current price (mặc định)

### Ví Dụ

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

T3: Price = 2652.00 (+2.0R)
  → Trail again (2.0R - 1.5R = 0.5R >= step)
  → New SL = 2652.00 - 10 = 2651.90
```

### Cấu Hình

| Tham Số | Giá Trị | Mô Tả |
|---------|---------|-------|
| Enable Trailing | true | Bật/tắt trailing |
| Trail Start | 1.0R | Bắt đầu tại +1R |
| Trail Step | 0.5R | Move mỗi +0.5R |
| Trail Distance | 2× ATR | Khoảng cách từ price |

---

## 🎯 6. Basket Management (Quản Lý Tổng Vị Thế)

### Quy Tắc

- **Sync SL** → Tất cả positions cùng side có cùng SL
- **Basket TP** → (Nếu bật) Đóng tất cả khi đạt target
- **Basket SL** → (Nếu bật) Đóng tất cả khi đạt limit

### Ví Dụ

```
Positions:
  Position #1: 0.10 lots @ 2650.00 | SL: 2640.00
  Position #2: 0.05 lots @ 2657.50 | SL: 2640.00 (DCA #1)
  Position #3: 0.03 lots @ 2665.00 | SL: 2640.00 (DCA #2)

Total: 0.18 lots
Avg Entry: ~2654.00

Khi BE triggered:
  → Move ALL SL to 2654.00 (avg entry)
  → Sync cho tất cả positions
```

---

## 🎯 7. Risk Overlays (Lớp Bảo Vệ Bổ Sung)

### Max Trades Per Day

- **Limit**: MaxTradesPerDay (mặc định: 10)
- **Khi đạt limit**: Không entry lệnh mới trong ngày

### Max Consecutive Loss + Cooldown

- **Limit**: MaxConsecutiveLoss (mặc định: 3)
- **Khi đạt limit**: 
  - Dừng giao dịch
  - Cooldown: CooldownHours (mặc định: 4 giờ)
  - Sau cooldown: Reset và tiếp tục

---

## 📝 Tóm Tắt Quy Tắc Quản Lý Vốn

### ✅ PHẢI TUÂN THỦ:
1. Risk per trade ≤ Risk% (0.5% mặc định)
2. Daily MDD < 8% (mặc định)
3. Max lot ≤ MaxLotPerSide (3.0 mặc định)
4. DCA chỉ khi position đang lãi
5. BE khi profit ≥ +1R

### ❌ KHÔNG BAO GIỜ:
1. Vượt quá Daily MDD limit
2. DCA khi position đang lỗ
3. Entry khi đã đạt Max Trades Per Day
4. Entry khi đang trong cooldown

### ⚠️ CẨN THẬN:
1. Equity health khi DCA
2. Max lot khi thêm DCA
3. Sync SL cho tất cả positions

---

## 🔗 Tài Liệu Liên Quan

- [TRADING_RULES.md](TRADING_RULES.md) - Tổng hợp quy tắc giao dịch
- [ENTRY_RULES.md](ENTRY_RULES.md) - Quy tắc entry
- [DCA_MECHANISM.md](DCA_MECHANISM.md) - Chi tiết cơ chế DCA
- [07_CONFIGURATION.md](07_CONFIGURATION.md) - Cấu hình tham số

---

**Cập nhật lần cuối**: 2025-12-14  
**Phiên bản**: v2.1

