// src/middleware/uploadExcel.js
// Cấu hình upload file Excel dùng chung cho các route import/export
"use strict";

const multer = require("multer");

// File upload — RAM only, max 10MB, chỉ nhận xlsx/xls
const uploadExcel = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: (parseInt(process.env.UPLOAD_MAX_SIZE_MB) || 10) * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
        const ok = file.mimetype.includes("spreadsheet") ||
            file.originalname.match(/\.(xlsx|xls)$/i);
        cb(ok ? null : new Error("Chỉ chấp nhận .xlsx hoặc .xls"), !!ok);
    },
});

module.exports = uploadExcel;