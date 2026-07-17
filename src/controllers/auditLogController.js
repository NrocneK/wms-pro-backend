// src/controllers/auditLogController.js
"use strict";

const db = require("../config/db");
const R = require("../utils/response");

/**
 * Lấy danh sách audit log, có phân trang + lọc theo entity/action
 * LƯU Ý: MySQL 8.4 + mysql2 không nhận placeholder (?) cho LIMIT/OFFSET
 * → phải inline trực tiếp sau khi ép kiểu Number, KHÔNG truyền qua params
 */
const getAll = async (req, res) => {
    try {
        const { page = 1, limit = 50, entity = "", action = "" } = req.query;
        const safeLimit = Math.max(1, parseInt(limit) || 50);
        const safePage = Math.max(1, parseInt(page) || 1);
        const offset = (safePage - 1) * safeLimit;

        const params = [];
        let where = "WHERE 1=1";
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