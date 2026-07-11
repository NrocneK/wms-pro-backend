// src/middleware/auth.js
// Xác thực JWT token cho mọi route được bảo vệ

"use strict";
const jwt = require("jsonwebtoken");

/**
 * Middleware xác thực — gắn req.user nếu token hợp lệ
 */
const authenticate = (req, res, next) => {
  const header = req.headers["authorization"];
  if (!header || !header.startsWith("Bearer ")) {
    return res.status(401).json({ success: false, message: "Chưa đăng nhập" });
  }

  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    req.user = payload;   // { id, username, role, warehouse_id }
    next();
  } catch (err) {
    const msg = err.name === "TokenExpiredError" ? "Token đã hết hạn" : "Token không hợp lệ";
    return res.status(401).json({ success: false, message: msg });
  }
};

/**
 * Middleware phân quyền — chỉ cho phép role nhất định
 * Dùng: authorize("admin", "manager")
 */
const authorize = (...roles) => (req, res, next) => {
  if (!roles.includes(req.user?.role)) {
    return res.status(403).json({ success: false, message: "Không có quyền thực hiện thao tác này" });
  }
  next();
};

module.exports = { authenticate, authorize };
