import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/invoice_provider.dart';
import '../models/invoice.dart';
import '../utils/responsive_helper.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  String selectedInterval = 'Monthly';

  int? filterMonth;
  int filterYear = DateTime.now().year;

  static const List<String> _monthNames = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  bool get _isFiltered => filterMonth != null;

  static const Color _bg      = Color(0xFF0F1117);
  static const Color _card    = Color(0xFF1A1A1A);
  static const Color _divider = Color(0xFF1E2235);
  static const Color _orange  = Color(0xFFFF6A00);

  // ── Data helpers ─────────────────────────────────────────────

  /// Filter invoices for the selected period (respects filterMonth)
  List<Invoice> _periodInvoices(List<Invoice> all) {
    final now = DateTime.now();
    switch (selectedInterval) {
      case 'Daily':
        return all.where((i) =>
            i.date.year == now.year &&
            i.date.month == now.month &&
            i.date.day == now.day).toList();
      case 'Weekly':
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
        return all.where((i) =>
            !i.date.isBefore(start) && !i.date.isAfter(end)).toList();
      case 'Quarterly':
        final q = ((now.month - 1) ~/ 3);
        final qStart = DateTime(now.year, q * 3 + 1, 1);
        final qEnd   = DateTime(now.year, q * 3 + 4, 0, 23, 59, 59);
        return all.where((i) =>
            !i.date.isBefore(qStart) && !i.date.isAfter(qEnd)).toList();
      case 'Monthly':
      default:
        if (_isFiltered) {
          return all.where((i) =>
              i.date.year == filterYear &&
              i.date.month == filterMonth).toList();
        }
        return all.where((i) =>
            i.date.year == now.year && i.date.month == now.month).toList();
    }
  }

  /// Previous period invoices for comparison
  List<Invoice> _prevPeriodInvoices(List<Invoice> all) {
    final now = DateTime.now();
    switch (selectedInterval) {
      case 'Daily':
        final yesterday = now.subtract(const Duration(days: 1));
        return all.where((i) =>
            i.date.year == yesterday.year &&
            i.date.month == yesterday.month &&
            i.date.day == yesterday.day).toList();
      case 'Weekly':
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1 + 7));
        final end = start.add(const Duration(days: 6, hours: 23, minutes: 59));
        return all.where((i) =>
            !i.date.isBefore(start) && !i.date.isAfter(end)).toList();
      case 'Quarterly':
        final q = ((now.month - 1) ~/ 3) - 1;
        if (q < 0) return [];
        final qStart = DateTime(now.year, q * 3 + 1, 1);
        final qEnd   = DateTime(now.year, q * 3 + 4, 0, 23, 59, 59);
        return all.where((i) =>
            !i.date.isBefore(qStart) && !i.date.isAfter(qEnd)).toList();
      case 'Monthly':
      default:
        final prevMonth = _isFiltered
            ? DateTime(filterYear, (filterMonth ?? now.month) - 1, 1)
            : DateTime(now.year, now.month - 1, 1);
        return all.where((i) =>
            i.date.year == prevMonth.year &&
            i.date.month == prevMonth.month).toList();
    }
  }

  /// Build chart spots depending on interval
  List<FlSpot> _chartSpots(List<Invoice> all) {
    final now = DateTime.now();
    switch (selectedInterval) {
      case 'Daily':
        // Hours 0..23
        return List.generate(24, (h) {
          final rev = all
              .where((i) =>
                  i.date.year  == now.year &&
                  i.date.month == now.month &&
                  i.date.day   == now.day  &&
                  i.date.hour  == h)
              .fold(0.0, (s, i) => s + i.total);
          return FlSpot(h.toDouble(), rev);
        });

      case 'Weekly':
        // Last 7 days
        return List.generate(7, (idx) {
          final day = DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: 6 - idx));
          final rev = all
              .where((i) =>
                  i.date.year  == day.year &&
                  i.date.month == day.month &&
                  i.date.day   == day.day)
              .fold(0.0, (s, i) => s + i.total);
          return FlSpot(idx.toDouble(), rev);
        });

      case 'Quarterly':
        // Current quarter weeks (up to 13)
        final q      = ((now.month - 1) ~/ 3);
        final qStart = DateTime(now.year, q * 3 + 1, 1);
        return List.generate(13, (wk) {
          final wStart = qStart.add(Duration(days: wk * 7));
          final wEnd   = wStart.add(const Duration(days: 6, hours: 23, minutes: 59));
          if (wStart.isAfter(now)) return FlSpot(wk.toDouble(), 0);
          final rev = all
              .where((i) =>
                  !i.date.isBefore(wStart) &&
                  !i.date.isAfter(wEnd))
              .fold(0.0, (s, i) => s + i.total);
          return FlSpot(wk.toDouble(), rev);
        });

      case 'Monthly':
      default:
        // Days in the selected / current month
        final year  = _isFiltered ? filterYear  : now.year;
        final month = _isFiltered ? filterMonth ?? now.month : now.month;
        final days  = DateTime(year, month + 1, 0).day;
        return List.generate(days, (d) {
          final rev = all
              .where((i) =>
                  i.date.year  == year &&
                  i.date.month == month &&
                  i.date.day   == (d + 1))
              .fold(0.0, (s, i) => s + i.total);
          return FlSpot(d.toDouble(), rev);
        });
    }
  }

  /// Bottom axis labels depending on interval
  String _bottomLabel(double v) {
    final now = DateTime.now();
    switch (selectedInterval) {
      case 'Daily':
        final h = v.toInt();
        if (h % 4 != 0) return '';
        return h == 0 ? '12a' : h < 12 ? '${h}a' : h == 12 ? '12p' : '${h - 12}p';
      case 'Weekly':
        const days = <String>['MON','TUE','WED','THU','FRI','SAT','SUN'];
        final idx = v.toInt();
        if (idx < 0 || idx >= 7) return '';
        return days[idx];
      case 'Quarterly':
        final wk = v.toInt();
        if (wk % 2 != 0) return '';
        return 'W${wk + 1}';
      case 'Monthly':
      default:
        final d = v.toInt() + 1;
        if (d == 1 || d % 5 == 0) return '$d';
        return '';
    }
  }

  /// Category → revenue map
  Map<String, double> _categoryRevenue(List<Invoice> invoices) {
    final map = <String, double>{};
    for (final inv in invoices) {
      for (final item in inv.items) {
        final cat = ((item['category'] as String?)?.trim().isNotEmpty == true)
            ? item['category'] as String
            : 'Other';
        final qty   = (item['qty']   as num?)?.toInt()    ?? 0;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        map[cat] = (map[cat] ?? 0) + price * qty;
      }
    }
    return map;
  }

  String _pctLabel(double cur, double prev) {
    if (prev == 0) return cur > 0 ? '+100%' : '0%';
    final p = (cur - prev) / prev * 100;
    return '${p >= 0 ? '+' : ''}${p.toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);
    final isNarrow = isMobile || isTablet;

    return Consumer<InvoiceProvider>(
      builder: (_, ip, __) {
        final all      = ip.invoices;
        final period   = _periodInvoices(all);
        final prevPeriod = _prevPeriodInvoices(all);

        final revenue     = period.fold(0.0, (s, i) => s + i.total);
        final prevRevenue = prevPeriod.fold(0.0, (s, i) => s + i.total);
        final orders      = period.length;
        final prevOrders  = prevPeriod.length;
        final avgOrder    = orders == 0 ? 0.0 : revenue / orders;
        final prevAvgOrder= prevOrders == 0 ? 0.0 : prevRevenue / prevOrders;

        final catRev     = _categoryRevenue(period);
        final catSorted  = catRev.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final totalCatRev = catSorted.fold(0.0, (s, e) => s + e.value);

        final spots = _chartSpots(all);
        final pctChange = _pctLabel(revenue, prevRevenue);
        final isGrowth  = prevRevenue == 0
            ? revenue > 0
            : revenue >= prevRevenue;

        // Prev period spots (same shape, different data)
        final prevSpots = _buildPrevSpots(prevPeriod, spots.length);

        return Scaffold(
          backgroundColor: _bg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final pad = isMobile ? 16.0 : 24.0;
              return SingleChildScrollView(
                padding: EdgeInsets.all(pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(isMobile),
                    SizedBox(height: isNarrow ? 20 : 32),
                    _buildMomentumChart(
                      spots      : spots,
                      prevSpots  : prevSpots,
                      pctChange  : pctChange,
                      isGrowth   : isGrowth,
                      isMobile   : isMobile,
                    ),
                    SizedBox(height: isNarrow ? 20 : 32),
                    if (isNarrow) ...[
                      _buildKpiGrid(
                        revenue    : revenue,
                        prevRevenue: prevRevenue,
                        orders     : orders,
                        prevOrders : prevOrders,
                        avgOrder   : avgOrder,
                        prevAvgOrder: prevAvgOrder,
                        isGrowth   : isGrowth,
                        pctChange  : pctChange,
                        isMobile   : isMobile,
                        isNarrow   : true,
                      ),
                      const SizedBox(height: 20),
                      _buildCategorySplit(catSorted, totalCatRev),
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildKpiGrid(
                              revenue    : revenue,
                              prevRevenue: prevRevenue,
                              orders     : orders,
                              prevOrders : prevOrders,
                              avgOrder   : avgOrder,
                              prevAvgOrder: prevAvgOrder,
                              isGrowth   : isGrowth,
                              pctChange  : pctChange,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 1,
                            child: _buildCategorySplit(catSorted, totalCatRev),
                          ),
                        ],
                      ),
                    SizedBox(height: isNarrow ? 20 : 32),
                    _buildInsights(
                      revenue    : revenue,
                      prevRevenue: prevRevenue,
                      orders     : orders,
                      catSorted  : catSorted,
                      isGrowth   : isGrowth,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ── Build prev-period spots aligned to same x-count ──────────
  List<FlSpot> _buildPrevSpots(List<Invoice> prev, int count) {
    if (count == 0) return [];
    if (selectedInterval == 'Monthly') {
      final now   = DateTime.now();
      final year  = _isFiltered ? filterYear  : now.year;
      final month = _isFiltered ? filterMonth ?? now.month : now.month;
      final pMonth = month == 1 ? 12 : month - 1;
      final pYear  = month == 1 ? year - 1 : year;
      final pDays  = DateTime(pYear, pMonth + 1, 0).day;
      return List.generate(count, (d) {
        if (d >= pDays) return FlSpot(d.toDouble(), 0);
        final rev = prev
            .where((i) => i.date.day == d + 1)
            .fold(0.0, (s, i) => s + i.total);
        return FlSpot(d.toDouble(), rev);
      });
    }
    // For other intervals just return flat zero line
    return List.generate(count, (i) => FlSpot(i.toDouble(), 0));
  }

  // ── HEADER ────────────────────────────────────────────────────
  Widget _buildHeader(bool isMobile) {
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Revenue Analysis',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(
            _isFiltered
                ? 'Filtered: ${_monthNames[filterMonth! - 1]} $filterYear'
                : 'Detailed breakdown of revenue streams and growth momentum',
            style: TextStyle(
              color: _isFiltered ? _orange : Colors.white.withOpacity(0.4),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Interval toggle
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _divider),
                  ),
                  child: Row(
                    children: <String>['Daily','Weekly','Monthly','Quarterly']
                        .map((l) => _IntervalBtn(l))
                        .toList(),
                  ),
                ),
                if (selectedInterval == 'Monthly') ...[
                  const SizedBox(width: 12),
                  // Filter button
                  GestureDetector(
                    onTap: _openMonthFilterSheet,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: _isFiltered ? _orange.withOpacity(0.15) : _card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _isFiltered ? _orange.withOpacity(0.5) : _divider,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.tune_rounded, color: _isFiltered ? _orange : Colors.white38, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _isFiltered ? '${_monthNames[filterMonth! - 1]} $filterYear' : 'Filter Month',
                            style: TextStyle(
                              color: _isFiltered ? _orange : Colors.white38,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_isFiltered) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => setState(() => filterMonth = null),
                              child: const Icon(Icons.close_rounded, color: _orange, size: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Revenue Analysis',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                _isFiltered
                    ? 'Filtered: ${_monthNames[filterMonth! - 1]} $filterYear'
                    : 'Detailed breakdown of revenue streams and growth momentum',
                style: TextStyle(
                  color: _isFiltered
                      ? _orange
                      : Colors.white.withOpacity(0.4),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),

        // Interval toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _divider),
          ),
          child: Row(
            children: <String>['Daily','Weekly','Monthly','Quarterly']
                .map((l) => _IntervalBtn(l))
                .toList(),
          ),
        ),
        if (selectedInterval == 'Monthly') ...[
          const SizedBox(width: 12),
          // Filter button
          GestureDetector(
            onTap: _openMonthFilterSheet,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _isFiltered
                    ? _orange.withOpacity(0.15)
                    : _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isFiltered
                      ? _orange.withOpacity(0.5)
                      : _divider,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded,
                      color: _isFiltered ? _orange : Colors.white38,
                      size: 16),
                  const SizedBox(width: 8),
                  Text(
                    _isFiltered
                        ? '${_monthNames[filterMonth! - 1]} $filterYear'
                        : 'Filter Month',
                    style: TextStyle(
                      color: _isFiltered ? _orange : Colors.white38,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_isFiltered) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => setState(() => filterMonth = null),
                      child: const Icon(Icons.close_rounded,
                          color: _orange, size: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── MOMENTUM CHART ────────────────────────────────────────────
  Widget _buildMomentumChart({
    required List<FlSpot> spots,
    required List<FlSpot> prevSpots,
    required String pctChange,
    required bool isGrowth,
    bool isMobile = false,
  }) {
    final allY = [
      ...spots.map((s) => s.y),
      ...prevSpots.map((s) => s.y),
    ];
    final maxY = allY.isEmpty
        ? 1000.0
        : allY.reduce((a, b) => a > b ? a : b) * 1.3;
    final safeMax = maxY == 0 ? 1000.0 : maxY;

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
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Revenue Momentum', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(isGrowth ? Icons.trending_up : Icons.trending_down, color: isGrowth ? const Color(0xFF4ADE80) : const Color(0xFFEF4444), size: 14),
                    const SizedBox(width: 4),
                    Text('$pctChange ', style: TextStyle(color: isGrowth ? const Color(0xFF4ADE80) : const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.w800)),
                    Text('vs last period', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _ChartLegend(color: _orange, label: 'Current'),
                    const SizedBox(width: 16),
                    _ChartLegend(color: Colors.white.withOpacity(0.12), label: 'Prev'),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Revenue Momentum',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isGrowth
                              ? Icons.trending_up
                              : Icons.trending_down,
                          color: isGrowth
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFEF4444),
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$pctChange ',
                          style: TextStyle(
                            color: isGrowth
                                ? const Color(0xFF4ADE80)
                                : const Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'vs last period',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    _ChartLegend(color: _orange, label: 'Current Period'),
                    const SizedBox(width: 24),
                    _ChartLegend(
                        color: Colors.white.withOpacity(0.12),
                        label: 'Prev Period'),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: safeMax,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) =>
                      const FlLine(color: Color(0xFF1E2235), strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 46,
                      getTitlesWidget: (v, _) => Text(
                        v == 0
                            ? '0'
                            : '₹${(v / 1000).toStringAsFixed(v >= 1000 ? 0 : 1)}k',
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
                        final lbl = _bottomLabel(v);
                        if (lbl.isEmpty) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(lbl,
                              style: const TextStyle(
                                  color: Colors.white24,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Current period
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: _orange,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          _orange.withOpacity(0.2),
                          _orange.withOpacity(0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Previous period
                  if (prevSpots.isNotEmpty)
                    LineChartBarData(
                      spots: prevSpots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: Colors.white.withOpacity(0.12),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      dashArray: <int>[6, 4],
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI GRID ──────────────────────────────────────────────────
  Widget _buildKpiGrid({
    required double revenue,
    required double prevRevenue,
    required int    orders,
    required int    prevOrders,
    required double avgOrder,
    required double prevAvgOrder,
    required bool   isGrowth,
    required String pctChange,
    bool isMobile = false,
    bool isNarrow = false,
  }) {
    final avgOrderPct = _pctLabel(avgOrder, prevAvgOrder);
    final avgOrderGrowth = avgOrder >= prevAvgOrder;
    final gap = (isMobile || isNarrow) ? 12.0 : 20.0;

    final kpi1 = _KpiCard(
      label : 'Net Sales',
      value : '₹${revenue.toStringAsFixed(0)}',
      sub   : pctChange,
      icon  : Icons.payments_rounded,
      color : const Color(0xFF4ADE80),
      positive: isGrowth,
    );
    final kpi2 = _KpiCard(
      label : 'Total Orders',
      value : '$orders',
      sub   : orders == 0
          ? 'No orders'
          : prevOrders == 0
              ? '$orders orders'
              : _pctLabel(orders.toDouble(), prevOrders.toDouble()),
      icon  : Icons.receipt_long_rounded,
      color : const Color(0xFF3B82F6),
      positive: orders >= prevOrders,
    );
    final kpi3 = _KpiCard(
      label : 'Avg. Order Value',
      value : '₹${avgOrder.toStringAsFixed(0)}',
      sub   : avgOrderPct,
      icon  : Icons.shutter_speed_rounded,
      color : const Color(0xFFA855F7),
      positive: avgOrderGrowth,
    );
    final kpi4 = _KpiCard(
      label : 'Revenue / Order',
      value : orders == 0 ? '₹0' : '₹${avgOrder.toStringAsFixed(0)}',
      sub   : revenue > 0 ? 'Live data' : 'No sales',
      icon  : Icons.pie_chart_rounded,
      color : const Color(0xFFFB923C),
      positive: revenue > 0,
    );

    if (isMobile) {
      return Column(
        children: [
          kpi1,
          SizedBox(height: gap),
          kpi2,
          SizedBox(height: gap),
          kpi3,
          SizedBox(height: gap),
          kpi4,
        ],
      );
    }

    if (isNarrow) {
      // 2×2 grid on narrow
      return Column(
        children: [
          Row(children: [
            Expanded(child: kpi1),
            SizedBox(width: gap),
            Expanded(child: kpi2),
          ]),
          SizedBox(height: gap),
          Row(children: [
            Expanded(child: kpi3),
            SizedBox(width: gap),
            Expanded(child: kpi4),
          ]),
        ],
      );
    }

    return Column(
      children: [
        Row(children: [
          Expanded(child: kpi1),
          SizedBox(width: gap),
          Expanded(child: kpi2),
        ]),
        SizedBox(height: gap),
        Row(children: [
          Expanded(child: kpi3),
          SizedBox(width: gap),
          Expanded(child: kpi4),
        ]),
      ],
    );
  }

  // ── CATEGORY SPLIT ────────────────────────────────────────────
  Widget _buildCategorySplit(
    List<MapEntry<String, double>> catSorted,
    double totalCatRev,
  ) {
    // Up to 4 categories + "Other"
    final List<Color> catColors = [
      const Color(0xFF3B82F6),
      const Color(0xFF4ADE80),
      const Color(0xFFA855F7),
      _orange,
      Colors.white24,
    ];

    final showCats = catSorted.take(4).toList();
    final otherRev = catSorted.length > 4
        ? catSorted.skip(4).fold(0.0, (s, e) => s + e.value)
        : 0.0;

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < showCats.length; i++) {
      sections.add(PieChartSectionData(
        color    : catColors[i],
        value    : showCats[i].value,
        radius   : 15,
        showTitle: false,
      ));
    }
    if (otherRev > 0) {
      sections.add(PieChartSectionData(
        color    : catColors[4],
        value    : otherRev,
        radius   : 15,
        showTitle: false,
      ));
    }
    if (sections.isEmpty) {
      sections.add(PieChartSectionData(
        color    : const Color(0xFF1E2235),
        value    : 1,
        radius   : 15,
        showTitle: false,
      ));
    }

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
          const Text('Category Split',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(PieChartData(
              sectionsSpace   : 4,
              centerSpaceRadius: 50,
              sections        : sections,
            )),
          ),
          const SizedBox(height: 24),

          if (catSorted.isEmpty)
            Center(
              child: Text(
                'No sales data yet',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 12),
              ),
            )
          else ...[
            for (int i = 0; i < showCats.length; i++) ...[
              _SplitItem(
                color : catColors[i],
                label : showCats[i].key,
                value : totalCatRev > 0
                    ? '${(showCats[i].value / totalCatRev * 100).toStringAsFixed(0)}%'
                    : '0%',
              ),
              if (i < showCats.length - 1) const SizedBox(height: 12),
            ],
            if (otherRev > 0) ...[
              const SizedBox(height: 12),
              _SplitItem(
                color : catColors[4],
                label : 'Others',
                value : totalCatRev > 0
                    ? '${(otherRev / totalCatRev * 100).toStringAsFixed(0)}%'
                    : '0%',
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ── INSIGHTS ──────────────────────────────────────────────────
  Widget _buildInsights({
    required double revenue,
    required double prevRevenue,
    required int    orders,
    required List<MapEntry<String, double>> catSorted,
    required bool   isGrowth,
  }) {
    final insights = <Map<String, dynamic>>[];

    // Revenue trend
    if (prevRevenue > 0) {
      final pct = ((revenue - prevRevenue) / prevRevenue * 100).abs();
      insights.add({
        'icon' : isGrowth ? Icons.lightbulb_rounded : Icons.warning_rounded,
        'color': isGrowth
            ? const Color(0xFF4ADE80)
            : const Color(0xFFFB923C),
        'text' : isGrowth
            ? 'Revenue has increased by ${pct.toStringAsFixed(1)}% compared to the previous period. Great momentum!'
            : 'Revenue has declined by ${pct.toStringAsFixed(1)}% compared to the previous period. Review pricing or promotions.',
      });
    } else if (revenue > 0) {
      insights.add({
        'icon' : Icons.lightbulb_rounded,
        'color': const Color(0xFF4ADE80),
        'text' : 'Total revenue this period: ₹${revenue.toStringAsFixed(0)} from $orders orders.',
      });
    } else {
      insights.add({
        'icon' : Icons.info_rounded,
        'color': const Color(0xFF3B82F6),
        'text' : 'No sales data found for this period yet.',
      });
    }

    // Top category
    if (catSorted.isNotEmpty) {
      insights.add({
        'icon' : Icons.trending_up,
        'color': const Color(0xFF3B82F6),
        'text' : '${catSorted.first.key} is the top revenue category with ₹${catSorted.first.value.toStringAsFixed(0)} in sales this period.',
      });
    }

    // Avg order
    if (orders > 0) {
      final avg = revenue / orders;
      insights.add({
        'icon' : Icons.receipt_long_rounded,
        'color': const Color(0xFFA855F7),
        'text' : 'Average order value is ₹${avg.toStringAsFixed(0)}. ${avg > 500 ? 'Strong ticket size!' : 'Consider upselling to increase average order value.'}',
      });
    }

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
          const Text('Key Insights & Alerts',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          for (int i = 0; i < insights.length; i++) ...[
            _InsightRow(
              icon : insights[i]['icon'] as IconData,
              color: insights[i]['color'] as Color,
              text : insights[i]['text'] as String,
            ),
            if (i < insights.length - 1)
              const Divider(color: _divider, height: 32),
          ],
        ],
      ),
    );
  }

  // ── MONTH FILTER SHEET ────────────────────────────────────────
  void _openMonthFilterSheet() {
    int? tempMonth = filterMonth;
    int  tempYear  = filterYear;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, ss) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Select Month',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  GestureDetector(
                    onTap: () => ss(() => tempMonth = null),
                    child: const Text('Reset',
                        style: TextStyle(
                            color: _orange,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => ss(() => tempYear--),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E2235)),
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white38, size: 20),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Text('$tempYear',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      if (tempYear < DateTime.now().year) {
                        ss(() => tempYear++);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E2235)),
                      ),
                      child: Icon(Icons.chevron_right_rounded,
                          color: tempYear < DateTime.now().year
                              ? Colors.white38
                              : Colors.white12,
                          size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.0,
                children: List.generate(12, (i) {
                  final active = tempMonth == (i + 1);
                  return GestureDetector(
                    onTap: () => ss(() => tempMonth = i + 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: active
                            ? _orange.withOpacity(0.18)
                            : const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: active
                              ? _orange.withOpacity(0.6)
                              : const Color(0xFF1E2235),
                          width: active ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _monthNames[i],
                          style: TextStyle(
                            color: active ? _orange : Colors.white38,
                            fontSize: 13,
                            fontWeight: active
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      filterMonth = tempMonth;
                      filterYear  = tempYear;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('Apply Filter',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _IntervalBtn(String label) {
    final active = selectedInterval == label;
    return GestureDetector(
      onTap: () => setState(() => selectedInterval = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _orange : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
              color: active ? Colors.white : Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

// ── KPI CARD ──────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String   label;
  final String   value;
  final String   sub;
  final IconData icon;
  final Color    color;
  final bool     positive;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.positive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
                child: Icon(icon, color: color, size: 18),
              ),
              Text(sub,
                  style: TextStyle(
                      color: positive
                          ? const Color(0xFF4ADE80)
                          : const Color(0xFFEF4444),
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

// ── SPLIT ITEM ────────────────────────────────────────────────────
class _SplitItem extends StatelessWidget {
  final Color  color;
  final String label;
  final String value;

  const _SplitItem(
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
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800)),
      ],
    );
  }
}

// ── INSIGHT ROW ───────────────────────────────────────────────────
class _InsightRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   text;

  const _InsightRow(
      {required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13, height: 1.5)),
        ),
      ],
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
          width: 12,
          height: 3,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(
                color: Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
