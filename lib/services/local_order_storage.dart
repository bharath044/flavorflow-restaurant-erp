import 'package:hive_flutter/hive_flutter.dart';
import '../models/table_order.dart';

class LocalOrderStorage {
  static const String _boxName = 'orders';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  /// ================= SAVE =================
  static void saveOrders(Map<String, TableOrder> orders) {
    final box = Hive.box(_boxName);

    final data = orders.map(
      (key, value) => MapEntry(key, value.toMap()),
    );

    box.put('orders', data);
  }

  /// ================= LOAD (WEB SAFE) =================
  static Map<String, dynamic>? loadOrders() {
    final box = Hive.box(_boxName);
    final raw = box.get('orders');

    if (raw == null) return null;

    // 🔥 THIS IS THE FIX
    return Map<String, dynamic>.from(raw);
  }
}
  