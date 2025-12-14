# Lịch Giao Dịch - Thời Gian Trade

## 📍 Tổng Quan

Tài liệu này mô tả **thời gian giao dịch** của bot EA theo góc độ business logic.

---

## 🎯 1. Hai Chế Độ Giao Dịch

### Mode 1: Full Day (Mặc Định) ⭐

#### Mô Tả
Giao dịch liên tục trong 1 khung giờ dài, không có break.

#### Timeline GMT+7:
```
00:00 ════════════════════════════════ Closed
07:00 ────────────────────────────────┐
      │  TRADING (Continuous)          │
      │  - Scan signals                │
      │  - Place orders                │
      │  - Manage positions            │
23:00 ────────────────────────────────┘
00:00 ════════════════════════════════ Closed (next day)

Duration: 16 hours continuous
```

#### Use Case:
- ✅ Catch tất cả opportunities
- ✅ Không bỏ lỡ signals
- ✅ Simple setup
- ✅ Phù hợp: Conservative traders, full automation

#### Cấu Hình:
```
InpSessionMode = SESSION_FULL_DAY
InpFullDayStart = 7   (07:00 GMT+7)
InpFullDayEnd = 23    (23:00 GMT+7)
```

---

### Mode 2: Multi-Session

#### Mô Tả
Giao dịch chỉ trong các khung giờ "vàng" (high liquidity), có break giữa các session.

#### Timeline GMT+7:
```
00:00 ════════════════════════════════ Closed
07:00 ────────────────────────────────┐
      │ WINDOW 1: ASIA SESSION         │
11:00 ────────────────────────────────┘
      ⊘ Break (11:00-12:00)
12:00 ────────────────────────────────┐
      │ WINDOW 2: LONDON SESSION       │
16:00 ────────────────────────────────┘
      ⊘ Break (16:00-18:00)
18:00 ────────────────────────────────┐
      │ WINDOW 3: NY SESSION           │
23:00 ────────────────────────────────┘
00:00 ════════════════════════════════ Closed

Total Trading: 4h + 4h + 5h = 13 hours
Breaks: 1h + 2h = 3 hours rest
```

#### Use Case:
- ✅ Focus vào high-liquidity sessions
- ✅ Tránh choppy periods (lunch, overlap gaps)
- ✅ Better win rate (trade quality > quantity)
- ✅ Phù hợp: Active traders, specific session preference

#### Cấu Hình:
```
InpSessionMode = SESSION_MULTI_WINDOW

// Window 1: Asia
InpWindow1_Enable = true
InpWindow1_Start = 7   (07:00 GMT+7)
InpWindow1_End = 11   (11:00 GMT+7)

// Window 2: London
InpWindow2_Enable = true
InpWindow2_Start = 12  (12:00 GMT+7)
InpWindow2_End = 16   (16:00 GMT+7)

// Window 3: NY
InpWindow3_Enable = true
InpWindow3_Start = 18  (18:00 GMT+7)
InpWindow3_End = 23   (23:00 GMT+7)
```

---

## 🎯 2. So Sánh Hai Chế Độ

| Tiêu Chí | Full Day | Multi-Session |
|----------|----------|---------------|
| **Thời gian trade** | 16 giờ | 13 giờ |
| **Số lượng signals** | Nhiều hơn | Ít hơn (chất lượng) |
| **Win rate** | Trung bình | Cao hơn |
| **Phù hợp** | Conservative, automation | Active, session-focused |
| **Setup** | Đơn giản | Phức tạp hơn |

---

## 🎯 3. Các Session Chính

### Asia Session (07:00-11:00 GMT+7)

#### Đặc Điểm:
- **Liquidity**: Trung bình
- **Volatility**: Thấp đến trung bình
- **Spread**: Thường rộng hơn
- **Phù hợp**: Range trading, breakout sớm

### London Session (12:00-16:00 GMT+7)

#### Đặc Điểm:
- **Liquidity**: Cao
- **Volatility**: Trung bình đến cao
- **Spread**: Tốt
- **Phù hợp**: Trend following, momentum

### NY Session (18:00-23:00 GMT+7)

#### Đặc Điểm:
- **Liquidity**: Rất cao
- **Volatility**: Cao
- **Spread**: Tốt nhất
- **Phù hợp**: Strong trends, high momentum

---

## 🎯 4. Khi Nào KHÔNG Được Trade?

### ❌ Ngoài Giờ Session

Bot tự động skip khi:
- Không trong giờ session được cấu hình
- Đang trong break (Multi-Session mode)

### ❌ Spread Quá Rộng

Bot tự động skip khi:
- Spread > MaxSpread (dynamic theo ATR)
- Spread > MaxSpreadPts (fixed points)

### ❌ Daily MDD Đạt Limit

Bot tự động dừng khi:
- Daily MDD ≥ 8% (mặc định)
- Đóng tất cả positions
- Dừng đến ngày hôm sau

### ❌ Rollover Time

Bot tự động skip khi:
- Trong thời gian rollover (nếu bật check)
- Tránh spread spikes

### ❌ News Embargo (Nếu Bật)

Bot tự động skip khi:
- Trước/sau tin tức quan trọng (nếu bật filter)
- Tránh volatility spikes

---

## 🎯 5. Timezone Conversion

### Quy Tắc

Bot tự động convert server time sang **GMT+7** (Vietnam time) để kiểm tra session.

### Công Thức:
```
Server GMT Offset = TimeGMTOffset() / 3600
VN GMT = 7
Delta = 7 - Server GMT Offset
VN Hour = (Server Hour + Delta + 24) % 24
```

### Ví Dụ:

#### Server GMT+0 (London):
```
Server Time: 10:00 GMT+0
Delta = 7 - 0 = 7
VN Hour = (10 + 7) % 24 = 17:00 GMT+7
```

#### Server GMT+3 (Moscow):
```
Server Time: 10:00 GMT+3
Delta = 7 - 3 = 4
VN Hour = (10 + 4) % 24 = 14:00 GMT+7
```

**Chi tiết**: Xem `code_logic/TIMEZONE_CONVERSION.md`

---

## 🎯 6. Ví Dụ Timeline

### Full Day Mode - Một Ngày

```
00:00 ──────────────────────────────────────── Closed
07:00 ────────────────────────────────────────┐
      │ Session OPEN                           │
      │ ✅ Scan signals                        │
      │ ✅ Place orders                        │
      │ ✅ Manage positions                    │
      │                                        │
      │ [07:00-23:00: Continuous trading]     │
      │                                        │
23:00 ────────────────────────────────────────┘
00:00 ──────────────────────────────────────── Closed
```

### Multi-Session Mode - Một Ngày

```
00:00 ──────────────────────────────────────── Closed
07:00 ────────────────────────────────────────┐
      │ Window 1: ASIA                        │
      │ ✅ Trading                            │
11:00 ────────────────────────────────────────┘
      ⊘ Break (11:00-12:00)
12:00 ────────────────────────────────────────┐
      │ Window 2: LONDON                       │
      │ ✅ Trading                            │
16:00 ────────────────────────────────────────┘
      ⊘ Break (16:00-18:00)
18:00 ────────────────────────────────────────┐
      │ Window 3: NY                           │
      │ ✅ Trading                            │
23:00 ────────────────────────────────────────┘
00:00 ──────────────────────────────────────── Closed
```

---

## 🎯 7. Khuyến Nghị

### Cho Trader Mới:
- ✅ Dùng **Full Day Mode**
- ✅ Đơn giản, không cần cấu hình nhiều
- ✅ Catch tất cả opportunities

### Cho Trader Có Kinh Nghiệm:
- ✅ Dùng **Multi-Session Mode**
- ✅ Focus vào high-liquidity sessions
- ✅ Better win rate

### Cho Conservative Trader:
- ✅ Dùng **Full Day Mode**
- ✅ Risk thấp, spread tốt hơn
- ✅ Automation đầy đủ

### Cho Active Trader:
- ✅ Dùng **Multi-Session Mode**
- ✅ Trade trong giờ tốt nhất
- ✅ Tránh choppy periods

---

## 🔗 Tài Liệu Liên Quan

- [TRADING_RULES.md](TRADING_RULES.md) - Tổng hợp quy tắc giao dịch
- [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md) - Chi tiết multi-session
- [07_CONFIGURATION.md](07_CONFIGURATION.md) - Cấu hình tham số

---

**Cập nhật lần cuối**: 2025-12-14  
**Phiên bản**: v2.1

