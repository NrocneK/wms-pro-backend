// src/routes/index.js
"use strict";

const express = require("express");
const multer = require("multer");
const router = express.Router();

const { authenticate, authorize } = require("../middleware/auth");
const authCtrl = require("../controllers/authController");
const productCtrl = require("../controllers/productController");
const importCtrl = require("../controllers/importController");
const exportCtrl = require("../controllers/exportController");
const inventoryCtrl = require("../controllers/inventoryController");

// File upload — RAM only, max 10MB, chỉ nhận xlsx/xls
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: (parseInt(process.env.UPLOAD_MAX_SIZE_MB) || 10) * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ok = file.mimetype.includes("spreadsheet") ||
      file.originalname.match(/\.(xlsx|xls)$/i);
    cb(ok ? null : new Error("Chỉ chấp nhận .xlsx hoặc .xls"), !!ok);
  },
});

const invImportCtrl = require("../controllers/inventoryImportController");
const userCtrl = require("../controllers/userController");

// ── PUBLIC (không cần token) ──────────────────────
router.post("/auth/login", authCtrl.login);
router.post("/auth/refresh", authCtrl.refresh);

// ── Tất cả route bên dưới cần JWT ────────────────
router.use(authenticate);

// AUTH
router.get("/auth/me", authCtrl.me);
router.post("/auth/change-password", authCtrl.changePassword);

// PRODUCTS
router.get("/products", productCtrl.getAll);
router.get("/products/:barcode", productCtrl.getByBarcode);
router.post("/products", authorize("admin", "manager"), productCtrl.create);
router.put("/products/:id", authorize("admin", "manager"), productCtrl.update);
router.delete("/products/:id", authorize("admin"), productCtrl.remove);

// IMPORT — staff được phép confirm (thao tác nhập/xuất)
router.post("/imports/parse-excel", upload.single("file"), importCtrl.parseExcel);
router.get("/imports", importCtrl.getAll);
router.get("/imports/:id", importCtrl.getOne);
router.post("/imports", importCtrl.create);
router.post("/imports/:id/confirm", authorize("admin", "manager", "staff"), importCtrl.confirm);

// EXPORT — staff được phép confirm
router.post("/exports/parse-excel", upload.single("file"), exportCtrl.parseExcel);
router.get("/exports/packing", exportCtrl.getPackingBatches);
router.get("/exports", exportCtrl.getAll);
router.get("/exports/:id", exportCtrl.getOne);
router.get("/exports/:id/packing-tickets", exportCtrl.getBatchTickets);
router.get("/exports/:id/packing-tickets/:refNo/items", exportCtrl.getTicketItems);
router.post("/exports", exportCtrl.create);
router.post("/exports/:id/confirm", authorize("admin", "manager", "staff"), exportCtrl.confirm);
router.post("/exports/:id/cancel", authorize("admin", "manager", "staff"), exportCtrl.cancelBatch);
router.put("/exports/items/:itemId/actual-quantity", authorize("admin", "manager", "staff"), exportCtrl.updateActualQuantity);

// USERS — chỉ admin
router.get("/users", authorize("admin"), userCtrl.getAll);
router.post("/users", authorize("admin"), userCtrl.create);
router.put("/users/:id", authorize("admin"), userCtrl.update);
router.post("/users/:id/reset-password", authorize("admin"), userCtrl.resetPassword);
router.delete("/users/:id", authorize("admin"), userCtrl.remove);

// WAREHOUSES — danh sách kho (dùng cho selector import/export)
router.get("/warehouses", async (req, res) => {
  try {
    const db = require("../config/db");
    const R = require("../utils/response");
    const [rows] = await db.execute(
      `SELECT id, code, name FROM warehouses WHERE is_active=1 ORDER BY code`
    );
    return R.ok(res, rows);
  } catch (err) {
    const R = require("../utils/response");
    return R.serverError(res, err);
  }
});


// AUDIT LOGS — admin và manager xem được
router.get("/audit-logs", authorize("admin", "manager"), async (req, res) => {
  const { page = 1, limit = 50, entity = "", action = "" } = req.query;
  const offset = (parseInt(page) - 1) * parseInt(limit);
  const params = [];
  let where = "WHERE 1=1";
  if (entity) { where += " AND entity=?"; params.push(entity); }
  if (action) { where += " AND action=?"; params.push(action); }

  const db = require("../config/db");
  const R = require("../utils/response");
  const [[{ total }]] = await db.execute(
    `SELECT COUNT(*) AS total FROM audit_logs ${where}`, params
  );
  const [rows] = await db.execute(
    `SELECT * FROM audit_logs ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
    [...params, parseInt(limit), offset]
  );
  return R.ok(res, {
    items: rows,
    pagination: { total, page: parseInt(page), limit: parseInt(limit) }
  });
});

// INVENTORY REPLACE (import từ Excel, thay thế toàn bộ)
router.post("/inventory/preview-replace", upload.single("file"), invImportCtrl.previewReplace);
router.post("/inventory/import-replace", authorize("admin", "manager"), upload.single("file"), invImportCtrl.importReplace);

// INVENTORY & REPORTS
router.get("/dashboard", inventoryCtrl.getDashboard);
router.get("/dashboard/history-dates", inventoryCtrl.getActivityHistoryDates);
router.get("/dashboard/history-orders", inventoryCtrl.getOrdersByDate);
router.get("/inventory", inventoryCtrl.getInventory);
router.get("/inventory/alerts", inventoryCtrl.getAlerts);
router.post("/inventory", authorize("admin", "manager"), inventoryCtrl.createInventoryItem);
router.put("/inventory/:id", authorize("admin", "manager"), inventoryCtrl.updateInventoryItem);
router.delete("/inventory/batch", authorize("admin"), inventoryCtrl.removeBatchInventory);
router.delete("/inventory/:id", authorize("admin"), inventoryCtrl.removeInventoryItem);
router.get("/reports/by-category", inventoryCtrl.getReportByCategory);
router.get("/reports/user-activity", inventoryCtrl.getReportUserActivity);

module.exports = router;
