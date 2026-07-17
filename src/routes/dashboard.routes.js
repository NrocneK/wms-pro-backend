// src/routes/dashboard.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const inventoryCtrl = require("../controllers/inventoryController");

router.get("/", inventoryCtrl.getDashboard);
router.get("/history-dates", inventoryCtrl.getActivityHistoryDates);
router.get("/history-orders", inventoryCtrl.getOrdersByDate);
router.get("/export-items", inventoryCtrl.getExportItemsByRefNo);

module.exports = router;