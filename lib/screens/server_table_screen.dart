import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../services/auth_provider.dart';
import 'billing_screen.dart';
import '../utils/responsive_helper.dart';
import 'qr_scanner_screen.dart';

// ─── DESIGN CONSTANTS ───────────────────────────────────────────────────────
const Color _kBg = Color(0xFF0F1117);
const Color _kSidebar = Color(0xFF0D1117);
const Color _kCard = Color(0xFF1A2035);
const Color _kCardBorder = Color(0xFF252D45);
const Color _kOrange = Color(0xFFFF6A00);

class ServerTableScreen extends StatelessWidget {
  const ServerTableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final tables = orderProvider.allTables;
    final size = MediaQuery.of(context).size;
    final bool showSidebar = size.width >= 800;

    // Shift stats derived from order provider
    final int runningCount =
        tables.where((t) => orderProvider.hasActiveOrder(t)).length;
    final int availableCount = tables.length - runningCount;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // ─── LEFT SIDEBAR (tablet/desktop only) ───
                if (showSidebar)
                  _LeftSidebar(
                    runningCount: runningCount,
                    availableCount: availableCount,
                  ),

                // ─── MAIN TABLE GRID ───
                Expanded(
                  child: _TableGrid(
                    tables: tables,
                    orderProvider: orderProvider,
                  ),
                ),
              ],
            ),
          ),

          // ─── SHIFT OVERVIEW BAR ───
          _ShiftOverviewBar(
            total: tables.length,
            running: runningCount,
            available: availableCount,
          ),
        ],
      ),
      floatingActionButton: ResponsiveHelper.isMobile(context)
          ? FloatingActionButton(
              onPressed: () async {
                final String? tableNo = await Navigator.push<String>(
                  context,
                  MaterialPageRoute(builder: (_) => const QrScannerScreen()),
                );
                if (tableNo != null && context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BillingScreen(
                        tableNo: tableNo,
                        onToggleTheme: () {},
                      ),
                    ),
                  );
                }
              },
              backgroundColor: _kOrange,
              child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _kSidebar,
      elevation: 0,
      centerTitle: false,
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: _kOrange,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Text(
              'SERVER',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (!ResponsiveHelper.isMobile(context))
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'FlavorFlow',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'SELECT TABLE',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.sync_rounded, color: Colors.white54),
          onPressed: () {
            // Refresh is handled automatically via provider
          },
        ),
        IconButton(
          tooltip: 'Notifications',
          icon: const Icon(Icons.notifications_outlined,
              color: Colors.white54),
          onPressed: () {},
        ),
        IconButton(
          tooltip: 'Logout',
          icon: const Icon(Icons.exit_to_app_rounded, color: Colors.white54),
          onPressed: () => context.read<AuthProvider>().logout(),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
//  LEFT SIDEBAR  (Menu only)
// ═══════════════════════════════════════════════════════
class _LeftSidebar extends StatelessWidget {
  final int runningCount;
  final int availableCount;

  const _LeftSidebar({
    required this.runningCount,
    required this.availableCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      color: _kSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          // Menu nav item only
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _kOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.restaurant_menu_rounded,
                      color: _kOrange, size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Menu',
                    style: TextStyle(
                      color: _kOrange,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TABLE GRID
// ═══════════════════════════════════════════════════════
class _TableGrid extends StatelessWidget {
  final List<String> tables;
  final OrderProvider orderProvider;

  const _TableGrid({
    required this.tables,
    required this.orderProvider,
  });

  int _crossAxisCount(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w < 500) return 2;
    if (w < 800) return 3;
    if (w < 1100) return 4;
    return 5;
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tables.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _crossAxisCount(context),
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.88,
      ),
      itemBuilder: (context, index) {
        final tableNo = tables[index];
        final bool isRunning = orderProvider.hasActiveOrder(tableNo);
        final order = orderProvider.getOrder(tableNo);
        final double orderTotal = order?.items.fold<double>(
                0.0, (s, i) => s + i.total) ??
            0.0;

        return _TableCard(
          tableNo: tableNo,
          isRunning: isRunning,
          orderTotal: orderTotal,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BillingScreen(
                  tableNo: tableNo,
                  onToggleTheme: () {},
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
//  TABLE CARD
// ═══════════════════════════════════════════════════════
class _TableCard extends StatefulWidget {
  final String tableNo;
  final bool isRunning;
  final double orderTotal;
  final VoidCallback onTap;

  const _TableCard({
    required this.tableNo,
    required this.isRunning,
    required this.orderTotal,
    required this.onTap,
  });

  @override
  State<_TableCard> createState() => _TableCardState();
}

class _TableCardState extends State<_TableCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        widget.isRunning ? _kOrange : const Color(0xFF2E7D32);
    final Color bgColor = widget.isRunning
        ? _kOrange.withOpacity(0.08)
        : const Color(0xFF2E7D32).withOpacity(0.06);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _hovered ? bgColor.withOpacity(0.16) : _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.isRunning
                  ? borderColor.withOpacity(_hovered ? 1 : 0.5)
                  : _kCardBorder,
              width: widget.isRunning ? 1.5 : 1,
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: borderColor.withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ─── Top row: table number + status badge ───
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Table icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: widget.isRunning
                            ? _kOrange.withOpacity(0.15)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.table_restaurant_rounded,
                        color: widget.isRunning
                            ? _kOrange
                            : Colors.white38,
                        size: 20,
                      ),
                    ),
                    const Spacer(),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: widget.isRunning
                            ? _kOrange.withOpacity(0.15)
                            : const Color(0xFF2E7D32).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: widget.isRunning
                              ? _kOrange.withOpacity(0.4)
                              : const Color(0xFF2E7D32).withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        widget.isRunning ? 'RUNNING' : 'FREE',
                        style: TextStyle(
                          color: widget.isRunning
                              ? _kOrange
                              : const Color(0xFF4CAF50),
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // ─── Table number ───
                Text(
                  widget.tableNo,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 4),

                // ─── Status info ───
                if (widget.isRunning && widget.orderTotal > 0)
                  Text(
                    '₹${widget.orderTotal.toInt()}',
                    style: TextStyle(
                      color: _kOrange.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    widget.isRunning ? 'In progress' : 'Available',
                    style: TextStyle(
                      color: widget.isRunning
                          ? Colors.white38
                          : const Color(0xFF4CAF50).withOpacity(0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
//  SHIFT OVERVIEW BAR
// ═══════════════════════════════════════════════════════
class _ShiftOverviewBar extends StatelessWidget {
  final int total;
  final int running;
  final int available;

  const _ShiftOverviewBar({
    required this.total,
    required this.running,
    required this.available,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: _kSidebar,
        border: Border(top: BorderSide(color: _kCardBorder, width: 1)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            const Icon(Icons.bar_chart_rounded,
                color: Colors.white38, size: 18),
            const SizedBox(width: 8),
            const Text(
              'SHIFT OVERVIEW',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 24),
            _overviewStat('Total', total.toString(), Colors.white54),
            const SizedBox(width: 20),
            _overviewStat('Running', running.toString(), _kOrange),
            const SizedBox(width: 20),
            _overviewStat(
                'Available', available.toString(), const Color(0xFF4CAF50)),
            const SizedBox(width: 20),
          ],
        ),
      ),
    );
  }

  Widget _overviewStat(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

