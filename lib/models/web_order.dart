import 'cart_item.dart';
import 'product.dart';

class WebOrder {
  final int id;
  final String tableNo;
  final List<CartItem> items;
  final String note;
  final String status;
  final String customerName; // 🔥 NEW
  final String customerPhone; // 🔥 NEW
  final DateTime createdAt;

  WebOrder({
    required this.id,
    required this.tableNo,
    required this.items,
    this.note = '',
    this.status = 'pending',
    this.customerName = 'Guest',
    this.customerPhone = '',
    required this.createdAt,
  });

  factory WebOrder.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] as List? ?? [];
    
    return WebOrder(
      id: map['id'] as int,
      tableNo: map['tableNo']?.toString() ?? '',
      note: map['note']?.toString() ?? '',
      customerName: map['customerName']?.toString() ?? '', // 🔥 NEW
      customerPhone: map['customerPhone']?.toString() ?? '', // 🔥 NEW
      createdAt: map['createdAt'] != null 
          ? DateTime.parse(map['createdAt']) 
          : DateTime.now(),
      items: rawItems.map((i) {
        final itemMap = Map<String, dynamic>.from(i);
        return CartItem(
          product: Product(
            id: itemMap['productId']?.toString() ?? '',
            name: itemMap['name']?.toString() ?? 'Unknown',
            price: (itemMap['price'] as num?)?.toDouble() ?? 0.0,
            category: '', // Not needed for the cart panel display
            image: '', // Missing required field fixed
          ),
          quantity: (itemMap['quantity'] as num?)?.toInt() ?? 0,
          isCancelled: itemMap['isCancelled'] == true, // 🔥 NEW
        );
      }).toList(),
    );
  }
}
