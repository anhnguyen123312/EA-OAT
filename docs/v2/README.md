# SMC/ICT EA v1.2 - Documentation

## 📚 Mục Lục

1. [Tổng Quan Hệ Thống](01_SYSTEM_OVERVIEW.md)
2. [Phát Hiện Tín Hiệu (Detectors)](02_DETECTORS.md) - **Updated v2.0** 🆕
3. [Quyết Định Giao Dịch (Arbiter)](03_ARBITER.md) - **Updated v2.0** 🆕
4. [Thực Thi Lệnh (Executor)](04_EXECUTOR.md) - **Updated v2.0** 🆕
5. [Quản Lý Rủi Ro (Risk Manager)](05_RISK_MANAGER.md) - **Updated v2.0** 🆕
6. [Thống Kê & Dashboard](06_STATS_DASHBOARD.md)
7. [Cấu Hình & Tham Số](07_CONFIGURATION.md) - **Updated v2.0** 🆕
8. [Luồng Hoạt Động Chính](08_MAIN_FLOW.md) - **Updated v2.0** 🆕
9. [Ví Dụ Thực Tế](09_EXAMPLES.md)
10. [🔮 Roadmap Cải Tiến](10_IMPROVEMENTS_ROADMAP.md) - **NEW** 🔥

---

## 🚀 Tài Liệu Bổ Sung

### Feature Guides
- [Multi-Session Trading](MULTI_SESSION_TRADING.md) - **NEW** 🔥 Hướng dẫn 2 chế độ trading
- [Multi-Session Implementation](MULTI_SESSION_IMPLEMENTATION.md) - **NEW** 🔧 Hướng dẫn code
- [Multi-Session Quick Reference](MULTI_SESSION_QUICK_REF.md) - **NEW** ⚡ Cheat sheet
- [DCA Mechanism](DCA_MECHANISM.md) - Chi tiết về pyramiding
- [Timezone Conversion](TIMEZONE_CONVERSION.md) - Hướng dẫn timezone

### Status & Summary
- [Documentation Complete](DOCUMENTATION_COMPLETE.md) - **NEW** ✅ Tổng kết hoàn thành
- [Update Summary](UPDATE_SUMMARY.md) - **NEW** 📝 Tóm tắt cập nhật

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
- ✅ Daily MDD Limit (Equity)
- ✅ Dynamic Lot Sizing theo equity
- ✅ Session & Spread Filter
- ✅ Rollover Protection

### 4. Thống Kê Chi Tiết
- ✅ Win/Loss theo từng pattern
- ✅ Profit Factor, Win Rate
- ✅ Real-time Dashboard trên chart

---

## 🚀 What's New in v2.0

### 🆕 Major Updates (Chi tiết trong từng file)
- 🔔 **News Embargo Filter** → [04_EXECUTOR.md](04_EXECUTOR.md)
- 📊 **Volatility Regime** → [04_EXECUTOR.md](04_EXECUTOR.md)
- 🎯 **ATR-Scaled Execution** → [04_EXECUTOR.md](04_EXECUTOR.md)
- ⭐ **Extended Scoring** → [03_ARBITER.md](03_ARBITER.md)
- 🛡️ **Risk Overlays** → [05_RISK_MANAGER.md](05_RISK_MANAGER.md)
- 🔄 **Adaptive DCA/Trailing** → [05_RISK_MANAGER.md](05_RISK_MANAGER.md)

### 📊 Expected Improvements
- Win Rate: **+3-5%** (65% → 68-70%)
- Profit Factor: **+0.15** (2.0 → 2.15+)
- Max Drawdown: **≤8%** (no increase)

---

## 📞 Hỗ Trợ

Xem chi tiết trong các file documentation:

---

---

## 📊 v2.0 Implementation Checklist

### Priority 1: Core Updates (Week 1)
- [ ] News Embargo Filter → `04_EXECUTOR.md`
- [ ] Volatility Regime Detection → `04_EXECUTOR.md`
- [ ] ATR-Scaled Execution → `04_EXECUTOR.md`
- [ ] Extended Arbiter Scoring → `03_ARBITER.md`

### Priority 2: Risk & Analytics (Week 2)
- [ ] Risk Overlays (MaxTrades, Cooldown) → `05_RISK_MANAGER.md`
- [ ] Adaptive DCA by Regime → `05_RISK_MANAGER.md`
- [ ] Adaptive Trailing by Regime → `05_RISK_MANAGER.md`
- [ ] Stats Enhancement (regime tracking)

### Testing & Validation
- [ ] Backtest v1.2 (baseline)
- [ ] Backtest v2.0 (each feature)
- [ ] Backtest v2.0 (full integration)
- [ ] Forward test (demo 2 weeks)

---

## 🎯 Expected Results (v2.0)

| Metric | v1.2 Baseline | v2.0 Target | Impact |
|--------|---------------|-------------|--------|
| Win Rate | 65% | 68-70% | +3-5% |
| Profit Factor | 2.0 | 2.15+ | +0.15 |
| Max Drawdown | 8% | ≤8% | No increase |
| Trades/Day | 5 | 4-6 | ±20% |
| Consecutive Loss | 5 | ≤3 | Reduced |

**Source**: Based on UPDATE_SPEC analysis & Step.md recommendations

---

## 🔮 v2.0+ Future Improvements

### 📋 Overview

Dựa trên phân tích chi tiết logic ICT/SMC, đã xác định được **4 điểm cải tiến chính**:

#### 1. **Sweep + BOS Requirement** 🔴 Critical
```
Current: BOS + OB → Valid (không cần sweep)
Proposed: Sweep + BOS + OB/FVG → Valid (ICT gold standard)

Expected Impact:
  ✅ Win rate: +5-8%
  ✅ Trade quality: Higher
  ⚠️ Trade count: -30-40%
```

#### 2. **Limit Order Entry** 🔴 Critical  
```
Current: Stop orders (chase breakout)
Proposed: Limit orders at POI (wait for pullback)

Example:
  Stop:  Entry 2651.50 | SL 2648.00 | Risk 3.50 pts | RR 2:1
  Limit: Entry 2649.00 | SL 2648.00 | Risk 1.00 pt  | RR 9:1 ⭐

Expected Impact:
  ✅ RR ratio: 2.0 → 3.5-4.0
  ✅ Win rate: +2-4%
  ⚠️ Fill rate: 95% → 65% (trade-off)
```

#### 3. **MA Trend Filter** 🟡 High Priority
```
Current: Only price structure (MTF bias)
Proposed: Add EMA 20/50 crossover

Expected Impact:
  ✅ Reduce counter-trend losses: -60-70%
  ✅ Win rate: +3-5%
  ⚠️ Trade count: -15-20%
```

#### 4. **WAE Momentum Confirmation** 🟡 High Priority
```
Current: Body size > ATR threshold
Proposed: Waddah Attar Explosion indicator

Expected Impact:
  ✅ Filter weak breakouts: -25-30% trades
  ✅ Win rate: +4-6%
  ✅ Profit factor: +0.2-0.3
```

---

### 📊 Combined Impact Estimate

| Metric | Current v1.2 | Target v2.0+ | Improvement |
|--------|--------------|--------------|-------------|
| **Win Rate** | 65% | **72-75%** | +7-10% |
| **Profit Factor** | 2.0 | **2.3-2.5** | +15-25% |
| **Avg RR** | 2.0 | **3.0-3.5** | +50-75% |
| **Trade Count** | 5-6/day | **3-4/day** | -30-40% |
| **Trade Quality** | Mixed | **High** | ⭐ |

---

### 🎯 Implementation Status

- ✅ **Documentation Complete** - All 4 improvements documented
  - [10_IMPROVEMENTS_ROADMAP.md](10_IMPROVEMENTS_ROADMAP.md) - Master plan
  - [03_ARBITER.md](03_ARBITER.md#-proposed-improvements-based-on-analysis) - Confluence logic
  - [04_EXECUTOR.md](04_EXECUTOR.md#-proposed-improvements-limit-order-entry) - Entry methods

- 🚧 **Code Implementation** - Not started
  - Phase 1 (Week 1-2): Sweep + BOS requirement
  - Phase 2 (Week 3): Limit order entry
  - Phase 3 (Week 4): MA filter & WAE
  - Phase 4 (Week 5): Testing & validation

---

### 📖 Quick Links

- **[Full Roadmap](10_IMPROVEMENTS_ROADMAP.md)** - Chi tiết đầy đủ
- **[Arbiter Improvements](03_ARBITER.md#-proposed-improvements-based-on-analysis)** - Confluence logic
- **[Executor Improvements](04_EXECUTOR.md#-proposed-improvements-limit-order-entry)** - Entry methods

---

**Version**: 1.2 → 2.0 (in development)  
**Date**: October 2025  
**Timeframe**: M15/M30 (M30 focus for v2.0)  
**Symbol**: XAUUSD

