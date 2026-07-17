// src/routes/export.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const { authorize } = require("../middleware/auth");
const uploadExcel = require("../middleware/uploadExcel");
const exportCtrl = require("../controllers/exportController");

router.post("/parse-excel", uploadExcel.single("file"), exportCtrl.parseExcel);

// ⚠️ QUAN TRỌNG: "/packing" PHẢI đứng trước "/:id" — nếu đảo thứ tự,
router.get("/packing", exportCtrl.getPackingBatches);
router.get("/", exportCtrl.getAll);
router.get("/:id", exportCtrl.getOne);
router.get("/:id/packing-tickets", exportCtrl.getBatchTickets);
router.get("/:id/packing-tickets/:refNo/items", exportCtrl.getTicketItems);
router.post("/", exportCtrl.create);
router.post("/:id/confirm", authorize("admin", "manager", "staff"), exportCtrl.confirm);
router.post("/:id/cancel", authorize("admin", "manager", "staff"), exportCtrl.cancelBatch);
router.put("/items/:itemId/actual-quantity", authorize("admin", "manager", "staff"), exportCtrl.updateActualQuantity);

module.exports = router;