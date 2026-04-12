import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class InvoiceServiceImpl {
  static Database? _db;
  static Future<Database>? _openFuture;

  static bool get _isDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  static Future<Database> get _database async {
    if (_db != null && _db!.isOpen) return _db!;
    _openFuture ??= _initDb();
    try {
      _db = await _openFuture;
      return _db!;
    } catch (e) {
      _openFuture = null;
      rethrow;
    }
  }

  static Future<Database> _initDb() async {
    if (_isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await getApplicationDocumentsDirectory();
      final path = join(dir.path, 'billing.db');
      return await openDatabase(
        path,
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
      );
    } else {
      // Mobile (Android / iOS)
      final path = join(await getDatabasesPath(), 'billing.db');
      return await openDatabase(
        path,
        version: 2,
        onCreate: (db, _) async {
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
        },
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 2) {
            await db.execute('ALTER TABLE invoices ADD COLUMN paymentMode TEXT');
          }
        },
      );
    }
  }

  static String get _tableName => _isDesktop ? 'bills' : 'invoices';

  static Future<void> save(Map<String, dynamic> data) async {
    final db = await _database;
    final safeData = Map<String, dynamic>.from(data);
    if (safeData['items'] != null && safeData['items'] is! String) {
      safeData['items'] = jsonEncode(safeData['items']);
    }
    await db.insert(_tableName, safeData);
  }

  static Future<List<Map<String, dynamic>>> getBills() async {
    final db = await _database;
    final rows = await db.query(_tableName, orderBy: 'id DESC');
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
    final db = await _database;
    final dateStr = day.toIso8601String().substring(0, 10);
    final result = await db.rawQuery(
      'SELECT SUM(total) as total FROM $_tableName WHERE date LIKE ?',
      ['$dateStr%']
    );
    return (result.first['total'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<double> gstTotal() async {
    final db = await _database;
    final result = await db.rawQuery('SELECT SUM(gst) as gst FROM $_tableName');
    return (result.first['gst'] as num?)?.toDouble() ?? 0.0;
  }

  static Future<void> deleteBill(dynamic key) async {
    final db = await _database;
    if (key is int) {
      await db.delete(_tableName, where: 'id = ?', whereArgs: [key]);
    } else {
      await db.delete(_tableName, where: 'billNo = ?', whereArgs: [key.toString()]);
    }
  }

  static Future<void> updateBill(dynamic key, Map<String, dynamic> updated) async {
    final db = await _database;
    final safeUpdate = Map<String, dynamic>.from(updated);
    if (safeUpdate['items'] != null && safeUpdate['items'] is! String) {
      safeUpdate['items'] = jsonEncode(safeUpdate['items']);
    }
    if (key is int) {
      await db.update(_tableName, safeUpdate, where: 'id = ?', whereArgs: [key]);
    } else {
      await db.update(_tableName, safeUpdate, where: 'billNo = ?', whereArgs: [key.toString()]);
    }
  }
}
