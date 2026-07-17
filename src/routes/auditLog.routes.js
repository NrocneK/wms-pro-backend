// src/routes/auditLog.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const { authorize } = require("../middleware/auth");
const auditLogCtrl = require("../controllers/auditLogController");

router.get("/", authorize("admin", "manager"), auditLogCtrl.getAll);

module.exports = router;