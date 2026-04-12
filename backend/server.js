const express = require('express');
const cors = require('cors');
const path = require('path');
const db = require('./db');

const app = express();
const PORT = process.env.PORT || 3000;

// ─── MIDDLEWARE ──────────────────────────────────────────────
app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// ─── STATIC FILES (product images) ──────────────────────────
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// ─── ROOT ROUTE (Status Page) ───────────────────────────────
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>FlavorFlow Backend - Active</title>
        <style>
            body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #0f1117; color: #ffffff; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
            .card { background-color: #1a2035; padding: 2.5rem; border-radius: 16px; border: 1px solid #252d45; box-shadow: 0 10px 30px rgba(0,0,0,0.3); text-align: center; max-width: 450px; }
            h1 { color: #ff6a00; margin-top: 0; font-weight: 800; letter-spacing: -0.5px; }
            p { color: #8b949e; line-height: 1.6; }
            .status { display: inline-flex; align-items: center; background-color: rgba(63, 191, 63, 0.1); color: #4ade80; padding: 6px 12px; border-radius: 99px; font-size: 14px; font-weight: 600; margin-bottom: 20px; }
            .dot { width: 8px; height: 8px; background-color: #4ade80; border-radius: 50%; margin-right: 8px; box-shadow: 0 0 10px #4ade80; animation: pulse 2s infinite; }
            @keyframes pulse { 0% { opacity: 1; } 50% { opacity: 0.4; } 100% { opacity: 1; } }
            code { background-color: #0d1117; padding: 10px; border-radius: 8px; display: block; margin: 20px 0; color: #ff6a00; border: 1px solid #252d45; }
        </style>
    </head>
    <body>
        <div class="card">
            <div class="status"><span class="dot"></span> Server Active</div>
            <h1>FlavorFlow Backend</h1>
            <p>Your centralized restaurant management API is running correctly. The Mobile App will connect to this address automatically.</p>
            <code>API Status: OK (Listening on Port ${PORT})</code>
            <p style="font-size: 12px;">© 2026 Advanced Restaurant Systems</p>
        </div>
    </body>
    </html>
  `);
});

// ─── ROUTES ─────────────────────────────────────────────────
const productsRouter  = require('./routes/products');
const categoriesRouter = require('./routes/categories');
const ordersRouter    = require('./routes/orders');
const invoicesRouter  = require('./routes/invoices');
const tablesRouter    = require('./routes/tables');
const menuWebRouter   = require('./routes/menu_web');
const expensesRouter  = require('./routes/expenses');  // 🔥 NEW
const inventoryRouter = require('./routes/inventory'); // 🔥 NEW

app.use('/api/products',   productsRouter);
app.use('/api/categories', categoriesRouter);
app.use('/api/orders',     ordersRouter);
app.use('/api/invoices',   invoicesRouter);
app.use('/api/tables',     tablesRouter);
app.use('/menu',           menuWebRouter);   // Customer QR web menu
app.use('/api/expenses',   expensesRouter);   // 🔥 NEW
app.use('/api/inventory',  inventoryRouter);  // 🔥 NEW

// ─── CUSTOMER ORDER ENDPOINT (called from web menu JS) ──────
app.post('/customer-orders', async (req, res) => {
  try {
    const { tableNo, items, note } = req.body;
    await db.query(
      'INSERT INTO customer_orders (table_no, items, note) VALUES (?, ?, ?)',
      [tableNo, JSON.stringify(items), note || '']
    );
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── HEALTH CHECK ────────────────────────────────────────────
app.get('/health', (req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString() });
});

// ─── START SERVER (ONLY IF NOT IN VERCEL) ──────────────────────
if (process.env.NODE_ENV !== 'production' || !process.env.VERCEL) {
  app.listen(PORT, '0.0.0.0', async () => {
    console.log(`\n🚀 FlavorFlow Backend running on port ${PORT}`);
    console.log(`   Local:   http://localhost:${PORT}`);

    // Show local IPs
    const { networkInterfaces } = require('os');
    const nets = networkInterfaces();
    for (const name of Object.keys(nets)) {
      for (const net of nets[name]) {
        if (net.family === 'IPv4' && !net.internal) {
          console.log(`   Network: http://${net.address}:${PORT}`);
        }
      }
    }

    // Test DB connection
    try {
      await db.query('SELECT 1');
      console.log(`   ✅ MySQL connected`);
    } catch (err) {
      console.error(`   ❌ MySQL error: ${err.message}`);
      console.error(`   Make sure XAMPP MySQL is running!`);
    }

    console.log(`\n📱 Customer Menu QR: http://<YOUR_IP>:3000/menu/T1\n`);
  });
}

// ─── VERCEL EXPORT ───────────────────────────────────────────
module.exports = app;
