// src/routes/index.js
// File này CHỈ gom các route theo domain lại — không chứa business logic.
// Nếu cần thêm/sửa 1 nhóm API, sửa đúng file routes/<domain>.routes.js tương ứng.
"use strict";

const express = require("express");
const router = express.Router();

const { authenticate } = require("../middleware/auth");

// ── PUBLIC (không cần token) ──────────────────────
router.use("/auth", require("./authPublic.routes"));

// ── Tất cả route bên dưới cần JWT ────────────────
router.use(authenticate);

router.use("/auth", require("./auth.routes"));
router.use("/products", require("./product.routes"));
router.use("/imports", require("./import.routes"));
router.use("/exports", require("./export.routes"));
router.use("/users", require("./user.routes"));
router.use("/warehouses", require("./warehouse.routes"));
router.use("/audit-logs", require("./auditLog.routes"));
router.use("/inventory", require("./inventory.routes"));
router.use("/dashboard", require("./dashboard.routes"));
router.use("/reports", require("./report.routes"));

module.exports = router;