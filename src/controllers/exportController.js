const { writeLog } = require("../utils/auditLog");

"use strict";
const db = require("../config/db");
const R = require("../utils/response");
const XLSX = require("xlsx");
const { warehouseGuard, assertWarehouse } = require("../utils/warehouseGuard");
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
    const { whClause, whParams } = warehouseGuard(req.user, "eo.warehouse_id");
    const params = [...whParams];
    let where = `WHERE 1=1 ${whClause}`;
    if (status) {
      where += " AND eo.status=?";
      params.push(status);
    }
    const [[{ total }]] = await db.execute(
      `SELECT COUNT(*) AS total FROM export_orders eo ${where}`,
      params
    );
    const [rows] = await db.execute(
      `SELECT eo.id,eo.ref_no,eo.export_date,eo.status,eo.total_items,eo.bookstore,eo.created_by,w.name AS warehouse_name,w.code AS warehouse_code,eo.created_at,eo.confirmed_at FROM export_orders eo JOIN warehouses w ON w.id=eo.warehouse_id ${where} ORDER BY eo.export_date DESC,eo.id DESC LIMIT ? OFFSET ?`,
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
    const { whClause, whParams } = warehouseGuard(req.user, "eo.warehouse_id");
    const [[order]] = await db.execute(
      `SELECT eo.*,w.name AS warehouse_name,w.code AS warehouse_code FROM export_orders eo JOIN warehouses w ON w.id=eo.warehouse_id WHERE eo.id=? ${whClause}`,
      [req.params.id, ...whParams]
    );
    if (!order)
      return R.notFound(res, "Phiếu không tồn tại hoặc bạn không có quyền");
    const [items] = await db.execute(
      `SELECT ei.*,p.barcode,p.name AS product_name,p.unit,inv.quantity AS current_stock,inv.location_text AS location_code FROM export_items ei JOIN products p ON p.id=ei.product_id LEFT JOIN inventory inv ON inv.product_id=ei.product_id AND inv.warehouse_id=? WHERE ei.export_order_id=? ORDER BY ei.id`,
      [order.warehouse_id, req.params.id]
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
      `SELECT p.barcode,p.name,p.unit,p.cost_price,p.sell_price,inv.quantity,inv.min_stock,inv.status,inv.location_text,inv.warehouse_id,w.code AS warehouse_code FROM products p LEFT JOIN inventory inv ON inv.product_id=p.id LEFT JOIN warehouses w ON w.id=inv.warehouse_id WHERE p.barcode IN (${barcodes
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
    const firstBookstore = String(rows[0][6] || "").trim();
    const items = rows.map((r) => {
      const barcode = String(r[2]).trim();
      const matched = productMap[barcode];
      const qtyRequested = Number(r[4]) || 0;
      const qtyAvail = matched?.quantity || 0;
      return {
        ref_no: String(r[1] || "").trim() || firstRefNo,
        barcode,
        name: String(r[3] || matched?.name || "").trim(),
        quantity: qtyRequested,
        unit_price: Number(r[5]) || 0,
        bookstore: String(r[6] || "").trim() || firstBookstore,
        location_code: matched?.location_text || "",
        warehouse_id: matched?.warehouse_id || req.user.warehouse_id || null,
        qty_available: qtyAvail,
        qty_ok: qtyAvail >= qtyRequested,
        not_found: !matched,
        status: matched?.status || null,
        cost_price: matched?.cost_price || 0,
        sell_price: matched?.sell_price || 0,
        warehouse_code: matched?.warehouse_code || ""
      };
    });
    return R.ok(res, {
      ref_no: firstRefNo,
      export_date: firstDate,
      bookstore: firstBookstore,
      total_rows: items.length,
      warn_rows: items.filter((i) => !i.qty_ok || i.not_found).length,
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
    const {
      ref_no,
      export_date,
      warehouse_id,
      bookstore = "",
      note,
      items = [],
    } = req.body;
    if (!ref_no || !export_date || !warehouse_id)
      return R.badRequest(res, "Thiếu ref_no, export_date hoặc warehouse_id");
    if (!items.length)
      return R.badRequest(res, "Phiếu xuất phải có ít nhất 1 dòng");
    if (!assertWarehouse(warehouse_id, req.user))
      return R.forbidden(res, "Bạn chỉ được xuất hàng từ kho được phân công");
    const [hResult] = await conn.execute(
      `INSERT INTO export_orders(ref_no,export_date,warehouse_id,bookstore,total_items,note,status,created_by)VALUES(?,?,?,?,?,?,'packing',?)`,
      [ref_no, export_date, warehouse_id, bookstore, items.length, note || null, String(req.user.id)]
    );
    const orderId = hResult.insertId;
    for (const item of items) {
      const { barcode, quantity, unit_price = 0, ref_no: itemRefNo = "", bookstore: itemBookstore = "" } = item;
      const [[product]] = await conn.execute("SELECT id FROM products WHERE barcode=?", [barcode]);
      if (!product) continue;
      const [[inv]] = await conn.execute(
        "SELECT id,location_text FROM inventory WHERE product_id=? AND warehouse_id=?",
        [product.id, warehouse_id]
      );
      // quantity_requested lưu cố định số gốc từ Excel; quantity sẽ bị ghi đè
      // thành số thực tế khi soạn hàng xong (dùng để trừ tồn lúc xác nhận)
      await conn.execute(
        `INSERT INTO export_items(export_order_id,ref_no,bookstore,product_id,location_text,quantity,quantity_requested,unit_price)VALUES(?,?,?,?,?,?,?,?)`,
        [orderId, itemRefNo, itemBookstore, product.id, inv?.location_text || "", quantity, quantity, unit_price]
      );
    }
    await conn.commit();
    return R.created(res, { order_id: orderId, ref_no });

  } catch (err) {
    await conn.rollback();
    if (err.code === "ER_DUP_ENTRY")
      return R.badRequest(res, `Số phiếu "${req.body.ref_no}" đã tồn tại`);
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
      "SELECT * FROM export_orders WHERE id=? AND status='packing'",
      [req.params.id]
    );
    if (!order)
      return R.badRequest(res, "Phiếu không tồn tại, đã xác nhận, hoặc chưa ở bước soạn hàng");
    if (!assertWarehouse(order.warehouse_id, req.user))
      return R.forbidden(res, "Bạn không có quyền xác nhận phiếu của kho khác");
    const [items] = await conn.execute(
      "SELECT * FROM export_items WHERE export_order_id=?",
      [order.id]
    );
    let skipped = 0;
    for (const item of items) {
      const [[inv]] = await conn.execute(
        "SELECT id,quantity,min_stock FROM inventory WHERE product_id=? AND warehouse_id=?",
        [item.product_id, order.warehouse_id]
      );
      if (!inv || inv.quantity < item.quantity) {
        skipped++;
        continue;
      }
      const newQty = inv.quantity - item.quantity;
      await conn.execute(
        `UPDATE inventory SET quantity=?,status=?,zero_since=CASE WHEN ?=0 AND zero_since IS NULL THEN NOW() ELSE zero_since END,last_export=NOW() WHERE id=?`,
        [newQty, calcStatus(newQty, inv.min_stock), newQty, inv.id]
      );
    }
    if (skipped === items.length) {
      await conn.rollback();
      return R.badRequest(res, "Không có dòng nào đủ tồn kho");
    }
    await conn.execute(
      "UPDATE export_orders SET status='confirmed',confirmed_at=NOW() WHERE id=?",
      [order.id]
    );
    await conn.execute(
      `UPDATE inventory SET location_text='',status='zero' WHERE quantity=0 AND zero_since IS NOT NULL AND TIMESTAMPDIFF(DAY,zero_since,NOW())>=3`
    );
    await conn.commit();
    await writeLog(db, req.user, "CONFIRM", "export_order", order.id,
      `Xác nhận xuất kho phiếu ${order.ref_no} (${items.length - skipped} dòng thành công)`);
    return R.ok(res, { skipped_rows: skipped }, "Xuất kho thành công");
  } catch (err) {
    await conn.rollback();
    return R.serverError(res, err);
  } finally {
    conn.release();
  }
};

// Cấp 1 accordion: phiếu đang soạn hàng
const getPackingBatches = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user, "eo.warehouse_id");
    const [rows] = await db.execute(
      `SELECT eo.id, eo.export_date, eo.created_at,
              w.code AS warehouse_code, w.name AS warehouse_name,
              COUNT(DISTINCT ei.ref_no) AS ticket_count,
              COUNT(DISTINCT ei.product_id) AS sku_count,
              COALESCE(SUM(ei.quantity * ei.unit_price),0) AS total_value
       FROM export_orders eo
       JOIN warehouses w ON w.id=eo.warehouse_id
       LEFT JOIN export_items ei ON ei.export_order_id=eo.id
       WHERE eo.status='packing' ${whClause}
       GROUP BY eo.id
       ORDER BY eo.created_at DESC`,
      whParams
    );
    return R.ok(res, rows);
  } catch (err) { return R.serverError(res, err); }
};

// Cấp 2: gom export_items theo ref_no trong CÙNG 1 phiếu soạn — mỗi ref_no là 1 phiếu xuất con
const getBatchTickets = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user, "eo.warehouse_id");
    const [[order]] = await db.execute(
      `SELECT eo.id FROM export_orders eo WHERE eo.id=? AND eo.status='packing' ${whClause}`,
      [req.params.id, ...whParams]
    );
    if (!order) return R.notFound(res, "Không tìm thấy phiếu soạn hoặc bạn không có quyền");

    const [rows] = await db.execute(
      `SELECT ei.ref_no, MIN(ei.bookstore) AS bookstore,
              COUNT(DISTINCT ei.product_id) AS sku_count,
              COALESCE(SUM(ei.quantity * ei.unit_price),0) AS total_value
       FROM export_items ei
       WHERE ei.export_order_id=?
       GROUP BY ei.ref_no
       ORDER BY ei.ref_no`,
      [req.params.id]
    );
    return R.ok(res, rows);
  } catch (err) { return R.serverError(res, err); }
};

// Cấp 3: chi tiết từng dòng sản phẩm — CHỈ của đúng 1 phiếu xuất con (ref_no) vừa bấm ở Cấp 2
const getTicketItems = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user, "eo.warehouse_id");
    const [[order]] = await db.execute(
      `SELECT eo.id, eo.warehouse_id FROM export_orders eo WHERE eo.id=? AND eo.status='packing' ${whClause}`,
      [req.params.id, ...whParams]
    );
    if (!order) return R.notFound(res, "Không tìm thấy phiếu soạn hoặc bạn không có quyền");

    const [items] = await db.execute(
      `SELECT ei.*, p.barcode, p.name AS product_name, inv.quantity AS current_stock
       FROM export_items ei
       JOIN products p ON p.id=ei.product_id
       LEFT JOIN inventory inv ON inv.product_id=ei.product_id AND inv.warehouse_id=?
       WHERE ei.export_order_id=? AND ei.ref_no=?
       ORDER BY ei.id`,
      [order.warehouse_id, order.id, req.params.refNo]
    );
    return R.ok(res, items);
  } catch (err) { return R.serverError(res, err); }
};
// Sửa số lượng thực tế 1 dòng — chỉ cho phép khi phiếu còn đang soạn hàng
const updateActualQuantity = async (req, res) => {
  try {
    const { quantity } = req.body;
    if (quantity === undefined || quantity < 0) return R.badRequest(res, "Số lượng không hợp lệ");
    const [[item]] = await db.execute(
      `SELECT ei.id,eo.warehouse_id,eo.status FROM export_items ei
       JOIN export_orders eo ON eo.id=ei.export_order_id WHERE ei.id=?`,
      [req.params.itemId]
    );
    if (!item) return R.notFound(res, "Không tìm thấy dòng hàng");
    if (item.status !== "packing") return R.badRequest(res, "Chỉ sửa được số lượng khi phiếu đang ở trạng thái soạn hàng");
    if (!assertWarehouse(item.warehouse_id, req.user)) return R.forbidden(res, "Bạn không có quyền sửa phiếu của kho khác");
    await db.execute("UPDATE export_items SET quantity=? WHERE id=?", [quantity, req.params.itemId]);
    return R.ok(res, {});
  } catch (err) { return R.serverError(res, err); }
};

// Hủy phiếu đang soạn — an toàn xóa vì CHƯA trừ tồn kho ở bước này
const cancelBatch = async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[order]] = await conn.execute(
      "SELECT * FROM export_orders WHERE id=? AND status='packing'",
      [req.params.id]
    );
    if (!order) return R.badRequest(res, "Phiếu không tồn tại hoặc không ở trạng thái đang soạn hàng");
    if (!assertWarehouse(order.warehouse_id, req.user))
      return R.forbidden(res, "Bạn không có quyền hủy phiếu của kho khác");
    await conn.execute("DELETE FROM export_items WHERE export_order_id=?", [order.id]);
    await conn.execute("DELETE FROM export_orders WHERE id=?", [order.id]);
    await conn.commit();
    await writeLog(db, req.user, "DELETE", "export_order", order.id, `Hủy phiếu đang soạn hàng ${order.ref_no}`);
    return R.ok(res, {}, "Đã hủy phiếu");
  } catch (err) {
    await conn.rollback();
    return R.serverError(res, err);
  } finally { conn.release(); }
};

module.exports = { getAll, getOne, create, confirm, parseExcel, getPackingBatches, getBatchTickets, getTicketItems, updateActualQuantity, cancelBatch };