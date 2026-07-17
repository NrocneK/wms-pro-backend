// src/routes/user.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const { authorize } = require("../middleware/auth");
const userCtrl = require("../controllers/userController");

// ⚠️ "/me" phải đứng trước "/:id" để tránh Express hiểu "me" là :id
router.put("/me", userCtrl.updateSelf);

router.get("/", authorize("admin"), userCtrl.getAll);
router.post("/", authorize("admin"), userCtrl.create);
router.put("/:id", authorize("admin"), userCtrl.update);
router.post("/:id/reset-password", authorize("admin"), userCtrl.resetPassword);
router.delete("/:id", authorize("admin"), userCtrl.remove);

module.exports = router;