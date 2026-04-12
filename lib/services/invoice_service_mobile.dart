import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class InvoiceServiceImpl {
  static Database? _db;
  static Future<Database>? _openFuture;

  static Future<Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
    
    _openFuture ??= _openDb();
    
    try {
      _db = await _openFuture;
      return _db!;
    } catch (e) {
      _openFuture = null;
      rethrow;
    }
  }

  // ================= OPEN DATABASE =================
  static Future<Database> _openDb() async {
    final path = join(await getDatabasesPath(), 'billing.db');

    return openDatabase(
      path,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE invoices (
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
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE invoices ADD COLUMN paymentMode TEXT');
    }
  }

  // ================= METHODS =================

  static Future<void> save(Map<String, dynamic> data) async {
    final database = await db;
    final safeData = Map<String, dynamic>.from(data);
    
    if (safeData['items'] != null && safeData['items'] is! String) {
      safeData['items'] = jsonEncode(safeData['items']);
    }
    
    await database.insert('invoices', safeData);
  }

  static Future<List<Map<String, dynamic>>> getBills() async {
    final database = await db;
    final rows = await database.query('invoices', orderBy: 'id DESC');
    
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

  static Future<double> todaySales(DateTime day) async {
    final database = await db;
    final dateStr = day.toIso8601String().substring(0, 10);
    
    final result = await database.rawQuery(
      'SELECT SUM(total) as total FROM invoices WHERE date LIKE ?',
      ['$dateStr%']
    );
    
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<double> gstTotal() async {
    final database = await db;
    final result = await database.rawQuery('SELECT SUM(gst) as gst FROM invoices');
    return (result.first['gst'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<void> deleteBill(dynamic key) async {
    final database = await db;
    if (key is int) {
      await database.delete('invoices', where: 'id = ?', whereArgs: [key]);
    } else {
      await database.delete('invoices', where: 'billNo = ?', whereArgs: [key.toString()]);
    }
  }

  static Future<void> updateBill(dynamic key, Map<String, dynamic> updated) async {
    final database = await db;
    final safeUpdate = Map<String, dynamic>.from(updated);
    
    if (safeUpdate['items'] != null && safeUpdate['items'] is! String) {
      safeUpdate['items'] = jsonEncode(safeUpdate['items']);
    }

    if (key is int) {
      await database.update('invoices', safeUpdate, where: 'id = ?', whereArgs: [key]);
    } else {
      await database.update('invoices', safeUpdate, where: 'billNo = ?', whereArgs: [key.toString()]);
    }
  }
}
