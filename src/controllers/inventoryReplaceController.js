const { writeLog } = require("../utils/auditLog");

("use strict");
const db = require("../config/db");
const R = require("../utils/response");
const XLSX = require("xlsx");
const { assertWarehouse } = require("../middleware/warehouseGuard");
const calcStatus = (qty, min = 5) =>
  qty === 0 ? "zero" : qty <= min ? "low" : qty <= min * 2 ? "warning" : "ok";

const importReplace = async (req, res) => {
  if (!req.file) return R.badRequest(res, "Chưa upload file Excel");
  const conn = await db.getConnection();
  try {
    const wb = XLSX.read(req.file.buffer, { type: "buffer" });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const raw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: "" });
    const dataRows = raw.slice(1).filter((r) => String(r[0]).trim());
    if (!dataRows.length)
      return R.badRequest(res, "File không có dữ liệu hợp lệ");

    const rawRows = dataRows.map(r => ({
      barcode: String(r[0]).trim(),
      name: String(r[1] || "").trim(),
      quantity: Number(r[2]) || 0,
      location: String(r[3] || "").trim(),
      whCode: String(r[4] || "X1").trim(),
      cost_price: Number(r[5]) || 0,
    }));

    // Loại bỏ trùng lặp theo cặp (barcode, kho) — nếu file Excel chứa cùng 1 barcode
    // nhiều lần cho cùng 1 kho, GIỮ DÒNG CUỐI CÙNG (coi như bản cập nhật mới nhất
    // ghi đè bản cũ), tránh lỗi ER_DUP_ENTRY khi insert hàng loạt vào bảng inventory
    // (khác với products dùng ON DUPLICATE KEY UPDATE nên không bị lỗi này).
    const dedupMap = new Map();
    for (const row of rawRows) {
      dedupMap.set(`${row.barcode}__${row.whCode}`, row);
    }
    const rows = [...dedupMap.values()];
    const skippedDuplicates = rawRows.length - rows.length;

    const whCodes = [...new Set(rows.map(r => r.whCode))];

    // Kiểm tra quyền kho
    if (req.user.warehouse_id) {
      const [[allowedWh]] = await conn.execute(
        "SELECT code FROM warehouses WHERE id=?",
        [req.user.warehouse_id]
      );
      const forbidden = whCodes.filter((c) => c !== allowedWh?.code);
      if (forbidden.length) {
        conn.release();
        return R.forbidden(
          res,
          `Bạn chỉ được cập nhật kho "${allowedWh?.code
          }", không được thao tác: ${forbidden.join(", ")}`
        );
      }
    }

    await conn.beginTransaction();
    const whMap = {};
    for (const code of whCodes) {
      const [[wh]] = await conn.execute(
        "SELECT id FROM warehouses WHERE code=?",
        [code]
      );
      if (wh) {
        whMap[code] = wh.id;
      } else {
        const [r] = await conn.execute(
          "INSERT INTO warehouses(code,name,city)VALUES(?,?,'') ON DUPLICATE KEY UPDATE code=code",
          [code, `Kho ${code}`]
        );
        whMap[code] = r.insertId || wh?.id;
      }
    }

    const CHUNK_SIZE = 500;

    // Bước 1: bulk upsert products theo lô 500 dòng/lần
    for (let i = 0; i < rows.length; i += CHUNK_SIZE) {
      const chunk = rows.slice(i, i + CHUNK_SIZE);
      const placeholders = chunk.map(() => "(?,?,'Cái',?,1)").join(",");
      const params = chunk.flatMap((r) => [
        r.barcode,
        r.name || "(Chưa có tên)",
        r.cost_price,
      ]);
      await conn.execute(
        `INSERT INTO products(barcode,name,unit,cost_price,is_active)
     VALUES ${placeholders}
     ON DUPLICATE KEY UPDATE name=VALUES(name), cost_price=VALUES(cost_price), is_active=1`,
        params
      );
    }

    for (const whId of Object.values(whMap)) {
      await conn.execute("DELETE FROM inventory WHERE warehouse_id=?", [whId]);
    }

    // Bước 2: lấy toàn bộ product_id cần thiết trong 1 câu, dựng map barcode → id
    const allBarcodes = rows.map((r) => r.barcode);
    const [productRows] = await conn.query(
      `SELECT id, barcode FROM products WHERE barcode IN (?)`,
      [allBarcodes]
    );
    const productIdMap = {};
    productRows.forEach((p) => {
      productIdMap[p.barcode] = p.id;
    });

    // Bước 3: bulk insert inventory theo lô 500 dòng/lần
    let insertedCount = 0;
    const validRows = rows.filter((r) => productIdMap[r.barcode]);
    for (let i = 0; i < validRows.length; i += CHUNK_SIZE) {
      const chunk = validRows.slice(i, i + CHUNK_SIZE);
      const placeholders = chunk.map(() => "(?,?,?,?,5,?)").join(",");
      const params = chunk.flatMap((r) => [
        productIdMap[r.barcode],
        whMap[r.whCode],
        r.location,
        r.quantity,
        calcStatus(r.quantity, 5),
      ]);
      await conn.execute(
        `INSERT INTO inventory(product_id,warehouse_id,location_text,quantity,min_stock,status) VALUES ${placeholders}`,
        params
      );
      insertedCount += chunk.length;
    }

    await conn.commit();
    await writeLog(conn, req.user, "REPLACE", "inventory", null,
      `Cập nhật toàn bộ tồn kho: ${insertedCount} sản phẩm tại kho ${whCodes.join(", ")}${skippedDuplicates > 0 ? ` (loại bỏ ${skippedDuplicates} dòng trùng barcode)` : ""}`);
    return R.ok(res, {
      total_rows: rows.length,
      inserted: insertedCount,
      warehouses: whCodes,
      skipped_duplicates: skippedDuplicates,
    }, `Đã thay thế tồn kho: ${insertedCount} sản phẩm${skippedDuplicates > 0 ? ` (đã tự động loại bỏ ${skippedDuplicates} dòng trùng barcode trong file)` : ""}`);
  } catch (err) {
    await conn.rollback();
    return R.serverError(res, err);
  } finally {
    conn.release();
  }
};

const previewReplace = async (req, res) => {
  try {
    if (!req.file) return R.badRequest(res, "Chưa upload file Excel");
    const wb = XLSX.read(req.file.buffer, { type: "buffer" });
    const ws = wb.Sheets[wb.SheetNames[0]];
    const raw = XLSX.utils.sheet_to_json(ws, { header: 1, defval: "" });
    const dataRows = raw.slice(1).filter((r) => String(r[0]).trim());
    if (!dataRows.length)
      return R.badRequest(res, "File không có dữ liệu hợp lệ");

    const rawRows = dataRows.map(r => ({
      barcode: String(r[0]).trim(),
      name: String(r[1] || "").trim(),
      quantity: Number(r[2]) || 0,
      location: String(r[3] || "").trim(),
      warehouse: String(r[4] || "X1").trim(),
      cost_price: Number(r[5]) || 0,
    }));

    const seenKeys = new Set();
    let duplicateCount = 0;
    for (const r of rawRows) {
      const key = `${r.barcode}__${r.warehouse}`;
      if (seenKeys.has(key)) duplicateCount++;
      seenKeys.add(key);
    }
    const rows = rawRows; // preview vẫn hiển thị đúng số dòng thật có trong file, chỉ cảnh báo thêm

    const warehouses = [...new Set(rows.map(r => r.warehouse))];
    const zeroQty = rows.filter(r => r.quantity === 0).length;
    const noLocation = rows.filter(r => !r.location).length;
    const totalQty = rows.reduce((s, r) => s + r.quantity, 0);
    const totalValue = rows.reduce((s, r) => s + r.quantity * r.cost_price, 0);
    return R.ok(res, {
      total_rows: rows.length,
      warehouses, zero_qty: zeroQty, no_location: noLocation, total_qty: totalQty, total_value: totalValue,
      duplicate_count: duplicateCount,
      sample: rows.slice(0, 5),
    });
  } catch (err) {
    return R.serverError(res, err);
  }
};

module.exports = { importReplace, previewReplace };
