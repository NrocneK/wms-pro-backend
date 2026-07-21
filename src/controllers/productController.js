"use strict";
const db = require("../config/db");
const R = require("../utils/response");
const { warehouseGuard, assertWarehouse } = require("../middleware/warehouseGuard");
const { writeLog } = require("../utils/auditLog");

const calcStatus = (qty, min = 5) =>
  qty === 0 ? "zero" : qty <= min ? "low" : qty <= min * 2 ? "warning" : "ok";

const getAll = async (req, res) => {
  try {
    const {
      search = "",
      page = 1,
      limit = 50,
      warehouse_id = "",
      status = "",
    } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);
    const params = [];
    let where = "WHERE p.is_active=1";
    if (search) {
      where += " AND (p.barcode LIKE ? OR p.name LIKE ? OR p.supplier_code LIKE ? OR p.supplier_name LIKE ?)";
      params.push(`%${search}%`, `%${search}%`, `%${search}%`, `%${search}%`);
    }

    const { whId, whClause, whParams } = warehouseGuard(
      req.user,
      "inv.warehouse_id"
    );
    if (whId) {
      where += whClause;
      params.push(...whParams);
    } else if (warehouse_id) {
      where += " AND inv.warehouse_id=?";
      params.push(warehouse_id);
    }
    if (status) {
      where += " AND inv.status=?";
      params.push(status);
    }
    const [[{ total }]] = await db.execute(
      `SELECT COUNT(DISTINCT p.id) AS total FROM products p LEFT JOIN inventory inv ON inv.product_id=p.id ${where}`,
      params
    );
    const [rows] = await db.execute(
      `SELECT p.id,p.barcode,p.name,p.unit,p.cost_price,p.sell_price,p.supplier_code,p.supplier_name,COALESCE(inv.quantity,0) AS quantity,COALESCE(inv.min_stock,5) AS min_stock,COALESCE(inv.status,'zero') AS status,inv.location_text AS location,inv.zero_since,w.id AS warehouse_id,w.code AS warehouse_code,w.name AS warehouse_name,p.updated_at FROM products p LEFT JOIN inventory inv ON inv.product_id=p.id LEFT JOIN warehouses w ON w.id=inv.warehouse_id ${where} ORDER BY p.name LIMIT ? OFFSET ?`,
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

const getByBarcode = async (req, res) => {
  try {
    const { whClause, whParams } = warehouseGuard(req.user, "inv.warehouse_id");
    const [rows] = await db.execute(
      `SELECT p.*,inv.quantity,inv.min_stock,inv.status,inv.location_text AS location,inv.zero_since,w.code AS warehouse_code,w.name AS warehouse_name FROM products p LEFT JOIN inventory inv ON inv.product_id=p.id LEFT JOIN warehouses w ON w.id=inv.warehouse_id WHERE p.barcode=? AND p.is_active=1 ${whClause}`,
      [req.params.barcode, ...whParams]
    );
    if (!rows.length)
      return R.notFound(res, `Không tìm thấy barcode: ${req.params.barcode}`);
    return R.ok(res, rows);
  } catch (err) {
    return R.serverError(res, err);
  }
};

const create = async (req, res) => {
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const {
      barcode,
      name,
      unit = "Cái",
      cost_price = 0,
      sell_price = 0,
      note,
      supplier_code = null,
      supplier_name = null,
      warehouse_id = null,
      location_text = "",
      quantity = 0,
      min_stock = 5,
    } = req.body;
    if (!barcode || !name)
      return R.badRequest(res, "Thiếu barcode hoặc tên sản phẩm");
    if (warehouse_id && !assertWarehouse(warehouse_id, req.user))
      return R.forbidden(
        res,
        "Bạn chỉ được thêm sản phẩm vào kho được phân công"
      );
    const [pResult] = await conn.execute(
      `INSERT INTO products(barcode,name,unit,cost_price,sell_price,note,supplier_code,supplier_name)VALUES(?,?,?,?,?,?,?,?)`,
      [barcode, name, unit, cost_price, sell_price, note || null, supplier_code, supplier_name]
    );
    const productId = pResult.insertId;

    // Chỉ tạo dòng inventory nếu có chỉ định kho — cho phép tạo sản phẩm "trong danh mục" mà chưa gắn kho nào
    if (warehouse_id) {
      await conn.execute(
        `INSERT INTO inventory(product_id,warehouse_id,location_text,quantity,min_stock,status)VALUES(?,?,?,?,?,?)`,
        [
          productId,
          warehouse_id,
          location_text,
          quantity,
          min_stock,
          calcStatus(quantity, min_stock),
        ]
      );
    }

    await conn.commit();

    await writeLog(
      db,
      req.user,
      "CREATE",
      "product",
      productId,
      `Thêm sản phẩm mới: ${name} (${barcode})`,
      warehouse_id // null nếu chỉ tạo trong danh mục, chưa gắn kho nào
    );
    return R.created(
      res,
      { id: productId, barcode },
      "Thêm sản phẩm thành công"
    );
  } catch (err) {
    await conn.rollback();
    if (err.code === "ER_DUP_ENTRY")
      return R.badRequest(res, "Barcode đã tồn tại");
    return R.serverError(res, err);
  } finally {
    conn.release();
  }
};

const update = async (req, res) => {
  try {
    const { id } = req.params;
    if (req.user.warehouse_id) {
      const [[inv]] = await db.execute(
        "SELECT warehouse_id FROM inventory WHERE product_id=? AND warehouse_id=?",
        [id, req.user.warehouse_id]
      );
      if (!inv) return R.forbidden(res, "Sản phẩm không thuộc kho của bạn");
    }
    const { name, unit, cost_price, sell_price, note, supplier_code, supplier_name } = req.body;
    const [result] = await db.execute(
      `UPDATE products SET name=?,unit=?,cost_price=?,sell_price=?,note=?,supplier_code=?,supplier_name=? WHERE id=? AND is_active=1`,
      [name, unit, cost_price, sell_price, note || null, supplier_code || null, supplier_name || null, id]
    );
    if (!result.affectedRows) return R.notFound(res);

    // Không truyền warehouseId — product là catalog-level, không thuộc 1 kho cụ thể
    await writeLog(db, req.user, "UPDATE", "product", id,
      `Cập nhật sản phẩm id=${id}: ${req.body.name}`);

    return R.ok(res, {}, "Cập nhật thành công");
  } catch (err) {
    return R.serverError(res, err);
  }
};

const remove = async (req, res) => {
  try {
    await db.execute("UPDATE products SET is_active=0 WHERE id=?", [
      req.params.id,
    ]);
    // Không truyền warehouseId — product là catalog-level, không thuộc 1 kho cụ thể
    await writeLog(db, req.user, "DELETE", "product", req.params.id,
      `Xóa sản phẩm id=${req.params.id}`);
    return R.ok(res, {}, "Đã xóa sản phẩm");
  } catch (err) {
    return R.serverError(res, err);
  }
};

module.exports = { getAll, getByBarcode, create, update, remove };
