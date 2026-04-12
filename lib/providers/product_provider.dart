import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;

  // ================= GETTERS =================
  
  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;

  Product? getById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Product? getProductByCode(String code) => getById(code);
  Product? getProductById(String id) => getById(id);

  // ================= REMOTE OPERATIONS =================

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    
    final remoteProducts = await ApiService.getProducts();
    _products = remoteProducts;
    
    _isLoading = false;
    notifyListeners();
  }

  /// ✅ UPDATE FROM REMOTE: UI update triggered by external sync/broadcast
  void updateFromRemote(String productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    _products[index] = _products[index].copyWith(
      quantity: quantity,
      isAvailable: quantity > 0,
    );
    notifyListeners();
  }

  // ================= STOCK CONTROL (COMPATIBILITY) =================

  bool hasStock(String productId) {
    final product = getById(productId);
    return product != null && product.quantity > 0;
  }

  bool hasEnoughStock(String productId, int requiredQty) {
    final product = getById(productId);
    return (product != null && product.quantity >= requiredQty);
  }

  // Legacy method used by BillingProvider
  bool canAddToCart(String productId, int quantity) {
    return hasEnoughStock(productId, quantity);
  }

  // Stock reduction is usually handled as part of order creation on the server
  // This updates local state for immediate UI feedback.
  void reduceStock({required String productId, required int quantity}) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    final currentStock = _products[index].quantity;
    final updatedStock = (currentStock - quantity);
    
    _products[index] = _products[index].copyWith(
      quantity: updatedStock < 0 ? 0 : updatedStock,
      isAvailable: updatedStock > 0,
    );
    notifyListeners();
  }

  // Legacy method used by BillingProvider
  void increaseStock(String productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    final currentStock = _products[index].quantity;
    final updatedStock = currentStock + quantity;
    
    _products[index] = _products[index].copyWith(
      quantity: updatedStock,
      isAvailable: updatedStock > 0,
    );
    notifyListeners();
  }

  // Legacy method used by KitchenMenuControlScreen
  void setStock({required String productId, required int quantity}) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    _products[index] = _products[index].copyWith(
      quantity: quantity,
      isAvailable: quantity > 0,
    );
    notifyListeners();
  }

  // Legacy method used by KitchenMenuControlScreen
  void updateAvailability({required String productId, required bool isAvailable}) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index == -1) return;

    _products[index] = _products[index].copyWith(
      isAvailable: isAvailable,
      quantity: isAvailable ? _products[index].quantity : 0,
    );
    notifyListeners();
  }

  // ================= ADMIN OPERATIONS =================

  Future<bool> addProduct(Product product, {File? imageFile, Uint8List? imageBytes}) async {
    final success = await ApiService.createProduct(product.toMap(), imageFile: imageFile, imageBytes: imageBytes);
    if (success) {
      await loadProducts(); // Refresh from server
    }
    return success;
  }

  Future<bool> updateProduct(Product updated, {File? imageFile, Uint8List? imageBytes}) async {
    final success = await ApiService.updateProductMetadata(updated.id, updated.toMap(), imageFile: imageFile, imageBytes: imageBytes);
    if (success) {
      await loadProducts(); // Refresh from server
    }
    return success;
  }

  Future<bool> removeProduct(String id) async {
    final success = await ApiService.deleteProduct(id);
    if (success) {
      _products.removeWhere((p) => p.id == id);
      notifyListeners();
    }
    return success;
  }

  List<Product> byCategory(String category) {
    return _products.where((p) => (category == 'All' || p.category == category)).toList();
  }
}