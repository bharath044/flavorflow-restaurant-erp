import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../providers/kitchen_provider.dart';
import '../models/kitchen_item_status.dart';

class KitchenScreen extends StatelessWidget {
  const KitchenScreen({super.key});

  // ── Design tokens ─────────────────────────────────────────────
  static const Color _bg      = Color(0xFF0F1117);
  static const Color _card    = Color(0xFF1A1A1A);
  static const Color _orange  = Color(0xFFFF6A00);
  static const Color _divider = Color(0xFF1E2235);
  static const Color _green   = Color(0xFF4ADE80);
  static const Color _red     = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    final orders  = context.watch<OrderProvider>().openOrders;
    final kitchen = context.watch<KitchenProvider>();

    // ── Guard: kitchen not configured yet ──────────────────────
    if (!kitchen.hasAnyConfiguredItem) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _divider),
                ),
                child: const Icon(Icons.kitchen_rounded,
                    color: Colors.white24, size: 48),
              ),
              const SizedBox(height: 20),
              const Text(
                'Kitchen Not Configured',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'Please configure kitchen availability first',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,

      // ── APP BAR ────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 70,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Kitchen Display',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            Text(
              '${orders.length} active order${orders.length == 1 ? '' : 's'}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.38),
                fontSize: 12,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(color: _divider, height: 1, thickness: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: _SessionToggle(kitchen: kitchen),
              ),
            ],
          ),
        ),
      ),

      // ── BODY ──────────────────────────────────────────────────
      body: orders.isEmpty
          ? _buildEmpty()
          : LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 700;
                final crossCount = isNarrow ? 1 : (constraints.maxWidth < 1100 ? 2 : 3);
                return GridView.builder(
                  padding: EdgeInsets.all(isNarrow ? 14 : 20),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: isNarrow ? 1.4 : 1.0,
                  ),
                  itemCount: orders.length,
                  itemBuilder: (_, i) => _OrderCard(
                    order: orders[i],
                    kitchen: kitchen,
                    isNarrow: isNarrow,
                  ),
                );
              },
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: _card,
              shape: BoxShape.circle,
              border: Border.all(color: _divider),
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                color: Colors.white24, size: 52),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Active Orders',
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'New orders will appear here automatically',
            style: TextStyle(
                color: Colors.white.withOpacity(0.38), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ── Session Toggle ─────────────────────────────────────────────
class _SessionToggle extends StatelessWidget {
  const _SessionToggle({required this.kitchen});
  final KitchenProvider kitchen;

  static const Color _orange  = Color(0xFFFF6A00);
  static const Color _card    = Color(0xFF1A1A1A);
  static const Color _divider = Color(0xFF1E2235);

  @override
  Widget build(BuildContext context) {
    final sessions = [
      (KitchenSession.morning,   'Morning',   Icons.wb_sunny_outlined),
      (KitchenSession.afternoon, 'Afternoon', Icons.wb_twilight_rounded),
      (KitchenSession.evening,   'Evening',   Icons.nights_stay_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: sessions.map((s) {
          final active = kitchen.currentSession == s.$1;
          return GestureDetector(
            onTap: () => kitchen.setSession(s.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
              decoration: BoxDecoration(
                color: active ? _orange : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(s.$3,
                      color: active ? Colors.white : Colors.white38, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    s.$2,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white38,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Order Card ─────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.kitchen,
    required this.isNarrow,
  });

  final dynamic order;
  final KitchenProvider kitchen;
  final bool isNarrow;

  static const Color _bg      = Color(0xFF0F1117);
  static const Color _card    = Color(0xFF1A1A1A);
  static const Color _orange  = Color(0xFFFF6A00);
  static const Color _divider = Color(0xFF1E2235);
  static const Color _green   = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    final tableName = order.isTakeaway
        ? 'TAKEAWAY'
        : 'TABLE ${order.tableNo}';

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: order.isTakeaway
                  ? _orange.withOpacity(0.12)
                  : const Color(0xFF1A2A1A),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: _divider, width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: order.isTakeaway
                        ? _orange
                        : _green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tableName,
                    style: TextStyle(
                      color:
                          order.isTakeaway ? Colors.white : _green,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${order.items.length} item${order.items.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // ── Items list ───────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              itemCount: order.items.length,
              separatorBuilder: (_, __) => Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                height: 1,
                color: _divider,
              ),
              itemBuilder: (ctx, j) {
                final item = order.items[j];
                return _ItemRow(
                  item: item,
                  kitchen: kitchen,
                  isNarrow: isNarrow,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Item Row ──────────────────────────────────────────────────
class _ItemRow extends StatelessWidget {
  const _ItemRow({
    required this.item,
    required this.kitchen,
    required this.isNarrow,
  });

  final dynamic item;
  final KitchenProvider kitchen;
  final bool isNarrow;

  static const Color _orange  = Color(0xFFFF6A00);
  static const Color _divider = Color(0xFF1E2235);
  static const Color _green   = Color(0xFF4ADE80);

  @override
  Widget build(BuildContext context) {
    final isAvail = kitchen.isItemAvailable(item.product.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.product.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Available toggle
            GestureDetector(
              onTap: () => kitchen.updateItem(
                productId: item.product.id,
                available: !isAvail,
                session: kitchen.currentSession,
                quantity: kitchen.getQty(item.product.id),
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isAvail
                      ? _green.withOpacity(0.12)
                      : Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAvail
                        ? _green.withOpacity(0.3)
                        : Colors.red.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  isAvail ? 'Available' : 'Unavailable',
                  style: TextStyle(
                    color: isAvail ? _green : Colors.red.shade300,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Session qty inputs
        Row(
          children: [
            _SessionQtyChip(
              label: 'AM',
              session: KitchenSession.morning,
              productId: item.product.id,
              kitchen: kitchen,
            ),
            const SizedBox(width: 8),
            _SessionQtyChip(
              label: 'PM',
              session: KitchenSession.afternoon,
              productId: item.product.id,
              kitchen: kitchen,
            ),
            const SizedBox(width: 8),
            _SessionQtyChip(
              label: 'EVE',
              session: KitchenSession.evening,
              productId: item.product.id,
              kitchen: kitchen,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Session Qty Chip ──────────────────────────────────────────
class _SessionQtyChip extends StatelessWidget {
  const _SessionQtyChip({
    required this.label,
    required this.session,
    required this.productId,
    required this.kitchen,
  });

  final String label;
  final KitchenSession session;
  final String productId;
  final KitchenProvider kitchen;

  static const Color _orange  = Color(0xFFFF6A00);
  static const Color _divider = Color(0xFF1E2235);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF0F1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _divider),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1A1A1A),
                borderRadius:
                    BorderRadius.horizontal(left: Radius.circular(7)),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                  hintText: '0',
                  hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                ),
                onChanged: (v) {
                  kitchen.updateItem(
                    productId: productId,
                    available: true,
                    session: session,
                    quantity: int.tryParse(v) ?? 0,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
