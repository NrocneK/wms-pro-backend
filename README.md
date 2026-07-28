# WMS Pro — Warehouse Management System (Backend)

> REST API backend for WMS Pro — a professional warehouse management system built for bookstore & publishing operations.

![Node.js](https://img.shields.io/badge/Node.js-18+-339933?logo=node.js)
![Express](https://img.shields.io/badge/Express-4-000000?logo=express)
![MySQL](https://img.shields.io/badge/MySQL-8-4479A1?logo=mysql)
![JWT](https://img.shields.io/badge/Auth-JWT-orange)
![License](https://img.shields.io/badge/license-MIT-green)

**Frontend Repo:** [wms-pro-frontend](https://github.com/NrocneK/wms-pro-frontend)
**Deployed on:** Render (API) + Aiven MySQL (Database)

---

## ✨ Features

- **JWT Authentication** — access token + refresh token rotation
- **Role & Warehouse-based Authorization** — Admin (global) vs Warehouse Keeper (scoped)
- **Inventory Management** — multi-warehouse stock tracking, real-time levels
- **Import / Export** — Excel file processing via SheetJS (multer + xlsx)
- **Picking Slip Generation** — outbound order management
- **Audit Log** — every write operation is logged with user, timestamp, action
- **Security** — helmet, CORS, rate limiting, bcryptjs password hashing, compression

---

## 🛠️ Tech Stack

| Category         | Technology                       |
| ---------------- | -------------------------------- |
| Runtime          | Node.js 18+                      |
| Framework        | Express 4                        |
| Database         | MySQL 8 (via mysql2)             |
| ORM/Query        | Raw SQL + mysql2                 |
| Auth             | JWT (access + refresh tokens)    |
| Password         | bcryptjs                         |
| File Upload      | multer                           |
| Excel Processing | SheetJS (xlsx)                   |
| Security         | helmet, cors, express-rate-limit |
| Compression      | compression                      |

---

## 🏗️ Architecture

```
Client (React Frontend)
        │
        ▼
   Express App (app.js)
        │
   ┌────┴────────────────────────────┐
   │  Middleware Stack               │
   │  helmet · cors · rate-limit     │
   │  compression · json-parser      │
   └────┬────────────────────────────┘
        │
   Auth Middleware (JWT verify)
        │
   ┌────┴────────────────────────────┐
   │  Routes                         │
   │  /auth    /users    /inventory  │
   │  /import  /export   /audit-log  │
   │  /picking /warehouses           │
   └────┬────────────────────────────┘
        │
   MySQL (Aiven Cloud)
```

---

## 🚀 Getting Started

### Prerequisites

- Node.js >= 18
- MySQL 8 (local via XAMPP, or cloud via Aiven)

### Installation

```bash
# Clone the repo
git clone https://github.com/NrocneK/wms-pro-backend.git
cd wms-pro-backend

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env

# Run database migrations (see /sql folder)
# Import the SQL schema file into your MySQL instance

# Start development server
npm run dev
```

---

## ⚙️ Environment Variables

```env
# Server
PORT=5000
NODE_ENV=development

# Database
DB_HOST=localhost
DB_PORT=3306
DB_USER=root
DB_PASSWORD=your_password
DB_NAME=wms_pro

# JWT
JWT_SECRET=your_jwt_secret_key
JWT_REFRESH_SECRET=your_refresh_secret_key
JWT_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=7d

# CORS
ALLOWED_ORIGIN=http://localhost:5173
```

---

## 📁 Project Structure

```
src/
├── app.js                  # Entry point — Express setup, middleware
├── config/
│   └── db.js               # MySQL connection pool
├── middleware/
│   ├── auth.js             # JWT verification
│   ├── authorize.js        # Role & warehouse permission checks
│   └── errorHandler.js     # Global error handler
├── routes/
│   ├── auth.routes.js
│   ├── user.routes.js
│   ├── inventory.routes.js
│   ├── import.routes.js
│   ├── export.routes.js
│   ├── picking.routes.js
│   ├── warehouse.routes.js
│   └── auditLog.routes.js
├── controllers/            # Business logic per route
├── services/               # Reusable service layer
└── utils/                  # Helpers: Excel parser, PDF gen, etc.
sql/
└── wms-pro.sql              # Full database schema
```

---

## 🔐 Authorization Model

| Role                 | Scope                                                    |
| -------------------- | -------------------------------------------------------- |
| **Admin**            | Full access — all warehouses, user management, audit log |
| **Warehouse Keeper** | Scoped to assigned warehouse(s) only                     |

Every protected route checks:

1. Valid JWT token
2. Role permission (Admin vs Keeper)
3. Warehouse scope (for Keepers)

---

## 👤 Author

**Ngo Minh Nhut**

- GitHub: [@NrocneK](https://github.com/NrocneK)
- Email: kdc.1110639@gmail.com
