import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'dart:async'; // 🔥 NEW: Required for Timer

import '../services/auth_provider.dart';
import '../models/user_role.dart';
import '../services/invoice_provider.dart';
import '../models/invoice.dart';
import '../providers/inventory_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/product_provider.dart'; // 🔥 NEW: Required for live sync
import '../widgets/dashboard/left_sidebar.dart';
import 'pin_reset_screen.dart';
import 'admin_report_settings_screen.dart';
import 'admin_reports_screen.dart';
import 'monthly_comparison_screens.dart';
import 'weekly_dashboard_screen.dart';
import 'top_products_daily_screen.dart';
import 'category_manage_screen.dart';
import 'product_add_screen.dart';
import 'monthly_comparison_screen.dart';
import 'inventory_screen.dart';
import 'expense_screen.dart';
import 'table_manage_screen.dart';
import '../utils/responsive_helper.dart';
import '../utils/platform_check.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int selectedIndex = 0;
  Timer? _refreshTimer; // 🔥 NEW: Real-time pulse

  late final List<Widget> pages;

  @override
  void initState() {
    super.initState();

    pages = [
      const _DashboardHome(),            // 0
      const AdminReportsScreen(),       // 1 (Reports / Revenue Analysis)
      MonthlyComparisonScreen(),         // 2
      const WeeklyDashboardScreen(),     // 3
      const TopProductsDailyScreen(),    // 4
      const CategoryManageScreen(),      // 5 (Settings)
      const ProductAddScreen(),          // 6 (Add Product)
      const MonthlyReportScreen(),       // 7
      const InventoryScreen(),           // 8
      const ExpenseScreen(),             // 9
      const _SupportPlaceholder(),       // 10 (Support)
      const TableManageScreen(),         // 11 (Tables)
    ];

    // Unified data refresh
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
    
    // 🔥 LIVE PULSE: Sync dashboard data every 10 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) => _refreshData());
  }

  void _refreshData() {
    if (!mounted) return;
    try {
      context.read<InvoiceProvider>().loadInvoices();
      context.read<ExpenseProvider>().loadAll();
      context.read<InventoryProvider>().loadAll();
      context.read<ProductProvider>().loadProducts();
    } catch (e) {
      debugPrint('⚠️ Admin Dashboard Sync Pulse Failed: $e');
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel(); // 🔥 STOP pulse when screen changes
    super.dispose();
  }

  void onMenuSelect(int index) {
    setState(() => selectedIndex = index);
  }

  // ── PIN RESET BOTTOM SHEET ────────────────────────────────────
  void _showPinResetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PinResetSheet(),
    );
  }

  // ── AppBar actions (shared between mobile & desktop) ──────────
  List<Widget> _buildAppBarActions(BuildContext context) {
    return [
      IconButton(
        onPressed: () {},
        tooltip: 'Notifications',
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded,
                color: Colors.white54, size: 22),
            Positioned(
              right: -1, top: -1,
              child: Container(
                width: 8, height: 8,
                decoration: const BoxDecoration(
                    color: Color(0xFFFF6A00), shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
      PopupMenuButton<String>(
        tooltip: 'Settings',
        icon: const Icon(Icons.settings_outlined,
            color: Colors.white54, size: 22),
        color: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF1E2235))),
        onSelected: (val) {
          if (val == 'report') {
            Navigator.push(context,
                MaterialPageRoute(
                    builder: (_) => const AdminReportSettingsScreen()));
          } else if (val == 'pin') {
            _showPinResetSheet(context);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'report',
            child: Row(children: [
              Icon(Icons.email_outlined, color: Colors.white54, size: 18),
              SizedBox(width: 12),
              Text('Report Settings',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
          PopupMenuDivider(),
          PopupMenuItem(
            value: 'pin',
            child: Row(children: [
              Icon(Icons.lock_reset_rounded,
                  color: Color(0xFFFF6A00), size: 18),
              SizedBox(width: 12),
              Text('Reset PIN',
                  style: TextStyle(
                      color: Color(0xFFFF6A00),
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ),
      IconButton(
        onPressed: () => context.read<AuthProvider>().logout(),
        tooltip: 'Logout',
        icon: const Icon(Icons.logout_rounded, color: Colors.white54, size: 22),
      ),
      const SizedBox(width: 8),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(children: [
          const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Alex Mercer',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              Text('FLOOR MANAGER',
                  style: TextStyle(
                      fontSize: 9,
                      color: Colors.white38,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5)),
            ],
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFFF6A00).withOpacity(0.2),
            child: const Text('A',
                style: TextStyle(
                    color: Color(0xFFFF6A00),
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ),
        ]),
      ),
      const SizedBox(width: 16),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);

    // ── Common AppBar bottom border ─────────────────────────────
    const appBarBottom = PreferredSize(
      preferredSize: Size.fromHeight(1),
      child: Divider(color: Color(0xFF1E2235), height: 1, thickness: 1),
    );

    return WillPopScope(
      onWillPop: () async {
        if (selectedIndex != 0) {
          setState(() => selectedIndex = 0);
          return false;
        }
        // If already at Home, Logout and return to Login Screen
        context.read<AuthProvider>().logout();
        return false;
      },
      child: Scaffold(
        key: ValueKey<bool>(isMobile), // Forces rebuild on resize to clear ghost DrawerControllers
        backgroundColor: const Color(0xFF0F0F0F),
        drawer: isMobile
            ? Drawer(
                child: LeftSidebar(
                  selectedIndex: selectedIndex,
                  onSelect: onMenuSelect,
                ),
              )
            : null,
        appBar: AppBar(
          backgroundColor: const Color(0xFF0F1117),
          elevation: 0,
          toolbarHeight: 64,
          centerTitle: false,
          automaticallyImplyLeading: isMobile,
          bottom: appBarBottom,
          iconTheme: const IconThemeData(color: Colors.white70),
          leading: isMobile
              ? Builder(
                  builder: (ctx) => IconButton(
                    icon: const Icon(Icons.menu_rounded),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                )
              : null,
          title: !isMobile
              ? SizedBox(
                  width: 280,
                  height: 38,
                  child: TextField(
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search orders, staff, inventory...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.28), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Colors.white.withOpacity(0.28), size: 18),
                      filled: true,
                      fillColor: const Color(0xFF1A1A2E),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFF252D45), width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Color(0xFFFF6A00), width: 1.5),
                      ),
                    ),
                  ),
                )
              : null,
          actions: _buildAppBarActions(context),
        ),
        body: isMobile
            ? IndexedStack(
                key: const ValueKey('mobile_stack'),
                index: selectedIndex,
                children: pages,
              )
            : Row(
                children: [
                  LeftSidebar(
                    selectedIndex: selectedIndex,
                    onSelect: onMenuSelect,
                  ),
                  Expanded(
                    child: IndexedStack(
                      key: const ValueKey('desktop_stack'),
                      index: selectedIndex,
                      children: pages,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/* ---------------- DASHBOARD HOME ---------------- */

class _DashboardHome extends StatelessWidget {
  const _DashboardHome();

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveHelper.isMobile(context);
    final isTablet = ResponsiveHelper.isTablet(context);

    // Dynamic grid count for KPI cards
    final gridCount = ResponsiveHelper.responsiveValue<int>(
      context,
      mobile: 2,
      tablet: 2,
      desktop: 4,
    );

    // Dynamic aspect ratio for KPI cards
    final gridAspectRatio = ResponsiveHelper.responsiveValue<double>(
      context,
      mobile: 1.3,
      tablet: 1.8,
      desktop: 1.6,
    );

    return Consumer2<InvoiceProvider, ExpenseProvider>(
      builder: (_, invoice, expense, __) {
        final todayProfit = invoice.todaySales - expense.todayTotal;
        // Real today-vs-yesterday comparison
        final pct      = invoice.todayVsYesterdayPercent;
        final pctLabel = pct == 0
            ? 'No data yesterday'
            : '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}% vs yesterday';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              /// KPI GRID
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: gridCount,
                childAspectRatio: gridAspectRatio,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  KpiCard(
                    "Orders Today",
                    invoice.todayOrders.toString(),
                    const Color(0xFF3B82F6),
                    icon: Icons.receipt_long_rounded,
                    percentage: invoice.todayOrders == 0
                        ? 'No orders yet'
                        : '${invoice.todayOrders} bills today',
                  ),
                  KpiCard(
                    "Today Sales",
                    "₹${invoice.todaySales.toStringAsFixed(0)}",
                    const Color(0xFF4ADE80),
                    icon: Icons.payments_rounded,
                    percentage: pctLabel,
                  ),
                  KpiCard(
                    "Today Expense",
                    "₹${expense.todayTotal.toStringAsFixed(0)}",
                    const Color(0xFFFF6A00),
                    icon: Icons.shopping_cart_rounded,
                    percentage: expense.todayTotal == 0
                        ? 'No expenses today'
                        : '₹${expense.todayTotal.toStringAsFixed(0)} spent',
                  ),
                  KpiCard(
                    "Today Profit",
                    "₹${todayProfit.toStringAsFixed(0)}",
                    const Color(0xFFA855F7),
                    icon: Icons.account_balance_wallet_rounded,
                    percentage: todayProfit >= 0 ? 'Profitable day!' : 'Loss today',
                    isSpecial: todayProfit > 0,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _responsiveSection(
                isMobile,
                [
                  WeeklySalesChart(
                      dailySales: invoice.last7DaysSales),
                  const PopularTimeChart(),
                ],
              ),

              const SizedBox(height: 16),

              _responsiveSection(
                isMobile,
                const [
                  TopCategoriesCard(),
                  LowMovingItemsCard(),
                ],
              ),

              const SizedBox(height: 16),

              const RecentTransactionsCard(),
            ],
          ),
        );
      },
    );
  }

  Widget _responsiveSection(bool isMobile, List<Widget> children) {
    if (isMobile) {
      return Column(
        children: children
            .map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: e,
                ))
            .toList(),
      );
    }

    return Row(
      children: children
          .map((e) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: e,
                ),
              ))
          .toList(),
    );
  }
}

/* ---------------- KPI CARD ---------------- */

class KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String percentage;
  final bool isSpecial;

  const KpiCard(this.title, this.value, this.color,
      {super.key, required this.icon, required this.percentage, this.isSpecial = false});

  @override
  Widget build(BuildContext context) {
    final bool isPositive = !percentage.startsWith('-') && !percentage.contains('Loss');
    final Color trendColor = isPositive ? const Color(0xFF4ADE80) : const Color(0xFFFF6A00);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSpecial
              ? const Color(0xFFFF6A00).withOpacity(0.3)
              : Colors.white.withOpacity(0.06),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.45),
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: trendColor,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                percentage,
                style: TextStyle(
                  fontSize: 10.5,
                  color: trendColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------- DASHBOARD CARD ---------------- */

class DashboardCard extends StatelessWidget {

  final String title;
  final Widget child;

  const DashboardCard({
    required this.title,
    required this.child,
    super.key,
  });

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      height: 280,

      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text(
                title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),

              const Divider(height: 20),

              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/* ---------------- WEEKLY SALES CHART ---------------- */

class WeeklySalesChart extends StatelessWidget {

  final List<double> dailySales;

  const WeeklySalesChart({
    super.key,
    required this.dailySales,
  });

  @override
  Widget build(BuildContext context) {

    final double maxSale =
        dailySales.isEmpty ? 0 : dailySales.reduce((a, b) => a > b ? a : b);

    final double maxY = maxSale == 0 ? 1000 : maxSale * 1.2;

    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Daily Sales Trend",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    "Revenue compared to target goals",
                    style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text("Last 7 Days", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.white.withOpacity(0.05),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        // Build last-7-days labels with today at index 6
                        final now = DateTime.now();
                        final dayNames = ['SUN','MON','TUE','WED','THU','FRI','SAT'];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= 7) return const SizedBox();
                        final day = now.subtract(Duration(days: 6 - idx));
                        final label = dayNames[day.weekday % 7];
                        final isToday = idx == 6;
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            isToday ? 'TODAY' : label,
                            style: TextStyle(
                              color: isToday ? Colors.orange : Colors.white24,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  dailySales.length,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: dailySales[i],
                        width: 48,
                        // today is always the last bar (index 6)
                        color: i == dailySales.length - 1
                            ? Colors.orange
                            : Colors.white.withOpacity(0.12),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ---------------- OTHER CARDS ---------------- */

class PopularTimeChart extends StatelessWidget {
  const PopularTimeChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.access_time_filled_rounded, color: Colors.white24, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            "Peak Hours Heatmap",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            "Generating heat map based on last 24 hours of activity.\nData will appear once the dinner service concludes.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4), height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
                4,
                (i) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    )),
          )
        ],
      ),
    );
  }
}

class TopCategoriesCard extends StatelessWidget {
  const TopCategoriesCard({super.key});

  static const List<Color> _palette = [
    Color(0xFFFF6A00),
    Color(0xFF4ADE80),
    Color(0xFF3B82F6),
    Color(0xFFA855F7),
    Color(0xFFFBBF24),
  ];

  // Compute category → total revenue from all invoices
  Map<String, double> _categoryRevenue(List<dynamic> invoices) {
    final Map<String, double> map = {};
    for (final inv in invoices) {
      for (final item in (inv.items as List<Map<String, dynamic>>)) {
        final cat     = (item['category'] as String?)?.trim() ?? 'Other';
        final price   = (item['price']   as num?)?.toDouble() ?? 0.0;
        final qty     = (item['qty']     as num?)?.toInt()    ?? 0;
        map[cat] = (map[cat] ?? 0.0) + price * qty;
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoiceProvider>(
      builder: (_, invoice, __) {
        final catMap = _categoryRevenue(invoice.invoices);
        final sorted = catMap.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top    = sorted.take(5).toList();
        final maxAmt = top.isEmpty ? 1.0 : top.first.value;

        return Container(
          height: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Top Categories",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    "${catMap.length} categories",
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (top.isEmpty)
                Expanded(
                  child: Center(
                    child: Text(
                      "No sales data yet",
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: top.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (_, i) {
                      final e     = top[i];
                      final color = _palette[i % _palette.length];
                      return _categoryRow(e.key, e.value, maxAmt == 0 ? 0 : e.value / maxAmt, color);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _categoryRow(String title, double amount, double progress, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text("₹${amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.05),
            color: color,
            minHeight: 6,
          ),
        )
      ],
    );
  }
}

class TodaySalesSummaryCard extends StatelessWidget {
  const TodaySalesSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {

    return const DashboardCard(
      title: "Today Sales Summary",
      child: Center(child: Text("Sales summary placeholder")),
    );
  }
}

class LowMovingItemsCard extends StatelessWidget {
  const LowMovingItemsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<InventoryProvider>(
      builder: (_, inv, __) {
        final lowItems = inv.lowStockMaterials;
        return Container(
          height: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Low Stock Alerts",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text("URGENT",
                        style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.w900)),
                  )
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: lowItems.isEmpty
                    ? const Center(
                        child: Text(
                          "✅ All stocks are sufficient",
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: lowItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          final m = lowItems[i];
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m.name,
                                          style: const TextStyle(
                                              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                      Text("Remaining: ${m.currentStock.toStringAsFixed(1)} ${m.unit}",
                                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {},
                                  child: const Text("Restock",
                                      style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                )
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
}

class RecentTransactionsCard extends StatelessWidget {
  const RecentTransactionsCard({super.key});

  String _shortId(String id) {
    final clean = id.replaceAll('-', '').toUpperCase();
    return '#${clean.substring(0, clean.length.clamp(0, 6))}';
  }

  String _fmtTime(DateTime d) {
    final h  = d.hour.toString().padLeft(2, '0');
    final m  = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<InvoiceProvider>(
      builder: (_, invoice, __) {
        // Most recent 8 invoices
        final recent = [...invoice.invoices]
          ..sort((a, b) => b.date.compareTo(a.date));
        final shown = recent.take(8).toList();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Recent Transactions",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    "${invoice.invoices.length} total bills",
                    style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Header
              const Row(
                children: [
                  Expanded(flex: 2, child: Text("BILL ID",    style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("TIME",       style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("PAYMENT",    style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("AMOUNT",     style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold))),
                  Expanded(flex: 2, child: Text("STATUS",     style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.bold))),
                ],
              ),
              const Divider(color: Colors.white10),

              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      "No bills yet today",
                      style: TextStyle(color: Colors.white24, fontSize: 13),
                    ),
                  ),
                )
              else
                ...shown.map((inv) => _liveRow(inv)),
            ],
          ),
        );
      },
    );
  }

  Widget _liveRow(Invoice inv) {
    final mode   = inv.paymentMode.toUpperCase();
    final isPaid = inv.syncStatus != 'PENDING';
    final modeColor = mode == 'UPI'
        ? const Color(0xFF3B82F6)
        : mode == 'CASH'
            ? const Color(0xFF4ADE80)
            : Colors.white38;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              _shortId(inv.id),
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _fmtTime(inv.date),
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: modeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                mode,
                style: TextStyle(color: modeColor, fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              "₹${inv.total.toStringAsFixed(0)}",
              style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isPaid
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isPaid ? "PAID" : "PENDING",
                style: TextStyle(
                  color: isPaid ? Colors.greenAccent : Colors.orangeAccent,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
class _SupportPlaceholder extends StatelessWidget {
  const _SupportPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0F1117),
      body: Center(
        child: Text(
          'Support System - Coming Soon',
          style: TextStyle(color: Colors.white24, fontSize: 16),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  PIN RESET BOTTOM SHEET
// ══════════════════════════════════════════════════════════════════
class _PinResetSheet extends StatefulWidget {
  const _PinResetSheet();

  @override
  State<_PinResetSheet> createState() => _PinResetSheetState();
}

class _PinResetSheetState extends State<_PinResetSheet> {
  // Steps: 0 = verify admin, 1 = pick role, 2 = new pin, 3 = confirm, 4 = success
  int _step = 0;

  String _adminPin   = '';
  String _newPin     = '';
  String _confirmPin = '';
  UserRole _role     = UserRole.staff;
  String? _error;

  static const Color _bg     = Color(0xFF13131A);
  static const Color _card   = Color(0xFF1A1A2E);
  static const Color _orange = Color(0xFFFF6A00);
  static const Color _div    = Color(0xFF1E2235);
  static const int   _len    = 4;

  String get _currentInput {
    if (_step == 0) return _adminPin;
    if (_step == 2) return _newPin;
    return _confirmPin;
  }

  void _append(String d) {
    if (_currentInput.length >= _len) return;
    setState(() {
      _error = null;
      if (_step == 0) _adminPin   += d;
      else if (_step == 2) _newPin    += d;
      else if (_step == 3) _confirmPin += d;
    });
    if (_currentInput.length == _len) {
      Future.delayed(const Duration(milliseconds: 180), _advance);
    }
  }

  void _back() {
    setState(() {
      _error = null;
      if (_step == 0) _adminPin   = _adminPin.isEmpty   ? '' : _adminPin.substring(0, _adminPin.length - 1);
      else if (_step == 2) _newPin    = _newPin.isEmpty    ? '' : _newPin.substring(0, _newPin.length - 1);
      else if (_step == 3) _confirmPin = _confirmPin.isEmpty ? '' : _confirmPin.substring(0, _confirmPin.length - 1);
    });
  }

  void _advance() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();

    if (_step == 0) {
      // Verify admin PIN
      if (auth.verifyAdminPin(_adminPin)) {
        setState(() { _step = 1; _error = null; });
      } else {
        setState(() { _error = 'Wrong admin PIN. Try again.'; _adminPin = ''; });
      }
    } else if (_step == 2) {
      // Move to confirm
      setState(() { _step = 3; _error = null; });
    } else if (_step == 3) {
      // Check match
      if (_newPin == _confirmPin) {
        auth.resetPin(role: _role, newPin: _newPin);
        setState(() => _step = 4);
      } else {
        setState(() {
          _error      = 'PINs do not match. Try again.';
          _confirmPin = '';
          _newPin     = '';
          _step       = 2;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _div),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 4),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.lock_reset_rounded,
                      color: _orange, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Reset PIN',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      Text(
                        _stepSubtitle(),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Step dots (3 steps: verify, pick role, new pin)
                if (_step < 4)
                  Row(
                    children: List.generate(3, (i) {
                      // map sheet step → dot index
                      final dotStep = _step == 0
                          ? 0
                          : _step == 1
                              ? 1
                              : 2; // step 2 & 3 both = dot 2
                      final active = i <= dotStep;
                      return Container(
                        margin: const EdgeInsets.only(left: 6),
                        width: i == dotStep ? 20 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active ? _orange : Colors.white12,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Divider(color: _div, height: 1),
          const SizedBox(height: 24),

          // Body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _step == 4 ? _buildSuccess() : _buildStepBody(),
          ),

          const SizedBox(height: 28),
        ],
      ),
    );
  }

  String _stepSubtitle() {
    switch (_step) {
      case 0: return 'Step 1 of 3 — Verify admin identity';
      case 1: return 'Step 2 of 3 — Choose role to reset';
      case 2: return 'Step 2 of 3 — Enter new PIN';
      case 3: return 'Step 3 of 3 — Confirm new PIN';
      default: return 'PIN updated successfully';
    }
  }

  Widget _buildStepBody() {
    if (_step == 1) return _buildRolePicker();

    final label = _step == 0
        ? 'Enter Admin PIN'
        : _step == 2
            ? 'New PIN for ${_role.name.toUpperCase()}'
            : 'Confirm New PIN';

    final dots = _step == 0
        ? _adminPin.length
        : _step == 2
            ? _newPin.length
            : _confirmPin.length;

    return Column(
      children: [
        // Label
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),

        // Dot display
        Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _error != null
                  ? Colors.red.withOpacity(0.5)
                  : _div,
            ),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_len, (i) {
                final filled = i < dots;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: filled ? 18 : 12,
                    height: filled ? 18 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? _orange : Colors.white12,
                    ),
                  ),
                );
              }),
            ),
          ),
        ),

        // Error
        if (_error != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            ],
          ),
        ],

        const SizedBox(height: 28),

        // Numpad
        _buildNumpad(),
      ],
    );
  }

  Widget _buildRolePicker() {
    final roles = [UserRole.admin, UserRole.staff, UserRole.server, UserRole.kitchen];
    final labels = {
      UserRole.admin  : 'Admin',
      UserRole.staff  : 'Staff',
      UserRole.server : 'Server',
      UserRole.kitchen: 'Kitchen',
    };
    final icons = {
      UserRole.admin  : Icons.admin_panel_settings_rounded,
      UserRole.staff  : Icons.people_rounded,
      UserRole.server : Icons.room_service_rounded,
      UserRole.kitchen: Icons.kitchen_rounded,
    };

    return Column(
      children: [
        const Text('Which role\'s PIN to reset?',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 2.8,
          children: roles.map((r) {
            final selected = _role == r;
            return GestureDetector(
              onTap: () => setState(() => _role = r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  color: selected
                      ? _orange.withOpacity(0.15)
                      : _card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? _orange.withOpacity(0.6)
                        : _div,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icons[r],
                        color: selected ? _orange : Colors.white38,
                        size: 20),
                    const SizedBox(width: 10),
                    Text(labels[r]!,
                        style: TextStyle(
                          color: selected ? _orange : Colors.white54,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () => setState(() => _step = 2),
            child: const Text('Continue',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF4ADE80).withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: Color(0xFF4ADE80), size: 38),
        ),
        const SizedBox(height: 20),
        const Text('PIN Updated!',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          '${_role.name.toUpperCase()} PIN has been reset successfully.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Colors.white.withOpacity(0.5), fontSize: 13),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _orange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Done',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildNumpad() {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '⌫'],
    ];
    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 80, height: 52);
              }
              final isBack = key == '⌫';
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: GestureDetector(
                  onTap: isBack ? _back : () => _append(key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 80),
                    width: 80,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isBack
                          ? _orange.withOpacity(0.1)
                          : _card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: isBack
                              ? _orange.withOpacity(0.3)
                              : _div),
                    ),
                    child: Center(
                      child: isBack
                          ? const Icon(Icons.backspace_rounded,
                              color: _orange, size: 20)
                          : Text(key,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
