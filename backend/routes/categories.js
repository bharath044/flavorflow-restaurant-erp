const express = require('express');
const router = express.Router();
const db = require('../db');

// GET all categories
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM categories ORDER BY name');
    res.json(rows.map(r => ({ id: r.id, name: r.name })));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST new category
router.post('/', async (req, res) => {
  try {
    const { name } = req.body;
    const [result] = await db.query('INSERT IGNORE INTO categories (name) VALUES (?)', [name]);
    res.json({ id: result.insertId, name });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// DELETE category
router.delete('/:name', async (req, res) => {
  try {
    await db.query('DELETE FROM categories WHERE name=?', [req.params.name]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
