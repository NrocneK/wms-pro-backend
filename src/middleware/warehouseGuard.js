// src/middleware/warehouseGuard.js
"use strict";

const warehouseGuard = (user, colName = "warehouse_id") => {
  const whId = user?.warehouse_id || null;
  if (!whId) return { whId: null, whClause: "", whParams: [] };
  return { whId, whClause: ` AND ${colName} = ?`, whParams: [whId] };
};

const assertWarehouse = (requestedWhId, user) => {
  if (!user?.warehouse_id) return true;
  return String(requestedWhId) === String(user.warehouse_id);
};

module.exports = { warehouseGuard, assertWarehouse };
