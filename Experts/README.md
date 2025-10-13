# SMC/ICT Trading EA for MetaTrader 5

**Version:** 1.0  
**Symbol:** XAUUSD (Gold)  
**Timeframe:** M15/M30  
**Trading Method:** Smart Money Concepts (SMC) / Inner Circle Trader (ICT)

## 📋 Overview

This Expert Advisor implements a complete SMC/ICT trading system based on the technical specification in `dev/code.md`. The system identifies high-probability setups by detecting:

- **Break of Structure (BOS/CHOCH)** - Trend confirmation
- **Liquidity Sweeps** - Stop hunts and liquidity grabs
- **Order Blocks (OB)** - Institutional supply/demand zones
- **Fair Value Gaps (FVG)** - Imbalances in price action
- **Momentum Breakouts** - Strong directional moves

## 🎯 Trading Logic

### Pipeline (Signal Flow)

```
Liquidity Sweep → BOS/CHOCH → Pullback to OB/FVG → Trigger Candle → Entry
```

### Entry Criteria

1. **BOS detected** in a direction (bullish/bearish)
2. **Liquidity sweep** opposite to BOS direction
3. **Pullback** touches valid OB or FVG
4. **Trigger candle** with body ≥ 0.4 ATR
5. **RR ratio** ≥ 2.0
6. **Session** and **spread** filters pass

### Signal Prioritization

- **Priority 1:** BOS + Sweep + (OB|FVG) same direction → Score 100+
- **Priority 2:** FVG completed but OB valid → Use OB
- **Priority 3:** Momentum against SMC → Discard momentum
- **Priority 4:** OB touched ≥3 times → Reduce size 50%
- **Priority 5:** FVG mitigated → Lower priority

## 📁 Project Structure

```
smc/
├── include/
│   ├── detectors.mqh        # Detection library (BOS, Sweep, OB, FVG, Momentum)
│   ├── arbiter.mqh          # Signal prioritization & conflict resolution
│   ├── executor.mqh         # Trade execution & session management
│   ├── risk_manager.mqh     # Position sizing, DCA, MDD protection
│   └── draw_debug.mqh       # Chart visualization
├── SMC_ICT_EA.mq5           # Main Expert Advisor
├── SMC_ICT_INDICATOR.mq5    # Visualization indicator
├── README.md                # This file
└── dev/
    └── code.md              # Technical specification
```

## ⚙️ Installation

### 1. Copy Files

Copy the entire `smc` folder to your MetaTrader 5 data folder:

```
C:\Users\[YourUser]\AppData\Roaming\MetaQuotes\Terminal\[TerminalID]\MQL5\Experts\
```

### 2. Compile

Open MetaEditor and compile:
- `SMC_ICT_EA.mq5` - Main EA
- `SMC_ICT_INDICATOR.mq5` - Optional indicator for visualization

### 3. Attach to Chart

1. Open XAUUSD M15 chart
2. Drag `SMC_ICT_EA` from Navigator to chart
3. Configure parameters (see below)
4. Enable AutoTrading

## 🔧 Parameter Configuration

### Unit Convention

```
InpPointsPerPip = 10    # 10 for most brokers, 100 for some
```

### Session & Market

```
InpSessStartHour = 8    # 08:00 GMT+7 (Asia/Ho_Chi_Minh)
InpSessEndHour = 23     # 23:00 GMT+7
InpSpreadMaxPts = 35    # Max 3.5 pips spread
```

### Risk Management

```
InpRiskPerTradePct = 0.3    # 0.3% equity per trade
InpMinRR = 2.0              # Minimum 1:2 Risk:Reward
InpMaxLotPerSide = 3.0      # Max 3 lots per direction
InpMaxDcaAddons = 2         # Max 2 DCA add-ons
InpDailyMddMax = 8.0        # 8% daily max drawdown
```

### BOS Detection

```
InpFractalK = 3             # 3 bars each side for swing
InpLookbackSwing = 50       # 50 bars lookback
InpMinBodyATR = 0.6         # Body ≥ 0.6 × ATR(14)
InpMinBreakPts = 50         # Min 50 points break
InpBOS_TTL = 40             # 40 bars time-to-live
```

### Liquidity Sweep

```
InpLookbackLiq = 30         # 30 bars lookback
InpMinWickPct = 35.0        # 35% wick minimum
InpSweep_TTL = 20           # 20 bars TTL
```

### Order Block

```
InpOB_MaxTouches = 3        # Max 3 touches
InpOB_BufferInvPts = 50     # 50 points buffer
InpOB_TTL = 120             # 120 bars TTL
```

### Fair Value Gap

```
InpFVG_MinPts = 150         # Min 150 points gap
InpFVG_MitigatePct = 35.0   # 35% mitigation threshold
InpFVG_CompletePct = 85.0   # 85% completion threshold
InpFVG_TTL = 60             # 60 bars TTL
```

### Execution

```
InpTriggerBodyATR = 40      # 0.40 × ATR trigger body
InpEntryBufferPts = 70      # 70 points entry buffer
InpMinStopPts = 300         # Min 300 points (30 pips) SL
InpOrder_TTL_Bars = 5       # Cancel pending after 5 bars
```

## 🎨 Visualization

### EA Dashboard

When enabled (`InpShowDashboard = true`), displays:
- Current state (Scanning/Signal Detected/Trading Halted)
- Account balance, equity, P/L
- Open positions count
- Risk metrics

### Chart Objects

When enabled (`InpShowDebugDraw = true`), draws:
- **BOS markers** - Arrows showing break points
- **Sweep levels** - Dashed lines at liquidity levels
- **Order Blocks** - Rectangles showing supply/demand zones
- **FVG boxes** - Dotted rectangles showing imbalances
- **State labels** - Valid/Mitigated/Completed status

### Standalone Indicator

Use `SMC_ICT_INDICATOR.mq5` for visualization without trading:
- Shows all detected structures
- Color-coded by validity
- Info panel with counts

## 📊 Risk Management Features

### Position Sizing

- **Fixed % risk** per trade based on equity
- **Dynamic lot calculation** based on SL distance
- **Min/Max lot limits** enforced

### DCA (Dollar Cost Averaging)

- **Add-on #1:** +0.75R profit → Add 0.5× original size
- **Add-on #2:** +1.5R profit → Add 0.33× original size
- **Max lots per side** respected
- **Automatic SL adjustment** for add-ons

### Breakeven & Trailing

- **Move to BE** at +1R profit
- **Trail SL** based on M5/M15 swings (future enhancement)

### Daily MDD Protection

- **Monitors daily P/L** from session start
- **Closes all positions** when daily loss ≥ 8%
- **Halts trading** for remainder of day
- **Resets** at start of new trading day

## 🔒 Safety Features

### Session Filter

- **Only trades** during configured hours (08:00-23:00 GMT+7)
- **Manages existing positions** outside session
- **No new entries** outside session

### Spread Filter

- **Checks spread** before every entry
- **Max spread:** 35 points (3.5 pips)
- **Protects against** slippage during high volatility

### Rollover Protection

- **Blocks entries** ±5 minutes around 00:00 server time
- **Avoids** spread spikes and gaps

### TTL (Time To Live)

- **Pending orders** auto-cancel after 5 bars
- **POIs expire** based on type (OB: 120 bars, FVG: 60 bars, etc.)
- **Prevents stale signals**

## 📈 Backtest Recommendations

### Optimization Parameters

```
FractalK:        {2, 3, 4}
MinBodyATR:      {0.5, 0.6, 0.7, 0.8}
MinFVG:          {120, 150, 180} points
Buffer:          {50, 70, 100} points
Risk%:           {0.2, 0.3, 0.5}
RR Target:       {2.0, 2.5, 3.0}
TTL:             {3, 4, 5} bars
```

### Test Period

- **Minimum:** 6 months
- **Recommended:** 1-2 years
- **Include:** Various market conditions (trending, ranging, volatile)

### Walk-Forward

1. **Optimize** 6 months
2. **Forward test** 2 months
3. **Roll forward** monthly
4. **Track** out-of-sample performance

### KPIs to Monitor

- **Win Rate:** Target 45-55%
- **Profit Factor:** Target > 1.5
- **Expectancy:** Target positive
- **Sharpe Ratio:** Target > 1.0
- **Max Drawdown:** Target < 15%
- **Recovery Factor:** Target > 2.0
- **Trades/Day:** Target 1-3

## 🐛 Troubleshooting

### EA Not Opening Trades

1. Check **session hours** - Are you in trading window?
2. Check **spread** - Is it below 35 points?
3. Check **daily MDD** - Has limit been exceeded?
4. Check **logs** - Look for detection messages
5. Enable **debug draw** - Verify structures are detected

### Positions Closing Unexpectedly

1. Check **daily MDD** status
2. Verify **TP/SL levels** are valid
3. Check for **broker disconnections**
4. Review **logs** for trade events

### Indicators Not Drawing

1. Verify **indicator compiled** successfully
2. Check **input parameters** match detection settings
3. Ensure **sufficient bars** loaded (200+ recommended)
4. Refresh chart or reattach indicator

## 📝 Logging & JSON Output

### Trade Logs

EA logs key events:
- BOS detection
- Sweep detection
- POI touches
- Entry signals
- Order placement
- Position management events
- Daily MDD checks

### JSON Schema Support

Structure for logging (future enhancement):

```json
{
  "timestamp": "2025-10-14T10:00:00+07:00",
  "method": "BOS",
  "order_type": "Stop",
  "prices": {"entry": 2005.00, "sl": 1990.00, "tp": 2035.00},
  "risk": {"R": 1.0, "%Equity": 0.3},
  "rationale": "Pullback after BOS up touched valid FVG"
}
```

## ⚠️ Disclaimer

This EA is for **educational and testing purposes**. Past performance does not guarantee future results. 

**Use at your own risk.** Always:
- Test on **demo account** first
- Start with **minimum lot sizes**
- Monitor **daily drawdown**
- Understand **SMC/ICT concepts**
- Keep **risk per trade low** (0.3% or less)

## 📚 Resources

### SMC/ICT Learning

- **ICT YouTube Channel** - Inner Circle Trader concepts
- **TradingView** - Chart examples and community
- **Smart Money Concepts** - Order flow and institutional trading

### MQL5 Documentation

- [MQL5 Reference](https://www.mql5.com/en/docs)
- [Trading Functions](https://www.mql5.com/en/docs/trading)
- [Indicators](https://www.mql5.com/en/docs/indicators)

## 🔄 Version History

### v1.0 (2025-10-13)
- Initial release
- Full SMC/ICT pipeline implementation
- BOS, Sweep, OB, FVG, Momentum detection
- Risk management with DCA
- Daily MDD protection
- Session and spread filters
- Chart visualization
- Comprehensive parameter configuration

## 📧 Support

For questions about the specification, refer to `dev/code.md`.

For MQL5 coding issues, consult the [MQL5 documentation](https://www.mql5.com/en/docs).

---

**Built with:** MQL5  
**Tested on:** MetaTrader 5  
**Symbol:** XAUUSD  
**Timeframe:** M15/M30  
**Strategy:** SMC/ICT Pipeline

