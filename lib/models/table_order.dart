import 'package:uuid/uuid.dart';
import 'cart_item.dart';

/// ================= ORDER STATUS =================
enum OrderStatus {
  sentToKitchen, // Server / Staff → Kitchen
  open,          // Kitchen → Staff
  billed,        // After billing
}

/// ================= TABLE / TAKEAWAY ORDER MODEL =================
///
/// ✔ Works for BOTH Mobile & Desktop
/// ✔ Same task, same data
/// ✔ Two-way sync safe
/// ✔ Backward compatible
///
class TableOrder {
  /// 🔥 GLOBAL UNIQUE ID (VERY IMPORTANT FOR SYNC)
  final String id;

  /// Table number OR "TAKEAWAY"
  final String tableNo;

  /// Customer Name (Web Orders)
  final String? customerName; // 🔥 NEW

  /// Items in the order
  final List<CartItem> items;

  /// Order flow status
  final OrderStatus status;

  /// Identify takeaway orders
  final bool isTakeaway;

  /// 🔥 Used for sync conflict resolution (LAST WRITE WINS)
  final DateTime updatedAt;

  TableOrder({
    String? id,
    required this.tableNo,
    required this.items,
    this.status = OrderStatus.sentToKitchen,
    this.isTakeaway = false,
    this.customerName, // 🔥 NEW
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(), // ✅ AUTO ID
        updatedAt = updatedAt ?? DateTime.now();

  // =====================================================
  // COPY WITH (USED BY PROVIDERS / KITCHEN UPDATES)
  // =====================================================
  TableOrder copyWith({
    List<CartItem>? items,
    OrderStatus? status,
    bool? isTakeaway,
    String? customerName, // 🔥 NEW
    DateTime? updatedAt,
  }) {
    return TableOrder(
      id: id, // 🔥 KEEP SAME ID
      tableNo: tableNo,
      items: items ?? this.items,
      status: status ?? this.status,
      isTakeaway: isTakeaway ?? this.isTakeaway,
      customerName: customerName ?? this.customerName, // 🔥 NEW
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // =====================================================
  // SAVE (LOCAL DB / API / WEB SAFE)
  // =====================================================
  Map<String, dynamic> toMap() {
    return {
      'id': id, // 🔥 REQUIRED FOR SYNC
      'tableNo': tableNo,
      'customerName': customerName, // 🔥 NEW
      'status': status.name,
      'isTakeaway': isTakeaway,
      'updatedAt': updatedAt.toIso8601String(),
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  // =====================================================
  // RESTORE (BACKWARD COMPATIBLE – VERY IMPORTANT)
  // =====================================================
  factory TableOrder.fromMap(Map<dynamic, dynamic> map) {
    final safeMap = Map<String, dynamic>.from(map);

    final rawItems = safeMap['items'] as List? ?? [];
    final tableNo = safeMap['tableNo']?.toString() ?? '';

    return TableOrder(
      /// ✅ OLD DATA SAFE (NO ID → AUTO GENERATE)
      id: safeMap['id']?.toString(),
      tableNo: tableNo,
      customerName: safeMap['customerName']?.toString(), // 🔥 NEW

      /// ✅ OLD STATUS SAFE
      status: safeMap['status'] != null
          ? OrderStatus.values.firstWhere(
              (e) => e.name == safeMap['status'],
              orElse: () => OrderStatus.sentToKitchen,
            )
          : OrderStatus.sentToKitchen,

      /// ✅ AUTO DETECT TAKEAWAY FOR OLD DATA
      isTakeaway: safeMap['isTakeaway'] ??
          (tableNo.toUpperCase() == 'TAKEAWAY'),

      /// ✅ OLD DATA SAFE
      updatedAt: safeMap['updatedAt'] != null
          ? DateTime.parse(safeMap['updatedAt'])
          : DateTime.now(),

      items: rawItems
          .map(
            (i) => CartItem.fromMap(
              Map<String, dynamic>.from(i as Map),
            ),
          )
          .toList(),
    );
  }
}
