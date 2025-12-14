# SMC/ICT Expert Advisor v2.1 - Cấu Trúc Tài Liệu

## 📁 Tổ Chức Tài Liệu

Tài liệu đã được tổ chức lại thành hai thư mục chính để dễ đọc và bảo trì:

### 📊 **business/** - Tài Liệu Kinh Doanh/Chiến Lược
**Mục đích**: Dành cho trader và người lập chiến lược, tập trung vào khái niệm cấp cao, tham số cấu hình và ứng dụng thực tế

**Nội dung bao gồm**:
- Tổng quan hệ thống và kiến trúc
- Hướng dẫn tham số cấu hình
- Ví dụ giao dịch thực tế
- Lộ trình cải tiến
- Hướng dẫn sử dụng tính năng (cơ chế DCA, giao dịch đa phiên, v.v.)
- Tóm tắt cập nhật phiên bản và tham chiếu nhanh

**Phù hợp cho**: 
- Trader (hiểu logic chiến lược)
- Người điều chỉnh tham số (tinh chỉnh cấu hình)
- Người lập chiến lược (lập kế hoạch cải tiến)

---

### 💻 **code_logic/** - Tài Liệu Code/Logic
**Mục đích**: Dành cho developer, mô tả chi tiết triển khai code, logic thuật toán và chi tiết kỹ thuật

**Nội dung bao gồm**:
- Thuật toán detector chi tiết (BOS, Sweep, OB, FVG, Momentum)
- Logic scoring arbiter
- Chi tiết triển khai executor
- Thuật toán quản lý rủi ro
- Triển khai dashboard thống kê
- Logic code luồng chính
- Hướng dẫn triển khai kỹ thuật (triển khai đa phiên, chuyển đổi múi giờ)
- Tài liệu sửa lỗi Bug

**Phù hợp cho**:
- Developer (triển khai và bảo trì code)
- Người tối ưu thuật toán (cải thiện logic phát hiện)
- Người kiểm tra kỹ thuật (kiểm tra chất lượng code)

---

## 📚 Điều Hướng Nhanh

### ⭐ Nếu bạn là Trader (muốn hiểu chiến lược):
1. 📖 [business/TRADING_RULES.md](business/TRADING_RULES.md) - **ĐỌC ĐẦU TIÊN** - Tổng hợp tất cả quy tắc
2. 📖 [business/ENTRY_RULES.md](business/ENTRY_RULES.md) - Quy tắc entry vào lệnh
3. 📖 [business/RISK_MANAGEMENT_RULES.md](business/RISK_MANAGEMENT_RULES.md) - Quy tắc quản lý vốn
4. 📖 [business/TRADING_SCHEDULE.md](business/TRADING_SCHEDULE.md) - Thời gian giao dịch
5. 📖 [business/09_EXAMPLES.md](business/09_EXAMPLES.md) - Ví dụ giao dịch thực tế
6. 📖 [business/07_CONFIGURATION.md](business/07_CONFIGURATION.md) - Tham số cấu hình

### Nếu bạn là Developer (muốn triển khai code):
1. 📖 [code_logic/02_DETECTORS.md](code_logic/02_DETECTORS.md) - Thuật toán detector
2. 📖 [code_logic/03_ARBITER.md](code_logic/03_ARBITER.md) - Logic scoring
3. 📖 [code_logic/04_EXECUTOR.md](code_logic/04_EXECUTOR.md) - Triển khai executor
4. 📖 [code_logic/08_MAIN_FLOW.md](code_logic/08_MAIN_FLOW.md) - Luồng chính

### Nếu bạn muốn tìm hiểu tính năng mới v2.1:
1. 📖 [business/V2.1_UPDATES_SUMMARY.md](business/V2.1_UPDATES_SUMMARY.md) - Tóm tắt cập nhật
2. 📖 [business/V2.1_QUICK_REFERENCE.md](business/V2.1_QUICK_REFERENCE.md) - Tham chiếu nhanh
3. 📖 [business/README_V2.1.md](business/README_V2.1.md) - Tổng quan v2.1

---

## 🎯 Giải Thích Phân Loại Tài Liệu

### Danh Sách File Thư Mục Business

#### ⭐ Quy Tắc Giao Dịch (Đọc Đầu Tiên)
| File | Nội Dung | Mục Đích |
|------|----------|----------|
| `TRADING_RULES.md` | **Tổng hợp tất cả quy tắc giao dịch** | Đọc đầu tiên - Hiểu toàn bộ quy tắc |
| `ENTRY_RULES.md` | **Quy tắc và điều kiện entry vào lệnh** | Hiểu khi nào bot entry |
| `RISK_MANAGEMENT_RULES.md` | **Quy tắc quản lý vốn** | Hiểu cách bot quản lý rủi ro |
| `TRADING_SCHEDULE.md` | **Thời gian giao dịch** | Hiểu khi nào bot trade |

#### Tài Liệu Cốt Lõi
| File | Nội Dung | Mục Đích |
|------|----------|----------|
| `README.md` | Tổng quan dự án | Hướng dẫn bắt đầu |
| `README_V2.1.md` | Mô tả phiên bản v2.1 | Tìm hiểu tính năng mới |
| `01_SYSTEM_OVERVIEW.md` | Tổng quan kiến trúc 5 lớp | Hiểu thiết kế hệ thống |
| `07_CONFIGURATION.md` | Tất cả tham số cấu hình | Điều chỉnh cài đặt EA |
| `09_EXAMPLES.md` | Ví dụ giao dịch thực tế | Học ứng dụng chiến lược |
| `10_IMPROVEMENTS_ROADMAP.md` | Kế hoạch cải tiến | Lập kế hoạch tương lai |

#### Hướng Dẫn Tính Năng
| File | Nội Dung | Mục Đích |
|------|----------|----------|
| `DCA_MECHANISM.md` | Giải thích cơ chế DCA | Hiểu logic thêm lệnh |

#### Cập Nhật Phiên Bản
| File | Nội Dung | Mục Đích |
|------|----------|----------|
| `V2.1_QUICK_REFERENCE.md` | Tham chiếu nhanh v2.1 | Tra cứu tính năng mới |
| `V2.1_UPDATES_SUMMARY.md` | Tóm tắt cập nhật v2.1 | Giải thích cập nhật chi tiết |

### Danh Sách File Thư Mục Code/Logic

| File | Nội Dung | Mục Đích |
|------|----------|----------|
| `02_DETECTORS.md` | Thuật toán detector chi tiết | Triển khai phát hiện tín hiệu |
| `03_ARBITER.md` | Logic scoring arbiter | Triển khai scoring tín hiệu |
| `04_EXECUTOR.md` | Chi tiết triển khai executor | Triển khai thực thi lệnh |
| `05_RISK_MANAGER.md` | Thuật toán quản lý rủi ro | Triển khai kiểm soát rủi ro |
| `06_STATS_DASHBOARD.md` | Triển khai dashboard thống kê | Triển khai hiển thị dữ liệu |
| `08_MAIN_FLOW.md` | Logic code luồng chính | Hiểu luồng thực thi |
| `MULTI_SESSION_IMPLEMENTATION.md` | Chi tiết triển khai đa phiên | Triển khai đa khung thời gian |
| `TIMEZONE_CONVERSION.md` | Kỹ thuật chuyển đổi múi giờ | Xử lý vấn đề múi giờ |
| `update.md` | Tài liệu sửa lỗi Bug | Sửa lỗi kỹ thuật |

---

## 🔍 Cách Tìm Thông Tin

### Tìm Theo Chủ Đề

**Muốn tìm hiểu quy tắc giao dịch**:
- Tất cả quy tắc → `business/TRADING_RULES.md` ⭐
- Quy tắc entry → `business/ENTRY_RULES.md`
- Quản lý vốn → `business/RISK_MANAGEMENT_RULES.md`
- Thời gian trade → `business/TRADING_SCHEDULE.md`
- Cơ chế DCA → `business/DCA_MECHANISM.md`

**Muốn tìm hiểu khái niệm giao dịch**:
- BOS (Break of Structure) → `code_logic/02_DETECTORS.md` (Section: BOS)
- Order Block → `code_logic/02_DETECTORS.md` (Section: Order Block)

**Muốn điều chỉnh tham số**:
- Tất cả tham số → `business/07_CONFIGURATION.md`
- Cài đặt đề xuất → `business/07_CONFIGURATION.md` (Section: Presets)

**Muốn hiểu logic code**:
- Luồng phát hiện → `code_logic/02_DETECTORS.md`
- Hệ thống scoring → `code_logic/03_ARBITER.md`
- Luồng thực thi → `code_logic/08_MAIN_FLOW.md`

**Muốn xem ví dụ thực tế**:
- Ví dụ giao dịch hoàn chỉnh → `business/09_EXAMPLES.md`
- Ví dụ các mô hình khác nhau → `business/09_EXAMPLES.md` (các Section)

---

## 📝 Hướng Dẫn Bảo Trì Tài Liệu

### Khi thêm tài liệu mới:
1. **Liên quan đến kinh doanh/chiến lược** → Đặt vào thư mục `business/`
2. **Liên quan đến code/thuật toán** → Đặt vào thư mục `code_logic/`
3. **Cập nhật README này** → Thêm tài liệu mới vào danh sách tương ứng

### Khi sửa đổi tài liệu hiện có:
- Giữ tài liệu trong thư mục ban đầu
- Nếu tính chất nội dung thay đổi, di chuyển đến thư mục tương ứng
- Cập nhật giải thích trong README này

---

## 🚀 Bắt Đầu Nhanh

### Bước 1: Chọn Vai Trò Của Bạn
- **Trader** → Đọc thư mục `business/`
- **Developer** → Đọc thư mục `code_logic/`

### Bước 2: Đọc Theo Thứ Tự
- Trader: README → SYSTEM_OVERVIEW → EXAMPLES → CONFIGURATION
- Developer: DETECTORS → ARBITER → EXECUTOR → MAIN_FLOW

### Bước 3: Hiểu Sâu Hơn
- Đọc tài liệu chi tiết về chủ đề cụ thể theo nhu cầu
- Tham khảo triển khai code (thư mục `Include/`)

---

## 📞 Cần Giúp Đỡ?

Nếu tài liệu thiếu thông tin hoặc không rõ ràng:
1. Kiểm tra file code liên quan (`Include/*.mqh`)
2. Xem tài liệu ví dụ (`business/09_EXAMPLES.md`)
3. Hỏi câu hỏi cụ thể để được làm rõ

---

## 🔧 Development Workflows

### Auto Build & Check

Hệ thống tự động compile và kiểm tra errors sau mỗi lần chỉnh sửa code:

- **Workflow**: `.agent/workflows/build-ea.md`
- **Command**: `.agent/commands/build-and-check.ps1`
- **Tự động chạy**: Sau khi edit file `.mq5` hoặc `.mqh`
- **Kết quả**: Hiển thị errors/warnings với file và line number

### Auto Update Documentation

Hệ thống tự động cập nhật documentation khi code hoặc requirements thay đổi:

- **Workflow**: `.agent/workflows/update-docs.md`
- **Quy tắc**: Cập nhật docs gốc, không tạo file mới với version/timeline
- **Mapping**: Tự động map code files → documentation files
- **Tự động chạy**: Khi code logic hoặc business rules thay đổi

Xem chi tiết trong `.cursorrules` và `.agent/README.md`.

---

**Cập nhật lần cuối**: 2025-01-XX  
**Phiên bản tài liệu**: v2.1  
**Trạng thái bảo trì**: ✅ Đang bảo trì tích cực
