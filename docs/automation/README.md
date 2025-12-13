# SMC/ICT EA Auto-Optimization System

Hệ thống tự động backtest và tối ưu hóa EA để đạt target win rate.

## 📁 Files

| File | Description |
|------|-------------|
| `optimize_ea.ps1` | Script chính - chạy optimization loop |
| `run_single_backtest.ps1` | Test nhanh 1 backtest |
| `backtest_config.txt` | Template config cho MT5 Tester |
| `V2-oat.set.txt` | Template parameters EA |

## 🚀 Quick Start

### 1. Chuẩn bị

1. Copy `backtest_config.txt` → `MQL5\Profiles\Tester\backtest_config.ini`
2. Copy `V2-oat.set.txt` → `MQL5\Profiles\Tester\V2-oat.set`

### 2. Test Single Backtest

```powershell
cd "path\to\MQL5\docs\automation"
.\run_single_backtest.ps1 -MT5Path "C:\Program Files\MetaTrader 5"
```

### 3. Run Full Optimization

```powershell
.\optimize_ea.ps1 -MT5Path "C:\Program Files\MetaTrader 5" -TargetWinRate 80 -MaxIterations 50
```

## ⚙️ Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-MT5Path` | `C:\Program Files\MetaTrader 5` | Đường dẫn MT5 |
| `-TargetWinRate` | 80 | Target win rate % |
| `-MaxIterations` | 50 | Số lần thử tối đa |
| `-Symbol` | XAUUSD | Symbol để test |
| `-Period` | M30 | Timeframe |
| `-FromDate` | 2024.01.01 | Ngày bắt đầu |
| `-ToDate` | 2024.12.01 | Ngày kết thúc |

## 📊 Output

- `optimization_results.json` - Log tất cả iterations
- `best_params.json` - Parameters tốt nhất tìm được
- Backtest reports trong `MQL5\tester\`

## ⚠️ Lưu ý

1. **MT5 phải được đóng** trước khi chạy script (script sẽ tự mở/đóng MT5)
2. **Data cần được download** đầy đủ cho symbol/timeframe đã chọn
3. **80% win rate là rất cao** - có thể không đạt được với mọi điều kiện
4. Tránh **overfitting** bằng cách test trên data khác sau khi optimize

## 🔧 EA Parameters được tối ưu

| Parameter | Range | Purpose |
|-----------|-------|---------|
| InpMinRR | 1.5-4.0 | Min Risk:Reward ratio |
| InpFractalK | 3-8 | Swing detection depth |
| InpMinBreakPts | 100-400 | BOS filter strength |
| InpMinStopPts | 800-1500 | Min SL distance |
| InpSpreadMaxPts | 300-600 | Max spread filter |
| InpMinBodyATR | 0.5-1.2 | Min candle body (ATR) |
| InpOB_MinSizePts | 150-350 | Min Order Block size |
