// src/routes/warehouse.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const warehouseCtrl = require("../controllers/warehouseController");

router.get("/", warehouseCtrl.getAll);

module.exports = router;