import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../services/api_service.dart';

// ─── DESIGN TOKENS ──────────────────────────────────────────────────────────
const Color _bg      = Color(0xFF0F1117);
const Color _appBar  = Color(0xFF0D1117);
const Color _card    = Color(0xFF1A2035);
const Color _cardAlt = Color(0xFF141825);
const Color _orange  = Color(0xFFFF6A00);
const Color _div     = Color(0xFF252D45);
const Color _green   = Color(0xFF00C853);
const Color _red     = Color(0xFFEF5350);
const Color _textSub = Color(0xFF8A94B2);

// ─── CART ITEM ────────────────────────────────────────────────────────────
class _Item {
  final Product product;
  int qty;
  _Item(this.product, this.qty);
  double get total  => product.price * qty;
  Map<String, dynamic> toOrderMap() => {
        'productId': product.id,
        'name':      product.name,
        'price':     product.price,
        'quantity':  qty,
      };
}

// ─── SCREEN STATES ───────────────────────────────────────────────────────
enum _Stage { info, menu, tracking }

// ─── SCREEN ──────────────────────────────────────────────────────────────
class CustomerOrderScreen extends StatefulWidget {
  final String tableNo;
  const CustomerOrderScreen({super.key, required this.tableNo});

  @override
  State<CustomerOrderScreen> createState() => _CustomerOrderScreenState();
}

class _CustomerOrderScreenState extends State<CustomerOrderScreen> {
  // ── stage ─────────────────────────────────────────────────────────────
  _Stage _stage = _Stage.info;

  // ── customer info ──────────────────────────────────────────────────────
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // ── menu / cart ────────────────────────────────────────────────────────
  List<Product> _products   = [];
  List<String>  _categories = [];
  String        _selCat     = 'All';
  String        _search     = '';
  final List<_Item>  _cart  = [];
  final _searchCtrl         = TextEditingController();
  final _noteCtrl           = TextEditingController();
  String  _note             = '';
  bool    _loadingProducts  = true;

  // ── order tracking ─────────────────────────────────────────────────────
  int     _orderId          = -1;
  bool    _placing          = false;
  bool    _cancelling       = false;
  bool    _cancelled        = false;
  bool    _editMode         = false;
  DateTime? _orderPlacedAt;
  Timer?  _countdownTimer;
  int     _secondsLeft      = 300;           // 5 minutes

  // ── lifecycle ──────────────────────────────────────────────────────────
  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _searchCtrl.dispose();
    _noteCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await ApiService.getPublicProducts();
    final cats = <String>['All'];
    for (final p in products) {
      if (p.category.isNotEmpty && !cats.contains(p.category)) {
        cats.add(p.category);
      }
    }
    if (!mounted) return;
    setState(() {
      _products   = products.where((p) => p.isAvailable).toList();
      _categories = cats;
      _loadingProducts = false;
    });
  }

  // ── helpers ────────────────────────────────────────────────────────────
  List<Product> get _filtered => _products.where((p) {
        final catOk  = _selCat == 'All' || p.category == _selCat;
        final q      = _search.toLowerCase();
        final nameOk = q.isEmpty || p.name.toLowerCase().contains(q);
        return catOk && nameOk;
      }).toList();

  double get _subTotal => _cart.fold(0.0, (s, i) => s + i.total);
  double get _gst      => _subTotal * 0.05;
  double get _grand    => _subTotal + _gst;
  int    get _count    => _cart.fold(0, (s, i) => s + i.qty);

  void _addToCart(Product p) {
    final idx = _cart.indexWhere((i) => i.product.id == p.id);
    setState(() {
      if (idx == -1) _cart.add(_Item(p, 1));
      else _cart[idx].qty++;
    });
  }

  void _changeQty(_Item item, int delta) {
    setState(() {
      item.qty += delta;
      if (item.qty <= 0) _cart.remove(item);
    });
  }

  int _cartQty(String productId) =>
      _cart.where((i) => i.product.id == productId).fold(0, (s, i) => s + i.qty);

  // ── Step 1: submit info form ──────────────────────────────────────────
  void _onInfoSubmit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _stage = _Stage.menu;
      _loadingProducts = true;
    });
    _loadProducts();
  }

  // ── Step 2: place order ──────────────────────────────────────────────
  Future<void> _placeOrder() async {
    if (_cart.isEmpty) return;
    setState(() => _placing = true);

    final id = await ApiService.placeCustomerOrder(
      tableNo:       widget.tableNo,
      customerName:  _nameCtrl.text.trim(),
      customerPhone: _phoneCtrl.text.trim(),
      items:         _cart.map((i) => i.toOrderMap()).toList(),
      note:          _note,
    );

    if (!mounted) return;
    if (id > 0) {
      _orderId       = id;
      _orderPlacedAt = DateTime.now();
      _secondsLeft   = 300;
      _startCountdown();
      setState(() {
        _stage   = _Stage.tracking;
        _placing = false;
      });
    } else {
      setState(() => _placing = false);
      _showSnack('Order failed. Please try again.', isError: true);
    }
  }

  // ── Step 3: countdown timer ───────────────────────────────────────────
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          _secondsLeft = 0;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  bool get _canCancel => _secondsLeft > 0 && !_cancelled;
  String get _countdownLabel {
    final m = _secondsLeft ~/ 60;
    final s = _secondsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── cancel order ─────────────────────────────────────────────────────
  Future<void> _cancelOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Order?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Your order will be cancelled.',
            style: TextStyle(color: _textSub)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO', style: TextStyle(color: _textSub)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES, CANCEL',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _cancelling = true);
    final ok = await ApiService.cancelCustomerOrder(_orderId);
    if (!mounted) return;
    setState(() {
      _cancelling = false;
      if (ok) {
        _cancelled = true;
        _countdownTimer?.cancel();
      }
    });
    if (ok) {
      _showSnack('Order cancelled successfully.');
    } else {
      _showSnack('Could not cancel. Please ask staff.', isError: true);
    }
  }

  // ── save edit ─────────────────────────────────────────────────────────
  Future<void> _saveEdit() async {
    setState(() => _placing = true);
    final ok = await ApiService.updateCustomerOrder(
      id:    _orderId,
      items: _cart.map((i) => i.toOrderMap()).toList(),
      note:  _note,
    );
    if (!mounted) return;
    setState(() {
      _placing  = false;
      _editMode = false;
    });
    _showSnack(ok ? 'Order updated!' : 'Update failed.', isError: !ok);
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? _red : _green,
      duration: const Duration(seconds: 3),
    ));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: switch (_stage) {
          _Stage.info     => _infoPage(),
          _Stage.menu     => _menuPage(),
          _Stage.tracking => _trackingPage(),
        },
      ),
    );
  }

  // ─── AppBar ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _appBar,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: _orange, borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.restaurant_rounded,
              color: Colors.white, size: 18),
        ),
        const SizedBox(width: 10),
        const Text('FlavorFlow',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 17)),
      ]),
      actions: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _div),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                    color: _orange, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Text(
              'TABLE ${widget.tableNo}',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.4),
            ),
          ]),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STAGE 1 — Customer Info Form
  // ════════════════════════════════════════════════════════════════════
  Widget _infoPage() {
    return Center(
      key: const ValueKey('info'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome block
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _orange.withOpacity(0.18),
                        _orange.withOpacity(0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border:
                        Border.all(color: _orange.withOpacity(0.25)),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: _orange,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.restaurant_menu_rounded,
                            color: Colors.white, size: 30),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Welcome!',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Table ${widget.tableNo}  •  Please enter your details to start ordering',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: _textSub, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Name field
                _label('Your Name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  textCapitalization: TextCapitalization.words,
                  decoration: _inputDeco(
                      hint: 'e.g. Bharath',
                      icon: Icons.person_rounded),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Please enter your name'
                          : null,
                ),

                const SizedBox(height: 20),

                // Phone field
                _label('Phone Number'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: _inputDeco(
                      hint: '10-digit mobile number',
                      icon: Icons.phone_rounded),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter phone number';
                    }
                    if (v.length < 10) return 'Enter 10-digit number';
                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _onInfoSubmit,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('VIEW MENU',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: 0.6)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
          fontWeight: FontWeight.w600));

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38, size: 20),
      filled: true,
      fillColor: _card,
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _orange, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.5),
      ),
      errorStyle:
          const TextStyle(color: _red, fontSize: 11),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STAGE 2 — Menu + Cart
  // ════════════════════════════════════════════════════════════════════
  Widget _menuPage() {
    return Stack(
      key: const ValueKey('menu'),
      children: [
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth >= 900) {
            return Row(children: [
              Expanded(flex: 7, child: _menuSection()),
              Container(width: 1, color: _div),
              SizedBox(width: 340, child: _cartSidePanel()),
            ]);
          }
          return _menuSection();
        }),
        // Mobile FAB
        LayoutBuilder(builder: (ctx, c) {
          if (c.maxWidth >= 900) return const SizedBox.shrink();
          return Positioned(
            right: 16,
            bottom: 20,
            child: _cartFab(),
          );
        }),
      ],
    );
  }

  // ── Product grid section ──────────────────────────────────────────
  Widget _menuSection() {
    return Column(children: [
      // Search
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        color: _bg,
        child: TextField(
          controller: _searchCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Search dishes…',
            hintStyle: const TextStyle(color: Colors.white24),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Colors.white38, size: 20),
            suffixIcon: _search.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white38, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _search = '');
                    },
                  )
                : null,
            filled: true,
            fillColor: _card,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
      ),
      // Category tabs
      SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _categories.length,
          itemBuilder: (_, i) {
            final cat    = _categories[i];
            final active = cat == _selCat;
            return GestureDetector(
              onTap: () => setState(() => _selCat = cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.symmetric(
                    horizontal: 4, vertical: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: active
                      ? _orange
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                ),
                alignment: Alignment.center,
                child: Text(cat,
                    style: TextStyle(
                        color: active ? Colors.white : Colors.white54,
                        fontSize: 12,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
            );
          },
        ),
      ),
      // Grid
      Expanded(
        child: _loadingProducts
            ? const Center(
                child: CircularProgressIndicator(color: _orange))
            : _filtered.isEmpty
                ? const Center(
                    child: Text('No items found',
                        style: TextStyle(
                            color: Colors.white24, fontSize: 14)))
                : GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _cols(
                          MediaQuery.of(context).size.width),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) => _ProductCard(
                      product:  _filtered[i],
                      cartQty:  _cartQty(_filtered[i].id),
                      onAdd:    () => _addToCart(_filtered[i]),
                      onRemove: () {
                        final idx = _cart.indexWhere(
                            (c) => c.product.id == _filtered[i].id);
                        if (idx != -1) _changeQty(_cart[idx], -1);
                      },
                    ),
                  ),
      ),
    ]);
  }

  int _cols(double w) {
    if (w >= 1100) return 4;
    if (w >= 750)  return 3;
    return 2;
  }

  // ── Cart side panel (desktop) ─────────────────────────────────────
  Widget _cartSidePanel() {
    return Column(children: [
      // Header
      Container(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        color: _cardAlt,
        child: Row(children: [
          const Icon(Icons.receipt_long_rounded,
              color: _orange, size: 20),
          const SizedBox(width: 10),
          const Text('Your Order',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15)),
          const Spacer(),
          if (_cart.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _cart.clear()),
              child: const Text('Clear',
                  style: TextStyle(
                      color: _textSub,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                      decorationColor: _textSub)),
            ),
        ]),
      ),
      Expanded(child: _cartBody()),
      if (_cart.isNotEmpty) ...[
        _noteField(),
        _billSummaryWidget(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
          child: _placeOrderButton(),
        ),
      ],
    ]);
  }

  Widget _cartBody() {
    if (_cart.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.shopping_cart_outlined,
              color: Colors.white12, size: 52),
          const SizedBox(height: 12),
          const Text('Your cart is empty',
              style: TextStyle(color: Colors.white24, fontSize: 14)),
          const SizedBox(height: 4),
          const Text('Tap a dish to add',
              style: TextStyle(color: Colors.white12, fontSize: 12)),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const Divider(color: _div, height: 14),
      itemBuilder: (_, i) => _CartRow(
        item: _cart[i],
        onInc: () => _changeQty(_cart[i], 1),
        onDec: () => _changeQty(_cart[i], -1),
      ),
    );
  }

  Widget _noteField() => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: TextField(
          controller: _noteCtrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Add a note (optional)…',
            hintStyle:
                const TextStyle(color: Colors.white24, fontSize: 12),
            prefixIcon: const Icon(Icons.edit_note_rounded,
                color: Colors.white24, size: 18),
            filled: true,
            fillColor: _card,
            contentPadding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
          ),
          onChanged: (v) => _note = v,
        ),
      );

  Widget _billSummaryWidget() => Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(children: [
          _sumRow('Subtotal', _subTotal),
          const SizedBox(height: 6),
          _sumRow('GST (5%)', _gst),
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: _div, height: 1)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              Text('₹${_grand.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w900,
                      fontSize: 20)),
            ],
          ),
        ]),
      );

  Widget _sumRow(String label, double val) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(color: _textSub, fontSize: 12)),
          Text('₹${val.toStringAsFixed(0)}',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 12)),
        ],
      );

  Widget _placeOrderButton() => SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _orange,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _placing ? null : _placeOrder,
          child: _placing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text('PLACE ORDER',
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 0.5)),
                  ],
                ),
        ),
      );

  // ── Cart FAB (mobile) ─────────────────────────────────────────────
  Widget _cartFab() {
    return Stack(clipBehavior: Clip.none, children: [
      FloatingActionButton(
        heroTag: 'fab_cust',
        backgroundColor: _orange,
        onPressed: _openCartSheet,
        child: const Icon(Icons.shopping_cart_rounded,
            color: Colors.white),
      ),
      if (_count > 0)
        Positioned(
          right: -4,
          top: -4,
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
            child: Center(
              child: Text('$_count',
                  style: const TextStyle(
                      color: _orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w900)),
            ),
          ),
        ),
    ]);
  }

  void _openCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _bg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
              child: Row(children: [
                const Icon(Icons.receipt_long_rounded,
                    color: _orange, size: 20),
                const SizedBox(width: 10),
                const Text('Your Order',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const Spacer(),
                if (_cart.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => _cart.clear());
                      setSheet(() {});
                      Navigator.pop(ctx);
                    },
                    child: const Text('Clear all',
                        style: TextStyle(
                            color: _textSub, fontSize: 12)),
                  ),
              ]),
            ),
            const Divider(color: _div, height: 1),
            // Items
            if (_cart.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                          color: Colors.white12, size: 52),
                      const SizedBox(height: 12),
                      const Text('Cart is empty',
                          style: TextStyle(
                              color: Colors.white24, fontSize: 14)),
                    ],
                  ),
                ),
              )
            else ...[
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 10),
                  itemCount: _cart.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: _div, height: 14),
                  itemBuilder: (_, i) => _CartRow(
                    item: _cart[i],
                    onInc: () {
                      _changeQty(_cart[i], 1);
                      setSheet(() {});
                    },
                    onDec: () {
                      _changeQty(_cart[i], -1);
                      setSheet(() {});
                    },
                  ),
                ),
              ),
              // Note
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _noteCtrl,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Add a note (optional)…',
                    hintStyle: const TextStyle(
                        color: Colors.white24, fontSize: 12),
                    filled: true, fillColor: _card,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none),
                  ),
                  onChanged: (v) => _note = v,
                ),
              ),
              // Summary
              _billSummaryWidget(),
              // Place order
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _orange,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    onPressed: _placing
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _placeOrder();
                          },
                    child: _placing
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5))
                        : const Text('PLACE ORDER',
                            style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.5)),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  // STAGE 3 — Order Tracking
  // ════════════════════════════════════════════════════════════════════
  Widget _trackingPage() {
    return SingleChildScrollView(
      key: const ValueKey('tracking'),
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(children: [
            const SizedBox(height: 16),

            // ── Status card ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: _cancelled
                        ? _red.withOpacity(0.4)
                        : _green.withOpacity(0.4)),
              ),
              child: Column(children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: (_cancelled ? _red : _green)
                        .withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: (_cancelled ? _red : _green)
                            .withOpacity(0.4),
                        width: 2),
                  ),
                  child: Icon(
                    _cancelled
                        ? Icons.cancel_rounded
                        : Icons.check_rounded,
                    color: _cancelled ? _red : _green,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _cancelled ? 'Order Cancelled' : 'Order Placed!',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  _cancelled
                      ? 'Your order has been cancelled.'
                      : 'Table ${widget.tableNo}  •  Being prepared 🍳',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _textSub, fontSize: 13),
                ),
                if (!_cancelled) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.access_time_rounded,
                          color: _textSub, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        _canCancel
                            ? 'Cancel window closes in $_countdownLabel'
                            : 'Cancel window closed',
                        style: TextStyle(
                            color: _canCancel ? _orange : _textSub,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ]),
            ),

            const SizedBox(height: 20),

            // ── Order items ──────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Text('Order Summary',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const Spacer(),
                    if (_editMode)
                      TextButton(
                        onPressed: () =>
                            setState(() => _editMode = false),
                        child: const Text('Discard',
                            style: TextStyle(
                                color: _textSub, fontSize: 12)),
                      ),
                  ]),
                  const SizedBox(height: 12),
                  // items
                  ..._cart.asMap().entries.map((e) {
                    final item = e.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                  '₹${item.product.price.toStringAsFixed(0)} each',
                                  style: const TextStyle(
                                      color: _textSub,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        // qty controls (only in edit mode + not cancelled)
                        if (_editMode && !_cancelled && _canCancel) ...[
                          _qBtn(Icons.remove_rounded,
                              () => _changeQty(item, -1)),
                          SizedBox(
                            width: 30,
                            child: Text('${item.qty}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14)),
                          ),
                          _qBtn(Icons.add_rounded,
                              () => _changeQty(item, 1)),
                        ] else ...[
                          Text('× ${item.qty}',
                              style: const TextStyle(
                                  color: _textSub, fontSize: 13)),
                        ],
                        const SizedBox(width: 12),
                        Text('₹${item.total.toStringAsFixed(0)}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ]),
                    );
                  }),
                  const Divider(color: _div, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14)),
                      Text('₹${_grand.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: _orange,
                              fontWeight: FontWeight.w900,
                              fontSize: 18)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Action buttons ──────────────────────────────────────
            if (!_cancelled) ...[
              const SizedBox(height: 20),

              if (_canCancel) ...[
                if (_editMode) ...[
                  // Save edit button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save_rounded, size: 18),
                      label: const Text('SAVE CHANGES',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 0.4)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _placing ? null : _saveEdit,
                    ),
                  ),
                ] else ...[
                  // Edit + Cancel buttons
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('EDIT ORDER',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(
                              color: Colors.white24),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        onPressed: () =>
                            setState(() => _editMode = true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: _cancelling
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2))
                            : const Icon(Icons.cancel_rounded,
                                size: 16),
                        label: const Text('CANCEL',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12)),
                        ),
                        onPressed:
                            _cancelling ? null : _cancelOrder,
                      ),
                    ),
                  ]),
                ],
              ],

              const SizedBox(height: 12),
            ],

            // Order more
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                    _cancelled ? 'ORDER AGAIN' : 'ADD MORE ITEMS',
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.4)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _cancelled ? _orange : _card,
                  foregroundColor:
                      _cancelled ? Colors.white : Colors.white70,
                  elevation: 0,
                  side: _cancelled
                      ? null
                      : const BorderSide(color: _div),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  _countdownTimer?.cancel();
                  setState(() {
                    _stage     = _Stage.menu;
                    _cancelled = false;
                    _editMode  = false;
                    if (_cancelled) _cart.clear();
                  });
                },
              ),
            ),
            const SizedBox(height: 32),
          ]),
        ),
      ),
    );
  }

  Widget _qBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white54, size: 15),
        ),
      );
}

// ─── Product Card ────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final int cartQty;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _ProductCard({
    required this.product,
    required this.cartQty,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final inCart = cartQty > 0;
    return GestureDetector(
      onTap: onAdd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: inCart
                ? _orange.withOpacity(0.55)
                : Colors.white.withOpacity(0.05),
            width: inCart ? 1.5 : 1,
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Image
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(13)),
              child: _smartImage(product.image),
            ),
          ),
          // Info
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.3),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '₹${product.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: _orange,
                          fontWeight: FontWeight.w900,
                          fontSize: 14),
                    ),
                    // qty badge / add button
                    if (inCart)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            width: 24, height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.remove_rounded,
                                color: Colors.white54, size: 14),
                          ),
                        ),
                        SizedBox(
                          width: 24,
                          child: Text('$cartQty',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                        ),
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(
                            color: _orange,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ])
                    else
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: _orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                              color: _orange.withOpacity(0.4)),
                        ),
                        child: const Icon(Icons.add_rounded,
                            color: _orange, size: 16),
                      ),
                  ],
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: const Color(0xFF1E2235),
        child: const Center(
          child: Icon(Icons.fastfood_rounded,
              color: Colors.white12, size: 36),
        ),
      );

  /// Smart image loader — handles network URLs, local assets, and
  /// "default" / missing paths from the backend without 404 errors.
  Widget _smartImage(String path) {
    if (path.isEmpty || path.contains('default') || path == 'null') {
      return _placeholder();
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    // Local asset path
    return Image.asset(
      path,
      fit: BoxFit.cover,
      width: double.infinity,
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}

// ─── Cart Row ────────────────────────────────────────────────────────────
class _CartRow extends StatelessWidget {
  final _Item item;
  final VoidCallback onInc;
  final VoidCallback onDec;
  const _CartRow(
      {required this.item, required this.onInc, required this.onDec});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.product.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text('₹${item.product.price.toStringAsFixed(0)} each',
              style: const TextStyle(color: _textSub, fontSize: 11)),
        ]),
      ),
      _qBtn(Icons.remove_rounded, onDec),
      SizedBox(
        width: 30,
        child: Text('${item.qty}',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ),
      _qBtn(Icons.add_rounded, onInc),
      const SizedBox(width: 8),
      SizedBox(
        width: 54,
        child: Text('₹${item.total.toStringAsFixed(0)}',
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    ]);
  }

  Widget _qBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: Colors.white54, size: 15),
        ),
      );
}
