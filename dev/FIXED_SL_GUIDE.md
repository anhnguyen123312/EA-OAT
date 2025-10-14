# 📌 FIXED SL/TP MODE - HƯỚNG DẪN

## 🎯 MỤC ĐÍCH

Cho phép bạn **config số pips SL/TP cố định**, override logic tính toán từ phương pháp (sweep level, POI, etc).

---

## ⚙️ CẤU HÌNH

### **Input Parameters:**
```cpp
InpUseFixedSL = false        // Bật/tắt Fixed SL mode
InpFixedSL_Pips = 100        // SL cố định (pips)
InpFixedTP_Enable = false    // Bật/tắt Fixed TP
InpFixedTP_Pips = 200        // TP cố định (pips)
```

---

## 🔄 LOGIC ƯU TIÊN

### **Khi `InpUseFixedSL = true`:**
```
Priority 1: Fixed SL (config)
Priority 2: Method SL (sweep/POI) - SKIPPED

VD:
  Phương pháp tính SL = 150 pips (từ sweep level)
  Config InpFixedSL_Pips = 100
  → Sử dụng 100 pips (Fixed) ✅
```

### **Khi `InpUseFixedSL = false`:**
```
Priority 1: Method SL (sweep/POI) ✅
Priority 2: MinStop adjustment nếu cần

VD:
  Phương pháp tính SL = 80 pips (từ OB bottom)
  MinStop = 300 points (30 pips)
  → Sử dụng 80 pips từ phương pháp ✅
```

---

## 📊 VÍ DỤ SỬ DỤNG

### **Scenario 1: Fixed SL 100 pips, RR-based TP**
```cpp
InpUseFixedSL = true
InpFixedSL_Pips = 100        // SL luôn = 100 pips
InpFixedTP_Enable = false    // TP = RR-based
InpMinRR = 2.0               // RR = 2:1
```

**Kết quả:**
```
Entry: 2650.00
SL: 2640.00 (100 pips fixed)
TP: 2670.00 (200 pips = 100 × 2.0 RR)

→ Mọi trade đều có SL = 100 pips
→ TP auto = SL × RR
```

---

### **Scenario 2: Fixed SL + Fixed TP**
```cpp
InpUseFixedSL = true
InpFixedSL_Pips = 80
InpFixedTP_Enable = true
InpFixedTP_Pips = 160
```

**Kết quả:**
```
Entry: 2650.00
SL: 2642.00 (80 pips fixed)
TP: 2666.00 (160 pips fixed)

→ RR = 160/80 = 2:1 (tự động)
→ Hoàn toàn cố định, không phụ thuộc phương pháp
```

---

### **Scenario 3: Method-based (default)**
```cpp
InpUseFixedSL = false
InpFixedTP_Enable = false
```

**Kết quả:**
```
BUY setup:
  Entry: 2650.00
  Method SL: 2645.50 (sweep level - buffer = 45 pips)
  → SL thực tế: 2645.50 (từ phương pháp)
  
  TP: 2650.00 + (4.5 × 2.0 RR) = 2659.00 (90 pips)
  → RR-based TP
```

---

## ⚡ KHI NÀO DÙNG FIXED SL?

### **✅ Nên dùng khi:**
1. **Backtest optimization** - Test nhiều SL values nhanh
2. **Risk consistent** - Muốn mọi trade có same risk
3. **Method SL không ổn định** - Quá lớn hoặc quá nhỏ
4. **Đơn giản hóa** - Không muốn phụ thuộc structure detection

### **❌ Không nên dùng khi:**
1. **Method SL tốt** - Sweep/POI levels accurate
2. **Muốn dynamic** - SL adjust theo market structure
3. **Optimize per setup** - Different setups need different SL

---

## 📈 TẢI NĂNG TRÊN LOT SIZING

### **Impact lên Lot Calculation:**
```
Fixed SL luôn = 100 pips:

Trade 1:
  SL = 100 pips → Lots = $50 / (1000pts × $0.1) = 0.5 lot

Trade 2:
  SL = 100 pips → Lots = $50 / (1000pts × $0.1) = 0.5 lot
  
→ CONSISTENT LOT SIZE mọi trade! ✅
```

```
Method SL (variable):

Trade 1:
  SL = 150 pips → Lots = $50 / (1500pts × $0.1) = 0.33 lot

Trade 2:
  SL = 50 pips → Lots = $50 / (500pts × $0.1) = 1.0 lot
  
→ Lot size khác nhau, nhưng risk = 0.5% luôn!
```

---

## 🧪 TESTING RECOMMENDATION

### **Test 1: Optimize Fixed SL**
```
Config:
  InpUseFixedSL = true
  InpFixedTP_Enable = false

Optimize:
  InpFixedSL_Pips: 50, 80, 100, 120, 150 (step 30)
  
→ Tìm SL value tối ưu cho strategy
```

### **Test 2: Compare Fixed vs Method**
```
Run A: InpUseFixedSL = false (method-based)
Run B: InpUseFixedSL = true, InpFixedSL_Pips = 100

Compare:
  - Total trades (same?)
  - Win rate (better?)
  - Profit factor
  - Max drawdown
```

---

## 📊 LOG OUTPUT

### **Khi Fixed SL enabled:**
```
📌 FIXED SL MODE: 100 pips = 1000 points
📌 FIXED TP MODE: 200 pips = 2000 points

═══════════════════════════════════════════════
💰 LOT SIZING CALCULATION:
   SL Distance: 1000 points = 100.0 pips (FIXED)
   ✅ FINAL LOTS: 0.50
═══════════════════════════════════════════════
```

### **Khi Method-based:**
```
⚠️ SL adjusted to minStop: 300 pts

═══════════════════════════════════════════════
💰 LOT SIZING CALCULATION:
   SL Distance: 850 points = 85.0 pips (from Sweep)
   ✅ FINAL LOTS: 0.59
═══════════════════════════════════════════════
```

---

## ✅ CHECKLIST

- [ ] Config InpUseFixedSL = true/false
- [ ] Set InpFixedSL_Pips hợp lý (50-200 pips)
- [ ] Optional: Enable Fixed TP
- [ ] Check log "📌 FIXED SL MODE" confirms
- [ ] Verify lot sizing consistent
- [ ] Compare results vs method-based

**Fixed SL Mode đã sẵn sàng!** 🚀

