import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/invoice_provider.dart';
import '../models/invoice.dart';

class WeeklyDashboardScreen extends StatefulWidget {
  const WeeklyDashboardScreen({super.key});

  @override
  State<WeeklyDashboardScreen> createState() => _WeeklyDashboardScreenState();
}

class _WeeklyDashboardScreenState extends State<WeeklyDashboardScreen> {
  String _viewMode = 'Weekly';

  static const Color _bg      = Color(0xFF0F1117);
  static const Color _card    = Color(0xFF1A1A1A);
  static const Color _divider = Color(0xFF1E2235);
  static const Color _orange  = Color(0xFFFF6A00);

  // ── Data helpers ──────────────────────────────────────────────
  static const List<String> _dayNames = ['MON','TUE','WED','THU','FRI','SAT','SUN'];
  static const List<String> _monthNames = [
    '','Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];

  /// Monday of the current week
  DateTime get _weekStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
  }

  List<Invoice> _weekInvoices(List<Invoice> all) {
    final start = _weekStart;
    final end   = start.add(const Duration(days: 6, hours: 23, minutes: 59));
    return all.where((i) =>
        !i.date.isBefore(start) && !i.date.isAfter(end)).toList();
  }

  List<Invoice> _monthInvoices(List<Invoice> all) {
    final now = DateTime.now();
    return all.where((i) =>
        i.date.year == now.year && i.date.month == now.month).toList();
  }

  List<Invoice> _prevWeekInvoices(List<Invoice> all) {
    final start = _weekStart.subtract(const Duration(days: 7));
    final end   = start.add(const Duration(days: 6, hours: 23, minutes: 59));
    return all.where((i) =>
        !i.date.isBefore(start) && !i.date.isAfter(end)).toList();
  }

  /// 7-day sales ending today
  List<double> _last7DaySales(List<Invoice> all) {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 6 - i));
      return all
          .where((inv) =>
              inv.date.year  == day.year &&
              inv.date.month == day.month &&
              inv.date.day   == day.day)
          .fold(0.0, (s, inv) => s + inv.total);
    });
  }

  /// Category → {orders, revenue} from invoices
  Map<String, Map<String, dynamic>> _categoryMap(List<Invoice> invoices) {
    final map = <String, Map<String, dynamic>>{};
    for (final inv in invoices) {
      for (final item in inv.items) {
        final cat     = (item['category'] as String?)?.trim();
        final key     = (cat == null || cat.isEmpty) ? 'Other' : cat;
        final qty     = (item['qty']   as num?)?.toInt()    ?? 0;
        final price   = (item['price'] as num?)?.toDouble() ?? 0.0;
        map[key] ??= {'orders': 0, 'revenue': 0.0};
        map[key]!['orders']  = (map[key]!['orders'] as int) + qty;
        map[key]!['revenue'] = (map[key]!['revenue'] as double) + price * qty;
      }
    }
    return map;
  }

  String _pct(double current, double prev) {
    if (prev == 0) return current > 0 ? '+100%' : '0%';
    final p = ((current - prev) / prev * 100);
    return '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}%';
  }

  bool _pctPositive(double current, double prev) => current >= prev;

  String _weekRangeLabel() {
    final start = _weekStart;
    final end   = start.add(const Duration(days: 6));
    return '${_monthNames[start.month]} ${start.day} – ${_monthNames[end.month]} ${end.day}, ${end.year}';
  }

  int _daysInMonth(int year, int month) =>
      DateTime(year, month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoiceProvider>(
      builder: (_, ip, __) {
        final all         = ip.invoices;
        final weekInvs    = _weekInvoices(all);
        final prevWeekInvs= _prevWeekInvoices(all);
        final monthInvs   = _monthInvoices(all);
        final sales7      = _last7DaySales(all);

        // Weekly totals
        final weekRevenue = weekInvs.fold(0.0, (s, i) => s + i.total);
        final prevWeekRev = prevWeekInvs.fold(0.0, (s, i) => s + i.total);
        final weekOrders  = weekInvs.length;
        final weekAvgOrder= weekOrders == 0 ? 0.0 : weekRevenue / weekOrders;
        final prevAvgOrder= prevWeekInvs.isEmpty ? 0.0
            : prevWeekInvs.fold(0.0, (s,i)=>s+i.total) / prevWeekInvs.length;

        // Monthly totals
        final monthRevenue = monthInvs.fold(0.0, (s, i) => s + i.total);
        final monthOrders  = monthInvs.length;
        final now          = DateTime.now();
        final daysInMonth  = _daysInMonth(now.year, now.month);
        final avgDailySales= now.day == 0 ? 0.0 : monthRevenue / now.day;

        // Cash vs UPI split (weekly)
        final weekCash = weekInvs
            .where((i) => i.paymentMode.toLowerCase() == 'cash')
            .fold(0.0, (s, i) => s + i.total);
        final weekOnline = weekRevenue - weekCash;
        final cashPct    = weekRevenue > 0 ? weekCash / weekRevenue : 0.0;
        final onlinePct  = weekRevenue > 0 ? weekOnline / weekRevenue : 0.0;

        // Category breakdown (weekly)
        final catMap   = _categoryMap(weekInvs);
        final catSorted = catMap.entries.toList()
          ..sort((a, b) =>
              (b.value['revenue'] as double)
                  .compareTo(a.value['revenue'] as double));

        return Scaffold(
          backgroundColor: _bg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 800;
              final pad = isNarrow ? 16.0 : 24.0;
              return SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),

                    if (_viewMode == 'Weekly') ...[
                      _buildKpiRow(
                        weekRevenue : weekRevenue,
                        prevRevenue : prevWeekRev,
                        avgOrder    : weekAvgOrder,
                        prevAvgOrder: prevAvgOrder,
                        weekOrders  : weekOrders,
                        isNarrow    : isNarrow,
                      ),
                      const SizedBox(height: 24),
                      isNarrow
                          ? Column(children: [
                              _buildRevenueChart(sales7),
                              const SizedBox(height: 16),
                              _buildOrderDistribution(
                                cashPct   : cashPct,
                                onlinePct : onlinePct,
                                weekCash  : weekCash,
                                weekOnline: weekOnline,
                              ),
                            ])
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildRevenueChart(sales7)),
                                const SizedBox(width: 24),
                                Expanded(
                                  flex: 1,
                                  child: _buildOrderDistribution(
                                    cashPct   : cashPct,
                                    onlinePct : onlinePct,
                                    weekCash  : weekCash,
                                    weekOnline: weekOnline,
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 24),
                      _buildPerformanceTable(catSorted),
                    ] else ...[
                      _buildMonthlyKpiRow(
                        monthRevenue : monthRevenue,
                        monthOrders  : monthOrders,
                        avgDailySales: avgDailySales,
                        daysInMonth  : daysInMonth,
                        isNarrow     : isNarrow,
                      ),
                      const SizedBox(height: 24),
                      _buildRevenueChart(sales7),
                      const SizedBox(height: 24),
                      _buildPerformanceTable(catSorted),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── HEADER ────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _viewMode == 'Weekly'
                    ? 'Weekly Performance Dashboard'
                    : 'Monthly Performance Dashboard',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                _viewMode == 'Weekly'
                    ? _weekRangeLabel()
                    : 'Month-to-date revenue and category analysis',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Week / Month toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _divider),
          ),
          child: Row(
            children: <String>['Weekly', 'Monthly'].map((String mode) {
              final active = _viewMode == mode;
              return GestureDetector(
                onTap: () => setState(() => _viewMode = mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 9),
                  decoration: BoxDecoration(
                    color: active ? _orange : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    mode,
                    style: TextStyle(
                      color: active ? Colors.white : Colors.white38,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ── WEEKLY KPI ROW ────────────────────────────────────────────
  Widget _buildKpiRow({
    required double weekRevenue,
    required double prevRevenue,
    required double avgOrder,
    required double prevAvgOrder,
    required int    weekOrders,
    bool isNarrow = false,
  }) {
    Widget card1 = _KpiCard(
      label: 'Weekly Revenue', value: '₹${weekRevenue.toStringAsFixed(0)}',
      change: _pct(weekRevenue, prevRevenue),
      isPositive: _pctPositive(weekRevenue, prevRevenue),
      icon: Icons.payments_rounded, color: const Color(0xFF4ADE80),
    );
    Widget card2 = _KpiCard(
      label: 'Avg. Order Value', value: '₹${avgOrder.toStringAsFixed(0)}',
      change: _pct(avgOrder, prevAvgOrder),
      isPositive: _pctPositive(avgOrder, prevAvgOrder),
      icon: Icons.shopping_bag_rounded, color: const Color(0xFF3B82F6),
    );
    Widget card3 = _KpiCard(
      label: 'Total Orders', value: '$weekOrders',
      change: weekOrders == 0 ? 'No orders yet' : '$weekOrders this week',
      isPositive: weekOrders > 0,
      icon: Icons.receipt_long_rounded, color: const Color(0xFF2DD4BF),
    );
    Widget card4 = _KpiCard(
      label: "Today's Revenue",
      value: '₹${_todaySales().toStringAsFixed(0)}',
      change: 'Live update', isPositive: true,
      icon: Icons.today_rounded, color: _orange,
    );

    if (isNarrow) {
      return Column(children: [
        Row(children: [card1, const SizedBox(width: 12), card2]),
        const SizedBox(height: 12),
        Row(children: [card3, const SizedBox(width: 12), card4]),
      ]);
    }
    return Row(children: [
      card1, const SizedBox(width: 20),
      card2, const SizedBox(width: 20),
      card3, const SizedBox(width: 20),
      card4,
    ]);
  }

  double _todaySales() {
    // Read from provider synchronously via context
    final all = context.read<InvoiceProvider>().invoices;
    final now = DateTime.now();
    return all
        .where((i) =>
            i.date.year  == now.year &&
            i.date.month == now.month &&
            i.date.day   == now.day)
        .fold(0.0, (s, i) => s + i.total);
  }

  // ── MONTHLY KPI ROW ───────────────────────────────────────────
  Widget _buildMonthlyKpiRow({
    required double monthRevenue,
    required int    monthOrders,
    required double avgDailySales,
    required int    daysInMonth,
    bool isNarrow = false,
  }) {
    Widget c1 = _KpiCard(
      label: 'Monthly Revenue', value: '₹${monthRevenue.toStringAsFixed(0)}',
      change: '${DateTime.now().day}/$daysInMonth days tracked',
      isPositive: monthRevenue > 0,
      icon: Icons.payments_rounded, color: const Color(0xFF4ADE80),
    );
    Widget c2 = _KpiCard(
      label: 'Monthly Orders', value: '$monthOrders',
      change: monthOrders == 0 ? 'No orders yet' : '$monthOrders bills',
      isPositive: monthOrders > 0,
      icon: Icons.receipt_long_rounded, color: const Color(0xFF3B82F6),
    );
    Widget c3 = _KpiCard(
      label: 'Avg. Daily Sales', value: '₹${avgDailySales.toStringAsFixed(0)}',
      change: avgDailySales > 0 ? 'Per active day' : 'No sales yet',
      isPositive: avgDailySales > 0,
      icon: Icons.trending_up_rounded, color: const Color(0xFF2DD4BF),
    );
    Widget c4 = _KpiCard(
      label: 'Avg. Order Value',
      value: monthOrders == 0 ? '₹0' : '₹${(monthRevenue / monthOrders).toStringAsFixed(0)}',
      change: 'Monthly average', isPositive: monthOrders > 0,
      icon: Icons.people_rounded, color: const Color(0xFFA855F7),
    );

    if (isNarrow) {
      return Column(children: [
        Row(children: [c1, const SizedBox(width: 12), c2]),
        const SizedBox(height: 12),
        Row(children: [c3, const SizedBox(width: 12), c4]),
      ]);
    }
    return Row(children: [
      c1, const SizedBox(width: 20),
      c2, const SizedBox(width: 20),
      c3, const SizedBox(width: 20),
      c4,
    ]);
  }

  // ── REVENUE CHART (7-day) ─────────────────────────────────────
  Widget _buildRevenueChart(List<double> sales7) {
    final maxY = sales7.isEmpty
        ? 1000.0
        : sales7.reduce((a, b) => a > b ? a : b) * 1.25;
    final safeMax = maxY == 0 ? 1000.0 : maxY;
    final now     = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Revenue — Last 7 Days',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total ₹${sales7.fold(0.0, (a, b) => a + b).toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white54, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 240,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: safeMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: safeMax / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(
                      color: Color(0xFF1E2235), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  topTitles   : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles : const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles  : AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (v, _) => Text(
                        v == 0 ? '0' : '₹${(v / 1000).toStringAsFixed(v >= 1000 ? 0 : 1)}k',
                        style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 9,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx < 0 || idx >= 7) return const SizedBox();
                        final day     = DateTime(now.year, now.month, now.day)
                            .subtract(Duration(days: 6 - idx));
                        final isToday = idx == 6;
                        final label   = isToday
                            ? 'TODAY'
                            : _dayNames[day.weekday - 1];
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            style: TextStyle(
                              color:
                                  isToday ? _orange : Colors.white24,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  sales7.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY   : sales7[i],
                        width : 32,
                        color : i == 6
                            ? _orange
                            : _orange.withOpacity(0.22),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Summary below chart
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(color: _orange, label: 'Today'),
              const SizedBox(width: 24),
              _ChartLegend(
                  color: _orange.withOpacity(0.4),
                  label: 'Previous days'),
            ],
          ),
        ],
      ),
    );
  }

  // ── ORDER DISTRIBUTION ────────────────────────────────────────
  Widget _buildOrderDistribution({
    required double cashPct,
    required double onlinePct,
    required double weekCash,
    required double weekOnline,
  }) {
    // When no data, show equal placeholder
    final hasData = (weekCash + weekOnline) > 0;
    final pieCash   = hasData ? cashPct   : 0.5;
    final pieOnline = hasData ? onlinePct : 0.5;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Split',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace   : 6,
                centerSpaceRadius: 52,
                sections: [
                  PieChartSectionData(
                    color   : const Color(0xFF4ADE80),
                    value   : pieCash * 100,
                    radius  : 22,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    color   : const Color(0xFF3B82F6),
                    value   : pieOnline * 100,
                    radius  : 22,
                    showTitle: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _DistributionItem(
            color : const Color(0xFF4ADE80),
            label : 'Cash',
            value : hasData
                ? '${(cashPct * 100).toStringAsFixed(0)}%  ₹${weekCash.toStringAsFixed(0)}'
                : '--',
          ),
          const SizedBox(height: 12),
          _DistributionItem(
            color : const Color(0xFF3B82F6),
            label : 'UPI / Online',
            value : hasData
                ? '${(onlinePct * 100).toStringAsFixed(0)}%  ₹${weekOnline.toStringAsFixed(0)}'
                : '--',
          ),
          if (!hasData) ...[
            const SizedBox(height: 16),
            Center(
              child: Text('No bills this week yet',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }

  // ── PERFORMANCE TABLE (category breakdown) ────────────────────
  Widget _buildPerformanceTable(
      List<MapEntry<String, Map<String, dynamic>>> catSorted) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Category Performance — This Week',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),

          if (catSorted.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No sales data this week yet',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13),
                ),
              ),
            )
          else ...[
            // Header
            const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('CATEGORY',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 2,
                      child: Text('QTY SOLD',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 2,
                      child: Text('REVENUE',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 2,
                      child: Text('SHARE',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                ],
              ),
            ),
            const Divider(color: _divider, height: 1),

            // Rows
            ...catSorted.take(6).map((e) {
              final totalRev = catSorted.fold(
                  0.0, (s, x) => s + (x.value['revenue'] as double));
              final sharePct = totalRev > 0
                  ? (e.value['revenue'] as double) / totalRev
                  : 0.0;
              return _CatTableRow(
                category : e.key,
                orders   : '${e.value['orders']}',
                revenue  : '₹${(e.value['revenue'] as double).toStringAsFixed(0)}',
                sharePct : sharePct,
              );
            }),
          ],
        ],
      ),
    );
  }
}

// ── KPI CARD ──────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String   label;
  final String   value;
  final String   change;
  final bool     isPositive;
  final IconData icon;
  final Color    color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E2235)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                Row(
                  children: [
                    Icon(
                      isPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      color: isPositive
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFEF4444),
                      size: 13,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      change,
                      style: TextStyle(
                        color: isPositive
                            ? const Color(0xFF4ADE80)
                            : const Color(0xFFEF4444),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

// ── CHART LEGEND ──────────────────────────────────────────────────
class _ChartLegend extends StatelessWidget {
  final Color  color;
  final String label;

  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── DISTRIBUTION ITEM ─────────────────────────────────────────────
class _DistributionItem extends StatelessWidget {
  final Color  color;
  final String label;
  final String value;

  const _DistributionItem(
      {required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 12),
        Text(label,
            style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ── CATEGORY TABLE ROW ────────────────────────────────────────────
class _CatTableRow extends StatelessWidget {
  final String category;
  final String orders;
  final String revenue;
  final double sharePct;

  const _CatTableRow({
    required this.category,
    required this.orders,
    required this.revenue,
    required this.sharePct,
  });

  static const Color _divider = Color(0xFF1E2235);
  static const Color _orange  = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          vertical: 14, horizontal: 12),
      decoration: const BoxDecoration(
        border: Border(
            bottom: BorderSide(color: _divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(category,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            flex: 2,
            child: Text(orders,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 13)),
          ),
          Expanded(
            flex: 2,
            child: Text(revenue,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ),
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: sharePct.clamp(0.0, 1.0),
                      backgroundColor:
                          Colors.white.withOpacity(0.06),
                      color: _orange,
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(sharePct * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
