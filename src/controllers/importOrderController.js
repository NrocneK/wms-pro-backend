const { writeLog } = require("../utils/auditLog");

"use strict";
const db = require("../config/db");
const R = require("../utils/response");
const XLSX = require("xlsx");
const { warehouseGuard, assertWarehouse } = require("../middleware/warehouseGuard");
const calcStatus = (qty, min = 5) =>
  qty === 0 ? "zero" : qty <= min ? "low" : qty <= min * 2 ? "warning" : "ok";
const parseDate = (v) => {
  if (!v) return new Date().toISOString().split("T")[0];
  if (typeof v === "number")
    return new Date(Math.round((v - 25569) * 86400 * 1000))
      .toISOString()
      .split("T")[0];
  return String(v).trim();
};

const getAll = async (req, res) => {
  try {
    const { page = 1, limit = 20, status = "" } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { whClause, whParams } = warehouseGuard(req.user, "io.warehouse_id");
    const params = [...whParams];
    let where = `WHERE 1=1 ${whClause}`;
    if (status) {
      where += " AND io.status=?";
      params.push(status);
    }
    const [[{ total }]] = await db.execute(
      `SELECT COUNT(*) AS total FROM import_orders io ${where}`,
      params
    );
    const [rows] = await db.execute(
      `SELECT io.id,io.ref_no,io.import_date,io.status,io.total_items,io.supplier,io.created_by,u.full_name AS created_by_name,w.name AS warehouse_name,w.code AS warehouse_code,io.created_at,io.confirmed_at FROM import_orders io JOIN warehouses w ON w.id=io.warehouse_id LEFT JOIN users u ON u.id=CAST(io.created_by AS UNSIGNED) ${where} ORDER BY io.import_date DESC,io.id DESC LIMIT ? OFFSET ?`,
      [...params, parseInt(limit), offset]
    );
    return R.ok(res, {
      items: rows,
      pagination: {
        total,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (err) {
    return R.serverError(res, err);
  }
};

const getOne = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user, "io.warehouse_id");
    const [[order]] = await db.execute(
      `SELECT io.*,w.name AS warehouse_name,w.code AS warehouse_code FROM import_orders io JOIN warehouses w ON w.id=io.warehouse_id WHERE io.id=? ${whClause}`,
      [req.params.id, ...whParams]
    );
    if (!order)
      return R.notFound(res, "Phiếu không tồn tại hoặc bạn không có quyền");
    const [items] = await db.execute(
      `SELECT ii.*,p.barcode,p.name AS product_name,p.unit FROM import_items ii JOIN products p ON p.id=ii.product_id WHERE ii.import_order_id=? ORDER BY ii.id`,
      [req.params.id]
    );
    return R.ok(res, { ...order, items });
  } catch (err) {
    return R.serverError(res, err);
  }
};

const parseExcel = async (req, res) => {
  try {
    if (!req.file) return R.badRequest(res, "Chưa upload file Excel");
    const wb = XLSX.read(req.file.buffer, { type: "buffer" });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const raw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: "" });
    const rows = raw.slice(1).filter((r) => r[2]);
    if (!rows.length) return R.badRequest(res, "File không có dữ liệu hợp lệ");
    const barcodes = [...new Set(rows.map((r) => String(r[2]).trim()))];
    const { whClause, whParams } = warehouseGuard(req.user, "inv.warehouse_id");
    const [existing] = await db.execute(
      `SELECT p.barcode,p.name,p.unit,p.cost_price,inv.location_text,inv.warehouse_id,w.code AS warehouse_code FROM products p LEFT JOIN inventory inv ON inv.product_id=p.id LEFT JOIN warehouses w ON w.id=inv.warehouse_id WHERE p.barcode IN (${barcodes
        .map(() => "?")
        .join(",")}) ${whClause}`,
      [...barcodes, ...whParams]
    );
    const productMap = {};
    existing.forEach((p) => {
      productMap[p.barcode] = p;
    });
    const firstRefNo = String(rows[0][1] || "").trim();
    const firstDate = parseDate(rows[0][0]);
    const items = rows.map((r) => {
      const barcode = String(r[2]).trim();
      const matched = productMap[barcode];
      return {
        ref_no: String(r[1] || "").trim() || firstRefNo,
        barcode,
        name: String(r[3] || matched?.name || "").trim(),
        quantity: Number(r[4]) || 0,
        unit_price: Number(r[5]) || 0,
        location_code: matched?.location_text || "",
        warehouse_id: matched?.warehouse_id || req.user.warehouse_id || null,
        warehouse_code: matched?.warehouse_code || "",
        cost_price: matched?.cost_price || 0,
        is_new: !matched,
      };
    });
    return R.ok(res, {
      ref_no: firstRefNo,
      import_date: firstDate,
      total_rows: items.length,
      new_barcodes: items.filter((i) => i.is_new).length,
      items,
    });
  } catch (err) {
    return R.serverError(res, err);
  }
};

const create = async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const { import_date, warehouse_id, note, items = [] } = req.body;

    // Không còn dùng ref_no cấp phiếu — mỗi item tự mang ref_no riêng
    if (!import_date || !warehouse_id)
      return R.badRequest(res, "Thiếu import_date hoặc warehouse_id");
    if (!items.length)
      return R.badRequest(res, "Phiếu nhập phải có ít nhất 1 dòng");
    if (!assertWarehouse(warehouse_id, req.user))
      return R.forbidden(res, "Bạn chỉ được nhập hàng vào kho được phân công");

    const [[wh]] = await conn.execute("SELECT id FROM warehouses WHERE id=?", [warehouse_id]);
    if (!wh) return R.badRequest(res, `Kho id=${warehouse_id} không tồn tại`);

    // ── Gom items theo từng ref_no → tạo N import_order độc lập ──
    const groupMap = new Map();
    for (const item of items) {
      const key = item.ref_no || "NO_REF";
      if (!groupMap.has(key)) groupMap.set(key, []);
      groupMap.get(key).push(item);
    }

    const createdOrders = [];
    for (const [ref_no, groupItems] of groupMap) {
      const [hResult] = await conn.execute(
        `INSERT INTO import_orders(ref_no,import_date,warehouse_id,supplier,total_items,note,status,created_by)
         VALUES(?,?,?,'',?,?,'draft',?)`,
        [ref_no, import_date, warehouse_id, groupItems.length, note || null, String(req.user.id)]
      );
      const orderId = hResult.insertId;

      for (const item of groupItems) {
        const { barcode, name, quantity, location_text = "", unit_price = 0 } = item;
        let [[product]] = await conn.execute(
          "SELECT id FROM products WHERE barcode=?", [barcode]
        );
        if (!product) {
          const [np] = await conn.execute(
            "INSERT INTO products(barcode,name,unit,cost_price)VALUES(?,?,?,?)",
            [barcode, name || "(Chưa có tên)", "Cái", unit_price || 0]
          );
          product = { id: np.insertId };
        }
        await conn.execute(
          `INSERT INTO import_items(import_order_id,product_id,location_text,quantity,unit_price)
           VALUES(?,?,?,?,?)`,
          [orderId, product.id, location_text, quantity, unit_price]
        );
      }
      createdOrders.push({ order_id: orderId, ref_no });
    }

    await conn.commit();
    // Trả về cả mảng orders lẫn order_id đầu tiên để tương thích ngược
    return R.created(res, {
      order_id: createdOrders[0].order_id,
      ref_no: createdOrders[0].ref_no,
      orders: createdOrders,
      count: createdOrders.length,
    });
  } catch (err) {
    await conn.rollback();
    if (err.code === "ER_DUP_ENTRY")
      return R.badRequest(res, "Một hoặc nhiều số phiếu đã tồn tại trong hệ thống");
    return R.serverError(res, err);
  } finally {
    conn.release();
  }
};

const confirm = async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[order]] = await conn.execute(
      "SELECT * FROM import_orders WHERE id=? AND status='draft'",
      [req.params.id]
    );
    if (!order)
      return R.badRequest(res, "Phiếu không tồn tại hoặc đã xác nhận");
    if (!assertWarehouse(order.warehouse_id, req.user))
      return R.forbidden(res, "Bạn không có quyền xác nhận phiếu của kho khác");
    const [items] = await conn.execute(
      "SELECT * FROM import_items WHERE import_order_id=?",
      [order.id]
    );
    for (const item of items) {
      const [[inv]] = await conn.execute(
        "SELECT id,quantity,min_stock FROM inventory WHERE product_id=? AND warehouse_id=?",
        [item.product_id, order.warehouse_id]
      );
      if (inv) {
        const newQty = inv.quantity + item.quantity;
        await conn.execute(
          `UPDATE inventory SET quantity=?,status=?,location_text=CASE WHEN ?!='' THEN ? ELSE location_text END,zero_since=NULL,last_import=NOW() WHERE id=?`,
          [
            newQty,
            calcStatus(newQty, inv.min_stock),
            item.location_text,
            item.location_text,
            inv.id,
          ]
        );
      } else {
        await conn.execute(
          `INSERT INTO inventory(product_id,warehouse_id,location_text,quantity,min_stock,status,last_import)VALUES(?,?,?,?,5,?,NOW())`,
          [
            item.product_id,
            order.warehouse_id,
            item.location_text,
            item.quantity,
            calcStatus(item.quantity, 5),
          ]
        );
      }

      if (item.unit_price > 0) {
        await conn.execute(
          "UPDATE products SET cost_price=? WHERE id=?",
          [item.unit_price, item.product_id]
        );
      }
    }
    await conn.execute(
      "UPDATE import_orders SET status='confirmed',confirmed_at=NOW() WHERE id=?",
      [order.id]
    );
    await conn.commit();
    await writeLog(db, req.user, "CONFIRM", "import_order", order.id,
      `Xác nhận nhập kho phiếu ${order.ref_no} (${items.length} dòng)`);
    return R.ok(res, {}, "Xác nhận nhập kho thành công");
  } catch (err) {
    await conn.rollback();
    return R.serverError(res, err);
  } finally {
    conn.release();
  }
};

module.exports = { getAll, getOne, create, confirm, parseExcel };
