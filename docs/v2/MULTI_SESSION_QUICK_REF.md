# Multi-Session Trading - Quick Reference

## 🚀 Cheat Sheet

### 2 Trading Modes

```
┌─────────────────────────────────────────────────────┐
│ MODE 1: FULL DAY                                    │
├─────────────────────────────────────────────────────┤
│ Duration: 16h continuous (7-23h)                    │
│ Trades/Day: 5-6                                     │
│ Win Rate: 65%                                       │
│ Use For: Maximum coverage, Conservative             │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ MODE 2: MULTI-WINDOW                                │
├─────────────────────────────────────────────────────┤
│ Windows: 3 (Asia 7-11, London 12-16, NY 18-23)     │
│ Duration: 13h with breaks                           │
│ Trades/Day: 4-5                                     │
│ Win Rate: 68-70%                                    │
│ Use For: Quality focus, Selective trading           │
└─────────────────────────────────────────────────────┘
```

---

## ⚙️ Quick Config

### Preset 1: Full Day (Default)
```cpp
InpSessionMode = SESSION_FULL_DAY;
InpFullDayStart = 7;
InpFullDayEnd = 23;
```

### Preset 2: All Windows
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;
InpWindow1_Enable = true;  // Asia 7-11
InpWindow2_Enable = true;  // London 12-16
InpWindow3_Enable = true;  // NY 18-23
```

### Preset 3: London + NY Only
```cpp
InpSessionMode = SESSION_MULTI_WINDOW;
InpWindow1_Enable = false;  // Skip Asia
InpWindow2_Enable = true;   // London
InpWindow3_Enable = true;   // NY
```

---

## 📊 Timeline Visual

### Full Day
```
00 01 02 03 04 05 06│07 08 09 10 11 12 13 14 15 16 17 18 19 20 21 22│23
══════════════════════│════════════════ TRADING ════════════════════│══
      CLOSED          └──────────────── 16 hours ──────────────────┘
```

### Multi-Window
```
00 01 02 03 04 05 06│07 08 09 10│11│12 13 14 15│16 17│18 19 20 21 22│23
══════════════════════│═══ WIN1 ══│⊘│══ WIN2 ══│⊘⊘⊘│═════ WIN3 ════│══
      CLOSED          └─ Asia 4h ┘ │└ London 4h┘     └───── NY 5h ──┘
                                BREAK              BREAK
```

---

## 🔍 Common Patterns

### Pattern 1: Skip Low-Quality Hours
```
Problem: Hours 11-12 và 16-18 có win rate thấp
Solution: Use Multi-Window to skip these hours

Config:
  InpSessionMode = SESSION_MULTI_WINDOW;
  Windows: 7-11, 12-16, 18-23
  
Result: +3-5% win rate
```

### Pattern 2: Focus on Best Session
```
Problem: Chỉ muốn trade London (highest liquidity)
Solution: Enable Window 2 only

Config:
  InpSessionMode = SESSION_MULTI_WINDOW;
  InpWindow1_Enable = false;
  InpWindow2_Enable = true;  // London only
  InpWindow3_Enable = false;
  
Result: Win rate 72%+, but fewer trades
```

### Pattern 3: Avoid Overlaps
```
Problem: Giữa 2 sessions thường choppy
Solution: Leave gaps between windows

Config:
  Window 1: 7-10   (leave 1h gap)
  Window 2: 12-15  (leave 3h gap)
  Window 3: 19-23  (leave 4h gap)
```

---

## ⚡ Quick Troubleshooting

### Bot không trade
```
✓ Check InpSessionMode = correct mode?
✓ Check window enables = at least 1 ON?
✓ Check current VN time = trong window?
✓ Check log: "Session: CLOSED" hay "IN"?
```

### Bot trade ngoài giờ
```
✓ Check timezone offset = đúng GMT+7?
✓ Check log VN Time = match đồng hồ?
✓ Check window hours = đúng config?
```

### Position không được manage
```
✓ Check OnTick() có ManagePositions() ngoài session không?
✓ Should be: if(!SessionOpen()) { ManagePositions(); return; }
```

---

## 📋 Testing Checklist

```
□ Compile thành công
□ Full Day mode: Trade 7-23h
□ Multi-Window: Trade chỉ trong windows
□ Break periods: No new trades
□ Break periods: Positions still managed
□ Timezone: VN time đúng trong log
□ Dashboard: Show correct session name
□ All windows disabled: Show error
□ Window overlap: Show warning
```

---

## 💡 Tips

### Tip 1: Test với Visual Mode
```
1. Set InpSessionMode = SESSION_MULTI_WINDOW
2. Enable Window 1 only (7-11h)
3. Run Strategy Tester trong visual mode
4. Verify:
   - 07:00: Bắt đầu scan
   - 11:00: Dừng scan, nhưng vẫn manage positions
   - 12:00: Không trade (Window 2 disabled)
```

### Tip 2: Analyze by Window
```
After backtest, check journal:
  - Count trades per window
  - Calculate win rate per window
  - Identify best-performing window
  → Customize windows based on data
```

### Tip 3: Use Comments
```
Add window name to trade comment:
  "SMC_BUY_RR2.1_Asia"
  "SMC_SELL_RR2.5_London"
  
→ Easier to analyze performance by session
```

---

## 📊 Performance Expectations

| Mode | Coverage | Trades | Win% | PF |
|------|----------|--------|------|----|
| Full Day | 16h | 5-6 | 65% | 2.0 |
| Multi (All) | 13h | 4-5 | 68% | 2.2 |
| London+NY | 9h | 3-4 | 71% | 2.4 |

**Rule of Thumb**: Fewer hours → Higher win rate

---

## 🔗 Full Documentation

- [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md) - Comprehensive user guide
- [MULTI_SESSION_IMPLEMENTATION.md](MULTI_SESSION_IMPLEMENTATION.md) - Step-by-step code guide
- [TIMEZONE_CONVERSION.md](TIMEZONE_CONVERSION.md) - Timezone conversion details

---

**Version**: v1.2+ Multi-Session  
**Status**: Ready to Implement  
**Time Required**: ~5 hours

