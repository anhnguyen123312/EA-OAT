# SMC/ICT Expert Advisor v2.1 - Tài Liệu Kinh Doanh

## 📍 Tổng Quan

Đây là thư mục **Tài Liệu Kinh Doanh/Chiến Lược**, dành cho trader và người lập chiến lược.

Bot EA tự động giao dịch XAUUSD dựa trên phương pháp **SMC (Smart Money Concepts) / ICT (Inner Circle Trader)**.

### 🎯 Mục Tiêu
- Phát hiện các setup giao dịch chất lượng cao theo SMC/ICT
- Quản lý vị thế tự động với DCA, Breakeven, Trailing Stop
- Bảo vệ vốn với Daily MDD limit và risk management
- Tối ưu lợi nhuận với dynamic lot sizing và basket management

### 📊 Thị Trường & Timeframe
- **Công cụ giao dịch**: XAUUSD (Vàng)
- **Timeframe chính**: M15 / M30
- **Timeframe cao hơn**: H1 / H4 (cho phân tích MTF)

---

## 📚 Mục Lục Tài Liệu

### ⭐ Quy Tắc Giao Dịch (BẮT ĐẦU TỪ ĐÂY)

| File | Nội Dung | Mục Đích |
|------|----------|----------|
| [TRADING_RULES.md](TRADING_RULES.md) | **Tổng hợp tất cả quy tắc giao dịch** | Đọc đầu tiên - Hiểu toàn bộ quy tắc |
| [ENTRY_RULES.md](ENTRY_RULES.md) | **Quy tắc và điều kiện entry vào lệnh** | Hiểu khi nào bot entry |
| [RISK_MANAGEMENT_RULES.md](RISK_MANAGEMENT_RULES.md) | **Quy tắc quản lý vốn** | Hiểu cách bot quản lý rủi ro |
| [TRADING_SCHEDULE.md](TRADING_SCHEDULE.md) | **Thời gian giao dịch** | Hiểu khi nào bot trade |

### Tài Liệu Cốt Lõi

| File | Nội Dung | Mục Đích |
|------|----------|----------|
| [README.md](README.md) | Tổng quan dự án | Hướng dẫn bắt đầu |
| [README_V2.1.md](README_V2.1.md) | Mô tả phiên bản v2.1 | Tìm hiểu tính năng mới |
| [01_SYSTEM_OVERVIEW.md](01_SYSTEM_OVERVIEW.md) | Tổng quan kiến trúc 5 lớp | Hiểu thiết kế hệ thống |
| [07_CONFIGURATION.md](07_CONFIGURATION.md) | Tất cả tham số cấu hình | Điều chỉnh cài đặt EA |
| [09_EXAMPLES.md](09_EXAMPLES.md) | Ví dụ giao dịch thực tế | Học ứng dụng chiến lược |
| [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md) | Kế hoạch cải tiến | Lập kế hoạch tương lai |

### Hướng Dẫn Tính Năng

| File | Nội Dung | Mục Đích |
|------|------|------|
| [DCA_MECHANISM.md](DCA_MECHANISM.md) | Giải thích cơ chế DCA | Hiểu logic thêm lệnh |

### Cập Nhật Phiên Bản

| File | Nội Dung | Mục Đích |
|------|------|------|
| [V2.1_QUICK_REFERENCE.md](V2.1_QUICK_REFERENCE.md) | Tham chiếu nhanh v2.1 | Tra cứu tính năng mới |
| [V2.1_UPDATES_SUMMARY.md](V2.1_UPDATES_SUMMARY.md) | Tóm tắt cập nhật v2.1 | Giải thích cập nhật chi tiết |

---

## 🔍 Điều Hướng Nhanh

### ⭐ Nếu bạn là Trader (muốn hiểu chiến lược):

**Đọc theo thứ tự này:**

1. 📖 [TRADING_RULES.md](TRADING_RULES.md) - **ĐỌC ĐẦU TIÊN** - Tổng hợp tất cả quy tắc
2. 📖 [ENTRY_RULES.md](ENTRY_RULES.md) - Quy tắc entry vào lệnh
3. 📖 [RISK_MANAGEMENT_RULES.md](RISK_MANAGEMENT_RULES.md) - Quy tắc quản lý vốn
4. 📖 [TRADING_SCHEDULE.md](TRADING_SCHEDULE.md) - Thời gian giao dịch
5. 📖 [09_EXAMPLES.md](09_EXAMPLES.md) - Ví dụ giao dịch thực tế
6. 📖 [07_CONFIGURATION.md](07_CONFIGURATION.md) - Tham số cấu hình

### Nếu bạn muốn tìm hiểu tính năng mới v2.1:
1. 📖 [V2.1_UPDATES_SUMMARY.md](V2.1_UPDATES_SUMMARY.md) - Tóm tắt cập nhật
2. 📖 [V2.1_QUICK_REFERENCE.md](V2.1_QUICK_REFERENCE.md) - Tham chiếu nhanh
3. 📖 [README_V2.1.md](README_V2.1.md) - Tổng quan v2.1

### Nếu bạn muốn cấu hình EA:
1. 📖 [07_CONFIGURATION.md](07_CONFIGURATION.md) - Tất cả tham số
2. 📖 [TRADING_SCHEDULE.md](TRADING_SCHEDULE.md) - Cấu hình thời gian trade
3. 📖 [DCA_MECHANISM.md](DCA_MECHANISM.md) - Cấu hình DCA
4. 📖 [RISK_MANAGEMENT_RULES.md](RISK_MANAGEMENT_RULES.md) - Cấu hình quản lý vốn

---

## 💻 Tài Liệu Kỹ Thuật

**Tài liệu chi tiết về code và thuật toán** nằm trong thư mục `../code_logic/`:
- Thuật toán detector → `../code_logic/02_DETECTORS.md`
- Logic scoring → `../code_logic/03_ARBITER.md`
- Triển khai executor → `../code_logic/04_EXECUTOR.md`
- Thuật toán quản lý rủi ro → `../code_logic/05_RISK_MANAGER.md`
- Logic luồng chính → `../code_logic/08_MAIN_FLOW.md`

---

## 📝 Giải Thích Tài Liệu

**Thư mục này bao gồm**:
- ✅ **Quy tắc giao dịch** - Tất cả quy tắc và điều kiện
- ✅ **Thời gian trade** - Khi nào bot được phép trade
- ✅ **Quy tắc entry** - Điều kiện và cách entry vào lệnh
- ✅ **Quản lý vốn** - Cách bot quản lý rủi ro và vốn
- ✅ **DCA mechanism** - Cách bot thêm lệnh
- ✅ Khái niệm và chiến lược ở cấp độ kinh doanh
- ✅ Hướng dẫn tham số cấu hình và sử dụng
- ✅ Ví dụ giao dịch thực tế
- ✅ Hướng dẫn sử dụng tính năng
- ✅ Tóm tắt cập nhật phiên bản

**Không bao gồm**:
- ❌ Triển khai code chi tiết (xem `code_logic/`)
- ❌ Chi tiết kỹ thuật thuật toán (xem `code_logic/`)
- ❌ Sửa lỗi ở cấp độ code (xem `code_logic/`)

---

## Kiến Trúc 5 Lớp

```
                     MARKET DATA
                          |
                          v
+----------------------------------------------------------+
|  1. DETECTION LAYER (detectors.mqh)                      |
|     BOS | Sweep | Order Block | FVG | Momentum           |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  2. ARBITRATION LAYER (arbiter.mqh)                      |
|     BuildCandidate() -> ScoreCandidate() -> Filter       |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  3. EXECUTION LAYER (executor.mqh)                       |
|     Session | Spread | Trigger | Entry/SL/TP | Order     |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  4. RISK MANAGEMENT LAYER (risk_manager.mqh)             |
|     Lot Size | DCA | BE | Trail | MDD | Basket           |
+----------------------------------------------------------+
                          |
                          v
+----------------------------------------------------------+
|  5. ANALYTICS LAYER (stats_manager.mqh)                  |
|     Track Trades | Statistics | Dashboard                |
+----------------------------------------------------------+
```

---

## Luồng Hoạt Động Chính

### OnTick() Flow
```
1. Check new bar
2. Pre-checks: Session? Spread? MDD? Rollover?
3. Run detectors: BOS, Sweep, OB, FVG, Momentum
4. Build & Score Candidate
5. If score >= 100: Find trigger -> Calculate Entry/SL/TP -> Place order
6. Manage existing positions: BE, Trailing, DCA
7. Update dashboard
```

### Entry Decision Tree
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
   ENTRY (OK)
```

---

## Hệ Thống Scoring (Điểm Tối Thiểu: 100)

### Điểm Cơ Bản
| Component | Điểm | Điều Kiện |
|-----------|------|-----------|
| Base | +100 | BOS + (OB hoặc FVG) |
| BOS | +40 | Valid BOS detected |
| Order Block | +35 | Valid OB |
| FVG | +30 | Valid FVG (state = 0) |
| Sweep | +25 | Valid liquidity sweep |

### Bonus
| Bonus | Điểm | Điều Kiện |
|-------|------|-----------|
| Sweep gần (<0.5 ATR) | +25 | Sweep proximity |
| MTF Aligned | +25 | Cùng hướng H1/H4 |
| OB có Sweep | +20-25 | Sweep trong/gần OB |
| FVG MTF Overlap | +20-30 | FVG subset của HTF |
| BOS Retest | +12-20 | 1-2+ lần retest |
| Fresh POI | +10 | OB 0 touches / FVG state=0 |
| London/NY Session | +8-10 | High liquidity time |

### Penalties
| Penalty | Điểm | Điều Kiện |
|---------|------|-----------|
| Counter-trend MTF | -40 | Ngược H1/H4 |
| OB nhiều touches | -20 | touches >= 2 |
| FVG Mitigated | -15 | state = 1 |
| OB Weak | -10 | Volume < 1.3x avg |
| BOS no retest | -8 | Direct breakout |

---

## DCA (Dollar Cost Averaging)

### Trigger Levels
| Level | Trigger | Lot Size |
|-------|---------|----------|
| DCA #1 | +0.75R profit | 0.5x original |
| DCA #2 | +1.5R profit | 0.33x original |

### Quy Tắc Quan Trọng
- **R được tính dựa trên ORIGINAL SL** (không đổi dù SL đã move về BE)
- Sync SL cho tất cả positions cùng side
- Check equity health trước khi DCA

---

## Quản Lý Vị Thế

### Breakeven
- Trigger: +1R profit
- Action: Move SL về entry price

### Trailing Stop
- Start: +1R profit
- Step: +0.5R mỗi lần move
- Distance: 2x ATR từ current price

### Daily MDD
- Limit: 8% daily drawdown
- Action: Close all + Halt trading đến ngày hôm sau

---

## Cấu Hình Session

### Mode 1: Full Day (7h-23h GMT+7)
```
07:00 ================================================ 23:00
      |---------------- 16 hours continuous --------------|
```

### Mode 2: Multi-Window
```
07:00 ==== 11:00    12:00 ==== 16:00    18:00 ======== 23:00
      | Asia | break | London | break |      NY       |
```

---

## Cấu Hình Khởi Động Nhanh

### Conservative (Tài khoản < $5k)
```
Risk: 0.2%
MDD: 5%
DCA: Disabled
MaxLot: 2.0
```

### Balanced (Tài khoản $5k-$20k) - Khuyến nghị
```
Risk: 0.3-0.5%
MDD: 8%
DCA: Enabled (2 levels)
MaxLot: 3.0
```

### Aggressive (Tài khoản > $20k)
```
Risk: 0.5-1%
MDD: 10-12%
DCA: Enabled (3 levels)
MaxLot: 5.0
```

---

## Files Quan Trọng

| File | Mô Tả |
|------|-------|
| `Experts/[EA].mq5` | Main EA file |
| `Include/detectors.mqh` | Signal detection |
| `Include/arbiter.mqh` | Scoring & filtering |
| `Include/executor.mqh` | Order execution |
| `Include/risk_manager.mqh` | Risk management |
| `Include/stats_manager.mqh` | Statistics & dashboard |

---

## Lịch Sử Phiên Bản

- **v1.2**: Base SMC/ICT detection, DCA, BE, Trail
- **v2.0**: News filter, Volatility regime, Adaptive parameters
- **v2.1**: OB Sweep validation, FVG MTF overlap, BOS retest tracking
