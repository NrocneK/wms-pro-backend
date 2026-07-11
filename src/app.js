// src/app.js
// Entry point — khởi động Express server
"use strict";

require("dotenv").config();
const express     = require("express");
const cors        = require("cors");
const helmet      = require("helmet");
const compression = require("compression");
const morgan      = require("morgan");
const rateLimit   = require("express-rate-limit");

const routes = require("./routes");

const app  = express();
const PORT = parseInt(process.env.PORT) || 3001;

// ─────────────────────────────────────────────
// MIDDLEWARE bảo mật & tiện ích
// ─────────────────────────────────────────────
app.use(helmet());        // bảo mật HTTP headers
app.use(compression());   // gzip response

// CORS — chỉ cho phép domain được cấu hình
const allowedOrigins = (process.env.ALLOWED_ORIGINS || "").split(",").map(o => o.trim()).filter(Boolean);
app.use(cors({
  origin: (origin, cb) => {
    if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
    cb(new Error(`CORS blocked: ${origin}`));
  },
  methods:     ["GET","POST","PUT","DELETE","OPTIONS"],
  allowedHeaders: ["Content-Type","Authorization"],
  credentials: true,
}));

// Rate limiting
app.use(rateLimit({
  windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS) || 15 * 60 * 1000,
  max:      parseInt(process.env.RATE_LIMIT_MAX)        || 500,
  message:  { success: false, message: "Quá nhiều yêu cầu, vui lòng thử lại sau" },
}));

// Logging
app.use(morgan(process.env.NODE_ENV === "production" ? "combined" : "dev"));

// Body parsing
app.use(express.json({ limit: "5mb" }));
app.use(express.urlencoded({ extended: true, limit: "5mb" }));

// ─────────────────────────────────────────────
// ROUTES
// ─────────────────────────────────────────────
app.use("/api/v1", routes);

// Health check
app.get("/health", (req, res) => res.json({
  status: "ok",
  app:    "WMS Pro API",
  version:"1.0.0",
  time:   new Date().toISOString(),
}));

// 404 handler
app.use((req, res) => res.status(404).json({ success: false, message: `Route không tồn tại: ${req.path}` }));

// Global error handler
app.use((err, req, res, next) => {
  console.error("[UNHANDLED ERROR]", err);
  res.status(500).json({
    success: false,
    message: err.message || "Lỗi hệ thống",
    ...(process.env.NODE_ENV === "development" && { stack: err.stack }),
  });
});

// ─────────────────────────────────────────────
// START
// ─────────────────────────────────────────────
app.listen(PORT, "0.0.0.0", () => {
  console.log(`\n🚀 WMS Pro API đang chạy trên port ${PORT}`);
  console.log(`   Môi trường : ${process.env.NODE_ENV || "development"}`);
  console.log(`   Health check: http://localhost:${PORT}/health`);
  console.log(`   API base    : http://localhost:${PORT}/api/v1\n`);
});

module.exports = app;
