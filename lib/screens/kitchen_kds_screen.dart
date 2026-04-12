import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../providers/kitchen_provider.dart';
import '../services/auth_provider.dart';
import '../utils/responsive_helper.dart';
import '../models/table_order.dart';
import '../models/cart_item.dart';
import '../models/kitchen_item_status.dart';
import 'kitchen_menu_control_screen.dart';

// ─── DESIGN TOKENS ──────────────────────────────────────────────────────────
const Color _kBg = Color(0xFF161616);
const Color _kSessionBg = Color(0xFF1C1C1C);
const Color _kQueueBg = Color(0xFF131313);
const Color _kCard = Color(0xFF212121);
const Color _kOrange = Color(0xFFFF6A00);
const Color _kDivider = Color(0xFF2A2A2A);

// ─────────────────────────────────────────────────────────────────────────────
//  MAIN SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class KitchenKDSScreen extends StatelessWidget {
  const KitchenKDSScreen({super.key});

  bool _isRecentlyUpdated(TableOrder order) =>
      DateTime.now().difference(order.updatedAt).inSeconds <= 5;

  bool _isItemUpdated(CartItem item) =>
      DateTime.now().difference(item.updatedAt).inSeconds <= 5;

  @override
  Widget build(BuildContext context) {
    final orders = context.watch<OrderProvider>().kitchenOrders;
    final kitchen = context.watch<KitchenProvider>();

    return Scaffold(
      backgroundColor: _kBg,
      body: LayoutBuilder(
        builder: (_, constraints) {
          if (constraints.maxWidth >= 800) {
            return _DesktopLayout(
              orders: orders,
              kitchen: kitchen,
              isRecentlyUpdated: _isRecentlyUpdated,
              isItemUpdated: _isItemUpdated,
            );
          }
          return _MobileLayout(
            orders: orders,
            kitchen: kitchen,
            isRecentlyUpdated: _isRecentlyUpdated,
            isItemUpdated: _isItemUpdated,
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  DESKTOP LAYOUT  (two panels side-by-side)
// ─────────────────────────────────────────────────────────────────────────────
class _DesktopLayout extends StatelessWidget {
  final List<TableOrder> orders;
  final KitchenProvider kitchen;
  final bool Function(TableOrder) isRecentlyUpdated;
  final bool Function(CartItem) isItemUpdated;

  const _DesktopLayout({
    required this.orders,
    required this.kitchen,
    required this.isRecentlyUpdated,
    required this.isItemUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Row(
        children: [
          // ── LEFT: Session Selector (Responsive width) ──
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420, minWidth: 320),
            child: _SessionPanel(kitchen: kitchen),
          ),
          Container(width: 1, color: _kDivider),
          // ── RIGHT: Active Queue ──
          Expanded(
            child: _QueuePanel(
              orders: orders,
              kitchen: kitchen,
              isRecentlyUpdated: isRecentlyUpdated,
              isItemUpdated: isItemUpdated,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBILE LAYOUT  (stacked)
// ─────────────────────────────────────────────────────────────────────────────
class _MobileLayout extends StatefulWidget {
  final List<TableOrder> orders;
  final KitchenProvider kitchen;
  final bool Function(TableOrder) isRecentlyUpdated;
  final bool Function(CartItem) isItemUpdated;

  const _MobileLayout({
    required this.orders,
    required this.kitchen,
    required this.isRecentlyUpdated,
    required this.isItemUpdated,
  });

  @override
  State<_MobileLayout> createState() => _MobileLayoutState();
}

class _MobileLayoutState extends State<_MobileLayout> {
  int _tab = 0; // 0 = session, 1 = queue

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          // Tab bar
          Container(
            padding: const EdgeInsets.only(top: 8), // Extra spacing for clarity
            color: _kSessionBg,
            child: Row(
              children: [
                _tab_item(0, Icons.grid_view_rounded, 'SESSION'),
                _tab_item(1, Icons.restaurant_menu_rounded, 'QUEUE'),
              ],
            ),
          ),
          Expanded(
            child: _tab == 0
                ? _SessionPanel(kitchen: widget.kitchen)
                : _QueuePanel(
                    orders: widget.orders,
                    kitchen: widget.kitchen,
                    isRecentlyUpdated: widget.isRecentlyUpdated,
                    isItemUpdated: widget.isItemUpdated,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tab_item(int index, IconData icon, String label) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: active ? _kOrange : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: active ? _kOrange : Colors.white38),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: active ? _kOrange : Colors.white38,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 1,
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
//  SESSION PANEL  (left / tab 0)
// ═══════════════════════════════════════════════════════════════════════════════
class _SessionPanel extends StatelessWidget {
  final KitchenProvider kitchen;
  const _SessionPanel({required this.kitchen});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // ── KMS watermark ──
        Positioned(
          bottom: -30,
          left: -10,
          child: Text(
            'KMS',
            style: TextStyle(
              fontSize: 140,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.03),
              letterSpacing: 8,
            ),
          ),
        ),

        // ── Panel content ──
        Container(
          color: _kSessionBg,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Brand ──
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: _kOrange,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Icon(Icons.restaurant_rounded,
                            color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'FLAVORFLOW KMS',
                        style: TextStyle(
                          color: _kOrange,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const Spacer(),
                      // Edit menu button
                      IconButton(
                        tooltip: 'Edit Kitchen Menu',
                        icon: const Icon(Icons.tune_rounded,
                            color: Colors.white38, size: 20),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const KitchenMenuControlScreen(),
                            ),
                          );
                        },
                      ),
                      // Logout
                      IconButton(
                        tooltip: 'Logout',
                        icon: const Icon(Icons.exit_to_app_rounded,
                            color: Colors.white38, size: 20),
                        onPressed: () =>
                            context.read<AuthProvider>().logout(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // ── Title ──
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'KITCHEN ',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text: 'LOGIN',
                          style: TextStyle(
                            color: _kOrange,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your active session to start managing orders.',
                    style: TextStyle(
                      color: Colors.white38,
                      fontSize: 13.5,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Session tiles ──
                  _SessionTile(
                    session: KitchenSession.morning,
                    label: 'Morning',
                    timeRange: '06:00 AM – 11:30 AM',
                    icon: Icons.wb_sunny_rounded,
                    current: kitchen.currentSession,
                    onTap: () =>
                        kitchen.setSession(KitchenSession.morning),
                  ),
                  const SizedBox(height: 12),
                  _SessionTile(
                    session: KitchenSession.afternoon,
                    label: 'Afternoon',
                    timeRange: '12:00 PM – 04:30 PM',
                    icon: Icons.light_mode_rounded,
                    current: kitchen.currentSession,
                    onTap: () =>
                        kitchen.setSession(KitchenSession.afternoon),
                  ),
                  const SizedBox(height: 12),
                  _SessionTile(
                    session: KitchenSession.evening,
                    label: 'Evening',
                    timeRange: '05:00 PM – 11:00 PM',
                    icon: Icons.nights_stay_rounded,
                    current: kitchen.currentSession,
                    onTap: () =>
                        kitchen.setSession(KitchenSession.evening),
                  ),

                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── SESSION TILE ────────────────────────────────────────────────────────────
class _SessionTile extends StatelessWidget {
  final KitchenSession session;
  final String label;
  final String timeRange;
  final IconData icon;
  final KitchenSession current;
  final VoidCallback onTap;

  const _SessionTile({
    required this.session,
    required this.label,
    required this.timeRange,
    required this.icon,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = current == session;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: active ? _kOrange : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? _kOrange : Colors.white10,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withOpacity(0.18)
                    : Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: active ? Colors.white : Colors.white54,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // Label + time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white.withOpacity(0.87),
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeRange,
                    style: TextStyle(
                      color: active
                          ? Colors.white70
                          : Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow or checkmark
            Icon(
              active ? Icons.check_circle_rounded : Icons.arrow_forward_ios_rounded,
              color: active ? Colors.white : Colors.white30,
              size: active ? 22 : 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  QUEUE PANEL  (right / tab 1)
// ═══════════════════════════════════════════════════════════════════════════════
class _QueuePanel extends StatelessWidget {
  final List<TableOrder> orders;
  final KitchenProvider kitchen;
  final bool Function(TableOrder) isRecentlyUpdated;
  final bool Function(CartItem) isItemUpdated;

  const _QueuePanel({
    required this.orders,
    required this.kitchen,
    required this.isRecentlyUpdated,
    required this.isItemUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final int pendingItems =
        orders.fold(0, (s, o) => s + o.items.length);

    return Container(
      color: _kQueueBg,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Panel header ───
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Queue',
                              style: TextStyle(
                                color: _kOrange,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Incoming from Main Hall',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // LIVE badge
                      _LiveBadge(),
                    ],
                  ),
                ),

                const Divider(color: _kDivider, height: 1),

                // ─── Orders / Empty (Responsive Grid) ───
                Expanded(
                  child: orders.isEmpty
                      ? _EmptyQueue()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: ResponsiveHelper.isMobile(context) ? 600 : 420,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            mainAxisExtent: 400, // Fixed height for KDS card uniformity
                          ),
                          itemCount: orders.length,
                          itemBuilder: (context, index) {
                            final order = orders[index];
                            final updated = isRecentlyUpdated(order);

                            return _BlinkWrapper(
                              enabled: updated,
                              child: _OrderCard(
                                order: order,
                                isUpdated: updated,
                                isItemUpdated: isItemUpdated,
                                onMarkReady: () {
                                  context
                                      .read<OrderProvider>()
                                      .markReady(order.tableNo);
                                },
                              ),
                            );
                          },
                        ),
                ),

                // ─── Bottom stats ───
                _StatsBar(
                  pendingItems: pendingItems,
                  orderCount: orders.length,
                ),
              ],
            ),
          ),
        );
  }
}

// ─── ORDER CARD ──────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final TableOrder order;
  final bool isUpdated;
  final bool Function(CartItem) isItemUpdated;
  final VoidCallback onMarkReady;

  const _OrderCard({
    required this.order,
    required this.isUpdated,
    required this.isItemUpdated,
    required this.onMarkReady,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTakeaway = order.isTakeaway;
    final String elapsed =
        _elapsed(order.updatedAt);
    final bool isRush = DateTime.now()
            .difference(order.updatedAt)
            .inMinutes >=
        5;

    // ── Build item rows ──
    final List<Widget> itemRows = [];
    for (final item in order.items) {
      final itemUpdated = isItemUpdated(item);
      itemRows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${item.quantity}× ${item.product.name}',
                  style: TextStyle(
                    color: item.isCancelled ? Colors.white38 : Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    decoration: item.isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (item.isCancelled)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _statusBadge('CANCELLED', Colors.red.shade900, small: true),
                ),
              if (itemUpdated)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _statusBadge('UPDATED', Colors.red.shade700, small: true),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isTakeaway ? 'TAKE' : 'MAIN',
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Outer container: handles shadow + border-radius only (no border)
    // Inner ClipRRect clips the card shape
    // Left orange accent is a Container inside a Row
    // This avoids the Flutter restriction: borderRadius + non-uniform border colors = error
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isUpdated
            ? [BoxShadow(color: _kOrange.withOpacity(0.25), blurRadius: 18, offset: const Offset(0, 4))]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _kCard,
            border: Border.all(color: _kDivider), // uniform → OK with borderRadius
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left orange accent bar ──
                Container(width: 3, color: _kOrange),

                // ── Card content ──
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Header ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: _kOrange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isTakeaway
                                    ? Icons.shopping_bag_rounded
                                    : Icons.table_restaurant_rounded,
                                color: _kOrange,
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    isTakeaway ? 'TAKEAWAY' : 'TABLE ${order.tableNo}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (order.customerName != null && order.customerName!.isNotEmpty)
                                    Text(
                                      order.customerName!.toUpperCase(),
                                      style: TextStyle(
                                        color: _kOrange.withOpacity(0.8),
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  Text(
                                    'Ordered $elapsed',
                                    style: const TextStyle(
                                        color: Colors.white38, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _statusBadge(
                              isUpdated
                                  ? 'UPDATED'
                                  : (isRush ? 'RUSH' : 'PREPARING'),
                              isUpdated
                                  ? Colors.red.shade700
                                  : (isRush
                                      ? const Color(0xFF0288D1)
                                      : _kOrange),
                            ),
                          ],
                        ),
                      ),

                      const Divider(color: _kDivider, height: 1),

                      // ── Items ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: itemRows,
                        ),
                      ),

                      // ── Mark Ready button ──
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        child: ElevatedButton.icon(
                          onPressed: onMarkReady,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B5E20),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.check_circle_rounded, size: 16),
                          label: const Text(
                            'MARK READY',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                letterSpacing: 0.8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color, {bool small = false}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 10,
        vertical: small ? 2 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: small ? 9.5 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  String _elapsed(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes == 1) return '1 min ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    return '${diff.inHours} hrs ago';
  }
}

// ─── LIVE BADGE ──────────────────────────────────────────────────────────────
class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF252525),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFF4CAF50),
                  const Color(0xFF81C784),
                  _ctrl.value,
                ),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 7),
          const Text(
            'LIVE UPDATES',
            style: TextStyle(
              color: Colors.white60,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── EMPTY STATE ─────────────────────────────────────────────────────────────
class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restaurant_menu_rounded,
            color: Colors.white.withOpacity(0.1),
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Waiting for Next Ticket',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Orders will appear here in real-time',
            style: TextStyle(color: Colors.white12, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─── STATS BAR ───────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final int pendingItems;
  final int orderCount;

  const _StatsBar({required this.pendingItems, required this.orderCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: _kDivider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statCard(
              label: 'PENDING ITEMS',
              value: pendingItems.toString(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _statCard(
              label: 'ACTIVE ORDERS',
              value: orderCount.toString(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kDivider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  BLINK WRAPPER  (keep as-is for live update animation)
// ═══════════════════════════════════════════════════════════════════════════════
class _BlinkWrapper extends StatefulWidget {
  final Widget child;
  final bool enabled;

  const _BlinkWrapper({required this.child, required this.enabled});

  @override
  State<_BlinkWrapper> createState() => _BlinkWrapperState();
}

class _BlinkWrapperState extends State<_BlinkWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.enabled) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _BlinkWrapper old) {
    super.didUpdateWidget(old);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return FadeTransition(
      opacity: _controller.drive(Tween(begin: 0.4, end: 1.0)),
      child: widget.child,
    );
  }
}
