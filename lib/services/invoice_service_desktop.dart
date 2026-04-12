import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class InvoiceServiceDesktop {
  static Database? _db;
  static Future<Database>? _openFuture;

  // ================= INIT DB =================
  static Future<Database> _database() async {
    if (_db != null && _db!.isOpen) return _db!;

    _openFuture ??= _initDbInternal();

    try {
      _db = await _openFuture;
      return _db!;
    } catch (e) {
      _openFuture = null;
      rethrow;
    }
  }

  static Future<Database> _initDbInternal() async {

    sqfliteFfiInit();

    final Directory dir = await getApplicationDocumentsDirectory();
    final String path = join(dir.path, 'billing.db');

    _db = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE bills (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              billNo TEXT,
              date TEXT,
              items TEXT,
              subtotal REAL,
              gst REAL,
              total REAL,
              paymentMode TEXT
            )
          ''');
        },
      ),
    );

    return _db!;
  }

  // ================= SAVE =================
  static Future<void> save(Map<String, dynamic> data) async {
    final db = await _database();

    /// 🔴 CRITICAL FIX
    /// sqflite cannot store List / Map directly
    final safeData = Map<String, dynamic>.from(data);

    if (safeData['items'] != null) {
      safeData['items'] = jsonEncode(safeData['items']);
    }

    await db.insert('bills', safeData);
  }

  // ================= GET ALL =================
  static Future<List<Map<String, dynamic>>> getBills() async {
    final db = await _database();

    final rows = await db.query(
      'bills',
      orderBy: 'id DESC',
    );

    /// 🔴 DECODE items back to List
    return rows.map((row) {
      final map = Map<String, dynamic>.from(row);

      if (map['items'] != null && map['items'] is String) {
        try {
          map['items'] = jsonDecode(map['items']);
        } catch (_) {
          map['items'] = [];
        }
      }

      return map;
    }).toList();
  }

  // ================= TODAY SALES =================
  static Future<double> todaySales(DateTime day) async {
    final db = await _database();

    final result = await db.rawQuery(
      '''
      SELECT SUM(total) as total
      FROM bills
      WHERE date LIKE ?
      ''',
      ['${day.toIso8601String().substring(0, 10)}%'],
    );

    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  // ================= GST TOTAL =================
  static Future<double> gstTotal() async {
    final db = await _database();

    final result =
        await db.rawQuery('SELECT SUM(gst) as gst FROM bills');

    return (result.first['gst'] as num?)?.toDouble() ?? 0.0;
  }

  // ================= DELETE (COMPAT FIX) =================
  /// Accepts:
  /// - id (int)
  /// - billNo (String)
  static Future<void> deleteBill(dynamic key) async {
    final db = await _database();

    if (key is int) {
      await db.delete(
        'bills',
        where: 'id = ?',
        whereArgs: [key],
      );
    } else {
      await db.delete(
        'bills',
        where: 'billNo = ?',
        whereArgs: [key.toString()],
      );
    }
  }

  // ================= UPDATE (COMPAT FIX) =================
  static Future<void> updateBill(
    dynamic key,
    Map<String, dynamic> updated,
  ) async {
    final db = await _database();

    final safeUpdate = Map<String, dynamic>.from(updated);

    /// 🔴 SAFE UPDATE FOR items ALSO
    if (safeUpdate['items'] != null &&
        safeUpdate['items'] is! String) {
      safeUpdate['items'] = jsonEncode(safeUpdate['items']);
    }

    if (key is int) {
      await db.update(
        'bills',
        safeUpdate,
        where: 'id = ?',
        whereArgs: [key],
      );
    } else {
      await db.update(
        'bills',
        safeUpdate,
        where: 'billNo = ?',
        whereArgs: [key.toString()],
      );
    }
  }
}
