import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/invoice_provider.dart';

class TopProductsDailyScreen extends StatefulWidget {
  const TopProductsDailyScreen({super.key});

  @override
  State<TopProductsDailyScreen> createState() =>
      _TopProductsDailyScreenState();
}

class _TopProductsDailyScreenState extends State<TopProductsDailyScreen> {
  // ── Design tokens ──────────────────────────────────────────────
  static const Color _kBg      = Color(0xFF0F1117);
  static const Color _kCard    = Color(0xFF1A1A2E);
  static const Color _kOrange  = Color(0xFFFF6A00);
  static const Color _kDivider = Color(0xFF1E2235);

  DateTime selectedDate = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: _kOrange,
            onPrimary: Colors.white,
            surface: Color(0xFF1A1A2E),
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  // ── Revenue map: name → { 'qty': int, 'revenue': double } ──────
  Map<String, Map<String, dynamic>> _dailyProductData(
      InvoiceProvider provider, DateTime date) {
    final Map<String, Map<String, dynamic>> data = {};

    for (final inv in provider.invoices) {
      if (inv.date.year == date.year &&
          inv.date.month == date.month &&
          inv.date.day == date.day) {
        for (final item in inv.items) {
          final name    = item['name']?.toString() ?? 'Unknown';
          final qty     = (item['qty'] as num?)?.toInt() ?? 0;
          final price   = (item['price'] as num?)?.toDouble() ?? 0.0;
          final revenue = price * qty;

          if (!data.containsKey(name)) {
            data[name] = {'qty': 0, 'revenue': 0.0};
          }
          data[name]!['qty']     = (data[name]!['qty'] as int) + qty;
          data[name]!['revenue'] = (data[name]!['revenue'] as double) + revenue;
        }
      }
    }
    return data;
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
      '${d.year}';

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoiceProvider>(
      builder: (_, invoice, __) {
        final rawData   = _dailyProductData(invoice, selectedDate);
        final products  = rawData.entries.toList()
          ..sort((a, b) =>
              (b.value['revenue'] as double)
                  .compareTo(a.value['revenue'] as double));

        final double maxRevenue = products.isEmpty
            ? 1.0
            : products
                .map((e) => e.value['revenue'] as double)
                .reduce((a, b) => a > b ? a : b);
        final double totalRevenue =
            products.fold(0.0, (s, e) => s + (e.value['revenue'] as double));
        final int totalQty =
            products.fold(0, (s, e) => s + (e.value['qty'] as int));

        return Container(
          color: _kBg,
          child: Column(
            children: [
              // ── HEADER ────────────────────────────────────────────
              _buildHeader(),

              // ── BODY ──────────────────────────────────────────────
              Expanded(
                child: products.isEmpty
                    ? _buildEmpty()
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 700;
                          final pad = isNarrow ? 14.0 : 24.0;
                          return SingleChildScrollView(
                        padding: EdgeInsets.all(pad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Summary KPI row
                            _buildKpiRow(
                              totalRevenue: totalRevenue,
                              totalQty: totalQty,
                              productCount: products.length,
                              topProduct: products.first.key,
                              isNarrow: isNarrow,
                            ),
                            SizedBox(height: isNarrow ? 20 : 28),

                            // Section label
                            Row(
                              children: [
                                const Icon(Icons.leaderboard_rounded,
                                    color: _kOrange, size: 18),
                                const SizedBox(width: 8),
                                const Text(
                                  'Sales Leaderboard',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${products.length} products',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Product list
                            Container(
                              decoration: BoxDecoration(
                                color: _kCard,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _kDivider, width: 1),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: products.length,
                                separatorBuilder: (_, __) => Container(
                                  height: 1,
                                  color: _kDivider,
                                ),
                                itemBuilder: (_, i) {
                                  final e       = products[i];
                                  final qty     = e.value['qty'] as int;
                                  final revenue = e.value['revenue'] as double;
                                  final pct     = maxRevenue > 0
                                      ? revenue / maxRevenue
                                      : 0.0;
                                  final isTop   = i == 0;

                                  return _ProductRow(
                                    rank   : i + 1,
                                    name   : e.key,
                                    qty    : qty,
                                    revenue: revenue,
                                    pct    : pct,
                                    isTop  : isTop,
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── HEADER ──────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 18),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(bottom: BorderSide(color: _kDivider, width: 1)),
      ),
      child: Row(
        children: [
          // Title block
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Products',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Sales performance by product',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.38),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const Spacer(),

          // Date pill
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: _kCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kDivider, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: _kOrange, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(selectedDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.expand_more_rounded,
                      color: Colors.white38, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI ROW ─────────────────────────────────────────────────────
  Widget _buildKpiRow({
    required double totalRevenue,
    required int    totalQty,
    required int    productCount,
    required String topProduct,
    bool isNarrow = false,
  }) {
    final gap = isNarrow ? 10.0 : 14.0;
    final k1 = _KpiCard(
      icon : Icons.currency_rupee_rounded,
      color: const Color(0xFF4ADE80),
      label: 'Total Revenue',
      value: '₹${totalRevenue.toStringAsFixed(0)}',
    );
    final k2 = _KpiCard(
      icon : Icons.shopping_bag_rounded,
      color: const Color(0xFF3B82F6),
      label: 'Items Sold',
      value: '$totalQty',
    );
    final k3 = _KpiCard(
      icon : Icons.category_rounded,
      color: _kOrange,
      label: 'Products',
      value: '$productCount',
    );
    final k4 = _KpiCard(
      icon : Icons.emoji_events_rounded,
      color: const Color(0xFFFBBF24),
      label: 'Top Seller',
      value: topProduct,
      isText: true,
    );

    if (isNarrow) {
      return Column(children: [
        Row(children: [
          Expanded(child: k1), SizedBox(width: gap),
          Expanded(child: k2),
        ]),
        SizedBox(height: gap),
        Row(children: [
          Expanded(child: k3), SizedBox(width: gap),
          Expanded(child: k4),
        ]),
      ]);
    }

    return Row(
      children: [
        Expanded(child: k1),
        SizedBox(width: gap),
        Expanded(child: k2),
        SizedBox(width: gap),
        Expanded(child: k3),
        SizedBox(width: gap),
        Expanded(child: k4),
      ],
    );
  }

  // ── EMPTY STATE ─────────────────────────────────────────────────
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _kCard,
              shape: BoxShape.circle,
              border: Border.all(color: _kDivider),
            ),
            child: const Icon(Icons.bar_chart_rounded,
                color: Colors.white24, size: 48),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Sales Data',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'No products sold on ${_formatDate(selectedDate)}',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _pickDate,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _kOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Change Date',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── KPI CARD ────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  final String   value;
  final bool     isText;

  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.isText = false,
  });

  static const Color _kCard    = Color(0xFF1A1A2E);
  static const Color _kDivider = Color(0xFF1E2235);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kDivider, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontSize: isText ? 13 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ── PRODUCT ROW ─────────────────────────────────────────────────────
class _ProductRow extends StatelessWidget {
  final int    rank;
  final String name;
  final int    qty;
  final double revenue;
  final double pct;
  final bool   isTop;

  const _ProductRow({
    required this.rank,
    required this.name,
    required this.qty,
    required this.revenue,
    required this.pct,
    required this.isTop,
  });

  static const Color _kOrange  = Color(0xFFFF6A00);
  static const Color _kDivider = Color(0xFF1E2235);

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFBBF24); // gold
    if (rank == 2) return const Color(0xFF94A3B8); // silver
    if (rank == 3) return const Color(0xFFCD7F32); // bronze
    return Colors.white24;
  }

  Color get _barColor {
    if (rank == 1) return _kOrange;
    if (rank == 2) return const Color(0xFF3B82F6);
    if (rank == 3) return const Color(0xFF4ADE80);
    return const Color(0xFF6366F1);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _rankColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _rankColor.withOpacity(0.4), width: 1),
            ),
            child: Center(
              child: isTop
                  ? Icon(Icons.emoji_events_rounded,
                      color: _rankColor, size: 16)
                  : Text(
                      '$rank',
                      style: TextStyle(
                        color: _rankColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),

          // Product details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: isTop ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: isTop
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Revenue badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: _kOrange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: _kOrange.withOpacity(0.3), width: 1),
                      ),
                      child: Text(
                        '₹${revenue.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _kOrange,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Qty badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '×$qty',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: _kDivider,
                    valueColor: AlwaysStoppedAnimation<Color>(_barColor),
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
