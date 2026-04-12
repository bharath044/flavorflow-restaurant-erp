import 'package:flutter/foundation.dart';
import '../models/expense_model.dart';
import '../services/inventory_db_service.dart';
import '../services/api_service.dart'; // 🔥 NEW: Required for cloud sync

class ExpenseProvider extends ChangeNotifier {
  // ─── LOCAL DB DEACTIVATED: All financial data now syncs via MySQL ───

  ExpenseProvider() {
    loadAll();
  }

  List<ExpenseEntry> _expenses = [];
  List<RecurringExpense> _recurring = [];
  List<SupplierPayment> _supplierPayments = [];
  List<ExpenseCategory> _categories = ExpenseCategory.defaults;

  List<ExpenseEntry> get expenses => List.unmodifiable(_expenses);
  List<RecurringExpense> get recurring => List.unmodifiable(_recurring);
  List<SupplierPayment> get supplierPayments => List.unmodifiable(_supplierPayments);
  List<ExpenseCategory> get categories => List.unmodifiable(_categories);

  double get totalPendingSupplier =>
      _supplierPayments.fold(0, (s, p) => s + p.pendingAmount);

  // =====================================================
  // LOAD
  // =====================================================
  Future<void> loadAll() async {
    // ─── GLOBAL SYNC ───
    await Future.wait([
      _loadExpenses(),
      _loadRecurring(),
      _loadSupplierPayments(),
    ]);
    notifyListeners();
  }

  Future<void> _loadExpenses() async {
    final raw = await ApiService.getExpenses();
    _expenses = raw.map((e) => ExpenseEntry.fromMap(e)).toList();
  }

  Future<void> _loadRecurring() async {
    final raw = await ApiService.getRecurringExpenses();
    _recurring = raw.map((r) => RecurringExpense.fromMap(r)).toList();
  }

  Future<void> _loadSupplierPayments() async {
    final raw = await ApiService.getSupplierPayments();
    _supplierPayments = raw.map((sp) => SupplierPayment.fromMap(sp)).toList();
  }

  // =====================================================
  // TODAY / MONTH VIEWS
  // =====================================================
  List<ExpenseEntry> get todayExpenses {
    final now = DateTime.now();
    return _expenses.where((e) {
      return e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day;
    }).toList();
  }

  List<ExpenseEntry> get thisMonthExpenses {
    final now = DateTime.now();
    return _expenses
        .where((e) => e.date.year == now.year && e.date.month == now.month)
        .toList();
  }

  double get todayTotal =>
      todayExpenses.fold(0, (s, e) => s + e.amount);

  double get monthTotal =>
      thisMonthExpenses.fold(0, (s, e) => s + e.amount);

  Map<String, double> get categoryBreakdownThisMonth {
    final Map<String, double> result = {};
    for (final e in thisMonthExpenses) {
      result[e.categoryName] = (result[e.categoryName] ?? 0) + e.amount;
    }
    return result;
  }

  // =====================================================
  // EXPENSE ENTRY
  // =====================================================
  Future<void> addExpense(ExpenseEntry entry) async {
    final success = await ApiService.upsertExpense(entry.toMap());
    if (success) {
       await _loadExpenses();
       notifyListeners();
    }
  }

  Future<void> deleteExpense(String id) async {
    final success = await ApiService.deleteExpense(id);
    if (success) {
      await _loadExpenses();
      notifyListeners();
    }
  }

  // =====================================================
  // RECURRING
  // =====================================================
  Future<void> addRecurring(RecurringExpense re) async {
    await ApiService.saveRecurringExpense(re.toMap());
    await _loadRecurring();
    notifyListeners();
  }

  Future<void> deleteRecurring(String id) async {
    await ApiService.deleteRecurringExpense(id);
    await _loadRecurring();
    notifyListeners();
  }

  // =====================================================
  // SUPPLIER PAYMENTS
  // =====================================================
  Future<void> addSupplierPayment(SupplierPayment sp) async {
    await ApiService.saveSupplierPayment(sp.toMap());
    await _loadSupplierPayments();
    notifyListeners();
  }

  Future<void> deleteSupplierPayment(String id) async {
    await ApiService.deleteSupplierPayment(id);
    await _loadSupplierPayments();
    notifyListeners();
  }

  // =====================================================
  // PROFIT CALCULATION
  // =====================================================
  double profitForMonth(double salesRevenue, int year, int month) {
    final now = DateTime.now();
    final useYear = year;
    final useMonth = month;
    final exp = _expenses.where((e) =>
        e.date.year == useYear && e.date.month == useMonth).fold(0.0, (s, e) => s + e.amount);
    return salesRevenue - exp;
  }

  Future<double> getMonthExpense(int year, int month) async {
    // Should use API once analytics logic is moved there.
    return 0;
  }

  Future<Map<String, double>> getCategoryExpense(int year, int month) async {
    return breakdownForMonth(year, month);
  }

  Map<String, double> breakdownForMonth(int year, int month) {
    final Map<String, double> result = {};
    for (final e in _expenses.where((e) => e.date.year == year && e.date.month == month)) {
      result[e.categoryName] = (result[e.categoryName] ?? 0) + e.amount;
    }
    return result;
  }
}
