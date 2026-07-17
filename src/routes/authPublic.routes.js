// src/routes/authPublic.routes.js
// Route KHÔNG cần token — phải mount TRƯỚC router.use(authenticate) trong index.js
"use strict";

const express = require("express");
const router = express.Router();

const authCtrl = require("../controllers/authController");

router.post("/login", authCtrl.login);
router.post("/refresh", authCtrl.refresh);

module.exports = router;