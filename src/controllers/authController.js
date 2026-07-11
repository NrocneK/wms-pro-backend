// src/controllers/authController.js
"use strict";

const bcrypt = require("bcryptjs");
const jwt    = require("jsonwebtoken");
const db     = require("../config/db");
const R      = require("../utils/response");

// ── Đăng nhập ───────────────────────────────────
const login = async (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password)
      return R.badRequest(res, "Vui lòng nhập username và mật khẩu");

    const [rows] = await db.execute(
      `SELECT u.id, u.username, u.password_hash, u.full_name, u.role,
              u.warehouse_id, w.code AS warehouse_code, u.is_active
       FROM users u
       LEFT JOIN warehouses w ON w.id = u.warehouse_id
       WHERE u.username = ? LIMIT 1`,
      [username]
    );

    const user = rows[0];
    if (!user || !user.is_active)
      return R.unauthorized(res, "Tài khoản không tồn tại hoặc đã bị khóa");

    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) return R.unauthorized(res, "Mật khẩu không đúng");

    await db.execute("UPDATE users SET last_login = NOW() WHERE id = ?", [user.id]);

    const payload = {
      id:             user.id,
      username:       user.username,
      full_name:      user.full_name,
      role:           user.role,
      warehouse_id:   user.warehouse_id,   // integer ID — dùng cho DB queries
      warehouse_code: user.warehouse_code, // mã kho — dùng cho UI
    };

    const token        = jwt.sign(payload, process.env.JWT_SECRET, { expiresIn: process.env.JWT_EXPIRES_IN || "8h" });
    const refreshToken = jwt.sign({ id: user.id }, process.env.JWT_SECRET, { expiresIn: process.env.JWT_REFRESH_EXPIRES_IN || "7d" });

    return R.ok(res, { token, refreshToken, user: payload }, "Đăng nhập thành công");
  } catch (err) { return R.serverError(res, err); }
};

// ── Refresh token ────────────────────────────────
const refresh = async (req, res) => {
  try {
    const { refreshToken } = req.body;
    if (!refreshToken) return R.badRequest(res, "Thiếu refresh token");

    const payload = jwt.verify(refreshToken, process.env.JWT_SECRET);
    const [rows]  = await db.execute(
      `SELECT u.id, u.username, u.full_name, u.role,
              u.warehouse_id, w.code AS warehouse_code
       FROM users u
       LEFT JOIN warehouses w ON w.id = u.warehouse_id
       WHERE u.id = ? AND u.is_active = 1`,
      [payload.id]
    );
    if (!rows[0]) return R.unauthorized(res, "Tài khoản không hợp lệ");

    const user  = rows[0];
    const token = jwt.sign(
      { id:user.id, username:user.username, full_name:user.full_name,
        role:user.role, warehouse_id:user.warehouse_id, warehouse_code:user.warehouse_code },
      process.env.JWT_SECRET,
      { expiresIn: process.env.JWT_EXPIRES_IN || "8h" }
    );
    return R.ok(res, { token }, "Token đã được gia hạn");
  } catch (err) {
    return R.unauthorized(res, "Refresh token không hợp lệ hoặc đã hết hạn");
  }
};

// ── Đổi mật khẩu ────────────────────────────────
const changePassword = async (req, res) => {
  try {
    const { old_password, new_password } = req.body;
    if (!old_password || !new_password)
      return R.badRequest(res, "Vui lòng nhập đầy đủ thông tin");
    if (new_password.length < 8)
      return R.badRequest(res, "Mật khẩu mới phải ít nhất 8 ký tự");

    const [rows] = await db.execute("SELECT password_hash FROM users WHERE id = ?", [req.user.id]);
    if (!rows[0]) return R.notFound(res, "Người dùng không tồn tại");

    const valid = await bcrypt.compare(old_password, rows[0].password_hash);
    if (!valid) return R.badRequest(res, "Mật khẩu cũ không đúng");

    const hash = await bcrypt.hash(new_password, 10);
    await db.execute("UPDATE users SET password_hash = ? WHERE id = ?", [hash, req.user.id]);
    return R.ok(res, {}, "Đổi mật khẩu thành công");
  } catch (err) { return R.serverError(res, err); }
};

// ── Thông tin người dùng hiện tại ───────────────
const me = async (req, res) => {
  try {
    const [rows] = await db.execute(
      `SELECT u.id, u.username, u.full_name, u.role,
              u.warehouse_id, w.code AS warehouse_code, w.name AS warehouse_name,
              u.last_login, u.created_at
       FROM users u
       LEFT JOIN warehouses w ON w.id = u.warehouse_id
       WHERE u.id = ?`,
      [req.user.id]
    );
    if (!rows[0]) return R.notFound(res);
    return R.ok(res, rows[0]);
  } catch (err) { return R.serverError(res, err); }
};

module.exports = { login, refresh, changePassword, me };
