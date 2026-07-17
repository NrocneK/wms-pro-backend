// src/routes/product.routes.js
"use strict";

const express = require("express");
const router = express.Router();

const { authorize } = require("../middleware/auth");
const productCtrl = require("../controllers/productController");

router.get("/", productCtrl.getAll);
router.get("/:barcode", productCtrl.getByBarcode);
router.post("/", authorize("admin", "manager"), productCtrl.create);
router.put("/:id", authorize("admin", "manager"), productCtrl.update);
router.delete("/:id", authorize("admin"), productCtrl.remove);

module.exports = router;