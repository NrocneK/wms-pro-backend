# WMS Pro — Backend

API backend cho hệ thống quản lý kho (Warehouse Management System) dành cho nghiệp vụ nhà sách/xuất bản — quản lý tồn kho đa kho, phiếu nhập/xuất, phân quyền theo vai trò và theo kho, nhật ký thao tác, xuất phiếu tìm hàng PDF.

Đây là backend cho [wms-pro-frontend](https://github.com/NrocneK/wms-pro-frontend).

## Công nghệ sử dụng

- **Node.js** + **Express** — REST API
- **MySQL** (qua `mysql2`) — cơ sở dữ liệu, triển khai trên [Aiven](https://aiven.io) (production) hoặc XAMPP (local)
- **JWT** (`jsonwebtoken`) — xác thực, có access token + refresh token
- **bcryptjs** — mã hóa mật khẩu
- **multer** + **xlsx** — nhận & xử lý file Excel (nhập/xuất kho, đồng bộ tồn kho hàng loạt)
- **helmet**, **cors**, **express-rate-limit**, **compression** — bảo mật & tối ưu tầng HTTP

## Cấu trúc thư mục

```
src/
├── app.js                  # Entry point — khởi tạo Express, middleware bảo mật
├── config/
│   └── db.js                # Kết nối pool MySQL
├── controllers/              # Logic xử lý theo domain (auth, product, inventory, import, export, user, warehouse, auditLog)
├── middleware/
│   ├── auth.js                # Xác thực JWT + phân quyền theo role
│   ├── warehouseGuard.js      # Giới hạn truy vấn theo kho được gán cho user
│   └── uploadExcel.js         # Cấu hình multer cho upload file Excel
├── routes/                   # Định nghĩa endpoint, tách theo domain — routes/index.js chỉ gom lại
└── utils/
    ├── auditLog.js             # Ghi nhật ký thao tác (kèm warehouse_id để lọc theo quyền kho)
    └── response.js              # Chuẩn hóa response { success, data, message }

sql/
├── 01_schema.sql             # Schema gốc
└── 02_audit_logs_warehouse.sql  # Migration bổ sung (chạy sau schema gốc, xem mục Database bên dưới)
```

## Cài đặt & chạy local

### Yêu cầu

- Node.js ≥ 18
- MySQL (khuyến nghị XAMPP cho local, hoặc kết nối thẳng tới Aiven)

### Các bước

```bash
git clone https://github.com/NrocneK/wms-pro-backend.git
cd wms-pro-backend
npm install
```

Tạo file `.env` từ mẫu:

```bash
cp .env.example .env
```

Mở `.env` và điền đúng thông tin kết nối MySQL, `JWT_SECRET` (chuỗi ngẫu nhiên dài, không dùng giá trị mẫu khi lên production), và `ALLOWED_ORIGINS` (domain frontend được phép gọi API).

### Database

Import lần lượt theo đúng thứ tự:

```bash
mysql -u <user> -p <database> < sql/01_schema.sql
mysql -u <user> -p <database> < sql/02_audit_logs_warehouse.sql
```

> ⚠️ Nếu database đã tồn tại từ trước (chưa có cột `warehouse_id` trong bảng `audit_logs`), **bắt buộc chạy `02_audit_logs_warehouse.sql`** — thiếu bước này audit log sẽ lỗi khi ghi/đọc.

### Chạy server

```bash
npm run dev     # chế độ dev, tự reload khi sửa code (nodemon)
npm start        # chế độ production
```

Server mặc định chạy ở `http://localhost:3001`, API gốc tại `http://localhost:3001/api/v1`.

## Tổng quan API

Toàn bộ endpoint nằm dưới `/api/v1`, yêu cầu header `Authorization: Bearer <token>` trừ `/auth/login` và `/auth/refresh`.

| Nhóm          | Mô tả                                                       |
| ------------- | ----------------------------------------------------------- |
| `/auth`       | Đăng nhập, làm mới token, đổi mật khẩu                      |
| `/products`   | Danh mục sản phẩm (catalog-level, không gắn kho)            |
| `/inventory`  | Tồn kho theo từng kho — CRUD, thay thế hàng loạt qua Excel  |
| `/imports`    | Phiếu nhập kho — tạo, xác nhận, đọc Excel                   |
| `/exports`    | Phiếu xuất kho — tạo, soạn hàng, xác nhận, hủy              |
| `/warehouses` | Danh sách kho                                               |
| `/users`      | Quản lý tài khoản (chỉ admin)                               |
| `/audit-logs` | Nhật ký thao tác — tự động lọc theo quyền kho của người xem |
| `/dashboard`  | Số liệu tổng quan, lịch sử giao dịch theo ngày              |
| `/reports`    | Báo cáo tồn kho theo danh mục, hoạt động người dùng         |

## Phân quyền

3 vai trò: **admin** (toàn quyền), **manager** (nhập/xuất/sửa tồn kho), **staff** (nhập/xuất, chỉ xem báo cáo). Mỗi tài khoản có thể được **gán 1 kho cụ thể** (`warehouse_code`) — khi đó mọi truy vấn dữ liệu (tồn kho, phiếu, audit log...) tự động bị giới hạn chỉ trong kho đó thông qua `middleware/warehouseGuard.js`. Tài khoản không gán kho (thường là admin) xem được toàn hệ thống.

## Các quy tắc kỹ thuật cần lưu ý

- **Thứ tự route quan trọng:** `/exports/packing` phải đăng ký trước `/exports/:id`, `/users/me` phải trước `/users/:id` — nếu đảo thứ tự Express sẽ hiểu nhầm tham số động.
- **MySQL 8.4 + `mysql2`:** không dùng placeholder `?` cho `LIMIT`/`OFFSET` trong prepared statement — phải inline số nguyên đã validate.
- **Ngày tháng:** tính "hôm nay" ở tầng Node.js, không dùng `CURDATE()` của MySQL (tránh lệch múi giờ khi so sánh với dữ liệu JS).

## Triển khai (Production)

Đang chạy trên **Render** (backend) kết nối tới **Aiven** (MySQL managed). Khi deploy, đảm bảo biến môi trường `NODE_ENV=production`, `ALLOWED_ORIGINS` trỏ đúng domain frontend thật, và `JWT_SECRET` là chuỗi ngẫu nhiên riêng (không dùng chung với môi trường dev).
