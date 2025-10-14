# ⚡ QUICK CONFIG REFERENCE - EA v1.2

## 🎯 3 BƯỚC SETUP NHANH

### **1️⃣ Chọn % Risk (Chấp nhận thua mỗi lần)**
```
InpRiskPerTradePct = ?
```
- 0.25% = Ultra Conservative
- 0.5%  = Conservative (khuyến nghị)
- 1.0%  = Balanced
- 2.0%  = Aggressive

---

### **2️⃣ Config Lot Range**
```
InpLotBase = ?     // Lot nhỏ nhất
InpLotMax = ?      // Lot lớn nhất
```

| Account | LotBase | LotMax | Notes |
|---------|---------|--------|-------|
| $1,000  | 0.01    | 0.5    | Micro |
| $5,000  | 0.05    | 1.0    | Small |
| $10,000 | 0.1     | 2.0    | Medium |
| $25,000 | 0.2     | 5.0    | Large |
| $50,000 | 0.5     | 10.0   | Pro |

---

### **3️⃣ Config Scaling**
```
InpEquityPerLotInc = 1000    // Mỗi $1000 equity
InpLotIncrement = 0.1        // Cộng thêm 0.1 lot
```

**Công thức:**
```
MaxLot = LotBase + floor(Equity / 1000) × 0.1
```

---

## 📋 PRESET CONFIGS

### **🟢 CONSERVATIVE**
Copy-paste vào Strategy Tester:
```
InpRiskPerTradePct=0.5
InpLotBase=0.1
InpLotMax=2.0
InpEquityPerLotInc=1000
InpLotIncrement=0.1
InpEnableDCA=false
InpEnableTrailing=true
InpTrailStartR=1.0
InpDailyMddMax=5.0
```

### **🟡 BALANCED (Khuyến nghị)**
```
InpRiskPerTradePct=0.5
InpLotBase=0.1
InpLotMax=5.0
InpEquityPerLotInc=1000
InpLotIncrement=0.1
InpEnableDCA=true
InpMaxDcaAddons=2
InpEnableTrailing=true
InpTrailStartR=1.0
InpDcaCheckEquity=true
InpDailyMddMax=8.0
```

### **🔴 AGGRESSIVE**
```
InpRiskPerTradePct=1.0
InpLotBase=0.3
InpLotMax=10.0
InpEquityPerLotInc=2000
InpLotIncrement=0.2
InpEnableDCA=true
InpMaxDcaAddons=3
InpEnableTrailing=true
InpTrailStartR=0.75
InpTrailStepR=0.3
InpDailyMddMax=12.0
```

---

## 🔍 TROUBLESHOOTING

### **Lot luôn = MinLot (0.01)?**
→ InpRiskPerTradePct quá thấp HOẶC balance quá nhỏ
→ Tăng risk% lên 1.0% để test

### **Lot luôn bị capped ở 1.0?**
→ InpLotMax hoặc InpLotBase quá thấp
→ Set InpLotMax = 5.0

### **Quá nhiều DCA positions?**
→ Check log "DCA Add-on" 
→ Verify InpMaxDcaAddons = 2

### **Không có DCA nào?**
→ Check InpEnableDCA = true
→ Verify positions đạt +0.75R

### **Trailing không hoạt động?**
→ Check InpEnableTrailing = true
→ Verify InpTrailStartR (default 1.0R)

---

## 💡 PRO TIPS

1. **Start Conservative:**
   - Risk 0.5%, Lot Max 2.0
   - Test 1 tháng data
   - Verify behavior OK

2. **Check Logs Carefully:**
   - First trade: Lot calculation
   - First DCA: SL/TP copied?
   - First BE: All positions moved?

3. **Adjust Based on Results:**
   - Too many trades → Tăng score threshold
   - Too few trades → Relax filters
   - Lots too small → Tăng Risk% hoặc LotBase

4. **Monitor MaxLot Scaling:**
   - Should see "MaxLotPerSide updated" trong log
   - Verify increments = equity / 1000

---

## 🎯 FINAL CHECKLIST

✅ Compile success (0 errors)
✅ Backtest deposit >= $10,000
✅ InpLotBase > 0
✅ InpLotMax > InpLotBase
✅ InpRiskPerTradePct > 0
✅ Check first trade log carefully
✅ Monitor DCA behavior
✅ Verify no "CAPPED" warnings

**GOOD LUCK! 🚀**

