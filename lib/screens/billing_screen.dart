import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/cart_item.dart';
import '../models/user_role.dart';

import '../widgets/product_section.dart';
import '../widgets/cart_panel.dart';

import '../services/invoice_provider.dart';
import '../services/invoice_service.dart';
import '../services/auth_provider.dart';

import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../providers/billing_provider.dart';
import '../providers/kitchen_provider.dart';
import '../providers/inventory_provider.dart';
import '../providers/category_provider.dart';

import '../utils/responsive_helper.dart';
import 'server_orders_sheet.dart';

enum PaymentMode { cash, online }

// ─── DESIGN CONSTANTS ───────────────────────────────────────────────────────
const Color _kBg = Color(0xFF0F1117);
const Color _kAppBar = Color(0xFF0D1117);
const Color _kCard = Color(0xFF1A2035);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kDivider = Color(0xFF252D45);

class BillingScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final String? tableNo;
  final String? customerName; // 🔥 NEW
  final Map<String, dynamic>? editingBill;
  /// Pre-fill cart items — used when forwarding a web order to billing
  final List<CartItem>? prefillItems;

  const BillingScreen({
    super.key,
    required this.onToggleTheme,
    this.tableNo,
    this.editingBill,
    this.prefillItems,
    this.customerName, // 🔥 NEW
  });

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  String selectedCategory = 'All';
  String searchQuery = '';

  final List<CartItem> cart = [];
  final double gstPercent = 5;
  bool _orderLoaded = false;
  bool _editLoaded = false;
  late OrderProvider _orderProvider; // 🔥 NEW

  PaymentMode? selectedPayment;

  bool get isTakeaway => widget.tableNo == null;

  @override
  void initState() {
    super.initState();
    _orderProvider = context.read<OrderProvider>();
    _orderProvider.addListener(_onOrderUpdate); // 🔥 NEW
    if (isTakeaway) cart.clear();
    // Pre-fill cart from web order forwarding
    if (widget.prefillItems != null && widget.prefillItems!.isNotEmpty) {
      cart.clear();
      // Only add items that are NOT cancelled
      cart.addAll(widget.prefillItems!.where((i) => !i.isCancelled));
      _orderLoaded = true; 
    }

    // 🚀 Refresh products if empty (Auto-fix for empty SQL data issue)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pProvider = context.read<ProductProvider>();
      if (pProvider.products.isEmpty) {
        pProvider.loadProducts();
        context.read<CategoryProvider>().loadCategories();
      }
    });
  }

  @override
  void dispose() {
    _orderProvider.removeListener(_onOrderUpdate); // 🔥 NEW
    super.dispose();
  }

  void _onOrderUpdate() {
    if (widget.tableNo == null || !_orderLoaded) return;
    
    // 🔥 If the remote order for this table was updated (cancellation)
    final remoteOrder = _orderProvider.getOrder(widget.tableNo!);
    if (remoteOrder != null) {
       setState(() {
         cart.clear();
         cart.addAll(remoteOrder.items.where((i) => !i.isCancelled));
       });
    }
  }

  // ========================= CART LOGIC =========================

  void addToCart(Product product) {
    final productProvider = context.read<ProductProvider>();
    final kitchenProvider = context.read<KitchenProvider>();

    final index = cart.indexWhere((c) => c.product.id == product.id);
    final currentInCart = index != -1 ? cart[index].quantity : 0;

    final sessionQty = kitchenProvider.getQty(product.id);
    final effectiveStock = sessionQty < 999
        ? sessionQty
        : (productProvider.getById(product.id)?.quantity ?? 0);

    if (currentInCart + 1 > effectiveStock) {
      _showStockError();
      return;
    }

    setState(() {
      if (index == -1) {
        cart.add(CartItem(product: product, quantity: 1));
      } else {
        cart[index].quantity++;
      }
    });
  }

  void _showStockError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Stock not available'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 1),
      ),
    );
  }

  double get subTotal => cart.fold(0, (s, i) => s + i.total);
  double get gstAmount => subTotal * gstPercent / 100;
  double get grandTotal => subTotal + gstAmount;

  // ========================= ACTIONS =========================

  void _sendToKitchen() {
    if (widget.tableNo == null) return;

    context.read<OrderProvider>().saveOrUpdateOrder(
          widget.tableNo!,
          cart,
          isTakeaway: false,
          customerName: widget.customerName, // 🔥 NEW
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order sent to Kitchen')),
    );

    Navigator.pop(context);
  }

  Future<void> _printAndSendTakeaway() async {
    if (selectedPayment == null) {
      _paymentError();
      return;
    }

    if (!_processStockUpdate()) return;

    context.read<OrderProvider>().saveOrUpdateOrder(
          'TAKEAWAY',
          cart,
          isTakeaway: true,
          customerName: widget.customerName, // 🔥 NEW
        );

    await _saveBill();
    _afterPrint();
  }

  Future<void> _printBill() async {
    if (selectedPayment == null) {
      _paymentError();
      return;
    }

    // Validate Stock first!
    if (widget.editingBill == null) {
      final productProvider = context.read<ProductProvider>();
      for (final item in cart) {
        if (!productProvider.hasEnoughStock(item.product.id, item.quantity)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Stock insufficient!'),
            backgroundColor: Colors.red,
          ));
          return;
        }
      }
    }

    // ── Update Existing Bill ──
    if (widget.editingBill != null) {
      final oldId = widget.editingBill!['id'];
      await InvoiceService.updateBill(oldId, {
        'id': oldId,
        'date': widget.editingBill!['date'],
        'items': cart.map((c) => c.toMap()).toList(),
        'subtotal': subTotal,
        'gst': gstAmount,
        'total': grandTotal,
        'paymentMode': selectedPayment == PaymentMode.cash ? 'CASH' : 'ONLINE',
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bill updated!'), backgroundColor: Colors.blue),
      );
      Navigator.pop(context, true);
      return;
    }

    if (!_processStockUpdate()) return;

    await _saveBill();

    if (mounted) {
      context.read<InvoiceProvider>().loadInvoices();
    }

    if (mounted) {
      final inventoryProvider = context.read<InventoryProvider>();
      for (final cartItem in cart) {
        await inventoryProvider.deductIngredientsForOrder(
          cartItem.product.id,
          cartItem.quantity,
        );
      }
    }

    if (widget.tableNo != null) {
      final orderProvider = context.read<OrderProvider>();
      await orderProvider.closeTable(widget.tableNo!);

      if (mounted) {
        context.read<KitchenProvider>().removeOrderForTable(widget.tableNo!);
      }
    }

    _afterPrint();
  }

  bool _processStockUpdate() {
    final productProvider =
        Provider.of<ProductProvider>(context, listen: false);
    final billingProvider =
        Provider.of<BillingProvider>(context, listen: false);
    final kitchenProvider =
        Provider.of<KitchenProvider>(context, listen: false);

    for (final cartItem in cart) {
      final product = productProvider.getById(cartItem.product.id);
      if (product == null || product.quantity < cartItem.quantity) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${cartItem.product.name} stock insufficient'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }

    for (final cartItem in cart) {
      productProvider.reduceStock(
        productId: cartItem.product.id,
        quantity: cartItem.quantity,
      );

      kitchenProvider.reduceQty(cartItem.product.id, cartItem.quantity);
    }

    billingProvider.syncWithStock(productProvider);
    return true;
  }

  Future<void> _saveBill() async {
    await context.read<InvoiceProvider>().saveBill(
          items: cart
              .map((c) => {
                    'id': c.product.id,
                    'name': c.product.name,
                    'price': c.product.price,
                    'qty': c.quantity,
                    'total': c.total,
                  })
              .toList(),
          subtotal: subTotal,
          gst: gstAmount,
          total: grandTotal,
          paymentMode:
              selectedPayment == PaymentMode.cash ? 'CASH' : 'ONLINE',
        );
  }

  void _afterPrint() {
    setState(() {
      cart.clear();
      selectedPayment = null;
    });

    if (Navigator.canPop(context)) Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bill printed successfully ✓'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _paymentError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Select Cash or Online payment mode'),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ========================= BUILD =========================

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().role;
    final productProvider = context.watch<ProductProvider>();
    context.watch<KitchenProvider>();

    final filteredProducts = productProvider
        .byCategory(selectedCategory)
        .where((p) =>
            p.name.toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    if (widget.editingBill != null && !_editLoaded) {
      final oldItems = widget.editingBill!['items'];
      if (oldItems is List) {
        cart.clear();
        for (var map in oldItems) {
          cart.add(CartItem.fromMap(map));
        }
      }
      final modeStr = widget.editingBill!['paymentMode'].toString().toLowerCase();
      if (modeStr.contains('online')) {
        selectedPayment = PaymentMode.online;
      } else {
        selectedPayment = PaymentMode.cash;
      }
      _editLoaded = true;
    }

    if (!isTakeaway && !_orderLoaded && widget.editingBill == null) {
      final order =
          context.read<OrderProvider>().getOrder(widget.tableNo!);
      if (order != null) {
        cart.clear();
        cart.addAll(order.items);
      }
      _orderLoaded = true;
    }

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(context, role),
      floatingActionButton: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth >= 900) return const SizedBox.shrink();
          return Stack(
            clipBehavior: Clip.none,
            children: [
              FloatingActionButton(
                heroTag: 'fab_billing_cart',
                backgroundColor: _kOrange,
                mini: true,
                onPressed: _openMobileCart,
                child: const Icon(Icons.shopping_cart_rounded,
                    color: Colors.white, size: 20),
              ),
              if (cart.isNotEmpty)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${cart.length}',
                        style: const TextStyle(
                          color: _kOrange,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      body: LayoutBuilder(
        builder: (context, c) {
          final isMobile = c.maxWidth < 900;

          final productWidget = ProductSection(
            selectedCategory: selectedCategory,
            onCategorySelected: (cat) =>
                setState(() => selectedCategory = cat),
            products: filteredProducts,
            onProductTap: addToCart,
            onSearch: (q) => setState(() => searchQuery = q),
            tableNo: widget.tableNo,
            isTakeaway: isTakeaway,
          );

          if (isMobile) return productWidget;

          return Row(
            children: [
              Expanded(flex: 7, child: productWidget),
              Container(
                width: 1,
                color: _kDivider,
              ),
              SizedBox(
                width: 340,
                child: Column(
                  children: [
                    if (role != UserRole.server) _paymentToggle(),
                    Expanded(
                      child: CartPanel(
                        cart: cart,
                        subTotal: subTotal,
                        gstAmount: gstAmount,
                        grandTotal: grandTotal,
                        onQtyChange: (cartItem, d) {
                          if (d > 0) {
                            final kitchenProvider = context.read<KitchenProvider>();
                            final sessionQty = kitchenProvider.getQty(cartItem.product.id);
                            final effectiveStock = sessionQty < 999
                                ? sessionQty
                                : (productProvider.getById(cartItem.product.id)?.quantity ?? 0);

                            if (cartItem.quantity + 1 > effectiveStock) {
                              _showStockError();
                              return;
                            }
                            setState(() => cartItem.quantity += d);
                          } else {
                            setState(() {
                              cartItem.quantity += d;
                              if (cartItem.quantity <= 0) {
                                cart.remove(cartItem);
                              }
                            });
                          }
                        },
                        onClear: () => setState(() => cart.clear()),
                        onPrint: role == UserRole.server
                            ? _sendToKitchen
                            : (isTakeaway
                                ? _printAndSendTakeaway
                                : _printBill),
                        actionLabel: isTakeaway ? 'PRINT BILL' : 'SAVE BILL',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, UserRole? role) {
    var sessionLabel = isTakeaway
        ? 'TAKEAWAY'
        : (ResponsiveHelper.isMobile(context) ? 'TBL ${widget.tableNo}' : 'BILLING – TABLE ${widget.tableNo}');
    
    if (widget.editingBill != null) {
      sessionLabel = 'EDITING BILL #${widget.editingBill!['id']}';
    }

    return AppBar(
      backgroundColor: _kAppBar,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // FlavorFlow brand
          if (!ResponsiveHelper.isMobile(context))
            Text(
              'FlavorFlow',
              style: TextStyle(
                color: _kOrange,
                fontWeight: FontWeight.w900,
                fontSize: 18,
                letterSpacing: 0.3,
              ),
            )
          else 
            Icon(Icons.restaurant_rounded, color: _kOrange, size: 20),
        ],
      ),
      actions: [
        // ── Billing mode indicator ──
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2035),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF252D45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _kOrange,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                sessionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),

        // Receipt log for admin/staff takeaway
        if (role != UserRole.server && isTakeaway)
          IconButton(
            tooltip: 'Orders',
            icon: const Icon(Icons.receipt_long_outlined,
                color: Colors.white54),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: _kCard,
                shape: const RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => const ServerOrdersSheet(),
              );
            },
          ),

        // Bell
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined,
              color: Colors.white38, size: 22),
          onPressed: () {},
        ),

        // Settings
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined,
              color: Colors.white38, size: 22),
          onPressed: widget.onToggleTheme,
        ),

        // Logout / back
        IconButton(
          tooltip: 'Exit',
          icon: const Icon(Icons.exit_to_app_rounded,
              color: Colors.white54, size: 22),
          onPressed: () {
            final auth = context.read<AuthProvider>();
            if (widget.editingBill != null) {
              Navigator.pop(context, false);
              return;
            }
            if (auth.role == UserRole.staff ||
                auth.role == UserRole.server) {
              if (widget.tableNo != null) {
                Navigator.pop(context);
                return;
              }
            }
            auth.logout();
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── PAYMENT TOGGLE (Desktop panel header / Mobile sheet header) ───
  Widget _paymentToggle([StateSetter? sheetState]) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      color: _kCard,
      child: Row(
        children: [
          _paymentChip(
            label: 'CASH',
            icon: Icons.payments_rounded,
            active: selectedPayment == PaymentMode.cash,
            activeColor: const Color(0xFF1B5E20),
            activeBorder: const Color(0xFF2E7D32),
            onTap: () {
              setState(() => selectedPayment = PaymentMode.cash);
              if (sheetState != null) sheetState(() {});
            },
          ),
          const SizedBox(width: 10),
          _paymentChip(
            label: 'ONLINE',
            icon: Icons.qr_code_scanner_rounded,
            active: selectedPayment == PaymentMode.online,
            activeColor: const Color(0xFF0D47A1),
            activeBorder: const Color(0xFF1565C0),
            onTap: () {
              setState(() => selectedPayment = PaymentMode.online);
              if (sheetState != null) sheetState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _paymentChip({
    required String label,
    required IconData icon,
    required bool active,
    required Color activeColor,
    required Color activeBorder,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 44,
          decoration: BoxDecoration(
            color: active ? activeColor : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active ? activeBorder : Colors.white12,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color: active ? Colors.white : Colors.white38, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── MOBILE CART BOTTOM SHEET ───
  void _openMobileCart() {
    final role = context.read<AuthProvider>().role;
    final productProvider = context.read<ProductProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: _kBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Column(
            children: [
              // Modal handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              if (role != UserRole.server) _paymentToggle(setSheetState),
              Expanded(
                child: CartPanel(
                  cart: cart,
                  subTotal: subTotal,
                  gstAmount: gstAmount,
                  grandTotal: grandTotal,
                  customerName: widget.customerName,
                  tableNo: widget.tableNo,
                  onQtyChange: (cartItem, d) {
                    if (d > 0) {
                      final kitchenProvider = context.read<KitchenProvider>();
                      final sessionQty = kitchenProvider.getQty(cartItem.product.id);
                      final effectiveStock = sessionQty < 999
                          ? sessionQty
                          : (productProvider.getById(cartItem.product.id)?.quantity ?? 0);

                      if (cartItem.quantity + 1 > effectiveStock) {
                        _showStockError();
                        return;
                      }
                      
                      setState(() => cartItem.quantity += d);
                      setSheetState(() {});
                    } else {
                      setState(() {
                        cartItem.quantity += d;
                        if (cartItem.quantity <= 0) cart.remove(cartItem);
                      });
                      setSheetState(() {});
                    }
                  },
                  onClear: () {
                    setState(() => cart.clear());
                    Navigator.pop(context);
                  },
                  onPrint: role == UserRole.server
                      ? _sendToKitchen
                      : (isTakeaway ? _printAndSendTakeaway : _printBill),
                  actionLabel: isTakeaway ? 'PRINT BILL' : 'SAVE BILL',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
