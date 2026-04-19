import 'dart:convert';

class Invoice {
  /// 🆔 Unique bill id (UUID)
  final String id;

  /// 📱 Device id (Desktop / Mobile)
  final String deviceId;

  /// 📅 Bill date / time
  final DateTime date;

  /// 💰 Bill total
  final double total;

  /// 📊 GST Amount
  final double gstAmount;

  /// 💳 Cash / Online / UPI etc.
  final String paymentMode;

  /// 🧾 Items sold in this bill
  /// Used for analytics (Top / Low products)
  /// Backward safe: old invoices = empty list
  final List<Map<String, dynamic>> items;

  /// 🔄 Sync status
  /// PENDING = offline saved
  /// SYNCED = server synced
  final String syncStatus;

  /// ⏱ For conflict resolution
  final int createdAt;
  final int updatedAt;

  Invoice({
    required this.id,
    required this.deviceId,
    required this.date,
    required this.total,
    required this.paymentMode,
    this.gstAmount = 0,
    this.items = const [],
    this.syncStatus = 'PENDING',
    int? createdAt,
    int? updatedAt,
  })  : createdAt =
            createdAt ?? DateTime.now().millisecondsSinceEpoch,
        updatedAt =
            updatedAt ?? DateTime.now().millisecondsSinceEpoch;

  // ======================================================
  // 🔥 ADD ONLY — compatibility getter
  // ======================================================
  String get invoiceNo => id;
  double get totalAmount => total;

  // ======================================================
  // 🔁 COPY WITH
  // ======================================================
  Invoice copyWith({
    String? syncStatus,
    int? updatedAt,
  }) {
    return Invoice(
      id: id,
      deviceId: deviceId,
      date: date,
      total: total,
      paymentMode: paymentMode,
      gstAmount: gstAmount,
      items: items,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt,
      updatedAt:
          updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  // ======================================================
  // 📦 TO DB MAP (SQLite)
  // ======================================================
  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'date': date.millisecondsSinceEpoch,
      'total': total,
      'gst_amount': gstAmount,
      'payment_mode': paymentMode,
      'items': jsonEncode(items),
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // ======================================================
  // 📦 FROM DB MAP
  // ======================================================
  factory Invoice.fromDbMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'],
      deviceId: map['device_id'],
      date: DateTime.fromMillisecondsSinceEpoch(map['date']),
      total: (map['total'] as num).toDouble(),
      gstAmount: (map['gst_amount'] as num?)?.toDouble() ?? 0,
      paymentMode: map['payment_mode'],
      items: map['items'] != null && map['items'].toString().isNotEmpty
          ? List<Map<String, dynamic>>.from(
              jsonDecode(map['items']),
            )
          : const [],
      syncStatus: map['sync_status'] ?? 'SYNCED',
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  // ======================================================
  // 🌐 TO API / WEBSOCKET JSON
  // ======================================================
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'device_id': deviceId,
      'date': date.toIso8601String(),
      'total': total,
      'gst_amount': gstAmount,
      'payment_mode': paymentMode,
      'items': items,
      'sync_status': syncStatus,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // ======================================================
  // 🌐 FROM API / WEBSOCKET JSON
  // ======================================================
  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Robust timestamp parsing
    int? parseTime(dynamic val) {
      if (val == null) return null;
      if (val is int) return val;
      if (val is String) {
        return DateTime.tryParse(val)?.millisecondsSinceEpoch;
      }
      return null;
    }

    return Invoice(
      id: json['id'],
      deviceId: json['device_id'] ?? 'UNKNOWN',
      date: DateTime.parse(json['date']),
      total: (json['total'] as num).toDouble(),
      gstAmount: (json['gst_amount'] as num?)?.toDouble() ?? 0,
      paymentMode: json['payment_mode'] ?? 'CASH',
      items: json['items'] != null
          ? List<Map<String, dynamic>>.from(json['items'])
          : const [],
      syncStatus: json['sync_status'] ?? 'SYNCED',
      createdAt: parseTime(json['created_at']),
      updatedAt: parseTime(json['updated_at']),
    );
  }
}
