import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/expense_provider.dart';
import '../models/expense_model.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _bg      = Color(0xFF0F1117);
  static const Color _card    = Color(0xFF1A1A1A);
  static const Color _orange  = Color(0xFFFF6A00);
  static const Color _divider = Color(0xFF1E2235);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExpenseProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────
  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${_mon(d.month)} ${d.year}';

  String _mon(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m];

  IconData _catIcon(String catId) {
    switch (catId) {
      case 'rent':        return Icons.home_rounded;
      case 'salary':      return Icons.badge_rounded;
      case 'electricity': return Icons.bolt_rounded;
      case 'purchase':    return Icons.shopping_basket_rounded;
      case 'maintenance': return Icons.build_rounded;
      default:            return Icons.receipt_rounded;
    }
  }

  // ── Add Expense bottom sheet ──────────────────────────────────
  void _showAddExpenseSheet() {
    final provider = context.read<ExpenseProvider>();
    final cats     = provider.categories;

    String   selectedCatId   = cats.first.id;
    String   selectedCatName = cats.first.name;
    String   paymentMode     = 'CASH';
    final    descCtrl        = TextEditingController();
    final    amtCtrl         = TextEditingController();
    bool     saving          = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, ss) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: _divider)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Add Expense',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),

                // Category dropdown
                DropdownButtonFormField<String>(
                  value: selectedCatId,
                  dropdownColor: _card,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  icon: const Icon(Icons.expand_more_rounded, color: Colors.white38),
                  decoration: _fieldDeco('Category', Icons.category_rounded),
                  items: cats.map((c) => DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.icon}  ${c.name}',
                        style: const TextStyle(color: Colors.white)),
                  )).toList(),
                  onChanged: (v) => ss(() {
                    selectedCatId   = v!;
                    selectedCatName = cats.firstWhere((c) => c.id == v).name;
                  }),
                ),
                const SizedBox(height: 14),

                // Description
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _fieldDeco('Description (e.g. Rice 10kg)', Icons.notes_rounded),
                ),
                const SizedBox(height: 14),

                // Amount
                TextField(
                  controller: amtCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: _fieldDeco('Amount (₹)', Icons.currency_rupee_rounded),
                ),
                const SizedBox(height: 14),

                // Payment mode toggle
                Row(
                  children: <String>['CASH', 'ONLINE'].map((mode) {
                    final active = paymentMode == mode;
                    return GestureDetector(
                      onTap: () => ss(() => paymentMode = mode),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? _orange : _card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: active ? _orange : _divider),
                        ),
                        child: Text(
                          mode,
                          style: TextStyle(
                            color: active ? Colors.white : Colors.white38,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: saving
                        ? null
                        : () async {
                            final amt = double.tryParse(amtCtrl.text.trim());
                            if (amt == null || amt <= 0) return;
                            final desc = descCtrl.text.trim();
                            if (desc.isEmpty) return;

                            ss(() => saving = true);
                            await provider.addExpense(
                              ExpenseEntry(
                                id           : const Uuid().v4(),
                                categoryId   : selectedCatId,
                                categoryName : selectedCatName,
                                amount       : amt,
                                description  : desc,
                                date         : DateTime.now(),
                                paymentMode  : paymentMode,
                              ),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                    child: saving
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Save Expense',
                            style: TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDeco(String label, IconData icon) => InputDecoration(
        labelText     : label,
        labelStyle    : TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
        prefixIcon    : Icon(icon, color: _orange, size: 18),
        filled        : true,
        fillColor     : _card,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _divider, width: 1)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _orange, width: 1.5)),
      );

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildExpensesTab(),
                _buildRecurringTab(),
                _buildSuppliersTab(),
                _buildReportsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(builder: (context, constraints) {
      final isNarrow = constraints.maxWidth < 600;
      final addBtn = ElevatedButton.icon(
        onPressed: _showAddExpenseSheet,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Expense',
            style: TextStyle(fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 14 : 20, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return Container(
      padding: EdgeInsets.fromLTRB(isNarrow ? 16 : 24, 20, isNarrow ? 16 : 24, 0),
      color: const Color(0xFF0D1117),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNarrow) ...[
            const Text(
              'Expense Management',
              style: TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            addBtn,
          ] else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                      const Text(
                        'Expense Management',
                        style: TextStyle(
                            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 20),
                      Text(
                        'Main Dashboard',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                ],
              ),
              addBtn,
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            indicatorColor: _orange,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Expenses'),
              Tab(text: 'Recurring'),
              Tab(text: 'Suppliers'),
              Tab(text: 'Reports'),
            ],
          ),
        ],
      ),
      );
    });
  }

  // ── EXPENSES TAB ─────────────────────────────────────────────
  Widget _buildExpensesTab() {
    return Consumer<ExpenseProvider>(
      builder: (_, provider, __) {
        return LayoutBuilder(builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 700;
          return SingleChildScrollView(
          padding: EdgeInsets.all(isNarrow ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildKpiRow(provider, isNarrow: isNarrow),
              SizedBox(height: isNarrow ? 20 : 32),
              _buildRecentTransactions(provider),
            ],
          ),
          );
        });
      },
    );
  }

  // ── RECURRING TAB ────────────────────────────────────────────
  Widget _buildRecurringTab() {
    return Consumer<ExpenseProvider>(
      builder: (_, provider, __) {
        final recurring = provider.recurring;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
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
                    const Text('Recurring Expenses',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${recurring.length} active',
                        style: const TextStyle(
                            color: _orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (recurring.isEmpty)
                  _emptyState(
                      Icons.sync_rounded, 'No recurring expenses set up yet'),
                ...recurring.map((r) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _divider),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _orange.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.sync_rounded,
                                  color: _orange, size: 16),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.description,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700)),
                                  Text(
                                      '${r.categoryName} · Day ${r.dayOfMonth} of month',
                                      style: const TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            Text(
                              '₹${r.amount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── SUPPLIERS TAB ────────────────────────────────────────────
  Widget _buildSuppliersTab() {
    return Consumer<ExpenseProvider>(
      builder: (_, provider, __) {
        final suppliers = [...provider.supplierPayments]
          ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
        final maxAmt =
            suppliers.isEmpty ? 1.0 : suppliers.first.totalAmount;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
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
                    const Text('Suppliers',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    Text(
                        'Pending: ₹${provider.totalPendingSupplier.toStringAsFixed(0)}',
                        style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 20),
                if (suppliers.isEmpty)
                  _emptyState(Icons.store_rounded,
                      'No supplier payments recorded yet'),
                ...suppliers.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.store_rounded,
                                    color: Colors.white38, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.supplierName,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                      s.isFullyPaid
                                          ? 'Fully Paid'
                                          : 'Pending: ₹${s.pendingAmount.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        color: s.isFullyPaid
                                            ? const Color(0xFF4ADE80)
                                            : Colors.redAccent,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '₹${s.totalAmount.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: maxAmt > 0
                                  ? (s.totalAmount / maxAmt).clamp(0.0, 1.0)
                                  : 0,
                              backgroundColor:
                                  Colors.white.withOpacity(0.05),
                              color: _orange,
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── REPORTS TAB ──────────────────────────────────────────────
  Widget _buildReportsTab() {
    return Consumer<ExpenseProvider>(
      builder: (_, provider, __) {
        final catBreakdown = provider.categoryBreakdownThisMonth;
        final sorted = catBreakdown.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final maxAmt = sorted.isEmpty ? 1.0 : sorted.first.value;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
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
                    const Text('This Month Breakdown',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    Text('₹${provider.monthTotal.toStringAsFixed(0)} total',
                        style: const TextStyle(
                            color: _orange,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 20),
                if (sorted.isEmpty)
                  _emptyState(
                      Icons.pie_chart_outline_rounded,
                      'No expenses this month'),
                ...sorted.map((e) {
                  final pct = maxAmt > 0 ? e.value / maxAmt : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text('₹${e.value.toStringAsFixed(0)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct.clamp(0.0, 1.0),
                            backgroundColor: Colors.white.withOpacity(0.05),
                            color: _orange,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── KPI ROW ──────────────────────────────────────────────────
  Widget _buildKpiRow(ExpenseProvider provider, {bool isNarrow = false}) {
    final pendingCount =
        provider.supplierPayments.where((p) => !p.isFullyPaid).length;
    final gap = isNarrow ? 12.0 : 20.0;

    final kpiToday = Expanded(
      child: _KpiCard(
        label: "Today's Expense",
        value: "₹${provider.todayTotal.toStringAsFixed(0)}",
        icon: Icons.calendar_today_rounded,
        badge: "${provider.todayExpenses.length} entries",
        badgeColor: _orange,
      ),
    );
    final kpiMonth = Expanded(
      child: _KpiCard(
        label: "This Month",
        value: "₹${provider.monthTotal.toStringAsFixed(0)}",
        icon: Icons.calendar_month_rounded,
        progress: provider.monthTotal > 0
            ? (provider.todayTotal / (provider.monthTotal / 30))
                .clamp(0.0, 1.0)
            : 0.0,
        progressLabel: "TODAY vs DAILY AVG",
      ),
    );
    final kpiPending = Expanded(
      child: GestureDetector(
            onTap: () => _tabController.animateTo(2), // go to Suppliers tab
            child: Container(
              height: 140,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: pendingCount > 0 ? _orange : const Color(0xFF1A2A1A),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    pendingCount > 0
                        ? Icons.receipt_long_rounded
                        : Icons.check_circle_outline_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pendingCount > 0 ? 'PENDING SUPPLIERS' : 'ALL CLEAR',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5),
                  ),
                  Text(
                    pendingCount > 0 ? '$pendingCount Pending' : 'No Dues',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'View Suppliers →',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline),
                  ),
                ],
              ),
            ),
          ),
        );

    if (isNarrow) {
      return Column(children: [
        Row(children: [kpiToday, SizedBox(width: gap), kpiMonth]),
        SizedBox(height: gap),
        Row(children: [kpiPending]),
      ]);
    }

    return Row(
      children: [kpiToday, SizedBox(width: gap), kpiMonth, SizedBox(width: gap), kpiPending],
    );
  }

  // ── RECENT TRANSACTIONS ───────────────────────────────────────
  Widget _buildRecentTransactions(ExpenseProvider provider) {
    final expenses = [...provider.expenses]
      ..sort((a, b) => b.date.compareTo(a.date));

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
              const Text(
                'All Expenses',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800),
              ),
              Text(
                '${expenses.length} records',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (expenses.isEmpty)
            _emptyState(Icons.receipt_long_rounded,
                'No expenses yet. Tap "Add Expense" to record one.')
          else ...[
            // Table header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                      flex: 3,
                      child: Text('DESCRIPTION & CATEGORY',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 2,
                      child: Text('PAYMENT',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 1,
                      child: Text('DATE',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 1,
                      child: Text('TYPE',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                  Expanded(
                      flex: 1,
                      child: Text('AMOUNT',
                          style: TextStyle(
                              color: Colors.white24,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5))),
                ],
              ),
            ),
            const Divider(color: _divider),
            ...expenses.map((e) => _ExpenseRow(
                  icon     : _catIcon(e.categoryId),
                  title    : e.description,
                  subtitle : e.categoryName,
                  payment  : e.paymentMode,
                  date     : _fmtDate(e.date),
                  isRecurring: e.isRecurring,
                  amount   : '₹${e.amount.toStringAsFixed(2)}',
                  onDelete : () async {
                    await provider.deleteExpense(e.id);
                  },
                )),
          ],
        ],
      ),
    );
  }

  Widget _emptyState(IconData icon, String msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white24, size: 30),
            ),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── KPI CARD ─────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final String?  badge;
  final Color?   badgeColor;
  final double?  progress;
  final String?  progressLabel;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    this.badge,
    this.badgeColor,
    this.progress,
    this.progressLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFF1E2235), width: 1),
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
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white54, size: 18),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor!.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900)),
              if (progress != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(progressLabel!,
                        style: const TextStyle(
                            color: Colors.white24,
                            fontSize: 8,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 80,
                      height: 6,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor:
                              Colors.white.withOpacity(0.1),
                          color: const Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── EXPENSE ROW ──────────────────────────────────────────────────
class _ExpenseRow extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   subtitle;
  final String   payment;
  final String   date;
  final bool     isRecurring;
  final String   amount;
  final VoidCallback onDelete;

  const _ExpenseRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.payment,
    required this.date,
    required this.isRecurring,
    required this.amount,
    required this.onDelete,
  });

  static const Color _divider = Color(0xFF1E2235);
  static const Color _orange  = Color(0xFFFF6A00);

  @override
  Widget build(BuildContext context) {
    final typeColor = isRecurring
        ? const Color(0xFFA855F7)
        : payment == 'CASH'
            ? const Color(0xFF4ADE80)
            : const Color(0xFF3B82F6);
    final typeLabel = isRecurring ? 'RECURRING' : payment;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _divider)),
      ),
      child: Row(
        children: [
          // Icon + title
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white54, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(subtitle,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.3),
                              fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Payment mode
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(payment,
                  style: TextStyle(
                      color: typeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          // Date
          Expanded(
            flex: 1,
            child: Text(date,
                style: const TextStyle(color: Colors.white38, fontSize: 11)),
          ),
          // Type badge
          Expanded(
            flex: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(typeLabel,
                  style: TextStyle(
                      color: typeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ),
          ),
          // Amount + delete
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(amount,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white24, size: 16),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String label;

  const _IconBtn(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
