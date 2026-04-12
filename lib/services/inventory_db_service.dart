import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/raw_material.dart';
import '../models/stock_entry.dart';
import '../models/expense_model.dart';

class InventoryDbService {
  static final InventoryDbService instance = InventoryDbService._();
  InventoryDbService._();
  factory InventoryDbService() => instance;

  static Database? _db;
  static Future<Database>? _openFuture;

  Future<Database> get database async {
    if (kIsWeb) throw StateError('Inventory DB not available on web');
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

  Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), 'inventory.db');
    return await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA journal_mode=WAL;');
        await db.execute('PRAGMA busy_timeout=5000;');
        await db.execute('PRAGMA synchronous=NORMAL;');
      },
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Raw Materials
    await db.execute('''
      CREATE TABLE IF NOT EXISTS raw_materials (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        unit TEXT NOT NULL,
        current_stock REAL DEFAULT 0,
        min_stock_level REAL DEFAULT 0,
        supplier_id TEXT,
        supplier_name TEXT,
        updated_at INTEGER
      )
    ''');

    // Stock In (Purchase)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_in (
        id TEXT PRIMARY KEY,
        material_id TEXT NOT NULL,
        material_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL,
        purchase_price REAL NOT NULL,
        total_cost REAL NOT NULL,
        supplier_name TEXT NOT NULL,
        date INTEGER NOT NULL,
        notes TEXT
      )
    ''');

    // Wastage
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wastage (
        id TEXT PRIMARY KEY,
        material_id TEXT NOT NULL,
        material_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        quantity REAL NOT NULL,
        reason TEXT NOT NULL,
        date INTEGER NOT NULL
      )
    ''');

    // Stock Adjustments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_adjustments (
        id TEXT PRIMARY KEY,
        material_id TEXT NOT NULL,
        material_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        old_qty REAL NOT NULL,
        new_qty REAL NOT NULL,
        reason TEXT NOT NULL,
        date INTEGER NOT NULL
      )
    ''');

    // Recipe Ingredients (product → raw material mapping)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recipe_ingredients (
        product_id TEXT NOT NULL,
        product_name TEXT NOT NULL,
        material_id TEXT NOT NULL,
        material_name TEXT NOT NULL,
        unit TEXT NOT NULL,
        qty_per_serving REAL NOT NULL,
        PRIMARY KEY (product_id, material_id)
      )
    ''');

    // Expense entries
    await db.execute('''
      CREATE TABLE IF NOT EXISTS expenses (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        category_name TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        date INTEGER NOT NULL,
        payment_mode TEXT NOT NULL,
        is_recurring INTEGER DEFAULT 0
      )
    ''');

    // Recurring expense templates
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_expenses (
        id TEXT PRIMARY KEY,
        category_id TEXT NOT NULL,
        category_name TEXT NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        day_of_month INTEGER NOT NULL,
        is_active INTEGER DEFAULT 1
      )
    ''');

    // Supplier payments
    await db.execute('''
      CREATE TABLE IF NOT EXISTS supplier_payments (
        id TEXT PRIMARY KEY,
        supplier_name TEXT NOT NULL,
        total_amount REAL NOT NULL,
        paid_amount REAL NOT NULL,
        description TEXT NOT NULL,
        date INTEGER NOT NULL,
        payment_mode TEXT NOT NULL
      )
    ''');
  }

  // ========================================================
  // RAW MATERIALS
  // ========================================================

  Future<List<RawMaterial>> getAllMaterials() async {
    final db = await database;
    final rows = await db.query('raw_materials', orderBy: 'name ASC');
    return rows.map((r) => RawMaterial.fromMap(r)).toList();
  }

  Future<RawMaterial?> getMaterial(String id) async {
    final db = await database;
    final rows = await db.query('raw_materials', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : RawMaterial.fromMap(rows.first);
  }

  Future<void> upsertMaterial(RawMaterial m) async {
    final db = await database;
    await db.insert('raw_materials', m.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteMaterial(String id) async {
    final db = await database;
    await db.delete('raw_materials', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<RawMaterial>> getLowStockMaterials() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM raw_materials WHERE current_stock <= min_stock_level ORDER BY current_stock ASC',
    );
    return rows.map((r) => RawMaterial.fromMap(r)).toList();
  }

  /// Reduce stock after an order (auto stock-out)
  Future<void> reduceStockForOrder(String materialId, double qty) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE raw_materials SET current_stock = MAX(0, current_stock - ?), updated_at = ? WHERE id = ?',
      [qty, DateTime.now().millisecondsSinceEpoch, materialId],
    );
  }

  // ========================================================
  // STOCK IN (PURCHASE)
  // ========================================================

  Future<List<StockIn>> getAllStockIn() async {
    final db = await database;
    final rows = await db.query('stock_in', orderBy: 'date DESC');
    return rows.map((r) => StockIn.fromMap(r)).toList();
  }

  Future<List<StockIn>> getStockInForDate(DateTime date) async {
    final db = await database;
    final start = DateTime(date.year, date.month, date.day).millisecondsSinceEpoch;
    final end = DateTime(date.year, date.month, date.day, 23, 59, 59).millisecondsSinceEpoch;
    final rows = await db.query('stock_in', where: 'date BETWEEN ? AND ?', whereArgs: [start, end]);
    return rows.map((r) => StockIn.fromMap(r)).toList();
  }

  Future<void> addStockIn(StockIn entry) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('stock_in', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      // Increase current stock
      await txn.rawUpdate(
        'UPDATE raw_materials SET current_stock = current_stock + ?, updated_at = ? WHERE id = ?',
        [entry.quantity, DateTime.now().millisecondsSinceEpoch, entry.materialId],
      );
    });
  }

  // ========================================================
  // WASTAGE
  // ========================================================

  Future<List<WastageEntry>> getAllWastage() async {
    final db = await database;
    final rows = await db.query('wastage', orderBy: 'date DESC');
    return rows.map((r) => WastageEntry.fromMap(r)).toList();
  }

  Future<void> addWastage(WastageEntry entry) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('wastage', entry.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      // Reduce current stock
      await txn.rawUpdate(
        'UPDATE raw_materials SET current_stock = MAX(0, current_stock - ?), updated_at = ? WHERE id = ?',
        [entry.quantity, DateTime.now().millisecondsSinceEpoch, entry.materialId],
      );
    });
  }

  // ========================================================
  // STOCK ADJUSTMENTS
  // ========================================================

  Future<List<StockAdjustment>> getAllAdjustments() async {
    final db = await database;
    final rows = await db.query('stock_adjustments', orderBy: 'date DESC');
    return rows.map((r) => StockAdjustment.fromMap(r)).toList();
  }

  Future<void> addAdjustment(StockAdjustment adj) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('stock_adjustments', adj.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      // Set stock to new quantity
      await txn.rawUpdate(
        'UPDATE raw_materials SET current_stock = ?, updated_at = ? WHERE id = ?',
        [adj.newQty, DateTime.now().millisecondsSinceEpoch, adj.materialId],
      );
    });
  }

  // ========================================================
  // RECIPE INGREDIENTS
  // ========================================================

  Future<List<RecipeIngredient>> getRecipeForProduct(String productId) async {
    final db = await database;
    final rows = await db.query('recipe_ingredients', where: 'product_id = ?', whereArgs: [productId]);
    return rows.map((r) => RecipeIngredient.fromMap(r)).toList();
  }

  Future<List<RecipeIngredient>> getAllRecipes() async {
    final db = await database;
    final rows = await db.query('recipe_ingredients', orderBy: 'product_name ASC');
    return rows.map((r) => RecipeIngredient.fromMap(r)).toList();
  }

  Future<void> upsertRecipeIngredient(RecipeIngredient ri) async {
    final db = await database;
    await db.insert('recipe_ingredients', ri.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRecipeIngredient(String productId, String materialId) async {
    final db = await database;
    await db.delete('recipe_ingredients',
        where: 'product_id = ? AND material_id = ?', whereArgs: [productId, materialId]);
  }

  Future<void> deleteAllRecipesForProduct(String productId) async {
    final db = await database;
    await db.delete('recipe_ingredients', where: 'product_id = ?', whereArgs: [productId]);
  }

  /// Called on each order item to auto-deduct ingredients
  Future<void> deductIngredientsForOrder(String productId, int quantity) async {
    final ingredients = await getRecipeForProduct(productId);
    for (final ing in ingredients) {
      final totalDeduct = ing.quantityPerServing * quantity;
      await reduceStockForOrder(ing.materialId, totalDeduct);
    }
  }

  // ========================================================
  // EXPENSES
  // ========================================================

  Future<List<ExpenseEntry>> getAllExpenses() async {
    final db = await database;
    final rows = await db.query('expenses', orderBy: 'date DESC');
    return rows.map((r) => ExpenseEntry.fromMap(r)).toList();
  }

  Future<List<ExpenseEntry>> getExpensesForMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final rows = await db.query('expenses',
        where: 'date >= ? AND date < ?', whereArgs: [start, end], orderBy: 'date DESC');
    return rows.map((r) => ExpenseEntry.fromMap(r)).toList();
  }

  Future<List<ExpenseEntry>> getExpensesForToday() async {
    final now = DateTime.now();
    return getExpensesForDay(now);
  }

  Future<List<ExpenseEntry>> getExpensesForDay(DateTime day) async {
    final db = await database;
    final start = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;
    final end = DateTime(day.year, day.month, day.day, 23, 59, 59).millisecondsSinceEpoch;
    final rows = await db.query('expenses',
        where: 'date BETWEEN ? AND ?', whereArgs: [start, end], orderBy: 'date DESC');
    return rows.map((r) => ExpenseEntry.fromMap(r)).toList();
  }

  Future<void> addExpense(ExpenseEntry e) async {
    final db = await database;
    await db.insert('expenses', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteExpense(String id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ========================================================
  // RECURRING EXPENSES
  // ========================================================

  Future<List<RecurringExpense>> getRecurringExpenses() async {
    final db = await database;
    final rows = await db.query('recurring_expenses', orderBy: 'day_of_month ASC');
    return rows.map((r) => RecurringExpense.fromMap(r)).toList();
  }

  Future<void> upsertRecurringExpense(RecurringExpense re) async {
    final db = await database;
    await db.insert('recurring_expenses', re.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteRecurringExpense(String id) async {
    final db = await database;
    await db.delete('recurring_expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ========================================================
  // SUPPLIER PAYMENTS
  // ========================================================

  Future<List<SupplierPayment>> getAllSupplierPayments() async {
    final db = await database;
    final rows = await db.query('supplier_payments', orderBy: 'date DESC');
    return rows.map((r) => SupplierPayment.fromMap(r)).toList();
  }

  Future<List<SupplierPayment>> getPendingSupplierPayments() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT * FROM supplier_payments WHERE paid_amount < total_amount ORDER BY date DESC',
    );
    return rows.map((r) => SupplierPayment.fromMap(r)).toList();
  }

  Future<void> upsertSupplierPayment(SupplierPayment sp) async {
    final db = await database;
    await db.insert('supplier_payments', sp.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteSupplierPayment(String id) async {
    final db = await database;
    await db.delete('supplier_payments', where: 'id = ?', whereArgs: [id]);
  }

  // ========================================================
  // REPORTS / ANALYTICS
  // ========================================================

  /// Total purchase cost for a month
  Future<double> getTotalPurchaseCostForMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT SUM(total_cost) as total FROM stock_in WHERE date >= ? AND date < ?',
      [start, end],
    );
    return (result.first['total'] as num? ?? 0).toDouble();
  }

  /// Total expense for a month
  Future<double> getTotalExpenseForMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM expenses WHERE date >= ? AND date < ?',
      [start, end],
    );
    return (result.first['total'] as num? ?? 0).toDouble();
  }

  /// Category-wise expense for a month
  Future<Map<String, double>> getCategoryExpenseForMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT category_name, SUM(amount) as total FROM expenses WHERE date >= ? AND date < ? GROUP BY category_name',
      [start, end],
    );
    return {for (final r in rows) r['category_name'] as String: (r['total'] as num).toDouble()};
  }

  /// Total wastage cost (qty-based — no price, just quantity summary)
  Future<Map<String, double>> getWastageSummaryForMonth(int year, int month) async {
    final db = await database;
    final start = DateTime(year, month, 1).millisecondsSinceEpoch;
    final end = DateTime(year, month + 1, 1).millisecondsSinceEpoch;
    final rows = await db.rawQuery(
      'SELECT material_name, unit, SUM(quantity) as total FROM wastage WHERE date >= ? AND date < ? GROUP BY material_id',
      [start, end],
    );
    return {
      for (final r in rows)
        '${r['material_name']} (${r['unit']})': (r['total'] as num).toDouble()
    };
  }
}
