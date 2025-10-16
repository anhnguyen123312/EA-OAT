# SMC/ICT EA v1.2 - Documentation

## 📚 Mục Lục

1. [Tổng Quan Hệ Thống](01_SYSTEM_OVERVIEW.md)
2. [Phát Hiện Tín Hiệu (Detectors)](02_DETECTORS.md)
3. [Quyết Định Giao Dịch (Arbiter)](03_ARBITER.md)
4. [Thực Thi Lệnh (Executor)](04_EXECUTOR.md)
5. [Quản Lý Rủi Ro (Risk Manager)](05_RISK_MANAGER.md)
6. [Thống Kê & Dashboard](06_STATS_DASHBOARD.md)
7. [Cấu Hình & Tham Số](07_CONFIGURATION.md)
8. [Luồng Hoạt Động Chính](08_MAIN_FLOW.md)
9. [Ví Dụ Thực Tế](09_EXAMPLES.md)

---

## 🎯 Mục Đích

Bot EA này được thiết kế để giao dịch tự động dựa trên phương pháp **Smart Money Concepts (SMC)** và **Inner Circle Trader (ICT)**, kết hợp với:
- Phát hiện cấu trúc thị trường (BOS/CHOCH)
- Liquidity Sweep
- Order Block & Fair Value Gap
- Momentum Breakout
- Quản lý vị thế động (DCA, Breakeven, Trailing)

---

## 📊 Kiến Trúc Hệ Thống

```
┌─────────────────────────────────────────────────────┐
│              SMC_ICT_EA.mq5 (Main EA)               │
│                                                     │
│  OnInit() → OnTick() → OnTrade() → OnTimer()       │
└──────────────┬──────────────────────────────────────┘
               │
       ┌───────┴────────┬───────────────┬──────────────┐
       ▼                ▼               ▼              ▼
┌─────────────┐  ┌─────────────┐  ┌──────────┐  ┌──────────┐
│ DETECTORS   │  │  ARBITER    │  │ EXECUTOR │  │   RISK   │
│             │  │             │  │          │  │  MANAGER │
│ - BOS       │→ │ - Build     │→ │ - Entry  │→ │ - DCA    │
│ - Sweep     │  │   Candidate │  │ - SL/TP  │  │ - BE     │
│ - OB        │  │ - Score     │  │ - Orders │  │ - Trail  │
│ - FVG       │  │ - Filter    │  │          │  │ - MDD    │
│ - Momentum  │  │             │  │          │  │          │
└─────────────┘  └─────────────┘  └──────────┘  └──────────┘
       │                                              │
       └──────────────────┬───────────────────────────┘
                          ▼
                  ┌──────────────┐
                  │   STATS &    │
                  │  DASHBOARD   │
                  └──────────────┘
```

---

## 🚀 Quick Start

### Bước 1: Cài Đặt
1. Copy tất cả file `.mqh` vào folder `Include/`
2. Copy `SMC_ICT_EA.mq5` vào folder `Experts/`
3. Compile EA trong MetaEditor

### Bước 2: Chọn Preset
Chọn một trong 3 preset có sẵn:
- **Conservative**: Risk thấp, không DCA
- **Balanced**: Cân bằng, DCA 2 levels (Khuyến nghị)
- **Aggressive**: Risk cao, DCA 3 levels

### Bước 3: Backtest
1. Chạy Strategy Tester trên XAUUSD M15
2. Kiểm tra Dashboard và Stats
3. Điều chỉnh tham số nếu cần

---

## ⚙️ Tham Số Chính

| Tham Số | Mô Tả | Giá Trị Mặc Định |
|---------|-------|------------------|
| `InpRiskPerTradePct` | Rủi ro mỗi lệnh (% equity) | 0.5% |
| `InpMinRR` | Tỷ lệ R:R tối thiểu | 2.0 |
| `InpDailyMddMax` | MDD tối đa mỗi ngày (%) | 8.0% |
| `InpEnableDCA` | Bật DCA (Pyramiding) | true |
| `InpEnableBE` | Bật Breakeven | true |
| `InpEnableTrailing` | Bật Trailing Stop | true |
| `InpLotBase` | Lot cơ bản | 0.1 |
| `InpLotMax` | Lot tối đa | 5.0 |

---

## 📈 Tính Năng Chính

### 1. Phát Hiện Tín Hiệu Đa Tầng
- ✅ Break of Structure (BOS/CHOCH)
- ✅ Liquidity Sweep (Fractal-based)
- ✅ Order Block (Demand/Supply zones)
- ✅ Fair Value Gap (Imbalance)
- ✅ Momentum Breakout

### 2. Quản Lý Vị Thế Thông Minh
- ✅ DCA (Dollar Cost Averaging) khi profit tăng
- ✅ Breakeven tự động khi đạt +1R
- ✅ Trailing Stop động theo ATR
- ✅ Basket TP/SL cho toàn bộ vị thế

### 3. Bảo Vệ Vốn
- ✅ Daily MDD Limit (Equity hoặc Balance)
- ✅ Dynamic Lot Sizing theo equity
- ✅ Session & Spread Filter
- ✅ Rollover Protection

### 4. Thống Kê Chi Tiết
- ✅ Win/Loss theo từng pattern
- ✅ Profit Factor, Win Rate
- ✅ Real-time Dashboard trên chart

---

## 📞 Hỗ Trợ

Xem chi tiết trong các file documentation:
- [01_SYSTEM_OVERVIEW.md](01_SYSTEM_OVERVIEW.md) - Tổng quan hệ thống
- [02_DETECTORS.md](02_DETECTORS.md) - Chi tiết phát hiện tín hiệu
- [03_ARBITER.md](03_ARBITER.md) - Logic quyết định
- [04_EXECUTOR.md](04_EXECUTOR.md) - Thực thi lệnh
- [05_RISK_MANAGER.md](05_RISK_MANAGER.md) - Quản lý rủi ro
- [09_EXAMPLES.md](09_EXAMPLES.md) - Ví dụ thực tế

---

**Version**: 1.2  
**Date**: October 2025  
**Timeframe**: M15 (Recommended)  
**Symbol**: XAUUSD

