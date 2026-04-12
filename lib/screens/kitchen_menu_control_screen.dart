import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/responsive_helper.dart';

import '../providers/product_provider.dart';
import '../providers/kitchen_provider.dart';
import '../providers/billing_provider.dart';
import '../models/kitchen_item_status.dart';
import '../models/product.dart';

// ─── DESIGN TOKENS ──────────────────────────────────────────────────────────
const Color _kBg = Color(0xFF141414);
const Color _kSidebar = Color(0xFF0F0F0F);
const Color _kCard = Color(0xFF1E1E1E);
const Color _kCardBorder = Color(0xFF2C2C2C);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kDivider = Color(0xFF252525);

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class KitchenMenuControlScreen extends StatefulWidget {
  const KitchenMenuControlScreen({super.key});

  @override
  State<KitchenMenuControlScreen> createState() =>
      _KitchenMenuControlScreenState();
}

class _KitchenMenuControlScreenState
    extends State<KitchenMenuControlScreen> {
  @override
  void initState() {
    super.initState();
    // 🚀 INITIALIZE KITCHEN STOCK from database values on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final products = context.read<ProductProvider>().products;
      if (products.isNotEmpty) {
        context.read<KitchenProvider>().initFromProducts(products);
      }
    });
  }

  String _selectedCategory = 'All';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductProvider>().products;
    final kitchen = context.watch<KitchenProvider>();

    // ── Category data ──
    final categories = [
      'All',
      ...{...products.map((p) => p.category)},
    ];
    final Map<String, int> catCounts = {};
    for (final p in products) {
      catCounts[p.category] = (catCounts[p.category] ?? 0) + 1;
    }

    // ── Filter products ──
    final filtered = products.where((p) {
      final matchCat =
          _selectedCategory == 'All' || p.category == _selectedCategory;
      final matchQ = p.name
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());
      return matchCat && matchQ;
    }).toList();

    // ── Critical stock count ──
    final criticalCount = products
        .where((p) {
          final qty = kitchen.getQty(p.id);
          return qty < 999 && qty < 5;
        })
        .length;

    final bool isMobile = ResponsiveHelper.isMobile(context);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            children: [
              // ─── TOP BAR ───
              _TopBar(
                searchQuery: _searchQuery,
                onSearch: (v) => setState(() => _searchQuery = v),
              ),
              Expanded(
                child: Row(
                  children: [
                    // ─── LEFT SIDEBAR (desktop only) ───
                    if (!isMobile) const _LeftSidebar(),

                    // ─── MAIN CONTENT ───
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Content header
                          _ContentHeader(kitchen: kitchen, products: products),
                          const Divider(color: _kDivider, height: 1),

                          // Mobile category filter row
                          if (isMobile)
                            _CategoryChipsMobile(
                              categories: categories,
                              selected: _selectedCategory,
                              counts: catCounts,
                              onSelect: (c) => setState(() => _selectedCategory = c),
                            ),

                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category panel
                                if (!isMobile)
                                  _CategoryPanel(
                                    categories: categories,
                                    selected: _selectedCategory,
                                    counts: catCounts,
                                    criticalCount: criticalCount,
                                    onSelect: (c) =>
                                        setState(() => _selectedCategory = c),
                                  ),

                                // Product grid
                                Expanded(
                                  child: filtered.isEmpty
                                      ? const _EmptyState()
                                      : GridView.builder(
                                          padding: const EdgeInsets.all(16),
                                          gridDelegate:
                                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                            maxCrossAxisExtent: 360,
                                            crossAxisSpacing: 14,
                                            mainAxisSpacing: 14,
                                            mainAxisExtent: 200,
                                          ),
                                          itemCount: filtered.length,
                                          itemBuilder: (context, index) {
                                            final p = filtered[index];
                                            final live = context
                                                    .watch<ProductProvider>()
                                                    .getById(p.id) ??
                                                p;
                                            return _ProductCard(
                                              product: live,
                                              kitchen: kitchen,
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TOP BAR
// ═══════════════════════════════════════════════════════════════════════════════
class _TopBar extends StatelessWidget {
  final String searchQuery;
  final ValueChanged<String> onSearch;
  const _TopBar({required this.searchQuery, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      color: _kSidebar,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Brand
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _kOrange,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.restaurant_rounded,
                    color: Colors.white, size: 15),
              ),
              const SizedBox(width: 8),
              const Text(
                'FlavorFlow KMS',
                style: TextStyle(
                  color: _kOrange,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),

          const Spacer(),

          // Search
          Container(
            width: MediaQuery.of(context).size.width < 450 ? 160 : 220,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kDivider),
            ),
            child: TextField(
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
              decoration: const InputDecoration(
                hintText: 'Search items...',
                hintStyle:
                    TextStyle(color: Colors.white30, fontSize: 12.5),
                prefixIcon: Icon(Icons.search_rounded,
                    color: Colors.white30, size: 16),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          // Back button
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded,
                color: Colors.white54, size: 20),
            tooltip: 'Back to Orders',
            onPressed: () => Navigator.maybePop(context),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  LEFT SIDEBAR
// ═══════════════════════════════════════════════════════════════════════════════
class _LeftSidebar extends StatelessWidget {
  const _LeftSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      color: _kSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Station info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _kOrange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.restaurant_rounded,
                      color: _kOrange, size: 18),
                ),
                const SizedBox(width: 10),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Main Kitchen',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Dinner Service',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(color: _kDivider, height: 1),
          const Spacer(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CONTENT HEADER  (title + session toggle)
// ═══════════════════════════════════════════════════════════════════════════════
class _ContentHeader extends StatelessWidget {
  final KitchenProvider kitchen;
  final List<Product> products;
  const _ContentHeader(
      {required this.kitchen, required this.products});

  void _switchSession(BuildContext context, KitchenSession session) {
    kitchen.setSession(session);
    final productProvider = context.read<ProductProvider>();
    final sessionQtys = kitchen.getAllQtysForSession(session);
    for (final p in products) {
      if (sessionQtys.containsKey(p.id)) {
        productProvider.setStock(
            productId: p.id, quantity: sessionQtys[p.id]!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Inventory Control',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Manage stock levels and item availability across service blocks.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.38),
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 16),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kDivider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _sessionBtn(context, 'Morning', KitchenSession.morning),
                        _sessionBtn(context, 'Afternoon', KitchenSession.afternoon),
                        _sessionBtn(context, 'Evening', KitchenSession.evening),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inventory Control',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Manage stock levels and item availability across service blocks.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.38),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                // Session toggle
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _kDivider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _sessionBtn(
                          context, 'Morning', KitchenSession.morning),
                      _sessionBtn(
                          context, 'Afternoon', KitchenSession.afternoon),
                      _sessionBtn(
                          context, 'Evening', KitchenSession.evening),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _sessionBtn(
      BuildContext context, String label, KitchenSession session) {
    final active = kitchen.currentSession == session;
    return GestureDetector(
      onTap: () => _switchSession(context, session),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white38,
            fontWeight:
                active ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CATEGORY PANEL
// ═══════════════════════════════════════════════════════════════════════════════
class _CategoryPanel extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final Map<String, int> counts;
  final int criticalCount;
  final ValueChanged<String> onSelect;

  const _CategoryPanel({
    required this.categories,
    required this.selected,
    required this.counts,
    required this.criticalCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: const Color(0xFF111111),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
            child: Text(
              'CATEGORIES',
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),

          // Category list
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              children: categories.map((cat) {
                final active = selected == cat;
                final count = cat == 'All'
                    ? counts.values.fold(0, (a, b) => a + b)
                    : (counts[cat] ?? 0);

                return GestureDetector(
                  onTap: () => onSelect(cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(bottom: 3),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: active
                          ? _kOrange.withOpacity(0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active
                            ? _kOrange.withOpacity(0.3)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat,
                            style: TextStyle(
                              color:
                                  active ? Colors.white : Colors.white54,
                              fontWeight: active
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: active
                                ? _kOrange.withOpacity(0.2)
                                : Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$count',
                            style: TextStyle(
                              color: active ? _kOrange : Colors.white38,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Critical stock alert
          if (criticalCount > 0)
            Container(
              margin: const EdgeInsets.all(10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.red.shade800.withOpacity(0.5)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.red.shade400, size: 15),
                      const SizedBox(width: 6),
                      Text(
                        'Critical Stock',
                        style: TextStyle(
                          color: Colors.red.shade400,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$criticalCount item${criticalCount > 1 ? 's' : ''} below safety threshold.',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => onSelect('All'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 7, horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade800.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.shade700.withOpacity(0.5)),
                      ),
                      child: const Center(
                        child: Text(
                          'REVIEW ITEMS',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PRODUCT CARD
// ═══════════════════════════════════════════════════════════════════════════════
class _ProductCard extends StatelessWidget {
  final Product product;
  final KitchenProvider kitchen;

  const _ProductCard({required this.product, required this.kitchen});

  @override
  Widget build(BuildContext context) {
    final int currentQty = kitchen.getQty(product.id);
    final bool isCritical = currentQty < 999 && currentQty < 5;
    final bool isSoldOut = currentQty == 0;

    return Container(
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCritical ? Colors.red.shade800.withOpacity(0.4) : _kCardBorder,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Top row: image + info + toggle ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Product image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: product.imageBytes != null
                        ? Image.memory(product.imageBytes!,
                            fit: BoxFit.cover)
                        : _smartProductImage(product.image),
                  ),
                ),
                const SizedBox(width: 10),

                // Name + category
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSoldOut
                              ? Colors.white30
                              : Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        product.category.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '₹${product.price.toInt()}',
                        style: const TextStyle(
                          color: _kOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                // Availability toggle
                _AvailabilitySwitch(product: product),
              ],
            ),
          ),

          const Divider(color: _kDivider, height: 1),

          // ─── Stock counter row ───
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 12,
              children: [
                // Label
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'STOCK LEVEL',
                      style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _sessionLabel(kitchen.currentSession),
                      style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 9),
                    ),
                  ],
                ),

                // -/+/counter and safety min
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StockCounter(product: product, kitchen: kitchen, isSoldOut: isSoldOut),
                    const SizedBox(width: 14),
                    // Safety min / critical indicator
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isCritical ? 'CRITICAL' : 'SAFETY MIN',
                          style: TextStyle(
                            color: isCritical ? Colors.red.shade400 : Colors.white.withOpacity(0.3),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCritical ? Colors.red.shade900.withOpacity(0.4) : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isCritical ? Colors.red.shade700.withOpacity(0.5) : Colors.transparent,
                            ),
                          ),
                          child: Text(
                            '10',
                            style: TextStyle(
                              color: isCritical ? Colors.red.shade400 : Colors.white54,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Sold out banner ───
          if (isSoldOut)
            Container(
              margin:
                  const EdgeInsets.fromLTRB(12, 0, 12, 10),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: const Center(
                child: Text(
                  'SOLD OUT',
                  style: TextStyle(
                    color: Colors.white30,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      color: Colors.white.withOpacity(0.06),
      child: const Icon(Icons.fastfood_rounded,
          color: Colors.white24, size: 24),
    );
  }

  /// Smart image: handles network URLs, local assets, and missing/default paths.
  Widget _smartProductImage(String path) {
    if (path.isEmpty || path.contains('default') || path == 'null') {
      return _imgPlaceholder();
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _imgPlaceholder(),
      );
    }
    return Image.asset(
      path,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _imgPlaceholder(),
    );
  }

  String _sessionLabel(KitchenSession s) {
    switch (s) {
      case KitchenSession.morning:
        return 'Morning Session';
      case KitchenSession.afternoon:
        return 'Afternoon Session';
      case KitchenSession.evening:
        return 'Evening Session';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  AVAILABILITY SWITCH
// ═══════════════════════════════════════════════════════════════════════════════
class _AvailabilitySwitch extends StatelessWidget {
  final Product product;
  const _AvailabilitySwitch({required this.product});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.8,
      child: Switch(
        value: product.isAvailable,
        activeColor: _kOrange,
        onChanged: (v) {
          context.read<KitchenProvider>().updateItem(
                productId: product.id,
                available: v,
                session: context.read<KitchenProvider>().currentSession,
                quantity: context.read<KitchenProvider>().getQty(product.id),
              );
          context.read<ProductProvider>().updateAvailability(productId: product.id, isAvailable: v);
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STOCK COUNTER  (replaces _QtyBox — same logic, +/- button UI)
// ═══════════════════════════════════════════════════════════════════════════════
class _StockCounter extends StatefulWidget {
  final Product product;
  final KitchenProvider kitchen;
  final bool isSoldOut;

  const _StockCounter({
    required this.product,
    required this.kitchen,
    required this.isSoldOut,
  });

  @override
  State<_StockCounter> createState() => _StockCounterState();
}

class _StockCounterState extends State<_StockCounter> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    final stored = widget.kitchen.getQtyForSession(
        widget.product.id, widget.kitchen.currentSession);
    _qty = stored < 999 ? stored : widget.product.quantity;
  }

  @override
  void didUpdateWidget(_StockCounter old) {
    super.didUpdateWidget(old);
    // Refresh when session or product changes
    if (old.product.id != widget.product.id ||
        old.kitchen.currentSession != widget.kitchen.currentSession) {
      final stored = widget.kitchen.getQtyForSession(
          widget.product.id, widget.kitchen.currentSession);
      setState(() {
        _qty = stored < 999 ? stored : widget.product.quantity;
      });
    }
  }

  void _change(BuildContext context, int delta) {
    final newQty = (_qty + delta).clamp(0, 999);
    setState(() => _qty = newQty);
    _syncToProviders(context, newQty);
  }

  void _syncToProviders(BuildContext context, int val) {
    final kitchen = context.read<KitchenProvider>();
    kitchen.updateItem(
      productId: widget.product.id,
      available: val > 0,
      session: kitchen.currentSession,
      quantity: val,
    );
    if (kitchen.currentSession == widget.kitchen.currentSession) {
      context.read<ProductProvider>().setStock(
            productId: widget.product.id,
            quantity: val,
          );
      context.read<BillingProvider>().clampCartToStock(
            widget.product.id,
            val,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isCritical = _qty < 5;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          icon: Icons.remove_rounded,
          onTap: () => _change(context, -1),
          enabled: _qty > 0,
        ),
        Container(
          width: 48,
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isCritical && _qty > 0
                ? Colors.red.shade900.withOpacity(0.3)
                : Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isCritical && _qty > 0
                  ? Colors.red.shade700.withOpacity(0.5)
                  : Colors.white12,
            ),
          ),
          child: Text(
            _qty.toString().padLeft(2, '0'),
            style: TextStyle(
              color: isCritical && _qty > 0
                  ? Colors.red.shade400
                  : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _btn(
          icon: Icons.add_rounded,
          onTap: () => _change(context, 1),
          enabled: true,
        ),
      ],
    );
  }

  Widget _btn(
      {required IconData icon,
      required VoidCallback onTap,
      required bool enabled}) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: enabled
              ? Colors.white.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: enabled ? Colors.white12 : Colors.transparent),
        ),
        child: Icon(
          icon,
          size: 16,
          color: enabled ? Colors.white60 : Colors.white12,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ═══════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined,
              color: Colors.white.withOpacity(0.08), size: 60),
          const SizedBox(height: 14),
          const Text(
            'No items found',
            style: TextStyle(color: Colors.white24, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  CATEGORY CHIPS (MOBILE)
// ═══════════════════════════════════════════════════════════════════════════════
class _CategoryChipsMobile extends StatelessWidget {
  final List<String> categories;
  final String selected;
  final Map<String, int> counts;
  final ValueChanged<String> onSelect;

  const _CategoryChipsMobile({
    required this.categories,
    required this.selected,
    required this.counts,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF111111),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: categories.map((cat) {
            final active = selected == cat;
            final count = cat == 'All'
                ? counts.values.fold(0, (a, b) => a + b)
                : (counts[cat] ?? 0);

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () => onSelect(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _kOrange.withOpacity(0.12) : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active ? _kOrange.withOpacity(0.3) : const Color(0xFF2C2C2C),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white54,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: active ? _kOrange.withOpacity(0.2) : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            color: active ? _kOrange : Colors.white38,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

