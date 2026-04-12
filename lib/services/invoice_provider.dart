import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/invoice.dart';
import 'invoice_service.dart';
import 'api_service.dart'; // 🔥 NEW: Required for cloud sync

class InvoiceProvider extends ChangeNotifier {
  final List<Invoice> invoices = [];

  final _uuid = const Uuid();

  /* ================= SAVE BILL ================= */
  Future<void> saveBill({
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double gst,
    required double total,
    String? paymentMode,
  }) async {
    final now = DateTime.now();

    // 1. Create proper Invoice model for global sync
    final invoice = Invoice(
      id: _uuid.v4(),
      deviceId: 'DESKTOP', // Placeholder, ideally app-wide unique id
      date: now,
      total: total,
      paymentMode: paymentMode ?? 'CASH',
      items: items,
      syncStatus: 'SYNCED',
    );

    // 2. Save to Central MySQL via API
    final success = await ApiService.saveInvoice(invoice);
    
    if (success) {
      // 3. Immediately refetch to update Dashboard state
      await loadInvoices();
    } else {
      debugPrint('🔴 Global Sync Failed: Saving locally as fallback');
      invoices.add(invoice);
      notifyListeners();
    }
  }

  /* ================= LOAD ================= */
  /// 🔥 NULL-SAFE FIX APPLIED (NO LOGIC CHANGE)
  Future<void> loadInvoices() async {
    final list = await ApiService.getInvoices();
    invoices.clear();
    invoices.addAll(list);
    notifyListeners();
  }

  /* ================= TODAY ================= */

  List<Invoice> get todayInvoices {
    final now = DateTime.now();
    return invoices.where((i) {
      final d = i.date.toLocal();
      return d.year == now.year && d.month == now.month && d.day == now.day;
    }).toList();
  }

  double get todaySales =>
      todayInvoices.fold(0.0, (sum, i) => sum + i.total);

  int get todayOrders => todayInvoices.length;

  double get avgOrderValue =>
      todayOrders == 0 ? 0 : todaySales / todayOrders;

  /* ================= YESTERDAY ================= */

  double get yesterdaySales {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return invoices.where((i) {
      final d = i.date.toLocal();
      return d.year == y.year && d.month == y.month && d.day == y.day;
    }).fold(0.0, (sum, i) => sum + i.total);
  }

  double get todayVsYesterdayPercent {
    if (yesterdaySales == 0) return 0.0;
    return ((todaySales - yesterdaySales) / yesterdaySales) * 100;
  }

  /* ================= DAILY SALES (7 DAYS) ================= */

  List<double> get last7DaysSales {
    final now = DateTime.now();

    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return invoices
          .where((inv) => inv.date.toLocal().year == day.year &&
                inv.date.toLocal().month == day.month &&
                inv.date.toLocal().day == day.day)
          .fold(0.0, (sum, inv) => sum + inv.total);
    });
  }

  /* ================= PEAK HOURS ================= */

  Map<int, int> get hourlyOrders {
    final Map<int, int> data = {};

    for (final inv in todayInvoices) {
      final h = inv.date.hour;
      data[h] = (data[h] ?? 0) + 1;
    }
    return data;
  }

  /* ================= TOP & LOW PRODUCTS ================= */

  Map<String, int> _weeklyProductCount(DateTime date) {
    final start = date.subtract(Duration(days: date.weekday - 1));
    final end = start.add(const Duration(days: 6));

    final Map<String, int> count = {};

    for (final inv in invoices) {
      final localDate = inv.date.toLocal();
      if (localDate.isBefore(start) || localDate.isAfter(end)) continue;

      for (final item in inv.items) {
        final String name = item['name'] ?? 'Unknown';
        final int qty = (item['qty'] as num?)?.toInt() ?? 1;

        count[name] = (count[name] ?? 0) + qty;
      }
    }
    return count;
  }

  List<MapEntry<String, int>> topProducts(DateTime weekDate) {
    final list = _weeklyProductCount(weekDate).entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list.take(3).toList();
  }

  List<MapEntry<String, int>> lowProducts(DateTime weekDate) {
    final list = _weeklyProductCount(weekDate).entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return list.take(2).toList();
  }
}
