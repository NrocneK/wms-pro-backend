// src/config/db.js
// MySQL connection pool — dùng chung toàn app, không tạo connection mới mỗi request

"use strict";
const mysql = require("mysql2/promise");
const dotenv = require("dotenv");
dotenv.config();

const pool = mysql.createPool({
  host: process.env.DB_HOST || "localhost",
  port: parseInt(process.env.DB_PORT) || 3306,
  database: process.env.DB_NAME || "wms_pro",
  user: process.env.DB_USER || "wms_user",
  password: process.env.DB_PASSWORD || "",
  waitForConnections: true,
  connectionLimit: parseInt(process.env.DB_POOL_MAX) || 20,
  queueLimit: 0,
  charset: "utf8mb4",
  timezone: "+07:00",
  decimalNumbers: true,
  // Thêm mới: bật SSL khi có biến DB_SSL_CA (chứa nội dung cert, không phải đường dẫn)
  ssl: process.env.DB_SSL_CA
    ? { ca: process.env.DB_SSL_CA }
    : undefined,
});

// Kiểm tra kết nối khi khởi động
pool.getConnection()
  .then(conn => {
    console.log("✅ MySQL connected — pool ready");
    conn.release();
  })
  .catch(err => {
    console.error("❌ MySQL connection failed:", err.message);
    process.exit(1);   // dừng server nếu không kết nối được DB
  });

module.exports = pool;
