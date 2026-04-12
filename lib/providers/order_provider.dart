import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/table_order.dart';
import '../models/cart_item.dart';
import '../models/web_order.dart';
import '../services/api_service.dart';

enum TableStatus { available, running }

class OrderProvider extends ChangeNotifier {
  final Map<String, TableOrder> _orders = {};
  final Map<String, TableStatus> _tableStatus = {};
  List<WebOrder> _pendingWebOrders = [];
  final Map<int, WebOrder> _webOrderCache = {}; // 🔥 NEW: Track all active web orders
  List<String> _allTables = [];
  bool _isLoading = false;
  Timer? _webOrderTimer;

  OrderProvider() {
    _init();
  }

  Future<void> _init() async {
    await loadAllActiveOrders(); // 🚀 RESTORE EVERYTHING
    _startWebOrderPolling();
  }

  void _startWebOrderPolling() {
    _webOrderTimer?.cancel();
    _webOrderTimer = Timer.periodic(const Duration(seconds: 5), (_) => fetchPendingWebOrders());
  }

  @override
  void dispose() {
    _webOrderTimer?.cancel();
    super.dispose();
  }

  // ================= GETTERS =================
  
  bool get isLoading => _isLoading;

  bool hasActiveOrder(String tableId) {
    return _orders.containsKey(tableId);
  }

  TableStatus getTableStatus(String tableId) {
    if (hasActiveOrder(tableId)) return TableStatus.running;
    return _tableStatus[tableId] ?? TableStatus.available;
  }

  List<TableOrder> get kitchenOrders {
    final list = _orders.values
        .where((o) => o.status == OrderStatus.sentToKitchen)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<TableOrder> get openOrders =>
      _orders.values.where((o) => o.status == OrderStatus.open).toList();

  List<WebOrder> get pendingWebOrders => List.unmodifiable(_pendingWebOrders);

  List<TableOrder> get activeOrders => _orders.values.toList();

  List<String> get allTables => _allTables;

  TableOrder? getOrder(String tableNo) => _orders[tableNo];

  // ================= REMOTE OPERATIONS =================

  Future<void> loadAllActiveOrders() async {
    _isLoading = true;
    notifyListeners();
    
    // 1. Restore Table Statuses (FREE/RUNNING)
    await loadTableStatuses();
    
    // 2. Fetch Full Items for ALL Active Tables
    final activeList = await ApiService.getActiveOrders();
    for (final order in activeList) {
      _orders[order.tableNo] = order;
      _tableStatus[order.tableNo] = TableStatus.running;
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTableStatuses() async {
    final tables = await ApiService.getTables();
    final List<String> newTableList = [];
    for (var t in tables) {
      final tableNo = t['tableNo']?.toString() ?? '';
      newTableList.add(tableNo);
      final status = t['status']?.toString() ?? 'FREE';
      _tableStatus[tableNo] = (status == 'RUNNING') ? TableStatus.running : TableStatus.available;
    }
    _allTables = newTableList;
    notifyListeners();
  }

  Future<void> fetchOrderForTable(String tableNo) async {
    final order = await ApiService.getOrderForTable(tableNo);
    if (order != null) {
      _orders[tableNo] = order;
      _tableStatus[tableNo] = TableStatus.running;
    } else {
      _orders.remove(tableNo);
      _tableStatus[tableNo] = TableStatus.available;
    }
    notifyListeners();
  }

  Future<void> saveOrUpdateOrder(
    String tableNo,
    List<CartItem> items, {
    bool isTakeaway = false,
    String? customerName,
  }) async {
    final now = DateTime.now();
    final order = TableOrder(
      tableNo: tableNo,
      items: items,
      status: OrderStatus.sentToKitchen,
      isTakeaway: isTakeaway,
      customerName: customerName,
      updatedAt: now,
    );

    // 1. Update In-Memory State
    _orders[tableNo] = order;
    _tableStatus[tableNo] = TableStatus.running;
    notifyListeners();

    // 2. Sync to Backend
    await ApiService.upsertOrder(order);
  }

  Future<void> markReady(String tableNo) async {
    final existing = _orders[tableNo];
    if (existing == null) return;

    final updated = existing.copyWith(
      status: OrderStatus.open,
      updatedAt: DateTime.now(),
    );

    _orders[tableNo] = updated;
    notifyListeners();

    await ApiService.updateOrderStatus(tableNo, 'open');
  }

  Future<void> closeTable(String tableNo) async {
    _orders.remove(tableNo);
    _tableStatus[tableNo] = TableStatus.available;
    notifyListeners();

    await ApiService.clearTableOrder(tableNo);
  }

  void markBilled(String tableNo) {
    _orders.remove(tableNo);
    _tableStatus[tableNo] = TableStatus.available;
    notifyListeners();
  }

  void onRemoteOrderUpdated() {
    loadTableStatuses();
  }

  // ================= WEB ORDER LOGIC =================
  // Web orders are AUTO-ACCEPTED: they go straight to Kitchen + Billing.
  // No manual review needed.

  Future<void> fetchPendingWebOrders() async {
    final raw = await ApiService.getCustomerOrders();
    final incoming = raw.map((m) => WebOrder.fromMap(m)).toList();

    // Auto-accept every incoming order ONLY after the 2-minute cancellation window
    for (final order in incoming) {
      _webOrderCache[order.id] = order; // Cache latest state (w/ cancellations)
      
      final ageSeconds = DateTime.now().difference(order.createdAt).inSeconds;
      if (ageSeconds >= 120 || order.status == 'accepted') {
        await _autoAccept(order);
      }
    }

    // Refresh table list to pick up any Admin changes
    await loadTableStatuses();

    // No pending queue needed — everything is accepted immediately
    _pendingWebOrders = [];
    notifyListeners();
  }

  /// Accept a web order immediately: mark on server + push to kitchen/billing.
  Future<void> _autoAccept(WebOrder webOrder) async {
    // 1. Mark accepted on server ONLY if it isn't already accepted
    if (webOrder.status == 'pending') {
      await ApiService.acceptCustomerOrder(webOrder.id);
    }

    // 2. REBUILD Table Items from ALL cached orders for this table
    final List<CartItem> allTableItems = [];
    String customerName = webOrder.customerName;

    _webOrderCache.values.forEach((o) {
      if (o.tableNo == webOrder.tableNo) {
        allTableItems.addAll(o.items);
        if (o.customerName.isNotEmpty) customerName = o.customerName;
      }
    });

    await saveOrUpdateOrder(
      webOrder.tableNo,
      allTableItems,
      isTakeaway: false,
      customerName: customerName,
    );
  }

  // Kept for backward compatibility (used by WebOrdersScreen if re-enabled)
  Future<void> acceptWebOrder(WebOrder webOrder) => _autoAccept(webOrder);

  Future<void> rejectWebOrder(int id) async {
    _pendingWebOrders.removeWhere((o) => o.id == id);
    notifyListeners();
  }
}