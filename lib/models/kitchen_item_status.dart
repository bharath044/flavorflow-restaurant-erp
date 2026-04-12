enum KitchenSession { morning, afternoon, evening }

class KitchenItemStatus {
  final String productId;
  bool isAvailable;

  // ✅ NEW: session-wise qty
  Map<KitchenSession, int> sessionQty;

  KitchenItemStatus({
    required this.productId,
    required this.isAvailable,
    required this.sessionQty,
  });

  int qtyFor(KitchenSession session) {
    return sessionQty[session] ?? 0;
  }
}
