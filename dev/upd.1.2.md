Tóm tắt thẳng tay các “chốt chặn” đang khiến EA của bạn chạy 1 tháng không vào được lệnh — kèm patch/fix cụ thể:

# 1) Sai logic timezone ⇒ luôn “ngoài phiên”

* Hiện tại bạn đang lấy **giờ server** rồi cộng “+7” cố định để so với cửa sổ 08:00–23:00. Nếu server không ở UTC (đa phần broker là UTC+2/+3 theo DST) thì phép cộng +7 **không phải** quy đổi “server → Asia/Ho_Chi_Minh”, mà thành một offset sai ⇒ SessionOpen() thường false.
* **Fix**: dùng **độ lệch giữa TZ đích (Asia/Ho_Chi_Minh, +7)** và **TZ server** (lấy từ TimeTradeServer) hoặc bỏ quy đổi, so trực tiếp bằng **giờ server** + cấu hình Session theo **giờ server**.

```cpp
// Cách 1: So trực tiếp theo giờ server (đơn giản & ổn định)
bool CExecutor::SessionOpen() {
  MqlDateTime s; TimeToStruct(TimeCurrent(), s); // server time
  return (s.hour >= m_sessStartHour && s.hour < m_sessEndHour);
}
// => đặt InpSessStartHour/EndHour theo GIỜ SERVER thay vì giờ VN.

// Cách 2: Tính delta đúng (nếu vẫn muốn nhập giờ theo VN)
int server_gmt = (int)TimeGMTOffset()/3600;   // xấp xỉ
int vn_gmt = 7;
int delta = vn_gmt - server_gmt;
int hour_localvn = (s.hour + delta + 24) % 24;
return (hour_localvn >= m_sessStartHour && hour_localvn < m_sessEndHour);
```

> Trong đặc tả bạn tự khóa khung “08:00–23:00 Asia/Ho_Chi_Minh”, nên SessionOpen là điều kiện chặn số 1 (khi sai thì mọi thứ dừng từ đầu vòng OnTick). 

# 2) Spread filter quá chặt

* Bạn đang **chặn cứng** khi `SYMBOL_SPREAD > InpSpreadMaxPts` (mặc định 35 points = 3.5 pip nếu 1 pip = 10 points). Vàng nhiều broker thường >35 points trong phần lớn thời gian ⇒ **SpreadOK() thường false**.
* **Fix**: nâng ngưỡng (ví dụ 120–250 points tùy broker) hoặc chuyển sang **ATR-based filter** linh hoạt:

```cpp
bool CExecutor::SpreadOK() {
  long sp = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
  double atr = GetATR();
  // chấp nhận spread tới min(ngưỡng cố định, 8% ATR) chẳng hạn
  long dyn = (long)MathMax(m_spreadMaxPts, 0.08 * atr / _Point);
  return sp <= dyn;
}
```

> Bộ lọc này nằm trong score/filters của bạn: “Spread > InpSpreadMaxPts hoặc ngoài phiên → không vào lệnh”. 

# 3) Điều kiện tín hiệu quá khắt: bắt buộc **BOS + Sweep + (OB|FVG)**

* Arbiter của bạn chỉ **valid** khi có đủ **BOS + Sweep** và thêm **OB hoặc FVG** cùng hướng. Trên thực tế, việc **Sweep xuất hiện đúng “cửa sổ”** cùng BOS rồi còn OB/FVG hợp lệ **không diễn ra thường xuyên** ⇒ hầu hết tick sẽ không đủ điều kiện.
* **Fix nhanh**: Cho phép 2 “đường vào”:

  * (A) BOS + (OB|FVG) **không bắt buộc** Sweep; **hoặc**
  * (B) Sweep + (OB|FVG) (thiếu BOS) **nhưng** yêu cầu momentum confirm.

```cpp
// sau khi set c.hasBOS / c.hasSweep / c.hasOB / c.hasFVG
bool pathA = c.hasBOS && (c.hasOB || c.hasFVG);               // relax không cần sweep
bool pathB = c.hasSweep && (c.hasOB || c.hasFVG) && c.hasMomo && !c.momoAgainstSmc;
c.valid = (pathA || pathB);
```

# 4) Trigger candle ≥ **0.40×ATR** trên **bar 0/1** ⇒ rất hiếm

* Yêu cầu thân nến **≥ 0.4 ATR** ở bar 0/1 sẽ hiếm khi thỏa trong khung M15/M30 của XAUUSD (ATR thường lớn).
* **Fix**: hạ ngưỡng hoặc quét **0..3** bars; cho phép **body ≥ max(0.25×ATR, MinBodyAbs)**:

```cpp
double minBody = MathMax( m_triggerBodyATR/100.0 * atr, 30*_Point ); // ví dụ 3 pip
for(int i=0;i<=3;i++){ /*...*/ if(bodySize >= minBody) { /* ok */ } }
```

# 5) Ép **SL tối thiểu = max(MinStopPts, ATR)** làm hỏng R:R

* Trong CalculateEntry bạn ép khoảng SL phải **≥ ATR** (ngoài buffer) ⇒ với XAUUSD ATR M15 dễ 800–1500 points. Kèm EntryBuffer 70 points + MinRR=2.0 → **RR rất khó đạt** ⇒ rớt ở bước “rr < m_minRR → bỏ lệnh”.
* **Fix**: dùng **MinStopPts** làm chặn mềm; **không ép** phải ≥ ATR; chỉ **cảnh báo** nếu SL nhỏ hơn kỷ luật tối thiểu:

```cpp
double minStop = m_minStopPts * _Point;        // ví dụ 300 pts (30 pip)
if(slDistance < minStop) sl = entry - direction*minStop;  // BUY: entry-minStop; SELL: entry+minStop
// bỏ điều kiện: slDistance < ATR -> force enlarge
```

# 6) Vòng kiểm tra vị thế hiện tại dùng **PositionGetSymbol(i)** sai API

* Trong MT5, phải `PositionSelectByIndex(i)` rồi `PositionGetString(POSITION_SYMBOL, sym)`. Gọi `PositionGetInteger` khi **chưa select** sẽ trả về rác/mặc định.
* **Bug**: có thể khiến bạn **nhận định sai** “đã có vị thế cùng chiều” và **không đặt lệnh mới**, hoặc ngược lại.
* **Fix**:

```cpp
int existing = 0;
for(int i=0;i<PositionsTotal();i++){
  if(!PositionSelectByIndex(i)) continue;
  string sym; PositionGetString(POSITION_SYMBOL, sym);
  if(sym!=_Symbol) continue;
  long type; PositionGetInteger(POSITION_TYPE, type);
  if((dir==1 && type==POSITION_TYPE_BUY) || (dir==-1 && type==POSITION_TYPE_SELL)) existing++;
}
if(existing==0) { /* place pending */ }
```

# 7) DetectSweep chỉ xét **bar hiện tại (0)** ⇒ bỏ lỡ sweep cách đây 1–2 nến

* Bạn đang so high/low **bar 0** với cực trị lookback và wick%. Nếu sweep xảy ra ở **bar 1/2** thì đã trượt.
* **Fix**: quét **0..N** bars gần nhất (ví dụ 0..3), lấy “*last valid sweep*”:

```cpp
for(int i=0;i<=3;i++){
  // tính wickPct và điều kiện sweep cho bar i
  if(/* hợp lệ */){ sweep.detected=true; sweep.time=iTime(...,i); break; }
}
```

# 8) TTL quá ngắn cho pending + vẽ/confirm chậm

* `InpOrder_TTL_Bars = 5` trên M30 nghĩa là chỉ **2.5h**; nếu StopEntry đặt hơi xa và giá không chạm kịp thì **bị hủy liên tục**.
* **Fix**: tăng TTL hoặc đổi sang **TTL theo phút** và kiểm tra theo **thời gian thực**.

---

## Checklist “bật vào ngay”

1. **Sửa SessionOpen** như (#1) **hoặc** đổi tham số phiên sang **giờ server**.
2. **Tăng** `InpSpreadMaxPts` (ví dụ 120–250) **hoặc** dùng spread động (#2).
3. Nới điều kiện hợp lệ của Arbiter như (#3).
4. Hạ ngưỡng Trigger candle + quét 0..3 bars (#4).
5. Bỏ ép SL ≥ ATR; chỉ dùng MinStopPts (#5).
6. Sửa duyệt vị thế theo API MT5 chuẩn (#6).
7. Sweep: quét 0..3 bars (#7).
8. Tăng `InpOrder_TTL_Bars` (ví dụ 12–24 bars) (#8).

---

## Vì sao tôi khẳng định các chốt (1) & (2) đang khóa EA?

* Chính trong đặc tả của bạn, **lọc phiên và spread** được áp trực tiếp vào score/entry: *“Spread > InpSpreadMaxPts hoặc ngoài 08:00–23:00 → không vào lệnh”*. Nếu một trong hai sai, vòng OnTick trả về sớm, hoặc PlaceStopOrder cũng từ chối.  

---

Nếu bạn muốn, mình sẽ **vá trực tiếp** 8 điểm trên vào các file:

* `executor.mqh` (SessionOpen, SpreadOK, GetTrigger, CalculateEntry, TTL)
* `arbiter.mqh` (nới điều kiện hợp lệ)
* `detectors.mqh` (Sweep 0..3 bars)
* `SMC_ICT_EA.mq5` (vòng kiểm tra vị thế bằng PositionSelectByIndex).

Bạn chỉ cần nói “patch giúp mình bản v2” là mình trả lại code đã sửa kèm diff.
