const express = require('express');
const router = express.Router();
const db = require('../db');
const { v4: uuidv4 } = require('uuid');

// ─── GET ALL INVOICES ────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const { from, to, limit } = req.query;
    let sql = 'SELECT * FROM invoices';
    const params = [];
    if (from && to) {
      sql += ' WHERE date BETWEEN ? AND ?';
      params.push(from, to);
    }
    sql += ' ORDER BY date DESC';
    if (limit) { sql += ' LIMIT ?'; params.push(parseInt(limit)); }
    const [rows] = await db.query(sql, params);
    res.json(rows.map(formatInvoice));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── TODAY SALES ─────────────────────────────────────────────
router.get('/today', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT SUM(total) as total FROM invoices WHERE DATE(date) = CURDATE()'
    );
    res.json({ total: parseFloat(rows[0].total) || 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GST TOTAL ───────────────────────────────────────────────
router.get('/gst', async (req, res) => {
  try {
    const [[setting]] = await db.query("SELECT value FROM settings WHERE key_name='gst_percent'");
    const gstPct = parseFloat(setting?.value || '5') / 100;
    const [[row]] = await db.query(
      'SELECT SUM(total) as total FROM invoices WHERE DATE(date) = CURDATE()'
    );
    const salesTotal = parseFloat(row?.total) || 0;
    res.json({ gst: parseFloat((salesTotal * gstPct).toFixed(2)) });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── CREATE INVOICE ──────────────────────────────────────────
router.post('/', async (req, res) => {
  try {
    const { id, deviceId, date, total, paymentMode, tableNo, items } = req.body;
    const invoiceId = id || uuidv4();
    // ─── INSERT INVOICE ───
    try {
      await db.query(
        `INSERT INTO invoices (id, device_id, date, total, payment_mode, table_no, items)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
        [invoiceId, deviceId || '', new Date(date), parseFloat(total),
         paymentMode || 'Cash', tableNo || '', JSON.stringify(items || [])]
      );
    } catch (dbErr) {
      if (dbErr.code === 'ER_NO_SUCH_TABLE') {
        await db.query(`
          CREATE TABLE invoices (
            id VARCHAR(50) PRIMARY KEY,
            device_id VARCHAR(50),
            date DATETIME,
            total DECIMAL(10,2),
            payment_mode VARCHAR(50),
            table_no VARCHAR(20),
            items JSON,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        `);
        // Retry
        await db.query(
          `INSERT INTO invoices (id, device_id, date, total, payment_mode, table_no, items)
           VALUES (?, ?, ?, ?, ?, ?, ?)`,
          [invoiceId, deviceId || '', new Date(date), parseFloat(total),
           paymentMode || 'Cash', tableNo || '', JSON.stringify(items || [])]
        );
      } else throw dbErr;
    }

    // ─── AUTO-DECREMENT STOCK ───
    if (items && Array.isArray(items)) {
      for (const item of items) {
        try {
          // Decrement standard product stock
          await db.query(
            "UPDATE products SET quantity = GREATEST(0, quantity - ?) WHERE id = ?",
            [item.quantity || 1, item.productId || item.id]
          );
        } catch (stockErr) {
          console.error("Stock update failed for item:", item.productId, stockErr);
        }
      }
    }
    res.json({ id: invoiceId, success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── UPDATE INVOICE ──────────────────────────────────────────
router.put('/:id', async (req, res) => {
  try {
    const { total, paymentMode, items } = req.body;
    await db.query(
      'UPDATE invoices SET total = ?, payment_mode = ?, items = ? WHERE id = ?',
      [parseFloat(total), paymentMode, JSON.stringify(items || []), req.params.id]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE INVOICE ──────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  const connection = await db.getConnection();
  await connection.beginTransaction();
  try {
    // 1. Get items to restore stock
    const [rows] = await connection.query('SELECT items FROM invoices WHERE id = ?', [req.params.id]);
    if (rows.length > 0) {
      const items = typeof rows[0].items === 'string' ? JSON.parse(rows[0].items) : (rows[0].items || []);
      for (const item of items) {
        await connection.query(
          "UPDATE products SET quantity = quantity + ? WHERE id = ?",
          [item.quantity || 1, item.productId || item.id]
        );
      }
    }

    // 2. Delete invoice
    await connection.query('DELETE FROM invoices WHERE id = ?', [req.params.id]);
    
    await connection.commit();
    res.json({ success: true });
  } catch (err) {
    await connection.rollback();
    res.status(500).json({ error: err.message });
  } finally {
    connection.release();
  }
});

function formatInvoice(row) {
  return {
    id: row.id,
    deviceId: row.device_id,
    date: row.date,
    total: parseFloat(row.total),
    paymentMode: row.payment_mode,
    tableNo: row.table_no,
    items: typeof row.items === 'string' ? JSON.parse(row.items) : (row.items || []),
    createdAt: row.created_at,
  };
}

module.exports = router;
