import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _products = [];
  bool _isLoading = false;

  List<Product> get products => List.unmodifiable(_products);
  bool get isLoading => _isLoading;

  Product? getById(String id) {
    try {
      return _products.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Product? getProductById(String id) => getById(id);
  Product? getProductByCode(String code) => getById(code);

  List<Product> byCategory(String category) {
    return _products.where((p) => (category == 'All' || p.category == category)).toList();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    _products = await ApiService.getProducts();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> addProduct(Product product, {Uint8List? imageBytes}) async {
    final success = await ApiService.createProduct(product.toMap(), imageBytes: imageBytes);
    if (success) await loadProducts();
    return success;
  }

  Future<bool> updateProduct(Product updated, {Uint8List? imageBytes}) async {
    final success = await ApiService.updateProductMetadata(updated.id, updated.toMap(), imageBytes: imageBytes);
    if (success) await loadProducts();
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

  // ================= COMPATIBILITY METHODS =================
  
  bool hasStock(String productId) => (getById(productId)?.quantity ?? 0) > 0;
  
  bool hasEnoughStock(String productId, int requiredQty) {
    final p = getById(productId);
    return (p != null && (p.quantity >= requiredQty || !p.isAvailable));
  }

  bool canAddToCart(String productId, int quantity) => hasEnoughStock(productId, quantity);

  void reduceStock({required String productId, required int quantity}) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final newQty = (_products[index].quantity - quantity).clamp(0, 100000);
      _products[index] = _products[index].copyWith(quantity: newQty, isAvailable: newQty > 0);
      notifyListeners();
    }
  }

  void increaseStock(String productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final newQty = _products[index].quantity + quantity;
      _products[index] = _products[index].copyWith(quantity: newQty, isAvailable: newQty > 0);
      notifyListeners();
    }
  }

  void setStock({required String productId, required int quantity}) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(quantity: quantity, isAvailable: quantity > 0);
      notifyListeners();
    }
  }

  void updateAvailability({required String productId, required bool isAvailable}) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(isAvailable: isAvailable);
      notifyListeners();
    }
  }

  void updateFromRemote(String productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      _products[index] = _products[index].copyWith(quantity: quantity, isAvailable: quantity > 0);
      notifyListeners();
    }
  }
}