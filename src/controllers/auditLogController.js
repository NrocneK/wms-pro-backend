// src/controllers/auditLogController.js
"use strict";

const db = require("../config/db");
const R = require("../utils/response");
const { warehouseGuard } = require("../middleware/warehouseGuard");

/**
 * Lấy danh sách audit log, có phân trang + lọc theo entity/action
 * + lọc theo quyền kho (manager chỉ thấy log của kho mình phụ trách;
 *   admin không bị lọc kho vì req.user.warehouse_id = null).
 * Các log có warehouse_id=NULL (hành động không thuộc 1 kho cụ thể, vd:
 * quản lý user, sửa product catalog) SẼ BỊ ẨN khỏi manager có giới hạn kho
 * — vì không thể xác định log đó có thuộc phạm vi của họ hay không, ẩn đi
 * là lựa chọn an toàn hơn hiển thị nhầm.
 * LƯU Ý: MySQL 8.4 + mysql2 không nhận placeholder (?) cho LIMIT/OFFSET
 * → phải inline trực tiếp sau khi ép kiểu Number, KHÔNG truyền qua params
 */
const getAll = async (req, res) => {
    try {
        const { page = 1, limit = 50, entity = "", action = "" } = req.query;
        const safeLimit = Math.max(1, parseInt(limit) || 50);
        const safePage = Math.max(1, parseInt(page) || 1);
        const offset = (safePage - 1) * safeLimit;

        const { whClause, whParams } = warehouseGuard(req.user, "warehouse_id");
        const params = [...whParams];
        let where = "WHERE 1=1" + whClause;
        if (entity) { where += " AND entity=?"; params.push(entity); }
        if (action) { where += " AND action=?"; params.push(action); }

        const [[{ total }]] = await db.execute(
            `SELECT COUNT(*) AS total FROM audit_logs ${where}`, params
        );
        const [rows] = await db.execute(
            `SELECT * FROM audit_logs ${where} ORDER BY created_at DESC LIMIT ${safeLimit} OFFSET ${offset}`,
            params
        );
        return R.ok(res, {
            items: rows,
            pagination: { total, page: safePage, limit: safeLimit }
        });
    } catch (err) {
        return R.serverError(res, err);
    }
};

module.exports = { getAll };