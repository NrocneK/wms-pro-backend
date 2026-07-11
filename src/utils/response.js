// src/utils/response.js
// Chuẩn hóa format response cho toàn bộ API

"use strict";

const ok = (res, data = {}, message = "Thành công", statusCode = 200) =>
  res.status(statusCode).json({ success: true, message, data });

const created = (res, data = {}, message = "Tạo mới thành công") =>
  res.status(201).json({ success: true, message, data });

const badRequest = (res, message = "Dữ liệu không hợp lệ", errors = null) =>
  res.status(400).json({ success: false, message, errors });

const unauthorized = (res, message = "Chưa đăng nhập") =>
  res.status(401).json({ success: false, message });

const forbidden = (res, message = "Không có quyền") =>
  res.status(403).json({ success: false, message });

const notFound = (res, message = "Không tìm thấy") =>
  res.status(404).json({ success: false, message });

const serverError = (res, err, message = "Lỗi hệ thống") => {
  console.error("[SERVER ERROR]", err);
  return res.status(500).json({
    success: false,
    message,
    ...(process.env.NODE_ENV === "development" && { detail: err.message }),
  });
};

module.exports = { ok, created, badRequest, unauthorized, forbidden, notFound, serverError };
