import 'package:flutter/material.dart';

import '../models/kitchen_item_status.dart'; // enum + model
import '../models/table_order.dart';
import '../models/product.dart';
import '../services/api_service.dart';

/// ================= KITCHEN PROVIDER =================
class KitchenProvider with ChangeNotifier {
  KitchenSession _currentSession = KitchenSession.morning;

  final Map<String, KitchenItemStatus> _items = {};

  KitchenSession get currentSession => _currentSession;

  // ================= SESSION (MANUAL) =================
  void setSession(KitchenSession session) {
    _currentSession = session;
    notifyListeners();
  }

  // ================= SESSION (AUTO BY TIME) =================
  void autoSetSessionByTime() {
    final now = TimeOfDay.now();
    final minutes = now.hour * 60 + now.minute;

    if (minutes >= 6 * 60 && minutes < 11 * 60) {
      _currentSession = KitchenSession.morning;
    } else if (minutes >= 11 * 60 && minutes < 16 * 60) {
      _currentSession = KitchenSession.afternoon;
    } else {
      _currentSession = KitchenSession.evening;
    }

    notifyListeners();
  }

  // ================= UPDATE ITEM (SESSION-WISE QTY) =================
  void updateItem({
    required String productId,
    required bool available,
    required KitchenSession session,
    required int quantity,
  }) {
    final existing = _items[productId];

    if (existing == null) {
      _items[productId] = KitchenItemStatus(
        productId: productId,
        isAvailable: available,
        sessionQty: {
          KitchenSession.morning:
              session == KitchenSession.morning ? quantity : 0,
          KitchenSession.afternoon:
              session == KitchenSession.afternoon ? quantity : 0,
          KitchenSession.evening:
              session == KitchenSession.evening ? quantity : 0,
        },
      );
    } else {
      existing.isAvailable = available;
      existing.sessionQty[session] = quantity;
    }

    notifyListeners();

    // 🚀 SYNC TO CLOUD: Ensure customer web menu updates
    ApiService.syncKitchenStock(productId, quantity, available, session.name);
  }

  // ================= LOAD FROM DB =================
  void initFromProducts(List<Product> products) {
    if (products.isEmpty) return;
    for (final p in products) {
      _items[p.id] = KitchenItemStatus(
        productId: p.id,
        isAvailable: p.isAvailable,
        sessionQty: {
          KitchenSession.morning: p.qtyMorning,
          KitchenSession.afternoon: p.qtyAfternoon,
          KitchenSession.evening: p.qtyEvening,
        },
      );
    }
    notifyListeners();
  }

  // ================= AVAILABILITY CHECK =================
  bool isItemAvailable(String productId) {
    final item = _items[productId];

    // ✅ Kitchen not configured → allow billing (default to 999 style)
    if (item == null) return true;

    final qty = item.qtyFor(_currentSession);
    return item.isAvailable && qty > 0;
  }

  // ================= GET QTY (CURRENT SESSION) =================
  int getQty(String productId) {
    final item = _items[productId];
    // If kitchen hasn't set a limit for this item, return a high number
    if (item == null) return 999;

    return item.qtyFor(_currentSession);
  }

  // ================= GET QTY (SPECIFIC SESSION) =================
  int getQtyForSession(String productId, KitchenSession session) {
    final item = _items[productId];
    if (item == null) return 0;
    return item.sessionQty[session] ?? 0;
  }

  // ================= ALL QTYS FOR A SESSION (batch update) =================
  Map<String, int> getAllQtysForSession(KitchenSession session) {
    final result = <String, int>{};
    for (final entry in _items.entries) {
      result[entry.key] = entry.value.sessionQty[session] ?? 0;
    }
    return result;
  }

  // ================= REDUCE QTY (CURRENT SESSION) =================
  void reduceQty(String productId, [int amount = 1]) {
    final item = _items[productId];
    if (item == null) return;

    final current = item.qtyFor(_currentSession);
    if (current <= 0) return;

    item.sessionQty[_currentSession] = current - amount;
    notifyListeners();

    // 🚀 SYNC TO CLOUD: Update available stock for customers
    ApiService.syncKitchenStock(productId, item.sessionQty[_currentSession]!, item.isAvailable, _currentSession.name);
  }

  // ================= 🔥 ADD QTY (RETURN STOCK) =================
  void addQty(String productId, [int amount = 1]) {
    final item = _items[productId];
    if (item == null) return; 

    final current = item.qtyFor(_currentSession);
    item.sessionQty[_currentSession] = current + amount;
    notifyListeners();

    // 🚀 SYNC TO CLOUD: Restore stock visibility for customers
    ApiService.syncKitchenStock(productId, item.sessionQty[_currentSession]!, item.isAvailable, _currentSession.name);
  }

  // ================= RESET ALL QUANTITIES =================
  void resetAllQuantities() {
    for (final item in _items.values) {
      item.sessionQty.updateAll((_, __) => 0);
    }
    notifyListeners();
  }

  // ================= SAFE ADD (REQUIRED FOR UI GUARD) =================
  bool get hasAnyConfiguredItem => _items.isNotEmpty;

  // ================= KITCHEN ORDERS =================
  final List<TableOrder> _kitchenOrders = [];

  List<TableOrder> get kitchenOrders => List.unmodifiable(_kitchenOrders);

  /// Load only orders sent to kitchen
  void loadOrdersFromDb(List<TableOrder> orders) {
    _kitchenOrders
      ..clear()
      ..addAll(
        orders.where(
          (o) => o.status == OrderStatus.sentToKitchen,
        ),
      );

    notifyListeners();
  }

  /// Removes order from the KDS display
  void removeOrderForTable(String tableNo) {
    _kitchenOrders.removeWhere((o) => o.tableNo == tableNo);
    notifyListeners();
  }

  /// Quick UI check
  bool get hasKitchenOrders => _kitchenOrders.isNotEmpty;

  // ================= WebSocket / Remote trigger =================
  void onRemoteUpdate() {
    // Orders will be refetched by the screen or handled by global refresh logic
    notifyListeners();
  }
}