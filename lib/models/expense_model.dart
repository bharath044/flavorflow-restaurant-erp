// Expense Category
class ExpenseCategory {
  final String id;
  final String name;
  final String icon; // emoji or icon name

  const ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
  });

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'icon': icon};
  factory ExpenseCategory.fromMap(Map<String, dynamic> m) =>
      ExpenseCategory(id: m['id'] as String, name: m['name'] as String, icon: m['icon'] as String);

  // Default categories
  static List<ExpenseCategory> get defaults => [
        const ExpenseCategory(id: 'rent', name: 'Rent', icon: '🏠'),
        const ExpenseCategory(id: 'salary', name: 'Salary', icon: '👷'),
        const ExpenseCategory(id: 'electricity', name: 'Electricity', icon: '⚡'),
        const ExpenseCategory(id: 'purchase', name: 'Purchase', icon: '🛒'),
        const ExpenseCategory(id: 'maintenance', name: 'Maintenance', icon: '🔧'),
        const ExpenseCategory(id: 'misc', name: 'Misc', icon: '📦'),
      ];
}

// Expense Entry
class ExpenseEntry {
  final String id;
  final String categoryId;
  final String categoryName;
  final double amount;
  final String description;
  final DateTime date;
  final String paymentMode; // CASH / ONLINE
  final bool isRecurring;

  ExpenseEntry({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.description,
    required this.date,
    required this.paymentMode,
    this.isRecurring = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'category_name': categoryName,
        'amount': amount,
        'description': description,
        'date': date.millisecondsSinceEpoch,
        'payment_mode': paymentMode,
        'is_recurring': isRecurring ? 1 : 0,
      };

  factory ExpenseEntry.fromMap(Map<String, dynamic> m) {
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

    return ExpenseEntry(
      id: m['id']?.toString() ?? '',
      categoryId: m['category_id']?.toString() ?? 'misc',
      categoryName: m['category_name']?.toString() ?? 'Misc',
      amount: parseDouble(m['amount']),
      description: m['description']?.toString() ?? '',
      date: parseDate(m['date']),
      paymentMode: m['payment_mode']?.toString() ?? 'CASH',
      isRecurring: (m['is_recurring'] as int? ?? 0) == 1,
    );
  }
}

// Recurring Expense template
class RecurringExpense {
  final String id;
  final String categoryId;
  final String categoryName;
  final double amount;
  final String description;
  final int dayOfMonth; // 1-31
  final bool isActive;

  RecurringExpense({
    required this.id,
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.description,
    required this.dayOfMonth,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'category_id': categoryId,
        'category_name': categoryName,
        'amount': amount,
        'description': description,
        'day_of_month': dayOfMonth,
        'is_active': isActive ? 1 : 0,
      };

  factory RecurringExpense.fromMap(Map<String, dynamic> m) {
    double parseDouble(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val) ?? 0.0;
      return 0.0;
    }

    return RecurringExpense(
      id: m['id']?.toString() ?? '',
      categoryId: m['category_id']?.toString() ?? '',
      categoryName: m['category_name']?.toString() ?? '',
      amount: parseDouble(m['amount']),
      description: m['description']?.toString() ?? '',
      dayOfMonth: m['day_of_month'] as int? ?? 1,
      isActive: (m['is_active'] as int? ?? 1) == 1,
    );
  }
}

// Supplier Payment
class SupplierPayment {
  final String id;
  final String supplierName;
  final double totalAmount;
  final double paidAmount;
  final String description;
  final DateTime date;
  final String paymentMode;

  SupplierPayment({
    required this.id,
    required this.supplierName,
    required this.totalAmount,
    required this.paidAmount,
    required this.description,
    required this.date,
    required this.paymentMode,
  });

  double get pendingAmount => totalAmount - paidAmount;
  bool get isFullyPaid => pendingAmount <= 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplier_name': supplierName,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'description': description,
        'date': date.millisecondsSinceEpoch,
        'payment_mode': paymentMode,
      };

  factory SupplierPayment.fromMap(Map<String, dynamic> m) {
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

    return SupplierPayment(
      id: m['id']?.toString() ?? '',
      supplierName: m['supplier_name']?.toString() ?? 'Unnamed Supplier',
      totalAmount: parseDouble(m['total_amount']),
      paidAmount: parseDouble(m['paid_amount']),
      description: m['description']?.toString() ?? '',
      date: parseDate(m['date']),
      paymentMode: m['payment_mode']?.toString() ?? 'CASH',
    );
  }
}
