import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../services/invoice_provider.dart';

const Color _kBg = Color(0xFF0F1117);
const Color _kCard = Color(0xFF1A1A1A);
const Color _kDivider = Color(0xFF1E2235);
const Color _kOrange = Color(0xFFFF6A00);

class MonthlyComparisonScreen extends StatefulWidget {
  const MonthlyComparisonScreen({super.key});

  @override
  State<MonthlyComparisonScreen> createState() => _MonthlyComparisonScreenState();
}

class _MonthlyComparisonScreenState extends State<MonthlyComparisonScreen> with SingleTickerProviderStateMixin {
  int monthA = DateTime.now().month;
  int monthB = DateTime.now().month == 1 ? 12 : DateTime.now().month - 1;

  static const Color _bg = Color(0xFF0F1117);
  static const Color _card = Color(0xFF1A1A1A);
  static const Color _divider = Color(0xFF1E2235);
  static const Color _orange = Color(0xFFFF6A00);

  final List<String> months = const [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];

  double _monthTotal(InvoiceProvider p, int month) {
    final year = DateTime.now().year;
    return p.invoices
        .where((i) => i.date.year == year && i.date.month == month)
        .fold(0.0, (sum, i) => sum + i.total);
  }

  List<double> _allMonthsTotal(InvoiceProvider p) {
    final year = DateTime.now().year;
    return List.generate(12, (m) {
      return p.invoices
          .where((i) => i.date.year == year && i.date.month == m + 1)
          .fold(0.0, (sum, i) => sum + i.total);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<InvoiceProvider>(
        builder: (_, invoice, __) {
          final salesA = _monthTotal(invoice, monthA);
          final salesB = _monthTotal(invoice, monthB);
          final diff = salesB - salesA;
          final double percent = salesA == 0 ? 0.0 : ((diff / salesA) * 100).abs().toDouble();
          final isUp = diff >= 0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 32),
                _buildSelectors(),
                const SizedBox(height: 32),
                _buildComparisonCards(salesA, salesB, percent, isUp),
                const SizedBox(height: 32),
                _buildCombinedChart(_allMonthsTotal(invoice)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly Comparison',
          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          'Analyze and compare performance between different months',
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSelectors() {
    return Row(
      children: [
        Expanded(child: _buildMonthDropdown(monthA, 'Baseline Month', (v) => setState(() => monthA = v))),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('VS', style: TextStyle(color: _orange, fontSize: 16, fontWeight: FontWeight.w900)),
        ),
        Expanded(child: _buildMonthDropdown(monthB, 'Comparison Month', (v) => setState(() => monthB = v))),
      ],
    );
  }

  Widget _buildMonthDropdown(int value, String label, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _divider),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: value,
              isExpanded: true,
              dropdownColor: _card,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white24),
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(months[i], style: const TextStyle(color: Colors.white)))),
              onChanged: (v) => onChanged(v!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComparisonCards(double salesA, double salesB, double percent, bool isUp) {
    return Row(
      children: [
        _KpiMini(label: months[monthA - 1], value: '₹${salesA.toStringAsFixed(0)}', color: Colors.blueAccent),
        const SizedBox(width: 20),
        _KpiMini(label: months[monthB - 1], value: '₹${salesB.toStringAsFixed(0)}', color: _orange),
        const SizedBox(width: 20),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _divider),
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Variance', style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${isUp ? "+" : "-"}${percent.toStringAsFixed(1)}%', style: TextStyle(color: isUp ? const Color(0xFF4ADE80) : const Color(0xFFEF4444), fontSize: 24, fontWeight: FontWeight.w900)),
                  ],
                ),
                const Spacer(),
                Icon(isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: isUp ? const Color(0xFF4ADE80) : const Color(0xFFEF4444), size: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCombinedChart(List<double> data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Annual Sales Trend', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 32),
          SizedBox(
            height: 320,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFF1E2235), strokeWidth: 1)),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (v, _) => Text('${(v).toInt()}k', style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        if (v >= 0 && v < 12) return Text(months[v.toInt()].substring(0, 3).toUpperCase(), style: const TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w700));
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(12, (i) {
                  final isA = i + 1 == monthA;
                  final isB = i + 1 == monthB;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i] / 1000,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        color: isA ? Colors.blueAccent : (isB ? _orange : Colors.white10),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ChartLegend(color: Colors.blueAccent, label: 'Baseline Month'),
              const SizedBox(width: 24),
              _ChartLegend(color: _orange, label: 'Comparison Month'),
              const SizedBox(width: 24),
              _ChartLegend(color: Colors.white10, label: 'Other Months'),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiMini extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiMini({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kDivider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
          ],
        ),
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  final Color color;
  final String label;
  const _ChartLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
