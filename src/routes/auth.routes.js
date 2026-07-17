// src/routes/auth.routes.js
// Route CẦN token — mount SAU router.use(authenticate) trong index.js
"use strict";

const express = require("express");
const router = express.Router();

const authCtrl = require("../controllers/authController");

router.get("/me", authCtrl.me);
router.post("/change-password", authCtrl.changePassword);

module.exports = router;