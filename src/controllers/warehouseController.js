// src/controllers/warehouseController.js
"use strict";

const db = require("../config/db");
const R = require("../utils/response");

/**
 * Lấy danh sách kho đang hoạt động
 * Dùng cho selector ở trang Import/Export
 */
const getAll = async (req, res) => {
    try {
        const [rows] = await db.execute(
            `SELECT id, code, name FROM warehouses WHERE is_active=1 ORDER BY code`
        );
        return R.ok(res, rows);
    } catch (err) {
        return R.serverError(res, err);
    }
};

module.exports = { getAll };