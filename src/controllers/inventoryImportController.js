const { writeLog } = require("../utils/auditLog");

"use strict";
const db = require("../config/db");
const R = require("../utils/response");
const XLSX = require("xlsx");
const { assertWarehouse } = require("../utils/warehouseGuard");
const calcStatus = (qty, min = 5) => qty === 0 ? "zero" : qty <= min ? "low" : qty <= min * 2 ? "warning" : "ok";

const importReplace = async (req, res) => {
  if (!req.file) return R.badRequest(res, "Chưa upload file Excel");
  const conn = await db.getConnection();
  try {
    const wb = XLSX.read(req.file.buffer, { type: "buffer" });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const raw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: "" });
    const dataRows = raw.slice(1).filter(r => String(r[0]).trim());
    if (!dataRows.length) return R.badRequest(res, "File không có dữ liệu hợp lệ");

    const rows = dataRows.map(r => ({
      barcode: String(r[0]).trim(),
      name: String(r[1] || "").trim(),
      quantity: Number(r[2]) || 0,
      location: String(r[3] || "").trim(),
      whCode: String(r[4] || "X1").trim(),
      cost_price: Number(r[5]) || 0,
    }));
    const whCodes = [...new Set(rows.map(r => r.whCode))];

    // Kiểm tra quyền kho
    if (req.user.warehouse_id) {
      const [[allowedWh]] = await conn.execute("SELECT code FROM warehouses WHERE id=?", [req.user.warehouse_id]);
      const forbidden = whCodes.filter(c => c !== allowedWh?.code);
      if (forbidden.length) { conn.release(); return R.forbidden(res, `Bạn chỉ được cập nhật kho "${allowedWh?.code}", không được thao tác: ${forbidden.join(", ")}`); }
    }

    await conn.beginTransaction();
    const whMap = {};
    for (const code of whCodes) {
      const [[wh]] = await conn.execute("SELECT id FROM warehouses WHERE code=?", [code]);
      if (wh) { whMap[code] = wh.id; }
      else { const [r] = await conn.execute("INSERT INTO warehouses(code,name,city)VALUES(?,?,'') ON DUPLICATE KEY UPDATE code=code", [code, `Kho ${code}`]); whMap[code] = r.insertId || wh?.id; }
    }

    for (const row of rows) {
      await conn.execute(
        `INSERT INTO products(barcode,name,unit,cost_price)
         VALUES(?,?,'Cái',?)
         ON DUPLICATE KEY UPDATE name=VALUES(name), cost_price=VALUES(cost_price)`,
        [row.barcode, row.name || "(Chưa có tên)", row.cost_price]
      );
    }

    for (const whId of Object.values(whMap)) {
      await conn.execute("DELETE FROM inventory WHERE warehouse_id=?", [whId]);
    }

    let insertedCount = 0;
    for (const row of rows) {
      const [[product]] = await conn.execute("SELECT id FROM products WHERE barcode=?", [row.barcode]);
      if (!product) continue;
      const whId = whMap[row.whCode];
      await conn.execute(`INSERT INTO inventory(product_id,warehouse_id,location_text,quantity,min_stock,status)VALUES(?,?,?,?,5,?)`, [product.id, whId, row.location, row.quantity, calcStatus(row.quantity, 5)]);
      insertedCount++;
    }

    await conn.commit();
    await writeLog(conn, req.user, "REPLACE", "inventory", null,
      `Cập nhật toàn bộ tồn kho: ${insertedCount} sản phẩm tại kho ${whCodes.join(", ")}`);
    return R.ok(res, { total_rows: rows.length, inserted: insertedCount, warehouses: whCodes }, `Đã thay thế tồn kho: ${insertedCount} sản phẩm`);
  } catch (err) { await conn.rollback(); return R.serverError(res, err); }
  finally { conn.release(); }
};

const previewReplace = async (req, res) => {
  try {
    if (!req.file) return R.badRequest(res, "Chưa upload file Excel");
    const wb = XLSX.read(req.file.buffer, { type: "buffer" });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const raw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: "" });
    const dataRows = raw.slice(1).filter(r => String(r[0]).trim());
    if (!dataRows.length) return R.badRequest(res, "File không có dữ liệu hợp lệ");
    const rows = dataRows.map(r => ({
      barcode: String(r[0]).trim(),
      name: String(r[1] || "").trim(),
      quantity: Number(r[2]) || 0,
      location: String(r[3] || "").trim(),
      warehouse: String(r[4] || "X1").trim(),
      cost_price: Number(r[5]) || 0,
    }));
    const warehouses = [...new Set(rows.map(r => r.warehouse))];
    const zeroQty = rows.filter(r => r.quantity === 0).length;
    const noLocation = rows.filter(r => !r.location).length;
    const totalQty = rows.reduce((s, r) => s + r.quantity, 0);
    return R.ok(res, { total_rows: rows.length, warehouses, zero_qty: zeroQty, no_location: noLocation, total_qty: totalQty, sample: rows.slice(0, 5) });
  } catch (err) { return R.serverError(res, err); }
};

module.exports = { importReplace, previewReplace };
