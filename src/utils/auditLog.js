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
 */
const writeLog = async (db, user, action, entity, entityId, description) => {
    try {
        await db.execute(
            `INSERT INTO audit_logs (user_id, username, full_name, action, entity, entity_id, description)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
            [
                user.id,
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