# 🏗️ Đề Xuất Refactor Bot - Cấu Trúc Mở Rộng

## 📍 Tổng Quan

Tài liệu này mô tả **thiết kế mới** cho bot EA với cấu trúc **modular, mở rộng dễ dàng**, cho phép thêm/bỏ phương pháp trading mà không cần sửa code core.

---

## 🎯 Mục Tiêu Thiết Kế

1. ✅ **Risk Management Layer đầu tiên** - Quyết định có trade không, trade bao nhiêu pip
2. ✅ **Detection Layer modular** - Chia theo Phương pháp (SMC, ICT), mỗi phương pháp một file riêng
3. ✅ **Mỗi detector tự tính entry/sl/tp và chấm điểm**
4. ✅ **Mỗi detector output kế hoạch DCA, BE, Trail** - Lập kế hoạch quản lý position hoàn chỉnh
6. ✅ **EXECUTION thực hiện và theo dõi lệnh theo kế hoạch**
7. ✅ **Dashboard hiển thị thông số**

**Mục tiêu chính**: 
- Thêm/bỏ phương pháp chỉ cần thêm/xóa file, không sửa code core
- Mỗi phương pháp tự quyết định cách quản lý position (DCA/BE/Trail strategy)

---

## 🏛️ Kiến Trúc Mới (5 Layers)

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 0: RISK GATE (risk_gate.mqh)                        │
│  ├─ CanTrade() → true/false                                │
│  ├─ GetMaxRiskPips() → số pip tối đa                       │
│  ├─ GetMaxLotSize() → lot size tối đa                      │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (nếu CanTrade() = true)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: DETECTION (modular - chia theo Phương pháp)      │
│  ├─ Methods/                                                │
│  │  ├─ method_smc.mqh      → SMC Method (BOS+OB+FVG+Sweep) │
│  │  ├─ method_ict.mqh      → ICT Method (FVG+OB+Momentum)  │
│  │  └─ method_custom.mqh   → Custom Method (dễ thêm)       │
│  │                                                           │
│  └─ Detectors/ (sub-detectors cho mỗi method)               │
│     ├─ detector_bos.mqh      → BOS detector                  │
│     ├─ detector_sweep.mqh    → Sweep detector                │
│     ├─ detector_ob.mqh       → OB detector                   │
│     ├─ detector_fvg.mqh      → FVG detector                  │
│     └─ detector_momentum.mqh → Momentum detector              │
│                                                             │
│  Mỗi Method Output:                                         │
│  ├─ SignalInfo: entry, sl, tp, score                        │
│  ├─ PositionPlan: DCA plan, BE plan, Trail plan            │
│  └─ Method-specific strategy                                │
└─────────────────────────────────────────────────────────────┘
                          │
                         ▼ (ExecutionOrder Arrays từ Layer 1)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2: EXECUTION & POSITION RISK                        │
│      (executor.mqh + risk_manager.mqh)                     │
│                                                             │
│  **Nguồn dữ liệu vào**                                      │
│  - ExecutionOrder[] từ Layer 1:                            │
│    - Kế hoạch lệnh đầy đủ: direction, entry, SL, TP, lot   │
│      đề xuất, PositionPlan (DCA/BE/Trail) kèm theo.        │
│  - RiskGateResult từ Layer 0:                              │
│    - Khung risk/lot tổng còn lại (remainingRisk/lot).      │
│                                                             │
│  **Nhiệm vụ chính**                                         │
│  - Phân bổ budget risk/lot cho từng setup dựa trên         │
│    RiskGateResult (scale lot nếu cần).                      │
│  - Đặt lệnh (pending/market) đúng theo ExecutionOrder.     │
│  - Quản lý pending orders: TTL theo bar, hủy khi hết hạn.  │
│  - Khi lệnh khớp: tạo PositionState và:                     │
│    - DCA add-on theo plan.                                  │
│    - Breakeven (move SL → entry).                          │
│    - Trailing stop theo ATR/structure.                      │
│    - Basket TP/SL nếu bật.                                  │
│  - Cập nhật risk/lot thực tế đã dùng và còn lại để lần     │
│    RiskGate tiếp theo đọc được.                             │
└─────────────────────────────────────────────────────────────┘
                          │
                          ▼ (all data)
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: ANALYTICS (stats_manager.mqh + dashboard.mqh)     │
│  ├─ TrackTrade() → lưu trade vào stats                     │
│  ├─ UpdateDashboard() → hiển thị real-time                 │
│  └─ GenerateReport() → báo cáo                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📁 Cấu Trúc File Mới

```
MQL5/
├─ Experts/
│  └─ oat.mq5              [Main EA - OnTick orchestrator]
│
└─ Include/
   ├─ Core/
   │  ├─ risk_gate.mqh         [NEW - Risk check đầu tiên] ⭐
   │  ├─ arbiter.mqh           [Arbitration - chọn signal tốt nhất]
   │  ├─ executor.mqh          [Execution - đặt lệnh]
   │  ├─ risk_manager.mqh      [Risk - DCA, BE, Trail]
   │  ├─ stats_manager.mqh    [Statistics]
   │  └─ dashboard.mqh         [Dashboard visualization]
   │
   ├─ Methods/                 [NEW - Phương pháp trading] ⭐
   │  ├─ method_base.mqh       [Base class cho methods]
   │  ├─ method_smc.mqh        [SMC Method - BOS+OB+FVG+Sweep]
   │  ├─ method_ict.mqh        [ICT Method - FVG+OB+Momentum]
   │  └─ method_custom.mqh     [Template cho method mới]
   │
   ├─ Detectors/               [Sub-detectors cho methods] ⭐
   │  ├─ detector_base.mqh     [Base class cho detectors]
   │  ├─ detector_bos.mqh      [BOS detector]
   │  ├─ detector_sweep.mqh    [Sweep detector]
   │  ├─ detector_ob.mqh       [Order Block detector]
   │  ├─ detector_fvg.mqh      [FVG detector]
   │  └─ detector_momentum.mqh [Momentum detector]
   │
   └─ Common/
      ├─ signal_structs.mqh    [Tất cả structs chung]
      └─ utils.mqh             [Helper functions]
```
