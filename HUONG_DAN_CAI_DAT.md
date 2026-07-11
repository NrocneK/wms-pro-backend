# WMS Pro — Hướng dẫn cài đặt Backend trên Windows VPS
# ============================================================

## 1. PHẦN MỀM CẦN CÀI TRƯỚC

### Node.js 18+
  - Tải tại: https://nodejs.org/en/download
  - Chọn bản LTS (Windows Installer .msi)
  - Cài xong kiểm tra: node -v && npm -v

### MySQL 8.0
  - Tải tại: https://dev.mysql.com/downloads/installer/
  - Chọn "MySQL Installer for Windows"
  - Trong quá trình cài chọn: MySQL Server + MySQL Workbench
  - Ghi nhớ root password đã tạo

### PM2 (chạy Node.js như service Windows)
  npm install -g pm2
  npm install -g pm2-windows-startup


## 2. TẠO DATABASE VÀ USER MYSQL

Mở MySQL Workbench, kết nối với root, chạy:

  -- Tạo user riêng (KHÔNG dùng root)
  CREATE USER 'wms_user'@'localhost' IDENTIFIED BY 'YourStrongPass!';
  GRANT ALL PRIVILEGES ON wms_pro.* TO 'wms_user'@'localhost';
  FLUSH PRIVILEGES;

Sau đó chạy file SQL schema:
  mysql -u root -p < sql/01_schema.sql


## 3. CÀI ĐẶT BACKEND

  # Clone hoặc copy thư mục wms-backend vào VPS
  # Ví dụ: C:\wms-backend\

  cd C:\wms-backend

  # Cài dependencies
  npm install

  # Tạo file .env từ template
  copy .env.example .env

  # Mở .env và chỉnh sửa:
  #   DB_PASSWORD = mật khẩu MySQL wms_user
  #   JWT_SECRET  = chuỗi ngẫu nhiên dài 64+ ký tự
  #   ALLOWED_ORIGINS = IP của VPS hoặc domain


## 4. CHẠY SERVER

### Development (test):
  npm run dev

### Production với PM2:
  pm2 start src/app.js --name "wms-api" --env production
  pm2 save
  pm2-startup install   # tự khởi động khi VPS reboot

  # Kiểm tra:
  pm2 status
  pm2 logs wms-api


## 5. MỞ PORT FIREWALL WINDOWS

  # Mở Command Prompt với quyền Admin, chạy:
  netsh advfirewall firewall add rule name="WMS API 3001" dir=in action=allow protocol=TCP localport=3001


## 6. KIỂM TRA API

  # Từ browser hoặc Postman:
  GET http://YOUR_VPS_IP:3001/health

  # Đăng nhập (mật khẩu mặc định: Admin@123)
  POST http://YOUR_VPS_IP:3001/api/v1/auth/login
  Body JSON: { "username": "admin", "password": "Admin@123" }

  # Đổi mật khẩu ngay sau khi đăng nhập lần đầu!


## 7. CẤU TRÚC THƯ MỤC

  wms-backend/
  ├── sql/
  │   └── 01_schema.sql       ← Chạy đầu tiên để tạo DB
  ├── src/
  │   ├── app.js              ← Entry point
  │   ├── config/
  │   │   └── db.js           ← MySQL connection pool
  │   ├── controllers/
  │   │   ├── authController.js
  │   │   ├── productController.js
  │   │   ├── importController.js
  │   │   ├── exportController.js
  │   │   └── inventoryController.js
  │   ├── middleware/
  │   │   └── auth.js         ← JWT middleware
  │   ├── routes/
  │   │   └── index.js        ← Toàn bộ API routes
  │   └── utils/
  │       └── response.js     ← Chuẩn hóa response
  ├── .env.example            ← Copy → .env rồi điền thông tin
  ├── .gitignore
  └── package.json


## 8. API ENDPOINTS TỔNG QUAN

  POST   /api/v1/auth/login               Đăng nhập
  POST   /api/v1/auth/refresh             Gia hạn token
  GET    /api/v1/auth/me                  Thông tin user hiện tại
  POST   /api/v1/auth/change-password     Đổi mật khẩu

  GET    /api/v1/products                 Danh sách sản phẩm
  GET    /api/v1/products/:barcode        Tìm theo barcode
  POST   /api/v1/products                 Thêm sản phẩm
  PUT    /api/v1/products/:id             Sửa sản phẩm
  DELETE /api/v1/products/:id             Xóa (mềm)

  POST   /api/v1/imports/parse-excel      Parse file Excel nhập
  POST   /api/v1/imports                  Tạo phiếu nhập (draft)
  POST   /api/v1/imports/:id/confirm      Xác nhận nhập kho
  GET    /api/v1/imports                  Lịch sử phiếu nhập

  POST   /api/v1/exports/parse-excel      Parse file Excel xuất
  POST   /api/v1/exports                  Tạo phiếu xuất (draft)
  POST   /api/v1/exports/:id/confirm      Xác nhận xuất kho
  GET    /api/v1/exports                  Lịch sử phiếu xuất

  GET    /api/v1/dashboard                KPI tổng quan
  GET    /api/v1/inventory                Tồn kho đầy đủ
  GET    /api/v1/inventory/alerts         Cảnh báo tồn thấp
  GET    /api/v1/inventory/locations/free Vị trí trống
  GET    /api/v1/reports/by-category      Báo cáo theo danh mục


## 9. BƯỚC TIẾP THEO (sau khi backend chạy)

  1. Kết nối React frontend với API (thay state bằng fetch calls)
  2. Cài đặt Nginx làm reverse proxy (bảo vệ port 3001)
  3. Cài SSL/HTTPS với Let's Encrypt
  4. Build APK với Capacitor (trỏ đến IP/domain của VPS)
  5. Cài Windows Task Scheduler chạy sp_reclaim_locations mỗi ngày lúc 2:00 AM
