// Stock In (Purchase Entry)
class StockIn {
  final String id;
  final String materialId;
  final String materialName;
  final String unit;
  final double quantity;
  final double purchasePrice; // per unit
  final double totalCost;
  final String supplierName;
  final DateTime date;
  final String? notes;

  StockIn({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.quantity,
    required this.purchasePrice,
    this.totalCost = 0,
    required this.supplierName,
    required this.date,
    this.notes,
  });

  double get computedTotal => quantity * purchasePrice;

  Map<String, dynamic> toMap() => {
        'id': id,
        'material_id': materialId,
        'material_name': materialName,
        'unit': unit,
        'quantity': quantity,
        'purchase_price': purchasePrice,
        'total_cost': computedTotal,
        'supplier_name': supplierName,
        'date': date.millisecondsSinceEpoch,
        'notes': notes,
      };

  factory StockIn.fromMap(Map<String, dynamic> m) {
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

    return StockIn(
      id: m['id']?.toString() ?? '',
      materialId: m['material_id']?.toString() ?? '',
      materialName: m['material_name']?.toString() ?? '',
      unit: m['unit']?.toString() ?? 'unit',
      quantity: parseDouble(m['quantity']),
      purchasePrice: parseDouble(m['purchase_price']),
      totalCost: parseDouble(m['total_cost']),
      supplierName: m['supplier_name']?.toString() ?? '',
      date: parseDate(m['date']),
      notes: m['notes']?.toString(),
    );
  }
}

// Wastage Entry
class WastageEntry {
  final String id;
  final String materialId;
  final String materialName;
  final String unit;
  final double quantity;
  final String reason;
  final DateTime date;

  WastageEntry({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.quantity,
    required this.reason,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'material_id': materialId,
        'material_name': materialName,
        'unit': unit,
        'quantity': quantity,
        'reason': reason,
        'date': date.millisecondsSinceEpoch,
      };

  factory WastageEntry.fromMap(Map<String, dynamic> m) {
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

    return WastageEntry(
      id: m['id']?.toString() ?? '',
      materialId: m['material_id']?.toString() ?? '',
      materialName: m['material_name']?.toString() ?? '',
      unit: m['unit']?.toString() ?? 'unit',
      quantity: parseDouble(m['quantity']),
      reason: m['reason']?.toString() ?? '',
      date: parseDate(m['date']),
    );
  }
}

// Stock Adjustment (manual correction)
class StockAdjustment {
  final String id;
  final String materialId;
  final String materialName;
  final String unit;
  final double oldQty;
  final double newQty;
  final String reason;
  final DateTime date;

  StockAdjustment({
    required this.id,
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.oldQty,
    required this.newQty,
    required this.reason,
    required this.date,
  });

  double get difference => newQty - oldQty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'material_id': materialId,
        'material_name': materialName,
        'unit': unit,
        'old_qty': oldQty,
        'new_qty': newQty,
        'reason': reason,
        'date': date.millisecondsSinceEpoch,
      };

  factory StockAdjustment.fromMap(Map<String, dynamic> m) {
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

    return StockAdjustment(
      id: m['id']?.toString() ?? '',
      materialId: m['material_id']?.toString() ?? '',
      materialName: m['material_name']?.toString() ?? '',
      unit: m['unit']?.toString() ?? 'unit',
      oldQty: parseDouble(m['old_qty']),
      newQty: parseDouble(m['new_qty']),
      reason: m['reason']?.toString() ?? '',
      date: parseDate(m['date']),
    );
  }
}

// Recipe Ingredient — maps product → raw material qty used per serving
class RecipeIngredient {
  final String productId;
  final String productName;
  final String materialId;
  final String materialName;
  final String unit;
  final double quantityPerServing; // e.g. 200g rice per biryani

  RecipeIngredient({
    required this.productId,
    required this.productName,
    required this.materialId,
    required this.materialName,
    required this.unit,
    required this.quantityPerServing,
  });

  Map<String, dynamic> toMap() => {
        'product_id': productId,
        'product_name': productName,
        'material_id': materialId,
        'material_name': materialName,
        'unit': unit,
        'qty_per_serving': quantityPerServing,
      };

  factory RecipeIngredient.fromMap(Map<String, dynamic> m) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return RecipeIngredient(
      productId: m['product_id']?.toString() ?? '',
      productName: m['product_name']?.toString() ?? '',
      materialId: m['material_id']?.toString() ?? '',
      materialName: m['material_name']?.toString() ?? '',
      unit: m['unit']?.toString() ?? '',
      quantityPerServing: parseDouble(m['qty_per_serving']),
    );
  }
}
