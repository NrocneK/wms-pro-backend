// vitest.config.js
// Cấu hình Vitest cho backend — môi trường Node.js thuần (không cần giả
// lập trình duyệt như frontend). Test mặc định tìm mọi file trong tests/.
const { defineConfig } = require("vitest/config");

module.exports = defineConfig({
    test: {
        environment: "node",
        globals: true,
        // Chạy tuần tự (không song song) vì các test integration cùng dùng
        // chung 1 kết nối database — chạy song song dễ gây xung đột dữ liệu.
        fileParallelism: false,
    },
});