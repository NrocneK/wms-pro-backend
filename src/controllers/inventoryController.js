// src/controllers/inventoryController.js
"use strict";
const db = require("../config/db");
const R = require("../utils/response");
const { warehouseGuard, assertWarehouse } = require("../utils/warehouseGuard");
const { writeLog } = require("../utils/auditLog");

const getDashboard = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user, "inv.warehouse_id");
    const [[kpi]] = await db.execute(`
      SELECT COUNT(DISTINCT p.id) AS total_skus,
             COUNT(DISTINCT inv.warehouse_id) AS total_warehouses,
             COALESCE(SUM(inv.quantity * p.cost_price),0) AS total_stock_value,
             SUM(CASE WHEN inv.status='low'     THEN 1 ELSE 0 END) AS count_low,
             SUM(CASE WHEN inv.status='zero'    THEN 1 ELSE 0 END) AS count_zero,
             SUM(CASE WHEN inv.status='warning' THEN 1 ELSE 0 END) AS count_warning
      FROM inventory inv
      JOIN products p ON p.id=inv.product_id AND p.is_active=1
      WHERE 1=1 ${whClause}`, whParams);

    const whIO = whClause.replace("inv.warehouse_id", "warehouse_id");

    // ── "Hôm nay" tính bằng giờ máy chủ Node.js, KHÔNG dùng CURDATE() của MySQL ──
    // Lý do: CURDATE() phụ thuộc timezone riêng của MySQL server (XAMPP mặc định
    // dễ lệch so với giờ hệ điều hành) — đã gây bug thực tế: header hiển thị 1/7
    // nhưng backend tính ra 2/7. Dùng chung 1 nguồn "hôm nay" từ Node cho cả hệ
    // thống để tránh 2 nơi tính khác nhau.
    const now = new Date();
    const todayStr = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;

    const [[todayStats]] = await db.execute(`
      SELECT
        (SELECT COUNT(*) FROM import_orders WHERE status='confirmed' AND import_date=? ${whIO}) AS today_imports,
        (SELECT COUNT(*) FROM export_orders WHERE status='confirmed' AND export_date=? ${whIO}) AS today_exports
    `, [todayStr, ...whParams, todayStr, ...whParams]);

    // ── Cửa sổ 7 ngày trượt được ─────────────────────────────
    // week_offset=0 → 7 ngày gần nhất, week_offset=1 → 7 ngày liền trước, v.v.
    // Tính range_start/range_end trực tiếp trong JS (không qua MySQL) — cùng lý
    // do tránh lệch timezone như trên, đồng thời bớt 1 lượt round-trip DB thừa.
    const weekOffset = Math.max(0, parseInt(req.query.week_offset) || 0);
    const rangeEndDate = new Date(now);
    rangeEndDate.setDate(rangeEndDate.getDate() - weekOffset * 7);

    const range_end = `${rangeEndDate.getFullYear()}-${String(rangeEndDate.getMonth() + 1).padStart(2, "0")}-${String(rangeEndDate.getDate()).padStart(2, "0")}`;
    const rangeStartDate = new Date(rangeEndDate);
    rangeStartDate.setDate(rangeStartDate.getDate() - 6);
    const range_start = `${rangeStartDate.getFullYear()}-${String(rangeStartDate.getMonth() + 1).padStart(2, "0")}-${String(rangeStartDate.getDate()).padStart(2, "0")}`;

    // Biểu đồ theo GIÁ TRỊ (quantity × unit_price) thay vì đếm số phiếu
    const [activity] = await db.execute(`
      SELECT DATE_FORMAT(o.activity_date,'%Y-%m-%d') AS date,
             COALESCE(SUM(CASE WHEN o.type='import' THEN i.line_value ELSE 0 END),0) AS import_value,
             COALESCE(SUM(CASE WHEN o.type='export' THEN i.line_value ELSE 0 END),0) AS export_value,
             COUNT(DISTINCT CASE WHEN o.type='import' THEN o.id END) AS import_count,
             COUNT(DISTINCT CASE WHEN o.type='export' THEN o.id END) AS export_count
      FROM (
        SELECT id, import_date AS activity_date, warehouse_id, 'import' AS type FROM import_orders
          WHERE status='confirmed' AND import_date BETWEEN ? AND ? ${whIO}
        UNION ALL
        SELECT id, export_date AS activity_date, warehouse_id, 'export' AS type FROM export_orders
          WHERE status='confirmed' AND export_date BETWEEN ? AND ? ${whIO}
      ) o
      LEFT JOIN (
        SELECT import_order_id AS order_id, 'import' AS type, quantity*unit_price AS line_value FROM import_items
        UNION ALL
        SELECT export_order_id AS order_id, 'export' AS type, quantity*unit_price AS line_value FROM export_items
      ) i ON i.order_id=o.id AND i.type=o.type
      GROUP BY DATE_FORMAT(o.activity_date,'%Y-%m-%d')
      ORDER BY date ASC`,
      [range_start, range_end, ...whParams, range_start, range_end, ...whParams]
    );

    // Còn dữ liệu cũ hơn cửa sổ đang xem không → để frontend bật/tắt nút "‹ Tuần trước"
    const [[{ has_older }]] = await db.execute(`
      SELECT EXISTS(
        SELECT 1 FROM (
          SELECT import_date AS activity_date FROM import_orders WHERE status='confirmed' ${whIO}
          UNION ALL
          SELECT export_date AS activity_date FROM export_orders WHERE status='confirmed' ${whIO}
        ) t WHERE t.activity_date < ?
      ) AS has_older`, [...whParams, ...whParams, range_start]);

    const { whClause: wClause, whParams: wParams } = warehouseGuard(req.user, "w.id");
    const [byWarehouse] = await db.execute(`
      SELECT w.code,w.name,
             COUNT(DISTINCT p.id) AS sku_count,
             COALESCE(SUM(inv.quantity*p.cost_price),0) AS stock_value,
             SUM(CASE WHEN inv.status='low'  THEN 1 ELSE 0 END) AS low_count,
             SUM(CASE WHEN inv.status='zero' THEN 1 ELSE 0 END) AS zero_count
      FROM warehouses w
      LEFT JOIN inventory inv ON inv.warehouse_id=w.id
      LEFT JOIN products  p   ON p.id=inv.product_id AND p.is_active=1
      WHERE w.is_active=1 ${wClause}
      GROUP BY w.id ORDER BY w.code`, wParams);

    return R.ok(res, {
      kpi,
      today: todayStats,
      activity,
      by_warehouse: byWarehouse,
      week_offset: weekOffset,
      range_start,
      range_end,
      has_older,
    });
  } catch (err) { return R.serverError(res, err); }
};

const getInventory = async (req, res) => {
  try {
    const { search = "", warehouse_id = "", warehouse_code = "", status = "", page = 1, limit = 50 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const params = [];
    let where = "WHERE 1=1";
    if (search) { where += " AND (barcode LIKE ? OR product_name LIKE ?)"; params.push(`%${search}%`, `%${search}%`); }
    const { whId, whClause, whParams } = warehouseGuard(req.user);
    if (whId) { where += whClause; params.push(...whParams); }
    else if (warehouse_code) { where += " AND warehouse_code=?"; params.push(warehouse_code); }
    else if (warehouse_id) { where += " AND warehouse_id=?"; params.push(warehouse_id); }
    if (status) { where += " AND status=?"; params.push(status); }
    const [[{ total }]] = await db.execute(`SELECT COUNT(*) AS total FROM v_inventory_full ${where}`, params);
    const limitNum = parseInt(limit) || 50;
    const offsetNum = offset;
    const [rows] = await db.execute(`SELECT * FROM v_inventory_full ${where} ORDER BY product_name LIMIT ${limitNum} OFFSET ${offsetNum}`, params);
    return R.ok(res, { items: rows, pagination: { total, page: parseInt(page), limit: parseInt(limit), totalPages: Math.ceil(total / limit) } });
  } catch (err) { return R.serverError(res, err); }
};

const getAlerts = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user);
    const [rows] = await db.execute(`
      SELECT * FROM v_inventory_full
      WHERE status IN ('low','zero','warning') ${whClause}
      ORDER BY CASE status WHEN 'zero' THEN 1 WHEN 'low' THEN 2 ELSE 3 END, quantity ASC
      LIMIT 200`, whParams);
    return R.ok(res, rows);
  } catch (err) { return R.serverError(res, err); }
};

const getReportByCategory = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user, "inv.warehouse_id");
    const [rows] = await db.execute(`
      SELECT w.code AS category,w.name,
             COUNT(DISTINCT p.id) AS sku_count,
             SUM(inv.quantity) AS total_qty,
             SUM(inv.quantity*p.cost_price) AS stock_value
      FROM inventory inv
      JOIN products p ON p.id=inv.product_id AND p.is_active=1
      JOIN warehouses w ON w.id=inv.warehouse_id
      WHERE 1=1 ${whClause}
      GROUP BY w.id ORDER BY stock_value DESC`, whParams);
    return R.ok(res, rows);
  } catch (err) { return R.serverError(res, err); }
};

const getReportUserActivity = async (req, res) => {
  try {
    const { whClause: ioC, whParams: ioP } = warehouseGuard(req.user, "io.warehouse_id");
    const { whClause: eoC, whParams: eoP } = warehouseGuard(req.user, "eo.warehouse_id");
    const [summary] = await db.execute(`
      SELECT u.id AS user_id,u.username,u.full_name,u.role,u.is_active,
             COUNT(DISTINCT io.id) AS import_orders,
             COALESCE(SUM(io.total_items),0) AS import_items,
             MAX(io.confirmed_at) AS last_import,
             COUNT(DISTINCT eo.id) AS export_orders,
             COALESCE(SUM(eo.total_items),0) AS export_items,
             MAX(eo.confirmed_at) AS last_export,
             GREATEST(COALESCE(MAX(io.confirmed_at),'1970-01-01'),COALESCE(MAX(eo.confirmed_at),'1970-01-01')) AS last_activity
      FROM users u
      LEFT JOIN import_orders io ON io.created_by=CAST(u.id AS CHAR) AND io.status='confirmed' ${ioC}
      LEFT JOIN export_orders eo ON eo.created_by=CAST(u.id AS CHAR) AND eo.status='confirmed' ${eoC}
      WHERE u.is_active=1
      GROUP BY u.id ORDER BY last_activity DESC`, [...ioP, ...eoP]);

    const [recent] = await db.execute(`
      SELECT 'import' AS type,io.ref_no,io.import_date AS txn_date,io.total_items,
             io.bookstore AS partner,io.confirmed_at,
             u.full_name AS user_name,u.username,u.role AS user_role,w.name AS warehouse_name
      FROM import_orders io
      JOIN users u ON CAST(u.id AS CHAR)=io.created_by
      JOIN warehouses w ON w.id=io.warehouse_id
      WHERE io.status='confirmed' ${ioC}
      UNION ALL
      SELECT 'export' AS type,eo.ref_no,eo.export_date AS txn_date,eo.total_items,
             eo.bookstore AS partner,eo.confirmed_at,
             u.full_name AS user_name,u.username,u.role AS user_role,w.name AS warehouse_name
      FROM export_orders eo
      JOIN users u ON CAST(u.id AS CHAR)=eo.created_by
      JOIN warehouses w ON w.id=eo.warehouse_id
      WHERE eo.status='confirmed' ${eoC}
      ORDER BY confirmed_at DESC LIMIT 50`, [...ioP, ...eoP]);

    return R.ok(res, { summary, recent });
  } catch (err) { return R.serverError(res, err); }
};

const calcStatus = (qty, min = 5) =>
  qty === 0 ? "zero" : qty <= min ? "low" : qty <= min * 2 ? "warning" : "ok";

const createInventoryItem = async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const { barcode, name, unit, cost_price, sell_price, warehouse_code, location_text, quantity, min_stock } = req.body;
    if (!barcode || !name || !warehouse_code) return R.badRequest(res, "Thiếu barcode, tên hoặc mã kho");

    const [[wh]] = await conn.execute("SELECT id FROM warehouses WHERE code=? AND is_active=1", [warehouse_code]);
    if (!wh) return R.badRequest(res, `Kho "${warehouse_code}" không tồn tại`);
    if (!assertWarehouse(wh.id, req.user)) return R.forbidden(res, "Bạn không có quyền thêm vào kho này");

    let [[product]] = await conn.execute("SELECT id FROM products WHERE barcode=?", [barcode]);
    if (!product) {
      const [np] = await conn.execute(
        "INSERT INTO products(barcode,name,unit,cost_price,sell_price)VALUES(?,?,?,?,?)",
        [barcode, name, unit || "Cái", cost_price || 0, sell_price || 0]
      );
      product = { id: np.insertId };
    }

    const [[existing]] = await conn.execute(
      "SELECT id FROM inventory WHERE product_id=? AND warehouse_id=?", [product.id, wh.id]
    );
    if (existing) return R.badRequest(res, "Sản phẩm đã tồn tại trong kho này");

    const qty = Number(quantity) || 0;
    const minS = Number(min_stock) || 5;
    await conn.execute(
      "INSERT INTO inventory(product_id,warehouse_id,location_text,quantity,min_stock,status)VALUES(?,?,?,?,?,?)",
      [product.id, wh.id, location_text || "", qty, minS, calcStatus(qty, minS)]
    );
    await conn.commit();
    await writeLog(db, req.user, "CREATE", "inventory", product.id,
      `Thêm mới sản phẩm "${name}" (${barcode}) vào kho ${warehouse_code}, SL: ${qty}`);
    return R.created(res, {});
  } catch (err) {
    await conn.rollback();
    return R.serverError(res, err);
  } finally { conn.release(); }
};

const updateInventoryItem = async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [[inv]] = await conn.execute("SELECT product_id,warehouse_id FROM inventory WHERE id=?", [req.params.id]);
    if (!inv) return R.notFound(res, "Không tìm thấy sản phẩm");
    if (!assertWarehouse(inv.warehouse_id, req.user)) return R.forbidden(res, "Bạn không có quyền sửa kho này");

    const { name, unit, cost_price, sell_price, min_stock, location_text } = req.body;
    await conn.execute(
      "UPDATE products SET name=?,unit=?,cost_price=?,sell_price=? WHERE id=?",
      [name, unit, Number(cost_price) || 0, Number(sell_price) || 0, inv.product_id]
    );
    await conn.execute(
      "UPDATE inventory SET min_stock=?,location_text=? WHERE id=?",
      [Number(min_stock) || 5, location_text || "", req.params.id]
    );
    await conn.commit();
    await writeLog(db, req.user, "UPDATE", "inventory", req.params.id,
      `Cập nhật sản phẩm "${name}" (id tồn kho=${req.params.id}): giá vốn=${cost_price}, giá bán=${sell_price}, tồn tối thiểu=${min_stock}, vị trí=${location_text || "—"}`);
    return R.ok(res, {});

  } catch (err) {
    await conn.rollback();
    return R.serverError(res, err);
  } finally { conn.release(); }
};

const removeInventoryItem = async (req, res) => {
  try {
    const [[inv]] = await db.execute(
      `SELECT inv.warehouse_id, p.name AS product_name, p.barcode
       FROM inventory inv JOIN products p ON p.id=inv.product_id
       WHERE inv.id=?`, [req.params.id]
    );
    if (!inv) return R.notFound(res, "Không tìm thấy sản phẩm");
    if (!assertWarehouse(inv.warehouse_id, req.user)) return R.forbidden(res, "Bạn không có quyền xóa ở kho này");
    await db.execute("DELETE FROM inventory WHERE id=?", [req.params.id]);
    await writeLog(db, req.user, "DELETE", "inventory", req.params.id,
      `Xóa sản phẩm "${inv.product_name}" (${inv.barcode}) khỏi kho`);
    return R.ok(res, {});
  } catch (err) { return R.serverError(res, err); }
};

const removeBatchInventory = async (req, res) => {
  try {
    const { ids } = req.body;
    if (!Array.isArray(ids) || ids.length === 0)
      return R.badRequest(res, "Danh sách id trống hoặc không hợp lệ");

    // Kiểm tra quyền từng kho trước khi xóa
    const [invRows] = await db.execute(
      `SELECT inv.id, inv.warehouse_id, p.name AS product_name, p.barcode
       FROM inventory inv JOIN products p ON p.id=inv.product_id
       WHERE inv.id IN (${ids.map(() => "?").join(",")})`,
      ids
    );
    for (const inv of invRows) {
      if (!assertWarehouse(inv.warehouse_id, req.user))
        return R.forbidden(res, "Bạn không có quyền xóa một hoặc nhiều sản phẩm trong danh sách");
    }

    const [result] = await db.execute(
      `DELETE FROM inventory WHERE id IN (${ids.map(() => "?").join(",")})`,
      ids
    );
    await writeLog(db, req.user, "DELETE", "inventory", null,
      `Xóa hàng loạt ${result.affectedRows} sản phẩm: ${invRows.map(i => i.barcode).join(", ")}`);
    return R.ok(res, { deleted: result.affectedRows });
  } catch (err) { return R.serverError(res, err); }
};

// ── Lịch sử theo ngày (accordion trên Dashboard) ─────────────
// Cấp 1: liệt kê các ngày có phát sinh phiếu, mới nhất trước, phân trang theo NGÀY
const getActivityHistoryDates = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user, "warehouse_id");
    const limit = Math.min(parseInt(req.query.limit) || 15, 50); // chặn giá trị bất thường
    const offset = parseInt(req.query.offset) || 0;

    const [rows] = await db.execute(`
      SELECT DATE_FORMAT(o.activity_date,'%Y-%m-%d') AS date,
             COUNT(DISTINCT CASE WHEN o.type='import' THEN o.id END) AS import_count,
             COUNT(DISTINCT CASE WHEN o.type='export' THEN o.id END) AS export_count,
             COALESCE(SUM(CASE WHEN o.type='import' THEN i.line_value ELSE 0 END),0) AS import_value,
             COALESCE(SUM(CASE WHEN o.type='export' THEN i.line_value ELSE 0 END),0) AS export_value
      FROM (
        SELECT id, import_date AS activity_date, 'import' AS type FROM import_orders WHERE status='confirmed' ${whClause}
        UNION ALL
        SELECT id, export_date AS activity_date, 'export' AS type FROM export_orders WHERE status='confirmed' ${whClause}
      ) o
      LEFT JOIN (
        SELECT import_order_id AS order_id, 'import' AS type, quantity*unit_price AS line_value FROM import_items
        UNION ALL
        SELECT export_order_id AS order_id, 'export' AS type, quantity*unit_price AS line_value FROM export_items
      ) i ON i.order_id=o.id AND i.type=o.type
      GROUP BY DATE_FORMAT(o.activity_date,'%Y-%m-%d')
      ORDER BY date DESC
     LIMIT ${limit} OFFSET ${offset}`,
      [...whParams, ...whParams]
    );

    rows.forEach(r => { r.total_count = r.import_count + r.export_count; });

    const [[{ total_dates }]] = await db.execute(`
      SELECT COUNT(DISTINCT DATE_FORMAT(t.activity_date,'%Y-%m-%d')) AS total_dates
      FROM (
        SELECT import_date AS activity_date FROM import_orders WHERE status='confirmed' ${whClause}
        UNION ALL
        SELECT export_date AS activity_date FROM export_orders WHERE status='confirmed' ${whClause}
      ) t`, [...whParams, ...whParams]);

    return R.ok(res, {
      dates: rows,
      total_dates,
      has_more: offset + rows.length < total_dates,
    });
  } catch (err) { return R.serverError(res, err); }
};

// Cấp 2: danh sách phiếu (cả nhập lẫn xuất) của MỘT ngày cụ thể — gọi khi user
// bấm mở rộng 1 ngày trong accordion (lazy load, không tải sẵn toàn bộ)
const getOrdersByDate = async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return R.badRequest(res, "Thiếu tham số date (định dạng YYYY-MM-DD)");

    const { whClause: ioC, whParams: ioP } = warehouseGuard(req.user, "io.warehouse_id");
    const { whClause: eoC, whParams: eoP } = warehouseGuard(req.user, "eo.warehouse_id");

    const [rows] = await db.execute(`
      SELECT io.id AS order_id,'import' AS type,io.ref_no,io.import_date AS txn_date,io.total_items,
             io.confirmed_at,w.code AS warehouse_code,u.full_name AS created_by_name,
             COALESCE((SELECT SUM(quantity*unit_price) FROM import_items WHERE import_order_id=io.id),0) AS total_value
      FROM import_orders io
      JOIN warehouses w ON w.id=io.warehouse_id
      LEFT JOIN users u ON u.id=CAST(io.created_by AS UNSIGNED)
      WHERE io.status='confirmed' AND io.import_date=? ${ioC}
      UNION ALL
      SELECT eo.id AS order_id,'export' AS type,eo.ref_no,eo.export_date AS txn_date,eo.total_items,
             eo.confirmed_at,w.code AS warehouse_code,u.full_name AS created_by_name,
             COALESCE((SELECT SUM(quantity*unit_price) FROM export_items WHERE export_order_id=eo.id),0) AS total_value
      FROM export_orders eo
      JOIN warehouses w ON w.id=eo.warehouse_id
      LEFT JOIN users u ON u.id=CAST(eo.created_by AS UNSIGNED)
      WHERE eo.status='confirmed' AND eo.export_date=? ${eoC}
      ORDER BY txn_date DESC`,
      [date, ...ioP, date, ...eoP]
    );

    return R.ok(res, { date, items: rows });
  } catch (err) { return R.serverError(res, err); }
};

module.exports = { getDashboard, getInventory, getAlerts, getReportByCategory, getReportUserActivity, createInventoryItem, updateInventoryItem, removeInventoryItem, removeBatchInventory, getActivityHistoryDates, getOrdersByDate };
