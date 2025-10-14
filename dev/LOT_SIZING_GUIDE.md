# 📊 HƯỚNG DẪN CẤU HÌNH LOT SIZING

## 🎯 CÔNG THỨC TÍNH LOT

### **Công thức cơ bản:**
```
Lots = (Balance × Risk%) ÷ (SL_Points × Value_Per_Point)
```

### **Giải thích:**
- **Balance × Risk%** = Số tiền chấp nhận thua (VD: $10,000 × 0.5% = $50)
- **SL_Points** = Số points SL mà phương pháp yêu cầu (VD: 1000 points = 100 pips)
- **Value_Per_Point** = Giá trị mỗi point per lot (XAUUSD ≈ $0.10/point/0.01lot)
- **Kết quả** = Lots cần mở để risk đúng %

---

## ⚙️ CẤU HÌNH PARAMETERS

### **1. Risk Per Trade (% chấp nhận thua mỗi lần)**
```cpp
input double InpRiskPerTradePct = 0.5;  // 0.5% của balance
```

**Ví dụ:**
| Balance | Risk 0.5% | Risk 1.0% | Risk 2.0% |
|---------|-----------|-----------|-----------|
| $10,000 | $50       | $100      | $200      |
| $50,000 | $250      | $500      | $1,000    |
| $100,000| $500      | $1,000    | $2,000    |

**Khuyến nghị:**
- Conservative: 0.25% - 0.5%
- Balanced: 0.5% - 1.0%
- Aggressive: 1.0% - 2.0%

---

### **2. Dynamic Lot Sizing (Tăng lot theo equity)**
```cpp
input double InpLotBase = 0.1;           // Lot khởi điểm
input double InpLotMax = 5.0;            // Lot tối đa (cap)
input double InpEquityPerLotInc = 1000;  // Mỗi $1000 equity
input double InpLotIncrement = 0.1;      // Cộng thêm 0.1 lot
```

**Công thức:**
```
MaxLot = LotBase + floor(Equity / EquityPerLotInc) × LotIncrement
```

**Ví dụ:**
```
Config: Base=0.1, Increment=0.1 per $1000

Equity $5,000:
  → Increments = floor(5000/1000) = 5
  → MaxLot = 0.1 + (5 × 0.1) = 0.6 lot

Equity $10,000:
  → Increments = floor(10000/1000) = 10
  → MaxLot = 0.1 + (10 × 0.1) = 1.1 lot

Equity $25,000:
  → Increments = floor(25000/1000) = 25
  → MaxLot = 0.1 + (25 × 0.1) = 2.6 lot

Equity $50,000:
  → MaxLot = 0.1 + 50×0.1 = 5.1 → CAPPED to 5.0 (LotMax)
```

---

## 📋 VÍ DỤ TÍNH LOT THỰC TẾ

### **Scenario 1: Balance $10,000**
```
Config:
  InpRiskPerTradePct = 0.5%
  InpLotBase = 0.1
  InpEquityPerLotInc = 1000
  InpLotIncrement = 0.1

Equity: $10,000
→ MaxLotPerSide = 0.1 + (10×0.1) = 1.1 lot

Setup: BUY XAUUSD
  Entry: 2650
  SL: 2640 (100 pips = 1000 points)

Calculation:
  Risk Amount: $10,000 × 0.5% = $50
  Value per point: $0.10
  Lots = $50 ÷ (1000 × $0.10) = $50 ÷ $100 = 0.5 lot

Final: 0.5 lot (< MaxLot 1.1, OK ✅)
```

### **Scenario 2: Balance $10,000, SL Lớn**
```
Setup: SELL XAUUSD
  Entry: 2650
  SL: 2670 (200 pips = 2000 points)

Calculation:
  Risk Amount: $10,000 × 0.5% = $50
  Lots = $50 ÷ (2000 × $0.10) = $50 ÷ $200 = 0.25 lot

Final: 0.25 lot (SL lớn → lot nhỏ để giữ risk = 0.5%)
```

### **Scenario 3: Balance $10,000, SL Nhỏ**
```
Setup: BUY XAUUSD
  Entry: 2650
  SL: 2645 (50 pips = 500 points)

Calculation:
  Risk Amount: $10,000 × 0.5% = $50
  Lots = $50 ÷ (500 × $0.10) = $50 ÷ $50 = 1.0 lot

Final: 1.0 lot (SL nhỏ → lot lớn hơn)
```

---

## 🎚️ PRESET CONFIGURATIONS

### **Conservative (Account < $10,000)**
```
InpRiskPerTradePct = 0.5
InpLotBase = 0.1
InpLotMax = 2.0
InpEquityPerLotInc = 1000
InpLotIncrement = 0.1
```

### **Balanced (Account $10,000 - $50,000)**
```
InpRiskPerTradePct = 0.75
InpLotBase = 0.2
InpLotMax = 5.0
InpEquityPerLotInc = 1000
InpLotIncrement = 0.1
```

### **Aggressive (Account > $50,000)**
```
InpRiskPerTradePct = 1.0
InpLotBase = 0.5
InpLotMax = 10.0
InpEquityPerLotInc = 2000
InpLotIncrement = 0.2
```

### **Micro Account (< $1,000)**
```
InpRiskPerTradePct = 1.0
InpLotBase = 0.01
InpLotMax = 0.5
InpEquityPerLotInc = 500
InpLotIncrement = 0.01
```

---

## 🔄 GROWTH SIMULATION

### **Account $10,000 → $50,000**
```
Config: Base=0.1, Inc=0.1 per $1000, Max=5.0

Start ($10,000):  MaxLot = 1.1 lot
$15,000:          MaxLot = 1.6 lot (+0.5)
$20,000:          MaxLot = 2.1 lot (+0.5)
$30,000:          MaxLot = 3.1 lot (+1.0)
$50,000:          MaxLot = 5.0 lot (hit cap)
$100,000:         MaxLot = 5.0 lot (capped)
```

**Lợi ích:**
- ✅ Lot size tăng theo equity (compound effect)
- ✅ Có cap để kiểm soát risk max
- ✅ Tự động scaling, không cần adjust thủ công

---

## 📊 CÁCH TÍNH % RISK CHẤP NHẬN THUA

### **Công thức ngược:**
```
Nếu bạn muốn:
- Thua tối đa $X mỗi lần
- Với balance $Y

→ Risk% = (X / Y) × 100

VD:
  Balance: $10,000
  Chấp nhận thua: $50/lần
  → Risk% = (50 / 10,000) × 100 = 0.5%
```

### **Bảng tham khảo:**
| Balance | Thua $25 | Thua $50 | Thua $100 | Thua $200 |
|---------|----------|----------|-----------|-----------|
| $5,000  | 0.5%     | 1.0%     | 2.0%      | 4.0%      |
| $10,000 | 0.25%    | 0.5%     | 1.0%      | 2.0%      |
| $50,000 | 0.05%    | 0.1%     | 0.2%      | 0.4%      |

---

## 🧪 TESTING CHECKLIST

Trước khi backtest, verify:

1. ✅ **Check log khi trade đầu tiên:**
   ```
   💰 LOT SIZING CALCULATION:
      Account: $10,000.00 (Balance)
      Risk per trade: 0.5%
      → Acceptable Loss: $50.00
      SL Distance: 1000 points = 100.0 pips
      Value per point/lot: $0.1000
      ───────────────────────────────────────
      Formula: $50.00 ÷ (1000 pts × $0.1000)
      Raw Lots: 0.5000
      Normalized: 0.50
      Current MaxLotPerSide: 1.10 (Base: 0.1 + Growth)
      ✅ FINAL LOTS: 0.50
   ```

2. ✅ **Verify MaxLot scaling:**
   ```
   📈 MaxLotPerSide updated: 1.1 → 1.2 (Equity: $12,000.00, Increments: 12)
   ```

3. ✅ **Check DCA lots:**
   ```
   ➕ DCA #1: 0.25 lots at +0.75R  (= 0.50 × 0.5)
   ➕ DCA #2: 0.165 lots at +1.5R  (= 0.50 × 0.33)
   ```

---

## ⚠️ LƯU Ý QUAN TRỌNG

1. **Lot sizing tự động điều chỉnh theo SL:**
   - SL lớn (200 pips) → Lot nhỏ
   - SL nhỏ (50 pips) → Lot lớn
   - **Luôn giữ risk = X%** bất kể SL

2. **MaxLotPerSide là CAP động:**
   - Bắt đầu từ LotBase
   - Tăng dần theo equity
   - Không bao giờ vượt LotMax

3. **Risk% áp dụng cho MỖI LỆNH:**
   - Mỗi position risk = 0.5%
   - Nếu có 3 positions cùng lúc = 1.5% total risk
   - DCA không add thêm risk (vì add khi đang lời)

---

## 🚀 QUICK START

### **Bước 1: Chọn Risk %**
```
Bạn chấp nhận thua bao nhiêu % mỗi lần?
→ Điền vào InpRiskPerTradePct
```

### **Bước 2: Config Lot Range**
```
Lot nhỏ nhất bạn muốn: InpLotBase = 0.1
Lot lớn nhất bạn muốn: InpLotMax = 5.0
```

### **Bước 3: Config Scaling**
```
Mỗi bao nhiêu $ equity tăng thêm lot?
→ InpEquityPerLotInc = 1000 ($1000)
→ InpLotIncrement = 0.1 (thêm 0.1 lot)
```

### **Bước 4: Run Backtest**
```
Check log xem lot calculation có đúng không
Adjust parameters nếu cần
```

---

## 📈 VÍ DỤ CONFIG THEO ACCOUNT SIZE

### **Account $5,000:**
```
InpRiskPerTradePct = 0.5      // Thua max $25/lần
InpLotBase = 0.05
InpLotMax = 1.0
InpEquityPerLotInc = 500
InpLotIncrement = 0.05
```

### **Account $10,000:**
```
InpRiskPerTradePct = 0.5      // Thua max $50/lần
InpLotBase = 0.1
InpLotMax = 2.0
InpEquityPerLotInc = 1000
InpLotIncrement = 0.1
```

### **Account $50,000:**
```
InpRiskPerTradePct = 0.5      // Thua max $250/lần
InpLotBase = 0.3
InpLotMax = 10.0
InpEquityPerLotInc = 2000
InpLotIncrement = 0.2
```

---

## ✅ ĐÃ IMPLEMENT

- ✅ Risk% configurable (InpRiskPerTradePct)
- ✅ Lot base min configurable (InpLotBase)
- ✅ Lot max configurable (InpLotMax)
- ✅ Equity increment configurable (InpEquityPerLotInc)
- ✅ Lot increment configurable (InpLotIncrement)
- ✅ Tự động scale theo equity growth
- ✅ Debug logging đầy đủ để verify
- ✅ Formula: Risk% ÷ SL_Pips = Lot size

**Bot đã sẵn sàng với hệ thống lot sizing linh hoạt!** 🚀

