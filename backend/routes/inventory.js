const express = require('express');
const router = express.Router();
const db = require('../db');
const { v4: uuidv4 } = require('uuid');

// ─── GET ALL RAW MATERIALS ────────────────────────────────────
router.get('/materials', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM raw_materials ORDER BY name ASC');
    res.json(rows.map(formatMaterial));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── UPSERT MATERIAL ──────────────────────────────────────────
router.post('/materials', async (req, res) => {
  try {
    const { id, name, unit, current_stock, min_stock_level } = req.body;
    const materialId = id || uuidv4();

    try {
      await db.query(`
        INSERT INTO raw_materials (id, name, unit, current_stock, min_stock_level, updated_at)
        VALUES (?, ?, ?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE 
          name=VALUES(name),
          unit=VALUES(unit),
          current_stock=VALUES(current_stock),
          min_stock_level=VALUES(min_stock_level),
          updated_at=NOW()
      `, [materialId, name, unit, current_stock || 0, min_stock_level || 0]);
    } catch (dbErr) {
      if (dbErr.code === 'ER_NO_SUCH_TABLE') {
        await db.query(`
          CREATE TABLE raw_materials (
            id VARCHAR(50) PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            unit VARCHAR(20) NOT NULL,
            current_stock DECIMAL(10,2) DEFAULT 0,
            min_stock_level DECIMAL(10,2) DEFAULT 0,
            updated_at DATETIME
          )
        `);
        await db.query(`
          INSERT INTO raw_materials (id, name, unit, current_stock, min_stock_level, updated_at)
          VALUES (?, ?, ?, ?, ?, NOW())
        `, [materialId, name, unit, current_stock || 0, min_stock_level || 0]);
      } else throw dbErr;
    }
    
    res.json({ success: true, id: materialId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE MATERIAL ──────────────────────────────────────────
router.delete('/materials/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM raw_materials WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── RECIPES ──────────────────────────────────────────────────
router.get('/recipes', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM inventory_recipes ORDER BY product_name ASC');
    res.json(rows);
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.json([]);
    res.status(500).json({ error: err.message });
  }
});

router.post('/recipes', async (req, res) => {
  try {
    const d = req.body;
    await saveRecipe(d);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/recipes/:productId/:materialId', async (req, res) => {
  try {
    await db.query('DELETE FROM inventory_recipes WHERE product_id = ? AND material_id = ?', [req.params.productId, req.params.materialId]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function saveRecipe(d) {
  try {
    await db.query(
      `INSERT INTO inventory_recipes (product_id, product_name, material_id, material_name, unit, qty_per_serving)
       VALUES (?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE qty_per_serving = VALUES(qty_per_serving)`,
      [d.product_id, d.product_name, d.material_id, d.material_name, d.unit, d.qty_per_serving]
    );
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      await db.query(`
        CREATE TABLE inventory_recipes (
          product_id VARCHAR(50),
          product_name VARCHAR(100),
          material_id VARCHAR(50),
          material_name VARCHAR(100),
          unit VARCHAR(20),
          qty_per_serving DECIMAL(10,3),
          PRIMARY KEY (product_id, material_id)
        )
      `);
      return saveRecipe(d);
    } else throw err;
  }
}

// ─── TRANSACTION HISTORY (LOGS) ────────────────────────────────
router.get('/history/:type', async (req, res) => {
  try {
    const { type } = req.params; // stock_in, wastage, adjustments
    let table = '';
    if (type === 'stock_in') table = 'inventory_stock_in';
    else if (type === 'wastage') table = 'inventory_wastage';
    else if (type === 'adjustments') table = 'inventory_adjustments';
    else return res.status(400).json({ error: 'Invalid type' });

    const [rows] = await db.query(`SELECT * FROM ${table} ORDER BY date DESC LIMIT 100`);
    res.json(rows);
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.json([]);
    res.status(500).json({ error: err.message });
  }
});

// ─── SAVE TRANSACTION ──────────────────────────────────────────
router.post('/history/:type', async (req, res) => {
  try {
    const { type } = req.params;
    const data = req.body;
    
    if (type === 'stock_in') {
      await saveStockIn(data);
    } else if (type === 'wastage') {
      await saveWastage(data);
    } else if (type === 'adjustments') {
      await saveAdjustment(data);
    } else return res.status(400).json({ error: 'Invalid type' });

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function saveStockIn(d) {
  try {
    await db.query(
      `INSERT INTO inventory_stock_in (id, material_id, material_name, unit, quantity, purchase_price, supplier_name, date, notes)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [d.id, d.materialId, d.materialName, d.unit, d.quantity, d.purchasePrice, d.supplierName, new Date(d.date), d.notes]
    );
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      await db.query(`
        CREATE TABLE inventory_stock_in (
          id VARCHAR(50) PRIMARY KEY,
          material_id VARCHAR(50),
          material_name VARCHAR(100),
          unit VARCHAR(20),
          quantity DECIMAL(10,2),
          purchase_price DECIMAL(10,2),
          supplier_name VARCHAR(100),
          date DATETIME,
          notes TEXT
        )
      `);
      return saveStockIn(d);
    } else throw err;
  }
}

async function saveWastage(d) {
  try {
    await db.query(
      `INSERT INTO inventory_wastage (id, material_id, material_name, unit, quantity, reason, date)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [d.id, d.materialId, d.materialName, d.unit, d.quantity, d.reason, new Date(d.date)]
    );
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      await db.query(`
        CREATE TABLE inventory_wastage (
          id VARCHAR(50) PRIMARY KEY,
          material_id VARCHAR(50),
          material_name VARCHAR(100),
          unit VARCHAR(20),
          quantity DECIMAL(10,2),
          reason VARCHAR(255),
          date DATETIME
        )
      `);
      return saveWastage(d);
    } else throw err;
  }
}

async function saveAdjustment(d) {
  try {
    await db.query(
      `INSERT INTO inventory_adjustments (id, material_id, material_name, unit, old_qty, new_qty, difference, reason, date)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [d.id, d.materialId, d.materialName, d.unit, d.oldQty, d.newQty, d.difference, d.reason, new Date(d.date)]
    );
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      await db.query(`
        CREATE TABLE inventory_adjustments (
          id VARCHAR(50) PRIMARY KEY,
          material_id VARCHAR(50),
          material_name VARCHAR(100),
          unit VARCHAR(20),
          old_qty DECIMAL(10,2),
          new_qty DECIMAL(10,2),
          difference DECIMAL(10,2),
          reason VARCHAR(255),
          date DATETIME
        )
      `);
      return saveAdjustment(d);
    } else throw err;
  }
}

// ─── STOCK TRANSACTION (IN/OUT/WASTAGE) ───────────────────────
router.post('/transaction', async (req, res) => {
  try {
    const { materialId, quantity, type } = req.body; // type: 'in', 'out', 'waste'
    const delta = type === 'in' ? quantity : -quantity;
    
    await db.query(
      'UPDATE raw_materials SET current_stock = GREATEST(0, current_stock + ?), updated_at = NOW() WHERE id = ?',
      [delta, materialId]
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE TRANSACTION LOG (WITH STOCK REVERSAL) ──────────────
router.delete('/history/:type/:id', async (req, res) => {
  try {
    const { type, id } = req.params;
    let table = '';
    if (type === 'stock_in') table = 'inventory_stock_in';
    else if (type === 'wastage') table = 'inventory_wastage';
    else if (type === 'adjustments') table = 'inventory_adjustments';
    else return res.status(400).json({ error: 'Invalid type' });

    // 1. Get the transaction record to determine reversal amount
    const [rows] = await db.query(`SELECT * FROM ${table} WHERE id = ?`, [id]);
    if (rows.length === 0) return res.status(404).json({ error: 'Log not found' });
    const log = rows[0];

    // 2. Perform Stock Reversal
    if (type === 'stock_in') {
      // Subtract quantity from stock (reversing the purchase)
      await db.query('UPDATE raw_materials SET current_stock = GREATEST(0, current_stock - ?), updated_at = NOW() WHERE id = ?', [log.quantity, log.material_id]);
    } else if (type === 'wastage') {
      // Add quantity back to stock (reversing the loss)
      await db.query('UPDATE raw_materials SET current_stock = current_stock + ?, updated_at = NOW() WHERE id = ?', [log.quantity, log.material_id]);
    } else if (type === 'adjustments') {
      // Revert current_stock back to the old value
      await db.query('UPDATE raw_materials SET current_stock = ?, updated_at = NOW() WHERE id = ?', [log.old_qty, log.material_id]);
    }

    // 3. Delete the history log
    await db.query(`DELETE FROM ${table} WHERE id = ?`, [id]);

    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function formatMaterial(row) {
  return {
    id: row.id,
    name: row.name,
    unit: row.unit,
    current_stock: parseFloat(row.current_stock),
    min_stock_level: parseFloat(row.min_stock_level),
    updated_at: row.updated_at
  };
}

module.exports = router;
