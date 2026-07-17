// src/routes/import.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const { authorize } = require("../middleware/auth");
const uploadExcel = require("../middleware/uploadExcel");
const importCtrl = require("../controllers/importOrderController");

router.post("/parse-excel", uploadExcel.single("file"), importCtrl.parseExcel);
router.get("/", importCtrl.getAll);
router.get("/:id", importCtrl.getOne);
router.post("/", importCtrl.create);
router.post("/:id/confirm", authorize("admin", "manager", "staff"), importCtrl.confirm);

module.exports = router;