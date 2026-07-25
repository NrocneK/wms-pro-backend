// tests/auth.test.js
//
// INTEGRATION TEST — khác unit test ở chỗ: file này gọi request HTTP THẬT
// vào app Express thật (qua supertest), và app đó query vào MySQL local
// thật (không giả lập). Mục đích: kiểm tra toàn bộ luồng đăng nhập hoạt
// động đúng từ đầu đến cuối — nhận request → query DB → so mật khẩu → trả
// token — chứ không chỉ 1 hàm đơn lẻ như unit test.
//
// AN TOÀN: file này CHỈ được chạy khi .env trỏ tới MySQL LOCAL (XAMPP).
// Không bao giờ chạy `npm test` với .env đang trỏ vào Aiven/production.
//
// Cách hoạt động của supertest: request(app).post("/api/v1/auth/login")
// gửi 1 request HTTP giả lập thẳng vào app, KHÔNG mở cổng mạng thật —
// nhanh hơn nhiều so với việc thật sự chạy server rồi gọi qua Postman.

import { describe, test, expect, beforeAll, afterAll } from "vitest";
import request from "supertest";
import bcrypt from "bcryptjs";
import app from "../src/app.js";
import db from "../src/config/db.js";

// Username/password riêng cho test — KHÔNG dùng chung với tài khoản thật
// nào trong database, để test tự tạo/tự dọn dữ liệu của chính nó, không
// phụ thuộc vào việc DB local đang có sẵn user nào.
const TEST_USERNAME = "__test_auth_user__";
const TEST_PASSWORD = "TestPass123!";
let testUserId;

// beforeAll chạy 1 LẦN DUY NHẤT trước khi tất cả test trong file này bắt
// đầu — dùng để chuẩn bị dữ liệu cần thiết (ở đây là tạo 1 user test).
beforeAll(async () => {
    const hash = await bcrypt.hash(TEST_PASSWORD, 10);
    const [result] = await db.execute(
        `INSERT INTO users (username, password_hash, full_name, role, is_active)
     VALUES (?, ?, ?, ?, 1)`,
        [TEST_USERNAME, hash, "Test User", "staff"]
    );
    testUserId = result.insertId;
});

// afterAll chạy 1 LẦN DUY NHẤT sau khi tất cả test xong — dọn dẹp dữ liệu
// đã tạo, để không để lại rác trong database sau mỗi lần chạy test.
afterAll(async () => {
    if (testUserId) await db.execute("DELETE FROM users WHERE id = ?", [testUserId]);
    await db.end(); // đóng connection pool — nếu không, `npm test` sẽ treo không thoát được
});

describe("POST /api/v1/auth/login", () => {
    test("đăng nhập đúng username + password → trả về token", async () => {
        const res = await request(app)
            .post("/api/v1/auth/login")
            .send({ username: TEST_USERNAME, password: TEST_PASSWORD });

        expect(res.status).toBe(200);
        expect(res.body.success).toBe(true);
        expect(res.body.data.token).toBeTruthy();
        expect(res.body.data.refreshToken).toBeTruthy();
        expect(res.body.data.user.username).toBe(TEST_USERNAME);
        expect(res.body.data.user.role).toBe("staff");
    });

    test("sai mật khẩu → 401, không lộ token", async () => {
        const res = await request(app)
            .post("/api/v1/auth/login")
            .send({ username: TEST_USERNAME, password: "sai-mat-khau" });

        expect(res.status).toBe(401);
        expect(res.body.success).toBe(false);
        expect(res.body.data).toBeUndefined();
    });

    test("username không tồn tại → 401 (không tiết lộ là do sai username hay sai gì)", async () => {
        const res = await request(app)
            .post("/api/v1/auth/login")
            .send({ username: "khong_ton_tai_123456", password: "bat-ky" });

        expect(res.status).toBe(401);
    });

    test("thiếu username hoặc password → 400", async () => {
        const res1 = await request(app).post("/api/v1/auth/login").send({ password: "abc" });
        expect(res1.status).toBe(400);

        const res2 = await request(app).post("/api/v1/auth/login").send({ username: "abc" });
        expect(res2.status).toBe(400);
    });
});

describe("GET /api/v1/auth/me — endpoint cần xác thực", () => {
    test("không có token → 401 (middleware auth chặn đúng)", async () => {
        const res = await request(app).get("/api/v1/auth/me");
        expect(res.status).toBe(401);
    });

    test("có token hợp lệ → trả về đúng thông tin user đã đăng nhập", async () => {
        // Đăng nhập trước để lấy token thật — không hardcode token giả
        const loginRes = await request(app)
            .post("/api/v1/auth/login")
            .send({ username: TEST_USERNAME, password: TEST_PASSWORD });
        const token = loginRes.body.data.token;

        const res = await request(app)
            .get("/api/v1/auth/me")
            .set("Authorization", `Bearer ${token}`);

        expect(res.status).toBe(200);
        expect(res.body.data.username).toBe(TEST_USERNAME);
    });

    test("token sai định dạng/giả mạo → 401", async () => {
        const res = await request(app)
            .get("/api/v1/auth/me")
            .set("Authorization", "Bearer token-gia-mao-khong-hop-le");
        expect(res.status).toBe(401);
    });
});