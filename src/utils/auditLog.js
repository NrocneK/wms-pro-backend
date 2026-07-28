// src/utils/auditLog.js
// Ghi log thao tác — dùng chung cho tất cả controllers
"use strict";

/**
 * @param {object} db    — db pool hoặc connection
 * @param {object} user  — req.user từ JWT
 * @param {string} action   — 'CREATE' | 'UPDATE' | 'DELETE' | 'CONFIRM' | 'REPLACE'
 * @param {string} entity   — 'product' | 'import_order' | 'export_order' | 'user' | 'inventory'
 * @param {string} entityId — ID của record bị tác động
 * @param {string} description — mô tả ngắn bằng tiếng Việt
 * @param {number|null} warehouseId — kho liên quan tới hành động, NULL nếu
 *   hành động không thuộc về 1 kho cụ thể (vd: quản lý user, sửa product
 *   catalog-level, thay thế tồn kho nhiều kho cùng lúc). Dùng để lọc log
 *   theo quyền kho ở auditLogController.
 */
const writeLog = async (db, user, action, entity, entityId, description, warehouseId = null) => {
    try {
        await db.execute(
            `INSERT INTO audit_logs (user_id, warehouse_id, username, full_name, action, entity, entity_id, description)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                user.id,
                warehouseId,
                user.username,
                user.full_name || "",
                action,
                entity,
                String(entityId || ""),
                description,
            ]
        );
    } catch (err) {
        // Không để lỗi audit làm hỏng luồng chính
        console.error("[AuditLog] Lỗi ghi log:", err.message);
    }
};

module.exports = { writeLog };