import 'product.dart';

class CartItem {
  final Product product;
  int quantity;

  /// 🔥 NEW (FOR KITCHEN UPDATE HIGHLIGHT)
  DateTime updatedAt;

  CartItem({
    required this.product,
    this.quantity = 1,
    DateTime? updatedAt,
    this.isCancelled = false, // 🔥 NEW
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool isCancelled; // 🔥 NEW

  /// 🔴 FIX: Explicit getter to ensure 'productId' is always accessible 
  /// This prevents 'productId isn't defined' errors in BillingProvider
  String get productId => product.id;

  /// Convenience getters for cleaner code elsewhere
  String get name => product.name;
  double get price => product.price;
  double get total => product.price * quantity;

  /// ================= SAVE (HIVE / WEB SAFE) =================
  /// ⚠️ OLD KEYS KEPT + NEW FIELD ADDED
  Map<String, dynamic> toMap() {
    return {
      // ✅ OLD FORMAT (DO NOT BREAK EXISTING DB)
      'id': product.id,
      'name': product.name,
      'price': product.price,
      'category': product.category,
      'image': product.image,
      'qty': quantity,

      // 🔥 NEW FIELDS
      'updatedAt': updatedAt.toIso8601String(),
      'isCancelled': isCancelled, // 🔥 NEW
    };
  }

  /// ================= RESTORE (WEB + HIVE SAFE) =================
  /// 🔥 BACKWARD COMPATIBLE: Handles old data without updatedAt
  factory CartItem.fromMap(Map<dynamic, dynamic> map) {
    final safeMap = Map<String, dynamic>.from(map);

    return CartItem(
      product: Product(
        id: safeMap['id'].toString(),
        name: safeMap['name'].toString(),
        price: (safeMap['price'] as num).toDouble(),
        category: safeMap['category']?.toString() ?? '',
        image: safeMap['image']?.toString() ?? '',
      ),
      quantity: (safeMap['qty'] as num).toInt(),

      // 🔥 IF OLD DATA → fallback to now
      updatedAt: safeMap['updatedAt'] != null
          ? DateTime.parse(safeMap['updatedAt'])
          : DateTime.now(),
      isCancelled: safeMap['isCancelled'] == true, // 🔥 NEW
    );
  }
}