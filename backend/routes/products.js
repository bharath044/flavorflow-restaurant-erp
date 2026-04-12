const express = require('express');
const router = express.Router();
const db = require('../db');
const { v4: uuidv4 } = require('uuid');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// ─── IMAGE UPLOAD SETUP ──────────────────────────────────────
const uploadDir = path.join(__dirname, '../uploads');
if (!fs.existsSync(uploadDir)) fs.mkdirSync(uploadDir, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname);
    cb(null, `${uuidv4()}${ext}`);
  },
});
const upload = multer({ storage, limits: { fileSize: 5 * 1024 * 1024 } });

// ─── GET ALL PRODUCTS ────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM products ORDER BY name');
    const products = rows.map(p => ({
      id: p.id,
      name: p.name,
      price: parseFloat(p.price),
      category: p.category,
      description: p.description,
      image: p.image_url || '',
      isAvailable: p.is_available === 1,
      quantity: p.quantity,
      qtyMorning: p.qty_morning || 0,
      qtyAfternoon: p.qty_afternoon || 0,
      qtyEvening: p.qty_evening || 0,
    }));
    res.json(products);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── GET SINGLE PRODUCT ──────────────────────────────────────
router.get('/:id', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM products WHERE id = ?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const p = rows[0];
    res.json({ id: p.id, name: p.name, price: parseFloat(p.price), category: p.category,
      description: p.description, image: p.image_url, isAvailable: p.is_available === 1, quantity: p.quantity,
      qtyMorning: p.qty_morning || 0, qtyAfternoon: p.qty_afternoon || 0, qtyEvening: p.qty_evening || 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── CREATE PRODUCT ──────────────────────────────────────────
router.post('/', upload.single('image'), async (req, res) => {
  try {
    const { name, price, category, description, isAvailable, quantity } = req.body;
    const id = uuidv4();
    const imageUrl = req.file ? `/uploads/${req.file.filename}` : (req.body.image || '');
    await db.query(
      'INSERT INTO products (id, name, price, category, description, image_url, is_available, quantity) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [id, name, parseFloat(price), category || '', description || '', imageUrl,
       isAvailable === 'false' || isAvailable === false ? 0 : 1, parseInt(quantity) || 0]
    );
    // Auto-add category if new
    if (category) {
      await db.query('INSERT IGNORE INTO categories (name) VALUES (?)', [category]);
    }
    res.json({ id, name, price: parseFloat(price), category, description, image: imageUrl,
      isAvailable: isAvailable !== 'false', quantity: parseInt(quantity) || 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── UPDATE PRODUCT ──────────────────────────────────────────
router.put('/:id', upload.single('image'), async (req, res) => {
  try {
    const { name, price, category, description, isAvailable, quantity } = req.body;
    const imageUrl = req.file
      ? `/uploads/${req.file.filename}`
      : (req.body.image || '');
    await db.query(
      `UPDATE products SET name=?, price=?, category=?, description=?, image_url=?,
       is_available=?, quantity=? WHERE id=?`,
      [name, parseFloat(price), category || '', description || '', imageUrl,
       isAvailable === 'false' || isAvailable === false ? 0 : 1,
       parseInt(quantity) || 0, req.params.id]
    );
    if (category) await db.query('INSERT IGNORE INTO categories (name) VALUES (?)', [category]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── UPDATE STOCK ONLY ──────────────────────────────────────
router.patch('/:id/stock', async (req, res) => {
  try {
    const { quantity } = req.body;
    await db.query('UPDATE products SET quantity=? WHERE id=?', [parseInt(quantity), req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── SYNC KITCHEN AVAILABILITY & STOCK ──────────────────────
router.patch('/:id/sync', async (req, res) => {
  try {
    const { quantity, isAvailable, session } = req.body;
    
    // Ensure session columns exist (Auto-migration)
    try {
      await db.query('ALTER TABLE products ADD COLUMN IF NOT EXISTS qty_morning INT DEFAULT 0');
      await db.query('ALTER TABLE products ADD COLUMN IF NOT EXISTS qty_afternoon INT DEFAULT 0');
      await db.query('ALTER TABLE products ADD COLUMN IF NOT EXISTS qty_evening INT DEFAULT 0');
    } catch (e) { /* ignore if already exists or IF NOT EXISTS not supported */ }

    let sql = 'UPDATE products SET quantity=?, is_available=?';
    let params = [parseInt(quantity), isAvailable ? 1 : 0];

    // Also update session-specific quantity if provided
    if (session) {
      if (session === 'morning') sql += ', qty_morning=?';
      else if (session === 'afternoon') sql += ', qty_afternoon=?';
      else if (session === 'evening') sql += ', qty_evening=?';
      params.push(parseInt(quantity));
    }

    sql += ' WHERE id=?';
    params.push(req.params.id);

    await db.query(sql, params);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE PRODUCT ──────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT image_url FROM products WHERE id=?', [req.params.id]);
    if (rows.length && rows[0].image_url) {
      const filePath = path.join(__dirname, '..', rows[0].image_url);
      if (fs.existsSync(filePath)) fs.unlinkSync(filePath);
    }
    await db.query('DELETE FROM products WHERE id=?', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
