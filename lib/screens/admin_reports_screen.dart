import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/invoice_service.dart';
import 'billing_screen.dart';

enum TimeSession { morning, afternoon, evening }

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

const Color _bg = Color(0xFF0D0D0D); // OLED Black
const Color _card = Color(0xFF1A1A1A); // Deep Grey Card
const Color _divider = Color(0xFF262626); // Subtle Divider
const Color _orange = Color(0xFFFF6A00); // FlavorFlow Orange
const Color _field = Color(0xFF0D0D0D);

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  DateTime selectedDate = DateTime.now();
  TimeSession selectedSession = TimeSession.morning;

  DateTime? _parseDate(dynamic iso) {
    if (iso == null) return null;
    try { return DateTime.parse(iso.toString()).toLocal(); } catch (_) { return null; }
  }

  bool _sameDate(dynamic iso) {
    final d = _parseDate(iso);
    if (d == null) return false;
    return d.year == selectedDate.year && d.month == selectedDate.month && d.day == selectedDate.day;
  }

  bool _inSession(dynamic iso) {
    final d = _parseDate(iso);
    if (d == null) return false;
    final h = d.hour;
    switch (selectedSession) {
      case TimeSession.morning:   return h >= 6  && h < 11;
      case TimeSession.afternoon: return h >= 11 && h < 16;
      case TimeSession.evening:   return h >= 16 && h < 24;
    }
  }

  String get sessionTitle {
    switch (selectedSession) {
      case TimeSession.morning:   return 'Morning';
      case TimeSession.afternoon: return 'Afternoon';
      case TimeSession.evening:   return 'Evening';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: InvoiceService.getBills(),
        builder: (_, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: _orange));

          final allBills = snap.data!;
          final dayBills = allBills.where((b) => _sameDate(b['date'])).toList();
          final sessionBills = dayBills.where((b) => _inSession(b['date'])).toList();

          final totalSales = dayBills.fold<double>(0, (s, b) => s + ((b['total'] ?? 0) as num).toDouble());
          final cashSales = dayBills.where((b) => b['paymentMode'] == 'CASH').fold<double>(0, (s, b) => s + ((b['total'] ?? 0) as num).toDouble());
          final onlineSales = dayBills.where((b) => b['paymentMode'] == 'ONLINE').fold<double>(0, (s, b) => s + ((b['total'] ?? 0) as num).toDouble());
          final sessionSales = sessionBills.fold<double>(0, (s, b) => s + ((b['total'] ?? 0) as num).toDouble());
          final avgTicket = dayBills.isEmpty ? 0.0 : totalSales / dayBills.length;

          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 750;
              final pad = isNarrow ? 16.0 : 24.0;
              return SingleChildScrollView(
            padding: EdgeInsets.all(pad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isNarrow: isNarrow),
                SizedBox(height: isNarrow ? 20 : 32),
                _buildSessionToggle(isNarrow: isNarrow),
                SizedBox(height: isNarrow ? 20 : 32),
                _buildKpiGrid(totalSales, sessionSales, cashSales, onlineSales, avgTicket, isNarrow: isNarrow),
                SizedBox(height: isNarrow ? 20 : 32),
                _buildBillTable(sessionBills, () => setState((){})),
              ],
            ),
          );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader({bool isNarrow = false}) {
    final dateBtn = GestureDetector(
      onTap: () async {
        final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2023), lastDate: DateTime.now());
        if (d != null) setState(() => selectedDate = d);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _divider)),
        child: const Row(children: [Icon(Icons.calendar_today_rounded, color: _orange, size: 16), SizedBox(width: 12), Text('Select Date', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))]),
      ),
    );

    if (isNarrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Operations Report', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
          const SizedBox(height: 12),
          dateBtn,
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Daily Operations Report', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)), // Greener dot
                  const SizedBox(width: 8),
                  Text('Live performance data for ${selectedDate.day}/${selectedDate.month}/${selectedDate.year}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        dateBtn,
      ],
    );
  }

  Widget _buildSessionToggle({bool isNarrow = false}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _divider)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TimeSession.values.map((s) {
          final active = selectedSession == s;
          final label = s.name[0].toUpperCase() + s.name.substring(1);
          return GestureDetector(
            onTap: () => setState(() => selectedSession = s),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isNarrow ? 16 : 24, vertical: 10),
              decoration: BoxDecoration(color: active ? _orange : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: TextStyle(color: active ? Colors.white : Colors.white24, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildKpiGrid(double total, double session, double cash, double online, double avg, {bool isNarrow = false}) {
    final gap = isNarrow ? 12.0 : 20.0;
    final k1 = _KpiReportCard(label: 'Total Revenue', value: '₹${total.toStringAsFixed(0)}', trendText: 'Daily target reached', isPositive: true, icon: Icons.payments_rounded, color: const Color(0xFF4ADE80));
    final k2 = _KpiReportCard(label: '$sessionTitle Sales', value: '₹${session.toStringAsFixed(0)}', trendText: 'Peak performance', isPositive: true, icon: Icons.timer_rounded, color: const Color(0xFF3B82F6));
    final k3 = _KpiReportCard(label: 'Avg. Ticket', value: '₹${avg.toStringAsFixed(0)}', trendText: 'Consistent growth', isPositive: true, icon: Icons.shutter_speed_rounded, color: const Color(0xFFA855F7));
    final k4 = _KpiReportCard(label: 'Cash Flow', value: '₹${cash.toStringAsFixed(0)}', trendText: 'Tender balanced', isPositive: true, icon: Icons.money_rounded, color: const Color(0xFFFB923C));
    final k5 = _KpiReportCard(label: 'Digital Pay', value: '₹${online.toStringAsFixed(0)}', trendText: 'High adoption', isPositive: true, icon: Icons.qr_code_rounded, color: const Color(0xFF2DD4BF));

    if (isNarrow) {
      return Column(children: [
        Row(children: [Expanded(child: k1), SizedBox(width: gap), Expanded(child: k2)]),
        SizedBox(height: gap),
        Row(children: [Expanded(child: k3), SizedBox(width: gap), Expanded(child: k4)]),
        SizedBox(height: gap),
        Row(children: [Expanded(child: k5), const Spacer()]),
      ]);
    }

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      childAspectRatio: 1.7, // Recalibrated for content safety
      mainAxisSpacing: gap,
      crossAxisSpacing: gap,
      children: [k1, k2, k3, k4, k5],
    );
  }

  Widget _buildBillTable(List<Map<String, dynamic>> bills, VoidCallback onRefresh) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useMobileCards = constraints.maxWidth < 650;

        if (useMobileCards) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text('$sessionTitle Transactions',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
              ),
              if (bills.isEmpty)
                Center(
                    child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('No records',
                      style: TextStyle(color: Colors.white12)),
                ))
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bills.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _BillCard(bills[i], onRefresh: onRefresh),
                ),
            ],
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 750,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$sessionTitle Session Transactions',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ),
                    const _TableHead(),
                    if (bills.isEmpty)
                      Padding(
                          padding: const EdgeInsets.all(48),
                          child: Center(
                              child: Text(
                                  'No transactions recorded for this session',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.2)))))
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: bills.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: _divider.withOpacity(0.5), height: 1),
                        itemBuilder: (_, i) =>
                            _BillRow(bills[i], onRefresh: onRefresh),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KpiReportCard extends StatelessWidget {
  final String label;
  final String value;
  final String trendText;
  final bool isPositive;
  final IconData icon;
  final Color color;
  const _KpiReportCard({required this.label, required this.value, required this.trendText, required this.isPositive, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16), // Reduced from 20
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12), // Reduced from 24 to fit 2.1 ratio
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: -1.0,
              ),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFFF6A00),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                trendText,
                style: TextStyle(
                  color: isPositive ? const Color(0xFF4ADE80) : const Color(0xFFFF6A00),
                  fontSize: 11,
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

class _TableHead extends StatelessWidget {
  const _TableHead();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(color: _bg, border: Border(bottom: BorderSide(color: _divider))),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('BILL ID', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
          Expanded(flex: 3, child: Text('CUSTOMER', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('PAYMENT', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
          Expanded(flex: 2, child: Text('ACTIONS', textAlign: TextAlign.right, style: TextStyle(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5))),
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final Map<String, dynamic> bill;
  final VoidCallback onRefresh;
  const _BillRow(this.bill, {required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final mode = bill['paymentMode']?.toString() ?? 'CASH';
    final displayId = bill['billNo'] != null ? 'INV-${bill['billNo']}' : (bill['id'] != null ? '#${bill['id']}' : '---');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(displayId, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700))),
          Expanded(flex: 3, child: Text(bill['customerName'] ?? "Walk-in Guest", style: const TextStyle(color: Colors.white70, fontSize: 13))),
          Expanded(flex: 2, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: mode == 'ONLINE' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(mode, style: TextStyle(color: mode == 'ONLINE' ? Colors.blue : Colors.green, fontSize: 10, fontWeight: FontWeight.w800), textAlign: TextAlign.center))),
          Expanded(flex: 2, child: Text('₹${((bill['total'] ?? 0) as num).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
          Expanded(
            flex: 2,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Edit Bill',
                  icon: const Icon(Icons.edit_note_rounded, color: Colors.blueAccent, size: 20),
                  onPressed: () async {
                    final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => BillingScreen(onToggleTheme: () {}, editingBill: bill)));
                    if (updated == true) onRefresh();
                  },
                ),
                IconButton(
                  tooltip: 'Delete Bill',
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () async {
                    final confirm = await _showDeleteDialog(context);
                    if (confirm == true) {
                      await InvoiceService.deleteBill(bill['id'] ?? bill['billNo']);
                      onRefresh();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C2235),
        title: const Text('Delete Invoice?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final Map<String, dynamic> bill;
  final VoidCallback onRefresh;
  const _BillCard(this.bill, {required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final mode = bill['paymentMode']?.toString() ?? 'CASH';
    final displayId = bill['billNo'] != null ? 'INV-${bill['billNo']}' : (bill['id'] != null ? '#${bill['id']}' : '---');
    final date = _parseDate(bill['date']);
    final timeStr = date != null ? '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}' : '--:--';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1A1A1A)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFF6A00).withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(displayId, style: const TextStyle(color: Color(0xFFFF6A00), fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              Text(timeStr, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bill['customerName'] ?? "Walk-in Guest", style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: mode == 'ONLINE' ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(mode, style: TextStyle(color: mode == 'ONLINE' ? Colors.blue : Colors.green, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              Text('₹${((bill['total'] ?? 0) as num).toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
            ],
          ),
          const Divider(color: Color(0xFF1E2235), height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _ActionBtn(icon: Icons.edit_note_rounded, label: 'Edit', color: Colors.blueAccent, onTap: () async {
                final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => BillingScreen(onToggleTheme: () {}, editingBill: bill)));
                if (updated == true) onRefresh();
              }),
              const SizedBox(width: 12),
              _ActionBtn(icon: Icons.delete_outline_rounded, label: 'Delete', color: Colors.redAccent, onTap: () async {
                final confirm = await _showDeleteDialog(context);
                if (confirm == true) {
                  await InvoiceService.deleteBill(bill['id'] ?? bill['billNo']);
                  onRefresh();
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  DateTime? _parseDate(dynamic iso) {
    if (iso == null) return null;
    try { return DateTime.parse(iso.toString()); } catch (_) { return null; }
  }

  Future<bool?> _showDeleteDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1C2235),
        title: const Text('Delete Invoice?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.2))),
        child: Row(
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
