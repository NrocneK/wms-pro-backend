const { writeLog } = require("../utils/auditLog");

"use strict";
const db = require("../config/db");
const bcrypt = require("bcryptjs");
const R = require("../utils/response");

const resolveWarehouse = async (conn, warehouseCode) => {
  if (!warehouseCode) return null;
  const [[wh]] = await conn.execute("SELECT id FROM warehouses WHERE code=?", [warehouseCode]);
  return wh?.id || null;
};

const getAll = async (req, res) => {
  try {
    const [rows] = await db.execute(`SELECT u.id,u.username,u.full_name,u.role,u.warehouse_id,w.code AS warehouse_code,w.name AS warehouse_name,u.is_active,u.last_login,u.created_at FROM users u LEFT JOIN warehouses w ON w.id=u.warehouse_id ORDER BY u.role ASC,u.created_at ASC`);
    return R.ok(res, rows);
  } catch (err) { return R.serverError(res, err); }
};

const create = async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const { username, password, full_name, role = "staff", warehouse_code } = req.body;
    if (!username || !password || !full_name) return R.badRequest(res, "Thiếu username, password hoặc full_name");
    if (!["admin", "manager", "staff"].includes(role)) return R.badRequest(res, "Role không hợp lệ");
    if (password.length < 6) return R.badRequest(res, "Mật khẩu phải ít nhất 6 ký tự");
    const warehouse_id = await resolveWarehouse(conn, warehouse_code);
    const hash = await bcrypt.hash(password, 10);
    const [result] = await conn.execute(`INSERT INTO users(username,password_hash,full_name,role,warehouse_id)VALUES(?,?,?,?,?)`, [username, hash, full_name, role, warehouse_id]);
    await conn.commit();
    await writeLog(conn, req.user, "CREATE", "user", result.insertId,
      `Tạo tài khoản: ${username} (${role})`);
    return R.created(res, { id: result.insertId, username, full_name, role, warehouse_id, warehouse_code: warehouse_code || null }, "Tạo tài khoản thành công");
  } catch (err) { await conn.rollback(); if (err.code === "ER_DUP_ENTRY") return R.badRequest(res, `Username "${req.body.username}" đã tồn tại`); return R.serverError(res, err); }
  finally { conn.release(); }
};

const update = async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const { id } = req.params;
    const { full_name, role, warehouse_code, is_active } = req.body;
    if (String(id) === String(req.user.id) && role && role !== req.user.role) return R.badRequest(res, "Không thể tự thay đổi role");
    const warehouse_id = await resolveWarehouse(conn, warehouse_code);
    await conn.execute(`UPDATE users SET full_name=?,role=?,warehouse_id=?,is_active=? WHERE id=?`, [full_name, role, warehouse_id, is_active ? 1 : 0, id]);
    await conn.commit();
    await writeLog(conn, req.user, "UPDATE", "user", id,
      `Cập nhật tài khoản id=${id}: role=${role}, is_active=${is_active ? 1 : 0}`);
    return R.ok(res, { warehouse_id, warehouse_code: warehouse_code || null }, "Cập nhật thành công");
  } catch (err) { await conn.rollback(); return R.serverError(res, err); }
  finally { conn.release(); }
};

const resetPassword = async (req, res) => {
  try {
    const { new_password } = req.body;
    if (!new_password || new_password.length < 6) return R.badRequest(res, "Mật khẩu phải ít nhất 6 ký tự");
    const hash = await bcrypt.hash(new_password, 10);
    await db.execute("UPDATE users SET password_hash=? WHERE id=?", [hash, req.params.id]);
    return R.ok(res, {}, "Đặt lại mật khẩu thành công");
  } catch (err) { return R.serverError(res, err); }
};

const remove = async (req, res) => {
  try {
    if (String(req.params.id) === String(req.user.id)) return R.badRequest(res, "Không thể xóa tài khoản đang đăng nhập");
    await db.execute("UPDATE users SET is_active=0 WHERE id=?", [req.params.id]);
    return R.ok(res, {}, "Đã vô hiệu hóa tài khoản");
  } catch (err) { return R.serverError(res, err); }
};

module.exports = { getAll, create, update, resetPassword, remove };
