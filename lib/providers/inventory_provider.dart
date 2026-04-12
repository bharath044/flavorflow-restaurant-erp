import 'package:flutter/foundation.dart';
import '../models/raw_material.dart';
import '../models/stock_entry.dart';
import '../services/inventory_db_service.dart';
import '../services/api_service.dart'; // 🔥 NEW: Required for cloud sync

class InventoryProvider extends ChangeNotifier {
  // ─── LOCAL DB DEACTIVATED: All data now syncs via MySQL ───

  InventoryProvider() {
    loadAll();
  }

  List<RawMaterial> _materials = [];
  List<StockIn> _stockIns = [];
  List<WastageEntry> _wastage = [];
  List<StockAdjustment> _adjustments = [];
  List<RecipeIngredient> _recipes = [];

  List<RawMaterial> get materials => List.unmodifiable(_materials);
  List<RawMaterial> get lowStockMaterials =>
      _materials.where((m) => m.isLowStock).toList();
  List<StockIn> get stockIns => List.unmodifiable(_stockIns);
  List<WastageEntry> get wastage => List.unmodifiable(_wastage);
  List<StockAdjustment> get adjustments => List.unmodifiable(_adjustments);
  List<RecipeIngredient> get recipes => List.unmodifiable(_recipes);

  int get lowStockCount => lowStockMaterials.length;

  // =====================================================
  // LOAD
  // =====================================================
  Future<void> loadAll() async {
    // ─── GLOBAL SYNC ───
    await Future.wait([
      _loadMaterials(),
      _loadStockIn(),
      _loadWastage(),
      _loadAdjustments(),
      _loadRecipes(),
    ]);
    notifyListeners();
  }

  Future<void> _loadMaterials() async {
    final raw = await ApiService.getRawMaterials();
    _materials = raw.map((m) => RawMaterial.fromMap(m)).toList();
  }

  Future<void> _loadStockIn() async {
    final raw = await ApiService.getInventoryHistory('stock_in');
    _stockIns = raw.map((m) => StockIn.fromMap(m)).toList();
  }

  Future<void> _loadWastage() async {
    final raw = await ApiService.getInventoryHistory('wastage');
    _wastage = raw.map((m) => WastageEntry.fromMap(m)).toList();
  }

  Future<void> _loadAdjustments() async {
    final raw = await ApiService.getInventoryHistory('adjustments');
    _adjustments = raw.map((m) => StockAdjustment.fromMap(m)).toList();
  }

  Future<void> _loadRecipes() async {
    final raw = await ApiService.getRecipes();
    _recipes = raw.map((r) => RecipeIngredient.fromMap(r)).toList();
  }

  // =====================================================
  // RAW MATERIALS
  // =====================================================
  Future<void> addMaterial(RawMaterial m) async {
    final success = await ApiService.upsertRawMaterial(m.toMap());
    if (success) {
      await _loadMaterials();
      notifyListeners();
    }
  }

  Future<void> updateMaterial(RawMaterial m) async {
    final success = await ApiService.upsertRawMaterial(m.toMap());
    if (success) {
      await _loadMaterials();
      notifyListeners();
    }
  }

  Future<void> deleteMaterial(String id) async {
    final success = await ApiService.deleteRawMaterial(id);
    if (success) {
      await _loadMaterials();
      notifyListeners();
    }
  }

  RawMaterial? getMaterialById(String id) {
    try {
      return _materials.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  // =====================================================
  // STOCK IN
  // =====================================================
  Future<void> addStockIn(StockIn entry) async {
    // 1. Update material current_stock
    await ApiService.recordInventoryTransaction(entry.materialId, entry.quantity, 'in');
    // 2. Save history log
    await ApiService.saveInventoryHistory('stock_in', entry.toMap());
    
    await loadAll();
  }

  Future<void> deleteStockIn(String id) async {
    final success = await ApiService.deleteInventoryHistory('stock_in', id);
    if (success) {
      await loadAll();
    }
  }

  // =====================================================
  // WASTAGE
  // =====================================================
  Future<void> addWastage(WastageEntry entry) async {
    // 1. Update material current_stock
    await ApiService.recordInventoryTransaction(entry.materialId, entry.quantity, 'waste');
    // 2. Save history log
    await ApiService.saveInventoryHistory('wastage', entry.toMap());
    
    await loadAll();
  }

  Future<void> deleteWastage(String id) async {
    final success = await ApiService.deleteInventoryHistory('wastage', id);
    if (success) {
      await loadAll();
    }
  }

  // =====================================================
  // ADJUSTMENTS
  // =====================================================
  Future<void> addAdjustment(StockAdjustment adj) async {
    // 1. Update material current_stock
    // Calculate difference (delta)
    double delta = adj.newQty - adj.oldQty;
    await ApiService.recordInventoryTransaction(adj.materialId, delta.abs(), delta >= 0 ? 'in' : 'out');
    
    // 2. Save history log
    await ApiService.saveInventoryHistory('adjustments', adj.toMap());
    
    await loadAll();
  }

  Future<void> deleteAdjustment(String id) async {
    final success = await ApiService.deleteInventoryHistory('adjustments', id);
    if (success) {
      await loadAll();
    }
  }

  // =====================================================
  // RECIPES
  // =====================================================
  List<RecipeIngredient> getRecipeForProduct(String productId) =>
      _recipes.where((r) => r.productId == productId).toList();

  Future<void> upsertRecipeIngredient(RecipeIngredient ri) async {
    await ApiService.saveRecipe(ri.toMap());
    await _loadRecipes();
    notifyListeners();
  }

  Future<void> deleteRecipeIngredient(String productId, String materialId) async {
    await ApiService.deleteRecipe(productId, materialId);
    await _loadRecipes();
    notifyListeners();
  }

  Future<void> saveRecipeForProduct(
      String productId, String productName, List<RecipeIngredient> ingredients) async {
    // Delete old
    final old = getRecipeForProduct(productId);
    for (final o in old) {
      await ApiService.deleteRecipe(productId, o.materialId);
    }
    // Save new
    for (final ing in ingredients) {
      await ApiService.saveRecipe(ing.toMap());
    }
    await _loadRecipes();
    notifyListeners();
  }

  // =====================================================
  // AUTO STOCK DEDUCTION (called from billing)
  // =====================================================
  Future<void> deductIngredientsForOrder(String productId, int qty) async {
    final recipe = getRecipeForProduct(productId);
    for (final ing in recipe) {
      final totalDeduct = ing.quantityPerServing * qty;
      await ApiService.recordInventoryTransaction(ing.materialId, totalDeduct, 'out');
    }
    await _loadMaterials();
    notifyListeners();
  }

  // =====================================================
  // REPORT DATA
  // =====================================================
  Future<double> getPurchaseCostForMonth(int year, int month) async {
    // This part should technically use the API once logic is implemented there.
    // For now, returning 0 to prevent crashes.
    return 0;
  }

  Future<Map<String, double>> getWastageSummary(int year, int month) async {
    return {};
  }
}
