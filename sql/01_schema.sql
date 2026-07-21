-- ============================================================
--  WMS Pro — Schema + Seed Data
--  File: 01_schema.sql  (phiên bản cập nhật từ TỒN_X1_210426.xlsx)
--  Hướng dẫn: chạy toàn bộ file này trong Navicat
--  Query > Run SQL File  hoặc  paste vào Query tab rồi Run
-- ============================================================

-- Tạo database nếu chưa có
CREATE DATABASE IF NOT EXISTS wms_pro
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE wms_pro;

-- Tắt kiểm tra FK tạm để drop/create dễ hơn
SET FOREIGN_KEY_CHECKS = 0;

-- ─────────────────────────────────────────────
-- DROP nếu đã tồn tại (để chạy lại sạch)
-- ─────────────────────────────────────────────
DROP TABLE IF EXISTS audit_logs;
DROP TABLE IF EXISTS export_items;
DROP TABLE IF EXISTS export_orders;
DROP TABLE IF EXISTS import_items;
DROP TABLE IF EXISTS import_orders;
DROP TABLE IF EXISTS inventory;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS bookstores;
DROP TABLE IF EXISTS suppliers;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS warehouses;

SET FOREIGN_KEY_CHECKS = 1;

-- ─────────────────────────────────────────────
-- 1. WAREHOUSES
-- ─────────────────────────────────────────────
CREATE TABLE warehouses (
  id         INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  code       VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Mã kho: X1, XN, Q1, N1',
  name       VARCHAR(100) NOT NULL,
  city       VARCHAR(50)  NOT NULL DEFAULT '',
  address    TEXT,
  is_active  TINYINT(1)   NOT NULL DEFAULT 1,
  created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- 2. PRODUCTS
-- ─────────────────────────────────────────────
CREATE TABLE products (
  id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  barcode     VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Mã barcode (10-12 số)',
  name        VARCHAR(500) NOT NULL,
  unit        VARCHAR(20)  NOT NULL DEFAULT 'Cái',
  cost_price  DECIMAL(15,2) NOT NULL DEFAULT 0,
  sell_price  DECIMAL(15,2) NOT NULL DEFAULT 0,
  note        TEXT,
  is_active   TINYINT(1)   NOT NULL DEFAULT 1,
  created_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_barcode (barcode),
  FULLTEXT INDEX ft_name (name)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- 3. INVENTORY
--    location_text: vị trí dạng text tự do (vd: "1", "C2.3", "E1.4")
--    Không dùng FK locations table vì vị trí thực tế là text tự do
-- ─────────────────────────────────────────────
CREATE TABLE inventory (
  id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  product_id     INT UNSIGNED NOT NULL,
  warehouse_id   INT UNSIGNED NOT NULL,
  location_text  VARCHAR(50)  NOT NULL DEFAULT '' COMMENT 'Vị trí tự do: 1, C2.3, E1.4...',
  quantity       INT          NOT NULL DEFAULT 0,
  min_stock      INT          NOT NULL DEFAULT 5,
  zero_since     DATETIME              DEFAULT NULL COMMENT 'Thời điểm tồn về 0',
  status         ENUM('ok','warning','low','zero') NOT NULL DEFAULT 'ok',
  last_import    DATETIME              DEFAULT NULL,
  last_export    DATETIME              DEFAULT NULL,
  created_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_product_warehouse (product_id, warehouse_id),
  FOREIGN KEY (product_id)   REFERENCES products(id)   ON DELETE RESTRICT,
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
  INDEX idx_warehouse  (warehouse_id),
  INDEX idx_status     (status),
  INDEX idx_location   (location_text)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- 4. IMPORT ORDERS + ITEMS
-- ─────────────────────────────────────────────
CREATE TABLE import_orders (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ref_no       VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Số phiếu nhập (7 số)',
  import_date  DATE         NOT NULL,
  warehouse_id INT UNSIGNED NOT NULL,
  supplier     VARCHAR(200) NOT NULL DEFAULT '',
  total_items  INT          NOT NULL DEFAULT 0,
  note         TEXT,
  status       ENUM('draft','confirmed','cancelled') NOT NULL DEFAULT 'draft',
  created_by   VARCHAR(100) NOT NULL DEFAULT '',
  confirmed_at DATETIME              DEFAULT NULL,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
  INDEX idx_ref_no     (ref_no),
  INDEX idx_date_imp   (import_date),
  INDEX idx_status_imp (status)
) ENGINE=InnoDB;

CREATE TABLE import_items (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  import_order_id INT UNSIGNED NOT NULL,
  product_id      INT UNSIGNED NOT NULL,
  location_text   VARCHAR(50)  NOT NULL DEFAULT '',
  quantity        INT          NOT NULL,
  unit_price      DECIMAL(15,2) NOT NULL DEFAULT 0,
  note            VARCHAR(255)          DEFAULT NULL,
  FOREIGN KEY (import_order_id) REFERENCES import_orders(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id)      REFERENCES products(id)       ON DELETE RESTRICT,
  INDEX idx_import_order (import_order_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- 5. EXPORT ORDERS + ITEMS
-- ─────────────────────────────────────────────
CREATE TABLE export_orders (
  id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  ref_no       VARCHAR(20)  NOT NULL UNIQUE COMMENT 'Số phiếu xuất (7 số)',
  export_date  DATE         NOT NULL,
  warehouse_id INT UNSIGNED NOT NULL,
  bookstore    VARCHAR(200) NOT NULL DEFAULT '' COMMENT 'Tên nhà sách',
  total_items  INT          NOT NULL DEFAULT 0,
  note         TEXT,
  status       ENUM('draft','confirmed','cancelled') NOT NULL DEFAULT 'draft',
  created_by   VARCHAR(100) NOT NULL DEFAULT '',
  confirmed_at DATETIME              DEFAULT NULL,
  created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
  INDEX idx_ref_no_exp  (ref_no),
  INDEX idx_date_exp    (export_date),
  INDEX idx_status_exp  (status)
) ENGINE=InnoDB;

CREATE TABLE export_items (
  id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  export_order_id INT UNSIGNED NOT NULL,
  product_id      INT UNSIGNED NOT NULL,
  location_text   VARCHAR(50)  NOT NULL DEFAULT '',
  quantity        INT          NOT NULL,
  unit_price      DECIMAL(15,2) NOT NULL DEFAULT 0,
  note            VARCHAR(255)          DEFAULT NULL,
  FOREIGN KEY (export_order_id) REFERENCES export_orders(id) ON DELETE CASCADE,
  FOREIGN KEY (product_id)      REFERENCES products(id)       ON DELETE RESTRICT,
  INDEX idx_export_order (export_order_id)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- 6. USERS
-- ─────────────────────────────────────────────
CREATE TABLE users (
  id            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  username      VARCHAR(50)  NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  full_name     VARCHAR(100) NOT NULL,
  role          ENUM('admin','manager','staff') NOT NULL DEFAULT 'staff',
  warehouse_id  INT UNSIGNED          DEFAULT NULL,
  is_active     TINYINT(1)   NOT NULL DEFAULT 1,
  last_login    DATETIME              DEFAULT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────
-- 7. AUDIT LOGS
-- ─────────────────────────────────────────────
CREATE TABLE audit_logs (
  id         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id    INT UNSIGNED     DEFAULT NULL,
  action     VARCHAR(50)  NOT NULL,
  table_name VARCHAR(50)      DEFAULT NULL,
  record_id  INT UNSIGNED     DEFAULT NULL,
  old_value  JSON             DEFAULT NULL,
  new_value  JSON             DEFAULT NULL,
  ip_address VARCHAR(45)      DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL,
  INDEX idx_action  (action),
  INDEX idx_created (created_at)
) ENGINE=InnoDB;

ALTER TABLE audit_logs
  ADD COLUMN warehouse_id INT UNSIGNED DEFAULT NULL AFTER user_id,
  ADD INDEX idx_warehouse (warehouse_id),
  ADD CONSTRAINT fk_audit_logs_warehouse
    FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE SET NULL;
    
-- ─────────────────────────────────────────────
-- VIEW: tồn kho đầy đủ
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW v_inventory_full AS
SELECT
  inv.id            AS inventory_id,
  p.id              AS product_id,
  p.barcode,
  p.name            AS product_name,
  p.unit,
  p.cost_price,
  p.sell_price,
  inv.quantity,
  inv.min_stock,
  inv.status,
  inv.zero_since,
  inv.location_text AS location,
  w.id              AS warehouse_id,
  w.code            AS warehouse_code,
  w.name            AS warehouse_name,
  (inv.quantity * p.cost_price) AS stock_value,
  inv.last_import,
  inv.last_export,
  inv.updated_at
FROM inventory inv
JOIN products   p ON p.id = inv.product_id AND p.is_active = 1
JOIN warehouses w ON w.id = inv.warehouse_id;

-- ─────────────────────────────────────────────
-- VIEW: dashboard KPI
-- ─────────────────────────────────────────────
CREATE OR REPLACE VIEW v_dashboard_kpi AS
SELECT
  COUNT(DISTINCT p.id)                                              AS total_skus,
  COUNT(DISTINCT inv.warehouse_id)                                  AS total_warehouses,
  COALESCE(SUM(inv.quantity * p.cost_price), 0)                    AS total_stock_value,
  SUM(CASE WHEN inv.status = 'low'     THEN 1 ELSE 0 END)         AS count_low,
  SUM(CASE WHEN inv.status = 'zero'    THEN 1 ELSE 0 END)         AS count_zero,
  SUM(CASE WHEN inv.status = 'warning' THEN 1 ELSE 0 END)         AS count_warning
FROM inventory inv
JOIN products p ON p.id = inv.product_id AND p.is_active = 1;

-- ─────────────────────────────────────────────
-- STORED PROCEDURE: Thu hồi vị trí tồn 0 >= 3 ngày
-- ─────────────────────────────────────────────
DROP PROCEDURE IF EXISTS sp_reclaim_locations;
DELIMITER $$
CREATE PROCEDURE sp_reclaim_locations()
BEGIN
  UPDATE inventory
  SET    location_text = '',
         status        = 'zero'
  WHERE  quantity    = 0
    AND  zero_since IS NOT NULL
    AND  TIMESTAMPDIFF(DAY, zero_since, NOW()) >= 3;
END$$
DELIMITER ;

-- ============================================================
--  SEED DATA
-- ============================================================

-- ─────────────────────────────────────────────
-- Kho (4 kho theo hệ thống)
-- ─────────────────────────────────────────────
INSERT INTO warehouses (code, name, city) VALUES
  ('X1', 'Kho X1', 'Hồ Chí Minh'),
  ('XN', 'Kho XN', 'Hồ Chí Minh'),
  ('Q1', 'Kho Q1', 'Hồ Chí Minh'),
  ('N1', 'Kho N1', 'Hồ Chí Minh');

-- ─────────────────────────────────────────────
-- Tài khoản admin mặc định
-- password: Admin@123  (bcrypt hash)
-- ĐỔI MẬT KHẨU SAU KHI ĐĂNG NHẬP LẦN ĐẦU!
-- ─────────────────────────────────────────────
INSERT INTO users (username, password_hash, full_name, role) VALUES
  ('admin', '$2b$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'Quản trị viên', 'admin');


-- ─────────────────────────────────────────────
-- PRODUCTS — 1317 sản phẩm từ TỒN_X1_210426.xlsx
-- ─────────────────────────────────────────────
INSERT INTO products (barcode, name, unit) VALUES
  ('201089900603', 'DOUBLE A - BÚT DẠ QUANG MÀU DỊU DOUBLE A (1 CÂY) - XANH LÁ (VT)', 'Cái'),
  ('497405283100', 'ARTLINE-VIẾT LÔNG KIM EK-220BK ĐEN(4953-PM)', 'Cái'),
  ('893600745700', 'PLUS - RUOT XOA WHIPER-V 5MM X 12M PINK 42-V273(HV)', 'Cái'),
  ('893600745885', 'POKEMON - BÚT CHÌ POKEMON VĨ 3 CÂY (OCEAN) 600-V002 (HV)', 'Cái'),
  ('893604439227', 'STACOM MS103P HOP DUNG CU HINH HOC(12B L)(A5390)', 'Cái'),
  ('893500182498', 'BÚT CHÌ GỖ GP-C02 (5C/H) (5404-TL)', 'Cái'),
  ('893532400319', 'VIẾT CHÌ BẤM 2B 2.0MM PC-030 (10C/H) (A5404-TL)', 'Cái'),
  ('893532402687', 'BÚT CHÌ BẤM MÀU TRẮNG PC-037/HS (HỘP 10 CÂY)(5404-TL)', 'Cái'),
  ('893532403700', 'RUỘT BÚT GEL GR-027 TÍM HỘP 20 TÚI (5404-TL)', 'Cái'),
  ('893532403702', 'RUỘT BÚT GEL GR-027 XANH HỘP 20 TÚI (5404-TL)', 'Cái'),
  ('893532403712', 'RUỘT BÚT GEL GR-028 ĐEN HỘP 20 TÚI (5404-TL)', 'Cái'),
  ('207180000275', 'PENTEL- RUỘT VIẾT KÝ BL57(12C/H ) LR7_C(TN)-NS HP KHACH LE', 'Cái'),
  ('201089900605', 'DOUBLE A - BÚT DẠ QUANG MÀU DỊU DOUBLE A (1 CÂY) - CAM (VT)', 'Cái'),
  ('693011453313', 'GUANGBO - HỒ NƯỚC HWW06324 CUTE ANIMAL 30ML (12C/H) (THCK0644)', 'Cái'),
  ('693011457143', 'SANRIO -GUANGBO - VIẾT MÁY MỰC XANH XÓA ĐƯỢC SR GUBKT82167 NGÒI 0.3MM (12C/H) (ANS-0644)', 'Cái'),
  ('890118070640', 'THƯỚC KẺ NHỰA 15CM 170640(0056-COX)', 'Cái'),
  ('84511376854', 'SAKURA --BÚT CHÌ BẤM SUMOGRIP, 05, MÀU XÁM (0064-HH)', 'Cái'),
  ('893621528075', 'RADIUS - VIẾT BI XANH - I-5 (0.5) (12C/H) (THKG0067)', 'Cái'),
  ('893500186095', 'RUỘT GEL XÓA TP-GRE002 ĐEN TÚI 2 (HỘP 20) (5404-TL)', 'Cái'),
  ('203020300732', 'CAPYBARA-VĨ BẤM KIM+ KIM E-015 (24C)(0061-HT)', 'Cái'),
  ('390000004767', 'GIẤY NOTE HÌNH+ VIẾT BLTP-0287 (0061-HT)', 'Cái'),
  ('390000022252', 'VĨ SỔ NHÍ 2 CUỐN FX-002…  (H.THUẬN)', 'Cái'),
  ('489293139266', 'XÓA KÉO VĨ 4C 9266 (24C/H) (HT-0061)', 'Cái'),
  ('693738490664', 'GIẤY NOTE ZX668 (0061-HT)', 'Cái'),
  ('697200419305', 'LABUBU-VĨ XOÁ KÉO K-99305 (24C)(0061-HT)', 'Cái'),
  ('893612739586', 'CẮM VIẾT SẮT VUÔNG XANH LÁ KB-102 (HT-0061)', 'Cái'),
  ('893533011212', 'TP 3091-CẮM VIẾT GỖ 5592 (T.PHÁT)', 'Cái'),
  ('893533011844', 'HỘP GỖ VUÔNG 12CM 81046 (T.PHÁT)', 'Cái'),
  ('693325660014', 'RUỘT CHÌ BẤM SUPER FINE 2B, 0.5MM X 75MM - 24 CÂY/ỐNG  127520(0056-COX)', 'Cái'),
  ('899721429102', 'TUÝP MÀU VẼ ACRYLIC 75ML BLACK (ĐEN) 187599 (0056-COX)', 'Cái'),
  ('497405281146', 'ARTLINE-MỰC VIẾT BẢNG ESK-50ABL XANH(4953-PM)', 'Cái'),
  ('893500185709', 'NHÃN DÍNH DECAL SAL-002(10C/TÚI) (5404-TL)', 'Cái'),
  ('893500185715', 'NHÃN DÍNH DECAL SAL-006 (20C/TÚI) (5404-TL)', 'Cái'),
  ('893500185721', 'NHÃN DÍNH DECAL SAL-010 (20C/TÚI) (5404-TL)', 'Cái'),
  ('893500185724', 'NHÃN DÍNH DECAL SAL-011 (20C/TÚI) (5404-TL)', 'Cái'),
  ('893500185727', 'NHÃN DÍNH DECAL SAL-013 (20C/TÚI) (5404-TL)', 'Cái'),
  ('893500185730', 'NHÃN DÍNH DECAL SAL-016 (20C/TÚI) (5404-TL)', 'Cái'),
  ('893500185736', 'NHÃN DÍNH DECAL SAL-020 (20C/TÚI) (5404-TL)', 'Cái'),
  ('203009900033', 'FILE ĐỰNG TÀI LIỆU NGANG DF-5X-G2,6853 40/T (THCK0354)', 'Cái'),
  ('893603872949', 'SỔ LX B5 KUSUMI RN-B5L160KU-MU MÀU VÀNG - 50/T - 29496 (THCK0354)', 'Cái'),
  ('893603872965', 'SỔ BÌA CÒNG 4 LỖ A5 KUSUMI BN-A5H4KU-MU MÀU VÀNG 40/T - 29656 (THCK0354)', 'Cái'),
  ('893603872972', 'RUỘT GIẤY LOOSE LEAF B5 KẺ CARO 5MM - 50/T - 29724 (THCK0354)', 'Cái'),
  ('893603872973', 'RUỘT GIẤY LOOSE LEAF  A5 KẺ NGANG 7MM - 50/T - 29731 (THCK0354)', 'Cái'),
  ('893603872974', 'RUỘT GIẤY LOOSE LEAF  A5 KẺ NGANG CÓ CHẤM 7MM - 50/T - 29748 (THCK0354)', 'Cái'),
  ('893612245460', 'MÁY BẮN KEO G STAR NHỎ (0061-HT)', 'Cái'),
  ('893524610011', 'BỘ 5 CÂY CỌ VẼ CM-05BRS-W (0170-BMQT)', 'Cái'),
  ('893524611213', 'BẢNG MÀU NƯỚC DẠNG NẾN 18 MAU(0170-BMQT)', 'Cái'),
  ('693011452158', 'GUANGBO - CẮM VIẾT NHỰA FIZZ HWW06703 MÀU  (ANS-0644)', 'Cái'),
  ('893500184891', 'HỘP BÚT TP-PCA012/DO (5404-TL)', 'Cái'),
  ('693011451134', 'GUANGBO - BÓP VIẾT H97034 (12C/H) (ANS-0644)', 'Cái'),
  ('692271102118', 'GUANGBO - BÓP VIẾT HWH06398 (24C/H) (ANS-0644)', 'Cái'),
  ('697534655576', 'BỘ DÂY ĐEO THẺ 86576 (SN -THCK0646)', 'Cái'),
  ('697534555583', 'BỘ DÂY ĐEO THẺ 86583 (SN -THCK0646)', 'Cái'),
  ('697534655578', 'BỘ DÂY ĐEO THẺ 86578 (SN -THCK0646)', 'Cái'),
  ('693011456750', 'SANRIO -GUANGBO - GÔM HÌNH SR GUBKT84467 (24C/H) (ANS-0644)', 'Cái'),
  ('893532401572', 'CẶP CHỐNG GÙ BP-019 XANH/T24 NEW (5404-TL)', 'Cái'),
  ('893532403552', 'CẶP CHỐNG GÙ AKOOLAND BP-022/AK FIHA/T24(5404-TL)', 'Cái'),
  ('893532403592', 'CẶP CHỐNG GÙ BP-025 HỒNG/T24 (5404-TL)', 'Cái'),
  ('693011454505', 'GUANGBO - THƯỚC KẺ TRONG H05325-Z 20CM (36C/H) (ANS-0644)', 'Cái'),
  ('693011455048', 'GUANGBO - THƯỚC KẺ H05338 MÀU TRÁI CÂY (15CM) (24C/H) (ANS-0644)', 'Cái'),
  ('207050001951', 'THƯỚC KIỂU HÌNH 8118 (72C/H) (SN-0646)', 'Cái'),
  ('955623314785', 'TẬP GIẤY MÀU CA 4785 100TỜ(4816-VT)', 'Cái'),
  ('893528390492', 'BÌA TRÌNH KÝ KÉP FO-CB03 LÁ PASTEL (A5404-TL)', 'Cái'),
  ('893528390493', 'BÌA TRÌNH KÝ KÉP FO-CB03 TÍM PASTEL (A5404-TL)', 'Cái'),
  ('893603872969', 'SỔ BÌA CÒNG 8 LỖ A5 CAT''S DAILY LIFE BN-A5H8CAT-04 MÀU VÀNG - 24/T - 29694 (THCK0354)', 'Cái'),
  ('209010001202', 'KỆ TRƯNG BÀY MÔ HÌNH DORAEMON KỶ NIỆM 45 NĂM MĐ (TEENBOX)', 'Cái'),
  ('697357838698', 'HỘP BÚT MÀU VẼ ACRYLIC MARKER CAO CẤP M03-48 (1 ĐẦU) (0061-HT)', 'Cái'),
  ('204019903197', 'GIẤY PHOTO SUPREME 80GSM KHỔ A3(T.NGOC)', 'Cái'),
  ('204019902181', 'GIAY PHOTO SUPREME 70GSM KHO A5', 'Cái'),
  ('899138913920', 'GIẤY IK COPY A4/80', 'Cái'),
  ('893603872784', 'BỘ THƯỚC KẺ GẤU MÈO RL-EZM-5(30 BỘ)(0377-TK)', 'Cái'),
  ('893621222065', 'BĂNG XÓA TAM GIÁC CL-CT603 (0377-TK)', 'Cái'),
  ('893603872688', 'FILE TÀI LIỆU NGANG SAKURA DF-5K-SKR (0377-TK)', 'Cái'),
  ('893603872712', 'FILE TÀI LIỆU ĐỨNG DF-5Y-G2 MÀU XANH THAN (0377-TK)', 'Cái'),
  ('893609256042', 'KEO NƯỚC 35MLCL-GL350 (12C/H) (0377-TK)', 'Cái'),
  ('893621222243', 'GIẤY NOTE CON THỎ CL-SN016(36C)(0377-TK)', 'Cái'),
  ('692173495367', 'COMPA SẮT CHÌ CÂY G20402 (12C/H) (0639-DELI)', 'Cái'),
  ('692173490495', 'VIẾT CHÌ 2B E5810 (12C/H) (0639-DELI)', 'Cái'),
  ('692173495756', 'THẺ ĐEO NGANG 105X70MM E5756 (50C/H) (0639-DELI)', 'Cái'),
  ('692173495757', 'THẺ ĐEO DỌC 70X105MM E5757 (50C/H) (0639-DELI)', 'Cái'),
  ('692173496036', 'KÉO VĂN PHÒNG 170MM 6036 (12C/H) (0639-DELI)', 'Cái'),
  ('693520537883', '(KSD) VIẾT CHÌ GỖ 2B EU53200 (12C/H) (0639-DELI)', 'Cái'),
  ('694179842217', 'BÚT CHÌ 2B NEON CC085-2B (0639-DELI)', 'Cái'),
  ('694179845323', 'TÚI BÚT, 19*5*5CM BẢN ST CH901 (1/12/96) (0639-DELI)', 'Cái'),
  ('693520537882', '(KSD) VIẾT CHÌ GỖ 2B EU53100 (12C/H) (0639-DELI)', 'Cái'),
  ('893621222020', 'BĂNG XÓA CL-CT601(12C/H)(0377-TK)', 'Cái'),
  ('693520535801', '(KSD CODE CŨ)DAO RỌC GIẤY E2040 (12C/H) (0639-DELI)', 'Cái'),
  ('201089900559', 'PLUS - BÚT DẠ QUANG XÓA ĐƯỢC GREEN 600-V007 (HV)', 'Cái'),
  ('201089900560', 'PLUS - BÚT DẠ QUANG XÓA ĐƯỢC ORANGE  600-V008 (HV)', 'Cái'),
  ('893600745874', 'PLUS - BÚT DẠ QUANG XÓA ĐƯỢC PINK 600-V009 (HV)', 'Cái'),
  ('893609256573', 'BĂNG XÓA CL-CT600 (0377-TK)', 'Cái'),
  ('693520535303', 'RUỘT CHÌ KIM 0.7 EU67700 (48C/H) (0639-DELI)', 'Cái'),
  ('693520539294', 'CHUỐT CHÌ MINI ER01301 (12C/H) (0639-DELI)', 'Cái'),
  ('697308372022', 'TẨY MÀU HÌNH QUE KEM 71122 (12C/H) (0639-DELI)', 'Cái'),
  ('893603872685', 'FILE TÀI LIỆU NGANG DF-5X-G2 MÀU XANH THAN (5 NGĂN)(0377-TK)', 'Cái'),
  ('893603872702', 'TÚI ĐỰNG TÀI LIỆU A4 SAKURA CLB--CON (24C/T) (0377-TK)', 'Cái'),
  ('893609256205', 'THƯỚC DẺO CL-FR300 (20C/H) (0377-TK)', 'Cái'),
  ('893621222147', 'NHÃN VỞ MAXTINI CL-NT237 (0377-TK)', 'Cái'),
  ('893609256324', 'BÚT SÁP 12 MÀU CL-CR101 (0377-TK)', 'Cái'),
  ('893609256325', 'BÚT SÁP 18 MÀU CL-CR102 (0377-TK)', 'Cái'),
  ('893609256326', 'BÚT SÁP 24 MÀU CL-CR103 (0377-TK)', 'Cái'),
  ('893609256526', 'BÚT SÁP 12 MÀU CL-CR201 (0377-TK)', 'Cái'),
  ('893609256901', 'CHÌ MÀU 12 MÀU AM-CL101 (12H) (0377 - TK)', 'Cái'),
  ('893603872916', 'THƯỚC KẺ 20CM RL-EZM-PS20-2(25C)(0377-TK)', 'Cái'),
  ('893609256779', 'THƯỚC KẺ 15CM RL05-PR (48C/H) (0377-TK)', 'Cái'),
  ('893609256902', 'CHÌ MÀU 18 MÀU AM-CL102 (12H) (0377 - TK)', 'Cái'),
  ('893621222045', 'THƯỚC KẺ 15CM CL-RL154 (48C/H) (0377-TK)', 'Cái'),
  ('204029901038', 'GIẤY BÌA MÀU A4 (100 TỜ/XẤP)', 'Cái'),
  ('692173499619', 'BỘ DỤNG CỤ HỌC SINH 9619 (24C/H) (0639-DELI)', 'Cái'),
  ('694179842800', 'BÚT MÁY NHỰA NGÒI TO CQ881 (0639-DELI)', 'Cái'),
  ('694179844972', 'BÚT BI 0.7MM MÀU XANH 50C/HỘP BẢN ST CQ184-BL (1/50/600) (0639-DELI)', 'Cái'),
  ('694179845595', 'VIẾT CHÌ ĐEN 2B BẢN ST CC30-2B (1/72/2880) (0639-DELI)', 'Cái'),
  ('697350400083', 'BÚT GEL 0.5 MM MÀU ĐEN EG16-BK (12C/H)(0639-DELI)', 'Cái'),
  ('693520531031', 'CHUỐT CHÌ MINI ER00100 (72C/H) (0639-DELI)', 'Cái'),
  ('893612739073', 'BẢNG MENU 10*20 MICA ĐẾ NHÔM CAO CẤP (0061-HT)', 'Cái'),
  ('692173495504', 'TÚI KHUY A4 ĐINH NGANG (VÀNG + BIỂN+ TRẮNG) 5504 (12C/H) (0639-DELI)', 'Cái'),
  ('692173495576', 'CẶP TÀI LIỆU 1 NGĂN 5576 (0639-DELI)', 'Cái'),
  ('692173497236', 'FILE LÁ HỌC SINH 20 LÁ EXPLORA EZ55302 (12C/H) (0639-DELI)', 'Cái'),
  ('692173497334', 'TÚI CÚC FC EXPLORA EZ65302 (10C/H) (0639-DELI)', 'Cái'),
  ('694179846041', 'TÚI ĐỰNG HỒ SƠ A4 BẢN ST EF554-HO ( 1/12/180/720) (0639-DELI)', 'Cái'),
  ('201990002496', 'VIẾT DẠ QUANG TOYO', 'Cái'),
  ('201990002521', 'DA3-NƯỚC RỬA TAY LIFEBUOY 180ML', 'Cái'),
  ('704315006152', 'RUBĂNG FULLMARK N186BK', 'Cái'),
  ('201990002497', 'DA3-BAO XOÀI BÓNG DẺO 24X34 KG (KT)', 'Cái'),
  ('201990002499', 'GIẤY BÓ THÉP TIỀN BẰNG TAY', 'Cái'),
  ('201990002512', 'DA3-GIẤY VỆ SINH WATER SILK', 'Cái'),
  ('201990002563', 'GIẤY BÓ THÉP TIỀN BẰNG TAY (100 TỜ/XẤP)', 'Cái'),
  ('201990002575', 'TH 149-MÀN THẢ TRĂNG SAO 138LED VÀNG (T.HÀ)', 'Cái'),
  ('202010902710', 'TH 47-DÂY NGÔI SAO-TA (6 LỚN, 6 NHỎ) (0477-TH)', 'Cái'),
  ('693520539018', 'RUỘT CỦA TẨY DẠNG BÚT EH01912 (2C/TÚI) (48TÚI/H) (0639-DELI)', 'Cái'),
  ('694179845613', 'TÚI ĐỰNG HỒ SƠ A4 BẢN ST EF554-XD (1/12/180/720) (0639-DELI)', 'Cái'),
  ('692173498553', 'KẸP BƯỚM MÀU 32MM E8553A (0639-DELI)', 'Cái'),
  ('204990000030', 'TEM DECAL GIẤY (50MM X 70MM) X 50M - 2 TEM (THCK0561)', 'Cái'),
  ('885241343715', 'GIẤY PHOTO SUPREME 80GSM KHỔ A4', 'Cái'),
  ('207130000213', 'HỒ NƯỚC', 'Cái'),
  ('202990001019', 'ỐNG NHỰA ĐÓNG CHỨNG TỪ Ø 6 (0568-ALV)', 'Cái'),
  ('202990001026', 'ỐNG NHỰA ĐÓNG CHỨNG TỪ 5.2MM (0568-ALV)', 'Cái'),
  ('893601333309', 'KHĂN ƯỚT VS KIN KIN 100 TỜ, KHÔNG MÙI (D.HIEP)', 'Cái'),
  ('893532403626', 'KM-BÚT GEL XÓA ĐƯỢC GELE-006/XMAS MỰC XANH-X.DƯƠNG MAZZIC TÚI 3 CÂY (5404-TL)', 'Cái'),
  ('893532403628', 'KM-BÚT GEL XÓA ĐƯỢC MAZZIC GELE-006/XMAS MỰC XANH-THÂN X.LÁ TÚI 3 CÂY (5404-TL)', 'Cái'),
  ('893532403627', 'KM-BÚT GEL XÓA ĐƯỢC GELE-006/XMAS MỰC XANH-THÂN ĐỎ MAZZIC TÚI 3 CÂY (5404-TL)', 'Cái'),
  ('201990001572', 'TG 06-BỘ ĐỒ BẢO HỘ TOÀN THÂN(T.TÂM)', 'Cái'),
  ('201990002090', 'TG 11-KÍNH BẢO HỘ CHỐNG GIỌT BẮN (T.TÂM)', 'Cái'),
  ('204990000028', 'VLB05-MỰC IN RIBBON WAX FREMIUM (110M * 300M) (0561-VLBELL)', 'Cái'),
  ('204990000037', 'TEM DECAL GIẤY (50MM X 25MM) X 50M - 2 TEM (0561-VLBELL)', 'Cái'),
  ('201990001981', 'HOA MAI VẢI NỈ B/2 (0517-STELL)', 'Cái'),
  ('201990002211', 'SL 337-VÒNG LỰU RUY BĂNG 35CM (STELLA)', 'Cái'),
  ('201990002640', 'MẸT HOA QUẠT GIẤY (STELLA)', 'Cái'),
  ('204990000036', 'TEM DECAL GIẤY  (50MM X 30MM) X 50M - 2 TEM (0561-VLBELL)', 'Cái'),
  ('201990001942', 'DÂY BI TRÒN MẠ VÀNG 4M/20LED-TA (0477-TH)', 'Cái'),
  ('201990002194', 'TH 129-DÂY HOA VẢI NHỎ 4M 18LED -RGB (T.HÀ)', 'Cái'),
  ('201990002196', 'TH 131-DÂY HOA MAI 5 CÁNH 60 BÔNG 8M  (T.HÀ)', 'Cái'),
  ('201990002197', 'TH 132-DÂY HOA MAI 5 CÁNH 18 LED  (T.HÀ)', 'Cái'),
  ('201990002202', 'TH 137-CẦU MAI 16CM 150LED  (T.HÀ)', 'Cái'),
  ('201990001951', 'VÒNG HOA MAI (0517-STELL)', 'Cái'),
  ('893532401114', 'HÚT BỤI MINI MVE-001 XANH (A5404-TL)', 'Cái'),
  ('893532401124', 'HÚT BỤI MINI MVE-001 HỒNG (A5404-TL)', 'Cái'),
  ('202000302203', 'SÁO DỌC RECORDER SOPRANO YRS-24B (YAMAHA)', 'Cái'),
  ('202000302205', 'SÁO DỌC RECORDER SOPRANO RAINBOW YRS-20BP - PINK (YAMAHA)', 'Cái'),
  ('202000302206', 'SÁO DỌC RECORDER SOPRANO RAINBOW YRS-20BG - GREEN (YAMAHA)', 'Cái'),
  ('202000302204', 'SÁO DỌC RECORDER SOPRANO RAINBOW YRS-20BB - BLUE (YAMAHA)', 'Cái'),
  ('202000302207', 'KÈN PIANICA P-32D (YAMAHA)', 'Cái'),
  ('202990001358', 'DÂY THUN KHOANH NHỎ', 'Cái'),
  ('202000302474', 'KM - QUÀ TẶNG MAKE & PLAY GUITAR (YAMAHA)', 'Cái'),
  ('893600880001', 'THƯỚC 15CM WIN TRONG C-15 (50C/H) (0489-QL)', 'Cái'),
  ('893600880003', 'THƯỚC 20CM WIN TRONG C-20 (50C/H) (0489-QL)', 'Cái'),
  ('893600880021', 'THƯỚC PARABOL 2C TRUNG QL-02 ( (20C/H) (0489-QL)', 'Cái'),
  ('893600880041', 'THƯỚC BỘ MÀU T-140 (20B/H) (0489-QL)', 'Cái'),
  ('893501581236', 'MỰC VIẾT MÁY QUEEN(TIM)(12C/LỐC)(5164-TVP)', 'Cái'),
  ('252000520049', 'BỘ THỰC HÀNH TOÁN -TIẾNG VIỆT LỚP 1-N20 (4631-ĐT)', 'Cái'),
  ('200060100237', 'BỘ THỰC HÀNH TOÁN LỚP 4(4631-ĐT)', 'Cái'),
  ('202000302475', 'KM - QUÀ TẶNG MAKE & PLAY BỘ TRỐNG (YAMAHA)', 'Cái'),
  ('893512826202', 'GIẤY PHOTO  A5  ( TTONE  ) - DL 80G/M2 (0515-TTT)', 'Cái'),
  ('204019902025', 'EXCEL - GIẤY PHOTO EXCEL 80 GSM KHỔ A5 (VT)', 'Cái'),
  ('203000200017', 'DA - BÌA HỘP 10CM', 'Cái'),
  ('899138913639', 'GIẤY PHOTO PAPERLINE A4-70 (0372-TP)', 'Cái'),
  ('201089900604', 'DOUBLE A - BÚT DẠ QUANG MÀU DỊU DOUBLE A (1 CÂY) - XANH DƯƠNG (VT)', 'Cái'),
  ('893500180246', 'BỘ DỤNG CỤ HỌC TOÁN TP-BTS021 (5404-TL)', 'Cái'),
  ('893532403703', 'RUỘT BÚT GEL GR-026 XANH HỘP 20 TÚI (5404-TL)', 'Cái'),
  ('893500181002', 'BÚT LÔNG FP-01/12C (5404-TL)', 'Cái'),
  ('893500181895', 'RUỘT GEL XANH GR-04 (24C/H) (5404-TL)', 'Cái'),
  ('893500183036', 'MỰC BÚT MÁY TÍM FPI-07 (6H/L) (5404-TL)', 'Cái'),
  ('893500184056', 'GÔM E-06', 'Cái'),
  ('893521948203', 'KẸP BƯỚM ĐEN 32MM FO-DC04 (12H/L) (5404-TL)', 'Cái'),
  ('893532401663', 'MÀU ACRYLIC TUYP 12ML ACR-C008 12 MÀU (5404-TL)', 'Cái'),
  ('893532402163', 'GÔM DEMON SLAYER E-036/DS (HỘP 20/T800) (5404-TL)', 'Cái'),
  ('893532402179', 'ỐNG MỰC BÚT MÁY CHIPY FPIC-020 ĐEN HỘP 6 (5404-TL)', 'Cái'),
  ('893532402188', 'BÚT MÁY CHIPY XANH FTC-020 MỰC XANH HỘP 20(5404-TL)', 'Cái'),
  ('893532402189', 'BÚT MÁY CHIPY HỒNG FTC-020 MỰC TÍM HỘP 20(5404-TL)', 'Cái'),
  ('893532402303', 'MIN CHÌ BẤM PCL-008 2B 0.5MM HỘP 40 (5404-TL)', 'Cái'),
  ('893532403701', 'RUỘT BÚT GEL GR-027 ĐEN HỘP 20 TÚI (5404-TL)', 'Cái'),
  ('893532404022', 'RUỘT BÚT BI BPR-031 XANH HỘP 100 (5404-TL)', 'Cái'),
  ('893532404023', 'RUỘT BÚT GEL BI BGR-023 XANH HỘP 100 (5404-TL)', 'Cái'),
  ('201089900601', 'DOUBLE A - BÚT DẠ QUANG MÀU DỊU DOUBLE A (1 CÂY) - VÀNG (VT)', 'Cái'),
  ('201089900602', 'DOUBLE A - BÚT DẠ QUANG MÀU DỊU DOUBLE A (1 CÂY) - HỒNG (VT)', 'Cái'),
  ('893532401049', 'LÕI GÔM ĐIỆN EER-009 (A5404-TL)', 'Cái'),
  ('893532401495', 'BÚT CHÌ MÀU WOODFREE CPC-C032/AK 18 MÀU(5404-TL)', 'Cái'),
  ('893532401793', 'GÔM AKOOLAND TP-E017/AK (HỘP 20/T800) (5404-TL)', 'Cái'),
  ('893532403042', 'COMPA C-021(HỘP 12 (5404-TL)', 'Cái'),
  ('893532403321', 'COMPA C-022 HỘP 16 (5404-TL)', 'Cái'),
  ('893532403705', 'RUỘT BÚT GEL GR-026 ĐEN HỘP 20 TÚI (5404-TL)', 'Cái'),
  ('893532403707', 'RUỘT BÚT GEL XÓA GRE-006 XANH HỘP 20 TÚI (5404-TL)', 'Cái'),
  ('893607339011', 'MÀU NƯỚC 12 MÀU W-14 (0489-QL)', 'Cái'),
  ('893532403710', 'RUỘT BÚT GEL GR-028 XANH HỘP 20 TÚI (5404-TL)', 'Cái'),
  ('893607339010', 'MÀU NƯỚC 6 MÀU W-12 (0489-QL)', 'Cái'),
  ('893600880059', 'MÀU NƯỚC 12 MÀU SẮC XUÂN W-06 (0489-QL)', 'Cái'),
  ('203020201694', 'DOUBLE A - KẸP BƯỚM 51MM DOUBLE A (VT)', 'Cái'),
  ('885874175071', 'DOUBLE A - PIN AAA DOUBLE A SUPER ALKALINE (VỈ 2V)(H 10VỈ)(VT)', 'Cái'),
  ('885874171688', 'DOUBLE A - KIM BAM 10 DOUBLE A (VT)', 'Cái'),
  ('885874171855', 'DOUBLE A - KẸP BƯỚM 32MM DOUBLE A (VT)', 'Cái'),
  ('203020201648', 'DOUBLE A - KẸP BƯỚM 25MM DOUBLE A (VT)', 'Cái'),
  ('893500184115', 'SAP NAN MC-03 (TL)', 'Cái'),
  ('893500184793', 'KÉO HỌC SINH SC-012 (20C/H) (5404-TL)', 'Cái'),
  ('893500184942', 'BỘ TẠO HÌNH SÁP NẶN MCT-C04 (20C/H) (5404-TL)', 'Cái'),
  ('893500186549', 'BỘ TÔ MÀU VẢI KIT-C034 (A5404-TL)', 'Cái'),
  ('893500186742', 'BỘ TÔ MÀU THẠCH CAO KIT-C037(5404-TL)', 'Cái'),
  ('893500186784', 'BỘ TÔ MÀU THẠCH CAO KIT-C038(5404-TL)', 'Cái'),
  ('893532400563', 'BÚT MÁY TP-FTC02 CÁN XANH-MỰC XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532400775', 'BỘT NẶN COLOKIT MD-C009 4 MÀU (LỐC 4 HỘP /T24) (5404-TL)', 'Cái'),
  ('893604045504', 'CHUỐT CHÌ TP-S018 (20C/H) (5404-TL)', 'Cái'),
  ('893532403605', 'BA LÔ BP-031 /T24 (5404-TL)', 'Cái'),
  ('893532403606', 'BA LÔ BP-032 /T24 (5404-TL)', 'Cái'),
  ('893500185325', 'BÚT GEL ĐEN B011 (20C/H) (5404-TL)', 'Cái'),
  ('893500180466', 'BÚT BI ĐỎ TL-031 (20C/H) (5404-TL)', 'Cái'),
  ('893500180037', 'BÚT BI XANH TL-023 (20C/H) (5404-TL)', 'Cái'),
  ('893500180467', 'BÚT BI ĐEN TL-031 (20C/H) (5404-TL)', 'Cái'),
  ('893500180470', 'BÚT BI ĐỎ TL-036 (20C/H)/T1200 (5404-TL)', 'Cái'),
  ('893500181022', 'BÚT LÔNG KIM XANH FL-04 (10C/H) (5404-TL)', 'Cái'),
  ('893500185346', 'BÚT GEL TÍM 08 NEW (20C/H) (5404-TL)', 'Cái'),
  ('893500185362', 'BÚT GEL ĐỎ GEL-012/DO (20C/H) (5404-TL)', 'Cái'),
  ('893500185469', 'BÚT GEL XANH GEL-030/FR (20C/H) (5404-TL)', 'Cái'),
  ('893500186180', 'BÚT GEL TÍM XÓA ĐƯỢC TP-GELE003 (20C/H) (5404-TL)', 'Cái'),
  ('893500186628', 'BÚT GEL TP-GEL038 XANH (20C/H) (A5404-TL)', 'Cái'),
  ('893532400436', 'BÚT GEL XÓA ĐƯỢC GELE-006 XANH (20C/H) TL (5404-TL)', 'Cái'),
  ('893532401708', 'BÚT GEL XÓA ĐƯỢC GELE-006/V1 XANH HỘP 20 (5404-TL)', 'Cái'),
  ('893532403642', 'BÚT GEL GEL-056 ĐEN HỘP 20 (5404-TL)', 'Cái'),
  ('893532403821', 'BÚT GEL BI GELB-028 XANH HỘP 20 (5404-TL)', 'Cái'),
  ('893532400437', 'BÚT GEL XÓA ĐƯỢC GELE-006 TÍM (20C/H) TL (5404-TL)', 'Cái'),
  ('893532403822', 'BÚT GEL BI GELB-029 XANH HỘP 20 (5404-TL)', 'Cái'),
  ('893500185344', 'BÚT GEL ĐỎ 08 NEW (20C/H) (5404-TL)', 'Cái'),
  ('893532401620', 'BÚT GEL TÍM GEL-012/AK (20C/H) (5404-TL)', 'Cái'),
  ('893500184850', 'TẬP HỌC SINH ĐIỂM 10 START-UP 80TR ĐL60 KẺ NGANG SM NB-097 (100C/T)(5404-TL)', 'Cái'),
  ('893500186992', 'TẬP HỌC SINH ĐIỂM 10 80TR ĐL100 4 ÔLY VUÔNG TP-NB003 (100C/T)(5404-TL)', 'Cái'),
  ('893532401726', 'TẬP HỌC SINH 48TR ĐL100 4 ÔLY VUÔNG TP-NB002/AK (200C/T)(5404-TL)', 'Cái'),
  ('893532404015', 'TẬP CHỐNG LEM 48TR ĐL100 5 Ô LY NB-120 (200C/T)(5404-TL)', 'Cái'),
  ('206030002972', 'KM DORAEMON - SỔ TAY BẢN GIAO HƯỞNG ĐỊA CẦU (TEENBOX)', 'Cái'),
  ('202000508181', 'KM BỘ TRANH CÔ TIÊN XANH', 'Cái'),
  ('200080011890', 'PLUS KIM BẤM SỐ 10', 'Cái'),
  ('893500186862', 'BÚT VẼ LÊN VẢI FM-C002 TÚI 12 MÀU (5404-TL)', 'Cái'),
  ('893532401981', 'MÀU ACRYLIC ACR-C009 75ML VÀNG ĐẤT (5404-TL)', 'Cái'),
  ('893532401983', 'MÀU ACRYLIC ACR-C009 75ML XANH DƯƠNG (5404-TL)', 'Cái'),
  ('893532401985', 'MÀU ACRYLIC ACR-C009 75ML ĐỎ (5404-TL)', 'Cái'),
  ('893532401986', 'MÀU ACRYLIC ACR-C009 75ML TÍM (5404-TL)', 'Cái'),
  ('893532401989', 'MÀU ACRYLIC ACR-C009 75ML HỒNG (5404-TL)', 'Cái'),
  ('893604045741', 'COMPA Y TL-C014,C01 (16C/H) (5404-TL)', 'Cái'),
  ('497756417703', 'PLUS - PLUS PS-10E BAM KIM 0 KIM (HV)', 'Cái'),
  ('893600745888', 'POKEMON - EXAM FILE A5 - BL 300-V001 (HV)', 'Cái'),
  ('893600745889', 'POKEMON - EXAM FILE A5 - YL 300-V002 (HV)', 'Cái'),
  ('893600745890', 'POKEMON - EXAM FILE A5 - GN 300-V003 (HV)', 'Cái'),
  ('893600745419', 'PLUS - DA-BIA LA NHUA F4 (PLUS DAY)', 'Cái'),
  ('204029901143', 'GIAY BIA MAU A3 (100 TO XAP)', 'Cái'),
  ('231990002351', 'BAO NHỰA ĐỰNG SỔ TIẾT KIỆM SCB (BBVL0037)', 'Cái'),
  ('231990002352', 'BAO NHỰA ĐỰNG THẺ THÔNG BÁO TÀI KHOẢN SCB (BBVL0037)', 'Cái'),
  ('231039901619', 'BAO LÌ XÌ SCB 23 B/8', 'Cái'),
  ('231039901620', 'BAO LÌ XÌ BẢO LONG 23 B/8', 'Cái'),
  ('233069900659', 'DA-HUY HIEU SCB (BBVL0037)', 'Cái'),
  ('490250541753', 'PILOT- VIẾT XÓA ĐƯỢC FRIXION BALL CLICKER MỰC TÍM/BLRT-FR7-V-ME (12C/H)(0323-BT)', 'Cái'),
  ('490250525642', 'PILOT - VIẾT BI REXGRIP MỰC ĐỎ (TIP 0.7MM)/BRG-10F-RR-BG (10C/H) (BT-0323)', 'Cái'),
  ('490250521045', 'PILOT- VIẾT GEL G-2 MỰC TÍM/BL-G2-7-V (12C/H)(0323-BT)', 'Cái'),
  ('490250541359', 'PILOT- VIẾT BI REXGRIP MỰC TÍM/BRG-10F-VV-BG (10C/H)(0323-BT)', 'Cái'),
  ('490250541749', 'PILOT- VIẾT XÓA ĐƯỢC FRIXION BALL CLICKER MỰC ĐEN/BLRT-FR7-B-ME (12C/H)(0323-BT)', 'Cái'),
  ('490250546178', 'PILOT- VIẾT GEL G-2 NHŨ TÍM/BL-G2-7-MV (12C/H)(0323-BT)', 'Cái'),
  ('490250558190', 'PILOT - VIẾT GEL JUICE UP MÀU ĐỎ (TIP 0.5MM)/LJP-20S5-R-EX (5C/H) (BT-0323)', 'Cái'),
  ('490250545104', 'PILOT- VIẾT GEL  JUICE MỰC ĐỎ/LJU-10F-R-EX (5C/H)(0323-BT)', 'Cái'),
  ('490250567396', 'PILOT - VIẾT GEL JUICE_MUTED MỰC XANH (TIP 0.5MM)/LJU-15-KUL (10C/H) (BT-0323)', 'Cái'),
  ('490250567397', 'PILOT - VIẾT GEL JUICE_MUTED MỰC TÍM (TIP 0.5MM)/LJU-15-KUV (10C/H) (BT-0323)', 'Cái'),
  ('490250545067', 'PILOT- VIẾT GEL  JUICE MỰC ĐEN/LJU-10EF-B-EX (5C/H)(0323-BT)', 'Cái'),
  ('490250534288', 'PILOT- VIẾT MỰC NƯỚC  HI-TECH V5 RT MỰC XANH/BXRT-V5-L (12C/H)(0323-BT)', 'Cái'),
  ('490250534287', 'PILOT- VIẾT MỰC NƯỚC  HI-TECH V5 RT MỰC ĐỎ/BXRT-V5-R (12C/H)(0323-BT)', 'Cái'),
  ('490250544286', 'PILOT- VIẾT  ROLLER BALL HI-TECPOINT V7 ĐEN/BXC-V7-B-BGD (12C/H)(0323-BT)', 'Cái'),
  ('490250508569', 'VIẾT LÔNG KIM PILOT BX-V5 ĐỎ (12C/H)(0323-BT)', 'Cái'),
  ('490250508575', 'PILOT - VIẾT MỰC NƯỚC HI-TECH V7(0.7) ĐEN/BXV7(12C/H)(THCK0323)', 'Cái'),
  ('490250515465', 'VIẾT BI BẤM  PILOT BPGP-10 R-F-R ĐỎ (12C/H)(0323-BT)', 'Cái'),
  ('490250542423', 'PILOT- VIẾT BI ACROBALL MỰC ĐEN/BAB-15M-B-BG (10C/H)(0323-BT)', 'Cái'),
  ('490250542425', 'PILOT- VIẾT BI I ACROBALL MỰC XANH/BAB-15M-L-BG (10C/H)(0323-BT)', 'Cái'),
  ('490250548202', 'PILOT - BÚT BI PLASTIC MỰC XANH/BP-1RT-F-L (12 CÂY/HỘP)(THCK0323)', 'Cái'),
  ('490250508568', 'VIẾT LÔNG KIM PILOT BX-V5 ĐEN (12C/H)(0323-BT)', 'Cái'),
  ('490250567393', 'PILOT - VIẾT GEL JUICE_MUTED MỰC CAM (TIP 0.5MM)/LJU-15-KUO (10C/H) (BT-0323)', 'Cái'),
  ('490250567395', 'PILOT - VIẾT GEL JUICE_MUTED MỰC XANH LÁ (TIP 0.5MM)/LJU-15-KUG (10C/H) (BT-0323)', 'Cái'),
  ('490250567398', 'PILOT - VIẾT GEL JUICE_MUTED MỰC HỒNG (TIP 0.5MM)/LJU-15-KUP (10C/H) (BT-0323)', 'Cái'),
  ('893603872346', 'TẬP CAMPUS 200TR DL70 EMOTION A5 - AEMT200 (0377-TK)', 'Cái'),
  ('893603872412', '(KSD) TẬP CAMPUS 96TR DL70 PETWORLD - APEW96 (0377-TK)', 'Cái'),
  ('893603872315', 'TẬP CAMPUS 96TR DL70 STREET ME - ASTR96 (0377-TK)', 'Cái'),
  ('893603872223', '(KSD)TẬP CAMPUS 96TR DL100 UNDER THẺ SEA A5 - AUTS96-1 (0377-TK)', 'Cái'),
  ('893612245377', 'VIẾT BI NƯỚC G STAR GP-04 ĐỦ MÀU (0061-HT)', 'Cái'),
  ('893612245378', 'VIẾT BI BẤM G STAR GP-05 ĐỦ MÀU (0061-HT)', 'Cái'),
  ('697630936071', 'HỘP MÀU VẼ 24 MÀU ACRYLIC MARKER 5012(0061-HT)', 'Cái'),
  ('880220301444', 'VIẾT MY-GEL METAL ĐỎ (0061-HT)', 'Cái'),
  ('880220303226', 'VIẾT NƯỚC 0.48MM XANH DA PERFUME (0061-HT)', 'Cái'),
  ('692424740885', 'VIẾT NƯỚC 885 (8 MÀU) CHOSCH (0061-HT)', 'Cái'),
  ('880220303231', 'VIẾT NƯỚC BẤM U-KNO CK ĐEN (0061-HT)', 'Cái'),
  ('880220303233', 'VIẾT NƯỚC BẤM U-KNO CK ĐỎ (0061-HT)', 'Cái'),
  ('880220352213', 'VIẾT ĐỎ ZERO NO 13 (0061-HT)', 'Cái'),
  ('880220376113', 'VIẾT ĐỎ JIJTORU 13 (0061-HT)', 'Cái'),
  ('697630936070', 'HỘP VIẾT LÔNG  18 MÀU ACRYLIC MARKER 5011(0061-HT)', 'Cái'),
  ('893603872681', 'TẬP SV CAMPUS 200TR DL60 4 ÔLY NGANG SỐ CUTE B5S - BSSCT200 (0377-TK)', 'Cái'),
  ('697465158175', 'VIẾT MÁY XÓA ĐƯỢC M006 (12C/H)(0061-HT)', 'Cái'),
  ('893603872319', 'TẬP CAMPUS 200TR DL70 STYLE ME A5 - ASTM200 (0377-TK)', 'Cái'),
  ('694862880307', 'VIẾT BIC ĐÂU MINI ĐỦ MÀU (12C/H) (0061-HT)', 'Cái'),
  ('893612245335', 'VIẾT BI G STAR GP-01 (0061-HT)', 'Cái'),
  ('200080096203', 'VIẾT NƯỚC ĐỦ MÀU PRETTY GEL  (0061-HT)', 'Cái'),
  ('880220350231', 'VIẾT JELLITTO MÀU ĐEN 31 (0061-HT)', 'Cái'),
  ('880220350238', 'VIẾT JELLITTO BLUE 38 MÀU XANH (0061-HT)', 'Cái'),
  ('880220375920', 'VIẾT NƯỚC 0,5 TÍM  MYGELL 5 20 (0061-HT)', 'Cái'),
  ('692424748035', 'VIẾT GEL XANH CS-K35A H/12 (THNK100)', 'Cái'),
  ('880220350213', 'VIẾT JELLITTO MÀU ĐỎ 13 (0061-HT)', 'Cái'),
  ('893612245375', 'VIẾT BI NƯỚC ĐỦ MÀU G STAR GP-02 (0061-HT)', 'Cái'),
  ('893521946071', 'CRAYOLA - BỘ BÚT SÁP DẦU 28 MÀU - 524628 (T.LONG)', 'Cái'),
  ('203020703606', 'HP - BANG KEO OPP MAU 45 MIC HPX 4.8CM X 70Y - XANH LA (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703414', 'HP 73-BĂNG KEO OPP MÀU 405 MIC HPX 4.8cm x 70Y - CAM (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703454', 'HP BĂNG KEO SIMILI 4.8CM X 12YY (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703468', 'HP 127-DECAL TOMTOM 20.5cm x 16.5cm (XẤP 10 TỜ) (0562-HP)', 'Cái'),
  ('203020703339', 'HP 2-BĂNG KEO OPP TRONG 40MIC - 4.8CM x 80Y (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703427', 'HP 86-BĂNG KEO 2 MẶT NƯỚC 1.2CM (24C/CÂY) (HP-0562)', 'Cái'),
  ('203020703448', 'HP 107-BĂNG KEO GiẤY 1.6cm x 22y (18C/CÂY) (HP-0562)', 'Cái'),
  ('203020703425', 'HP BĂNG KEO 2 MẶT NƯỚC 2.4CM X 9Y (12C/C)(HP-0562)', 'Cái'),
  ('203020703352', 'HP BĂNG KEO OPP TRONG 45MIC 1.2CM x 80Y (24C/CÂY) (HP-0562)', 'Cái'),
  ('203020703607', 'HP - BANG KEO OPP MAU 45 MIC HPX 4.8CM X 70Y - VANG (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703447', 'HP BĂNG KEO GIAY 2.4CM X 22Y (12C/C)(HP-0562)', 'Cái'),
  ('203020703455', 'HP 114-BĂNG KEO SIMILI 2.4cm x 12Y (0562-HP)', 'Cái'),
  ('203020703428', 'HP 87-BĂNG KEO 2 MẶT NƯỚC 0.5cm x 9y (50C/CÂY) (HP-0562)', 'Cái'),
  ('203020703481', 'HP 140-BĂNG KEO HÀNG DỄ VỠ (T.ANH + T.VIỆT) 48mm x 100Ya (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703465', 'HP 124-BĂNG KEO ĐIỆN NHỎ 10YA (10C/CÂY) (HP-0562)', 'Cái'),
  ('203020703424', 'HP BĂNG KEO 2 MẶT NƯỚC 4.8CM X 9Y (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703426', 'HP BĂNG KEO 2 MẶT NƯỚC 1.5CM X 9Y (20C/C)(HP-0562)', 'Cái'),
  ('203020703446', 'HP 105-BĂNG KEO GiẤY 4.8cm x 22y (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703483', 'BĂNG KEO OPP TRONG 43MIC 4.8CM X 100Y (0562-HP)', 'Cái'),
  ('203020703401', 'HP 60-BĂNG KEO OPP ĐỤC 40MIC 4.8CM x 80Y (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703421', 'HP 80-BĂNG KEO OPP VPP 1.8cm x 25Y (10C/CÂY) (0562-HP)', 'Cái'),
  ('203020703422', 'HP BĂNG KEO OPP VPP 1.2CM X 25Y (10C/CÂY) (HP-0562)', 'Cái'),
  ('203020703423', 'HP BĂNG KEO OPP VPP 1.8CM X 17Y (10C/CÂY) (HP-0562)', 'Cái'),
  ('203020703453', 'HP 112-BĂNG KEO SIMILI 3.6cm x 12Y(8C/CÂY) (HP-0562)', 'Cái'),
  ('203020703480', 'HP 139-DÁN NỀN SỌC ĐỎ TRẮNG 48mm x 20m (0562-HP)', 'Cái'),
  ('203020703482', 'BĂNG KEO SIMILI 7CM x 12Y (4C/CÂY) (HP-0562)', 'Cái'),
  ('203020703369', 'HP 28-BĂNG KEO OPP  ĐỤC 45MIC 4.8CM X 100Y (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703358', 'HP 17-BĂNG KEO OPP TRONG 45MIC 4.8CM X 100Y (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703475', 'HP 134-BĂNG KEO VẢI MÈO 4.8cm x 15y (6C/CÂY) (HP-0562)', 'Cái'),
  ('203020703443', 'HP 102-BĂNG KEO 2 MẶT DẦU TRẮNG 4.8cm x 23Y (0562-HP)', 'Cái'),
  ('203020703479', 'HP 138-DÁN NỀN SỌC VÀNG ĐEN 4.8cm x 33M (0562-HP)', 'Cái'),
  ('201990002205', 'SL 331-VÒNG HOA ĐÀO NƠ HỒNG 33CM (STELLA)', 'Cái'),
  ('201049901923', 'SL 319-DÂY TREO ĐỒNG TIỀN KHOÉT NHỎ DT-DTK-22 (STELLA)', 'Cái'),
  ('201049901906', 'SL 302-DÂY CÁ CHÉP ĐƠN DCCĐ-30 (STELLA)', 'Cái'),
  ('201049901907', 'SL 303-DÂY LIỄN PHÁO DLP-30 (STELLA)', 'Cái'),
  ('201049901908', 'SL 304-DÂY LIỄN PHÁO DLP-40 (STELLA)', 'Cái'),
  ('201049901913', 'SL 309-LIỄN HOA VĂN CMNM  LGHV-60 (STELLA)', 'Cái'),
  ('201049901919', 'SL 315-DÂY TREO LỒNG ĐÈN DÀI DTN-LD-17 B 10 (STELLA)', 'Cái'),
  ('201049901922', 'SL 318-DÂY TREO BÔNG MAI NHỎ B 5 (STELLA)', 'Cái'),
  ('201049901925', 'SL 321-DÂY LIỄN LỒNG ĐÈN KHOÉT NHỎ DT-LĐK-25 B 5 (STELLA)', 'Cái'),
  ('201049902146', 'DÂY CÁ CHÉP ĐƠN 40 (STELLA)', 'Cái'),
  ('201049902148', 'DÂY TREO ĐỒNG TIỀN KHOÉT LỚN (STELLA)', 'Cái'),
  ('201990001956', 'DÂY PHÁO LỚN (0517-STELL)', 'Cái'),
  ('201990001966', 'MÚT DẺO HOA MAI 1 (0517-STELL)', 'Cái'),
  ('201990002206', 'SL 332-VÒNG ĐÀO THẦN TÀI 33CM (STELLA)', 'Cái'),
  ('201990002658', 'SET 6 QUẠT GIẤY ĐỎ (STELLA)', 'Cái'),
  ('204029901797', 'CÀNH HOA ĐÀO (STELLA)', 'Cái'),
  ('204029901773', 'CÀNH HOA HỒNG (STELLA)', 'Cái'),
  ('204029901788', 'CÀNH ĐÀO ĐÔNG 6 NHÁNH (STELLA)', 'Cái'),
  ('204029901789', 'CÀNH ĐÀO ĐÔNG 12 NHÁNH (STELLA)', 'Cái'),
  ('204029901795', 'CÀNH LÁ DƯƠNG XỈ NHŨ (STELLA)', 'Cái'),
  ('204029901798', 'CÀNH HOA MAI (STELLA)', 'Cái'),
  ('692173493574', 'BÚT GEL BẤM 0.5 MM MÀU ĐEN EG118-BK HỘP 12 (0639-DELI)', 'Cái'),
  ('893500181659', 'BÚT LÔNG KIM TÍM FL-04 (10C/H) (5404-TL)', 'Cái'),
  ('893532403493', 'BÚT GEL BI GELB-018 MỰC XANH 4 MÀU CÁN HỘP 20 CÂY (5404-TL)', 'Cái'),
  ('693520539030', 'RUỘT CHÌ KIM S483 48C/HỘP (0639-DELI)', 'Cái'),
  ('694223365928', 'BÚT CHÌ KIM SẮT 0.7MM EU501-07 (24C/H) (0639-DELI)', 'Cái'),
  ('692173490522', 'CHUỐT CHÌ LẬT ĐẬT 522 (12 (C/H) (0639-DELI)', 'Cái'),
  ('693520530738', 'CHUỐT CHÌ MINI NHỎ ER00200 (36C/H) (0639-DELI)', 'Cái'),
  ('694223360851', 'BÚT GEL 0.5MM MÀU XANH  EG057-BL (12C/H)(0639-DELI)', 'Cái'),
  ('694223367418', 'BÚT GEL BẤM SIÊU TRƠN 0.5 XANH EG575-BL(12C/H) (0639-DELI)', 'Cái'),
  ('693520530624', 'TẨY HÌNH HOẠT HÌNH LOẠI NHỎ EH01200(45C/H) (0639-DELI)', 'Cái'),
  ('693520533685', 'CHUỐT CHÌ MINI - HÌNH CON HEO E0557 DELI (1/12/480) (0639-DELI)', 'Cái'),
  ('692173495360', 'COMPA SẮT CHÌ KIM G20302 (12C/H) (0639-DELI)', 'Cái'),
  ('693520539028', 'RUỘT CHÌ KIM S482 (48C/H) (0639-DELI)', 'Cái'),
  ('692173497416', 'BÚT GEL 0.5MM EG118-BR MÀU NÂU (12C/H) (0639-DELI)', 'Cái'),
  ('694223360847', 'BÚT GEL 0.5MM MÀU ĐEN EG057-BK (12C/H)(0639-DELI)', 'Cái'),
  ('694223363037', 'BÚT GEL VĂN PHÒNG 0.5MM ĐEN S05(12C/H) (0639-DELI)', 'Cái'),
  ('693520530145', 'BÚT CHÌ KIM 0.5MM MÀU LẪN EU999 (36C/H) (0639-DELI)', 'Cái'),
  ('692173493589', 'BÚT GEL 0.5MM EG118-RD MÀU ĐỎ (12C/H) (0639-DELI)', 'Cái'),
  ('694223365724', 'BÚT GEL BẤM NGÒI 0.5MM MÀU ĐỎ EG057-RD (12C/H)(0639-DELI)', 'Cái'),
  ('697477620400', 'BÚT CHÌ 2B ONE PIECE EC021-2B DELI (1/12/144/2880) (0639-DELI)', 'Cái'),
  ('693267372548', 'BÚT GEL BẤM 0.5MM MÀU NÂU TRẦM EG118-LR (12C/H)(0639-DELI)', 'Cái'),
  ('694223366281', 'BÚT GEL BẤM SIÊU TRƠN 0.5MM XANH EG05-BL (12C/H)(0639-DELI)', 'Cái'),
  ('201099902232', 'KM-Bút sáp 12M (MIC)', 'Cái'),
  ('200060100235', 'BỘ THỰC HÀNH TOÁN LỚP 2(4631-ĐT)', 'Cái'),
  ('200060100238', 'BỘ THỰC HÀNH TOÁN LỚP 5(4631-ĐT)', 'Cái'),
  ('207080003390', 'BỘ THỰC HÀNH TOÁN LỚP 3(2PHẦN/BỘ)2022(A4631)', 'Cái'),
  ('201990001953', 'VÒNG HOA ĐÀO ĐỎ (0517-STELL)', 'Cái'),
  ('201990001955', 'VÒNG HOA ĐÀO ĐÔNG NHÁNH VÀNG (0517-STELL)', 'Cái'),
  ('201990002213', 'SL 339-VÒNG SAO HOA TẾT 30CM (STELLA)', 'Cái'),
  ('201990002222', 'SL 348-DECAL RÈM LIỄN TREO (STELLA)', 'Cái'),
  ('201990001962', 'QUẢ CẦU MAI B/6 (0517-STELL)', 'Cái'),
  ('201990001961', 'DƯA HẤU XỐP (0517-STELL)', 'Cái'),
  ('697350400085', 'BÚT GEL 0.5 MM MÀU XANH EG16-BL (12C/H)(0639-BN)', 'Cái'),
  ('201990001573', 'BBVL 75-NÓN BẢO HỘ CHỐNG BỤI (KODOROS) (BBVL0002)', 'Cái'),
  ('201049901738', 'SL 78-LIỄN GỖ PHÚC LỘC TÀI  (0517-STELL)', 'Cái'),
  ('201049901736', 'SL 76-LIỄN TREO NHỎ 3 (0517-STELL)', 'Cái'),
  ('201049901737', 'SL 77-LIỄN TREO NHỎ 4 (0517-STELL)', 'Cái'),
  ('201049901915', 'SL 311-DÂY TỨ QUÝ CÁ NHUNG NỔI (STELLA)', 'Cái'),
  ('201049901916', 'SL 312-DÂY TREO LIỄN XIN VÀNG DTLXV-20 B 5(STELLA)', 'Cái'),
  ('201049901917', 'SL 313-DÂY TREO LIỄN XIN VÀNG DTLXV-25 B 5 (STELLA)', 'Cái'),
  ('201049901920', 'SL 316-DÂY TREO LỒNG ĐÈN DÀI DTN-LD-20 B 5 (STELLA)', 'Cái'),
  ('201049901921', 'SL 317-DÂY TREO THỎI VÀNG NHỎ B 10 (STELLA)', 'Cái'),
  ('201049901942', 'SL 362-DÂY TREO LIỄN THOI VÀNG 25CM B 5 (STELLA)', 'Cái'),
  ('201990001957', 'DÂY TREO THỎI VÀNG (CO LO) (0517-STELL)', 'Cái'),
  ('201990002221', 'SL 347-DECAL THẦN TÀI 2 (STELLA)', 'Cái'),
  ('201990002225', 'SL 351-DECAL CÀNH ĐÀO ĐỎ (STELLA)', 'Cái'),
  ('201990002229', 'SL 355-DECAL TẾT 04 (STELLA)', 'Cái'),
  ('201990001945', 'DÂY HOA VẢI 6M/20LED-HỒNG ĐẬM (0477-TH)', 'Cái'),
  ('201029900978', 'BAO LÌ XÌ SÀI GÒN 3M VUÔNG (6C/XẤP) (DTT)', 'Cái'),
  ('201990002030', 'DÂY CUỘN BÓ THÉP', 'Cái'),
  ('201029900933', 'LÌ XÌ 181 (M.B.MINH)', 'Cái'),
  ('203190700179', 'DÂY TREO 6804 (0279-HQ)', 'Cái'),
  ('203190700183', 'ĐỎ TREO 100028 (0279-HQ)', 'Cái'),
  ('203190700186', 'DÂY TREO ĐỦ MẪU 6008 (0279-HQ)', 'Cái'),
  ('202010901855', 'CHUỖI BI TRÒN 10M/100 BÓNG VÀNG CÓ ĐẦU NỐI (T.HÀ)', 'Cái'),
  ('201049901930', 'SL 326-DÂY TREO 2022 18CM B 5 (STELLA)', 'Cái'),
  ('201049901931', 'SL 327-DÂY TREO 2022 20CM B 4 (STELLA)', 'Cái'),
  ('201990002651', 'CHỮ DECAL PHÁT LỚN (STELLA)', 'Cái'),
  ('201990002654', 'CHỮ DECAL LỘC LỚN (STELLA)', 'Cái'),
  ('201990002657', 'CHỮ DECAL TÀI LỚN (STELLA)', 'Cái'),
  ('202010905057', 'LỒNG ĐÈN TRE CON THỎ CÓ ĐÈN (STELLA)', 'Cái'),
  ('201990002486', 'DA3-GĂNG TAY CAO SU SIZE L', 'Cái'),
  ('201990002523', 'DA3-BAO RÁC 3 CUỘN - TRUNG', 'Cái'),
  ('201990002524', 'DA3-BAO RÁC 3 CUỘN - ĐẠI', 'Cái'),
  ('885241345941', 'GIẤY PHOTO IDEA WORK 80GSM KHỔ A3', 'Cái'),
  ('204029900986', 'GIẤY BÌA MÀU A3 (100 TỜ/XẤP)', 'Cái'),
  ('885241391754', 'GIẤY A4 SUPREME ĐL 70(T.NGOC)', 'Cái'),
  ('201049901742', 'SL 86-LIỄN TRUNG THOI VÀNG ĐỎ (0517-STELL)', 'Cái'),
  ('201049901744', 'SL 88-LIỄN TRUNG THOI ĐỎ (0517-STELL)', 'Cái'),
  ('201049901909', 'SL 305-DÂY LIỄN PHÁO DLP-50 (STELLA)', 'Cái'),
  ('201049901911', 'SL 307-LIỄN HOA VĂN CMNM  LGHV-40 (STELLA)', 'Cái'),
  ('201990001954', 'MẸT HOA CHÚC TẾT (0517-STELL)', 'Cái'),
  ('201990002207', 'SL 333-VÒNG GIẢ MÂY LỰU ĐỎ 33CM (STELLA)', 'Cái'),
  ('201990002210', 'SL 336-KHUNG VUÔNG ĐÀO LỰU 30CM (STELLA)', 'Cái'),
  ('201990002212', 'SL 338-VÒNG LỰU ĐÀO ĐÔNG LÁ VÀNG NƠ 35CM (STELLA)', 'Cái'),
  ('204029901790', 'CÀNH ĐỒNG TIỀN 3 NHÁNH (STELLA)', 'Cái'),
  ('204029901779', 'CÀNH HOA CHỒN XỐP (STELLA)', 'Cái'),
  ('204029901786', 'CÀNH HOA TRÀ GẠO XỐP (STELLA)', 'Cái'),
  ('204029901774', 'CÀNH HỒNG KHÔNG LÁ (STELLA)', 'Cái'),
  ('204029901775', 'CÀNH HOA TULIP 1 BÔNG (STELLA)', 'Cái'),
  ('204029901776', 'CÀNH HOA TULIP 3 BÔNG (STELLA)', 'Cái'),
  ('204029901778', 'CÀNH HOA CÁT TƯỜNG (STELLA)', 'Cái'),
  ('204029901785', 'CÀNH LÚA NHỰA (STELLA)', 'Cái'),
  ('204029901792', 'CÀNH LÁ QUẠT NHŨ (STELLA)', 'Cái'),
  ('204029901793', 'CÀNH LÁ TÁO NHŨ (STELLA)', 'Cái'),
  ('204029901794', 'CÀNH LÁ CỌ NHŨ (STELLA)', 'Cái'),
  ('204029901799', 'CÀNH LỰU NHỎ (STELLA)', 'Cái'),
  ('204029901342', 'MD-CÀNH HOA CÚC HỌA MI (N.DECOR)', 'Cái'),
  ('204029901768', 'CÀNH TRÁI CÂY NHỎ (CHANH/ CHERRY/ ĐÀO) (STELLA)', 'Cái'),
  ('204029901769', 'CÀNH TRÁI CÂY TO (CHANH/ CHERRY/ ĐÀO) (STELLA)', 'Cái'),
  ('204029901770', 'CÀNH HOA DIÊN VĨ (STELLA)', 'Cái'),
  ('204029901771', 'CÀNH ANH ĐÀO CHÙM (STELLA)', 'Cái'),
  ('204029901777', 'CÀNH TÁO SU 5 NHÁNH (STELLA)', 'Cái'),
  ('204029901781', 'CÚC TỔ ÔNG (STELLA)', 'Cái'),
  ('204029901782', 'CÀNH ĐÀO RÂU (STELLA)', 'Cái'),
  ('204029901783', 'CÀNH ĐIỂM HOA (STELLA)', 'Cái'),
  ('204029901784', 'CÀNH HOA TRÀ TỈ MUỘI (STELLA)', 'Cái'),
  ('204029901787', 'CÀNH HOA LAVENDER NHỰA (STELLA)', 'Cái'),
  ('204029901791', 'CÀNH ĐUÔI CÔNG NHỦ (STELLA)', 'Cái'),
  ('201990002188', 'MD-CÀNH LỰU TRÁI NHỎ ĐỎ (KAVAL)', 'Cái'),
  ('201049901895', 'SL 291-LIỄN LIỀN 1M (STELLA)', 'Cái'),
  ('201049901896', 'SL 292-LIỄN HÌNH THOI LỚN  (STELLA)', 'Cái'),
  ('201049901901', 'SL 297-DÂY TREO THẦN TÀI DTT-40 (STELLA)', 'Cái'),
  ('201049901902', 'SL 298-DÂY TREO THẦN TÀI DTT-50 (STELLA)', 'Cái'),
  ('201049901903', 'SL 299-DÂY LIỄN CÁ CHÉP LCC-20 (STELLA)', 'Cái'),
  ('201049901904', 'SL 300-DÂY LIỄN CÁ CHÉP LCC-30 (STELLA)', 'Cái'),
  ('201049901912', 'SL 308-LIỄN HOA VĂN CMNM  LGHV-50 (STELLA)', 'Cái'),
  ('201049901924', 'SL 320-DÂY TREO CÁT TƯỜNG NHỎ B 5 (STELLA)', 'Cái'),
  ('201049901926', 'SL 322-DÂY LIỄN LỒNG ĐÈN KHOÉT NHỎ DT-LĐK-30 B 5 (STELLA)', 'Cái'),
  ('201049901932', 'SL 328-DÂY  TREO TỨ QUÝ B 5 (STELLA)', 'Cái'),
  ('201049901941', 'SL 361-DÂY TREO LIỄN THOI VÀNG 20CM B 5 (STELLA)', 'Cái'),
  ('201990002233', 'SL 359-LỒNG ĐÈN NILON CHỮ PHÚC 20CM SET 5 (STELLA)', 'Cái'),
  ('201990002204', 'SL 330-VÒNG LÚA MÌ QUẾ CAM 32CM (STELLA)', 'Cái'),
  ('201990002208', 'SL 334-BẢNG GỖ HOA ĐÀO 30*70CM (STELLA)', 'Cái'),
  ('201990002650', 'CHỮ DECAL PHÁT TRUNG (STELLA)', 'Cái'),
  ('201990001939', 'DÂY LÔNG ĐÈN ĐỎ 5M/20LED-TA (0477-TH)', 'Cái'),
  ('201990001943', 'DÂY CẦU BÓNG 5M/20LED-VÀNG (0477-TH)', 'Cái'),
  ('201990002567', 'TH 141-DÂY NOEL-XANH DƯƠNG-10M-100LED-NHẤP NHÁY (T.HÀ)', 'Cái'),
  ('201049902141', 'LIỄN ĐỒNG TIỀN 15 (STELLA)', 'Cái'),
  ('201049902147', 'DÂY TREO THỎI VÀNG LỚN (STELLA)', 'Cái'),
  ('201990002649', 'CHỮ DECAL PHÁT NHÒ (STELLA)', 'Cái'),
  ('201990002652', 'CHỮ DECAL LỘC NHÒ (STELLA)', 'Cái'),
  ('201990002653', 'CHỮ DECAL LỘC TRUNG (STELLA)', 'Cái'),
  ('201990002655', 'CHỮ DECAL TÀI NHÒ (STELLA)', 'Cái'),
  ('201990002656', 'CHỮ DECAL TÀI TRUNG (STELLA)', 'Cái'),
  ('201049901734', 'SL 74-LIỄN TREO NHỎ 1 B/2 (0517-STELL)', 'Cái'),
  ('201049901735', 'SL 75-LIỄN TREO NHỎ 2 (0517-STELL)', 'Cái'),
  ('201049901897', 'SL 293-LIỄN ĐỒNG TIỀN ĐƠN  LĐTĐ-15 (STELLA)', 'Cái'),
  ('201049902149', 'DÂY THẺ BÀI NHỎ (STELLA)', 'Cái'),
  ('201990001980', 'HOA MAI VẢI NỈ B/3 (0517-STELL)', 'Cái'),
  ('201990001982', 'HOA MAI VẢI NỈ (0517-STELL)', 'Cái'),
  ('201990002218', 'SL 344-MÚT DẺO HOA ĐÀO KHOÉT B 3 (STELLA)', 'Cái'),
  ('201990002219', 'SL 345-MÚT DẺO HOA ĐÀO 3 LỚP 10CM B 2 (STELLA)', 'Cái'),
  ('201990002228', 'SL 354-DEACAL TẾT 03 (STELLA)', 'Cái'),
  ('203190601119', 'CHUÔNG CHỮ MTL212F (0025-ABM)', 'Cái'),
  ('201990002186', 'MD-HOA TULIP (KAVAL)', 'Cái'),
  ('201990001952', 'VÒNG HOA ĐÀO (0517-STELL)', 'Cái'),
  ('202010903293', 'SL 179-VỚ BỐ LỚN (0517-STELL)', 'Cái'),
  ('204029901800', 'CÀNH LỰU LỚN 6 NHÁNH (STELLA)', 'Cái'),
  ('201990002203', 'SL 329-VÒNG ĐÀO TRÁI BÔNG 32CM (STELLA)', 'Cái'),
  ('201990002641', 'KHUNG TRÒN ĐÀO XỊN (STELLA)', 'Cái'),
  ('201990002644', 'KHUNG LỤC GIÁC TRÁI CÂY (STELLA)', 'Cái'),
  ('201990002645', 'KHUNG TRÒN CHUỒN CHUỒN (STELLA)', 'Cái'),
  ('201990002647', 'VÒNG HOA ĐÀO ĐÔNG NƠ (STELLA)', 'Cái'),
  ('893500181665', 'BÚT LÔNG KIM TÍM FL-04/DO (10C/H) (5404-TL)', 'Cái'),
  ('885874172416', 'DOUBLE A - BÚT DẠ QUANG MÀU DỊU DOUBLE A (12C/H) - XANH DƯƠNG (VT)', 'Cái'),
  ('885874172419', 'DOUBLE A - BÚT DẠ QUANG MÀU DỊU DOUBLE A (12C/H) - XANH LÁ (VT)', 'Cái'),
  ('454944100208', 'ARTLINE-VIẾT LÔNG KIM,ĐỎ,0.4MM  VEPFS-200RD(4953-PM)', 'Cái'),
  ('454944100210', 'ARTLINE-VIẾT LÔNG KIM,LỤC,0.4MM  VEPFS-200GR(4953-PM)', 'Cái'),
  ('454944100211', 'ARTLINE-VIẾT LÔNG KIM,CAM,0.4MM  VEPFS-200OR(4953-PM)', 'Cái'),
  ('454944100212', 'ARTLINE-VIẾT LÔNG KIM,VÀNG,0.4MM  VEPFS-200YE(4953-PM)', 'Cái'),
  ('454944100217', 'ARTLINE-VIẾT LÔNG KIM,XANH DA TROI,0.  VEPFS-200SBL(4953-PM)', 'Cái'),
  ('454944100218', 'ARTLINE-VIẾT LÔNG KIM,VÀNG CHANH,0.4M  VEPFS-200YGR(4953-PM)', 'Cái'),
  ('454944100220', 'ARTLINE-VIẾT LÔNG KIM,XÁM,0.4MM  VEPFS-200GRE(4953-PM)', 'Cái'),
  ('454944100221', 'ARTLINE-VIẾT LÔNG KIM, MÀU MO,0.4MM  VEPFS-200APR(4953-PM)', 'Cái'),
  ('454944100224', 'ARTLINE-VIẾT LÔNG KIM,XANH LAM,0.4MM  VEPFS-200RBL(4953-PM)', 'Cái'),
  ('454944100225', 'ARTLINE-VIẾT LÔNG KIM,XANH NGỌC,0.4MM  VEPFS-200TUR(4953-PM)', 'Cái'),
  ('454944100320', 'ARTLINE - VIẾT BI ARTLINE, MÀU ĐỎ, 0.7MM EGB-SG1 RD(12C/H)(4953-PM)', 'Cái'),
  ('454944102145', 'VIẾT BI GEL ARTLINE J-POP EGB-S260 FYE, VÀNG SÁNG, 0.5MM (PM-4953)', 'Cái'),
  ('497405283105', 'ARTLINE-VIẾT LÔNG KIM EK-220OR CAM(4953-PM)', 'Cái'),
  ('497405283107', 'ARTLINE-VIẾT LÔNG KIM EK-220YE VÀNG(4953-PM)', 'Cái'),
  ('497405284851', 'ARTLINE-EK-841T RED VIẾT TRÊN CD/DVD (H/12) (4953-PM)', 'Cái'),
  ('497405285263', 'ARTLINE - VIẾT VẼ KỸ THUẬT ARTLINE EK-237, ĐỎ, NGÒI 0.7MM(A4903-PM)', 'Cái'),
  ('497405286278', 'ARTLINE-VIẾT LÔNG KIM 0.5MM ,XANH EXT-200BL(4953-PM)', 'Cái'),
  ('893500180515', 'BÚT BI ĐỎ TL-095 (20C/H) (5404-TL)', 'Cái'),
  ('893500185345', 'BÚT GEL ĐEN 08 NEW (20C/H) (5404-TL)', 'Cái'),
  ('2600018232', 'KEO ELMER''S TRONG XANH LA 147ML-2022913 (3 CHAI HOP) (A5404-TL)', 'Cái'),
  ('489515154096', 'KEO ELMER''S K.TUYEN177ML XANH DƯƠNG -2106670 (6C/H) (5404-TL)', 'Cái'),
  ('489515154097', '(KSD BO MAU) KEO ELMER''S K.TUYEN 177ML VÀNG -2106671 (6C/H) (5404-TL)', 'Cái'),
  ('893500181476', 'BÚT DẠ QUANG VÀNG HL-07 (10C/H) (5404-TL)', 'Cái'),
  ('893500182777', 'BÚT MÁY TP-FTC09 ỐNG MỰC TÍM (5404-TL)', 'Cái'),
  ('893500183034', 'MỰC BÚT MÁY XANH FPI-07 (6H/L) (5404-TL)', 'Cái'),
  ('893500183146', 'MUC BUT LONG DAU PMI-01 DO(6C L)(A5404)', 'Cái'),
  ('893500183802', 'BÚT NHIỀU NGÒI BIZ-11 VỈ 01 (5404-TL)', 'Cái'),
  ('893521948100', 'KẸP GIẤY 25MM FO-PAC01 (10C/H) (5404-TL)', 'Cái'),
  ('893521948302', 'LƯỠI DAO RỌC GIẤY 9MM FO-BL01 (50C/H) (5404-TL)', 'Cái'),
  ('893521948303', 'LƯỠI DAO RỌC GIẤY 18MM FO-BL02 (20C/H) (5404-TL)', 'Cái'),
  ('454944100002', 'ARTLINE-VIẾT DẠ QUANG STIX, 1.0 -4.0 MM, VÀNG VETX-600FYE(4953-PM)', 'Cái'),
  ('489515155028', 'KEO ELMER''S ĐỔI MÀU 147ML VÀNG -2119219 (3C/H) (5404-TL)', 'Cái'),
  ('893532402952', 'BÚT LÔNG DẦU PM-019/HS XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893500180389', 'BÚT BI XANH TL-079 VỈ 5 (5404-TL)', 'Cái'),
  ('893500180504', 'BÚT BI ĐEN TL-089 (20C/H) (5404-TL)', 'Cái'),
  ('893500185274', 'BÚT GEL XANH B011 (20C/H) (5404-TL)', 'Cái'),
  ('893500188213', 'BÚT BI XANH FO-024/VN VỈ 3 CÂY (5404-TL)', 'Cái'),
  ('893532400320', 'BÚT GEL GEL-033 XANH (10C/H) TL (5404-TL)', 'Cái'),
  ('893532401545', 'BÚT LÔNG BẢNG WB-03 PLUS XANH (12C/H) (5404-TL)', 'Cái'),
  ('893532402207', 'BÚT GEL GEL-033/DS LÁ - M.XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532402828', 'BÚT GEL GEL-049/HS XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532404675', 'BÚT GEL GEL-057/DS XANH - MỰC XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532404676', 'BÚT GEL GEL-057/DS VÀNG - MỰC XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893500182229', 'VIẾT CHÌ GỖ GP-01 (10C/H) (5404-TL)', 'Cái'),
  ('893500185789', 'BUT GELTP-GELE002 TIM HOP 20  XOA DUOC(A5404-TL)', 'Cái'),
  ('893500185324', 'BÚT GEL ĐỎ B011 (20C/H) (5404-TL)', 'Cái'),
  ('893500181227', 'BÚT LÔNG KIM XANH FL-04/DO (10C/H) (5404-TL)', 'Cái'),
  ('893500180511', 'BÚT BI ĐỎ TL-093 (20C/H) (5404-TL)', 'Cái'),
  ('893500180512', 'BÚT BI ĐEN TL-093 (20C/H) (5404-TL)', 'Cái'),
  ('893500180516', 'BÚT BI ĐEN TL-095 (20C/H) (5404-TL)', 'Cái'),
  ('893500180519', 'BÚT BI ĐỎ TL-097 (20C/H) (5404-TL)', 'Cái'),
  ('893500181326', 'BÚT LÔNG BẢNG XANH WB-016/DO (10C/H) (5404-TL)', 'Cái'),
  ('893500185016', 'BÚT GEL XANH B01 (10C/H) (5404-TL)', 'Cái'),
  ('893500185340', 'BÚT GEL TÍM GEL-07 (20C/H) (5404-TL)', 'Cái'),
  ('893500186179', 'BÚT GEL XANH XÓA ĐƯỢC TP-GELE003 (20C/H) (5404-TL)', 'Cái'),
  ('893500186694', 'BÚT GEL TP-GEL039 TÍM (20C/H) (A5404-TL)', 'Cái'),
  ('893500180450', 'BÚT BI ĐỎ TL-08 (20C/H) (5404-TL)', 'Cái'),
  ('893500180292', 'BÚT BI TL-047 XANH 20C/H (5404-TL)', 'Cái'),
  ('893500180133', 'BÚT BI XANH TL-031 (20C/H) (5404-TL)', 'Cái'),
  ('893500180411', 'BÚT BI XANH TL-097 (20C/H) (5404-TL)', 'Cái'),
  ('893500181454', 'BÚT LÔNG DẦU ĐỎ PM-04 (10C/H) (5404-TL)', 'Cái'),
  ('893500187908', 'BÚT BI 0.5 XANH CALINA FO-030/VN (10C/H) (5404-TL)', 'Cái'),
  ('893500188111', 'BÚT BI XANH STARTUP FO-039/VN (20C/H) (5404-TL)', 'Cái'),
  ('893532403641', 'BÚT GEL GEL-056 XANH HỘP 20 (5404-TL)', 'Cái'),
  ('893500187871', 'BÚT BI XANH FO-024/VN (20C/H) (5404-TL)', 'Cái'),
  ('888706620620', 'MỰC DẤU - SQ-2062', 'Cái'),
  ('204059900513', 'BAO THƯ 12X22CM KHÔNG KEO 80GSM', 'Cái'),
  ('203020501324', 'MỰC DẤU SHINY', 'Cái'),
  ('893532401309', 'BÚT GEL XÓA ĐƯỢC GELE-008 XANH HỘP 20 (5404-TL)', 'Cái'),
  ('893500182443', 'BÚT NHỰA MÀU COLOKIT PCR-C09 24 MÀU/KM (5404-TL)', 'Cái'),
  ('893532401499', 'BÚT LÔNG MÀU ACRYLIC 1Đ ACM-C003 12 MÀU (5404-TL)', 'Cái'),
  ('893500186181', 'BÚT LÔNG MÀU RỬA ĐƯỢC SWM-C006 36 MÀU (5404-TL)', 'Cái'),
  ('893500184938', 'MÀU NƯỚC WACO-C09 14 MÀU (5404-TL)', 'Cái'),
  ('893500187883', 'MÀU NƯỚC WACO-C07 12 MÀU (5404-TL)', 'Cái'),
  ('893500183538', 'KÉO VĂN PHÒNG SC-021 (10C/H) (5404-TL)', 'Cái'),
  ('893500183544', 'KÉO ĐA NĂNG SC-020 (10C/H) (5404-TL)', 'Cái'),
  ('893521948007', 'BẤM KIM SỐ 10 FO-ST02 (12C/H) (5404-TL)', 'Cái'),
  ('893521948022', 'BỘ BẤM KIM SỐ 10 FO-ST02-S2 (10C/H) (5404-TL)', 'Cái'),
  ('893521948026', 'BỘ BẤM KIM SỐ 10 FO-ST03-S2 (10C/H) (5404-TL)', 'Cái'),
  ('893532401399', 'KẸP BƯỚM CTH 32MM DCL-011 (5404-TL)', 'Cái'),
  ('893521948005', 'KIM BẤM SỐ 10 FO-STS02(20/H) (5404-TL)', 'Cái'),
  ('893521948205', 'KẸP BƯỚM ĐEN 51MM FO-DC06 (12H/L) (5404-TL)', 'Cái'),
  ('893521948214', 'KẸP BƯỚM MÀU 15MM FO-DCC01(12H/L) (5404-TL)', 'Cái'),
  ('893521948215', 'KẸP BƯỚM MÀU 19MM FO-DCC02 (12H/L) (5404-TL)', 'Cái'),
  ('893532401272', 'BẤM KIM SỐ 10 ST-023 (12C/H) (5404-TL)', 'Cái'),
  ('893532402950', 'BÚT LÔNG BẢNG WB-025/HS XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532402827', 'BÚT GEL GEL-048/HS ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893500181398', 'BÚT LÔNG DẦU ĐỎ PM-09 (10C/H) (5404-TL)', 'Cái'),
  ('893500184231', 'KEO KHÔ G-011/ĐOREMON (30C/H) (A540-TL)', 'Cái'),
  ('893500187989', 'BÚT LÔNG DẦU ĐỦ MÀU (ĐEN,ĐỎ,XANH) FO-PM01/VN (5404-TL)', 'Cái'),
  ('893521946022', 'BÚT LÔNG DẦU XANH NGỌC SHARPIE FINE 30127 (12C/H) (5404-TL)', 'Cái'),
  ('893528390511', 'PHẤN TRẮNG KHÔNG BỤI TP-DC009 (A5404-TL)', 'Cái'),
  ('893532401547', 'BÚT LÔNG BẢNG WB-03 PLUS ĐEN (12C/H) (5404-TL)', 'Cái'),
  ('893532401909', 'KEO KHÔ TRẮNG G-026/AK (12C/H) (5404-TL)', 'Cái'),
  ('893532402901', 'BÚT LÔNG BẢNG WB-025/HS ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532402909', 'BÚT LÔNG DẦU PM-019/HS ĐỎ HỘP 10 (5404-TL)', 'Cái'),
  ('893532402915', 'BÚT LÔNG DẦU PM-021/HS ĐỎ HỘP 10 (5404-TL)', 'Cái'),
  ('893532402951', 'BÚT LÔNG BẢNG WB-025/HS ĐỎ HỘP 10 (5404-TL)', 'Cái'),
  ('893532403032', 'BÚT GEL GEL-046/HS XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532403033', 'BÚT GEL GEL-046/HS ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532403045', 'BÚT GEL GEL-047/HS ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532404278', 'BÚT LÔNG DẦU PM-023 XANH - ĐỎ HỘP 10 (5404-TL)', 'Cái'),
  ('893500181397', 'BÚT LÔNG DẦU XANH PM-09 (10C/H) (5404-TL)', 'Cái'),
  ('893532401546', 'BÚT LÔNG BẢNG WB-03 PLUS ĐỎ (12C/H) (5404-TL)', 'Cái'),
  ('893500183878', 'GIẤY THỦ CÔNG 12 MÀU KHỔ VỪA GTC-C002 (5404-TL)', 'Cái'),
  ('893500181399', 'BÚT LÔNG DẦU ĐEN PM-09 (10C/H) (5404-TL)', 'Cái'),
  ('893532402829', 'BÚT GEL GEL-049/HS ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('203000500278', 'BÌA 40 LÁ NHỰA A4 MÀU XANH', 'Cái'),
  ('203020800757', 'MUC DAU - SQ-2062', 'Cái'),
  ('893500184300', 'VỈ 2 CỤC GÔM E-06 (5404-TL)', 'Cái'),
  ('893500182427', 'BÚT XÓA TP-CP01 5ML (10C/H) (5404-TL)', 'Cái'),
  ('692173497506', 'MÁY ĐÓNG 6 SỐ', 'Cái'),
  ('893500181465', 'BÚT DẠ QUANG VÀNG HL-03 (10C/H) (5404-TL)', 'Cái'),
  ('893500180463', 'BÚT BI ĐEN TL-027', 'Cái'),
  ('893500180491', 'BÚT BI ĐỎ TL-079 (20C/H) (5404-TL)', 'Cái'),
  ('893500180492', 'BÚT BI ĐEN TL-079 (20C/H) (5404-TL)', 'Cái'),
  ('893532401503', 'BÚT LÔNG MÀU ACRYLIC 1Đ ACM-C004 24 MÀU (5404-TL)', 'Cái'),
  ('893532401540', 'BÚT LÔNG MÀU ACRYLIC 1Đ ACM-C005 36 MÀU (5404-TL)', 'Cái'),
  ('893532401542', 'BÚT LÔNG MÀU ACRYLIC 2Đ ACM-C006 36 MÀU (5404-TL)', 'Cái'),
  ('893500184785', 'BỘ KHUÔN SÁP NẶN MCT C03 16 MÓN (5404-TL)', 'Cái'),
  ('893532401891', 'TRANH TÔ MÀU NÉN KID CPA-C002 (5404-TL)', 'Cái'),
  ('893532402527', 'TÚI BÚT DEMON SLAYER PCA-022/DS HỒNG (5404-TL)', 'Cái'),
  ('893500184737', 'HỘP BÚT DORAEMON PCA - 011/DO (5404-TL)', 'Cái'),
  ('893532403553', 'CẶP CHỐNG GÙ AKOOLAND BP-022/AK DASI/T24 (5404-TL)', 'Cái'),
  ('893532403554', 'CẶP CHỐNG GÙ AKOOLAND BP-022/AK CICI/T24 (5404-TL)', 'Cái'),
  ('893532403603', 'BA LÔ STRIVE BP-030 /T24 (5404-TL)', 'Cái'),
  ('893532400350', 'BÚT LÔNG MÀU RỬA ĐƯỢC SWM-C009 20 MÀU COLOKIT (5404-TL)', 'Cái'),
  ('893532403454', 'BÚT LÔNG MÀU FP-C023 METALLIC 6 MÀU (5404-TL)', 'Cái'),
  ('893532403811', 'BÚT LÔNG MÀU FP-C020 HYGEE 24 MÀU(5404-TL)', 'Cái'),
  ('893532403456', 'BÚT LÔNG MÀU FP-C024 METALLIC 12 MÀU (5404-TL)', 'Cái'),
  ('893532403814', 'BÚT LÔNG MÀU FP-C019 HYGEE 12 MÀU(5404-TL)', 'Cái'),
  ('893532402496', 'BÚT LÔNG MÀU BẤM FP-C016 KAWAII 12 MÀU (5404-TL)', 'Cái'),
  ('893532402489', 'BÚT LÔNG MÀU BẤM FP-C013 6 MÀU (5404-TL)', 'Cái'),
  ('893532402491', 'BÚT LÔNG MÀU BẤM FP-C014 12 MÀU (5404-TL)', 'Cái'),
  ('893532402493', 'BÚT LÔNG MÀU BẤM FP-C015 KAWAII 6 MÀU (5404-TL)', 'Cái'),
  ('893532403809', 'BÚT LÔNG MÀU FP-C017 COTTON CANDY 12 MÀU(5404-TL)', 'Cái'),
  ('893532403819', 'BÚT LÔNG MÀU FP-C018COTTON CANDY 24 MÀU(5404-TL)', 'Cái'),
  ('893532403743', 'BÚT SƠN ACRYLIC MỰC LỎNG ACM-C012 24 MÀU (5404-TL)', 'Cái'),
  ('893532403879', 'BÚT LÔNG MÀU SIÊU SẠCH UWM-C002 24 MÀU (5404-TL)', 'Cái'),
  ('893500182289', 'VIẾT CHÌ 16 MÀU CP-C08 (5404-TL)', 'Cái'),
  ('489515154092', 'KEO ELMER''S K.TUYEN 177ML X.LÁ -2106666 (6C/H) (5404-TL)', 'Cái'),
  ('489515155067', 'KEO ELMER''S DẠ QUANG CAM 147ML-2120412 (3C/H) (A5404-TL)', 'Cái'),
  ('893600745894', 'POKEMON - EXAM HOLDER A5 (4 CÁI/XẤP/ 4 MÀU) 400-V001 (HV)', 'Cái'),
  ('893500180605', 'BÚT BI ĐỎ TL-025 VỈ 2 (5404-TL)', 'Cái'),
  ('893500181475', 'BÚT DẠ QUANG XANH LÁ HL-07 (10C/H) (5404-TL)', 'Cái'),
  ('893500182208', 'BÚT SÁP MÀU CR-C07 10 MÀU (5404-TL)', 'Cái'),
  ('893500184806', 'COMPA C-08 (20C/H) (5404-TL)', 'Cái'),
  ('893500185028', 'BÚT GEL XANH, ĐỎ, ĐEN GEL-07 (20C/H) (5404-TL)', 'Cái'),
  ('893528390229', 'THƯỚC THẲNG 30CM SR-031', 'Cái'),
  ('893528390570', 'MÀU NƯỚC WACO-C09 WHITE (5404-TL)', 'Cái'),
  ('893532400412', 'BÌA HỌC SINH 30 LÁ DB-002_TÍM HỒNG TL (5404-TL)', 'Cái'),
  ('893532401452', 'BÚT LÔNG BẢNG WB-022 ĐEN (12C/H) (5404-TL)', 'Cái'),
  ('893532401785', 'NHÃN VỞ NBL-006/AK (15C/X) (5404-TL)', 'Cái'),
  ('893604045395', 'THƯỚC THẲNG 15CM SR-027 (5404-TL)', 'Cái'),
  ('203040900004', 'GIẤY IN BILL MIMOSA - SUMIKURA KHỔ 75(0232-QHST)', 'Cái'),
  ('893500183045', 'VỞ VẼ A3 SKB-C02 (5404-TL)', 'Cái'),
  ('893500184485', 'BẢNG ĐEN HS B-08 (5404-TL)', 'Cái'),
  ('697310004451', 'DC NGẪU NHIÊN BLIND BOX KIMMON 12.5CM (SET/6C) (HT-0061)', 'Cái'),
  ('880220306389', 'VIẾT NƯỚC ĐÔNG-A OKTOKI60 ĐEN (0061-HT)', 'Cái'),
  ('893611749318', 'BẤM 2 LỖ', 'Cái'),
  ('893532403161', 'TÚI VẢI TOTE NỀN TRẮNG TB-001/DS XANH(5404-TL)', 'Cái'),
  ('893532403162', 'TÚI VẢI TOTE NỀN TRẮNG TB-001/DS HỒNG(5404-TL)', 'Cái'),
  ('893532404670', 'ỐNG CẮM BÚT VUÔNG PS-007/DS XANH LÁ (5404-TL)', 'Cái'),
  ('893532404671', 'ỐNG CẮM BÚT VUÔNG PS-007/DS HỒNG (5404-TL)', 'Cái'),
  ('893532404735', 'BÌA 30 LÁ A4 DB-012/DS TRẮNG (5404-TL)', 'Cái'),
  ('893611749312', 'KIM BẤM 23/13', 'Cái'),
  ('893611749310', 'KIM BẤM 23/8', 'Cái'),
  ('893611749311', 'KIM BẤM 23/10', 'Cái'),
  ('893851020505', 'KẸP BƯỚM ECHO 41MM', 'Cái'),
  ('471421800004', 'KIM BẤM 24/6', 'Cái'),
  ('893851020506', 'KẸP BƯỚM ECHO 51MM', 'Cái'),
  ('893500183668', 'BUT SAP VAN TCR-C008 DO 18 MAU (A5404-TL)', 'Cái'),
  ('893611749300', 'DẬP GHIM LỚN', 'Cái'),
  ('201049901889', 'VIẾT BI SCB TL-023 XANH', 'Cái'),
  ('893500185043', 'BÚT GEL XANH GEL-012 (20C/H) (5404-TL)', 'Cái'),
  ('497405285797', 'ARTLINE-VIẾT DẠ QUANG EK-670 FOR CAM NHẠT', 'Cái'),
  ('203010603670', '(KSD-BARCODE MÀU) BÚT GEL 018 (5404-TL)', 'Cái'),
  ('893532400016', 'BÚT GEL TP-GEL038 XANH VỈ 3 (A5404-TL)', 'Cái'),
  ('202990000991', 'DÂY THUN HIỆP THÀNH', 'Cái'),
  ('893532404103', 'BÚT LÔNG KIM FL-04 XANH /LUCK VỈ 3(5404-TL)', 'Cái'),
  ('893600745845', 'PLUS - GÔM NHỎ POKEMON WH 610-V002 (HV)', 'Cái'),
  ('893600745846', 'PLUS - GÔM NHỎ POKEMON BK 610-V001 (HV)', 'Cái'),
  ('893528390397', 'BANG HOC SINH MONDEE TP-B022 XANH-T50 (A5404-TL)', 'Cái'),
  ('893528390399', 'BANG HOC SINH MONDEE TP-B021 DEN-T50 (A5404-TL)', 'Cái'),
  ('201049901520', 'VIẾT BIC NHŨ G-STAR GLITTER ĐỦ MÀU (12C/H) (0061-HT)', 'Cái'),
  ('203020800810', 'DA07 - LƯỠI DAO SDI NHỎ', 'Cái'),
  ('202990001342', 'DÂY THUN LỢI LỢI - VÒNG NHỎ', 'Cái'),
  ('203020401648', 'KÉO K19', 'Cái'),
  ('497405285799', 'ARTLINE-VIẾT DẠ QUANG EK-670 FRD ĐỎ NHẠT', 'Cái'),
  ('893500184922', 'GIẤY KIỂM TRA KẺ NGANG TP-GKT05 (5404-TL)', 'Cái'),
  ('893612245557', 'VIẾT LÔNG 36 MÀU GSTAR CAO CẤP LM-706 (0061-HT)', 'Cái'),
  ('893600880036', 'THƯỚC 50CM T-50 (10C/H) (0489-QL)', 'Cái'),
  ('893607339052', 'THƯỚC PARABOL 4 QL-04 (10B/H) (0489-QL)', 'Cái'),
  ('893600880087', 'THƯỚC PARABOL 3 QL-03 (10B/H) (0489-QL)', 'Cái'),
  ('893600880028', 'THƯỚC BỘ TRẮNG T-160 (50B/H) (0489-QL)', 'Cái'),
  ('893500182441', 'BÚT SÁP MÀU 38 M CR-C038/CA (5404-TL)', 'Cái'),
  ('893500182446', 'BÚT SÁP MÀU 18M JUMBỘ CR-C035 (5404-TL)', 'Cái'),
  ('893500182447', 'BÚT SÁP MÀU 24 MÀU JUMBO CR-C036 (5404-TL)', 'Cái'),
  ('893532403742', 'BÚT SƠN ACRYLIC MỰC LỎNG ACM-C011 12 MÀU (5404-TL)', 'Cái'),
  ('893521945079', 'BÌA TRÌNH KÝ ĐƠN A4 PVC FO-CB02 XANH (5404-TL)', 'Cái'),
  ('893532403934', 'TÚI ĐỰNG TÀI LIỆU A4 CBF-005/AK LÁ T12 (5404-TL)', 'Cái'),
  ('893532403935', 'TÚI ĐỰNG TÀI LIỆU A4 CBF-005/AK HỒNG T12 (5404-TL)', 'Cái'),
  ('893532403937', 'TÚI ĐỰNG TÀI LIỆU A4 CBF-005/AK CAM (T12) (5404-TL)', 'Cái'),
  ('893532404469', 'BÌA NÚT A4 CBF-008/DS XANH LÁ (5404-TL)', 'Cái'),
  ('893532404730', 'BÌA NÚT A4 CBF-008/DS HỒNG (5404-TL)', 'Cái'),
  ('893532404731', 'BÌA NÚT A4 CBF-008/DS CAM (5404-TL)', 'Cái'),
  ('893532404732', 'BÌA NÚT A4 CBF-008/DS XANH BIỂN (5404-TL)', 'Cái'),
  ('893532404748', 'CẶP TÀI LIỆU 8 NGĂN A4 DF-006/DS TRẮNG (5404-TL)', 'Cái'),
  ('893604045185', 'BÌA TRÌNH KÝ KÉP A4 MÀU XANH PVC FO-CB01 (5404-TL)', 'Cái'),
  ('893500181478', 'BÚT DẠ QUANG HỒNG HL-07 (10C/H) (5404-TL)', 'Cái'),
  ('893521946060', 'CRAYOLA - BÚT LÔNG NÉT DÀY 12 MÀU - 587812 (T.LONG)', 'Cái'),
  ('893500182231', 'VIẾT CHÌ MÀU CP-C06 (5404-TL)', 'Cái'),
  ('893604045029', 'CHUỐT CHÌ TP-S016 (2C/VỈ) (5404-TL)', 'Cái'),
  ('893605001738', 'KINGJIM - BÌA 8 NGĂN CÓ DÂY CỘT RED 1737GSV (HV)', 'Cái'),
  ('893500180611', 'BÚT BI ĐỎ TL-027 VỈ 5 (5404-TL)', 'Cái'),
  ('893532400778', 'BĂNG KEO HÀNG DỄ VỠ FRAGILE BKD-001 50M/ XANH (5C/LỐC) (5404-TL)', 'Cái'),
  ('201049902666', 'DOUBLE A - VIẾT BI BLISS 0.7MM - ĐEN (VT)', 'Cái'),
  ('490199105350', 'TOMBOW VIẾT CHÌ GỖ HELLO NATURE, 2B ACF-354E(3C/V)(0376-TSVN)', 'Cái'),
  ('893500189835', 'BÚT CHÌ MÀU CPC-C021 24 MÀU (A5404-TL)', 'Cái'),
  ('893500182242', 'SÁP MÀU CRC016 (5404-TL)', 'Cái'),
  ('893500186591', 'BÚT LÔNG MỸ THUẬT AM-C002 12 MÀU(5404-TL)', 'Cái'),
  ('893500184632', 'MÀU NƯỚC 8 MÀU WACO-C06 (5404-TL)', 'Cái'),
  ('893532402523', 'BỘ DÂY ĐEO THẺ CHD-001/DS XANH TÚI 20 (5404-TL)', 'Cái'),
  ('893532402517', 'BỘ DÂY ĐEO THẺ CHD-001/DS CAM TÚI 20 (5404-TL)', 'Cái'),
  ('893532402518', 'BỘ DÂY ĐEO THẺ CHD-001/DS NÂU TÚI 20 (5404-TL)', 'Cái'),
  ('893532404764', 'BỘ DÂY ĐEO THẺ CHD-002/DS MITSURI TÚI 20 (5404-TL)', 'Cái'),
  ('893532404765', 'BỘ DÂY ĐEO THẺ CHD-002/DS GIYU TÚI 20 (5404-TL)', 'Cái'),
  ('893532404766', 'BỘ DÂY ĐEO THẺ CHD-002/DS SHINOBU -HỒNG TÚI 20 (5404-TL)', 'Cái'),
  ('893532404768', 'BỘ DÂY ĐEO THẺ CHD-002/DS MUICHIRO -XANH TÚI 20 (5404-TL)', 'Cái'),
  ('893500183147', 'MỰC BÚT LÔNG DẦU ĐEN PMI-01 (6C/L) (5404-TL)', 'Cái'),
  ('893500181392', 'BÚT LÔNG DẦU ĐỎ PM-07 (10C/H) (5404-TL)', 'Cái'),
  ('893500181464', 'BÚT DẠ QUANG XANH LÁ HL-03 (10C/H) (5404-TL)', 'Cái'),
  ('893500181487', 'BÚT DẠ QUANG VÀNG HL-012 (10C/H) (5404-TL)', 'Cái'),
  ('893500181488', 'BÚT DẠ QUANG CAM HL-012 (10C/H) (5404-TL)', 'Cái'),
  ('893500181489', 'BÚT DẠ QUANG HỒNG HL-012 (10C/H) (5404-TL)', 'Cái'),
  ('893500181531', 'BÚT LÔNG BẢNG ĐEN WB-02 (20C/H) (5404-TL)', 'Cái'),
  ('893500182286', 'VIẾT CHÌ GỖ BIZNER BIZ-P01 (10C/H) (5404-TL)', 'Cái'),
  ('893500182495', 'VIẾT CHÌ GỖ GP-C01 (5C/H) (5404-TL)', 'Cái'),
  ('893500182573', 'VIẾT CHÌ GỖ BIZ-P03 (10C/H) (A5404-TL)', 'Cái'),
  ('893500183142', 'MỰC BÚT LÔNG BẢNG ĐỎ WBI-01 (6C/L) (5404-TL)', 'Cái'),
  ('893500183143', 'MỰC BÚT BẢNG ĐEN WB101 (6C/L) (5404-TL)', 'Cái'),
  ('893528390074', 'VIẾT CHÌ BẤM PC-024 (10C/H) (5404-TL)', 'Cái'),
  ('893532401011', 'GÔM ĐIỆN TỰ ĐỘNG EE-001 HỒNG (A5404-TL)', 'Cái'),
  ('893532401016', 'GÔM ĐIỆN TỰ ĐỘNG EE-001 XANH (A5404-TL)', 'Cái'),
  ('893532401911', 'BÚT VẼ KỸ THUẬT 02 DW-C001 HỘP 12(5404-TL)', 'Cái'),
  ('893532401920', 'BÚT VẼ KỸ THUẬT 05 DW-C004 HỘP 12(5404-TL)', 'Cái'),
  ('893532402948', 'BÚT DẠ QUANG HL-018/HS BIỂN HỘP 10 (5404-TL)', 'Cái'),
  ('893532402949', 'BÚT DẠ QUANG HL-018/HS HỒNG HỘP 10 (5404-TL)', 'Cái'),
  ('893532404104', 'BÚT LÔNG KIM FL-04 TÍM /LUCK VỈ 3 CÂY (5404-TL)', 'Cái'),
  ('893532404192', 'BÚT DẠ QUANG FREE INK HL-020 HỒNG HỘP 10 (5404-TL)', 'Cái'),
  ('893532404193', 'BÚT DẠ QUANG FREE INK HL-020 TÍM HỘP 10 (5404-TL)', 'Cái'),
  ('893532404195', 'BÚT DẠ QUANG FREE INK HL-020 CAM HỘP 10 (5404-TL)', 'Cái'),
  ('893532404196', 'BÚT DẠ QUANG FREE INK HL-020 LÁ HỘP 10 (5404-TL)', 'Cái'),
  ('893532404563', 'BÚT DẠ QUANG HL-023 CAM PASTEL HỘP 10 (5404-TL)', 'Cái'),
  ('893532404564', 'BÚT DẠ QUANG HL-023 VÀNG PASTEL HỘP 10 (5404-TL)', 'Cái'),
  ('893532404570', 'BÚT DẠ QUANG HL-023 LÁ PASTEL HỘP 10 (5404-TL)', 'Cái'),
  ('893532404571', 'BÚT DẠ QUANG HL-023 TÍM PASTEL HỘP 10 (5404-TL)', 'Cái'),
  ('893532404595', 'BÚT DẠ QUANG HL-024 VÀNG MORANDI HỘP 10 (5404-TL)', 'Cái'),
  ('893532404596', 'BÚT DẠ QUANG HL-024 TÍM MORANDI HỘP 10 (5404-TL)', 'Cái'),
  ('893532404597', 'BÚT DẠ QUANG HL-024 XÁM MORANDI HỘP 10 (5404-TL)', 'Cái'),
  ('893532404598', 'BÚT DẠ QUANG HL-024 HỒNG MORANDI HỘP 10 (5404-TL)', 'Cái'),
  ('893532404599', 'BÚT DẠ QUANG HL-024 XANH MORANDI HỘP 10 (5404-TL)', 'Cái'),
  ('893500181393', 'BÚT LÔNG DẦU ĐEN PM-07 (10C/H) (5404-TL)', 'Cái'),
  ('893500188188', 'BÚT BI ĐEN FO-024/VN (20C/H) (5404-TL)', 'Cái'),
  ('893521946058', 'CRAYOLA - BÚT LÔNG 50 MÀU SUPERTIPS - 585050 (T.LONG)', 'Cái'),
  ('893500185446', 'BÚT GEL TÍM GEL-030/CA (20C/H) (5404-TL)', 'Cái'),
  ('893521946066', 'CRAYOLA - BỘ 6 MÀU NƯỚC RỬA ĐƯỢC - 541204 (T.LONG)', 'Cái'),
  ('490481046742', 'XE NO.100 LEXUS IS F SPORT TM-467427 (G.KID)', 'Cái'),
  ('490481082481', 'XE NO.8 SUZUKI ALTO TM-824817 (G.KID)', 'Cái'),
  ('490481087951', 'XE TOMICA NO.06-10 SUBARU  TM-879510 (G.KID)', 'Cái'),
  ('490481087955', 'XE TOMICA NO.27-11 NISSAN NV200 TM-879558 (G.KID)', 'Cái'),
  ('801858396452', 'XE TOMICA BOX NO.58 SUZUKI WAGON R TM-471097 (G.KID)', 'Cái'),
  ('893521943458', 'NINJA 4 IN 1 YYUAN 0812-1-TLMN 126', 'Cái'),
  ('893600869016', 'BÌA 1 NÚT F4 (GIAI PHÁT)', 'Cái'),
  ('893600869019', 'BÌA NÚT A4 (KING-STAR)(GIAI PHÁT)', 'Cái'),
  ('893500181530', 'BÚT LÔNG BẢNG XANH WB-02 (20C/H) (5404-TL)', 'Cái'),
  ('893500185514', 'BÚT GEL XANH XÓA ĐƯỢC TP-GELE01 (20C/H) (5404-TL)', 'Cái'),
  ('893500180130', 'BÚT BI XANH TL-08 (20C/H) (5404-TL)', 'Cái'),
  ('893500182938', 'BÚT GEL TÍM XÓA ĐƯỢC TP GELE01 (20C/H) (5404-TL)', 'Cái'),
  ('893500180451', 'BÚT BI ĐEN TL-08 (20C/H) (5404-TL)', 'Cái'),
  ('893500185364', 'BÚT GEL TÍM GEL-012/DO (20C/H) (5404-TL)', 'Cái'),
  ('893500185368', 'BÚT GEL XANH TP- GEL03 (20C/H) (5404-TL)', 'Cái'),
  ('893500183670', 'BUT SAP VAN TCR-C007 DO 12 MAU (A5404-TL)', 'Cái'),
  ('893500180394', 'BÚT BI XANH TL-089 (20C/H) (5404-TL)', 'Cái'),
  ('893532400289', 'BÚT BI TL-105 XANH VỎ PASTEL TL (20C/H) (5404-TL)', 'Cái'),
  ('893532401420', 'BÚT GEL GEL-042 XANH HỘP 20 (5404-TL)', 'Cái'),
  ('893500180403', 'BÚT BI XANH TL-093 (20C/H) (5404-TL)', 'Cái'),
  ('893500181453', 'BÚT LÔNG DẦU PM-04 XANH (H10) (A5404-TL)', 'Cái'),
  ('201049901890', 'VIẾT ĐẾ CẮM SCB PH-02 XANH', 'Cái'),
  ('893500180455', 'BÚT BI ĐEN TL-023 (20C/H) (5404-TL)', 'Cái'),
  ('893500180488', 'BÚT BI ĐEN TL-062 (20C/H) (5404-TL)', 'Cái'),
  ('893500180454', 'BÚT BI ĐỎ TL-023 (20C/H) (5404-TL)', 'Cái'),
  ('893500185430', 'BÚT GEL TÍM TP- GEL01 (20C/H) (5404-TL)', 'Cái'),
  ('893500181008', 'BÚT LÔNG BẢNG XANH WB-03 (10C/H) (5404-TL)', 'Cái'),
  ('893500181784', 'BÚT LÔNG BẢNG ĐỎ WB-03 (10C/H) (5404-TL)', 'Cái'),
  ('893500181785', 'BÚT LÔNG BẢNG ĐEN WB-03 (10C/H) (5404-TL)', 'Cái'),
  ('207080004226', 'BỘ THỰC HÀNH TOÁN - TIẾNG VIỆT LỚP 1 (TBTH)', 'Cái'),
  ('990000069750', 'BỘ THỰC HÀNH TOÁN LỚP 3 (TBTH)', 'Cái'),
  ('893500182323', 'VIẾT CHÌ GỖ BIZNER BIZ-P02 (10C/H) (5404-TL)', 'Cái'),
  ('893532401600', 'BÚT GEL XÓA ĐƯỢC GELE-007/V1 TÍM HỘP 10 (5404-TL)', 'Cái'),
  ('893500182006', 'BÚT XÓA CP-02 (10C/H) (A5404-TL)', 'Cái'),
  ('893500184778', '(BO MAU)GOM 2D E-012(20VI H)(THIEN LONG)', 'Cái'),
  ('693110555532', 'BIA CONG CUA NHUA 3,5CM A4', 'Cái'),
  ('201990002028', 'DA3 LY NHỰA 220ML (50 CÁI/LỐ)', 'Cái'),
  ('893532401668', 'BÚT LÔNG MÀU ACRYLIC 2Đ ACM-C002 24 MÀU (5404-TL)', 'Cái'),
  ('893500180595', 'BÚT BI ĐỎ TL-08 VỈ 5 (5404-TL)', 'Cái'),
  ('893532402095', 'BÚT BI TL-019 ĐEN (20C/H) (5404-TL)', 'Cái'),
  ('893521946070', 'CRAYOLA - BỘ BÚT CHÌ 50 MÀU - 684050 (T.LONG)', 'Cái'),
  ('893500181904', 'ỐNG MỰC TÍM FPIC-01 (10C/H) (5404-TL)', 'Cái'),
  ('893500185428', 'BÚT GEL XANH TP- GEL01 (20C/H) (5404-TL)', 'Cái'),
  ('200080007673', 'THƯỚC THẲNG 300MM SR-03 (5404-TL)', 'Cái'),
  ('893500185213', '(BO MAU)50003502 BUT GEL-022 XANH HOP 20(THIEN LONG)', 'Cái'),
  ('893500185407', 'BÚT GEL XANH 031 (20C/H) (5404-TL)', 'Cái'),
  ('893532401761', 'BÓP VIẾT 2 NGĂN PCA-019 (5404-TL)', 'Cái'),
  ('203020201631', 'KẸP BƯỚM 32MM DOUBLE A (THÀNH THẮNG)', 'Cái'),
  ('200080544926', '(KSD-BARCODE MÀU) MỰC BÚT MÁY FPI-07 (5404-TL)', 'Cái'),
  ('893500180647', 'BÚT BI ĐỎ TL-079 VỈ 5 (5404-TL)', 'Cái'),
  ('893500183145', 'MỰC BÚT LÔNG DẦU XANH PMI-01 (6C/L) (5404-TL)', 'Cái'),
  ('893500184734', 'CHUỐT CHÌ S-08 (60C/H) (5404-TL)', 'Cái'),
  ('893500184782', 'GÔM E-014 (30V/H) (5404-TL)', 'Cái'),
  ('893500186223', 'KEO ĐA NĂNG 502 FO-SG001 VN (10C VỈ) (5404-TL)', 'Cái'),
  ('893521944009', 'GIẤY GHI CHÚ 3*5 FO-SN05 LỐC 5 (5404-TL)', 'Cái'),
  ('893528390214', 'KSD GÔM TP-E026 TPR 4 MÀU (20C/H) (A5404-TL)', 'Cái'),
  ('893528390255', 'HỘP BÚT TP-PCA016 (5404-TL)', 'Cái'),
  ('893609256774', 'BÚT MÁY ICHI NGÒI NÉT THANH NÉT ĐẬM (CÔNG CHÚA) CL-FP400 (12C/H) (0377-TK)', 'Cái'),
  ('203020300555', 'KIM BẤM 10 DOUBLE A (T.THẮNG)', 'Cái'),
  ('893528390500', 'KSD GÔM E-010 (30C/H) (A5404-TL)', 'Cái'),
  ('893500185399', 'BÚT GEL ĐEN GEL-029 (10C/H) (5404-TL)', 'Cái'),
  ('893500180582', 'BÚT BI XANH TP-05 4MC (20C/H) (5404-TL)', 'Cái'),
  ('893532401307', 'BÚT GEL XÓA ĐƯỢC GELE-008 ĐEN HỘP 20 (5404-TL)', 'Cái'),
  ('893532404189', 'BÚT GEL GEL-074/AK XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893500180532', 'BÚT BI ĐỎ TL-047 (10C/H) (5404-TL)', 'Cái'),
  ('893500180828', 'BÚT LÔNG DẦU ĐỎ PM-07 VỈ 2 (5404-TL)', 'Cái'),
  ('893500181474', 'BÚT DẠ QUANG XANH BIỂN HL-07 (10C/H) (5404-TL)', 'Cái'),
  ('893500182055', 'KSD VIẾT CHÌ GỖ GP-03 (10C/H) (5404-TL)', 'Cái'),
  ('893500182576', 'BÚT CHÌ BẤM PC-018 20C H (5404-TL)', 'Cái'),
  ('893500185311', 'BÚT GEL XANH GEL-029 (10C/H) (5404-TL)', 'Cái'),
  ('893521946016', 'BÚT LÔNG DẦU XANH DƯƠNG SHARPIE FINE 30063 (12C/H) (5404-TL)', 'Cái'),
  ('893532401699', 'BÚT GEL XÓA ĐƯỢC GELE-006/V1 ĐEN HỘP 20 (5404-TL)', 'Cái'),
  ('893532401700', 'BÚT GEL XÓA ĐƯỢC GELE-006/V1 TÍM HỘP 20 (5404-TL)', 'Cái'),
  ('893532402547', 'BÚT GEL GEL-045 XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532403079', 'BÚT LÔNG BI RB-007 XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532403473', 'BÚT GELB-032 XANH 0.5MM 2MC HỘP 20/T960(5404-TL)', 'Cái'),
  ('893532403475', 'BÚT GELB-031 XANH 0.5MM 4MC HỘP 20 (5404-TL)', 'Cái'),
  ('893532403479', 'BÚT GELB-033 XANH-PHỞ TÁI 0.5MM H20/T960 (5404-TL)', 'Cái'),
  ('893532403480', 'BÚT GELB-033 XANH-CƠM TẤM 0.5MM H20/T960 (5404-TL)', 'Cái'),
  ('893500183767', 'BÚT BI ĐEN TP-07 (20C/H) (5404-TL)', 'Cái'),
  ('893532401306', 'BÚT GEL XÓA ĐƯỢC GELE-008 TÍM HỘP 20 (5404-TL)', 'Cái'),
  ('893532404058', 'BÚT GEL GEL-040/LUCK XANH TÚI 2 BÚT (5404-TL)', 'Cái'),
  ('893532401621', 'BÚT GEL XANH GEL-012/AK (20C/H) (5404-TL)', 'Cái'),
  ('893500180700', 'BÚT GEL TÍM GEL-08 VỈ 2 (5404-TL)', 'Cái'),
  ('893500180761', 'BÚT GEL ĐỎ B01 VỈ 2 (5404-TL)', 'Cái'),
  ('893500182969', 'CỌ VẼ TÚI 10 CÂY BRW-C03 (5404-TL)', 'Cái'),
  ('893500185659', 'MÀU NƯỚC KHAY 6 BROWN WACO-C09  (5404-TL)', 'Cái'),
  ('893500185661', 'MÀU NƯỚC KHAY 6 COBALT BLUE WACO-C09 (5404-TL)', 'Cái'),
  ('893500185664', 'MÀU NƯỚC KHAY 6 GREEN WACO-C09 (5404-TL)', 'Cái'),
  ('893604439561', 'STACOM-COMPA CHÌ GỖ CS_101A(24C/H)(5390-ST)', 'Cái'),
  ('893500183195', 'ỐNG MỰC ĐEN BIZ-WBIC01 (10C/H) (5404-TL)', 'Cái'),
  ('893500181509', 'BÚT LÔNG DẦU PM-C01 (12C/H) COLOKIT (5404-TL)', 'Cái'),
  ('893500185534', 'BÚT GEL TÍM B-C01 5 MÀU VỈ 5 (20V/H) (5404-TL)', 'Cái'),
  ('893528390344', 'BÌA 20 LÁ A4 FO-DB007/NĐ LÁ (A5404-TL)', 'Cái'),
  ('893532400375', 'BÌA HỌC SINH 40 LÁ DB-003_TÍM HỒNG TL (5404-TL)', 'Cái'),
  ('893532400377', 'BÌA HỌC SINH 40 LÁ DB-003_XANH DƯƠNG CAM TL (5404-TL)', 'Cái'),
  ('893500182445', 'BÚT SÁP MÀU COLOKIT JUMBO CR-C034 12 MÀU/KM (5404-TL)', 'Cái'),
  ('893521946057', 'CRAYOLA - BÚT LÔNG 20 MÀU SUPERTIPS - 588106 (T.LONG)', 'Cái'),
  ('893521946075', 'CRAYOLA - BỘ BÚT CHÌ 24 MÀU DA COTW - 684607 (T.LONG)', 'Cái'),
  ('893532401078', 'BỘ TẬP TÔ MÀU DISNEY POOH COB-C008 (A5404-TL)', 'Cái'),
  ('893532401613', 'TRANH CUỘN TÔ MÀU KHỦNG LONG CRO-C002 (5404-TL)', 'Cái'),
  ('893521948217', 'KẸP BƯỚM MÀU 32MM FO-DCC04 (12H/L) (5404-TL)', 'Cái'),
  ('893500184706', 'KÉO HỌC SINH SC-09/DO (20C/H) (5404-TL)', 'Cái'),
  ('893521948216', 'KẸP BƯỚM MÀU 25MM FO-DCC03 (12H/L) (5404-TL)', 'Cái'),
  ('893532401156', 'BÚT MÁY TP-FTC030 CÁN XANH HỘP 10 CÓ TEM (5404-TL)', 'Cái'),
  ('893532401157', 'BÚT MÁY TP-FTC04 CÁN XANH HỘP 10 CÓ TEM (5404-TL)', 'Cái'),
  ('893532401158', 'BÚT MÁY TP-FTC04 CÁN HỒNG HỘP 10 CÓ TEM (5404-TL)', 'Cái'),
  ('893500182404', 'BÚT SÁP MÀU 36M CR-C032/CA (5404-TL)', 'Cái'),
  ('893500182405', 'BÚT SÁP MÀU 36 MÀU CR-C033/FR (5404-TL)', 'Cái'),
  ('893500183037', 'MỰC BÚT MÁY XANH FPI-08/DO (8H/L) (5404-TL)', 'Cái'),
  ('893500183039', 'MỰC BÚT MÁY TÍM FPI-08/DO (8H/L) (5404-TL)', 'Cái'),
  ('893532400550', 'BÚT MÁY TP-FTC02 HỒNG-MỰC XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532401122', 'BÚT MÁY TP-FTC09 CÁN ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532401152', 'BÚT MÁY TP-FTC03 CÁN XANH HỘP 10 CÓ TEM (5404-TL)', 'Cái'),
  ('893532401153', 'BÚT MÁY TP-FTC03 CÁN HỒNG HỘP 10 CÓ TEM (5404-TL)', 'Cái'),
  ('893532401155', 'BÚT MÁY TP-FTC030 CÁN HỒNG HỘP 10 CÓ TEM (5404-TL)', 'Cái'),
  ('893532402173', 'BỘ TẬP TÔ MÀU COB-C034/AK T40(5404-TL)', 'Cái'),
  ('893532400009', 'VỞ VẼ A4 150GSM SKB-C006 (5404-TL)', 'Cái'),
  ('893532401007', 'BÚT GEL XÓA ĐƯỢC GELE-007 XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532401121', 'BÚT MÁY TP-FTC09 CÁN XANH NGỌC HỘP 10 (5404-TL)', 'Cái'),
  ('893500182308', 'SÁP MÀU 24 MÀU CR-C021 (5404-TL)', 'Cái'),
  ('893504452836', 'HH-SỔ LÒ XO BISTRO, A6, 200TR , ĐL: 70/90 (10Q/LỐC) (THKG0064)', 'Cái'),
  ('893504453006', 'HH - SỔ LÒ XO BÌA NHỰA BASIC, A5-160TR, ĐL 80/76-78 (THKG0064)', 'Cái'),
  ('893504453009', 'HH - SỔ LÒ XO BÌA NHỰA BASIC, A4-160TR, ĐL 80/76-78 (THKG0064)', 'Cái'),
  ('893504454142', 'HH - SỔ LÒ XO LANDSCAPE, A6, 200TR, ĐL: 70/90 (10Q/LỐC) (HH-0064)', 'Cái'),
  ('893504454536', 'HH-SỔ BÌA BỒI SUBJECT, B5, 300TR, ĐL: 58/84 (5Q/LỐC) (THKG0064)', 'Cái'),
  ('893504454617', 'HH - SỔ BÌA BỒI SUBJECT (RUỘT CARO), A4, 200 TRANG, ĐL: 58/84 (HH-0064)', 'Cái'),
  ('893504454900', 'HH-VỞ VẼ A3 20 TỜ ĐL: 100/90(10Q/LỐC) (THKG0064)', 'Cái'),
  ('893504454942', 'HH- VỞ VẼ A3 20 TỜ ĐL: 100/78 (THKG0064)', 'Cái'),
  ('893504454180', 'HH - SỔ LO XO DAILY VOCAB 03(97X125 MM) 200TR, ĐL 70/76 -78 - 4180 (HH-0064)', 'Cái'),
  ('893528390031', 'BÌA NÚT F4 TL-HCB-02 (10C/X) ( A5404-TL)', 'Cái'),
  ('893528390330', 'BÌA LÁ A4 FO-CH168 TÚI (100C/X) (5404-TL)', 'Cái'),
  ('893604045540', 'BÌA LÁ F4 CH02/FO TRONG (5404-TL)', 'Cái'),
  ('893500182544', 'BÚT XÓA TP-CP04 (20C/H) (5404-TL)', 'Cái'),
  ('893500181907', 'ỐNG MỰC TÍM FPIC-02 (10C/H) (5404-TL)', 'Cái'),
  ('893500182370', 'VIẾT CHÌ MỸ THUẬT 3B GP-022 (10C/H) (5404-TL)', 'Cái'),
  ('893500184040', 'MÀU NƯỚC 12 MÀU WACO 05 (5404-TL)', 'Cái'),
  ('893500184710', 'BAO THƯ BT-01 TÚI (25C/XẤP)/T5000 (5404-TL)', 'Cái'),
  ('893500184932', 'NHÃN VỞ TP-NBL01 (3C/X) (5404-TL)', 'Cái'),
  ('893500185935', 'NHÃN VỞ TP-NBL005 (3 CÁI) XẤP 4 (5404-TL)', 'Cái'),
  ('893532401694', 'THƯỚC THẲNG TP-SR011/AK TÚI 1/T200(5404-TL)', 'Cái'),
  ('893532402162', 'BÚT CHÌ GỖ ĐEN DEMON SLAYER GP-030/DS (5404-TL)', 'Cái'),
  ('893532403803', 'THƯỚC THẲNG 15CM SR-037 TÚI 1/200(5404-TL)', 'Cái'),
  ('893604045379', 'THƯỚC DẺO 20CM SR-024 (5404-TL)', 'Cái'),
  ('893532402025', 'MÀU NƯỚC DẠNG NÉN WACO-C017 18 MÀU (5404-TL)', 'Cái'),
  ('893532404033', 'MÀU NƯỚC WACO-C06/AK 8 MÀU/T60 (5404-TL)', 'Cái'),
  ('893500184024', 'MÀU NƯỚC 8 MÀU WACO-03 (5404-TL)', 'Cái'),
  ('893500186353', 'BÚT LÔNG MỸ THUẬT AM-C001 24 MÀU(5404-TL)', 'Cái'),
  ('893532401688', 'MÀU NƯỚC RỬA ĐƯỢC SWP-C004/AK KHAY 12 MÀU (5404-TL)', 'Cái'),
  ('893532401691', 'MÀU NƯỚC RỬA ĐƯỢC SWP-C003/AK KHAY 6 MÀU (5404-TL)', 'Cái'),
  ('893532401980', 'MÀU ACRYLIC ACR-C009 75ML VÀNG (5404-TL)', 'Cái'),
  ('893532401984', 'MÀU ACRYLIC ACR-C009 75ML VÀNG CHANH (5404-TL)', 'Cái'),
  ('893532401987', 'MÀU ACRYLIC ACR-C009 75ML HỒNG CÁNH SEN (5404-TL)', 'Cái'),
  ('893532401988', 'MÀU ACRYLIC ACR-C009 75ML XANH LÁ MẠ (5404-TL)', 'Cái'),
  ('893532401991', 'MÀU ACRYLIC ACR-C010 100ML VÀNG ĐẤT (5404-TL)', 'Cái'),
  ('893532401992', 'MÀU ACRYLIC ACR-C010 100ML CAM (5404-TL)', 'Cái'),
  ('893532401994', 'MÀU ACRYLIC ACR-C010 100ML TÍM(5404-TL)', 'Cái'),
  ('893532401995', 'MÀU ACRYLIC ACR-C010 100ML XANH DƯƠNG(5404-TL)', 'Cái'),
  ('893532401996', 'MÀU ACRYLIC ACR-C010 100ML XANH LÁ(5404-TL)', 'Cái'),
  ('893532402001', 'MÀU ACRYLIC ACR-C009 75ML NÂU (5404-TL)', 'Cái'),
  ('893532402004', 'MÀU ACRYLIC ACR-C010 100ML HỒNG CÁNH SEN (5404-TL)', 'Cái'),
  ('893532402005', 'MÀU ACRYLIC ACR-C010 100ML XANH LÁ MẠ (5404-TL)', 'Cái'),
  ('893532402020', 'MÀU NƯỚC DẠNG NÉN WACO-C016 12 MÀU (5404-TL)', 'Cái'),
  ('893532403713', 'MÀU NƯỚC WACO-C06/DO 8 MÀU/T60 (5404-TL)', 'Cái'),
  ('893532403716', 'MÀU NƯỚC WACO-C002/DO 12 MÀU/T60 (5404-TL)', 'Cái'),
  ('694128872763', 'MÀU ACRYLIC METALLIC 75ML ĐỎ KR972208 (THNK068)', 'Cái'),
  ('893532403691', 'BÚT SƠN ACRYLIC MỰC LỎNG ACM-C013 6 MÀU (5404-TL)', 'Cái'),
  ('893500182444', 'BÚT SÁP DẦU COLOKIT OP-C016 38 MÀU/KM (5404-TL)', 'Cái'),
  ('893500184701', 'SÁP NẶN MC-016 (5404-TL)', 'Cái'),
  ('893500186619', 'SÁP MÀU ĐA NĂNG WSO-C001 (12C/H) (A5404-TL)', 'Cái'),
  ('893500180462', 'BÚT BI ĐỎ TL-027 (20C/H) (360 ĐỘ) (5404-TL)', 'Cái'),
  ('893500180503', 'BÚT BI ĐỎ TL-089 (20C/H) (5404-TL)', 'Cái'),
  ('893500185790', 'BUT GELTP-GELE002 XANH HOP 20 XOA DUOC  (A5404-TL)', 'Cái'),
  ('893532401599', 'BÚT GEL XÓA ĐƯỢC GELE-007/V1 XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532401624', 'BÚT LÔNG KIM XANH FL-04/AK (20C/H) (5404-TL)', 'Cái'),
  ('893532402479', 'BÚT GEL GEL-057 ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532403616', 'BÚT GEL GEL-050 VÀNG HỘP 10 (5404-TL)', 'Cái'),
  ('893532404155', 'BÚT ĐÙN TL-021 ĐEN 0.6 HỘP 20/T2000 (5404-TL)', 'Cái'),
  ('893500180322', 'BÚT BI XANH TL-061 (20C/H) (5404-TL)', 'Cái'),
  ('893500180471', 'BÚT BI ĐEN TL-036 (20C/H)/T1200 (5404-TL)', 'Cái'),
  ('893521946056', 'CRAYOLA -  BÚT LÔNG 10 MÀU SUPERTIPS - 588610 (T.LONG)', 'Cái'),
  ('893521946072', 'CRAYOLA - BỘ BÚT SÁP DẦU 16 MÀU - 524616 (T.LONG)', 'Cái'),
  ('893521948204', 'KẸP BƯỚM ĐEN 41MM FO-DC05 (12H/L) (5404-TL)', 'Cái'),
  ('893500185151', 'BÚT GEL XANH GEL-012/DO (20C/H) (5404-TL)', 'Cái'),
  ('893500183684', 'VIẾT CHÌ BẤM PC-026 (10C/H) (5404-TL)', 'Cái'),
  ('893500185439', 'BÚT GEL ĐEN BIZ-GEL01 VỈ 01 (20V/H) (5404-TL)', 'Cái'),
  ('893532401802', 'TẬP TÔ MÀU COB-C029 LỐC 20(5404-TL)', 'Cái'),
  ('893532401806', 'TẬP TÔ MÀU COB-C031 LỐC 20(5404-TL)', 'Cái'),
  ('893532402529', 'BÚT ĐẾ CẮM PH-063/ECO XANH M.XANH HỘP 01 (5404-TL)', 'Cái'),
  ('893532402602', 'BÚT ĐẾ CẮM PH-063/ECO HỒNG M.XANH HỘP 01 (5404-TL)', 'Cái'),
  ('893500180479', 'BÚT BI ĐỎ TL-049 (20C/H) (5404-TL)', 'Cái'),
  ('893500181090', '(KSD- BARCODE THEO MÀU) BÚT LÔNG DẦU PM- 07TL', 'Cái'),
  ('893500181477', 'BÚT DẠ QUANG CAM HL-07 (10C/H) (5404-TL)', 'Cái'),
  ('893500182689', 'BÚT BI XANH TP-06 4MC (20C/H) (5404-TL)', 'Cái'),
  ('893500183004', 'MỰC BÚT LÔNG DẦU PMI-01 (6C/LOC) (5404-TL) (893500183147)', 'Cái'),
  ('893500185392', 'BÚT GEL ĐỎ GEL-027 (20C/H) (5404-TL)', 'Cái'),
  ('893500185393', 'BÚT GEL ĐEN GEL-027 (20C/H) (5404-TL)', 'Cái'),
  ('893500185459', 'BÚT GEL ĐEN GEL-030/PR (20C/H) (5404-TL)', 'Cái'),
  ('893500187845', 'MỰC BÚT LÔNG DẦU ĐỦ MÀU FO-PMI02 (6C/L) (5404-TL)', 'Cái'),
  ('893500187846', 'MỰC BÚT LÔNG BẢNG ĐỦ MÀU FO-WBI02 (6C/L) (5404-TL)', 'Cái'),
  ('893500187853', 'BÚT LÔNG DẦU XANH FO-PM09/VN (10C/H) (5404-TL)', 'Cái'),
  ('893500189637', 'BÚT BI ĐEN FO-036/VN (10C/H) (5404-TL)', 'Cái'),
  ('893532404304', 'THƯỚC THẲNG 15CM SR-038/DS TÚI 1/200 (5404-TL)', 'Cái'),
  ('893604045380', 'THƯỚC DẺO 15CM SR-025 (5404-TL)', 'Cái'),
  ('893500185012', 'BÚT GEL XANH GEL-04 (20C/H) T960 (5404-TL)', 'Cái'),
  ('893500181485', 'BÚT DẠ QUANG XANH BIỂN HL-012 (10C/H) (5404-TL)', 'Cái'),
  ('893500183526', 'KÉO HỌC SINH SC-C04 (12C/H) (5404-TL)', 'Cái'),
  ('893500183547', 'KÉO ĐA NĂNG SC-022 (10C/H) (5404-TL)', 'Cái'),
  ('893500184412', 'THƯỚC THẲNG SR-011/DO (5404-TL)', 'Cái'),
  ('893500184791', 'KÉO HỌC SINH SC- 011 (20C/H) (5404-TL)', 'Cái'),
  ('893500186502', 'BÚT DẠ QUANG FO-HL009/VN VÀNG HỘP 10 (5404-TL)', 'Cái'),
  ('893500187034', 'BÚT LÔNG BẢNG ĐỎ FO-WB02 (10C/H) (5404-TL)', 'Cái'),
  ('893521948305', 'DAO VĂN PHÒNG FO-KN04 (12C/H) (5404-TL)', 'Cái'),
  ('893528390009', 'KÉO HỌC SINH SC-C01 T240 (20C/H) (5404-TL)', 'Cái'),
  ('893528390016', 'KÉO VĂN PHÒNG SC-016 T240 (20C/H) (5404-TL)', 'Cái'),
  ('204029901140', 'BÌA THƠM THÁI LAN A4 MỎNG (250 TỜ  XẤP)(ALV)', 'Cái'),
  ('200060100243', 'BẢNG NHÓM DUNG CHO HS "40*60cm" (4631-ĐT)', 'Cái'),
  ('893500180245', 'KEO KHÔ TÍM FO-G006 (30C/H) (5404-TL)', 'Cái'),
  ('893500183200', 'MÀU NƯỚC 6 MÀU WACO-C011 HỘP (5404-TL)', 'Cái'),
  ('893500185133', 'BÚT GEL XANH GEL-012 VỈ 2 (5404-TL)', 'Cái'),
  ('893500184918', 'GIẤY KIỂM TRA 4 ÔLY VUÔNG TP-GKT01 (5404-TL)', 'Cái'),
  ('893500184919', 'GIẤY KIỂM TRA 4 ÔLY VUÔNG TP-GKT02 (5404-TL)', 'Cái'),
  ('893500184924', 'GIẤY KIỂM TRA 4 ÔLY VUÔNG 2X2 TP-GKT07(5404-TL)', 'Cái'),
  ('893500185966', 'TẬP HỌC SINH ĐIỂM 10 120TR ĐL70 KẺ NGANG TP-NB104 (100C/T)(5404-TL)', 'Cái'),
  ('893532403965', 'TẬP CHỐNG LEM 96TR ĐL120 4 Ô LY NB-121/AK (100C/T)(5404-TL)', 'Cái'),
  ('893532404068', 'TẬP DÁN GÁY 96TR ĐL70G LY NGANG NB-111/DS XANH (100C/T)(5404-TL)', 'Cái'),
  ('893532402376', 'SỔ LÒ XO A5 CAM 120T KẺ NGANG MB-023/DS (5C/L) (5404-TL)', 'Cái'),
  ('893500183612', 'GIẤY KIỂM TRA 5 ÔLY VUÔNG TP-GKT011 2/3 (5404-TL)', 'Cái'),
  ('893600745858', 'PLUS - BÚT CHÌ POKEMON HỘP 12 CÂY GN 600-V001 (HV)', 'Cái'),
  ('893600745859', 'PLUS - BÚT CHÌ POKEMON HỘP 12 CÂY BL 600-V005 (HV)', 'Cái'),
  ('203010603671', '(KSD-BARCODE MÀU) BÚT GEL 018 VỈ 2 CÂY (5404-TL)', 'Cái'),
  ('893500180371', '(BO MAU)BUT BI TL 076 (THIEN LONG)', 'Cái'),
  ('893500180380', '(BO MAU)BUT BI TL080(20C H)(THIEN LONG)', 'Cái'),
  ('893500180429', '(BO MAU)BUT BI TL-092 BIZNER(THIEN LONG)', 'Cái'),
  ('893500180637', 'BÚT BI ĐỎ TL-061 VỈ 3 (5404-TL)', 'Cái'),
  ('893500180638', 'BÚT BI ĐEN TL-061 VỈ 3 (5404-TL)', 'Cái'),
  ('893500183025', '(BO MAU)ONG MUC BUT PHAN NUOC CMIC-01(10C H)(THIEN LONG)', 'Cái'),
  ('893500184831', '(KSD) CHUỐT CHÌ HÌNH NAM S-012 (24C/H) (5404-TL)', 'Cái'),
  ('893500185290', '(BO MAU)VI 2 BUT GEL-022(THIEN LONG)', 'Cái'),
  ('893500186545', 'BỘ TÔ MÀU GỖ KIT-C032 SET BỘ (A5404-TL)', 'Cái'),
  ('203020300578', 'GỠ KIM EAGLE (ALV)', 'Cái'),
  ('204049901017', 'GIẤY THAN GSTART A4 LOẠI 1 (0568-ALV)', 'Cái'),
  ('201029900883', 'LÌ XÌ 182 (BÔNG LỚN) (M.B.MINH)', 'Cái'),
  ('201039901484', 'BBVL 882-BAO LÌ XÌ X 8 (Đ. VIỆT)', 'Cái'),
  ('893500182153', 'BÚT SÁP MÀU 16M CRC05/DOREMON (5404-TL)', 'Cái'),
  ('893532401518', 'BÚT CHÌ MÀU CC HỘP THIẾC CPC-C039 12 MÀU(5404-TL)', 'Cái'),
  ('893532401523', 'BÚT CHÌ MÀU CPC-C037 18 MÀU (5404-TL)', 'Cái'),
  ('893532403877', 'BÚT LÔNG MÀU SIÊU SẠCH UWM-C001 12 MÀU (5404-TL)', 'Cái'),
  ('893532401488', 'BÚT CHÌ MÀU WOODFREE CPC-C031/AK 12 MÀU(5404-TL)', 'Cái'),
  ('893500182152', 'BÚT SÁP MÀU CRC04/DOREMON 10 MÀU (5404-TL)', 'Cái'),
  ('893500184698', 'HỒ DÁN 15ML- G-015 (12C/L) (5404-TL)', 'Cái'),
  ('893500184486', 'BẢNG BỘ B-09 (5404-TL)', 'Cái'),
  ('893528390175', 'BẢNG HỌC SINH TP-B018 XANH (A5404-TL)', 'Cái'),
  ('893532403497', 'GIẤY GHI CHÚ BESTIES 70X70 SN-020 LỐC 12 (5404-TL)', 'Cái'),
  ('893500180065', 'BÚT BI XANH TL-036 (20C/H)/T1200 (5404-TL)', 'Cái'),
  ('893532404084', 'TẬP DÁN GÁY 200TR ĐL70G LY NGANG NB-112/DS XANH (100C/T)(5404-TL)', 'Cái'),
  ('893532404075', 'TẬP DÁN GÁY 120TR ĐL70G CARO NB-110/DS VÀNG (100C/T)(5404-TL)', 'Cái'),
  ('893532404095', 'TẬP DÁN GÁY 120TR ĐL70G KẺ NGANG NB-108/DS HỒNG (100C/T)(5404-TL)', 'Cái'),
  ('893532404099', 'TẬP DÁN GÁY 120TR ĐL70G KẺ NGANG NB-108/DS XANH (100C/T)(5404-TL)', 'Cái'),
  ('893500187086', 'LAU BẢNG FO-WBE01 (10C/H) (5404-TL)', 'Cái'),
  ('893532403882', 'BÚT DẠ QUANG HL-03/LUCK TÚI 3 BÚT 3 MÀU (5404-TL)', 'Cái'),
  ('893532404055', 'BÚT GEL BI GELB-046/LUCK XANH TÚI 3 BÚT (5404-TL)', 'Cái'),
  ('893500180035', 'BÚT BI XANH TL-025', 'Cái'),
  ('893500185061', 'BÚT GEL XANH GEL-07 VỈ 2 (5404-TL)', 'Cái'),
  ('893500185521', 'BÚT GEL GEL-030 CA XANH ĐẦU BI 0.5 MM (VỈ 2) (5404-TL)', 'Cái'),
  ('893532404709', 'BÚT LÔNG MÀU RỬA ĐƯỢC SWM-C012/DS 48 MÀU (5404-TL)', 'Cái'),
  ('893532403202', 'LY GIỮ NHIỆT TC-001/DS NÂU 650ML (5404-TL)', 'Cái'),
  ('893532403201', 'LY GIỮ NHIỆT TC-001/DS CAM 650ML (5404-TL)', 'Cái'),
  ('893500181455', 'BÚT LÔNG DẦU ĐEN PM-04 (10C/H) (5404-TL)', 'Cái'),
  ('893532402379', 'SỔ LÒ XO A5 HỒNG 120T KẺ NGANG MB-023/DS (5C/L) (5404-TL)', 'Cái'),
  ('893532401973', 'BÚT CHÌ MÀU HỘP THIẾC 24 MÀU CPC-C043/DS (5404-TL)', 'Cái'),
  ('893532401966', 'BÚT CHÌ MÀU HỘP THIẾC 12 MÀU CPC-C042/DS (5404-TL)', 'Cái'),
  ('893500184920', 'GIẤY KIỂM TRA TP-GKT03 5 ÔLY VUÔNG (5404-TL)', 'Cái'),
  ('893532404069', 'TẬP DÁN GÁY 96TR ĐL70G LY NGANG NB-111/DS HỒNG (100C/T)(5404-TL)', 'Cái'),
  ('893532404078', 'TẬP DÁN GÁY 120TR ĐL70G CARO NB-110/DS XANH (100C/T)(5404-TL)', 'Cái'),
  ('893532404083', 'TẬP DÁN GÁY 200TR ĐL70G LY NGANG NB-112/DS VÀNG (100C/T)(5404-TL)', 'Cái'),
  ('893500185949', 'GIẤY KIỂM TRA KẺ NGANG 20 TỜ TP-GKT15 (5404-TL)', 'Cái'),
  ('893532403878', 'BÚT ĐÙN TL-021 XANH 0.6 HỘP 20/T2000 (5404-TL)', 'Cái'),
  ('302698143643', 'PARKER 60002174 BÚT BI IM PRM X-PEARL GT GB-2143643 (A5404-TL)', 'Cái'),
  ('893500180533', 'BÚT BI ĐEN TL-047 (10C/H) (5404-TL)', 'Cái'),
  ('893500181486', 'BÚT DẠ QUANG XANH LÁ HL-012 (10C/H) (5404-TL)', 'Cái'),
  ('893500182125', 'RUỘT CHÌ PCL-03 (5404-TL)', 'Cái'),
  ('893500185308', 'BÚT GEL XANH GEL-027 (20C/H) (5404-TL)', 'Cái'),
  ('893521946033', 'BÚT LÔNG DẦU ĐỎ SHARPIE ULTRA FINE 37122 (12C/H) (5404-TL)', 'Cái'),
  ('893532400435', 'BÚT GEL XÓA ĐƯỢC GELE-006 ĐEN (20C/H) TL (5404-TL)', 'Cái'),
  ('893532401010', 'BÚT GEL XÓA ĐƯỢC GELE-007 ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532401838', 'BÚT GEL GEL-040 XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532402552', 'BÚT GEL GEL-045 ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532403140', 'RUỘT CHÌ PCL-009/HS HB 0.5MM HỘP 10 (5404-TL)', 'Cái'),
  ('893532403474', 'BÚT GELB-034 XANH-BT TRỘN 0.5MM H20/T960 (5404-TL)', 'Cái'),
  ('893532403478', 'BÚT GELB-033 XANH-BÁNH MÌ 0.5MM H20/T960 (5404-TL)', 'Cái'),
  ('893532403509', 'BÚT GELB-034 XANH-BTNƯỚNG 0.5MM H20/T960 (5404-TL)', 'Cái'),
  ('893532403613', 'BÚT GEL GEL-050 CAM HỘP 10 (5404-TL)', 'Cái'),
  ('893532403615', 'BÚT GEL GEL-050 XANH LÁ HỘP 10 (5404-TL)', 'Cái'),
  ('893532403617', 'BÚT GEL GEL-050 XANH DA TRỜI HỘP 10 (5404-TL)', 'Cái'),
  ('893532403807', 'BÚT GEL GEL-071 ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532403831', 'BÚT GEL GEL-066 ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532404024', 'BÚT GELB-035 XANH 0.5 HỘP 20/T960 (5404-TL)', 'Cái'),
  ('893532404191', 'BÚT GEL GEL-074/AK ĐEN HỘP 10 (5404-TL)', 'Cái'),
  ('893532404194', 'BÚT DẠ QUANG FREE INK HL-020 VÀNG HỘP 10 (5404-TL)', 'Cái'),
  ('893532402688', 'BÚT CHÌ BẤM MÀU ĐEN PC-037/HS (HỘP 10 CÂY) (5404-TL)', 'Cái'),
  ('893500186178', 'BÚT GEL ĐEN XÓA ĐƯỢC TP-GELE003 (20C/H) (5404-TL)', 'Cái'),
  ('893607841019', 'BAO SÁCH LỚP 1 MỚI(KHỔ 190*265)(100 TỜ/XẤP)(5298-TNT)', 'Cái'),
  ('893500180478', 'BÚT BI XANH TL-049 (20C/H) (5404-TL)', 'Cái'),
  ('893500180530', 'BÚT BI TÍM TL-027 (20C/H) (360 ĐỘ) (5404-TL)', 'Cái'),
  ('893500181324', 'BÚT LÔNG KIM XANH,TÍM, ĐEN FL-08/DO (10C/H) (5404-TL)', 'Cái'),
  ('893500182448', 'BÚT SÁP MÀU COLOKIT CR-C040 16 MÀU/KM (5404-TL)', 'Cái'),
  ('893500185316', 'BÚT GEL ĐỎ B01 (10C/H) (5404-TL)', 'Cái'),
  ('893500185321', 'BÚT GEL ĐEN B03 (10C/H) (5404-TL)', 'Cái'),
  ('893500185356', 'BÚT GEL ĐỎ GEL-012 (20C/H) (5404-TL)', 'Cái'),
  ('893500185363', 'BÚT GEL ĐEN GEL-012/DO (20C/H) (5404-TL)', 'Cái'),
  ('893500186492', 'BÚT DẠ QUANG HL-016 ĐỎ PASTEL (5C/H) (A5404-TL)', 'Cái'),
  ('893532400318', 'BÚT GEL GEL-033 ĐỎ (10C/H) TL (5404-TL)', 'Cái'),
  ('893532401719', 'SÁP MÀU RỬA ĐƯỢC SWCR-C002/AK 18 MÀU (5404-TL)', 'Cái'),
  ('893532401732', 'BÚT CHÌ GỖ 2B AKOOLAND TP-GP021/AK H10/960(5404-TL)', 'Cái'),
  ('893532401914', 'BÚT VẼ KỸ THUẬT 03 DW-C002 HỘP 12(5404-TL)', 'Cái'),
  ('893532402053', 'BÚT GEL B-046 HỒNG - MỰC XANH (20C/H) (5404-TL)', 'Cái'),
  ('893532402058', 'BÚT GEL B-046 XANH - MỰC XANH (20C/H) (5404-TL)', 'Cái'),
  ('893532403485', 'BÚT GEL GEL-059 XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893532404178', 'BÚT GEL GEL-067 XANH HỘP 20 (5404-TL)', 'Cái'),
  ('893532404190', 'BÚT GEL GEL-074/AK TÍM HỘP 10 (5404-TL)', 'Cái'),
  ('893500182290', 'VIẾT CHÌ GỖ GP-018 (10C/H) (5404-TL)', 'Cái'),
  ('893604045375', 'BẢNG HỌC SINH B-016 PLUS XANH (5404-TL)', 'Cái'),
  ('893500184556', 'BẢNG BỘ B011 (5404-TL)', 'Cái'),
  ('893528390171', 'BẢNG HỌC SINH TP-B016 XANH (5404-TL)', 'Cái'),
  ('893528390173', 'BẢNG HỌC SINH TP-B016 PLUS/T100 (5404-TL)', 'Cái'),
  ('893528390436', 'BẢNG HỌC SINH TP-B018 PLUS XANH (A5404-TL)', 'Cái'),
  ('893528390522', '(KSD)BÌA NÚT A4 FO-CBF009 MÀU PASTEL T10 XANH LÁ (A5404-TL)', 'Cái'),
  ('893532401633', 'BẢNG HỌC SINH TP-B09/AK (5404-TL)', 'Cái'),
  ('893604045359', 'BẢNG BỘ HỌC SINH B 015/DO (5404-TL)', 'Cái'),
  ('893500181463', 'BÚT DẠ QUANG XANH BIỂN HL-03 (10C/H) (5404-TL)', 'Cái'),
  ('893500186693', 'BÚT GEL TP-GEL039 XANH (20C/H) (A5404-TL)', 'Cái'),
  ('893532400290', 'BÚT BI TL-105  ĐỎ TL (20C/H) (5404-TL)', 'Cái'),
  ('893532404049', 'BÚT GELB-035 ĐEN 0.5 HỘP 20/T960 (5404-TL)', 'Cái'),
  ('893532404102', 'BÚT BI TL-095 ĐEN /LUCK VỈ 3 CÂY (5404-TL)', 'Cái'),
  ('893532404187', 'BÚT GEL GEL-073/AK XANH HỘP 20 (5404-TL)', 'Cái'),
  ('893500182069', 'VIẾT CHÌ KHÚC PC-09 (20C/H) (5404-TL)', 'Cái'),
  ('893532404106', 'BÚT BI TL-105 ĐEN /LUCK VỈ 3 CÂY (5404-TL)', 'Cái'),
  ('893532402826', 'BÚT GEL GEL-048/HS XANH HỘP 10 (5404-TL)', 'Cái'),
  ('893604045300', 'BÌA NÚT F4 IN Ô VUÔNG FO CBF01 TRONG (5404-TL)', 'Cái'),
  ('893532403199', 'BÌNH GIỮ NHIỆT VF-001/DS HỒNG 750ML (5404-TL)', 'Cái'),
  ('893532403200', 'BÌNH GIỮ NHIỆT VF-001/DS XANH 750ML (5404-TL)', 'Cái'),
  ('893521946054', 'CRAYOLA - BỘ BÚT LÔNG 811324 8C/H - (T.LONG)', 'Cái'),
  ('893532400366', 'BÌA NÚT PASTEL F4 CBF-003_HỒNG TL (5404-TL)', 'Cái'),
  ('893532400365', 'BÌA NÚT PASTEL F4 CBF-003_TRẮNG TL (5404-TL)', 'Cái'),
  ('893528390523', '(KSD) BÌA NÚT A4 FO-CBF009 MÀU PASTEL T10 XANH DƯƠNG (A5404-TL)', 'Cái'),
  ('893528390525', '(KSD)BÌA NÚT A4 FO-CBF009 MÀU PASTEL T10 TÍM (A5404-TL)', 'Cái'),
  ('893528390533', 'BÌA NÚT F4 FO-CBF010 MÀU PASTEL T10 TÍM (A5404-TL)', 'Cái'),
  ('893532400374', 'BÌA NÚT PASTEL F4 CBF-003 VÀNG TL (5404-TL)', 'Cái'),
  ('893532400427', 'BÌA NÚT PASTEL F4 CBF-003_ XANH TL (5404-TL)', 'Cái'),
  ('893604045228', 'BÌA NÚT A4 TRƠN FO CBF05 TRONG (5404-TL)', 'Cái'),
  ('893528390524', '(KSD)BÌA NÚT A4 FO-CBF009 MÀU PASTEL T10 HỒNG (A5404-TL)', 'Cái'),
  ('893532402377', 'SỔ LÒ XO A5 NÂU 120T KẺ NGANG MB-023/DS (5C/L) (5404-TL)', 'Cái'),
  ('893500184925', 'GIẤY KIỂM TRA TP-GKT08 5 ÔLY VUÔNG 2X2 (5404-TL)', 'Cái'),
  ('893500185962', 'GIẤY KIỂM TRA KẺ NGANG 20 TỜ TP-GKT14 (5404-TL)', 'Cái'),
  ('893532404683', 'BÚT LÔNG MÀU RỬA ĐƯỢC SWM-C013/DS 60 MÀU (5404-TL)', 'Cái'),
  ('893532401665', 'BÚT LÔNG MÀU ACRYLIC 2Đ ACM-C001 12 MÀU (5404-TL)', 'Cái'),
  ('893532401423', 'BÚT GEL GEL-042 ĐEN HỘP 20 (5404-TL)', 'Cái'),
  ('893500180034', 'BÚT BI XANH TL-027 (20C/H) (360 ĐỘ) (5404-TL)', 'Cái'),
  ('893500180376', 'BÚT BI XANH TL-079 (20C/H) (5404-TL)', 'Cái'),
  ('893605001096', '(KSD) KINGJIM - BIA CONG F4 7CM MAU XANH', 'Cái'),
  ('202990001194', 'BÌA LÓT LƯNG TIỀN MỆNH GIÁ 500', 'Cái'),
  ('202990001196', 'BÌA LÓT LƯNG TIỀN MỆNH GIÁ 100', 'Cái'),
  ('202990001197', 'BÌA LÓT LƯNG TIỀN MỆNH GIÁ 50', 'Cái'),
  ('202990001198', 'BÌA LÓT LƯNG TIỀN MỆNH GIÁ 20', 'Cái'),
  ('202990001199', 'BÌA LÓT LƯNG TIỀN MỆNH GIÁ 10', 'Cái'),
  ('893614194122', 'TẬP THUẬN TIẾN 96T DL100 4ÔLI BAO GIẤY THỦ CÔNG HỒNG', 'Cái'),
  ('893614194123', 'TẬP THUẬN TIẾN 96T DL100 4ÔLI BAO GIẤY THỦ CÔNG CAM', 'Cái'),
  ('893512826309', 'TẬP THUẬN TIẾN DL80 - TỆP GIẤY KIỂM TRA(20 TỜ/CUỐN)', 'Cái'),
  ('893512826003', 'TAP THUAN TIEN 200T DL60 - GIAO AN', 'Cái'),
  ('893512826036', 'TẬP SV THUẬN TIẾN 200T DL70 NGANG - THƯ PHÁP', 'Cái'),
  ('893512826068', '(KSD)-TẬP THUẬN TIẾN 200T DL60 - ĐÔNG HỒ', 'Cái'),
  ('893512826158', 'TẬP SV THUẬN TIẾN 200T DL60 ÔLI - NGANG - HEO BOO', 'Cái'),
  ('893512826166', '(KSD)-TẬP THUẬN TIẾN 200T DL80 4ÔLI - CHUỘT VÀNG', 'Cái'),
  ('893512826467', '(KSD)-TẬP THUẬN TIẾN 98T DL60 - GÁY VUÔNG BACK TO SCHOOL', 'Cái'),
  ('893512826470', '(KSD)-TẬP THUẬN TIẾN 98T DL70 - GÁY VUÔNG HAPPY DAY', 'Cái'),
  ('893512826479', 'TẬP SV THUẬN TIẾN 200T DL60 - GÁY VUÔNG TINH HOA ĐẤT VIỆT (SV01)', 'Cái'),
  ('893614194104', '(KSD)-TẬP THUẬN TIẾN 200T - DL80 4ÔLI - DOG CUTE (THCK0256)', 'Cái'),
  ('893614194107', '(KSD)-TẬP THUẬN TIẾN 96T DL80 4ÔLI - DOG CUTE', 'Cái'),
  ('893614194113', 'TẬP THUẬN TIẾN 96T DL100 5ÔLI BAO GIẤY THỦ CÔNG TÍM', 'Cái'),
  ('893614194114', 'TẬP THUẬN TIẾN 96T DL100 5ÔLI BAO GIẤY THỦ CÔNG ĐỎ', 'Cái'),
  ('893614194119', 'TẬP THUẬN TIẾN 96T DL100 4ÔLI BAO GIẤY THỦ CÔNG VÀNG', 'Cái'),
  ('893614194126', 'TẬP THUẬN TIẾN 96T DL100 4ÔLI GÁY VUÔNG BAO GIẤY BAO HÌNH', 'Cái'),
  ('893614194135', '(KSD)-TẬP THUẬN TIẾN 96T - DL95 4ÔLI - ANGLE 3D (THCK0256)', 'Cái'),
  ('893614194156', '(KSD)-TẬP THUẬN TIẾN 96T - DL60 4ÔLI - SHEEP LAND (THCK0256)', 'Cái'),
  ('893614194162', '(KSD)-TẬP THUẬN TIẾN 200T - DL60 4ÔLI - SHEEP LAND (THCK0256)', 'Cái'),
  ('893614194164', '(KSD)-TẬP THUẬN TIẾN 200T - DL60 4ÔLI - SINH VIÊN BTS', 'Cái'),
  ('893614194170', '(KSD)-TẬP THUẬN TIẾN 96T - DL120 4ÔLI - CHIPI (THCK0256)', 'Cái'),
  ('893614194181', '(KSD)-TAP THUAN TIEN 96T DL100 4OLY-5OLY HELLO PET', 'Cái'),
  ('893614194222', '(KSD)-TẬP THUẬN TIẾN 96T DL70 4ÔLI-NGANG CHUỘT NHÍ (BÌA TỰ HỦY)', 'Cái'),
  ('893614194328', 'TẬP THUẬN TIẾN 96T DL120 4ÔLI - CON CƯNG (THCK0256)', 'Cái'),
  ('893614194411', 'TẬP THUẬN TIẾN 200T DL80 4ÔLI - BEAR CUTE (THCK0256)', 'Cái'),
  ('203050311454', 'SỔ DA CK2  (0515-TTT)', 'Cái'),
  ('203050311455', 'SO DA CK4  (THUAN TIEN)', 'Cái'),
  ('893512825996', 'SỔ DA A4 DÀY (21X30CM)(0515-TTT)', 'Cái'),
  ('893512826053', 'SỔ CK7 DB ( 15X21CM)(0515-TTT)', 'Cái'),
  ('893512826056', 'SỔ DA F4 DÀY ( 21X32CM)(0515-TTT)', 'Cái'),
  ('893512826087', 'SỔ KẾ TÓAN  - 200 TRANG  19.8 *31.4', 'Cái'),
  ('893512826091', 'SỔ KẾ TÓAN  - 200 TRANG   23.5 *32 (0515-TTT)', 'Cái'),
  ('893512826097', 'SỔ DA CK9 ĐB (TTT-0515)', 'Cái'),
  ('893512826291', 'GIẤY PHOTO A3 EXCEL DL 80G/M2(0515-TTT)', 'Cái'),
  ('893512826350', 'GIẤY BAO TẬP 20 TỜ/XẤP (0515-TTT)', 'Cái'),
  ('893512826351', 'GIẤY BAO TẬP GAN 10 TỜ/XẤP (0515-TTT)', 'Cái'),
  ('893512826381', 'GIẤY BAO TẬP CAO CAP HAPPY 10 TỜ/XẤP (0515-TTT)', 'Cái'),
  ('893512826418', 'NHÃN DECAN  10 O TRUNG  4TỜ/XẤP (0515-TTT)', 'Cái'),
  ('893512826419', 'NHÃN DECAN  CAO CAP 4 O LỚN (0515-TTT)', 'Cái'),
  ('893512826422', 'NHÃN DECAN  10 O LỚN 4TỜ/XẤP (0515-TTT)', 'Cái'),
  ('893614194047', 'SỔ DA CK 1(THCK0515)', 'Cái'),
  ('893614194050', 'SỔ DA CK 5(THCK0515)', 'Cái'),
  ('893614194235', 'BÌA KÊ TAY TẬP BKT-01 THÂN THIỆN MÔI TRƯỜNG  (0515-TTT)', 'Cái'),
  ('893614194240', 'SỔ DA CK 7(THCK0515)', 'Cái'),
  ('893614194246', 'TỆP PHOTO 50TỜ -A4 DL70 (0515-TTT)', 'Cái'),
  ('893614194359', 'BAO TẬP NAI CAO CẤP TIBOOK (155 x 205mm) (10TỜ/CUỘN) (0515-TTT)', 'Cái'),
  ('893614194360', 'BAO TẬP SINH VIÊN TIBOOK (175 x 255mm)(10TỜ/CUỘN) (0515-TTT)', 'Cái'),
  ('893614194361', 'BAO SÁCH CẢI CÁCH TIBOOK (380 x 265mm)(10TỜ/CUỘN) (0515-TTT)', 'Cái'),
  ('203050311460', 'SỔ DA CK9', 'Cái'),
  ('893512826201', 'GIẤY PHOTO  A5  (TTONE ) -  DL 70G/M2 (0515-TTT)', 'Cái'),
  ('893512826349', 'BÌA KÊ TAY  TẬP  02 - KITTY (0515-TTT)', 'Cái'),
  ('893512826353', '(KSD-893512826381) GIAY BAO TAP CAO CAP HAPPY, CARO 10 TO XAP (THUAN TIEN)', 'Cái'),
  ('893512826347', 'BÌA KÊ TAY  TẬP  02 - BIG HERO (0515-TTT)', 'Cái'),
  ('893512826348', 'BÌA KÊ TAY  TẬP  02 - DOREMON (0515-TTT)', 'Cái'),
  ('893512826420', 'NHÃN DECAN  CAO CAP 6 O LỚN (0515-TTT)', 'Cái'),
  ('893512826189', 'TẬP THUẬN TIẾN 96T DL60 4ÔLI - 5ÔLI - HOA HỌC TRÒ', 'Cái'),
  ('893512826311', 'TẬP THUẬN TIẾN 96T DL95 4ÔLI - 5ÔLI - HOA NHỎ', 'Cái'),
  ('893614194239', 'SỔ DA CK 6(THCK0515)', 'Cái'),
  ('893512825916', 'TẬP THUẬN TIẾN 96T DL80 4ÔLI - HỌC SINH ABC', 'Cái'),
  ('893512826408', 'TẬP THUẬN TIẾN 96T DL60 ÔLI - 5ÔLI - NGANG MY FRIEND', 'Cái'),
  ('893512826344', 'BÌA KÊ TAY BIG HERO (0515-TTT)', 'Cái'),
  ('893614194120', 'TẬP THUẬN TIẾN 96T DL100 4ÔLI BAO GIẤY THỦ CÔNG TÍM', 'Cái'),
  ('203050311459', 'SỔ DA CK8  (0515-TTT)', 'Cái'),
  ('893614194236', 'BÌA KÊ TAY SÁCH BKS-01 THÂN THIỆN MÔI TRƯỜNG  (0515-TTT)', 'Cái'),
  ('893512826021', '(KSD)-TẬP THUẬN TIẾN 96T DL80 4ÔLI - CHUỘT VÀNG', 'Cái'),
  ('893614194116', 'TẬP THUẬN TIẾN 96T DL100 5ÔLI BAO- GIẤY THỦ CÔNG CAM', 'Cái'),
  ('893614194115', 'TẬP THUẬN TIẾN 96T DL100 5ÔLI BAO GIẤY THỦ CÔNG HỒNG', 'Cái'),
  ('893512826270', 'TẬP THUẬN TIẾN 200T DL60 - HOA HỌC TRÒ', 'Cái'),
  ('893512826315', 'TẬP THUẬN TIẾN 96T DL70 NGANG - TEEN', 'Cái'),
  ('893512826382', 'BAO TẬP NYLON -  GIẤY THỦ CÔNG (10TỜ/XẤP) (0515-TTT)', 'Cái'),
  ('203000700048', 'BÌA CỘT 3 DÂY GIẤY 7CM', 'Cái'),
  ('202990000945', 'DÂY CHỈ CỘT TIỀN 1KG/BÓ ±2 (BBVL0002)', 'Cái'),
  ('202990000944', 'DÂY CHỈ CỘT TIỀN 2KG/CUỘN ±2 (BBVL0002)', 'Cái'),
  ('202990001195', 'BÌA LÓT LƯNG TIỀN MỆNH GIÁ 200', 'Cái'),
  ('204029900985', 'GIẤY BÌA MÀU A4 (100 TỜ/XẤP)', 'Cái'),
  ('203000700047', 'BÌA CỘT 3 DÂY GIẤY 15CM', 'Cái'),
  ('202990000981', 'BÌA LÓT LƯNG TIỀN MỆNH GIÁ 500', 'Cái'),
  ('202990000982', 'BÌA LÓT LƯNG TIỀN  MỆNH GIÁ 200', 'Cái'),
  ('202990000975', 'DÂY CHỈ CỘT CHỨNG TỪ/CUỘN ±2 (BBVL0002)', 'Cái'),
  ('204019902422', 'GIẤY PHOTO E-BANK A4/70GSM CHIA 2', 'Cái'),
  ('885241351694', 'GIẤY PHOTO DELIGHT 70GSM KHỔ A4', 'Cái'),
  ('204019901865', 'GIẤY PHOTO SUPREME 70GSM KHỔ A3', 'Cái'),
  ('885241345091', 'GIẤY PHOTO SUPREME 80GSM KHỔ A3', 'Cái'),
  ('885241345939', 'GIẤY PHOTO IDEA WORK 80GSM KHỔ A4', 'Cái'),
  ('885241355681', 'GIẤY PHOTO DELIGHT 70GSM KHỔ A3', 'Cái'),
  ('885241356429', 'GIẤY PHOTO SUPREME 70GSM KHỔ A5', 'Cái'),
  ('204019901864', 'GIẤY PHOTO SUPREME 70GSM KHỔ A4', 'Cái'),
  ('899138913900', 'GIẤY IK COPY A4/70 (5404-TL)', 'Cái'),
  ('204019901953', 'DOUBLE A - GIẤY PHOTO DOUBLE A 70 GSM KHỔ A4 (VT)', 'Cái'),
  ('204019901954', 'DOUBLE A - GIẤY PHOTO DOUBLE A 80 GSM KHỔ A4 (VT)', 'Cái'),
  ('893512826266', 'GIẤY PHOTO A5 EXCEL DL 70G/M2 (0515-TTT)', 'Cái'),
  ('893512826267', 'GIẤY PHOTO A5 EXCEL DL 80G/M2 (0515-TTT)', 'Cái'),
  ('893512826204', 'GIẤY PHOTO  A4 EXCEL DL 80G/M2(0515-TTT)', 'Cái'),
  ('893512826203', 'GIẤY PHOTO  A4 EXCEL DL 70G/M2(0515-TTT)', 'Cái'),
  ('454952661369', 'MÁY TÍNH CASIO FX880BTG(MÀU ĐEN)(TL)(A4014)', 'Cái'),
  ('454952661147', 'MÁY TÍNH CASIO FX-580VN X-BU (MÀU XANH)(4014-BT)', 'Cái'),
  ('454952661148', 'MÁY TÍNH CASIO FX-580VN X-PK (MÀU HỒNG)(4014-BT)', 'Cái'),
  ('204030402646', 'KAMI -  GIẤY IN BILLL 65GSM 80-80 (BY)', 'Cái'),
  ('204030402645', 'KAMI -  GIẤY IN BILLL 65GSM 80-65 (BY)', 'Cái'),
  ('204030402641', 'KAMI - GIẤY IN NHIỆT 65GSM 57- 38 (BY)', 'Cái'),
  ('204030402830', 'GIẤY IN BILL MIMOSA - SUMIKURA 80X65MM (50C/TH) (0232-QHST)', 'Cái'),
  ('204030402644', 'KAMI -  GIẤY IN BILLL 65GSM 80-60 (BY)', 'Cái'),
  ('204030402643', 'KAMI - GIẤY IN BILLL  65GSM 80-45 (BY)', 'Cái'),
  ('454952660603', 'MÁY TÍNH CASIO FX-580VN X(MÀU ĐEN)(4014-BT)', 'Cái'),
  ('454952661370', 'MÁY TÍNH CASIO FX880BTG-BU(MÀU XANH)(TL)(A4014)', 'Cái'),
  ('454952661389', 'MÁY TÍNH CASIO FX880BTG-GY(MÀU XÁM)(TL)(A4014)', 'Cái'),
  ('893500184145', 'BĂNG KEO 5P 80YARDS BKT08 TRONG CÓ TEM (5404-TL)', 'Cái'),
  ('893532404754', 'BÚT ACRYLIC ĐẦU BRUSH ACM-C021 24+4 MÀU (5404-TL)', 'Cái'),
  ('893532404757', 'BÚT ACRYLIC ĐẦU BRUSH ACM-C022 36+6 MÀU (5404-TL)', 'Cái'),
  ('893607841004', 'BAO TẬP SV 255(5298-TNT)', 'Cái'),
  ('893607841010', 'BAO TẬP + GIẤY TC(5298-TNT)', 'Cái'),
  ('893535030942', 'LELE BROTHER ĐCLR MINI HALLOWEEN 6IN1 TDM-T001 60019646 (THKG0084)', 'Cái'),
  ('893535030931', 'CUTEROOM LR C.ROOM HỘP QUÀ GIÁNG SINH RUJ0RB0108 60019599 (THKG0084)', 'Cái'),
  ('203029907680', 'ROBOTIME ĐC MÔ HÌNH QUÁN CÀ PHÊ 17 DG162 60015178 (LL)', 'Cái'),
  ('203029907681', 'ROBOTIME ĐC PHÒNG TẮM BONG BÓNG DS018 60015378 (LL)', 'Cái'),
  ('203029907683', 'ROBOTIME LẮP RÁP CỬA HÀNG TRÁI CÂY DW003 60017097 (LL)', 'Cái'),
  ('203029907687', 'ROBOTIME ĐC VẸN TRÒN GIẤC NGỦ DW009 60017103 (LL)', 'Cái'),
  ('203029907694', 'ROBOTIME ĐC PHÒNG HỌC CỦA SAM DG102 60017122 (LL)', 'Cái'),
  ('203029907699', 'ROBOTIME QUÁN CÀ PHÊ LƯỜI DS020 60018870 (LL)', 'Cái'),
  ('203029907708', 'ROBOTIME ĐCLR TIỆM BURGER YUM YUM DW010 60019470 (LL)', 'Cái'),
  ('203029907709', 'ROBOTIME ĐCLR BÀN TRÀ NGỌT NGÀO DW011 60019471 (LL)', 'Cái'),
  ('203029907710', 'ROBOTIME ĐCLR QUẦY BAR VUI VẺ DW012 60019472 (LL)', 'Cái'),
  ('203029907723', 'ROBOTIME LẮP RÁP VƯỜN TRÀ NỞ RỘ DW013B (LL)', 'Cái'),
  ('203029907724', 'ROBOTIME ĐCLR PHÒNG TẮM BONG BÓNG DW014B 60020701 (LL)', 'Cái'),
  ('203029907728', 'ROBOTIME ĐCLR BAN CÔNG DWP08 60020707 (LL)', 'Cái'),
  ('203029907737', 'ROBOTIME ĐCLR TIỆM SÁCH KÝ ỨC DWS04B C60001184 (LL)', 'Cái'),
  ('203029907630', 'BOOKNOOK SAMPLE - BỘ LR BOOK NOOK JIU FEN C60001264 (THKG0084)', 'Cái'),
  ('203029907631', 'BOOKNOOK SAMPLE - BỘ LR BOOK NOOK GINZAN ONSEN C60001265 (THKG0084)', 'Cái'),
  ('203029907632', 'BOOKNOOK SAMPLE - BỘ LR BOOK NOOK THE ABANDONED SUBMARINE C60001266 (THKG0084)', 'Cái'),
  ('203029907635', 'BOOKNOOK SAMPLE - BỘ LR BOOK NOOK RENAISSANCE HOGWART C60001269 (THKG0084)', 'Cái'),
  ('695883853914', 'ZHEGAO ĐCLR HỘP QUÀ NHÀ GIÁNG SINH QL662023 60019657 (THKG0084)', 'Cái'),
  ('695883853915', 'ZHEGAO ĐCLR HỘP QUÀ GIÁNG SINH BÌNH AN QL662024 60019658 (THKG0084)', 'Cái'),
  ('695883853955', 'ZHEGAO ĐCLR NHÀ GIÁNG SINH TRONG RỪNG QL613001 60019659 (THKG0084)', 'Cái'),
  ('893535030091', 'DUY TÂM HALLOWEEN - ĐỒ CHƠI TRÁI BÍ DẺO 60016681 (THKG0084)', 'Cái'),
  ('893535030128', 'DUY TÂM HALLOWEEN 0 BỘ DIY TÚI NHIỀU MẪU 60016683 (THKG0084)', 'Cái'),
  ('893535030604', 'U-TRENDS BUỘC TÓC BEANIES MON025 60018220 (THKG0084)', 'Cái'),
  ('893535030818', 'NOBRAND BĂNG ĐÔ MÔI TỀU 60017130 (THKG0084)', 'Cái'),
  ('893535030930', 'CUTEROOM LR C.ROOM GIÁNG SINH NGỌT NGÀO RUJ0R0007 60019598 (THKG0084)', 'Cái'),
  ('893535030933', 'CUTEROOM KHO BÁU MA THUẬT 60019601 (THKG0084)', 'Cái'),
  ('893535030945', 'LELE BROTHER ĐCLR LỊCH HALLOWEEN TDM-T004 60019649 (THKG0084)', 'Cái'),
  ('893535030946', 'LELE BROTHER ĐCLR LỊCH XMAS TDM-T005 60019650 (THKG0084)', 'Cái'),
  ('893535030947', 'LELE BROTHER ĐCLR LỊCH XMAS TDM-T006 60019651 (THKG0084)', 'Cái'),
  ('694678511950', 'ROBOTIME ĐCLR XE NGỰA THẾ KỶ 19 ROBOTIME AMKA1 60019450 (THKG0084)', 'Cái'),
  ('893535030956', 'LELE BROTHER ĐCLR NGÔI NHÀ VAMPIRE TDM-T009 60019654 (THKG0084)', 'Cái'),
  ('893535031003', 'NOBRAND MÓC KHÓA GẤU PUPPY DỌN DẸP 60020116 (THKG0084)', 'Cái'),
  ('893535030943', 'LELE BROTHER ĐCLR ĐOÀN TÀU HALLOWEEN 6IN1 TDM-T002 60019647 (THKG0084)', 'Cái'),
  ('885241347785', 'GIẤY PHOTO IDEA MAX 70GSM KHỔ A3', 'Cái'),
  ('204019902935', 'GIẤY PHOTO SUPREME 80GSM KHỔ A5', 'Cái'),
  ('204019902603', 'DA - GIẤY PHOTO IK PLUS 70GSM KHỔ A5', 'Cái'),
  ('893521949005', 'BĂNG KEO 5P BKT10/FO TRONG CÓ TEM (5404-TL)', 'Cái'),
  ('893500184147', 'BĂNG KEO 5P 100YARDS BKT10 TRONG CÓ TEM (5404-TL)', 'Cái'),
  ('893532404753', 'BÚT ACRYLIC ĐẦU BRUSH ACM-C020 12+2 MÀU (5404-TL)', 'Cái'),
  ('237990000939', 'HỘP CƠM SCB (KHÔNG TÚI)', 'Cái'),
  ('203990402398', 'TUI COM GIU NHIET (SCB)', 'Cái'),
  ('209010000432', 'BO QUA TANG BINH GIU NHIET KEM HOP VA TUI (BBVL0002)', 'Cái'),
  ('201990002153', 'QUAI ĐEO KHẨU TRANG - HTUAN', 'Cái'),
  ('201990001817', 'PV 02-TÚI 3 CHIẾC KHẨU TRANG KHÁNG KHUẨN LAKA (NEW) (P.VÂN)', 'Cái'),
  ('203000500277', 'BÌA 20 LÁ NHỰA A4 MÀU XANH', 'Cái'),
  ('203000500279', 'BÌA 60 LÁ NHỰA A4 MÀU XANH', 'Cái'),
  ('201990002089', 'TG 10-TẤM CHỐNG GIỌT BẮN CÓ GỌNG (T.TÂM)', 'Cái'),
  ('201990001472', 'AD 02-NƯỚC RỬA TAY HASOCO HƯƠNG TRÀ XANH  500GR', 'Cái'),
  ('893850711546', 'GEL RỬA TAY KHÔ SENSE HEALTH 100ML (S.PLUS)', 'Cái'),
  ('205020002733', 'DA-BỘ HỘP + TÚI GIẤY', 'Cái'),
  ('231039901468', 'BAO LÌ XÌ SCB B 8', 'Cái'),
  ('203000300082', 'BÌA CÒNG A5 7CM', 'Cái'),
  ('203000500280', 'BÌA 100 LÁ NHỰA A4 MÀU XANH', 'Cái');

-- ─────────────────────────────────────────────
-- INVENTORY — tồn kho thực tế kho X1
-- ─────────────────────────────────────────────
SET @wh_x1 = (SELECT id FROM warehouses WHERE code = 'X1');

INSERT INTO inventory (product_id, warehouse_id, location_text, quantity, min_stock, status)
SELECT p.id, @wh_x1, t.loc, t.qty, 5, t.st
FROM (
  SELECT '201089900603' AS bc, 89 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '497405283100' AS bc, 1 AS qty, 'low' AS st, '1' AS loc UNION ALL
  SELECT '893600745700' AS bc, 1 AS qty, 'low' AS st, '1' AS loc UNION ALL
  SELECT '893600745885' AS bc, 16 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '893604439227' AS bc, 2 AS qty, 'low' AS st, '1' AS loc UNION ALL
  SELECT '893500182498' AS bc, 16 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '893532400319' AS bc, 21 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '893532402687' AS bc, 14 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '893532403700' AS bc, 20 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '893532403702' AS bc, 20 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '893532403712' AS bc, 60 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '207180000275' AS bc, 9 AS qty, 'warning' AS st, '1' AS loc UNION ALL
  SELECT '201089900605' AS bc, 75 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '693011453313' AS bc, 2 AS qty, 'low' AS st, '1' AS loc UNION ALL
  SELECT '693011457143' AS bc, 10 AS qty, 'warning' AS st, '1' AS loc UNION ALL
  SELECT '890118070640' AS bc, 3 AS qty, 'low' AS st, '1' AS loc UNION ALL
  SELECT '84511376854' AS bc, 1 AS qty, 'low' AS st, '1' AS loc UNION ALL
  SELECT '893621528075' AS bc, 1 AS qty, 'low' AS st, '1' AS loc UNION ALL
  SELECT '893500186095' AS bc, 24 AS qty, 'ok' AS st, '1' AS loc UNION ALL
  SELECT '203020300732' AS bc, 1 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '390000004767' AS bc, 2 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '390000022252' AS bc, 5 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '489293139266' AS bc, 7 AS qty, 'warning' AS st, '2' AS loc UNION ALL
  SELECT '693738490664' AS bc, 3 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '697200419305' AS bc, 11 AS qty, 'ok' AS st, '2' AS loc UNION ALL
  SELECT '893612739586' AS bc, 1 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '893533011212' AS bc, 2 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '893533011844' AS bc, 2 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '693325660014' AS bc, 3 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '899721429102' AS bc, 3 AS qty, 'low' AS st, '2' AS loc UNION ALL
  SELECT '497405281146' AS bc, 10 AS qty, 'warning' AS st, '3' AS loc UNION ALL
  SELECT '893500185709' AS bc, 6 AS qty, 'warning' AS st, '3' AS loc UNION ALL
  SELECT '893500185715' AS bc, 8 AS qty, 'warning' AS st, '3' AS loc UNION ALL
  SELECT '893500185721' AS bc, 6 AS qty, 'warning' AS st, '3' AS loc UNION ALL
  SELECT '893500185724' AS bc, 8 AS qty, 'warning' AS st, '3' AS loc UNION ALL
  SELECT '893500185727' AS bc, 13 AS qty, 'ok' AS st, '3' AS loc UNION ALL
  SELECT '893500185730' AS bc, 10 AS qty, 'warning' AS st, '3' AS loc UNION ALL
  SELECT '893500185736' AS bc, 8 AS qty, 'warning' AS st, '3' AS loc UNION ALL
  SELECT '203009900033' AS bc, 2 AS qty, 'low' AS st, '3' AS loc UNION ALL
  SELECT '893603872949' AS bc, 1 AS qty, 'low' AS st, '3' AS loc UNION ALL
  SELECT '893603872965' AS bc, 5 AS qty, 'low' AS st, '3' AS loc UNION ALL
  SELECT '893603872972' AS bc, 1 AS qty, 'low' AS st, '3' AS loc UNION ALL
  SELECT '893603872973' AS bc, 1 AS qty, 'low' AS st, '3' AS loc UNION ALL
  SELECT '893603872974' AS bc, 2 AS qty, 'low' AS st, '3' AS loc UNION ALL
  SELECT '893612245460' AS bc, 4 AS qty, 'low' AS st, '3' AS loc UNION ALL
  SELECT '893524610011' AS bc, 1 AS qty, 'low' AS st, '5' AS loc UNION ALL
  SELECT '893524611213' AS bc, 1 AS qty, 'low' AS st, '5' AS loc UNION ALL
  SELECT '693011452158' AS bc, 1 AS qty, 'low' AS st, '5' AS loc UNION ALL
  SELECT '893500184891' AS bc, 2 AS qty, 'low' AS st, '5' AS loc UNION ALL
  SELECT '693011451134' AS bc, 2 AS qty, 'low' AS st, '5' AS loc UNION ALL
  SELECT '692271102118' AS bc, 3 AS qty, 'low' AS st, '5' AS loc UNION ALL
  SELECT '697534655576' AS bc, 4 AS qty, 'low' AS st, '5' AS loc UNION ALL
  SELECT '697534555583' AS bc, 5 AS qty, 'low' AS st, '5' AS loc UNION ALL
  SELECT '697534655578' AS bc, 6 AS qty, 'warning' AS st, '5' AS loc UNION ALL
  SELECT '693011456750' AS bc, 15 AS qty, 'ok' AS st, '5' AS loc UNION ALL
  SELECT '893532401572' AS bc, 1 AS qty, 'low' AS st, '6' AS loc UNION ALL
  SELECT '893532403552' AS bc, 1 AS qty, 'low' AS st, '6' AS loc UNION ALL
  SELECT '893532403592' AS bc, 1 AS qty, 'low' AS st, '6' AS loc UNION ALL
  SELECT '693011454505' AS bc, 17 AS qty, 'ok' AS st, '9' AS loc UNION ALL
  SELECT '693011455048' AS bc, 12 AS qty, 'ok' AS st, '9' AS loc UNION ALL
  SELECT '207050001951' AS bc, 15 AS qty, 'ok' AS st, '9' AS loc UNION ALL
  SELECT '955623314785' AS bc, 1 AS qty, 'low' AS st, '10' AS loc UNION ALL
  SELECT '893528390492' AS bc, 4 AS qty, 'low' AS st, '10' AS loc UNION ALL
  SELECT '893528390493' AS bc, 2 AS qty, 'low' AS st, '10' AS loc UNION ALL
  SELECT '893603872969' AS bc, 5 AS qty, 'low' AS st, '10' AS loc UNION ALL
  SELECT '209010001202' AS bc, 2 AS qty, 'low' AS st, '12' AS loc UNION ALL
  SELECT '697357838698' AS bc, 7 AS qty, 'warning' AS st, '21' AS loc UNION ALL
  SELECT '204019903197' AS bc, 2 AS qty, 'low' AS st, '22' AS loc UNION ALL
  SELECT '204019902181' AS bc, 34 AS qty, 'ok' AS st, '23' AS loc UNION ALL
  SELECT '899138913920' AS bc, 15 AS qty, 'ok' AS st, '25' AS loc UNION ALL
  SELECT '893603872784' AS bc, 12 AS qty, 'ok' AS st, '30' AS loc UNION ALL
  SELECT '893621222065' AS bc, 12 AS qty, 'ok' AS st, '30' AS loc UNION ALL
  SELECT '893603872688' AS bc, 5 AS qty, 'low' AS st, '31' AS loc UNION ALL
  SELECT '893603872712' AS bc, 5 AS qty, 'low' AS st, '31' AS loc UNION ALL
  SELECT '893609256042' AS bc, 12 AS qty, 'ok' AS st, '32' AS loc UNION ALL
  SELECT '893621222243' AS bc, 12 AS qty, 'ok' AS st, '32' AS loc UNION ALL
  SELECT '692173495367' AS bc, 8 AS qty, 'warning' AS st, '33' AS loc UNION ALL
  SELECT '692173490495' AS bc, 2 AS qty, 'low' AS st, '33' AS loc UNION ALL
  SELECT '692173495756' AS bc, 8 AS qty, 'warning' AS st, '33' AS loc UNION ALL
  SELECT '692173495757' AS bc, 4 AS qty, 'low' AS st, '33' AS loc UNION ALL
  SELECT '692173496036' AS bc, 1 AS qty, 'low' AS st, '33' AS loc UNION ALL
  SELECT '693520537883' AS bc, 2 AS qty, 'low' AS st, '33' AS loc UNION ALL
  SELECT '694179842217' AS bc, 2 AS qty, 'low' AS st, '33' AS loc UNION ALL
  SELECT '694179845323' AS bc, 1 AS qty, 'low' AS st, '33' AS loc UNION ALL
  SELECT '693520537882' AS bc, 9 AS qty, 'warning' AS st, '33' AS loc UNION ALL
  SELECT '893621222020' AS bc, 12 AS qty, 'ok' AS st, '34' AS loc UNION ALL
  SELECT '693520535801' AS bc, 5 AS qty, 'low' AS st, '34' AS loc UNION ALL
  SELECT '201089900559' AS bc, 60 AS qty, 'ok' AS st, '40' AS loc UNION ALL
  SELECT '201089900560' AS bc, 60 AS qty, 'ok' AS st, '40' AS loc UNION ALL
  SELECT '893600745874' AS bc, 24 AS qty, 'ok' AS st, '40' AS loc UNION ALL
  SELECT '893609256573' AS bc, 12 AS qty, 'ok' AS st, '40' AS loc UNION ALL
  SELECT '693520535303' AS bc, 8 AS qty, 'warning' AS st, '40' AS loc UNION ALL
  SELECT '693520539294' AS bc, 2 AS qty, 'low' AS st, '40' AS loc UNION ALL
  SELECT '697308372022' AS bc, 9 AS qty, 'warning' AS st, '40' AS loc UNION ALL
  SELECT '893603872685' AS bc, 5 AS qty, 'low' AS st, '41' AS loc UNION ALL
  SELECT '893603872702' AS bc, 10 AS qty, 'warning' AS st, '41' AS loc UNION ALL
  SELECT '893609256205' AS bc, 20 AS qty, 'ok' AS st, '41' AS loc UNION ALL
  SELECT '893621222147' AS bc, 50 AS qty, 'ok' AS st, '41' AS loc UNION ALL
  SELECT '893609256324' AS bc, 6 AS qty, 'warning' AS st, '42' AS loc UNION ALL
  SELECT '893609256325' AS bc, 12 AS qty, 'ok' AS st, '42' AS loc UNION ALL
  SELECT '893609256326' AS bc, 6 AS qty, 'warning' AS st, '42' AS loc UNION ALL
  SELECT '893609256526' AS bc, 6 AS qty, 'warning' AS st, '42' AS loc UNION ALL
  SELECT '893609256901' AS bc, 5 AS qty, 'low' AS st, '42' AS loc UNION ALL
  SELECT '893603872916' AS bc, 25 AS qty, 'ok' AS st, '44' AS loc UNION ALL
  SELECT '893609256779' AS bc, 48 AS qty, 'ok' AS st, '44' AS loc UNION ALL
  SELECT '893609256902' AS bc, 5 AS qty, 'low' AS st, '44' AS loc UNION ALL
  SELECT '893621222045' AS bc, 48 AS qty, 'ok' AS st, '44' AS loc UNION ALL
  SELECT '204029901038' AS bc, 2 AS qty, 'low' AS st, '51' AS loc UNION ALL
  SELECT '692173499619' AS bc, 10 AS qty, 'warning' AS st, '51' AS loc UNION ALL
  SELECT '694179842800' AS bc, 1 AS qty, 'low' AS st, '51' AS loc UNION ALL
  SELECT '694179844972' AS bc, 1 AS qty, 'low' AS st, '51' AS loc UNION ALL
  SELECT '694179845595' AS bc, 6 AS qty, 'warning' AS st, '51' AS loc UNION ALL
  SELECT '697350400083' AS bc, 3 AS qty, 'low' AS st, '51' AS loc UNION ALL
  SELECT '693520531031' AS bc, 60 AS qty, 'ok' AS st, '52' AS loc UNION ALL
  SELECT '893612739073' AS bc, 7 AS qty, 'warning' AS st, '54' AS loc UNION ALL
  SELECT '692173495504' AS bc, 2 AS qty, 'low' AS st, '54' AS loc UNION ALL
  SELECT '692173495576' AS bc, 1 AS qty, 'low' AS st, '54' AS loc UNION ALL
  SELECT '692173497236' AS bc, 1 AS qty, 'low' AS st, '54' AS loc UNION ALL
  SELECT '692173497334' AS bc, 1 AS qty, 'low' AS st, '54' AS loc UNION ALL
  SELECT '694179846041' AS bc, 5 AS qty, 'low' AS st, '54' AS loc UNION ALL
  SELECT '201990002496' AS bc, 60 AS qty, 'ok' AS st, '55' AS loc UNION ALL
  SELECT '201990002521' AS bc, 3 AS qty, 'low' AS st, '57' AS loc UNION ALL
  SELECT '704315006152' AS bc, 2 AS qty, 'low' AS st, '57' AS loc UNION ALL
  SELECT '201990002497' AS bc, 3 AS qty, 'low' AS st, '57' AS loc UNION ALL
  SELECT '201990002499' AS bc, 1 AS qty, 'low' AS st, '60' AS loc UNION ALL
  SELECT '201990002512' AS bc, 4 AS qty, 'low' AS st, '60' AS loc UNION ALL
  SELECT '201990002563' AS bc, 22 AS qty, 'ok' AS st, '60' AS loc UNION ALL
  SELECT '201990002575' AS bc, 2 AS qty, 'low' AS st, '60' AS loc UNION ALL
  SELECT '202010902710' AS bc, 1 AS qty, 'low' AS st, '60' AS loc UNION ALL
  SELECT '693520539018' AS bc, 8 AS qty, 'warning' AS st, '61' AS loc UNION ALL
  SELECT '694179845613' AS bc, 56 AS qty, 'ok' AS st, '62' AS loc UNION ALL
  SELECT '692173498553' AS bc, 1 AS qty, 'low' AS st, '63' AS loc UNION ALL
  SELECT '204990000030' AS bc, 137 AS qty, 'ok' AS st, '70' AS loc UNION ALL
  SELECT '885241343715' AS bc, 6 AS qty, 'warning' AS st, '70' AS loc UNION ALL
  SELECT '207130000213' AS bc, 22 AS qty, 'ok' AS st, '80' AS loc UNION ALL
  SELECT '202990001019' AS bc, 19 AS qty, 'ok' AS st, '81' AS loc UNION ALL
  SELECT '202990001026' AS bc, 4 AS qty, 'low' AS st, '81' AS loc UNION ALL
  SELECT '893601333309' AS bc, 47 AS qty, 'ok' AS st, '83' AS loc UNION ALL
  SELECT '893532403626' AS bc, 780 AS qty, 'ok' AS st, '101' AS loc UNION ALL
  SELECT '893532403628' AS bc, 1712 AS qty, 'ok' AS st, '102' AS loc UNION ALL
  SELECT '893532403627' AS bc, 480 AS qty, 'ok' AS st, '103' AS loc UNION ALL
  SELECT '201990001572' AS bc, 56 AS qty, 'ok' AS st, '110' AS loc UNION ALL
  SELECT '201990002090' AS bc, 15 AS qty, 'ok' AS st, '111' AS loc UNION ALL
  SELECT '204990000028' AS bc, 30 AS qty, 'ok' AS st, '112' AS loc UNION ALL
  SELECT '204990000037' AS bc, 133 AS qty, 'ok' AS st, '130' AS loc UNION ALL
  SELECT '201990001981' AS bc, 63 AS qty, 'ok' AS st, '131' AS loc UNION ALL
  SELECT '201990002211' AS bc, 2 AS qty, 'low' AS st, '131' AS loc UNION ALL
  SELECT '201990002640' AS bc, 1 AS qty, 'low' AS st, '131' AS loc UNION ALL
  SELECT '204990000036' AS bc, 110 AS qty, 'ok' AS st, '141' AS loc UNION ALL
  SELECT '201990001942' AS bc, 2 AS qty, 'low' AS st, '142' AS loc UNION ALL
  SELECT '201990002194' AS bc, 3 AS qty, 'low' AS st, '142' AS loc UNION ALL
  SELECT '201990002196' AS bc, 9 AS qty, 'warning' AS st, '142' AS loc UNION ALL
  SELECT '201990002197' AS bc, 3 AS qty, 'low' AS st, '142' AS loc UNION ALL
  SELECT '201990002202' AS bc, 2 AS qty, 'low' AS st, '142' AS loc UNION ALL
  SELECT '201990001951' AS bc, 8 AS qty, 'warning' AS st, '143' AS loc UNION ALL
  SELECT '893532401114' AS bc, 2 AS qty, 'low' AS st, '152' AS loc UNION ALL
  SELECT '893532401124' AS bc, 2 AS qty, 'low' AS st, '152' AS loc UNION ALL
  SELECT '202000302203' AS bc, 385 AS qty, 'ok' AS st, '161' AS loc UNION ALL
  SELECT '202000302205' AS bc, 45 AS qty, 'ok' AS st, '162' AS loc UNION ALL
  SELECT '202000302206' AS bc, 63 AS qty, 'ok' AS st, '163' AS loc UNION ALL
  SELECT '202000302204' AS bc, 54 AS qty, 'ok' AS st, '164' AS loc UNION ALL
  SELECT '202000302207' AS bc, 17 AS qty, 'ok' AS st, '171' AS loc UNION ALL
  SELECT '202990001358' AS bc, 34 AS qty, 'ok' AS st, '174' AS loc UNION ALL
  SELECT '202000302474' AS bc, 167 AS qty, 'ok' AS st, '175' AS loc UNION ALL
  SELECT '893600880001' AS bc, 110 AS qty, 'ok' AS st, '183' AS loc UNION ALL
  SELECT '893600880003' AS bc, 100 AS qty, 'ok' AS st, '183' AS loc UNION ALL
  SELECT '893600880021' AS bc, 45 AS qty, 'ok' AS st, '183' AS loc UNION ALL
  SELECT '893600880041' AS bc, 13 AS qty, 'ok' AS st, '183' AS loc UNION ALL
  SELECT '893501581236' AS bc, 84 AS qty, 'ok' AS st, '184' AS loc UNION ALL
  SELECT '252000520049' AS bc, 8 AS qty, 'warning' AS st, '191' AS loc UNION ALL
  SELECT '200060100237' AS bc, 19 AS qty, 'ok' AS st, '191' AS loc UNION ALL
  SELECT '202000302475' AS bc, 8 AS qty, 'warning' AS st, '201' AS loc UNION ALL
  SELECT '893512826202' AS bc, 9 AS qty, 'warning' AS st, '203' AS loc UNION ALL
  SELECT '204019902025' AS bc, 34 AS qty, 'ok' AS st, '203' AS loc UNION ALL
  SELECT '203000200017' AS bc, 14 AS qty, 'ok' AS st, '205' AS loc UNION ALL
  SELECT '899138913639' AS bc, 2 AS qty, 'low' AS st, '206' AS loc UNION ALL
  SELECT '201089900604' AS bc, 54 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893500180246' AS bc, 4 AS qty, 'low' AS st, '210' AS loc UNION ALL
  SELECT '893532403703' AS bc, 53 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893500181002' AS bc, 1 AS qty, 'low' AS st, '210' AS loc UNION ALL
  SELECT '893500181895' AS bc, 33 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893500183036' AS bc, 27 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893500184056' AS bc, 1 AS qty, 'low' AS st, '210' AS loc UNION ALL
  SELECT '893521948203' AS bc, 1 AS qty, 'low' AS st, '210' AS loc UNION ALL
  SELECT '893532401663' AS bc, 1 AS qty, 'low' AS st, '210' AS loc UNION ALL
  SELECT '893532402163' AS bc, 2 AS qty, 'low' AS st, '210' AS loc UNION ALL
  SELECT '893532402179' AS bc, 2 AS qty, 'low' AS st, '210' AS loc UNION ALL
  SELECT '893532402188' AS bc, 14 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893532402189' AS bc, 1 AS qty, 'low' AS st, '210' AS loc UNION ALL
  SELECT '893532402303' AS bc, 22 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893532403701' AS bc, 20 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893532404022' AS bc, 95 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893532404023' AS bc, 99 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '201089900601' AS bc, 78 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '201089900602' AS bc, 76 AS qty, 'ok' AS st, '210' AS loc UNION ALL
  SELECT '893532401049' AS bc, 10 AS qty, 'warning' AS st, '210' AS loc UNION ALL
  SELECT '893532401495' AS bc, 6 AS qty, 'warning' AS st, '211' AS loc UNION ALL
  SELECT '893532401793' AS bc, 8 AS qty, 'warning' AS st, '211' AS loc UNION ALL
  SELECT '893532403042' AS bc, 2 AS qty, 'low' AS st, '211' AS loc UNION ALL
  SELECT '893532403321' AS bc, 7 AS qty, 'warning' AS st, '211' AS loc UNION ALL
  SELECT '893532403705' AS bc, 19 AS qty, 'ok' AS st, '211' AS loc UNION ALL
  SELECT '893532403707' AS bc, 13 AS qty, 'ok' AS st, '211' AS loc UNION ALL
  SELECT '893607339011' AS bc, 1 AS qty, 'low' AS st, '212' AS loc UNION ALL
  SELECT '893532403710' AS bc, 43 AS qty, 'ok' AS st, '212' AS loc UNION ALL
  SELECT '893607339010' AS bc, 3 AS qty, 'low' AS st, '212' AS loc UNION ALL
  SELECT '893600880059' AS bc, 23 AS qty, 'ok' AS st, '212' AS loc UNION ALL
  SELECT '203020201694' AS bc, 15 AS qty, 'ok' AS st, '213' AS loc UNION ALL
  SELECT '885874175071' AS bc, 27 AS qty, 'ok' AS st, '214' AS loc UNION ALL
  SELECT '885874171688' AS bc, 30 AS qty, 'ok' AS st, '215' AS loc UNION ALL
  SELECT '885874171855' AS bc, 1 AS qty, 'low' AS st, '215' AS loc UNION ALL
  SELECT '203020201648' AS bc, 12 AS qty, 'ok' AS st, '215' AS loc UNION ALL
  SELECT '893500184115' AS bc, 1 AS qty, 'low' AS st, '220' AS loc UNION ALL
  SELECT '893500184793' AS bc, 1 AS qty, 'low' AS st, '220' AS loc UNION ALL
  SELECT '893500184942' AS bc, 2 AS qty, 'low' AS st, '220' AS loc UNION ALL
  SELECT '893500186549' AS bc, 1 AS qty, 'low' AS st, '220' AS loc UNION ALL
  SELECT '893500186742' AS bc, 4 AS qty, 'low' AS st, '220' AS loc UNION ALL
  SELECT '893500186784' AS bc, 1 AS qty, 'low' AS st, '220' AS loc UNION ALL
  SELECT '893532400563' AS bc, 17 AS qty, 'ok' AS st, '220' AS loc UNION ALL
  SELECT '893532400775' AS bc, 2 AS qty, 'low' AS st, '220' AS loc UNION ALL
  SELECT '893604045504' AS bc, 15 AS qty, 'ok' AS st, '220' AS loc UNION ALL
  SELECT '893532403605' AS bc, 1 AS qty, 'low' AS st, '221' AS loc UNION ALL
  SELECT '893532403606' AS bc, 2 AS qty, 'low' AS st, '221' AS loc UNION ALL
  SELECT '893500185325' AS bc, 20 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500180466' AS bc, 99 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500180037' AS bc, 27 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500180467' AS bc, 69 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500180470' AS bc, 100 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500181022' AS bc, 14 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500185346' AS bc, 1 AS qty, 'low' AS st, '222' AS loc UNION ALL
  SELECT '893500185362' AS bc, 80 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500185469' AS bc, 28 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500186180' AS bc, 1 AS qty, 'low' AS st, '222' AS loc UNION ALL
  SELECT '893500186628' AS bc, 61 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893532400436' AS bc, 54 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893532401708' AS bc, 87 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893532403642' AS bc, 10 AS qty, 'warning' AS st, '222' AS loc UNION ALL
  SELECT '893532403821' AS bc, 34 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893532400437' AS bc, 41 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893532403822' AS bc, 242 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500185344' AS bc, 73 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893532401620' AS bc, 85 AS qty, 'ok' AS st, '222' AS loc UNION ALL
  SELECT '893500184850' AS bc, 5 AS qty, 'low' AS st, '223' AS loc UNION ALL
  SELECT '893500186992' AS bc, 30 AS qty, 'ok' AS st, '223' AS loc UNION ALL
  SELECT '893532401726' AS bc, 10 AS qty, 'warning' AS st, '223' AS loc UNION ALL
  SELECT '893532404015' AS bc, 7 AS qty, 'warning' AS st, '223' AS loc UNION ALL
  SELECT '206030002972' AS bc, 8 AS qty, 'warning' AS st, '223' AS loc UNION ALL
  SELECT '202000508181' AS bc, 11 AS qty, 'ok' AS st, '223' AS loc UNION ALL
  SELECT '200080011890' AS bc, 308 AS qty, 'ok' AS st, '224' AS loc UNION ALL
  SELECT '893500186862' AS bc, 8 AS qty, 'warning' AS st, '225' AS loc UNION ALL
  SELECT '893532401981' AS bc, 2 AS qty, 'low' AS st, '225' AS loc UNION ALL
  SELECT '893532401983' AS bc, 4 AS qty, 'low' AS st, '225' AS loc UNION ALL
  SELECT '893532401985' AS bc, 2 AS qty, 'low' AS st, '225' AS loc UNION ALL
  SELECT '893532401986' AS bc, 3 AS qty, 'low' AS st, '225' AS loc UNION ALL
  SELECT '893532401989' AS bc, 3 AS qty, 'low' AS st, '225' AS loc UNION ALL
  SELECT '893604045741' AS bc, 17 AS qty, 'ok' AS st, '225' AS loc UNION ALL
  SELECT '497756417703' AS bc, 2 AS qty, 'low' AS st, '226' AS loc UNION ALL
  SELECT '893600745888' AS bc, 2 AS qty, 'low' AS st, '226' AS loc UNION ALL
  SELECT '893600745889' AS bc, 5 AS qty, 'low' AS st, '226' AS loc UNION ALL
  SELECT '893600745890' AS bc, 3 AS qty, 'low' AS st, '226' AS loc UNION ALL
  SELECT '893600745419' AS bc, 29 AS qty, 'ok' AS st, '226' AS loc UNION ALL
  SELECT '204029901143' AS bc, 8 AS qty, 'warning' AS st, '231' AS loc UNION ALL
  SELECT '231990002351' AS bc, 500 AS qty, 'ok' AS st, '231' AS loc UNION ALL
  SELECT '231990002352' AS bc, 500 AS qty, 'ok' AS st, '231' AS loc UNION ALL
  SELECT '231039901619' AS bc, 752 AS qty, 'ok' AS st, '232' AS loc UNION ALL
  SELECT '231039901620' AS bc, 225 AS qty, 'ok' AS st, '232' AS loc UNION ALL
  SELECT '233069900659' AS bc, 327 AS qty, 'ok' AS st, '233' AS loc UNION ALL
  SELECT '490250541753' AS bc, 12 AS qty, 'ok' AS st, '241' AS loc UNION ALL
  SELECT '490250525642' AS bc, 58 AS qty, 'ok' AS st, '241' AS loc UNION ALL
  SELECT '490250521045' AS bc, 59 AS qty, 'ok' AS st, '241' AS loc UNION ALL
  SELECT '490250541359' AS bc, 68 AS qty, 'ok' AS st, '241' AS loc UNION ALL
  SELECT '490250541749' AS bc, 57 AS qty, 'ok' AS st, '241' AS loc UNION ALL
  SELECT '490250546178' AS bc, 83 AS qty, 'ok' AS st, '241' AS loc UNION ALL
  SELECT '490250558190' AS bc, 74 AS qty, 'ok' AS st, '242' AS loc UNION ALL
  SELECT '490250545104' AS bc, 63 AS qty, 'ok' AS st, '242' AS loc UNION ALL
  SELECT '490250567396' AS bc, 76 AS qty, 'ok' AS st, '242' AS loc UNION ALL
  SELECT '490250567397' AS bc, 55 AS qty, 'ok' AS st, '242' AS loc UNION ALL
  SELECT '490250545067' AS bc, 70 AS qty, 'ok' AS st, '242' AS loc UNION ALL
  SELECT '490250534288' AS bc, 95 AS qty, 'ok' AS st, '243' AS loc UNION ALL
  SELECT '490250534287' AS bc, 71 AS qty, 'ok' AS st, '243' AS loc UNION ALL
  SELECT '490250544286' AS bc, 46 AS qty, 'ok' AS st, '243' AS loc UNION ALL
  SELECT '490250508569' AS bc, 119 AS qty, 'ok' AS st, '243' AS loc UNION ALL
  SELECT '490250508575' AS bc, 54 AS qty, 'ok' AS st, '243' AS loc UNION ALL
  SELECT '490250515465' AS bc, 132 AS qty, 'ok' AS st, '244' AS loc UNION ALL
  SELECT '490250542423' AS bc, 18 AS qty, 'ok' AS st, '244' AS loc UNION ALL
  SELECT '490250542425' AS bc, 162 AS qty, 'ok' AS st, '244' AS loc UNION ALL
  SELECT '490250548202' AS bc, 104 AS qty, 'ok' AS st, '245' AS loc UNION ALL
  SELECT '490250508568' AS bc, 8 AS qty, 'warning' AS st, '246' AS loc UNION ALL
  SELECT '490250567393' AS bc, 6 AS qty, 'warning' AS st, '246' AS loc UNION ALL
  SELECT '490250567395' AS bc, 9 AS qty, 'warning' AS st, '246' AS loc UNION ALL
  SELECT '490250567398' AS bc, 10 AS qty, 'warning' AS st, '246' AS loc UNION ALL
  SELECT '893603872346' AS bc, 100 AS qty, 'ok' AS st, '250' AS loc UNION ALL
  SELECT '893603872412' AS bc, 10 AS qty, 'warning' AS st, '251' AS loc UNION ALL
  SELECT '893603872315' AS bc, 40 AS qty, 'ok' AS st, '252' AS loc UNION ALL
  SELECT '893603872223' AS bc, 50 AS qty, 'ok' AS st, '254' AS loc UNION ALL
  SELECT '893612245377' AS bc, 562 AS qty, 'ok' AS st, '255' AS loc UNION ALL
  SELECT '893612245378' AS bc, 41 AS qty, 'ok' AS st, '255' AS loc UNION ALL
  SELECT '697630936071' AS bc, 2 AS qty, 'low' AS st, '258' AS loc UNION ALL
  SELECT '880220301444' AS bc, 59 AS qty, 'ok' AS st, '258' AS loc UNION ALL
  SELECT '880220303226' AS bc, 522 AS qty, 'ok' AS st, '258' AS loc UNION ALL
  SELECT '692424740885' AS bc, 96 AS qty, 'ok' AS st, '258' AS loc UNION ALL
  SELECT '880220303231' AS bc, 30 AS qty, 'ok' AS st, '258' AS loc UNION ALL
  SELECT '880220303233' AS bc, 82 AS qty, 'ok' AS st, '258' AS loc UNION ALL
  SELECT '880220352213' AS bc, 17 AS qty, 'ok' AS st, '258' AS loc UNION ALL
  SELECT '880220376113' AS bc, 57 AS qty, 'ok' AS st, '258' AS loc UNION ALL
  SELECT '697630936070' AS bc, 7 AS qty, 'warning' AS st, '259' AS loc UNION ALL
  SELECT '893603872681' AS bc, 95 AS qty, 'ok' AS st, '261' AS loc UNION ALL
  SELECT '697465158175' AS bc, 24 AS qty, 'ok' AS st, '263' AS loc UNION ALL
  SELECT '893603872319' AS bc, 120 AS qty, 'ok' AS st, '265' AS loc UNION ALL
  SELECT '694862880307' AS bc, 104 AS qty, 'ok' AS st, '266' AS loc UNION ALL
  SELECT '893612245335' AS bc, 527 AS qty, 'ok' AS st, '266' AS loc UNION ALL
  SELECT '200080096203' AS bc, 93 AS qty, 'ok' AS st, '279' AS loc UNION ALL
  SELECT '880220350231' AS bc, 47 AS qty, 'ok' AS st, '279' AS loc UNION ALL
  SELECT '880220350238' AS bc, 35 AS qty, 'ok' AS st, '279' AS loc UNION ALL
  SELECT '880220375920' AS bc, 5 AS qty, 'low' AS st, '279' AS loc UNION ALL
  SELECT '692424748035' AS bc, 17 AS qty, 'ok' AS st, '279' AS loc UNION ALL
  SELECT '880220350213' AS bc, 83 AS qty, 'ok' AS st, '279' AS loc UNION ALL
  SELECT '893612245375' AS bc, 216 AS qty, 'ok' AS st, '280' AS loc UNION ALL
  SELECT '893521946071' AS bc, 4 AS qty, 'low' AS st, '430' AS loc UNION ALL
  SELECT '203020703606' AS bc, 24 AS qty, 'ok' AS st, '451' AS loc UNION ALL
  SELECT '203020703414' AS bc, 28 AS qty, 'ok' AS st, '452' AS loc UNION ALL
  SELECT '203020703454' AS bc, 6 AS qty, 'warning' AS st, '453' AS loc UNION ALL
  SELECT '203020703468' AS bc, 3 AS qty, 'low' AS st, '454' AS loc UNION ALL
  SELECT '203020703339' AS bc, 2328 AS qty, 'ok' AS st, '461' AS loc UNION ALL
  SELECT '203020703427' AS bc, 936 AS qty, 'ok' AS st, '481' AS loc UNION ALL
  SELECT '203020703448' AS bc, 3337 AS qty, 'ok' AS st, '491' AS loc UNION ALL
  SELECT '203020703425' AS bc, 1554 AS qty, 'ok' AS st, '501' AS loc UNION ALL
  SELECT '203020703352' AS bc, 132 AS qty, 'ok' AS st, '502' AS loc UNION ALL
  SELECT '203020703607' AS bc, 24 AS qty, 'ok' AS st, '511' AS loc UNION ALL
  SELECT '203020703447' AS bc, 1167 AS qty, 'ok' AS st, '512' AS loc UNION ALL
  SELECT '203020703455' AS bc, 675 AS qty, 'ok' AS st, '521' AS loc UNION ALL
  SELECT '203020703428' AS bc, 100 AS qty, 'ok' AS st, '522' AS loc UNION ALL
  SELECT '203020703481' AS bc, 6 AS qty, 'warning' AS st, '523' AS loc UNION ALL
  SELECT '203020703465' AS bc, 30 AS qty, 'ok' AS st, '524' AS loc UNION ALL
  SELECT '203020703424' AS bc, 30 AS qty, 'ok' AS st, '531' AS loc UNION ALL
  SELECT '203020703426' AS bc, 2240 AS qty, 'ok' AS st, '532' AS loc UNION ALL
  SELECT '203020703446' AS bc, 426 AS qty, 'ok' AS st, '541' AS loc UNION ALL
  SELECT '203020703483' AS bc, 102 AS qty, 'ok' AS st, '542' AS loc UNION ALL
  SELECT '203020703401' AS bc, 2172 AS qty, 'ok' AS st, '551' AS loc UNION ALL
  SELECT '203020703421' AS bc, 2340 AS qty, 'ok' AS st, '561' AS loc UNION ALL
  SELECT '203020703422' AS bc, 3252 AS qty, 'ok' AS st, '562' AS loc UNION ALL
  SELECT '203020703423' AS bc, 994 AS qty, 'ok' AS st, '563' AS loc UNION ALL
  SELECT '203020703453' AS bc, 12 AS qty, 'ok' AS st, '564' AS loc UNION ALL
  SELECT '203020703480' AS bc, 3 AS qty, 'low' AS st, '564' AS loc UNION ALL
  SELECT '203020703482' AS bc, 764 AS qty, 'ok' AS st, '571' AS loc UNION ALL
  SELECT '203020703369' AS bc, 12 AS qty, 'ok' AS st, '572' AS loc UNION ALL
  SELECT '203020703358' AS bc, 12 AS qty, 'ok' AS st, '573' AS loc UNION ALL
  SELECT '203020703475' AS bc, 31 AS qty, 'ok' AS st, '574' AS loc UNION ALL
  SELECT '203020703443' AS bc, 30 AS qty, 'ok' AS st, '591' AS loc UNION ALL
  SELECT '203020703479' AS bc, 17 AS qty, 'ok' AS st, '591' AS loc UNION ALL
  SELECT '201990002205' AS bc, 10 AS qty, 'warning' AS st, '600' AS loc UNION ALL
  SELECT '201049901923' AS bc, 4 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201049901906' AS bc, 1 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201049901907' AS bc, 4 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201049901908' AS bc, 1 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201049901913' AS bc, 2 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201049901919' AS bc, 1 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201049901922' AS bc, 3 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201049901925' AS bc, 3 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201049902146' AS bc, 6 AS qty, 'warning' AS st, '601' AS loc UNION ALL
  SELECT '201049902148' AS bc, 3 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201990001956' AS bc, 7 AS qty, 'warning' AS st, '601' AS loc UNION ALL
  SELECT '201990001966' AS bc, 2 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201990002206' AS bc, 1 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '201990002658' AS bc, 2 AS qty, 'low' AS st, '601' AS loc UNION ALL
  SELECT '204029901797' AS bc, 5 AS qty, 'low' AS st, '602' AS loc UNION ALL
  SELECT '204029901773' AS bc, 2 AS qty, 'low' AS st, '602' AS loc UNION ALL
  SELECT '204029901788' AS bc, 19 AS qty, 'ok' AS st, '602' AS loc UNION ALL
  SELECT '204029901789' AS bc, 6 AS qty, 'warning' AS st, '602' AS loc UNION ALL
  SELECT '204029901795' AS bc, 17 AS qty, 'ok' AS st, '602' AS loc UNION ALL
  SELECT '204029901798' AS bc, 12 AS qty, 'ok' AS st, '602' AS loc UNION ALL
  SELECT '692173493574' AS bc, 3444 AS qty, 'ok' AS st, '603' AS loc UNION ALL
  SELECT '893500181659' AS bc, 4341 AS qty, 'ok' AS st, '610' AS loc UNION ALL
  SELECT '893532403493' AS bc, 3580 AS qty, 'ok' AS st, '611' AS loc UNION ALL
  SELECT '693520539030' AS bc, 36 AS qty, 'ok' AS st, '612' AS loc UNION ALL
  SELECT '694223365928' AS bc, 14 AS qty, 'ok' AS st, '612' AS loc UNION ALL
  SELECT '692173490522' AS bc, 31 AS qty, 'ok' AS st, '612' AS loc UNION ALL
  SELECT '693520530738' AS bc, 26 AS qty, 'ok' AS st, '612' AS loc UNION ALL
  SELECT '694223360851' AS bc, 12 AS qty, 'ok' AS st, '612' AS loc UNION ALL
  SELECT '694223367418' AS bc, 252 AS qty, 'ok' AS st, '621' AS loc UNION ALL
  SELECT '693520530624' AS bc, 25 AS qty, 'ok' AS st, '622' AS loc UNION ALL
  SELECT '693520533685' AS bc, 9 AS qty, 'warning' AS st, '622' AS loc UNION ALL
  SELECT '692173495360' AS bc, 1 AS qty, 'low' AS st, '622' AS loc UNION ALL
  SELECT '693520539028' AS bc, 2 AS qty, 'low' AS st, '622' AS loc UNION ALL
  SELECT '692173497416' AS bc, 156 AS qty, 'ok' AS st, '623' AS loc UNION ALL
  SELECT '694223360847' AS bc, 12 AS qty, 'ok' AS st, '623' AS loc UNION ALL
  SELECT '694223363037' AS bc, 336 AS qty, 'ok' AS st, '624' AS loc UNION ALL
  SELECT '693520530145' AS bc, 14 AS qty, 'ok' AS st, '625' AS loc UNION ALL
  SELECT '692173493589' AS bc, 120 AS qty, 'ok' AS st, '631' AS loc UNION ALL
  SELECT '694223365724' AS bc, 12 AS qty, 'ok' AS st, '644' AS loc UNION ALL
  SELECT '697477620400' AS bc, 432 AS qty, 'ok' AS st, '648' AS loc UNION ALL
  SELECT '693267372548' AS bc, 12 AS qty, 'ok' AS st, '651' AS loc UNION ALL
  SELECT '694223366281' AS bc, 372 AS qty, 'ok' AS st, '653' AS loc UNION ALL
  SELECT '201099902232' AS bc, 100 AS qty, 'ok' AS st, '661' AS loc UNION ALL
  SELECT '200060100235' AS bc, 1 AS qty, 'low' AS st, '662' AS loc UNION ALL
  SELECT '200060100238' AS bc, 39 AS qty, 'ok' AS st, '663' AS loc UNION ALL
  SELECT '207080003390' AS bc, 1 AS qty, 'low' AS st, '665' AS loc UNION ALL
  SELECT '201990001953' AS bc, 4 AS qty, 'low' AS st, '682' AS loc UNION ALL
  SELECT '201990001955' AS bc, 1 AS qty, 'low' AS st, '682' AS loc UNION ALL
  SELECT '201990002213' AS bc, 2 AS qty, 'low' AS st, '682' AS loc UNION ALL
  SELECT '201990002222' AS bc, 3 AS qty, 'low' AS st, '682' AS loc UNION ALL
  SELECT '201990001962' AS bc, 14 AS qty, 'ok' AS st, '683' AS loc UNION ALL
  SELECT '201990001961' AS bc, 3 AS qty, 'low' AS st, '683' AS loc UNION ALL
  SELECT '697350400085' AS bc, 612 AS qty, 'ok' AS st, '684' AS loc UNION ALL
  SELECT '201990001573' AS bc, 398 AS qty, 'ok' AS st, '690' AS loc UNION ALL
  SELECT '201049901738' AS bc, 6 AS qty, 'warning' AS st, '691' AS loc UNION ALL
  SELECT '201049901736' AS bc, 16 AS qty, 'ok' AS st, '691' AS loc UNION ALL
  SELECT '201049901737' AS bc, 20 AS qty, 'ok' AS st, '691' AS loc UNION ALL
  SELECT '201049901915' AS bc, 3 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201049901916' AS bc, 5 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201049901917' AS bc, 2 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201049901920' AS bc, 1 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201049901921' AS bc, 7 AS qty, 'warning' AS st, '691' AS loc UNION ALL
  SELECT '201049901942' AS bc, 2 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201990001957' AS bc, 1 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201990002221' AS bc, 4 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201990002225' AS bc, 1 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201990002229' AS bc, 1 AS qty, 'low' AS st, '691' AS loc UNION ALL
  SELECT '201990001945' AS bc, 5 AS qty, 'low' AS st, '692' AS loc UNION ALL
  SELECT '201029900978' AS bc, 23 AS qty, 'ok' AS st, '692' AS loc UNION ALL
  SELECT '201990002030' AS bc, 242 AS qty, 'ok' AS st, '700' AS loc UNION ALL
  SELECT '201029900933' AS bc, 78 AS qty, 'ok' AS st, '711' AS loc UNION ALL
  SELECT '203190700179' AS bc, 7 AS qty, 'warning' AS st, '711' AS loc UNION ALL
  SELECT '203190700183' AS bc, 1 AS qty, 'low' AS st, '711' AS loc UNION ALL
  SELECT '203190700186' AS bc, 4 AS qty, 'low' AS st, '711' AS loc UNION ALL
  SELECT '202010901855' AS bc, 1 AS qty, 'low' AS st, '711' AS loc UNION ALL
  SELECT '201049901930' AS bc, 4 AS qty, 'low' AS st, '711' AS loc UNION ALL
  SELECT '201049901931' AS bc, 5 AS qty, 'low' AS st, '711' AS loc UNION ALL
  SELECT '201990002651' AS bc, 6 AS qty, 'warning' AS st, '711' AS loc UNION ALL
  SELECT '201990002654' AS bc, 2 AS qty, 'low' AS st, '711' AS loc UNION ALL
  SELECT '201990002657' AS bc, 6 AS qty, 'warning' AS st, '711' AS loc UNION ALL
  SELECT '202010905057' AS bc, 30 AS qty, 'ok' AS st, '711' AS loc UNION ALL
  SELECT '201990002486' AS bc, 2 AS qty, 'low' AS st, '713' AS loc UNION ALL
  SELECT '201990002523' AS bc, 2 AS qty, 'low' AS st, '713' AS loc UNION ALL
  SELECT '201990002524' AS bc, 1 AS qty, 'low' AS st, '713' AS loc UNION ALL
  SELECT '885241345941' AS bc, 2 AS qty, 'low' AS st, '714' AS loc UNION ALL
  SELECT '204029900986' AS bc, 16 AS qty, 'ok' AS st, '715' AS loc UNION ALL
  SELECT '885241391754' AS bc, 2 AS qty, 'low' AS st, '716' AS loc UNION ALL
  SELECT '201049901742' AS bc, 1 AS qty, 'low' AS st, '720' AS loc UNION ALL
  SELECT '201049901744' AS bc, 1 AS qty, 'low' AS st, '720' AS loc UNION ALL
  SELECT '201049901909' AS bc, 4 AS qty, 'low' AS st, '720' AS loc UNION ALL
  SELECT '201049901911' AS bc, 1 AS qty, 'low' AS st, '720' AS loc UNION ALL
  SELECT '201990001954' AS bc, 2 AS qty, 'low' AS st, '720' AS loc UNION ALL
  SELECT '201990002207' AS bc, 2 AS qty, 'low' AS st, '720' AS loc UNION ALL
  SELECT '201990002210' AS bc, 1 AS qty, 'low' AS st, '720' AS loc UNION ALL
  SELECT '201990002212' AS bc, 1 AS qty, 'low' AS st, '720' AS loc UNION ALL
  SELECT '204029901790' AS bc, 3 AS qty, 'low' AS st, '730' AS loc UNION ALL
  SELECT '204029901779' AS bc, 10 AS qty, 'warning' AS st, '730' AS loc UNION ALL
  SELECT '204029901786' AS bc, 4 AS qty, 'low' AS st, '730' AS loc UNION ALL
  SELECT '204029901774' AS bc, 7 AS qty, 'warning' AS st, '730' AS loc UNION ALL
  SELECT '204029901775' AS bc, 10 AS qty, 'warning' AS st, '730' AS loc UNION ALL
  SELECT '204029901776' AS bc, 2 AS qty, 'low' AS st, '730' AS loc UNION ALL
  SELECT '204029901778' AS bc, 11 AS qty, 'ok' AS st, '730' AS loc UNION ALL
  SELECT '204029901785' AS bc, 10 AS qty, 'warning' AS st, '730' AS loc UNION ALL
  SELECT '204029901792' AS bc, 5 AS qty, 'low' AS st, '730' AS loc UNION ALL
  SELECT '204029901793' AS bc, 15 AS qty, 'ok' AS st, '730' AS loc UNION ALL
  SELECT '204029901794' AS bc, 11 AS qty, 'ok' AS st, '730' AS loc UNION ALL
  SELECT '204029901799' AS bc, 8 AS qty, 'warning' AS st, '730' AS loc UNION ALL
  SELECT '204029901342' AS bc, 1 AS qty, 'low' AS st, '731' AS loc UNION ALL
  SELECT '204029901768' AS bc, 11 AS qty, 'ok' AS st, '731' AS loc UNION ALL
  SELECT '204029901769' AS bc, 3 AS qty, 'low' AS st, '731' AS loc UNION ALL
  SELECT '204029901770' AS bc, 2 AS qty, 'low' AS st, '731' AS loc UNION ALL
  SELECT '204029901771' AS bc, 3 AS qty, 'low' AS st, '731' AS loc UNION ALL
  SELECT '204029901777' AS bc, 7 AS qty, 'warning' AS st, '731' AS loc UNION ALL
  SELECT '204029901781' AS bc, 2 AS qty, 'low' AS st, '731' AS loc UNION ALL
  SELECT '204029901782' AS bc, 8 AS qty, 'warning' AS st, '731' AS loc UNION ALL
  SELECT '204029901783' AS bc, 1 AS qty, 'low' AS st, '731' AS loc UNION ALL
  SELECT '204029901784' AS bc, 4 AS qty, 'low' AS st, '731' AS loc UNION ALL
  SELECT '204029901787' AS bc, 9 AS qty, 'warning' AS st, '731' AS loc UNION ALL
  SELECT '204029901791' AS bc, 7 AS qty, 'warning' AS st, '731' AS loc UNION ALL
  SELECT '201990002188' AS bc, 14 AS qty, 'ok' AS st, '732' AS loc UNION ALL
  SELECT '201049901895' AS bc, 8 AS qty, 'warning' AS st, '732' AS loc UNION ALL
  SELECT '201049901896' AS bc, 2 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901901' AS bc, 2 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901902' AS bc, 4 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901903' AS bc, 4 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901904' AS bc, 2 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901912' AS bc, 3 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901924' AS bc, 2 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901926' AS bc, 4 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901932' AS bc, 1 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201049901941' AS bc, 2 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201990002233' AS bc, 1 AS qty, 'low' AS st, '732' AS loc UNION ALL
  SELECT '201990002204' AS bc, 2 AS qty, 'low' AS st, '733' AS loc UNION ALL
  SELECT '201990002208' AS bc, 5 AS qty, 'low' AS st, '733' AS loc UNION ALL
  SELECT '201990002650' AS bc, 3 AS qty, 'low' AS st, '735' AS loc UNION ALL
  SELECT '201990001939' AS bc, 2 AS qty, 'low' AS st, '735' AS loc UNION ALL
  SELECT '201990001943' AS bc, 2 AS qty, 'low' AS st, '735' AS loc UNION ALL
  SELECT '201990002567' AS bc, 1 AS qty, 'low' AS st, '735' AS loc UNION ALL
  SELECT '201049902141' AS bc, 2 AS qty, 'low' AS st, '735' AS loc UNION ALL
  SELECT '201049902147' AS bc, 1 AS qty, 'low' AS st, '735' AS loc UNION ALL
  SELECT '201990002649' AS bc, 8 AS qty, 'warning' AS st, '735' AS loc UNION ALL
  SELECT '201990002652' AS bc, 7 AS qty, 'warning' AS st, '735' AS loc UNION ALL
  SELECT '201990002653' AS bc, 5 AS qty, 'low' AS st, '735' AS loc UNION ALL
  SELECT '201990002655' AS bc, 7 AS qty, 'warning' AS st, '735' AS loc UNION ALL
  SELECT '201990002656' AS bc, 6 AS qty, 'warning' AS st, '735' AS loc UNION ALL
  SELECT '201049901734' AS bc, 8 AS qty, 'warning' AS st, '741' AS loc UNION ALL
  SELECT '201049901735' AS bc, 20 AS qty, 'ok' AS st, '741' AS loc UNION ALL
  SELECT '201049901897' AS bc, 1 AS qty, 'low' AS st, '741' AS loc UNION ALL
  SELECT '201049902149' AS bc, 1 AS qty, 'low' AS st, '741' AS loc UNION ALL
  SELECT '201990001980' AS bc, 36 AS qty, 'ok' AS st, '741' AS loc UNION ALL
  SELECT '201990001982' AS bc, 34 AS qty, 'ok' AS st, '741' AS loc UNION ALL
  SELECT '201990002218' AS bc, 3 AS qty, 'low' AS st, '741' AS loc UNION ALL
  SELECT '201990002219' AS bc, 2 AS qty, 'low' AS st, '741' AS loc UNION ALL
  SELECT '201990002228' AS bc, 2 AS qty, 'low' AS st, '741' AS loc UNION ALL
  SELECT '203190601119' AS bc, 1 AS qty, 'low' AS st, '742' AS loc UNION ALL
  SELECT '201990002186' AS bc, 2 AS qty, 'low' AS st, '742' AS loc UNION ALL
  SELECT '201990001952' AS bc, 5 AS qty, 'low' AS st, '742' AS loc UNION ALL
  SELECT '202010903293' AS bc, 1 AS qty, 'low' AS st, '742' AS loc UNION ALL
  SELECT '204029901800' AS bc, 3 AS qty, 'low' AS st, '742' AS loc UNION ALL
  SELECT '201990002203' AS bc, 9 AS qty, 'warning' AS st, '743' AS loc UNION ALL
  SELECT '201990002641' AS bc, 1 AS qty, 'low' AS st, '743' AS loc UNION ALL
  SELECT '201990002644' AS bc, 2 AS qty, 'low' AS st, '743' AS loc UNION ALL
  SELECT '201990002645' AS bc, 1 AS qty, 'low' AS st, '743' AS loc UNION ALL
  SELECT '201990002647' AS bc, 1 AS qty, 'low' AS st, '743' AS loc UNION ALL
  SELECT '893500181665' AS bc, 7264 AS qty, 'ok' AS st, '750' AS loc UNION ALL
  SELECT '885874172416' AS bc, 12 AS qty, 'ok' AS st, '760' AS loc UNION ALL
  SELECT '885874172419' AS bc, 48 AS qty, 'ok' AS st, '760' AS loc UNION ALL
  SELECT '454944100208' AS bc, 12 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100210' AS bc, 12 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100211' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100212' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100217' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100218' AS bc, 18 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100220' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100221' AS bc, 36 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100224' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100225' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944100320' AS bc, 48 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '454944102145' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '497405283105' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '497405283107' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '497405284851' AS bc, 12 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '497405285263' AS bc, 12 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '497405286278' AS bc, 12 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '893500180515' AS bc, 20 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '893500185345' AS bc, 24 AS qty, 'ok' AS st, '761' AS loc UNION ALL
  SELECT '2600018232' AS bc, 28 AS qty, 'ok' AS st, '762' AS loc UNION ALL
  SELECT '489515154096' AS bc, 2 AS qty, 'low' AS st, '762' AS loc UNION ALL
  SELECT '489515154097' AS bc, 1 AS qty, 'low' AS st, '762' AS loc UNION ALL
  SELECT '893500181476' AS bc, 20 AS qty, 'ok' AS st, '763' AS loc UNION ALL
  SELECT '893500182777' AS bc, 2 AS qty, 'low' AS st, '763' AS loc UNION ALL
  SELECT '893500183034' AS bc, 30 AS qty, 'ok' AS st, '763' AS loc UNION ALL
  SELECT '893500183146' AS bc, 28 AS qty, 'ok' AS st, '763' AS loc UNION ALL
  SELECT '893500183802' AS bc, 3 AS qty, 'low' AS st, '763' AS loc UNION ALL
  SELECT '893521948100' AS bc, 8 AS qty, 'warning' AS st, '763' AS loc UNION ALL
  SELECT '893521948302' AS bc, 14 AS qty, 'ok' AS st, '763' AS loc UNION ALL
  SELECT '893521948303' AS bc, 2 AS qty, 'low' AS st, '763' AS loc UNION ALL
  SELECT '454944100002' AS bc, 12 AS qty, 'ok' AS st, '764' AS loc UNION ALL
  SELECT '489515155028' AS bc, 11 AS qty, 'ok' AS st, '764' AS loc UNION ALL
  SELECT '893532402952' AS bc, 20 AS qty, 'ok' AS st, '765' AS loc UNION ALL
  SELECT '893500180389' AS bc, 5 AS qty, 'low' AS st, '765' AS loc UNION ALL
  SELECT '893500180504' AS bc, 106 AS qty, 'ok' AS st, '765' AS loc UNION ALL
  SELECT '893500185274' AS bc, 1 AS qty, 'low' AS st, '765' AS loc UNION ALL
  SELECT '893500188213' AS bc, 10 AS qty, 'warning' AS st, '765' AS loc UNION ALL
  SELECT '893532400320' AS bc, 20 AS qty, 'ok' AS st, '765' AS loc UNION ALL
  SELECT '893532401545' AS bc, 14 AS qty, 'ok' AS st, '765' AS loc UNION ALL
  SELECT '893532402207' AS bc, 65 AS qty, 'ok' AS st, '765' AS loc UNION ALL
  SELECT '893532402828' AS bc, 46 AS qty, 'ok' AS st, '765' AS loc UNION ALL
  SELECT '893532404675' AS bc, 74 AS qty, 'ok' AS st, '765' AS loc UNION ALL
  SELECT '893532404676' AS bc, 7 AS qty, 'warning' AS st, '765' AS loc UNION ALL
  SELECT '893500182229' AS bc, 171 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500185789' AS bc, 119 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500185324' AS bc, 136 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500181227' AS bc, 106 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500180511' AS bc, 31 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500180512' AS bc, 74 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500180516' AS bc, 20 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500180519' AS bc, 52 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500181326' AS bc, 15 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500185016' AS bc, 36 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500185340' AS bc, 1 AS qty, 'low' AS st, '766' AS loc UNION ALL
  SELECT '893500186179' AS bc, 46 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500186694' AS bc, 46 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500180450' AS bc, 293 AS qty, 'ok' AS st, '766' AS loc UNION ALL
  SELECT '893500180292' AS bc, 41 AS qty, 'ok' AS st, '768' AS loc UNION ALL
  SELECT '893500180133' AS bc, 36 AS qty, 'ok' AS st, '768' AS loc UNION ALL
  SELECT '893500180411' AS bc, 8 AS qty, 'warning' AS st, '768' AS loc UNION ALL
  SELECT '893500181454' AS bc, 18 AS qty, 'ok' AS st, '768' AS loc UNION ALL
  SELECT '893500187908' AS bc, 44 AS qty, 'ok' AS st, '768' AS loc UNION ALL
  SELECT '893500188111' AS bc, 59 AS qty, 'ok' AS st, '768' AS loc UNION ALL
  SELECT '893532403641' AS bc, 110 AS qty, 'ok' AS st, '768' AS loc UNION ALL
  SELECT '893500187871' AS bc, 62 AS qty, 'ok' AS st, '768' AS loc UNION ALL
  SELECT '888706620620' AS bc, 67 AS qty, 'ok' AS st, '770' AS loc UNION ALL
  SELECT '204059900513' AS bc, 10 AS qty, 'warning' AS st, '772' AS loc UNION ALL
  SELECT '203020501324' AS bc, 161 AS qty, 'ok' AS st, '773' AS loc UNION ALL
  SELECT '893532401309' AS bc, 77 AS qty, 'ok' AS st, '777' AS loc UNION ALL
  SELECT '893500182443' AS bc, 4 AS qty, 'low' AS st, '780' AS loc UNION ALL
  SELECT '893532401499' AS bc, 5 AS qty, 'low' AS st, '780' AS loc UNION ALL
  SELECT '893500186181' AS bc, 3 AS qty, 'low' AS st, '781' AS loc UNION ALL
  SELECT '893500184938' AS bc, 5 AS qty, 'low' AS st, '782' AS loc UNION ALL
  SELECT '893500187883' AS bc, 7 AS qty, 'warning' AS st, '782' AS loc UNION ALL
  SELECT '893500183538' AS bc, 2 AS qty, 'low' AS st, '783' AS loc UNION ALL
  SELECT '893500183544' AS bc, 2 AS qty, 'low' AS st, '783' AS loc UNION ALL
  SELECT '893521948007' AS bc, 11 AS qty, 'ok' AS st, '783' AS loc UNION ALL
  SELECT '893521948022' AS bc, 7 AS qty, 'warning' AS st, '783' AS loc UNION ALL
  SELECT '893521948026' AS bc, 11 AS qty, 'ok' AS st, '783' AS loc UNION ALL
  SELECT '893532401399' AS bc, 7 AS qty, 'warning' AS st, '783' AS loc UNION ALL
  SELECT '893521948005' AS bc, 52 AS qty, 'ok' AS st, '784' AS loc UNION ALL
  SELECT '893521948205' AS bc, 1 AS qty, 'low' AS st, '784' AS loc UNION ALL
  SELECT '893521948214' AS bc, 10 AS qty, 'warning' AS st, '784' AS loc UNION ALL
  SELECT '893521948215' AS bc, 7 AS qty, 'warning' AS st, '784' AS loc UNION ALL
  SELECT '893532401272' AS bc, 1 AS qty, 'low' AS st, '784' AS loc UNION ALL
  SELECT '893532402950' AS bc, 28 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893532402827' AS bc, 36 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893500181398' AS bc, 38 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893500184231' AS bc, 18 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893500187989' AS bc, 10 AS qty, 'warning' AS st, '785' AS loc UNION ALL
  SELECT '893521946022' AS bc, 63 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893528390511' AS bc, 14 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893532401547' AS bc, 10 AS qty, 'warning' AS st, '785' AS loc UNION ALL
  SELECT '893532401909' AS bc, 1 AS qty, 'low' AS st, '785' AS loc UNION ALL
  SELECT '893532402901' AS bc, 11 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893532402909' AS bc, 3 AS qty, 'low' AS st, '785' AS loc UNION ALL
  SELECT '893532402915' AS bc, 6 AS qty, 'warning' AS st, '785' AS loc UNION ALL
  SELECT '893532402951' AS bc, 10 AS qty, 'warning' AS st, '785' AS loc UNION ALL
  SELECT '893532403032' AS bc, 19 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893532403033' AS bc, 2 AS qty, 'low' AS st, '785' AS loc UNION ALL
  SELECT '893532403045' AS bc, 7 AS qty, 'warning' AS st, '785' AS loc UNION ALL
  SELECT '893532404278' AS bc, 20 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893500181397' AS bc, 1 AS qty, 'low' AS st, '785' AS loc UNION ALL
  SELECT '893532401546' AS bc, 7 AS qty, 'warning' AS st, '785' AS loc UNION ALL
  SELECT '893500183878' AS bc, 35 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '893500181399' AS bc, 10 AS qty, 'warning' AS st, '785' AS loc UNION ALL
  SELECT '893532402829' AS bc, 65 AS qty, 'ok' AS st, '785' AS loc UNION ALL
  SELECT '203000500278' AS bc, 197 AS qty, 'ok' AS st, '790' AS loc UNION ALL
  SELECT '203020800757' AS bc, 27 AS qty, 'ok' AS st, '792' AS loc UNION ALL
  SELECT '893500184300' AS bc, 72 AS qty, 'ok' AS st, '793' AS loc UNION ALL
  SELECT '893500182427' AS bc, 65 AS qty, 'ok' AS st, '794' AS loc UNION ALL
  SELECT '692173497506' AS bc, 342 AS qty, 'ok' AS st, '800' AS loc UNION ALL
  SELECT '893500181465' AS bc, 121 AS qty, 'ok' AS st, '811' AS loc UNION ALL
  SELECT '893500180463' AS bc, 7 AS qty, 'warning' AS st, '811' AS loc UNION ALL
  SELECT '893500180491' AS bc, 35 AS qty, 'ok' AS st, '811' AS loc UNION ALL
  SELECT '893500180492' AS bc, 41 AS qty, 'ok' AS st, '811' AS loc UNION ALL
  SELECT '893532401503' AS bc, 2 AS qty, 'low' AS st, '812' AS loc UNION ALL
  SELECT '893532401540' AS bc, 6 AS qty, 'warning' AS st, '812' AS loc UNION ALL
  SELECT '893532401542' AS bc, 4 AS qty, 'low' AS st, '812' AS loc UNION ALL
  SELECT '893500184785' AS bc, 1 AS qty, 'low' AS st, '813' AS loc UNION ALL
  SELECT '893532401891' AS bc, 19 AS qty, 'ok' AS st, '813' AS loc UNION ALL
  SELECT '893532402527' AS bc, 1 AS qty, 'low' AS st, '813' AS loc UNION ALL
  SELECT '893500184737' AS bc, 1 AS qty, 'low' AS st, '813' AS loc UNION ALL
  SELECT '893532403553' AS bc, 1 AS qty, 'low' AS st, '814' AS loc UNION ALL
  SELECT '893532403554' AS bc, 1 AS qty, 'low' AS st, '814' AS loc UNION ALL
  SELECT '893532403603' AS bc, 2 AS qty, 'low' AS st, '814' AS loc UNION ALL
  SELECT '893532400350' AS bc, 9 AS qty, 'warning' AS st, '815' AS loc UNION ALL
  SELECT '893532403454' AS bc, 2 AS qty, 'low' AS st, '815' AS loc UNION ALL
  SELECT '893532403811' AS bc, 2 AS qty, 'low' AS st, '815' AS loc UNION ALL
  SELECT '893532403456' AS bc, 6 AS qty, 'warning' AS st, '815' AS loc UNION ALL
  SELECT '893532403814' AS bc, 7 AS qty, 'warning' AS st, '815' AS loc UNION ALL
  SELECT '893532402496' AS bc, 7 AS qty, 'warning' AS st, '815' AS loc UNION ALL
  SELECT '893532402489' AS bc, 8 AS qty, 'warning' AS st, '815' AS loc UNION ALL
  SELECT '893532402491' AS bc, 10 AS qty, 'warning' AS st, '815' AS loc UNION ALL
  SELECT '893532402493' AS bc, 15 AS qty, 'ok' AS st, '815' AS loc UNION ALL
  SELECT '893532403809' AS bc, 11 AS qty, 'ok' AS st, '815' AS loc UNION ALL
  SELECT '893532403819' AS bc, 14 AS qty, 'ok' AS st, '816' AS loc UNION ALL
  SELECT '893532403743' AS bc, 4 AS qty, 'low' AS st, '816' AS loc UNION ALL
  SELECT '893532403879' AS bc, 5 AS qty, 'low' AS st, '816' AS loc UNION ALL
  SELECT '893500182289' AS bc, 3 AS qty, 'low' AS st, '817' AS loc UNION ALL
  SELECT '489515154092' AS bc, 3 AS qty, 'low' AS st, '818' AS loc UNION ALL
  SELECT '489515155067' AS bc, 1 AS qty, 'low' AS st, '818' AS loc UNION ALL
  SELECT '893600745894' AS bc, 24 AS qty, 'ok' AS st, '820' AS loc UNION ALL
  SELECT '893500180605' AS bc, 5 AS qty, 'low' AS st, '820' AS loc UNION ALL
  SELECT '893500181475' AS bc, 15 AS qty, 'ok' AS st, '820' AS loc UNION ALL
  SELECT '893500182208' AS bc, 8 AS qty, 'warning' AS st, '820' AS loc UNION ALL
  SELECT '893500184806' AS bc, 7 AS qty, 'warning' AS st, '820' AS loc UNION ALL
  SELECT '893500185028' AS bc, 80 AS qty, 'ok' AS st, '820' AS loc UNION ALL
  SELECT '893528390229' AS bc, 15 AS qty, 'ok' AS st, '820' AS loc UNION ALL
  SELECT '893528390570' AS bc, 3 AS qty, 'low' AS st, '820' AS loc UNION ALL
  SELECT '893532400412' AS bc, 2 AS qty, 'low' AS st, '820' AS loc UNION ALL
  SELECT '893532401452' AS bc, 10 AS qty, 'warning' AS st, '820' AS loc UNION ALL
  SELECT '893532401785' AS bc, 1 AS qty, 'low' AS st, '820' AS loc UNION ALL
  SELECT '893604045395' AS bc, 2 AS qty, 'low' AS st, '820' AS loc UNION ALL
  SELECT '203040900004' AS bc, 6 AS qty, 'warning' AS st, '821' AS loc UNION ALL
  SELECT '893500183045' AS bc, 12 AS qty, 'ok' AS st, '822' AS loc UNION ALL
  SELECT '893500184485' AS bc, 10 AS qty, 'warning' AS st, '822' AS loc UNION ALL
  SELECT '697310004451' AS bc, 11 AS qty, 'ok' AS st, '823' AS loc UNION ALL
  SELECT '880220306389' AS bc, 42 AS qty, 'ok' AS st, '824' AS loc UNION ALL
  SELECT '893611749318' AS bc, 164 AS qty, 'ok' AS st, '830' AS loc UNION ALL
  SELECT '893532403161' AS bc, 3 AS qty, 'low' AS st, '841' AS loc UNION ALL
  SELECT '893532403162' AS bc, 1 AS qty, 'low' AS st, '841' AS loc UNION ALL
  SELECT '893532404670' AS bc, 10 AS qty, 'warning' AS st, '841' AS loc UNION ALL
  SELECT '893532404671' AS bc, 8 AS qty, 'warning' AS st, '841' AS loc UNION ALL
  SELECT '893532404735' AS bc, 3 AS qty, 'low' AS st, '841' AS loc UNION ALL
  SELECT '893611749312' AS bc, 756 AS qty, 'ok' AS st, '850' AS loc UNION ALL
  SELECT '893611749310' AS bc, 1402 AS qty, 'ok' AS st, '851' AS loc UNION ALL
  SELECT '893611749311' AS bc, 460 AS qty, 'ok' AS st, '860' AS loc UNION ALL
  SELECT '893851020505' AS bc, 16 AS qty, 'ok' AS st, '861' AS loc UNION ALL
  SELECT '471421800004' AS bc, 49 AS qty, 'ok' AS st, '862' AS loc UNION ALL
  SELECT '893851020506' AS bc, 170 AS qty, 'ok' AS st, '864' AS loc UNION ALL
  SELECT '893500183668' AS bc, 1031 AS qty, 'ok' AS st, '870' AS loc UNION ALL
  SELECT '893611749300' AS bc, 23 AS qty, 'ok' AS st, '890' AS loc UNION ALL
  SELECT '201049901889' AS bc, 14940 AS qty, 'ok' AS st, '900' AS loc UNION ALL
  SELECT '893500185043' AS bc, 226 AS qty, 'ok' AS st, '910' AS loc UNION ALL
  SELECT '497405285797' AS bc, 36 AS qty, 'ok' AS st, '910' AS loc UNION ALL
  SELECT '203010603670' AS bc, 10 AS qty, 'warning' AS st, '910' AS loc UNION ALL
  SELECT '893532400016' AS bc, 7 AS qty, 'warning' AS st, '910' AS loc UNION ALL
  SELECT '202990000991' AS bc, 2 AS qty, 'low' AS st, '910' AS loc UNION ALL
  SELECT '893532404103' AS bc, 12 AS qty, 'ok' AS st, '910' AS loc UNION ALL
  SELECT '893600745845' AS bc, 10 AS qty, 'warning' AS st, '911' AS loc UNION ALL
  SELECT '893600745846' AS bc, 4 AS qty, 'low' AS st, '911' AS loc UNION ALL
  SELECT '893528390397' AS bc, 11 AS qty, 'ok' AS st, '911' AS loc UNION ALL
  SELECT '893528390399' AS bc, 9 AS qty, 'warning' AS st, '911' AS loc UNION ALL
  SELECT '201049901520' AS bc, 156 AS qty, 'ok' AS st, '911' AS loc UNION ALL
  SELECT '203020800810' AS bc, 35 AS qty, 'ok' AS st, '911' AS loc UNION ALL
  SELECT '202990001342' AS bc, 1 AS qty, 'low' AS st, '911' AS loc UNION ALL
  SELECT '203020401648' AS bc, 9 AS qty, 'warning' AS st, '912' AS loc UNION ALL
  SELECT '497405285799' AS bc, 12 AS qty, 'ok' AS st, '912' AS loc UNION ALL
  SELECT '893500184922' AS bc, 1 AS qty, 'low' AS st, '912' AS loc UNION ALL
  SELECT '893612245557' AS bc, 2 AS qty, 'low' AS st, '912' AS loc UNION ALL
  SELECT '893600880036' AS bc, 28 AS qty, 'ok' AS st, '913' AS loc UNION ALL
  SELECT '893607339052' AS bc, 20 AS qty, 'ok' AS st, '913' AS loc UNION ALL
  SELECT '893600880087' AS bc, 111 AS qty, 'ok' AS st, '914' AS loc UNION ALL
  SELECT '893600880028' AS bc, 1 AS qty, 'low' AS st, '914' AS loc UNION ALL
  SELECT '893500182441' AS bc, 3 AS qty, 'low' AS st, '915' AS loc UNION ALL
  SELECT '893500182446' AS bc, 4 AS qty, 'low' AS st, '915' AS loc UNION ALL
  SELECT '893500182447' AS bc, 6 AS qty, 'warning' AS st, '915' AS loc UNION ALL
  SELECT '893532403742' AS bc, 9 AS qty, 'warning' AS st, '915' AS loc UNION ALL
  SELECT '893521945079' AS bc, 6 AS qty, 'warning' AS st, '916' AS loc UNION ALL
  SELECT '893532403934' AS bc, 24 AS qty, 'ok' AS st, '916' AS loc UNION ALL
  SELECT '893532403935' AS bc, 10 AS qty, 'warning' AS st, '916' AS loc UNION ALL
  SELECT '893532403937' AS bc, 12 AS qty, 'ok' AS st, '916' AS loc UNION ALL
  SELECT '893532404469' AS bc, 7 AS qty, 'warning' AS st, '916' AS loc UNION ALL
  SELECT '893532404730' AS bc, 6 AS qty, 'warning' AS st, '916' AS loc UNION ALL
  SELECT '893532404731' AS bc, 9 AS qty, 'warning' AS st, '916' AS loc UNION ALL
  SELECT '893532404732' AS bc, 10 AS qty, 'warning' AS st, '916' AS loc UNION ALL
  SELECT '893532404748' AS bc, 2 AS qty, 'low' AS st, '916' AS loc UNION ALL
  SELECT '893604045185' AS bc, 8 AS qty, 'warning' AS st, '916' AS loc UNION ALL
  SELECT '893500181478' AS bc, 24 AS qty, 'ok' AS st, '920' AS loc UNION ALL
  SELECT '893521946060' AS bc, 18 AS qty, 'ok' AS st, '920' AS loc UNION ALL
  SELECT '893500182231' AS bc, 299 AS qty, 'ok' AS st, '921' AS loc UNION ALL
  SELECT '893604045029' AS bc, 36 AS qty, 'ok' AS st, '922' AS loc UNION ALL
  SELECT '893605001738' AS bc, 1 AS qty, 'low' AS st, '922' AS loc UNION ALL
  SELECT '893500180611' AS bc, 1 AS qty, 'low' AS st, '922' AS loc UNION ALL
  SELECT '893532400778' AS bc, 1 AS qty, 'low' AS st, '922' AS loc UNION ALL
  SELECT '201049902666' AS bc, 3 AS qty, 'low' AS st, '922' AS loc UNION ALL
  SELECT '490199105350' AS bc, 3 AS qty, 'low' AS st, '923' AS loc UNION ALL
  SELECT '893500189835' AS bc, 13 AS qty, 'ok' AS st, '923' AS loc UNION ALL
  SELECT '893500182242' AS bc, 3 AS qty, 'low' AS st, '923' AS loc UNION ALL
  SELECT '893500186591' AS bc, 5 AS qty, 'low' AS st, '923' AS loc UNION ALL
  SELECT '893500184632' AS bc, 13 AS qty, 'ok' AS st, '923' AS loc UNION ALL
  SELECT '893532402523' AS bc, 28 AS qty, 'ok' AS st, '924' AS loc UNION ALL
  SELECT '893532402517' AS bc, 29 AS qty, 'ok' AS st, '924' AS loc UNION ALL
  SELECT '893532402518' AS bc, 20 AS qty, 'ok' AS st, '924' AS loc UNION ALL
  SELECT '893532404764' AS bc, 15 AS qty, 'ok' AS st, '924' AS loc UNION ALL
  SELECT '893532404765' AS bc, 17 AS qty, 'ok' AS st, '924' AS loc UNION ALL
  SELECT '893532404766' AS bc, 47 AS qty, 'ok' AS st, '924' AS loc UNION ALL
  SELECT '893532404768' AS bc, 36 AS qty, 'ok' AS st, '924' AS loc UNION ALL
  SELECT '893500183147' AS bc, 3 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893500181392' AS bc, 24 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893500181464' AS bc, 18 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893500181487' AS bc, 28 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893500181488' AS bc, 3 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893500181489' AS bc, 16 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893500181531' AS bc, 24 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893500182286' AS bc, 17 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893500182495' AS bc, 5 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893500182573' AS bc, 27 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893500183142' AS bc, 3 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893500183143' AS bc, 5 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893528390074' AS bc, 22 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893532401011' AS bc, 4 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893532401016' AS bc, 9 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532401911' AS bc, 9 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532401920' AS bc, 9 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532402948' AS bc, 7 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532402949' AS bc, 2 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893532404104' AS bc, 1 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893532404192' AS bc, 6 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532404193' AS bc, 14 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893532404195' AS bc, 9 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532404196' AS bc, 13 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893532404563' AS bc, 10 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532404564' AS bc, 12 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893532404570' AS bc, 1 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893532404571' AS bc, 3 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893532404595' AS bc, 9 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532404596' AS bc, 8 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893532404597' AS bc, 14 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893532404598' AS bc, 4 AS qty, 'low' AS st, '926' AS loc UNION ALL
  SELECT '893532404599' AS bc, 7 AS qty, 'warning' AS st, '926' AS loc UNION ALL
  SELECT '893500181393' AS bc, 35 AS qty, 'ok' AS st, '926' AS loc UNION ALL
  SELECT '893500188188' AS bc, 2879 AS qty, 'ok' AS st, '930' AS loc UNION ALL
  SELECT '893521946058' AS bc, 12 AS qty, 'ok' AS st, '931' AS loc UNION ALL
  SELECT '893500185446' AS bc, 7 AS qty, 'warning' AS st, '932' AS loc UNION ALL
  SELECT '893521946066' AS bc, 12 AS qty, 'ok' AS st, '932' AS loc UNION ALL
  SELECT '490481046742' AS bc, 1 AS qty, 'low' AS st, '932' AS loc UNION ALL
  SELECT '490481082481' AS bc, 1 AS qty, 'low' AS st, '932' AS loc UNION ALL
  SELECT '490481087951' AS bc, 1 AS qty, 'low' AS st, '932' AS loc UNION ALL
  SELECT '490481087955' AS bc, 1 AS qty, 'low' AS st, '932' AS loc UNION ALL
  SELECT '801858396452' AS bc, 3 AS qty, 'low' AS st, '932' AS loc UNION ALL
  SELECT '893521943458' AS bc, 2 AS qty, 'low' AS st, '932' AS loc UNION ALL
  SELECT '893600869016' AS bc, 1 AS qty, 'low' AS st, '932' AS loc UNION ALL
  SELECT '893600869019' AS bc, 1 AS qty, 'low' AS st, '932' AS loc UNION ALL
  SELECT '893500181530' AS bc, 3737 AS qty, 'ok' AS st, '940' AS loc UNION ALL
  SELECT '893500185514' AS bc, 409 AS qty, 'ok' AS st, '941' AS loc UNION ALL
  SELECT '893500180130' AS bc, 3812 AS qty, 'ok' AS st, '942' AS loc UNION ALL
  SELECT '893500182938' AS bc, 3800 AS qty, 'ok' AS st, '950' AS loc UNION ALL
  SELECT '893500180451' AS bc, 360 AS qty, 'ok' AS st, '952' AS loc UNION ALL
  SELECT '893500185364' AS bc, 354 AS qty, 'ok' AS st, '953' AS loc UNION ALL
  SELECT '893500185368' AS bc, 396 AS qty, 'ok' AS st, '961' AS loc UNION ALL
  SELECT '893500183670' AS bc, 137 AS qty, 'ok' AS st, '970' AS loc UNION ALL
  SELECT '893500180394' AS bc, 2022 AS qty, 'ok' AS st, '972' AS loc UNION ALL
  SELECT '893532400289' AS bc, 1077 AS qty, 'ok' AS st, '973' AS loc UNION ALL
  SELECT '893532401420' AS bc, 1459 AS qty, 'ok' AS st, '980' AS loc UNION ALL
  SELECT '893500180403' AS bc, 1515 AS qty, 'ok' AS st, '982' AS loc UNION ALL
  SELECT '893500181453' AS bc, 1079 AS qty, 'ok' AS st, '983' AS loc UNION ALL
  SELECT '201049901890' AS bc, 1313 AS qty, 'ok' AS st, '991' AS loc UNION ALL
  SELECT '893500180455' AS bc, 78 AS qty, 'ok' AS st, '1000' AS loc UNION ALL
  SELECT '893500180488' AS bc, 81 AS qty, 'ok' AS st, '1000' AS loc UNION ALL
  SELECT '893500180454' AS bc, 132 AS qty, 'ok' AS st, '1003' AS loc UNION ALL
  SELECT '893500185430' AS bc, 78 AS qty, 'ok' AS st, '1003' AS loc UNION ALL
  SELECT '893500181008' AS bc, 1311 AS qty, 'ok' AS st, '1004' AS loc UNION ALL
  SELECT '893500181784' AS bc, 3 AS qty, 'low' AS st, '1004' AS loc UNION ALL
  SELECT '893500181785' AS bc, 10 AS qty, 'warning' AS st, '1004' AS loc UNION ALL
  SELECT '207080004226' AS bc, 2 AS qty, 'low' AS st, '1004' AS loc UNION ALL
  SELECT '990000069750' AS bc, 4 AS qty, 'low' AS st, '1004' AS loc UNION ALL
  SELECT '893500182323' AS bc, 2130 AS qty, 'ok' AS st, '1005' AS loc UNION ALL
  SELECT '893532401600' AS bc, 43 AS qty, 'ok' AS st, '1005' AS loc UNION ALL
  SELECT '893500182006' AS bc, 744 AS qty, 'ok' AS st, '1010' AS loc UNION ALL
  SELECT '893500184778' AS bc, 1791 AS qty, 'ok' AS st, '1012' AS loc UNION ALL
  SELECT '693110555532' AS bc, 60 AS qty, 'ok' AS st, '1020' AS loc UNION ALL
  SELECT '201990002028' AS bc, 21 AS qty, 'ok' AS st, '1021' AS loc UNION ALL
  SELECT '893532401668' AS bc, 79 AS qty, 'ok' AS st, '1030' AS loc UNION ALL
  SELECT '893500180595' AS bc, 4 AS qty, 'low' AS st, '1040' AS loc UNION ALL
  SELECT '893532402095' AS bc, 58 AS qty, 'ok' AS st, '1040' AS loc UNION ALL
  SELECT '893521946070' AS bc, 5 AS qty, 'low' AS st, '1040' AS loc UNION ALL
  SELECT '893500181904' AS bc, 10 AS qty, 'warning' AS st, '1040' AS loc UNION ALL
  SELECT '893500185428' AS bc, 20 AS qty, 'ok' AS st, '1041' AS loc UNION ALL
  SELECT '200080007673' AS bc, 2 AS qty, 'low' AS st, '1041' AS loc UNION ALL
  SELECT '893500185213' AS bc, 72 AS qty, 'ok' AS st, '1041' AS loc UNION ALL
  SELECT '893500185407' AS bc, 244 AS qty, 'ok' AS st, '1041' AS loc UNION ALL
  SELECT '893532401761' AS bc, 2 AS qty, 'low' AS st, '1041' AS loc UNION ALL
  SELECT '203020201631' AS bc, 5 AS qty, 'low' AS st, '1041' AS loc UNION ALL
  SELECT '200080544926' AS bc, 6 AS qty, 'warning' AS st, '1042' AS loc UNION ALL
  SELECT '893500180647' AS bc, 1 AS qty, 'low' AS st, '1042' AS loc UNION ALL
  SELECT '893500183145' AS bc, 6 AS qty, 'warning' AS st, '1042' AS loc UNION ALL
  SELECT '893500184734' AS bc, 55 AS qty, 'ok' AS st, '1042' AS loc UNION ALL
  SELECT '893500184782' AS bc, 4 AS qty, 'low' AS st, '1042' AS loc UNION ALL
  SELECT '893500186223' AS bc, 9 AS qty, 'warning' AS st, '1042' AS loc UNION ALL
  SELECT '893521944009' AS bc, 1 AS qty, 'low' AS st, '1042' AS loc UNION ALL
  SELECT '893528390214' AS bc, 27 AS qty, 'ok' AS st, '1042' AS loc UNION ALL
  SELECT '893528390255' AS bc, 14 AS qty, 'ok' AS st, '1042' AS loc UNION ALL
  SELECT '893609256774' AS bc, 12 AS qty, 'ok' AS st, '1042' AS loc UNION ALL
  SELECT '203020300555' AS bc, 3 AS qty, 'low' AS st, '1042' AS loc UNION ALL
  SELECT '893528390500' AS bc, 151 AS qty, 'ok' AS st, '1042' AS loc UNION ALL
  SELECT '893500185399' AS bc, 39 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893500180582' AS bc, 20 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532401307' AS bc, 87 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532404189' AS bc, 111 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893500180532' AS bc, 29 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893500180828' AS bc, 9 AS qty, 'warning' AS st, '1043' AS loc UNION ALL
  SELECT '893500181474' AS bc, 56 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893500182055' AS bc, 60 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893500182576' AS bc, 10 AS qty, 'warning' AS st, '1043' AS loc UNION ALL
  SELECT '893500185311' AS bc, 85 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893521946016' AS bc, 21 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532401699' AS bc, 38 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532401700' AS bc, 40 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532402547' AS bc, 4 AS qty, 'low' AS st, '1043' AS loc UNION ALL
  SELECT '893532403079' AS bc, 8 AS qty, 'warning' AS st, '1043' AS loc UNION ALL
  SELECT '893532403473' AS bc, 21 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532403475' AS bc, 61 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532403479' AS bc, 45 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532403480' AS bc, 34 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893500183767' AS bc, 45 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532401306' AS bc, 22 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893532404058' AS bc, 6 AS qty, 'warning' AS st, '1043' AS loc UNION ALL
  SELECT '893532401621' AS bc, 179 AS qty, 'ok' AS st, '1043' AS loc UNION ALL
  SELECT '893500180700' AS bc, 85 AS qty, 'ok' AS st, '1044' AS loc UNION ALL
  SELECT '893500180761' AS bc, 172 AS qty, 'ok' AS st, '1044' AS loc UNION ALL
  SELECT '893500182969' AS bc, 42 AS qty, 'ok' AS st, '1050' AS loc UNION ALL
  SELECT '893500185659' AS bc, 10 AS qty, 'warning' AS st, '1050' AS loc UNION ALL
  SELECT '893500185661' AS bc, 16 AS qty, 'ok' AS st, '1050' AS loc UNION ALL
  SELECT '893500185664' AS bc, 2 AS qty, 'low' AS st, '1050' AS loc UNION ALL
  SELECT '893604439561' AS bc, 48 AS qty, 'ok' AS st, '1051' AS loc UNION ALL
  SELECT '893500183195' AS bc, 83 AS qty, 'ok' AS st, '1051' AS loc UNION ALL
  SELECT '893500181509' AS bc, 18 AS qty, 'ok' AS st, '1052' AS loc UNION ALL
  SELECT '893500185534' AS bc, 26 AS qty, 'ok' AS st, '1053' AS loc UNION ALL
  SELECT '893528390344' AS bc, 1 AS qty, 'low' AS st, '1053' AS loc UNION ALL
  SELECT '893532400375' AS bc, 1 AS qty, 'low' AS st, '1053' AS loc UNION ALL
  SELECT '893532400377' AS bc, 1 AS qty, 'low' AS st, '1053' AS loc UNION ALL
  SELECT '893500182445' AS bc, 11 AS qty, 'ok' AS st, '1054' AS loc UNION ALL
  SELECT '893521946057' AS bc, 3 AS qty, 'low' AS st, '1054' AS loc UNION ALL
  SELECT '893521946075' AS bc, 7 AS qty, 'warning' AS st, '1054' AS loc UNION ALL
  SELECT '893532401078' AS bc, 1 AS qty, 'low' AS st, '1054' AS loc UNION ALL
  SELECT '893532401613' AS bc, 10 AS qty, 'warning' AS st, '1054' AS loc UNION ALL
  SELECT '893521948217' AS bc, 4 AS qty, 'low' AS st, '1055' AS loc UNION ALL
  SELECT '893500184706' AS bc, 20 AS qty, 'ok' AS st, '1056' AS loc UNION ALL
  SELECT '893521948216' AS bc, 8 AS qty, 'warning' AS st, '1056' AS loc UNION ALL
  SELECT '893532401156' AS bc, 5 AS qty, 'low' AS st, '1056' AS loc UNION ALL
  SELECT '893532401157' AS bc, 9 AS qty, 'warning' AS st, '1056' AS loc UNION ALL
  SELECT '893532401158' AS bc, 11 AS qty, 'ok' AS st, '1056' AS loc UNION ALL
  SELECT '893500182404' AS bc, 3 AS qty, 'low' AS st, '1057' AS loc UNION ALL
  SELECT '893500182405' AS bc, 2 AS qty, 'low' AS st, '1057' AS loc UNION ALL
  SELECT '893500183037' AS bc, 13 AS qty, 'ok' AS st, '1057' AS loc UNION ALL
  SELECT '893500183039' AS bc, 2 AS qty, 'low' AS st, '1057' AS loc UNION ALL
  SELECT '893532400550' AS bc, 3 AS qty, 'low' AS st, '1057' AS loc UNION ALL
  SELECT '893532401122' AS bc, 3 AS qty, 'low' AS st, '1057' AS loc UNION ALL
  SELECT '893532401152' AS bc, 8 AS qty, 'warning' AS st, '1057' AS loc UNION ALL
  SELECT '893532401153' AS bc, 7 AS qty, 'warning' AS st, '1057' AS loc UNION ALL
  SELECT '893532401155' AS bc, 8 AS qty, 'warning' AS st, '1057' AS loc UNION ALL
  SELECT '893532402173' AS bc, 5 AS qty, 'low' AS st, '1057' AS loc UNION ALL
  SELECT '893532400009' AS bc, 4 AS qty, 'low' AS st, '1058' AS loc UNION ALL
  SELECT '893532401007' AS bc, 20 AS qty, 'ok' AS st, '1058' AS loc UNION ALL
  SELECT '893532401121' AS bc, 1 AS qty, 'low' AS st, '1058' AS loc UNION ALL
  SELECT '893500182308' AS bc, 1 AS qty, 'low' AS st, '1060' AS loc UNION ALL
  SELECT '893504452836' AS bc, 2 AS qty, 'low' AS st, '1061' AS loc UNION ALL
  SELECT '893504453006' AS bc, 1 AS qty, 'low' AS st, '1061' AS loc UNION ALL
  SELECT '893504453009' AS bc, 1 AS qty, 'low' AS st, '1061' AS loc UNION ALL
  SELECT '893504454142' AS bc, 2 AS qty, 'low' AS st, '1061' AS loc UNION ALL
  SELECT '893504454536' AS bc, 2 AS qty, 'low' AS st, '1061' AS loc UNION ALL
  SELECT '893504454617' AS bc, 3 AS qty, 'low' AS st, '1061' AS loc UNION ALL
  SELECT '893504454900' AS bc, 1 AS qty, 'low' AS st, '1061' AS loc UNION ALL
  SELECT '893504454942' AS bc, 8 AS qty, 'warning' AS st, '1061' AS loc UNION ALL
  SELECT '893504454180' AS bc, 1 AS qty, 'low' AS st, '1061' AS loc UNION ALL
  SELECT '893528390031' AS bc, 8 AS qty, 'warning' AS st, '1062' AS loc UNION ALL
  SELECT '893528390330' AS bc, 52 AS qty, 'ok' AS st, '1062' AS loc UNION ALL
  SELECT '893604045540' AS bc, 88 AS qty, 'ok' AS st, '1062' AS loc UNION ALL
  SELECT '893500182544' AS bc, 15 AS qty, 'ok' AS st, '1063' AS loc UNION ALL
  SELECT '893500181907' AS bc, 13 AS qty, 'ok' AS st, '1063' AS loc UNION ALL
  SELECT '893500182370' AS bc, 1 AS qty, 'low' AS st, '1063' AS loc UNION ALL
  SELECT '893500184040' AS bc, 6 AS qty, 'warning' AS st, '1063' AS loc UNION ALL
  SELECT '893500184710' AS bc, 23 AS qty, 'ok' AS st, '1063' AS loc UNION ALL
  SELECT '893500184932' AS bc, 13 AS qty, 'ok' AS st, '1063' AS loc UNION ALL
  SELECT '893500185935' AS bc, 13 AS qty, 'ok' AS st, '1063' AS loc UNION ALL
  SELECT '893532401694' AS bc, 8 AS qty, 'warning' AS st, '1063' AS loc UNION ALL
  SELECT '893532402162' AS bc, 19 AS qty, 'ok' AS st, '1063' AS loc UNION ALL
  SELECT '893532403803' AS bc, 9 AS qty, 'warning' AS st, '1063' AS loc UNION ALL
  SELECT '893604045379' AS bc, 4 AS qty, 'low' AS st, '1063' AS loc UNION ALL
  SELECT '893532402025' AS bc, 1 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532404033' AS bc, 5 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893500184024' AS bc, 5 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893500186353' AS bc, 2 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401688' AS bc, 10 AS qty, 'warning' AS st, '1064' AS loc UNION ALL
  SELECT '893532401691' AS bc, 4 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401980' AS bc, 1 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401984' AS bc, 1 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401987' AS bc, 2 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401988' AS bc, 1 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401991' AS bc, 4 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401992' AS bc, 2 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401994' AS bc, 4 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401995' AS bc, 2 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532401996' AS bc, 3 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532402001' AS bc, 4 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532402004' AS bc, 4 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532402005' AS bc, 3 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532402020' AS bc, 1 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532403713' AS bc, 2 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532403716' AS bc, 2 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '694128872763' AS bc, 3 AS qty, 'low' AS st, '1064' AS loc UNION ALL
  SELECT '893532403691' AS bc, 10 AS qty, 'warning' AS st, '1064' AS loc UNION ALL
  SELECT '893500182444' AS bc, 3 AS qty, 'low' AS st, '1065' AS loc UNION ALL
  SELECT '893500184701' AS bc, 5 AS qty, 'low' AS st, '1065' AS loc UNION ALL
  SELECT '893500186619' AS bc, 18 AS qty, 'ok' AS st, '1065' AS loc UNION ALL
  SELECT '893500180462' AS bc, 118 AS qty, 'ok' AS st, '1066' AS loc UNION ALL
  SELECT '893500180503' AS bc, 8 AS qty, 'warning' AS st, '1066' AS loc UNION ALL
  SELECT '893500185790' AS bc, 46 AS qty, 'ok' AS st, '1066' AS loc UNION ALL
  SELECT '893532401599' AS bc, 22 AS qty, 'ok' AS st, '1066' AS loc UNION ALL
  SELECT '893532401624' AS bc, 29 AS qty, 'ok' AS st, '1066' AS loc UNION ALL
  SELECT '893532402479' AS bc, 48 AS qty, 'ok' AS st, '1066' AS loc UNION ALL
  SELECT '893532403616' AS bc, 7 AS qty, 'warning' AS st, '1066' AS loc UNION ALL
  SELECT '893532404155' AS bc, 41 AS qty, 'ok' AS st, '1066' AS loc UNION ALL
  SELECT '893500180322' AS bc, 73 AS qty, 'ok' AS st, '1066' AS loc UNION ALL
  SELECT '893500180471' AS bc, 11 AS qty, 'ok' AS st, '1070' AS loc UNION ALL
  SELECT '893521946056' AS bc, 6 AS qty, 'warning' AS st, '1070' AS loc UNION ALL
  SELECT '893521946072' AS bc, 21 AS qty, 'ok' AS st, '1070' AS loc UNION ALL
  SELECT '893521948204' AS bc, 6 AS qty, 'warning' AS st, '1070' AS loc UNION ALL
  SELECT '893500185151' AS bc, 281 AS qty, 'ok' AS st, '1071' AS loc UNION ALL
  SELECT '893500183684' AS bc, 6 AS qty, 'warning' AS st, '1072' AS loc UNION ALL
  SELECT '893500185439' AS bc, 3 AS qty, 'low' AS st, '1072' AS loc UNION ALL
  SELECT '893532401802' AS bc, 10 AS qty, 'warning' AS st, '1072' AS loc UNION ALL
  SELECT '893532401806' AS bc, 18 AS qty, 'ok' AS st, '1072' AS loc UNION ALL
  SELECT '893532402529' AS bc, 4 AS qty, 'low' AS st, '1072' AS loc UNION ALL
  SELECT '893532402602' AS bc, 5 AS qty, 'low' AS st, '1072' AS loc UNION ALL
  SELECT '893500180479' AS bc, 100 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500181090' AS bc, 19 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500181477' AS bc, 11 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500182689' AS bc, 56 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500183004' AS bc, 8 AS qty, 'warning' AS st, '1073' AS loc UNION ALL
  SELECT '893500185392' AS bc, 11 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500185393' AS bc, 23 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500185459' AS bc, 60 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500187845' AS bc, 15 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500187846' AS bc, 3 AS qty, 'low' AS st, '1073' AS loc UNION ALL
  SELECT '893500187853' AS bc, 1 AS qty, 'low' AS st, '1073' AS loc UNION ALL
  SELECT '893500189637' AS bc, 130 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893532404304' AS bc, 29 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893604045380' AS bc, 7 AS qty, 'warning' AS st, '1073' AS loc UNION ALL
  SELECT '893500185012' AS bc, 219 AS qty, 'ok' AS st, '1073' AS loc UNION ALL
  SELECT '893500181485' AS bc, 7 AS qty, 'warning' AS st, '1074' AS loc UNION ALL
  SELECT '893500183526' AS bc, 5 AS qty, 'low' AS st, '1074' AS loc UNION ALL
  SELECT '893500183547' AS bc, 4 AS qty, 'low' AS st, '1074' AS loc UNION ALL
  SELECT '893500184412' AS bc, 8 AS qty, 'warning' AS st, '1074' AS loc UNION ALL
  SELECT '893500184791' AS bc, 22 AS qty, 'ok' AS st, '1074' AS loc UNION ALL
  SELECT '893500186502' AS bc, 2 AS qty, 'low' AS st, '1074' AS loc UNION ALL
  SELECT '893500187034' AS bc, 10 AS qty, 'warning' AS st, '1074' AS loc UNION ALL
  SELECT '893521948305' AS bc, 11 AS qty, 'ok' AS st, '1074' AS loc UNION ALL
  SELECT '893528390009' AS bc, 6 AS qty, 'warning' AS st, '1074' AS loc UNION ALL
  SELECT '893528390016' AS bc, 5 AS qty, 'low' AS st, '1074' AS loc UNION ALL
  SELECT '204029901140' AS bc, 149 AS qty, 'ok' AS st, '1080' AS loc UNION ALL
  SELECT '200060100243' AS bc, 1 AS qty, 'low' AS st, '1080' AS loc UNION ALL
  SELECT '893500180245' AS bc, 16 AS qty, 'ok' AS st, '1080' AS loc UNION ALL
  SELECT '893500183200' AS bc, 18 AS qty, 'ok' AS st, '1080' AS loc UNION ALL
  SELECT '893500185133' AS bc, 77 AS qty, 'ok' AS st, '1080' AS loc UNION ALL
  SELECT '893500184918' AS bc, 9 AS qty, 'warning' AS st, '1081' AS loc UNION ALL
  SELECT '893500184919' AS bc, 16 AS qty, 'ok' AS st, '1081' AS loc UNION ALL
  SELECT '893500184924' AS bc, 11 AS qty, 'ok' AS st, '1081' AS loc UNION ALL
  SELECT '893500185966' AS bc, 19 AS qty, 'ok' AS st, '1081' AS loc UNION ALL
  SELECT '893532403965' AS bc, 10 AS qty, 'warning' AS st, '1081' AS loc UNION ALL
  SELECT '893532404068' AS bc, 40 AS qty, 'ok' AS st, '1081' AS loc UNION ALL
  SELECT '893532402376' AS bc, 19 AS qty, 'ok' AS st, '1081' AS loc UNION ALL
  SELECT '893500183612' AS bc, 17 AS qty, 'ok' AS st, '1081' AS loc UNION ALL
  SELECT '893600745858' AS bc, 11 AS qty, 'ok' AS st, '1082' AS loc UNION ALL
  SELECT '893600745859' AS bc, 22 AS qty, 'ok' AS st, '1082' AS loc UNION ALL
  SELECT '203010603671' AS bc, 25 AS qty, 'ok' AS st, '1082' AS loc UNION ALL
  SELECT '893500180371' AS bc, 2 AS qty, 'low' AS st, '1082' AS loc UNION ALL
  SELECT '893500180380' AS bc, 12 AS qty, 'ok' AS st, '1082' AS loc UNION ALL
  SELECT '893500180429' AS bc, 6 AS qty, 'warning' AS st, '1082' AS loc UNION ALL
  SELECT '893500180637' AS bc, 18 AS qty, 'ok' AS st, '1082' AS loc UNION ALL
  SELECT '893500180638' AS bc, 13 AS qty, 'ok' AS st, '1082' AS loc UNION ALL
  SELECT '893500183025' AS bc, 26 AS qty, 'ok' AS st, '1082' AS loc UNION ALL
  SELECT '893500184831' AS bc, 6 AS qty, 'warning' AS st, '1082' AS loc UNION ALL
  SELECT '893500185290' AS bc, 12 AS qty, 'ok' AS st, '1082' AS loc UNION ALL
  SELECT '893500186545' AS bc, 6 AS qty, 'warning' AS st, '1083' AS loc UNION ALL
  SELECT '203020300578' AS bc, 4 AS qty, 'low' AS st, '1083' AS loc UNION ALL
  SELECT '204049901017' AS bc, 6 AS qty, 'warning' AS st, '1083' AS loc UNION ALL
  SELECT '201029900883' AS bc, 2 AS qty, 'low' AS st, '1084' AS loc UNION ALL
  SELECT '201039901484' AS bc, 11 AS qty, 'ok' AS st, '1084' AS loc UNION ALL
  SELECT '893500182153' AS bc, 11 AS qty, 'ok' AS st, '1086' AS loc UNION ALL
  SELECT '893532401518' AS bc, 3 AS qty, 'low' AS st, '1086' AS loc UNION ALL
  SELECT '893532401523' AS bc, 2 AS qty, 'low' AS st, '1086' AS loc UNION ALL
  SELECT '893532403877' AS bc, 5 AS qty, 'low' AS st, '1086' AS loc UNION ALL
  SELECT '893532401488' AS bc, 5 AS qty, 'low' AS st, '1086' AS loc UNION ALL
  SELECT '893500182152' AS bc, 509 AS qty, 'ok' AS st, '1086' AS loc UNION ALL
  SELECT '893500184698' AS bc, 33 AS qty, 'ok' AS st, '1087' AS loc UNION ALL
  SELECT '893500184486' AS bc, 9 AS qty, 'warning' AS st, '1087' AS loc UNION ALL
  SELECT '893528390175' AS bc, 8 AS qty, 'warning' AS st, '1087' AS loc UNION ALL
  SELECT '893532403497' AS bc, 18 AS qty, 'ok' AS st, '1087' AS loc UNION ALL
  SELECT '893500180065' AS bc, 20 AS qty, 'ok' AS st, '1089' AS loc UNION ALL
  SELECT '893532404084' AS bc, 20 AS qty, 'ok' AS st, '1091' AS loc UNION ALL
  SELECT '893532404075' AS bc, 30 AS qty, 'ok' AS st, '1093' AS loc UNION ALL
  SELECT '893532404095' AS bc, 30 AS qty, 'ok' AS st, '1093' AS loc UNION ALL
  SELECT '893532404099' AS bc, 30 AS qty, 'ok' AS st, '1094' AS loc UNION ALL
  SELECT '893500187086' AS bc, 1 AS qty, 'low' AS st, '1095' AS loc UNION ALL
  SELECT '893532403882' AS bc, 36 AS qty, 'ok' AS st, '1095' AS loc UNION ALL
  SELECT '893532404055' AS bc, 14 AS qty, 'ok' AS st, '1095' AS loc UNION ALL
  SELECT '893500180035' AS bc, 717 AS qty, 'ok' AS st, '1097' AS loc UNION ALL
  SELECT '893500185061' AS bc, 30 AS qty, 'ok' AS st, '1100' AS loc UNION ALL
  SELECT '893500185521' AS bc, 373 AS qty, 'ok' AS st, '1101' AS loc UNION ALL
  SELECT '893532404709' AS bc, 40 AS qty, 'ok' AS st, '1110' AS loc UNION ALL
  SELECT '893532403202' AS bc, 18 AS qty, 'ok' AS st, '1111' AS loc UNION ALL
  SELECT '893532403201' AS bc, 16 AS qty, 'ok' AS st, '1112' AS loc UNION ALL
  SELECT '893500181455' AS bc, 2065 AS qty, 'ok' AS st, '1113' AS loc UNION ALL
  SELECT '893532402379' AS bc, 33 AS qty, 'ok' AS st, '1114' AS loc UNION ALL
  SELECT '893532401973' AS bc, 18 AS qty, 'ok' AS st, '1120' AS loc UNION ALL
  SELECT '893532401966' AS bc, 30 AS qty, 'ok' AS st, '1122' AS loc UNION ALL
  SELECT '893500184920' AS bc, 10 AS qty, 'warning' AS st, '1123' AS loc UNION ALL
  SELECT '893532404069' AS bc, 30 AS qty, 'ok' AS st, '1123' AS loc UNION ALL
  SELECT '893532404078' AS bc, 40 AS qty, 'ok' AS st, '1123' AS loc UNION ALL
  SELECT '893532404083' AS bc, 45 AS qty, 'ok' AS st, '1124' AS loc UNION ALL
  SELECT '893500185949' AS bc, 33 AS qty, 'ok' AS st, '1125' AS loc UNION ALL
  SELECT '893532403878' AS bc, 12 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '302698143643' AS bc, 1 AS qty, 'low' AS st, '1126' AS loc UNION ALL
  SELECT '893500180533' AS bc, 35 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893500181486' AS bc, 22 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893500182125' AS bc, 7 AS qty, 'warning' AS st, '1126' AS loc UNION ALL
  SELECT '893500185308' AS bc, 21 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893521946033' AS bc, 1 AS qty, 'low' AS st, '1126' AS loc UNION ALL
  SELECT '893532400435' AS bc, 110 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532401010' AS bc, 7 AS qty, 'warning' AS st, '1126' AS loc UNION ALL
  SELECT '893532401838' AS bc, 27 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532402552' AS bc, 14 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532403140' AS bc, 1 AS qty, 'low' AS st, '1126' AS loc UNION ALL
  SELECT '893532403474' AS bc, 3 AS qty, 'low' AS st, '1126' AS loc UNION ALL
  SELECT '893532403478' AS bc, 4 AS qty, 'low' AS st, '1126' AS loc UNION ALL
  SELECT '893532403509' AS bc, 28 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532403613' AS bc, 18 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532403615' AS bc, 33 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532403617' AS bc, 20 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532403807' AS bc, 40 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532403831' AS bc, 22 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532404024' AS bc, 28 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532404191' AS bc, 47 AS qty, 'ok' AS st, '1126' AS loc UNION ALL
  SELECT '893532404194' AS bc, 6 AS qty, 'warning' AS st, '1126' AS loc UNION ALL
  SELECT '893532402688' AS bc, 3 AS qty, 'low' AS st, '1127' AS loc UNION ALL
  SELECT '893500186178' AS bc, 38 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893607841019' AS bc, 200 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893500180478' AS bc, 1 AS qty, 'low' AS st, '1127' AS loc UNION ALL
  SELECT '893500180530' AS bc, 26 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893500181324' AS bc, 87 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893500182448' AS bc, 4 AS qty, 'low' AS st, '1127' AS loc UNION ALL
  SELECT '893500185316' AS bc, 10 AS qty, 'warning' AS st, '1127' AS loc UNION ALL
  SELECT '893500185321' AS bc, 10 AS qty, 'warning' AS st, '1127' AS loc UNION ALL
  SELECT '893500185356' AS bc, 40 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893500185363' AS bc, 3 AS qty, 'low' AS st, '1127' AS loc UNION ALL
  SELECT '893500186492' AS bc, 6 AS qty, 'warning' AS st, '1127' AS loc UNION ALL
  SELECT '893532400318' AS bc, 8 AS qty, 'warning' AS st, '1127' AS loc UNION ALL
  SELECT '893532401719' AS bc, 4 AS qty, 'low' AS st, '1127' AS loc UNION ALL
  SELECT '893532401732' AS bc, 4 AS qty, 'low' AS st, '1127' AS loc UNION ALL
  SELECT '893532401914' AS bc, 6 AS qty, 'warning' AS st, '1127' AS loc UNION ALL
  SELECT '893532402053' AS bc, 14 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893532402058' AS bc, 12 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893532403485' AS bc, 1 AS qty, 'low' AS st, '1127' AS loc UNION ALL
  SELECT '893532404178' AS bc, 10 AS qty, 'warning' AS st, '1127' AS loc UNION ALL
  SELECT '893532404190' AS bc, 16 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893500182290' AS bc, 3002 AS qty, 'ok' AS st, '1127' AS loc UNION ALL
  SELECT '893604045375' AS bc, 24 AS qty, 'ok' AS st, '1130' AS loc UNION ALL
  SELECT '893500184556' AS bc, 2 AS qty, 'low' AS st, '1132' AS loc UNION ALL
  SELECT '893528390171' AS bc, 9 AS qty, 'warning' AS st, '1132' AS loc UNION ALL
  SELECT '893528390173' AS bc, 6 AS qty, 'warning' AS st, '1132' AS loc UNION ALL
  SELECT '893528390436' AS bc, 3 AS qty, 'low' AS st, '1132' AS loc UNION ALL
  SELECT '893528390522' AS bc, 9 AS qty, 'warning' AS st, '1132' AS loc UNION ALL
  SELECT '893532401633' AS bc, 8 AS qty, 'warning' AS st, '1132' AS loc UNION ALL
  SELECT '893604045359' AS bc, 1 AS qty, 'low' AS st, '1132' AS loc UNION ALL
  SELECT '893500181463' AS bc, 23 AS qty, 'ok' AS st, '1133' AS loc UNION ALL
  SELECT '893500186693' AS bc, 42 AS qty, 'ok' AS st, '1133' AS loc UNION ALL
  SELECT '893532400290' AS bc, 8 AS qty, 'warning' AS st, '1133' AS loc UNION ALL
  SELECT '893532404049' AS bc, 40 AS qty, 'ok' AS st, '1133' AS loc UNION ALL
  SELECT '893532404102' AS bc, 11 AS qty, 'ok' AS st, '1133' AS loc UNION ALL
  SELECT '893532404187' AS bc, 119 AS qty, 'ok' AS st, '1133' AS loc UNION ALL
  SELECT '893500182069' AS bc, 2 AS qty, 'low' AS st, '1133' AS loc UNION ALL
  SELECT '893532404106' AS bc, 9 AS qty, 'warning' AS st, '1133' AS loc UNION ALL
  SELECT '893532402826' AS bc, 46 AS qty, 'ok' AS st, '1133' AS loc UNION ALL
  SELECT '893604045300' AS bc, 142 AS qty, 'ok' AS st, '1134' AS loc UNION ALL
  SELECT '893532403199' AS bc, 20 AS qty, 'ok' AS st, '1140' AS loc UNION ALL
  SELECT '893532403200' AS bc, 15 AS qty, 'ok' AS st, '1141' AS loc UNION ALL
  SELECT '893521946054' AS bc, 85 AS qty, 'ok' AS st, '1142' AS loc UNION ALL
  SELECT '893532400366' AS bc, 19 AS qty, 'ok' AS st, '1143' AS loc UNION ALL
  SELECT '893532400365' AS bc, 13 AS qty, 'ok' AS st, '1143' AS loc UNION ALL
  SELECT '893528390523' AS bc, 20 AS qty, 'ok' AS st, '1143' AS loc UNION ALL
  SELECT '893528390525' AS bc, 11 AS qty, 'ok' AS st, '1143' AS loc UNION ALL
  SELECT '893528390533' AS bc, 2 AS qty, 'low' AS st, '1143' AS loc UNION ALL
  SELECT '893532400374' AS bc, 12 AS qty, 'ok' AS st, '1143' AS loc UNION ALL
  SELECT '893532400427' AS bc, 8 AS qty, 'warning' AS st, '1143' AS loc UNION ALL
  SELECT '893604045228' AS bc, 52 AS qty, 'ok' AS st, '1143' AS loc UNION ALL
  SELECT '893528390524' AS bc, 20 AS qty, 'ok' AS st, '1143' AS loc UNION ALL
  SELECT '893532402377' AS bc, 19 AS qty, 'ok' AS st, '1150' AS loc UNION ALL
  SELECT '893500184925' AS bc, 10 AS qty, 'warning' AS st, '1151' AS loc UNION ALL
  SELECT '893500185962' AS bc, 22 AS qty, 'ok' AS st, '1151' AS loc UNION ALL
  SELECT '893532404683' AS bc, 33 AS qty, 'ok' AS st, '1152' AS loc UNION ALL
  SELECT '893532401665' AS bc, 197 AS qty, 'ok' AS st, '1153' AS loc UNION ALL
  SELECT '893532401423' AS bc, 901 AS qty, 'ok' AS st, '1163' AS loc UNION ALL
  SELECT '893500180034' AS bc, 9020 AS qty, 'ok' AS st, '1170' AS loc UNION ALL
  SELECT '893500180376' AS bc, 3456 AS qty, 'ok' AS st, '1172' AS loc UNION ALL
  SELECT '893605001096' AS bc, 920 AS qty, 'ok' AS st, '960 + A10.7' AS loc UNION ALL
  SELECT '202990001194' AS bc, 47500 AS qty, 'ok' AS st, 'A10.6' AS loc UNION ALL
  SELECT '202990001196' AS bc, 5850 AS qty, 'ok' AS st, 'A10.6' AS loc UNION ALL
  SELECT '202990001197' AS bc, 5500 AS qty, 'ok' AS st, 'A10.6' AS loc UNION ALL
  SELECT '202990001198' AS bc, 2902 AS qty, 'ok' AS st, 'A10.6' AS loc UNION ALL
  SELECT '202990001199' AS bc, 2927 AS qty, 'ok' AS st, 'A10.6' AS loc UNION ALL
  SELECT '893614194122' AS bc, 14 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194123' AS bc, 10 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826309' AS bc, 6 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826003' AS bc, 42 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826036' AS bc, 165 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826068' AS bc, 165 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826158' AS bc, 18 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826166' AS bc, 25 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826467' AS bc, 10 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826470' AS bc, 110 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826479' AS bc, 30 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194104' AS bc, 10 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194107' AS bc, 141 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194113' AS bc, 190 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194114' AS bc, 70 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194119' AS bc, 70 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194126' AS bc, 72 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194135' AS bc, 92 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194156' AS bc, 20 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194162' AS bc, 120 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194164' AS bc, 65 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194170' AS bc, 10 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194181' AS bc, 220 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194222' AS bc, 30 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194328' AS bc, 100 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194411' AS bc, 5 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '203050311454' AS bc, 10 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '203050311455' AS bc, 20 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512825996' AS bc, 3 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826053' AS bc, 5 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826056' AS bc, 5 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826087' AS bc, 14 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826091' AS bc, 2 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826097' AS bc, 2 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826291' AS bc, 3 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826350' AS bc, 94 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826351' AS bc, 38 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826381' AS bc, 198 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826418' AS bc, 81 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826419' AS bc, 23 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826422' AS bc, 110 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194047' AS bc, 10 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194050' AS bc, 4 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194235' AS bc, 162 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194240' AS bc, 73 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194246' AS bc, 3 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194359' AS bc, 71 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194360' AS bc, 133 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194361' AS bc, 121 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '203050311460' AS bc, 12 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826201' AS bc, 10 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826349' AS bc, 273 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826353' AS bc, 1 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826347' AS bc, 224 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826348' AS bc, 220 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826420' AS bc, 92 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826189' AS bc, 3 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826311' AS bc, 3 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194239' AS bc, 76 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512825916' AS bc, 5 AS qty, 'low' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826408' AS bc, 8 AS qty, 'warning' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826344' AS bc, 70 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194120' AS bc, 250 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '203050311459' AS bc, 77 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194236' AS bc, 331 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826021' AS bc, 550 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194116' AS bc, 130 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893614194115' AS bc, 230 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826270' AS bc, 75 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826315' AS bc, 100 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '893512826382' AS bc, 212 AS qty, 'ok' AS st, 'A6.6' AS loc UNION ALL
  SELECT '203000700048' AS bc, 5028 AS qty, 'ok' AS st, 'A8.1' AS loc UNION ALL
  SELECT '202990000945' AS bc, 70 AS qty, 'ok' AS st, 'A8.5' AS loc UNION ALL
  SELECT '202990000944' AS bc, 304 AS qty, 'ok' AS st, 'A8.5' AS loc UNION ALL
  SELECT '202990001195' AS bc, 46750 AS qty, 'ok' AS st, 'A8.7' AS loc UNION ALL
  SELECT '204029900985' AS bc, 434 AS qty, 'ok' AS st, 'A8.8' AS loc UNION ALL
  SELECT '203000700047' AS bc, 3792 AS qty, 'ok' AS st, 'A9.1' AS loc UNION ALL
  SELECT '202990000981' AS bc, 203 AS qty, 'ok' AS st, 'A9.3' AS loc UNION ALL
  SELECT '202990000982' AS bc, 128 AS qty, 'ok' AS st, 'A9.5' AS loc UNION ALL
  SELECT '202990000975' AS bc, 193 AS qty, 'ok' AS st, 'A9.6' AS loc UNION ALL
  SELECT '204019902422' AS bc, 94 AS qty, 'ok' AS st, 'A9.8' AS loc UNION ALL
  SELECT '885241351694' AS bc, 1055 AS qty, 'ok' AS st, 'C1.1' AS loc UNION ALL
  SELECT '204019901865' AS bc, 5 AS qty, 'low' AS st, 'C1.5' AS loc UNION ALL
  SELECT '885241345091' AS bc, 5 AS qty, 'low' AS st, 'C1.5' AS loc UNION ALL
  SELECT '885241345939' AS bc, 10 AS qty, 'warning' AS st, 'C1.5' AS loc UNION ALL
  SELECT '885241355681' AS bc, 5 AS qty, 'low' AS st, 'C1.5' AS loc UNION ALL
  SELECT '885241356429' AS bc, 315 AS qty, 'ok' AS st, 'C1.5' AS loc UNION ALL
  SELECT '204019901864' AS bc, 800 AS qty, 'ok' AS st, 'C1.6' AS loc UNION ALL
  SELECT '899138913900' AS bc, 344 AS qty, 'ok' AS st, 'C1.8' AS loc UNION ALL
  SELECT '204019901953' AS bc, 490 AS qty, 'ok' AS st, 'C2.1 + 203' AS loc UNION ALL
  SELECT '204019901954' AS bc, 180 AS qty, 'ok' AS st, 'C2.2' AS loc UNION ALL
  SELECT '893512826266' AS bc, 57 AS qty, 'ok' AS st, 'C2.3' AS loc UNION ALL
  SELECT '893512826267' AS bc, 3 AS qty, 'low' AS st, 'C2.3' AS loc UNION ALL
  SELECT '893512826204' AS bc, 58 AS qty, 'ok' AS st, 'C2.3' AS loc UNION ALL
  SELECT '893512826203' AS bc, 120 AS qty, 'ok' AS st, 'C2.3' AS loc UNION ALL
  SELECT '454952661369' AS bc, 120 AS qty, 'ok' AS st, 'C2.4' AS loc UNION ALL
  SELECT '454952661147' AS bc, 357 AS qty, 'ok' AS st, 'C2.4' AS loc UNION ALL
  SELECT '454952661148' AS bc, 178 AS qty, 'ok' AS st, 'C2.4' AS loc UNION ALL
  SELECT '204030402646' AS bc, 90 AS qty, 'ok' AS st, 'C2.5' AS loc UNION ALL
  SELECT '204030402645' AS bc, 120 AS qty, 'ok' AS st, 'C2.5' AS loc UNION ALL
  SELECT '204030402641' AS bc, 150 AS qty, 'ok' AS st, 'C2.5' AS loc UNION ALL
  SELECT '204030402830' AS bc, 1000 AS qty, 'ok' AS st, 'C2.5' AS loc UNION ALL
  SELECT '204030402644' AS bc, 180 AS qty, 'ok' AS st, 'C2.5' AS loc UNION ALL
  SELECT '204030402643' AS bc, 650 AS qty, 'ok' AS st, 'C2.5' AS loc UNION ALL
  SELECT '454952660603' AS bc, 714 AS qty, 'ok' AS st, 'C2.6' AS loc UNION ALL
  SELECT '454952661370' AS bc, 50 AS qty, 'ok' AS st, 'C2.7' AS loc UNION ALL
  SELECT '454952661389' AS bc, 2 AS qty, 'low' AS st, 'C2.7' AS loc UNION ALL
  SELECT '893500184145' AS bc, 494 AS qty, 'ok' AS st, 'C2.8' AS loc UNION ALL
  SELECT '893532404754' AS bc, 351 AS qty, 'ok' AS st, 'C2.8' AS loc UNION ALL
  SELECT '893532404757' AS bc, 596 AS qty, 'ok' AS st, 'C2.8' AS loc UNION ALL
  SELECT '893607841004' AS bc, 77 AS qty, 'ok' AS st, 'C2.9' AS loc UNION ALL
  SELECT '893607841010' AS bc, 4328 AS qty, 'ok' AS st, 'C2.9' AS loc UNION ALL
  SELECT '893535030942' AS bc, 27 AS qty, 'ok' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030931' AS bc, 4 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907680' AS bc, 2 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907681' AS bc, 2 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907683' AS bc, 19 AS qty, 'ok' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907687' AS bc, 2 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907694' AS bc, 3 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907699' AS bc, 50 AS qty, 'ok' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907708' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907709' AS bc, 2 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907710' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907723' AS bc, 19 AS qty, 'ok' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907724' AS bc, 4 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907728' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907737' AS bc, 8 AS qty, 'warning' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907630' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907631' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907632' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '203029907635' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '695883853914' AS bc, 4 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '695883853915' AS bc, 5 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '695883853955' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030091' AS bc, 2 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030128' AS bc, 10 AS qty, 'warning' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030604' AS bc, 4 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030818' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030930' AS bc, 5 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030933' AS bc, 3 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030945' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030946' AS bc, 2 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030947' AS bc, 2 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '694678511950' AS bc, 1 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030956' AS bc, 4 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535031003' AS bc, 3 AS qty, 'low' AS st, 'C3.1' AS loc UNION ALL
  SELECT '893535030943' AS bc, 30 AS qty, 'ok' AS st, 'C3.1' AS loc UNION ALL
  SELECT '885241347785' AS bc, 2 AS qty, 'low' AS st, 'C3.2' AS loc UNION ALL
  SELECT '204019902935' AS bc, 54 AS qty, 'ok' AS st, 'C3.2' AS loc UNION ALL
  SELECT '204019902603' AS bc, 4 AS qty, 'low' AS st, 'C3.2 + 203' AS loc UNION ALL
  SELECT '893521949005' AS bc, 298 AS qty, 'ok' AS st, 'C3.8' AS loc UNION ALL
  SELECT '893500184147' AS bc, 320 AS qty, 'ok' AS st, 'C3.8' AS loc UNION ALL
  SELECT '893532404753' AS bc, 1172 AS qty, 'ok' AS st, 'C3.8' AS loc UNION ALL
  SELECT '237990000939' AS bc, 14 AS qty, 'ok' AS st, 'E1.1' AS loc UNION ALL
  SELECT '203990402398' AS bc, 25 AS qty, 'ok' AS st, 'E1.1' AS loc UNION ALL
  SELECT '209010000432' AS bc, 121 AS qty, 'ok' AS st, 'E1.1' AS loc UNION ALL
  SELECT '201990002153' AS bc, 2261 AS qty, 'ok' AS st, 'E1.2' AS loc UNION ALL
  SELECT '201990001817' AS bc, 200 AS qty, 'ok' AS st, 'E1.2' AS loc UNION ALL
  SELECT '203000500277' AS bc, 450 AS qty, 'ok' AS st, 'E1.3' AS loc UNION ALL
  SELECT '203000500279' AS bc, 477 AS qty, 'ok' AS st, 'E1.3' AS loc UNION ALL
  SELECT '201990002089' AS bc, 519 AS qty, 'ok' AS st, 'E1.4' AS loc UNION ALL
  SELECT '201990001472' AS bc, 105 AS qty, 'ok' AS st, 'E1.4' AS loc UNION ALL
  SELECT '893850711546' AS bc, 130 AS qty, 'ok' AS st, 'E1.4' AS loc UNION ALL
  SELECT '205020002733' AS bc, 88 AS qty, 'ok' AS st, 'E2.1' AS loc UNION ALL
  SELECT '231039901468' AS bc, 3440 AS qty, 'ok' AS st, 'E2.2' AS loc UNION ALL
  SELECT '203000300082' AS bc, 509 AS qty, 'ok' AS st, 'E2.3' AS loc UNION ALL
  SELECT '203000500280' AS bc, 883 AS qty, 'ok' AS st, 'E2.4' AS loc
) t
JOIN products p ON p.barcode = t.bc;

-- ============================================================
-- Hoàn tất! Kiểm tra:
-- SELECT COUNT(*) FROM products;   -- phải = 1317
-- SELECT COUNT(*) FROM inventory;  -- phải = 1317
-- SELECT * FROM v_inventory_full LIMIT 5;
-- ============================================================