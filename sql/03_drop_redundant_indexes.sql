-- sql/03_drop_redundant_indexes.sql
-- Dọn 3 index bị trùng lặp hoàn toàn với UNIQUE KEY đã có sẵn trên cùng cột.
-- UNIQUE KEY tự động tạo ra 1 index — index KEY thêm bên cạnh là dư thừa
-- 100%, không tăng tốc truy vấn thêm (đã kiểm chứng qua EXPLAIN: cả 2
-- trường hợp trước/sau khi xóa đều cho type=const/eq_ref như nhau), chỉ
-- tốn thêm dung lượng lưu trữ và làm chậm nhẹ các lệnh INSERT/UPDATE/DELETE
-- (mỗi thay đổi dữ liệu phải cập nhật thêm 1 index không cần thiết).
--
-- AN TOÀN: đây là DROP INDEX (không phải DROP CONSTRAINT), không ảnh hưởng
-- ràng buộc UNIQUE hay dữ liệu hiện có.

ALTER TABLE products DROP INDEX idx_barcode;
ALTER TABLE import_orders DROP INDEX idx_ref_no;
ALTER TABLE export_orders DROP INDEX idx_ref_no_exp;