import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/api_service.dart';

// NOTE: We avoid dart:io 'File' to support Flutter Web Compilation.
// imageData (Uint8List) is used for cross-platform support.

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

  // Compatibility helpers
  bool hasStock(String productId) => (getById(productId)?.quantity ?? 0) > 0;
  void reduceStock({required String productId, required int quantity}) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final newQty = (_products[index].quantity - quantity).clamp(0, 10000);
      _products[index] = _products[index].copyWith(quantity: newQty, isAvailable: newQty > 0);
      notifyListeners();
    }
  }
}