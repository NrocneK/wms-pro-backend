// src/server.js
// Entry point THẬT SỰ khi chạy production/dev — require app.js (đã định
// nghĩa xong toàn bộ middleware/routes) rồi mới gọi listen().
// Tách khỏi app.js để test (supertest) có thể import app mà không tự mở
// cổng mạng.
"use strict";

const app = require("./app");

const PORT = parseInt(process.env.PORT) || 3001;

app.listen(PORT, "0.0.0.0", () => {
    console.log(`\n🚀 WMS Pro API đang chạy trên port ${PORT}`);
    console.log(`   Môi trường : ${process.env.NODE_ENV || "development"}`);
    console.log(`   Health check: http://localhost:${PORT}/health`);
    console.log(`   API base    : http://localhost:${PORT}/api/v1\n`);
});