const express = require('express');
const router = express.Router();
const db = require('../db');
const QRCode = require('qrcode');

// ─── GET ALL TABLES WITH STATUS ──────────────────────────────
router.get('/', async (req, res) => {
  try {
    const [tables] = await db.query('SELECT * FROM tables ORDER BY table_no');
    // Enrich with active order count
    const [orders] = await db.query(
      "SELECT table_no, COUNT(*) as cnt FROM table_orders WHERE status != 'billed' GROUP BY table_no"
    );
    const orderMap = {};
    orders.forEach(o => (orderMap[o.table_no] = o.cnt));

    res.json(tables.map(t => ({
      tableNo: t.table_no,
      label: t.label,
      status: orderMap[t.table_no] ? 'RUNNING' : 'FREE',
    })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── ADD TABLE ───────────────────────────────────────────────
router.post('/', async (req, res) => {
  try {
    const { tableNo, label } = req.body;
    await db.query('INSERT IGNORE INTO tables (table_no, label) VALUES (?, ?)', [tableNo, label || tableNo]);
    res.json({ success: true, tableNo });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE TABLE ────────────────────────────────────────────
router.delete('/:tableNo', async (req, res) => {
  try {
    await db.query('DELETE FROM tables WHERE table_no=?', [req.params.tableNo]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET QR CODE for a table (returns base64 PNG) ───────────
router.get('/:tableNo/qr', async (req, res) => {
  try {
    // The QR content is the URL staff/customers scan
    const host = req.headers.host; // e.g. 192.168.1.37:3000
    const protocol = req.protocol;
    const url = `${protocol}://${host}/menu/${req.params.tableNo}`;
    const qrBase64 = await QRCode.toDataURL(url, {
      width: 400,
      margin: 2,
      color: { dark: '#000000', light: '#FFFFFF' },
    });
    res.json({ tableNo: req.params.tableNo, url, qr: qrBase64 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET SETTINGS (table count, restaurant name) ─────────────
router.get('/settings/all', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM settings');
    const map = {};
    rows.forEach(r => (map[r.key_name] = r.value));
    res.json(map);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── UPDATE SETTINGS ─────────────────────────────────────────
router.put('/settings/:key', async (req, res) => {
  try {
    const { value } = req.body;
    await db.query(
      'INSERT INTO settings (key_name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value=?',
      [req.params.key, value, value]
    );
    // If table_count changed, sync the tables table
    if (req.params.key === 'table_count') {
      const count = parseInt(value);
      for (let i = 1; i <= count; i++) {
        await db.query('INSERT IGNORE INTO tables (table_no, label) VALUES (?, ?)',
          [`T${i}`, `Table ${i}`]);
      }
    }
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
