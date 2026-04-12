import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/cart_item.dart';
import '../models/invoice.dart';
import '../providers/product_provider.dart';
import '../providers/order_provider.dart';
import '../services/api_service.dart';

class BillingProvider with ChangeNotifier {
  BillingProvider();

  // ===============================
  // CART (UI STATE ONLY)
  // ===============================
  final List<CartItem> _items = []; 
  List<CartItem> get cartItems => _items;

  /// ✅ FIXED: SYNC WITH STOCK
  void syncWithStock(ProductProvider productProvider) {
    _items.removeWhere((item) {
      final product = productProvider.getById(item.product.id);
      return product == null || product.quantity <= 0;
    });
    notifyListeners();
  }

  /// 🛡️ SAFETY METHOD: CLAMP CART TO STOCK
  void clampCartToStock(String productId, int stock) {
    final index = _items.indexWhere((e) => e.product.id == productId);
    if (index == -1) return;

    if (_items[index].quantity > stock) {
      _items[index].quantity = stock;
      if (_items[index].quantity <= 0) {
        _items.removeAt(index);
      }
      notifyListeners();
    }
  }

  /// ✅ addItem (UI State Change Only)
  bool addItem({
    required String productId, 
    required ProductProvider productProvider,
    required OrderProvider orderProvider, 
    String? tableId, 
  }) {
    final product = productProvider.getById(productId);
    if (product == null) return false;

    // Check availability in memory before adding
    if (!productProvider.canAddToCart(productId, 1)) {
      debugPrint('🚫 Out of stock for ${product.name}');
      return false;
    }

    final existingIndex = _items.indexWhere((i) => i.product.id == productId);

    if (existingIndex != -1) {
      _items[existingIndex].quantity++;
      _items[existingIndex].updatedAt = DateTime.now();
    } else {
      _items.add(
        CartItem(product: product, quantity: 1),
      );
    }

    // Update the UI stock counter immediately (Memory only)
    productProvider.reduceStock(productId: productId, quantity: 1);
    notifyListeners();
    return true;
  }

  /// ✅ removeOne
  void removeOne({
    required String productId,
    required ProductProvider productProvider,
  }) {
    final index = _items.indexWhere((i) => i.product.id == productId);
    if (index == -1) return;

    // Return stock to the UI counter (Memory only)
    productProvider.increaseStock(productId, 1);

    if (_items[index].quantity > 1) {
      _items[index].quantity -= 1;
    } else {
      _items.removeAt(index);
    }

    notifyListeners();
  }

  /// ✅ FULL REMOVE FROM CART
  void removeFromCart(CartItem item, ProductProvider productProvider) {
    final index = _items.indexWhere((i) => i.product.id == item.product.id);
    if (index != -1) {
      productProvider.increaseStock(item.product.id, _items[index].quantity);
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  // ===============================
  // CALCULATIONS
  // ===============================
  double get subtotal => _items.fold(0, (sum, item) => sum + item.total);
  double get gst => subtotal * 0.05;
  double get total => subtotal + gst;

  // ===============================
  // CREATE BILL (API)
  // ===============================
  Future<void> createBill({
    required String paymentMode,
    required ProductProvider productProvider,
    required OrderProvider orderProvider, 
    String? tableId, 
  }) async {
    if (_items.isEmpty) return;

    final now = DateTime.now();

    // 1. Create Invoice Object
    final invoice = Invoice(
      id: const Uuid().v4(),
      deviceId: 'DEVICE_ID', // Can be refined later
      date: now,
      total: total,
      paymentMode: paymentMode,
      items: _items.map((e) => e.toMap()).toList(),
      syncStatus: 'SUCCESS',
    );

    // 2. Perform Backend Writes
    try {
      if (tableId != null) {
        // Save/Update order status on server
        await orderProvider.saveOrUpdateOrder(tableId, _items);
      }

      // Save the invoice to Node.js backend
      await ApiService.saveInvoice(invoice);
      
      if (tableId != null) {
        debugPrint('🟢 Table $tableId marked as PAID/CLOSED on server');
        await orderProvider.closeTable(tableId);
      }

      // 3. Reset UI State
      clearCart();
    } catch (e) {
      debugPrint('❌ BillingProvider: createBill failed: $e');
    }
  }
}