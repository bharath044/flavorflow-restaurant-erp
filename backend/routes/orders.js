const express = require('express');
const router = express.Router();
const db = require('../db');
const { v4: uuidv4 } = require('uuid');

// ─── GET ALL ACTIVE ORDERS ───────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM table_orders WHERE status != 'billed' ORDER BY updated_at DESC"
    );
    res.json(rows.map(formatOrder));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET ORDERS FOR A TABLE ──────────────────────────────────
router.get('/:tableNo', async (req, res) => {
  try {
    const [rows] = await db.query(
      "SELECT * FROM table_orders WHERE table_no=? AND status != 'billed' LIMIT 1",
      [req.params.tableNo]
    );
    if (!rows.length) return res.json(null);
    res.json(formatOrder(rows[0]));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── UPSERT ORDER (create or replace) ───────────────────────
router.post('/', async (req, res) => {
  try {
    const { id, tableNo, items, status, isTakeaway, customerName } = req.body;
    const orderId = id || uuidv4();
    const itemsJson = JSON.stringify(items || []);
    const orderStatus = status || 'sentToKitchen';

    // Delete existing active order for this table first
    await db.query(
      "DELETE FROM table_orders WHERE table_no=? AND status != 'billed'",
      [tableNo]
    );

    // Insert new/updated order
    try {
      await db.query(
        `INSERT INTO table_orders (id, table_no, status, is_takeaway, items, customer_name)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [orderId, tableNo, orderStatus, isTakeaway ? 1 : 0, itemsJson, customerName || '']
      );
    } catch (err) {
      // Auto-migrate column if missing
      if (err.code === 'ER_BAD_FIELD_ERROR') {
        await db.query("ALTER TABLE table_orders ADD COLUMN customer_name VARCHAR(120) DEFAULT ''");
        await db.query(
          `INSERT INTO table_orders (id, table_no, status, is_takeaway, items, customer_name)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [orderId, tableNo, orderStatus, isTakeaway ? 1 : 0, itemsJson, customerName || '']
        );
      } else throw err;
    }

    // Update table status
    await db.query(
      "UPDATE tables SET status='RUNNING' WHERE table_no=?", [tableNo]
    );

    res.json({ id: orderId, tableNo, status: orderStatus, items, isTakeaway });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── UPDATE ORDER STATUS ─────────────────────────────────────
router.patch('/:tableNo/status', async (req, res) => {
  try {
    const { status } = req.body;
    await db.query(
      "UPDATE table_orders SET status=? WHERE table_no=? AND status != 'billed'",
      [status, req.params.tableNo]
    );
    if (status === 'billed') {
      await db.query("UPDATE tables SET status='FREE' WHERE table_no=?", [req.params.tableNo]);
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── CLEAR TABLE ORDER (after billing) ──────────────────────
router.delete('/:tableNo', async (req, res) => {
  try {
    await db.query(
      "DELETE FROM table_orders WHERE table_no=? AND status != 'billed'",
      [req.params.tableNo]
    );
    await db.query("UPDATE tables SET status='FREE' WHERE table_no=?", [req.params.tableNo]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function formatOrder(row) {
  return {
    id: row.id,
    tableNo: row.table_no,
    status: row.status,
    isTakeaway: row.is_takeaway === 1,
    customerName: row.customer_name || '',
    items: typeof row.items === 'string' ? JSON.parse(row.items) : row.items,
    updatedAt: row.updated_at,
  };
}

module.exports = router;
