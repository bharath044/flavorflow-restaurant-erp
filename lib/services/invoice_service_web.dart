import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:idb_shim/idb_browser.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class InvoiceServiceImpl {
  static const String _dbName = 'billing_db';
  static const String _storeName = 'invoices';

  // ================= OPEN DB =================
  static Future<Database> _openDb() async {
    final factory = getIdbFactory();
    if (factory == null) {
      throw Exception('IndexedDB not supported');
    }

    return factory.open(
      _dbName,
      version: 1, // DO NOT CHANGE
      onUpgradeNeeded: (e) {
        final db = e.database;
        if (!db.objectStoreNames.contains(_storeName)) {
          db.createObjectStore(
            _storeName,
            autoIncrement: true,
          );
        }
      },
    );
  }

  // ================= SAVE BILL =================
  static Future<void> save(Map<String, dynamic> data) async {
    final db = await _openDb();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);

    await store.add(jsonEncode(data));

    await txn.completed;
    db.close();

    if (kIsWeb) {
      await _printBillWeb(data);
    }
  }

  // ================= GET ALL BILLS =================
  static Future<List<Map<String, dynamic>>> getBills() async {
    final db = await _openDb();
    final txn = db.transaction(_storeName, idbModeReadOnly);
    final store = txn.objectStore(_storeName);

    final List<Map<String, dynamic>> bills = [];

    await store.openCursor(autoAdvance: true).listen((cursor) {
      final bill =
          Map<String, dynamic>.from(jsonDecode(cursor.value as String));

      bill['id'] = cursor.key; // 🔥 Consistent ID across platforms
      bill['_key'] = cursor.key; // attach key ONLY for UI

      bills.add(bill);
    }).asFuture();

    await txn.completed;
    db.close();

    return bills.reversed.toList();
  }

  // ================= STATS =================
  static Future<double> todaySales(DateTime day) async {
    final bills = await getBills();
    final dateStr = day.toIso8601String().substring(0, 10);
    
    double total = 0;
    for (final b in bills) {
      final bDate = b['date']?.toString().substring(0, 10);
      if (bDate == dateStr) {
        total += (b['total'] as num?)?.toDouble() ?? 0.0;
      }
    }
    return total;
  }

  static Future<double> gstTotal() async {
    final bills = await getBills();
    double total = 0;
    for (final b in bills) {
      total += (b['gst'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  // ================= DELETE BILL =================
  static Future<void> deleteBill(dynamic key) async {
    final db = await _openDb();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);

    await store.delete(key);

    await txn.completed;
    db.close();
  }

  // ================= UPDATE BILL =================
  static Future<void> updateBill(
    dynamic key,
    Map<String, dynamic> updatedBill,
  ) async {
    final db = await _openDb();
    final txn = db.transaction(_storeName, idbModeReadWrite);
    final store = txn.objectStore(_storeName);

    // 🔥 CLEAN DATA BEFORE SAVE
    final clean = Map<String, dynamic>.from(updatedBill);

    clean.remove('_key'); // remove DB key
    clean['items'] = jsonEncode(clean['items']); // convert back to string

    await store.put(jsonEncode(clean), key);

    await txn.completed;
    db.close();
  }

  // ================= WEB PRINT =================
  static Future<void> _printBillWeb(Map<String, dynamic> bill) async {
    final pdf = pw.Document();

    final List items =
        bill['items'] is String
            ? jsonDecode(bill['items'])
            : bill['items'];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          58 * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4,
        ),
        build: (_) {
          return pw.Text("Bill Printed");
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => pdf.save());
  }
}
