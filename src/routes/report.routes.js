// src/routes/report.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const inventoryCtrl = require("../controllers/inventoryController");

router.get("/by-category", inventoryCtrl.getReportByCategory);
router.get("/user-activity", inventoryCtrl.getReportUserActivity);

module.exports = router;