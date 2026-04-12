const express = require('express');
const router = express.Router();
const db = require('../db');
const { v4: uuidv4 } = require('uuid');

// ─── GET ALL EXPENSES ────────────────────────────────────────
router.get('/', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM expenses ORDER BY date DESC');
    res.json(rows.map(formatExpense));
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── TODAY'S TOTAL ───────────────────────────────────────────
router.get('/today', async (req, res) => {
  try {
    const [rows] = await db.query(
      'SELECT SUM(amount) as total FROM expenses WHERE DATE(date) = CURDATE()'
    );
    res.json({ total: parseFloat(rows[0].total) || 0 });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── CREATE/UPDATE EXPENSE ───────────────────────────────────
router.post('/', async (req, res) => {
  try {
    const { id, category_id, category_name, amount, description, date, payment_mode } = req.body;
    const expenseId = id || uuidv4();
    
    // Auto-create table if missing
    try {
      await db.query(`
        INSERT INTO expenses (id, category_id, category_name, amount, description, date, payment_mode)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE 
          category_id=VALUES(category_id),
          category_name=VALUES(category_name),
          amount=VALUES(amount),
          description=VALUES(description),
          date=VALUES(date),
          payment_mode=VALUES(payment_mode)
      `, [expenseId, category_id, category_name, amount, description, new Date(date), payment_mode]);
    } catch (dbErr) {
      if (dbErr.code === 'ER_NO_SUCH_TABLE') {
        await db.query(`
          CREATE TABLE expenses (
            id VARCHAR(50) PRIMARY KEY,
            category_id VARCHAR(50),
            category_name VARCHAR(100),
            amount DECIMAL(10,2),
            description TEXT,
            date DATETIME,
            payment_mode VARCHAR(50)
          )
        `);
        // Retry
        await db.query(`
          INSERT INTO expenses (id, category_id, category_name, amount, description, date, payment_mode)
          VALUES (?, ?, ?, ?, ?, ?, ?)
        `, [expenseId, category_id, category_name, amount, description, new Date(date), payment_mode]);
      } else throw dbErr;
    }
    
    res.json({ success: true, id: expenseId });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── DELETE EXPENSE ──────────────────────────────────────────
router.delete('/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM expenses WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

function formatExpense(row) {
  return {
    id: row.id,
    categoryId: row.category_id,
    categoryName: row.category_name,
    amount: parseFloat(row.amount),
    description: row.description,
    date: row.date,
    paymentMode: row.payment_mode
  };
}

// ─── RECURRING EXPENSES ────────────────────────────────────────
router.get('/recurring', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM recurring_expenses ORDER BY day_of_month ASC');
    res.json(rows);
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.json([]);
    res.status(500).json({ error: err.message });
  }
});

router.post('/recurring', async (req, res) => {
  try {
    const d = req.body;
    await saveRecurring(d);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/recurring/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM recurring_expenses WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function saveRecurring(d) {
  try {
    await db.query(
      `INSERT INTO recurring_expenses (id, category_id, category_name, amount, description, day_of_month, is_active)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE 
         category_id=VALUES(category_id), category_name=VALUES(category_name), 
         amount=VALUES(amount), description=VALUES(description), 
         day_of_month=VALUES(day_of_month), is_active=VALUES(is_active)`,
      [d.id, d.category_id, d.category_name, d.amount, d.description, d.day_of_month, d.is_active ? 1 : 0]
    );
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      await db.query(`
        CREATE TABLE recurring_expenses (
          id VARCHAR(50) PRIMARY KEY,
          category_id VARCHAR(50),
          category_name VARCHAR(100),
          amount DECIMAL(10,2),
          description TEXT,
          day_of_month INTEGER,
          is_active TINYINT DEFAULT 1
        )
      `);
      return saveRecurring(d);
    } else throw err;
  }
}

// ─── SUPPLIER PAYMENTS ─────────────────────────────────────────
router.get('/supplier-payments', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM supplier_payments ORDER BY date DESC');
    res.json(rows);
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') return res.json([]);
    res.status(500).json({ error: err.message });
  }
});

router.post('/supplier-payments', async (req, res) => {
  try {
    const d = req.body;
    await saveSupplierPayment(d);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

router.delete('/supplier-payments/:id', async (req, res) => {
  try {
    await db.query('DELETE FROM supplier_payments WHERE id = ?', [req.params.id]);
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

async function saveSupplierPayment(d) {
  try {
    await db.query(
      `INSERT INTO supplier_payments (id, supplier_name, total_amount, paid_amount, description, date, payment_mode)
       VALUES (?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE 
         total_amount=VALUES(total_amount), paid_amount=VALUES(paid_amount), 
         description=VALUES(description), date=VALUES(date), payment_mode=VALUES(payment_mode)`,
      [d.id, d.supplier_name, d.total_amount, d.paid_amount, d.description, new Date(d.date), d.payment_mode]
    );
  } catch (err) {
    if (err.code === 'ER_NO_SUCH_TABLE') {
      await db.query(`
        CREATE TABLE supplier_payments (
          id VARCHAR(50) PRIMARY KEY,
          supplier_name VARCHAR(100),
          total_amount DECIMAL(10,2),
          paid_amount DECIMAL(10,2),
          description TEXT,
          date DATETIME,
          payment_mode VARCHAR(50)
        )
      `);
      return saveSupplierPayment(d);
    } else throw err;
  }
}

module.exports = router;
