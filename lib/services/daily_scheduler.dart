import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/inventory_db_service.dart';
import 'email_service.dart';
import 'report_settings_service.dart';

class DailyScheduler {
  static Timer? _timer;

  static void start() {
    if (kIsWeb) {
      debugPrint('ℹ️ DailyScheduler: Skipping on Web.');
      return;
    }
    _schedule();
  }

  static void stop() => _timer?.cancel();

  static void _schedule() {
    final now = DateTime.now();
    final runTime = DateTime(
      now.year, now.month, now.day,
      ReportSettingsService.hour,
      ReportSettingsService.minute,
    );
    final next =
        now.isAfter(runTime) ? runTime.add(const Duration(days: 1)) : runTime;

    _timer = Timer(next.difference(now), () async {
      await runNow(); // fire the report
      _schedule();    // reschedule for next day
    });

    debugPrint('⏰ DailyScheduler: next run at $next');
  }

  /// Public method — callable from "Send Now" test button too
  static Future<void> runNow() async {
    try {
      final today     = DateTime.now();
      final dateLabel = DateFormat('yyyy-MM-dd').format(today);

      // ── 1. Load today's invoices from ApiService ──────────────
      final startOfDay = DateFormat('yyyy-MM-dd 00:00:00').format(today);
      final endOfDay   = DateFormat('yyyy-MM-dd 23:59:59').format(today);
      
      final todayInvoices = await ApiService.getInvoices(from: startOfDay, to: endOfDay);

      if (todayInvoices.isEmpty) {
        debugPrint('ℹ️ DailyScheduler: No invoices today, skipping email.');
        return;
      }

      // ── 2. Compute payment totals ─────────────────────────────
      double totalSales = 0;
      double cash       = 0;
      double online     = 0;

      for (final inv in todayInvoices) {
        totalSales += inv.total;
        if (inv.paymentMode.toLowerCase() == 'cash') {
          cash += inv.total;
        } else {
          online += inv.total;
        }
      }

      // ── 3. Compute product-level breakdown ────────────────────
      final Map<String, Map<String, dynamic>> productMap = {};

      for (final inv in todayInvoices) {
        for (final item in inv.items) {
          final name    = item['name']?.toString() ?? 'Unknown';
          final qty     = (item['qty']    as num?)?.toInt()    ?? 0;
          final price   = (item['price']  as num?)?.toDouble() ?? 0.0;
          final revenue = price * qty;

          if (!productMap.containsKey(name)) {
            productMap[name] = {'qty': 0, 'revenue': 0.0};
          }
          productMap[name]!['qty']     = (productMap[name]!['qty'] as int) + qty;
          productMap[name]!['revenue'] = (productMap[name]!['revenue'] as double) + revenue;
        }
      }

      final itemList = productMap.entries
          .map((e) => {'name': e.key, 'qty': e.value['qty'], 'revenue': e.value['revenue']})
          .toList()
        ..sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));

      // ── 4. Fetch today's expenses ─────────────────────────────
      double todayExpense = 0.0;
      try {
        final expDb  = InventoryDbService.instance;
        final exps   = await expDb.getAllExpenses();
        todayExpense = exps
            .where((e) =>
                e.date.year  == today.year &&
                e.date.month == today.month &&
                e.date.day   == today.day)
            .fold(0.0, (sum, e) => sum + e.amount);
      } catch (e) {
        debugPrint('⚠️ DailyScheduler: Could not fetch expenses: $e');
      }

      // ── 5. Send email ─────────────────────────────────────────
      await EmailService.sendReport(
        null, // no PDF file — HTML email is sufficient
        dateLabel,
        ReportSettingsService.email,
        summary: {
          'date'   : dateLabel,
          'orders' : todayInvoices.length,
          'total'  : totalSales,
          'cash'   : cash,
          'online' : online,
        },
        items  : itemList,
        expense: todayExpense,
      );

      debugPrint('✅ DailyScheduler: Report sent for $dateLabel');
    } catch (e, st) {
      debugPrint('❌ DailyScheduler Error: $e\n$st');
    }
  }
}
