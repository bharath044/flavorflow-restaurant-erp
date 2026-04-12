class RawMaterial {
  final String id;
  String name;
  String unit; // kg / litre / pcs
  double currentStock;
  double minStockLevel;
  String? supplierId;
  String? supplierName;
  DateTime updatedAt;

  RawMaterial({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.minStockLevel,
    this.supplierId,
    this.supplierName,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  bool get isLowStock => currentStock <= minStockLevel;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'unit': unit,
        'current_stock': currentStock,
        'min_stock_level': minStockLevel,
        'supplier_id': supplierId,
        'supplier_name': supplierName,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory RawMaterial.fromMap(Map<String, dynamic> m) {
    DateTime parseDate(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return RawMaterial(
      id: m['id']?.toString() ?? '',
      name: m['name']?.toString() ?? 'Unnamed',
      unit: m['unit']?.toString() ?? 'unit',
      currentStock: parseDouble(m['current_stock']),
      minStockLevel: parseDouble(m['min_stock_level']),
      supplierId: m['supplier_id']?.toString(),
      supplierName: m['supplier_name']?.toString(),
      updatedAt: parseDate(m['updated_at']),
    );
  }
}
