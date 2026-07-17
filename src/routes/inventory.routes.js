// src/routes/inventory.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const { authorize } = require("../middleware/auth");
const uploadExcel = require("../middleware/uploadExcel");
const inventoryCtrl = require("../controllers/inventoryController");
const invReplaceCtrl = require("../controllers/inventoryReplaceController");

// INVENTORY REPLACE (import từ Excel, thay thế toàn bộ)
router.post("/preview-replace", uploadExcel.single("file"), invReplaceCtrl.previewReplace);
router.post("/import-replace", authorize("admin", "manager"), uploadExcel.single("file"), invReplaceCtrl.importReplace);

// INVENTORY CRUD
router.get("/alerts", inventoryCtrl.getAlerts);
router.get("/", inventoryCtrl.getInventory);
router.post("/", authorize("admin", "manager", "staff"), inventoryCtrl.createInventoryItem);
router.put("/:id", authorize("admin", "manager"), inventoryCtrl.updateInventoryItem);
router.delete("/batch", authorize("admin"), inventoryCtrl.removeBatchInventory);
router.delete("/:id", authorize("admin"), inventoryCtrl.removeInventoryItem);

module.exports = router;