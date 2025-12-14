# Timezone Conversion - Hướng Dẫn Chi Tiết

## 📍 Tổng Quan

Bot sử dụng **timezone conversion** để đảm bảo trading session hoạt động đúng giờ địa phương (VN Time = GMT+7), bất kể broker của bạn dùng GMT offset nào.

---

## 🔧 Cơ Chế Hoạt Động

### 1. **Các Thành Phần**

#### A. Input Parameters (`SMC_ICT_EA.mq5`)
```cpp
input string   InpTZ              = "Asia/Ho_Chi_Minh";  // GMT+7
input int      InpSessStartHour   = 7;   // 7:00 VN Time
input int      InpSessEndHour     = 23;  // 23:00 VN Time
```

#### B. Executor Variables (`executor.mqh`)
```cpp
int m_timezoneOffset = 7;  // GMT+7 cho VN
```

#### C. Conversion Logic (`SessionOpen()` function)
```cpp
// 1. Lấy GMT offset của broker
int server_gmt = (int)(TimeGMTOffset() / 3600);

// 2. GMT offset của target timezone (VN)
int vn_gmt = 7;

// 3. Tính delta (chênh lệch)
int delta = vn_gmt - server_gmt;

// 4. Chuyển đổi server hour → VN hour
int hour_localvn = (s.hour + delta + 24) % 24;
```

---

## 📊 Ví Dụ Chi Tiết

### **Ví Dụ 1: Broker GMT+0 (IC Markets, Pepperstone)**

**Server Time: 14:00 GMT+0**

```
server_gmt = 0
vn_gmt = 7
delta = 7 - 0 = 7

hour_localvn = (14 + 7 + 24) % 24
            = 45 % 24
            = 21 (9:00 PM VN Time) ✅
```

| Server Time (GMT+0) | VN Time (GMT+7) | In Session (7-23)? |
|---------------------|-----------------|-------------------|
| 00:00               | 07:00           | ✅ YES            |
| 06:00               | 13:00           | ✅ YES            |
| 16:00               | 23:00           | ✅ YES (cuối)     |
| 17:00               | 00:00           | ❌ NO             |
| 23:00               | 06:00           | ❌ NO             |

---

### **Ví Dụ 2: Broker GMT+2 (Exness, XM)**

**Server Time: 16:00 GMT+2**

```
server_gmt = 2
vn_gmt = 7
delta = 7 - 2 = 5

hour_localvn = (16 + 5 + 24) % 24
            = 45 % 24
            = 21 (9:00 PM VN Time) ✅
```

| Server Time (GMT+2) | VN Time (GMT+7) | In Session (7-23)? |
|---------------------|-----------------|-------------------|
| 02:00               | 07:00           | ✅ YES            |
| 08:00               | 13:00           | ✅ YES            |
| 18:00               | 23:00           | ✅ YES (cuối)     |
| 19:00               | 00:00           | ❌ NO             |

---

### **Ví Dụ 3: Broker GMT+3 (Alpari, RoboForex)**

**Server Time: 10:00 GMT+3**

```
server_gmt = 3
vn_gmt = 7
delta = 7 - 3 = 4

hour_localvn = (10 + 4 + 24) % 24
            = 38 % 24
            = 14 (2:00 PM VN Time) ✅
```

| Server Time (GMT+3) | VN Time (GMT+7) | In Session (7-23)? |
|---------------------|-----------------|-------------------|
| 03:00               | 07:00           | ✅ YES            |
| 09:00               | 13:00           | ✅ YES            |
| 19:00               | 23:00           | ✅ YES (cuối)     |
| 20:00               | 00:00           | ❌ NO             |

---

### **Ví Dụ 4: Edge Case - Negative Delta**

**Giả sử broker GMT+10 (Sydney), muốn trade theo VN GMT+7**

```
server_gmt = 10
vn_gmt = 7
delta = 7 - 10 = -3

Nếu server time = 05:00 GMT+10
hour_localvn = (5 + (-3) + 24) % 24
            = 26 % 24
            = 2 (2:00 AM VN Time) ❌ Ngoài session
```

> **Lưu ý**: `+ 24` trong công thức để tránh số âm khi modulo

---

## 🎯 Cách Customize Cho Timezone Khác

### **Thay Đổi Sang London Time (GMT+0)**

1. **Sửa `executor.mqh` (line 80)**
```cpp
m_timezoneOffset = 0;  // GMT+0 cho London
```

2. **Sửa session trong EA inputs**
```cpp
input int InpSessStartHour = 8;   // 8:00 AM London
input int InpSessEndHour   = 20;  // 8:00 PM London
```

3. **Logic tự động adjust** - không cần sửa `SessionOpen()`

---

### **Thay Đổi Sang New York Time (GMT-5/GMT-4)**

1. **Sửa `executor.mqh`**
```cpp
m_timezoneOffset = -5;  // GMT-5 cho NY (winter)
// hoặc -4 cho daylight saving
```

2. **Sửa session**
```cpp
input int InpSessStartHour = 9;   // 9:00 AM NY
input int InpSessEndHour   = 21;  // 9:00 PM NY
```

---

## 🐛 Debug & Verification

### **Check Log Output**

Bot tự động log timezone info mỗi giờ:

```
🕐 Session Check | Server: 14:00 | VN Time: 21:00 | Status: IN SESSION ✅
🕐 Session Check | Server: 17:00 | VN Time: 00:00 | Status: CLOSED ❌
```

### **Test Timezone Conversion**

Thêm code này vào `OnInit()` để test:

```cpp
Print("═══ TIMEZONE TEST ═══");
MqlDateTime s;
TimeToStruct(TimeCurrent(), s);

int server_gmt = (int)(TimeGMTOffset() / 3600);
int vn_gmt = 7;
int delta = vn_gmt - server_gmt;
int hour_localvn = (s.hour + delta + 24) % 24;

Print("Server GMT: +", server_gmt);
Print("Target GMT: +", vn_gmt);
Print("Delta: ", delta);
Print("Server Hour: ", s.hour, ":00");
Print("Local Hour: ", hour_localvn, ":00");
Print("═══════════════════");
```

**Output mẫu:**
```
═══ TIMEZONE TEST ═══
Server GMT: +2
Target GMT: +7
Delta: 5
Server Hour: 16:00
Local Hour: 21:00
═══════════════════
```

---

## 📋 Bảng Chuyển Đổi Nhanh

### **VN Time (GMT+7) → Server Time**

| Broker GMT | Session 7-23 VN | Server Start | Server End |
|------------|-----------------|--------------|------------|
| GMT+0      | 7:00 - 23:00 VN | 00:00        | 16:00      |
| GMT+2      | 7:00 - 23:00 VN | 02:00        | 18:00      |
| GMT+3      | 7:00 - 23:00 VN | 03:00        | 19:00      |
| GMT+7      | 7:00 - 23:00 VN | 07:00        | 23:00      |

---

## ⚠️ Lưu Ý Quan Trọng

### 1. **Daylight Saving Time (DST)**
- Một số broker tự động adjust GMT offset khi DST
- Check log hàng ngày để verify
- Có thể cần update `m_timezoneOffset` theo mùa

### 2. **TimeGMTOffset() Function**
```cpp
// Trả về offset tính bằng GIÂY
TimeGMTOffset() / 3600  // Convert sang GIỜ
```

### 3. **Modulo 24 Wrap-Around**
```cpp
(hour + delta + 24) % 24
```
- `+ 24` đảm bảo không âm
- `% 24` wrap 25→1, 26→2, etc.

### 4. **Session Overlap**
Nếu session cross midnight (ví dụ: 22:00 → 02:00):
```cpp
// Cần logic đặc biệt
bool inSession = (hour >= m_sessStartHour) || (hour < m_sessEndHour);
```
> Bot hiện tại **KHÔNG hỗ trợ** session qua midnight

---

## 🔍 Troubleshooting

### **Vấn Đề: Bot trade sai giờ**

1. **Check broker GMT offset**
```cpp
Print("Broker GMT: ", (int)(TimeGMTOffset() / 3600));
```

2. **Verify timezone log**
- Xem log mỗi giờ: `Session Check | Server: X | VN Time: Y`
- So sánh với đồng hồ thực tế

3. **Test với session rộng**
```cpp
input int InpSessStartHour = 0;   // 24/7 để test
input int InpSessEndHour   = 24;
```

### **Vấn Đề: Log không hiện**

Check `lastLogHour` reset:
```cpp
static int lastLogHour = -1;
if(s.hour != lastLogHour) {
    // Log sẽ chỉ hiện 1 lần/giờ
}
```

---

## 📝 Tóm Tắt Công Thức

```
VN_Hour = (Server_Hour + Delta + 24) % 24

Trong đó:
  Delta = VN_GMT - Server_GMT
  VN_GMT = 7 (cố định)
  Server_GMT = TimeGMTOffset() / 3600
```

### **Ví Dụ Cuối:**
```
Broker: GMT+2
Server Time: 15:30 GMT+2
Delta: 7 - 2 = 5
VN Time: (15 + 5) % 24 = 20:00 (8 PM) ✅
Session 7-23: TRONG PHIÊN
```

---

## 🎓 Best Practices

1. **Luôn verify timezone** sau khi đổi broker
2. **Check log hourly** trong tuần đầu
3. **Không hardcode** server time - dùng conversion
4. **Test trước** với session 24/7
5. **Document** GMT offset của broker hiện tại

---

---

## 🔄 Multi-Session Support

### Overview

Bot hỗ trợ **2 chế độ session**:
1. **FULL DAY**: 7-23h continuous (simple)
2. **MULTI-WINDOW**: 3 khung giờ riêng biệt (flexible)

Chi tiết: [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md)

---

### Multi-Window Logic

```cpp
bool SessionOpen() {
    MqlDateTime s;
    TimeToStruct(TimeCurrent(), s);
    
    // Calculate VN time (GMT+7) - SAME FORMULA
    int server_gmt = (int)(TimeGMTOffset() / 3600);
    int vn_gmt = 7;
    int delta = vn_gmt - server_gmt;
    int hour_localvn = (s.hour + delta + 24) % 24;
    
    bool inSession = false;
    
    // ═══════════════════════════════════════════════════
    // MODE 1: Full Day
    // ═══════════════════════════════════════════════════
    if(m_sessionMode == SESSION_FULL_DAY) {
        inSession = (hour_localvn >= m_sessStartHour && 
                    hour_localvn < m_sessEndHour);
    }
    // ═══════════════════════════════════════════════════
    // MODE 2: Multi-Window
    // ═══════════════════════════════════════════════════
    else {
        // Check Window 1: Asia (7-11)
        if(m_windows[0].enabled &&
           hour_localvn >= m_windows[0].startHour &&
           hour_localvn < m_windows[0].endHour) {
            inSession = true;
        }
        // Check Window 2: London (12-16)
        else if(m_windows[1].enabled &&
                hour_localvn >= m_windows[1].startHour &&
                hour_localvn < m_windows[1].endHour) {
            inSession = true;
        }
        // Check Window 3: NY (18-23)
        else if(m_windows[2].enabled &&
                hour_localvn >= m_windows[2].startHour &&
                hour_localvn < m_windows[2].endHour) {
            inSession = true;
        }
    }
    
    return inSession;
}
```

**Key Point**: Timezone conversion **GIỐNG NHAU** cho cả 2 modes - chỉ khác logic check!

---

### Example: Multi-Window với Broker GMT+2

**Config**:
```
Broker: GMT+2 (Exness)
Windows: 7-11, 12-16, 18-23 (GMT+7)
```

**Conversion**:
```
Delta = 7 - 2 = 5

VN 07:00 → Server 02:00  ✅ Window 1 start
VN 11:00 → Server 06:00  ❌ Window 1 end (BREAK)
VN 12:00 → Server 07:00  ✅ Window 2 start
VN 16:00 → Server 11:00  ❌ Window 2 end (BREAK)
VN 18:00 → Server 13:00  ✅ Window 3 start
VN 23:00 → Server 18:00  ❌ Window 3 end (CLOSED)
```

**Server Time Schedule**:
```
Server Time    VN Time     Status
═══════════════════════════════════════
01:59          06:59       CLOSED
02:00          07:00       Window 1 ✅
06:00          11:00       BREAK 🔴
07:00          12:00       Window 2 ✅
11:00          16:00       BREAK 🔴
13:00          18:00       Window 3 ✅
18:00          23:00       CLOSED ❌
```

---

### Log Output Example

**Full Day Mode**:
```
🕐 Session Check | Server: 02:00 | VN Time: 07:00 | Mode: FULL DAY | Session: FULL DAY | Status: IN ✅
🕐 Session Check | Server: 08:00 | VN Time: 13:00 | Mode: FULL DAY | Session: FULL DAY | Status: IN ✅
```

**Multi-Window Mode**:
```
🕐 Session Check | Server: 02:00 | VN Time: 07:00 | Mode: MULTI-WINDOW | Session: Asia | Status: IN ✅
🕐 Session Check | Server: 06:00 | VN Time: 11:00 | Mode: MULTI-WINDOW | Session: CLOSED | Status: OUT ❌
🕐 Session Check | Server: 07:00 | VN Time: 12:00 | Mode: MULTI-WINDOW | Session: London | Status: IN ✅
🕐 Session Check | Server: 11:00 | VN Time: 16:00 | Mode: MULTI-WINDOW | Session: CLOSED | Status: OUT ❌
🕐 Session Check | Server: 13:00 | VN Time: 18:00 | Mode: MULTI-WINDOW | Session: NY | Status: IN ✅
🕐 Session Check | Server: 18:00 | VN Time: 23:00 | Mode: MULTI-WINDOW | Session: CLOSED | Status: OUT ❌
```

---

## 🎓 See Also

- [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md) - Full guide
- [04_EXECUTOR.md](04_EXECUTOR.md) - Session management details
- [07_CONFIGURATION.md](07_CONFIGURATION.md) - Parameter setup

---

**File liên quan:**
- `Include/executor.mqh` (lines 135-157) - `SessionOpen()`
- `Experts/SMC_ICT_EA.mq5` (lines 28-30) - Session inputs
- [MULTI_SESSION_TRADING.md](MULTI_SESSION_TRADING.md) - Multi-session guide
