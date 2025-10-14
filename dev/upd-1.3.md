# EA SMC/ICT – **DCA Guard + MaxLot + MaxDrawdown** (Implementation Doc)

> **Goal:** Chặn “bùng nổ” lệnh DCA gây đứng máy; ép EA tuân thủ 3 giới hạn: **MaxAdds**, **MaxLotPerSide**, **Max Daily MDD%**. Đồng thời giảm spam `OrderSend`/`Print` khi vi phạm (không lặp lại mỗi tick).

> **Lưu ý:** Vì bạn chưa gửi **URL/commit hash** repo, mình không thể trỏ **chính xác số dòng**. Dưới đây mình chỉ ra **file + anchor (mốc comment/hàm)** để bạn **tìm–đặt–sửa**; khi bạn cung cấp link/commit, mình sẽ **map đúng line** ngay.

---

## 1) Decompose → Plan → ToT (scored) → Reverse Thinking

### Decompose

* **Entry/DCA Trigger:** +0.75R và +1.5R (pyramiding khi đang lãi).
* **Guards:** MaxAdds (số DCA), MaxLotPerSide (tổng lot theo chiều), DailyMddMax% (cầu chì ngày).
* **Order Mgmt:** Không lặp `OrderSend` nếu vi phạm guard; log một lần rồi **skip**.
* **Perf:** Tắt vẽ/log khi backtest multi-core; throttle in ra log.

### Plan (thứ tự xử lý)

1. Thêm **inputs** + **flags** (Skipped) vào state.
2. Tạo hàm **CanAddDCA(...)** check đủ 3 guard trước khi gọi `AddDCAPosition`.
3. Sửa block **DCA #1/#2**: nếu guard fail → **đánh dấu Skipped** (không thử lại mỗi tick).
4. (Tuỳ chọn) Giảm log/vẽ khi backtest đa luồng.
5. Kiểm thử stress (MaxLots, MDD, pyramiding, long-run).

### Tree-of-Thought (phương án)

| Phương án       | Mô tả                                                                  | Correctness | Risk | Cost/Time |
| --------------- | ---------------------------------------------------------------------- | ----------: | ---: | --------: |
| A (khuyến nghị) | Pre-check guard + flag **Skipped** để không retry                      |    **9/10** | 3/10 |  **2/10** |
| B               | Chuyển `AddDCAPosition()` trả mã lỗi, set flag theo mã                 |        9/10 | 3/10 |      4/10 |
| C               | Dồn mọi guard vào `AddDCAPosition()`, dùng **debounce** theo thời gian |        7/10 | 4/10 |      5/10 |

**Chọn A**: đơn giản, nguy cơ side-effect thấp, retrofit nhanh.

### Reverse Thinking

* *Nếu kết luận sai?* Có thể vẫn lặp do guard đặt **sau** `OrderSend`. → Bắt buộc **pre-check** trước khi gọi `AddDCAPosition`.
* *Phản chứng?* Nếu skip nhầm (do điều kiện tạm thời) → thêm **tuỳ chọn** reset flag khi **TP/SL** hoặc khi **state thay đổi**.
* *Fail-safe?* `IsTradingHalted()` → **return early** ở OnTick/manager; logs **một dòng** rồi im.

---

## 2) **Questions cần bạn xác nhận** (để chốt line số)

1. Link GitHub + **commit hash/branch** bạn đang chạy? (mình sẽ map **exact line**).
2. Tên file chứa **main loop** (thường: `Experts/SMC_ICT_EA.mq5`?) và file chứa **risk/DCA helpers** (thường: `Include/risk_manager.mqh`?).
3. Biến state vị thế (struct chứa `dca1Added/dca2Added`…) hiện ở file nào?

---

## 3) **Spec kỹ thuật + chỉ rõ vị trí sửa (theo anchor)**

> Ký hiệu:
>
> * **[FILE]**: đường dẫn tương đối trong repo.
> * **🔎 Anchor**: chuỗi comment/hàm để bạn **Ctrl+F**.
> * **// PATCH #**: khối cần thêm/sửa.
> * Khi có link/commit, mình sẽ bổ sung “**Line X–Y**” tương ứng.

### 3.1. Thêm **Inputs** (nếu chưa có/đổi default)

**[FILE]** `Experts/SMC_ICT_EA.mq5`
**🔎 Anchor:** `input` block (các tham số Inp*) gần đầu file.

```cpp
// PATCH 1 — Inputs (confirm/điều chỉnh default)
input int     InpMaxDcaAddons    = 2;      // số add-on tối đa / chuỗi
input double  InpMaxLotPerSide   = 3.0;    // trần tổng lot theo chiều
input double  InpDailyMddMaxPct  = 8.0;    // dừng giao dịch khi MDD ngày vượt %
input bool    InpDebugLogs       = false;  // giảm spam log khi backtest
input bool    InpDebugDraw       = false;  // tắt vẽ object khi backtest multi-core
// (Giữ các inputs RiskPerTradePct, MinRR... như hiện tại)
```

> **Why:** đảm bảo 3 giới hạn có thể **config**; cho phép tắt **log/draw** khi cần.

---

### 3.2. Mở rộng **state** vị thế (thêm cờ Skipped)

**[FILE]** `Include/…` (nơi khai báo `struct PositionState` hay tương đương)
**🔎 Anchor:** `struct PositionState` / chỗ có `dca1Added`, `dca2Added`, `dcaCount`.

```cpp
// PATCH 2 — State flags
struct PositionState {
  // ... existing fields ...
  bool dca1Added;
  bool dca2Added;
  int  dcaCount;

  // NEW: đánh dấu đã bỏ qua để không retry mỗi tick
  bool dca1Skipped;   // NEW
  bool dca2Skipped;   // NEW
};
```

**Init default** ở nơi khởi tạo `PositionState`:

```cpp
ps.dca1Skipped = ps.dca2Skipped = false;
```

---

### 3.3. Hàm **GetLotsPerSide** (nếu chưa có)

**[FILE]** `Include/risk_manager.mqh` hoặc nơi quản lý positions
**🔎 Anchor:** `GetSideLots` / chỗ tính tổng lot theo `ENUM_POSITION_TYPE`.

```cpp
// PATCH 3 — tiện ích tổng lot theo chiều
double GetLotsPerSide(ENUM_POSITION_TYPE dir) {
  double total = 0.0;
  // lặp qua positions hiện tại (Symbol(), Magic)
  // cộng dồn lot theo 'dir'
  // ...
  return total;
}
```

---

### 3.4. Hàm **CanAddDCA(...)** – guard trước khi gọi OrderSend

**[FILE]** nơi chứa helpers DCA (cùng chỗ AddDCAPosition)
**🔎 Anchor:** `AddDCAPosition` hoặc comment `// DCA add-on`.

```cpp
// PATCH 4 — Guard check trước khi add
bool CanAddDCA(const PositionState &ps, double addLots, ENUM_POSITION_TYPE dir) {
  if(IsTradingHalted()) return false;                       // MDD day guard
  if(ps.dcaCount >= InpMaxDcaAddons) return false;          // MaxAdds
  if(GetLotsPerSide(dir) + addLots > InpMaxLotPerSide + 1e-8)
     return false;                                          // MaxLot per side
  return true;
}
```

---

### 3.5. Sửa block **DCA #1 / DCA #2** (trong manager loop)

**[FILE]** `Experts/SMC_ICT_EA.mq5` (hoặc module quản lý lệnh mở)
**🔎 Anchor:** nơi tính **profit in R** và có điều kiện `+0.75R` / `+1.5R`.

```cpp
// PATCH 5 — DCA #1
if (profitR >= 0.75 && !ps.dca1Added && !ps.dca1Skipped) {
  double addLots = NormalizeLots(ps.entryLots * 0.50);  // 50% lệnh gốc
  if (CanAddDCA(ps, addLots, dir) && AddDCAPosition(sym, dir, addLots, /*...*/)) {
      ps.dca1Added = true;
      ps.dcaCount++;
      if(InpDebugLogs) Print("DCA#1 added: ", addLots);
  } else {
      ps.dca1Skipped = true;  // <-- NGỪNG THỬ LẠI
      if(InpDebugLogs) Print("DCA#1 SKIPPED (MaxAdds/MaxLot/MDD)");
  }
}

// PATCH 6 — DCA #2
if (profitR >= 1.50 && !ps.dca2Added && !ps.dca2Skipped) {
  double addLots = NormalizeLots(ps.entryLots * 0.33);  // ~33% lệnh gốc
  if (CanAddDCA(ps, addLots, dir) && AddDCAPosition(sym, dir, addLots, /*...*/)) {
      ps.dca2Added = true;
      ps.dcaCount++;
      if(InpDebugLogs) Print("DCA#2 added: ", addLots);
  } else {
      ps.dca2Skipped = true;  // <-- NGỪNG THỬ LẠI
      if(InpDebugLogs) Print("DCA#2 SKIPPED (MaxAdds/MaxLot/MDD)");
  }
}
```

> **[Risk]** Nếu bạn muốn **retry** khi điều kiện thay đổi (ví dụ giảm lot tổng) → thay vì `Skipped=true` có thể dùng **debounce** theo thời gian: chỉ thử lại sau **N giây/bar**.

---

### 3.6. **AddDCAPosition(...)** – early return + log 1 lần

**[FILE]** nơi định nghĩa `AddDCAPosition`
**🔎 Anchor:** `bool AddDCAPosition(`.

```cpp
// PATCH 7 — safety (nếu vẫn muốn check bên trong)
if(GetLotsPerSide(dir) + lots > InpMaxLotPerSide + 1e-8) {
   if(InpDebugLogs) Print("Skip AddDCA: exceed MaxLotPerSide");
   return false;  // KHÔNG Print lặp lại nơi khác
}
if(IsTradingHalted()) {
   if(InpDebugLogs) Print("Skip AddDCA: trading halted by MDD");
   return false;
}
```

---

### 3.7. **Daily MDD guard** – return early ở OnTick/manager

**[FILE]** `Experts/SMC_ICT_EA.mq5`
**🔎 Anchor:** `OnTick()` hoặc `ManageOpenPositions()` đầu hàm.

```cpp
// PATCH 8 — cầu chì ngày
if(CheckDailyMDD(InpDailyMddMaxPct)) {   // cập nhật m_tradingHalted
   if(m_tradingHalted) {
      // optional: đóng lệnh, huỷ pending tại đây nếu chưa làm
      return;  // KHÔNG xử lý gì nữa trong tick này
   }
}
```

> Đảm bảo `CheckDailyMDD` so sánh **equity drawdown trong ngày** (vs balance đầu ngày) và set `m_tradingHalted=true` khi vượt ngưỡng.

---

### 3.8. **Giảm tải backtest multi-core**

**[FILE]** nơi vẽ **dashboard/objects** & nơi `Print` nhiều
**🔎 Anchor:** `Draw...`, `Dashboard`, `Print(`

```cpp
// PATCH 9 — bao quanh bởi flags
if(InpDebugDraw) {
   // ... vẽ FVG/OB/BOS ...
}

if(InpDebugLogs) {
   Print("...chỉ log khi cần...");
}
```

---

## 4) Test Checklist (stress)

1. **MaxLot stress:** Set `InpMaxLotPerSide=0.1`, risk cao → DCA bị chặn. Kỳ vọng: **log 1 dòng** skip, **không retry**.
2. **MDD day:** Hạ `InpDailyMddMaxPct` (3–5%), feed data lỗ. Kỳ vọng: in 1 log **MDD exceeded**, **ngừng** mở lệnh tới hết ngày.
3. **Pyramiding OK:** Xu hướng mạnh → mở đủ DCA #1/#2 đúng mốc **0.75R/1.5R**, tổng lot **≤ MaxLotPerSide**.
4. **Multi-core:** Tắt `InpDebugDraw/Logs`, chạy optimization → **không treo**, thời gian giảm.

---

## 5) Tham số khuyến nghị (XAUUSD M5 – mặc định)

| Param              | Default |    Min/Max | Ghi chú                     |
| ------------------ | ------: | ---------: | --------------------------- |
| InpRiskPerTradePct | 1.0–2.0 |    0.2–5.0 | Live khuyến nghị 1–2%       |
| InpMaxDcaAddons    |   **2** |        0–2 | Code hiện hỗ trợ 2 cấp      |
| InpMaxLotPerSide   | **3.0** |     0.1–10 | Bảo hiểm quá tải lot        |
| InpDailyMddMaxPct  | **8.0** |       3–15 | Cầu chì ngày                |
| InpDebugLogs/Draw  |   false | true/false | Tắt khi backtest multi-core |

---

## 6) **Devil’s Advocate** (Counter/Reverse)

* **Skip cứng quá?** Có thể lỡ cơ hội nếu điều kiện trở lại hợp lệ. → Dùng **debounce** (ví dụ `retryAfterTime`) thay vì skip vĩnh viễn.
* **MaxLotPerSide quá thấp** làm **không bao giờ có DCA**. → Theo dõi log “SKIPPED MaxLot”, cân đối tăng nhẹ hoặc giảm risk ban đầu.
* **MDD day** cắt sớm cơ hội hồi phục. → Chọn ngưỡng phù hợp (5–8%), và reset sang ngày mới.

---

## 7) Pseudocode tổng hợp (đặt trong manager loop)

```cpp
for (auto &ps : positions) {
  if (m_tradingHalted) continue;

  double profitR = (PriceNow - ps.entry)/ps.risk; // long; đảo dấu cho short

  // DCA #1 @ +0.75R
  if (profitR >= 0.75 && !ps.dca1Added && !ps.dca1Skipped) {
     double addLots = NormalizeLots(ps.entryLots * 0.50);
     if (CanAddDCA(ps, addLots, ps.dir) && AddDCAPosition(..., addLots)) {
        ps.dca1Added = true; ps.dcaCount++;
     } else { ps.dca1Skipped = true; }
  }

  // DCA #2 @ +1.5R
  if (profitR >= 1.50 && !ps.dca2Added && !ps.dca2Skipped) {
     double addLots = NormalizeLots(ps.entryLots * 0.33);
     if (CanAddDCA(ps, addLots, ps.dir) && AddDCAPosition(..., addLots)) {
        ps.dca2Added = true; ps.dcaCount++;
     } else { ps.dca2Skipped = true; }
  }
}
```

---

## 8) Hướng dẫn backtest **nhiều CPU**

* Optimization → bật **Multi-threading**; tắt `InpDebugDraw/Logs`.
* Model: **1 minute OHLC** (hoặc Every tick nếu cần chính xác), nhưng ưu tiên OHLC để nhanh.
* Dùng **mốc thời gian dài** (18–24 tháng) + **WFO 70/30** để tránh overfit.

---

## 9) Definition of Done (DoD)

* Không còn log/attempt **lặp** khi bị chặn MaxLot/MaxAdds/MDD.
* Pyramiding hoạt động đúng **0.75R/1.5R** với lot 50%/33%.
* Backtest multi-core hoàn tất **không treo**.
* Báo cáo stress tests: **pass** 4 case ở mục 4.

---

## 10) Cần bạn cung cấp để mình chèn **đúng LINE**

Vui lòng gửi:

* **URL repo + branch/commit hash** bạn đang chạy,
* hoặc **2 file**: `Experts/SMC_ICT_EA.mq5` và `Include/risk_manager.mqh` (hoặc file tương đương chứa DCA).

→ Mình sẽ phản hồi **bản MD** kèm **đúng số dòng (Line X–Y)** cho từng **PATCH** ở trên.

---

## 11) Self-Review & Sanity Check

* Logic không thay đổi entry, chỉ thêm **guard** và **flag** để **không retry vô hạn**.
* Không can thiệp `OrderSend` ngoài **pre-check**.
* Edge cases: **5 digits vs 3 digits** không ảnh hưởng vì guard theo **lot**, không theo **points**.
* **Confidence:** **Medium-High** (90% nếu repo theo cấu trúc chuẩn; cần link để gắn chính xác line).
