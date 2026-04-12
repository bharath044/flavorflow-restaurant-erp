const express = require('express');
const router  = express.Router();
const db      = require('../db');

// ─── SUBMIT ORDER ────────────────────────────────────────────
router.post('/submit', async (req, res) => {
  try {
    const { tableNo, customerName, customerPhone, items, note } = req.body;
    const [result] = await db.query(
      `INSERT INTO customer_orders
         (table_no, customer_name, customer_phone, items, note, status, created_at)
       VALUES (?, ?, ?, ?, ?, 'pending', NOW())`,
      [tableNo, customerName || '', customerPhone || '', JSON.stringify(items), note || '']
    );
    res.json({ success: true, id: result.insertId });
  } catch (err) {
    try {
      await db.query(`ALTER TABLE customer_orders
        ADD COLUMN IF NOT EXISTS customer_name  VARCHAR(120) DEFAULT '',
        ADD COLUMN IF NOT EXISTS customer_phone VARCHAR(20)  DEFAULT '',
        ADD COLUMN IF NOT EXISTS created_at     DATETIME    DEFAULT CURRENT_TIMESTAMP`);
    } catch (_) {}
    const { tableNo, customerName, customerPhone, items, note } = req.body;
    const [result] = await db.query(
      `INSERT INTO customer_orders (table_no, customer_name, customer_phone, items, note, status)
       VALUES (?, ?, ?, ?, ?, 'pending')`,
      [tableNo, customerName || '', customerPhone || '', JSON.stringify(items), note || '']
    );
    res.json({ success: true, id: result.insertId });
  }
});

// ─── CANCEL ORDER ──────────────────────────────────────────────
router.patch('/:id/cancel', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM customer_orders WHERE id=?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const order = rows[0];
    const diffMs = Date.now() - new Date(order.created_at).getTime();
    if (diffMs > 2 * 60 * 1000) return res.status(403).json({ error: 'Window expired' });
    
    await db.query("UPDATE customer_orders SET status='cancelled' WHERE id=?", [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── UPDATE ORDER ──────────────────────────────────────────────
router.patch('/:id/update', async (req, res) => {
  try {
    const { items, note } = req.body;
    const [rows] = await db.query('SELECT * FROM customer_orders WHERE id=?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const order = rows[0];
    const diffMs = Date.now() - new Date(order.created_at).getTime();
    if (diffMs > 2 * 60 * 1000) return res.status(403).json({ error: 'Window expired' });

    await db.query('UPDATE customer_orders SET items=?, note=? WHERE id=?',
      [JSON.stringify(items), note || order.note, req.params.id]
    );
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── GET PENDING/RECENT ORDERS (for app polling) ────────────
router.get('/pending', async (req, res) => {
  try {
    const [rows] = await db.query(
      `SELECT * FROM customer_orders 
       WHERE status='pending' 
       OR (status='accepted' AND created_at > NOW() - INTERVAL 10 MINUTE)
       ORDER BY created_at ASC`
    );
    res.json(rows.map(r => ({
      id:            r.id,
      tableNo:       r.table_no,
      customerName:  r.customer_name || '',
      customerPhone: r.customer_phone || '',
      items:         typeof r.items === 'string' ? JSON.parse(r.items) : r.items,
      note:          r.note,
      status:        r.status,
      createdAt:     r.created_at,
    })));
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── GET SINGLE ORDER (tracking) ────────────────────────────
router.get('/order/:id', async (req, res) => {
  try {
    const [rows] = await db.query('SELECT * FROM customer_orders WHERE id=?', [req.params.id]);
    if (!rows.length) return res.status(404).json({ error: 'Not found' });
    const r = rows[0];
    res.json({
      id:        r.id,
      items:     typeof r.items === 'string' ? JSON.parse(r.items) : r.items,
      status:    r.status,
      createdAt: r.created_at
    });
  } catch(err) { res.status(500).json({ error: err.message }); }
});

router.patch('/:id/accept', async (req, res) => {
  try {
    await db.query("UPDATE customer_orders SET status='accepted' WHERE id=?", [req.params.id]);
    res.json({ success: true });
  } catch (err) { res.status(500).json({ error: err.message }); }
});

// ─── WEB MENU ───────────────────────────────────────────────
router.get('/:tableNo', async (req, res) => {
  try {
    const { tableNo } = req.params;
    const [tables] = await db.query('SELECT * FROM `tables` WHERE table_no=?', [tableNo]);
    if (!tables.length) return res.status(404).send(errorPage('Table not found'));
    const [products] = await db.query('SELECT * FROM products WHERE is_available=1 ORDER BY category, name');
    let restaurantName = 'FlavorFlow';
    try {
      const [[setting]] = await db.query("SELECT value FROM settings WHERE key_name='restaurant_name'");
      if (setting?.value) restaurantName = setting.value;
    } catch (_) {}
    const cats = [...new Set(products.map(p => p.category || 'Other'))];
    const productsJson = JSON.stringify(products.map(p => ({
      id:    p.id,
      name:  p.name,
      price: parseFloat(p.price),
      category: p.category || 'Other',
      image: p.image_url || p.image || '',
      quantity: p.quantity || 0,
    })));
    res.send(buildPage({ restaurantName, tableNo, cats, productsJson }));
  } catch (err) { res.status(500).send(errorPage(err.message)); }
});

module.exports = router;

// ────────────────────────────────────────────────────────────
// UI BUILDERS
// ────────────────────────────────────────────────────────────
function buildPage({ restaurantName, tableNo, cats, productsJson }) {
  const catButtons = ['All', ...cats].map(c =>
    `<button class="cat-btn${c==='All'?' active':''}" data-cat="${c==='All'?'__all__':c}">${c}</button>`
  ).join('');

  return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1">
<title>${restaurantName} — Table ${tableNo}</title>
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
<style>
:root {
  --primary: #EE6F0A; --bg: #0D0D0D; --surface: #18181A; --surface-2: #242426;
  --border: rgba(255,255,255,0.08); --text: #FFFFFF; --text-muted: #8E8E93; --header-h: 72px;
}
* { margin:0; padding:0; box-sizing:border-box; -webkit-tap-highlight-color:transparent; }
body { font-family:'Inter',sans-serif; background:var(--bg); color:var(--text); min-height:100vh; overflow-x:hidden; }
.header { height:var(--header-h); background:var(--bg); border-bottom:1px solid var(--border); padding:0 20px; display:flex; align-items:center; justify-content:space-between; position:sticky; top:0; z-index:500; backdrop-filter:blur(10px); }
.brand-name { font-weight:900; font-size:20px; color:var(--primary); }
.brand-sub { font-size:10px; font-weight:700; color:var(--text-muted); opacity:0.6; }
.header-actions { display:flex; align-items:center; gap:12px; }
.table-badge { background:var(--surface); border:1px solid var(--border); border-radius:12px; padding:8px 14px; font-size:12px; font-weight:700; display:flex; align-items:center; gap:8px; }
.table-dot { width:8px; height:8px; background:var(--primary); border-radius:50%; box-shadow:0 0 8px var(--primary); }
.icon-btn { width:44px; height:44px; background:var(--surface); border:1px solid var(--border); border-radius:12px; display:flex; align-items:center; justify-content:center; font-size:20px; cursor:pointer; position:relative; }
.icon-btn.active::after { content:''; position:absolute; top:8px; right:8px; width:8px; height:8px; background:#4CD964; border-radius:50%; border:2px solid var(--surface); animation:pulse 1.5s infinite; }
@keyframes pulse { 0% { opacity:1; transform:scale(1); } 50% { opacity:0.5; transform:scale(1.2); } 100% { opacity:1; transform:scale(1); } }

.screen { position:absolute; top:var(--header-h); left:0; width:100%; min-height:calc(100vh - var(--header-h)); background:var(--bg); transition:transform 0.4s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.3s; padding-bottom:120px; z-index:10; }
.screen.hidden { transform:translateX(100%); opacity:0; pointer-events:none; }
#screen-menu { z-index:20; }
#screen-tracking { z-index:30; background:var(--bg); transform:translateX(0); }
#screen-tracking.hidden { transform:translateX(-100%); }

.hero { padding:20px; }
.hero-card { position:relative; height:180px; border-radius:24px; overflow:hidden; display:flex; flex-direction:column; justify-content:flex-end; padding:24px; }
.hero-img { position:absolute; inset:0; width:100%; height:100%; object-fit:cover; z-index:1; }
.hero-overlay { position:absolute; inset:0; background:linear-gradient(to top, rgba(0,0,0,0.9), transparent); z-index:2; }
.hero-content { position:relative; z-index:3; }
.hero-badge { background:rgba(255,255,255,0.2); backdrop-filter:blur(8px); padding:4px 10px; border-radius:6px; font-size:10px; font-weight:800; display:inline-block; margin-bottom:8px; }
.hero-title { font-size:24px; font-weight:900; }

.cat-wrap { position:sticky; top:0; background:var(--bg); z-index:90; padding:12px 0; }
.cat-bar { display:flex; gap:10px; padding:0 20px; overflow-x:auto; scrollbar-width:none; }
.cat-bar::-webkit-scrollbar { display:none; }
.cat-btn { white-space:nowrap; padding:12px 24px; border-radius:14px; background:var(--surface); border:1px solid var(--border); color:var(--text-muted); font-size:14px; font-weight:700; cursor:pointer; }
.cat-btn.active { background:var(--primary); color:var(--text); border-color:var(--primary); }

.products { padding:10px 20px; display:flex; flex-direction:column; gap:16px; }
.p-card { background:var(--surface); border-radius:20px; border:1px solid var(--border); display:flex; overflow:hidden; min-height:130px; cursor:pointer; }
.p-card.out { opacity:0.6; filter:grayscale(1); }
.p-img-wrap { width:120px; height:130px; flex-shrink:0; background:var(--surface-2); display:flex; align-items:center; justify-content:center; }
.p-img { width:100%; height:100%; object-fit:cover; }
.p-info { flex:1; padding:16px; display:flex; flex-direction:column; justify-content:space-between; }
.p-name { font-size:16px; font-weight:800; display:block; margin-bottom:4px; }
.p-price { font-size:18px; font-weight:900; color:var(--text); }
.p-meta { display:flex; align-items:center; gap:8px; margin:8px 0; }
.p-stock-dot { width:6px; height:6px; background:#4CD964; border-radius:50%; }
.p-card.out .p-stock-dot { background:#FF3B30; }
.p-stock-label { font-size:11px; font-weight:700; color:var(--text-muted); }
.add-btn { background:var(--primary); color:var(--text); border:none; border-radius:12px; padding:10px 18px; font-size:13px; font-weight:900; cursor:pointer; }
.qty-ctrl { display:flex; align-items:center; gap:16px; background:var(--surface-2); border-radius:12px; padding:6px 12px; }
.q-btn { width:24px; height:24px; background:none; border:none; color:var(--text); font-size:20px; font-weight:700; cursor:pointer; }
.q-val { font-size:15px; font-weight:900; min-width:20px; text-align:center; }

.bottom-bar { position:fixed; bottom:24px; left:20px; right:20px; z-index:1000; display:none; }
.bottom-bar.visible { display:block; animation:popIn 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275); }
@keyframes popIn { from { transform:scale(0.8); opacity:0; } to { transform:scale(1); opacity:1; } }
.action-card { background:var(--primary); border-radius:24px; padding:18px 24px; display:flex; align-items:center; justify-content:space-between; box-shadow: 0 20px 40px rgba(238,111,10,0.4); cursor:pointer; }
.ac-badge { width:22px; height:22px; background:#fff; color:var(--primary); border-radius:50%; font-size:12px; font-weight:900; display:flex; align-items:center; justify-content:center; }
.ac-total { font-size:24px; font-weight:900; }

.overlay { position:fixed; inset:0; background:rgba(0,0,0,0.8); backdrop-filter:blur(4px); z-index:2000; display:none; align-items:flex-end; }
.overlay.show { display:flex; }
.drawer { background:#161617; width:100%; border-radius:32px 32px 0 0; padding:20px 20px 40px; transform:translateY(100%); transition:transform 0.3s ease; }
.overlay.show .drawer { transform:translateY(0); }
.d-header { display:flex; align-items:center; justify-content:space-between; margin-bottom:24px; }
.d-title { font-size:18px; font-weight:900; }
.d-close { width:36px; height:36px; background:var(--surface-2); border-radius:12px; display:flex; align-items:center; justify-content:center; cursor:pointer; }
.btn-main { width:100%; background:var(--primary); color:#fff; border:none; border-radius:16px; padding:18px; font-size:15px; font-weight:900; cursor:pointer; }

/* ── TRACKING SCREEN ───────────────────────────────────────── */
.track-header { padding:20px; display:flex; align-items:center; gap:16px; border-bottom:1px solid var(--border); }
.back-btn { width:40px; height:40px; background:var(--surface); border-radius:50%; display:flex; align-items:center; justify-content:center; font-size:18px; cursor:pointer; }
.track-body { padding:20px; display:flex; flex-direction:column; gap:20px; }
.status-card { background:var(--surface); border-radius:24px; padding:24px; border:1px solid var(--primary); display:flex; flex-direction:column; align-items:center; gap:12px; }
.status-icon { width:64px; height:64px; background:var(--surface-2); border-radius:20px; display:flex; align-items:center; justify-content:center; font-size:32px; }
.status-title { font-size:20px; font-weight:900; color:var(--primary); }
.status-desc { font-size:12px; color:var(--text-muted); text-align:center; }
.items-card { background:var(--surface); border-radius:24px; padding:20px; }
.track-item { display:flex; justify-content:space-between; align-items:center; padding:16px 0; border-bottom:1px solid var(--border); }
.track-item:last-child { border:none; }
.track-item.cancelled { opacity:0.3; }
.track-item.cancelled .ti-name { text-decoration:line-through; }
.ti-name { font-weight:700; font-size:15px; display:block; }
.ti-meta { font-size:12px; color:var(--text-muted); margin-top:4px; }
.ti-price { font-weight:800; color:var(--primary); }
.ti-status { font-size:10px; font-weight:900; color:#ff3d3d; margin-left:8px; }
.ti-cancel { background:rgba(255,61,61,0.1); color:#ff3d3d; border:none; border-radius:10px; padding:8px 16px; font-size:11px; font-weight:900; cursor:pointer; }
.ti-cancel:disabled { opacity:0; pointer-events:none; }
</style>
</head>
<body>
<div class="header">
  <div class="brand"><div class="brand-name">${restaurantName}</div><div class="brand-sub">KINETIC ENGINE</div></div>
  <div class="header-actions">
    <div class="table-badge"><div class="table-dot"></div> T-${tableNo}</div>
    <div class="icon-btn" id="track-trigger" onclick="showScreen('tracking')">📦</div>
    <div class="icon-btn" onclick="openProfile()">👤</div>
  </div>
</div>

<div class="screen" id="screen-menu">
  <div class="hero"><div class="hero-card"><img src="https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&fit=crop" class="hero-img"><div class="hero-overlay"></div><div class="hero-content"><div class="hero-badge">CHEF'S SPECIAL</div><div class="hero-title">Tasty Creations</div></div></div></div>
  <div class="cat-wrap"><div class="cat-bar" id="cat-bar">${catButtons}</div></div>
  <div class="products" id="prod-grid"></div>
</div>

<div class="screen hidden" id="screen-tracking">
  <div class="track-header"><div class="back-btn" onclick="showScreen('menu')">←</div><div style="font-weight:900;font-size:18px">My Orders</div></div>
  <div class="track-body">
    <div class="status-card">
      <div class="status-icon" id="stat-icon">🍳</div>
      <div class="status-title" id="stat-title">Preparing</div>
      <div class="status-desc" id="stat-desc">The kitchen is crafting your delicious meal now.</div>
      <div id="stat-id" style="font-size:11px;opacity:0.6;margin-top:8px">Order ID: #---</div>
      <div id="cancel-zone" style="margin-top:20px;width:100%;display:none">
        <div id="cancel-timer" style="font-size:12px;color:#ff3d3d;font-weight:700;margin-bottom:10px;text-align:center"></div>
        <button class="btn-main" onclick="cancelFullOrder()" style="background:#ff3d3d;padding:14px;font-size:13px">CANCEL ENTIRE ORDER</button>
      </div>
    </div>
    <div class="items-card" id="track-items-list"></div>
    <button class="btn-main" onclick="showScreen('menu')" style="background:var(--surface-2)">ADD MORE ITEMS</button>
  </div>
</div>

<div class="bottom-bar" id="bottom-bar" onclick="openOrderDrawer()">
  <div class="action-card">
    <div style="display:flex;align-items:center;gap:12px"><div class="ac-badge" id="bag-count">0</div><div><div style="font-weight:900">VIEW BUCKET</div><div id="bag-sub" style="font-size:11px;opacity:0.8">0 items</div></div></div>
    <div class="ac-total" id="bag-total">₹0</div>
  </div>
</div>

<div class="overlay" id="profile-overlay" onclick="maybeClose(event, 'profile-overlay')">
  <div class="drawer">
    <div class="d-header"><span class="d-title">Customer Info</span><div class="d-close" onclick="closeProfile()">✕</div></div>
    <div style="margin-bottom:20px">
      <label class="form-label" style="display:block;font-size:11px;font-weight:800;color:var(--text-muted);margin-bottom:8px">FULL NAME</label>
      <input class="form-input" id="inp-name" placeholder="John Doe" style="width:100%;padding:16px;background:var(--surface);border:1px solid var(--border);border-radius:14px;color:#fff;outline:none">
    </div>
    <div style="margin-bottom:24px">
      <label class="form-label" style="display:block;font-size:11px;font-weight:800;color:var(--text-muted);margin-bottom:8px">PHONE NUMBER</label>
      <input class="form-input" id="inp-phone" placeholder="10 Digits" maxlength="10" style="width:100%;padding:16px;background:var(--surface);border:1px solid var(--border);border-radius:14px;color:#fff;outline:none">
    </div>
    <button class="btn-main" onclick="saveProfile()">CONTINUE</button>
  </div>
</div>

<div class="overlay" id="order-overlay" onclick="maybeClose(event, 'order-overlay')">
  <div class="drawer">
    <div class="d-header"><span class="d-title">Bucket Items</span><div class="d-close" onclick="closeOrderDrawer()">✕</div></div>
    <div id="drawer-items" style="max-height:45vh;overflow-y:auto"></div>
    <div style="margin:20px 0;background:var(--surface-2);padding:18px;border-radius:20px">
      <div style="display:flex;justify-content:space-between;opacity:0.6;margin-bottom:8px;font-size:13px"><span>Subtotal (estimated)</span><span id="bill-sub">₹0</span></div>
      <div style="display:flex;justify-content:space-between;font-weight:900;font-size:18px"><span>Grand Total</span><span id="bill-total" style="color:var(--primary)">₹0</span></div>
    </div>
    <button class="btn-main" id="place-btn" onclick="validateAndPlace()">CONFIRM & ORDER</button>
  </div>
</div>

<script>
const TABLE_NO = '${tableNo}'; const PRODUCTS = ${productsJson};
let cart = {}; let activeOrderId = localStorage.getItem('last_order_id');
let currentOrder = null;

window.onload = () => {
  const n = localStorage.getItem('flavor_name'); const p = localStorage.getItem('flavor_phone');
  if(n) document.getElementById('inp-name').value = n; if(p) document.getElementById('inp-phone').value = p;
  if(activeOrderId) pollOrder(); renderProducts('__all__');
  showScreen('menu');
};

function maybeClose(e, id) { if(e.target === document.getElementById(id)) { closeProfile(); closeOrderDrawer(); } }
function openProfile() { document.getElementById('profile-overlay').classList.add('show'); }
function closeProfile() { document.getElementById('profile-overlay').classList.remove('show'); }
function openOrderDrawer() { buildOrderSummary(); document.getElementById('order-overlay').classList.add('show'); }
function closeOrderDrawer() { document.getElementById('order-overlay').classList.remove('show'); }

function showScreen(id) {
  document.querySelectorAll('.screen').forEach(s => s.classList.add('hidden'));
  document.getElementById('screen-' + id).classList.remove('hidden');
}

function saveProfile() {
  const n = document.getElementById('inp-name').value.trim(); const p = document.getElementById('inp-phone').value.trim();
  if(!n || p.length<10) return alert('Please enter valid details');
  localStorage.setItem('flavor_name', n); localStorage.setItem('flavor_phone', p); closeProfile();
}

function renderProducts(cat) {
  const grid = document.getElementById('prod-grid');
  grid.innerHTML = PRODUCTS.filter(p => cat==='__all__' || p.category===cat).map(p => {
    const qty = cart[p.id] || 0; const isOut = p.quantity<=0;
    return \`<div class="p-card \${isOut?'out':''}" onclick="\${isOut?'':"checkAuthAndAdd('"+p.id+"')" }">
      <div class="p-img-wrap">\${p.image?\`<img class="p-img" src="\${p.image}" onerror="this.style.display='none'">\`:''}🥘</div>
      <div class="p-info">
        <div><span class="p-name">\${p.name}</span><span class="p-price">₹\${p.price.toFixed(0)}</span>
          <div class="p-meta"><div class="p-stock-dot"></div><span class="p-stock-label">\${isOut?'OUT OF STOCK':'AVAILABLE'}</span></div>
        </div>
        <div class="p-footer">
          \${isOut?'':(qty>0?\`<div class="qty-ctrl"><div class="q-btn" onclick="event.stopPropagation();chgQty('\${p.id}',-1)">−</div><div class="q-val">\${qty}</div><div class="q-btn" onclick="event.stopPropagation();chgQty('\${p.id}',1)">+</div></div>\`:\`<button class="add-btn">ADD +</button>\`)}
        </div>
      </div>
    </div>\`;
  }).join('');
}

function checkAuthAndAdd(id) {
  if(!localStorage.getItem('flavor_name')) { alert('Please enter your details to start ordering.'); openProfile(); return; }
  chgQty(id, 1);
}

function chgQty(id, delta) {
  cart[id] = Math.max(0, (cart[id]||0)+delta); if(cart[id]===0) delete cart[id];
  renderProducts(document.querySelector('.cat-btn.active').dataset.cat); updateBottomBar();
}

function updateBottomBar() {
  const entries = Object.entries(cart); const count = entries.reduce((s,[,q])=>s+q,0);
  const total = entries.reduce((s,[id,q])=>s+q*PRODUCTS.find(p=>p.id===id).price, 0);
  document.getElementById('bag-count').textContent = count;
  document.getElementById('bag-sub').textContent = count + ' items';
  document.getElementById('bag-total').textContent = '₹'+total.toFixed(0);
  document.getElementById('bottom-bar').classList.toggle('visible', count>0);
}

function buildOrderSummary() {
  const entries = Object.entries(cart); const sub = entries.reduce((s,[id,q])=>s+q*PRODUCTS.find(p=>p.id===id).price, 0);
  document.getElementById('drawer-items').innerHTML = entries.map(([id,q])=>{
    const p = PRODUCTS.find(p=>p.id===id);
    return \`<div style="display:flex;justify-content:space-between;padding:16px 0;border-bottom:1px solid var(--border)">
      <div><b style="font-size:15px">\${p.name}</b><br><small style="color:var(--text-muted)">₹\${p.price} × \${q}</small></div><b>₹\${p.price*q}</b>
    </div>\`;
  }).join('');
  document.getElementById('bill-sub').textContent = '₹'+sub.toFixed(0);
  document.getElementById('bill-total').textContent = '₹'+(sub*1.05).toFixed(0);
}

async function validateAndPlace() {
  const items = Object.entries(cart).map(([id,q])=>({productId:id, name:PRODUCTS.find(p=>p.id===id).name, price:PRODUCTS.find(p=>p.id===id).price, quantity:q}));
  const res = await fetch('/menu/submit', {
    method:'POST',headers:{'Content-Type':'application/json'},
    body: JSON.stringify({ tableNo:TABLE_NO, customerName:localStorage.getItem('flavor_name'), customerPhone:localStorage.getItem('flavor_phone'), items })
  });
  const data = await res.json();
  if(data.success) { localStorage.setItem('last_order_id',data.id); activeOrderId=data.id; cart={}; closeOrderDrawer(); pollOrder(); showScreen('tracking'); }
}

async function pollOrder() {
  if(!activeOrderId) return;
  const res = await fetch('/menu/order/'+activeOrderId); const order = await res.json();
  if(order.error) { activeOrderId=null; localStorage.removeItem('last_order_id'); document.getElementById('track-trigger').classList.remove('active'); return; }
  
  document.getElementById('track-trigger').classList.add('active');
  document.getElementById('stat-id').textContent = "Order ID: #" + order.id;
  
  // Update status visuals
  const sTitle = document.getElementById('stat-title');
  const sDesc = document.getElementById('stat-desc');
  const sIcon = document.getElementById('stat-icon');
  
  if (order.status === 'pending') {
    sTitle.textContent = "Pending";
    sDesc.textContent = "Waiting for the kitchen to accept your order.";
    sIcon.textContent = "⌛";
  } else if (order.status === 'accepted') {
    sTitle.textContent = "Preparing";
    sDesc.textContent = "The kitchen is crafting your delicious meal now.";
    sIcon.textContent = "🍳";
  } else if (order.status === 'cancelled') {
    sTitle.textContent = "Cancelled";
    sDesc.textContent = "This order has been cancelled.";
    sIcon.textContent = "❌";
    sTitle.style.color = "#ff3d3d";
    activeOrderId = null; localStorage.removeItem('last_order_id');
    document.getElementById('track-trigger').classList.remove('active');
  }

  currentOrder = order;
  const diffMs = new Date() - new Date(order.createdAt);
  const timeLimit = 2 * 60 * 1000;
  const canCan = order.status === 'pending' && diffMs < timeLimit;
  
  runTimer();
  
  renderItems(order, canCan);
}

function renderItems(order, canCan) {
  const itemsHtml = order.itemstree ? order.itemstree.map((i,idx)=>\`
    <div class="track-item \${i.isCancelled?'cancelled':''}">
      <div class="ti-main">
        <span class="ti-name">\${i.name} × \${i.quantity}</span>
        <div class="ti-meta"><span class="ti-price">₹\${i.price*i.quantity}</span>\${i.isCancelled?'<span class="ti-status">CANCELLED</span>':''}</div>
      </div>
      <button class="ti-cancel" \${i.isCancelled||!canCan?'disabled':''} onclick="cancelItem(\${idx})">CANCEL</button>
    </div>\`).join('') : '';
  
  if (order.items && !order.itemstree) {
     document.getElementById('track-items-list').innerHTML = order.items.map((i,idx)=>\`
      <div class="track-item \${i.isCancelled?'cancelled':''}">
        <div class="ti-main">
          <span class="ti-name">\${i.name} × \${i.quantity}</span>
          <div class="ti-meta"><span class="ti-price">₹\${i.price*i.quantity}</span>\${i.isCancelled?'<span class="ti-status">CANCELLED</span>':''}</div>
        </div>
        <button class="ti-cancel" \${i.isCancelled||!canCan?'disabled':''} onclick="cancelItem(\${idx})">CANCEL</button>
      </div>\`).join('');
  } else {
     document.getElementById('track-items-list').innerHTML = itemsHtml;
  }
}

function runTimer() {
  if (!activeOrderId || !currentOrder || currentOrder.status !== 'pending') {
    document.getElementById('cancel-zone').style.display = 'none';
    return;
  }
  
  const diffMs = new Date() - new Date(currentOrder.createdAt);
  const timeLimit = 2 * 60 * 1000;
  const canCan = diffMs < timeLimit;
  
  const cZone = document.getElementById('cancel-zone');
  const cTimer = document.getElementById('cancel-timer');
  
  if (canCan) {
    cZone.style.display = 'block';
    const remaining = Math.max(0, Math.floor((timeLimit - diffMs) / 1000));
    const mins = Math.floor(remaining / 60);
    const secs = remaining % 60;
    cTimer.textContent = "You can cancel for " + mins + ":" + (secs < 10 ? '0' : '') + secs;
  } else {
    cZone.style.display = 'none';
  }
}

async function cancelFullOrder() {
  if (!activeOrderId) return;
  if (!confirm('Are you sure you want to CANCEL this entire order?')) return;
  
  const res = await fetch('/menu/' + activeOrderId + '/cancel', { method: 'PATCH' });
  const data = await res.json();
  if (data.success) {
    alert('Order cancelled successfully.');
    pollOrder();
  } else {
    alert('Could not cancel: ' + (data.error || 'Unknown error'));
  }
}

async function cancelItem(idx) {
  if(!confirm('Are you sure you want to cancel this item from your order?')) return;
  const res = await fetch('/menu/order/'+activeOrderId); const order = await res.json();
  order.items[idx].isCancelled = true;
  await fetch('/menu/'+activeOrderId+'/update', { method:'PATCH',headers:{'Content-Type':'application/json'}, body:JSON.stringify({items:order.items}) });
  pollOrder();
}

setInterval(pollOrder, 5000);
setInterval(runTimer, 1000);
document.getElementById('cat-bar').addEventListener('click', e => {
  const b = e.target.closest('.cat-btn'); if(!b) return;
  document.querySelectorAll('.cat-btn').forEach(x=>x.classList.remove('active'));
  b.classList.add('active'); renderProducts(b.dataset.cat);
});
</script>
</body>
</html>`;
}

function errorPage(msg) {
  return `<!DOCTYPE html><html><body style="background:#0F1117;color:#fff;display:flex;align-items:center;justify-content:center;min-height:100vh;font-family:sans-serif">
    <div style="text-align:center"><h2>${msg}</h2></div></body></html>`;
}
