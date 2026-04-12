import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'server_config.dart';
import '../models/product.dart';
import '../models/table_order.dart';
import '../models/invoice.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  ));

  static Future<bool> updateInvoice(String id, Map<String, dynamic> data) async {
    try {
      await _dio.put('${ServerConfig.baseUrl}/api/invoices/$id', data: data);
      return true;
    } catch (e) {
      debugPrint('Error updating invoice: $e');
      return false;
    }
  }

  static Future<bool> deleteInvoice(String id) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/invoices/$id');
      return true;
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      return false;
    }
  }

  // ─── PRODUCTS ──────────────────────────────────────────────
  static Future<List<Product>> getProducts() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/products');
      return (response.data as List).map((p) => Product.fromMap(p)).toList();
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/categories');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  static Future<bool> createProduct(Map<String, dynamic> data, {File? imageFile, Uint8List? imageBytes}) async {
    try {
      FormData formData = FormData.fromMap({
        ...data,
        if (imageFile != null)
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          )
        else if (imageBytes != null)
          'image': MultipartFile.fromBytes(
            imageBytes,
            filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
      });

      await _dio.post('${ServerConfig.baseUrl}/api/products', data: formData);
      return true;
    } catch (e) {
      debugPrint('Error creating product: $e');
      return false;
    }
  }

  static Future<bool> updateProductMetadata(String id, Map<String, dynamic> data, {File? imageFile, Uint8List? imageBytes}) async {
    try {
      FormData formData = FormData.fromMap({
        ...data,
        if (imageFile != null)
          'image': await MultipartFile.fromFile(
            imageFile.path,
            filename: imageFile.path.split('/').last,
          )
        else if (imageBytes != null)
          'image': MultipartFile.fromBytes(
            imageBytes,
            filename: 'upload_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
      });

      await _dio.put('${ServerConfig.baseUrl}/api/products/$id', data: formData);
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  static Future<bool> deleteProduct(String id) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/products/$id');
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  // ─── ORDERS ────────────────────────────────────────────────
  static Future<TableOrder?> getOrderForTable(String tableNo) async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/orders/$tableNo');
      if (response.data == null) return null;
      return TableOrder.fromMap(response.data);
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  static Future<bool> upsertOrder(TableOrder order) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/orders', data: order.toMap());
      return true;
    } catch (e) {
      debugPrint('Error upserting order: $e');
      return false;
    }
  }

  static Future<List<TableOrder>> getActiveOrders() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/orders');
      if (response.data == null) return [];
      return (response.data as List).map((o) => TableOrder.fromMap(o)).toList();
    } catch (e) {
      debugPrint('Error getting active orders: $e');
      return [];
    }
  }

  static Future<bool> updateOrderStatus(String tableNo, String status) async {
    try {
      await _dio.patch('${ServerConfig.baseUrl}/api/orders/$tableNo/status', data: {'status': status});
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  static Future<bool> clearTableOrder(String tableNo) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/orders/$tableNo');
      return true;
    } catch (e) {
      debugPrint('Error clearing table order: $e');
      return false;
    }
  }

  // ─── INVOICES ──────────────────────────────────────────────
  static Future<bool> saveInvoice(Invoice invoice) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/invoices', data: invoice.toJson());
      return true;
    } catch (e) {
      debugPrint('Error saving invoice: $e');
      return false;
    }
  }

  static Future<List<Invoice>> getInvoices({String? from, String? to}) async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/invoices', queryParameters: {
        'from': from,
        'to': to,
      });
      return (response.data as List).map((json) => Invoice.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error getting invoices: $e');
      return [];
    }
  }

  static Future<double> getTodaySales() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/invoices/today');
      return (response.data['total'] as num).toDouble();
    } catch (e) {
      debugPrint('Error getting today sales: $e');
      return 0.0;
    }
  }

  static Future<double> getGstTotal() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/invoices/gst');
      return (response.data['gst'] as num).toDouble();
    } catch (e) {
      debugPrint('Error getting GST total: $e');
      return 0.0;
    }
  }

  // ─── TABLES & SETTINGS ──────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTables() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/tables');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting tables: $e');
      return [];
    }
  }

  static Future<bool> addTable(String tableNo, String label) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/tables', data: {'tableNo': tableNo, 'label': label});
      return true;
    } catch (e) {
      debugPrint('Error adding table: $e');
      return false;
    }
  }

  static Future<bool> deleteTable(String tableNo) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/tables/$tableNo');
      return true;
    } catch (e) {
      debugPrint('Error deleting table: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getQrForTable(String tableNo) async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/tables/$tableNo/qr');
      return response.data;
    } catch (e) {
      debugPrint('Error getting QR: $e');
      return {};
    }
  }

  // ─── WEB ORDERS (CUSTOMER MENU) ──────────────────────────
  static Future<List<Map<String, dynamic>>> getCustomerOrders() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/menu/pending');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting customer orders: $e');
      return [];
    }
  }

  static Future<bool> acceptCustomerOrder(int id) async {
    try {
      await _dio.patch('${ServerConfig.baseUrl}/menu/$id/accept');
      return true;
    } catch (e) {
      debugPrint('Error accepting customer order: $e');
      return false;
    }
  }

  /// Customer places an order. Returns order id or -1 on failure.
  /// POST /menu/order  { tableNo, customerName, customerPhone, items, note }
  static Future<int> placeCustomerOrder({
    required String tableNo,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    String note = '',
  }) async {
    try {
      final response = await _dio.post(
        '${ServerConfig.baseUrl}/menu/order',
        data: {
          'tableNo':       tableNo,
          'customerName':  customerName,
          'customerPhone': customerPhone,
          'items':         items,
          'note':          note,
        },
      );
      // backend should return { id: <orderId> }
      return (response.data['id'] as num?)?.toInt() ?? 1;
    } catch (e) {
      debugPrint('Error placing customer order: $e');
      return -1;
    }
  }

  /// Cancel a customer order within the allowed window.
  /// PATCH /menu/:id/cancel
  static Future<bool> cancelCustomerOrder(int id) async {
    try {
      await _dio.patch('${ServerConfig.baseUrl}/menu/$id/cancel');
      return true;
    } catch (e) {
      debugPrint('Error cancelling customer order: $e');
      return false;
    }
  }

  /// Update items of a pending customer order.
  /// PATCH /menu/:id/update  { items, note }
  static Future<bool> updateCustomerOrder({
    required int id,
    required List<Map<String, dynamic>> items,
    String note = '',
  }) async {
    try {
      await _dio.patch(
        '${ServerConfig.baseUrl}/menu/$id/update',
        data: {'items': items, 'note': note},
      );
      return true;
    } catch (e) {
      debugPrint('Error updating customer order: $e');
      return false;
    }
  }

  /// Fetch all products (public — no auth needed for customer menu).
  static Future<List<Product>> getPublicProducts() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/products');
      return (response.data as List).map((p) => Product.fromMap(p)).toList();
    } catch (e) {
      debugPrint('Error fetching public products: $e');
      return [];
    }
  }

  // ─── EXPENSES (CENTRALIZED) ─────────────────────────────
  static Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/expenses');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting expenses: $e');
      return [];
    }
  }

  static Future<bool> upsertExpense(Map<String, dynamic> data) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/expenses', data: data);
      return true;
    } catch (e) {
      debugPrint('Error upserting expense: $e');
      return false;
    }
  }

  static Future<bool> deleteExpense(String id) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/expenses/$id');
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  // ─── INVENTORY (CENTRALIZED) ────────────────────────────
  static Future<List<Map<String, dynamic>>> getRawMaterials() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/inventory/materials');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting materials: $e');
      return [];
    }
  }

  static Future<bool> upsertRawMaterial(Map<String, dynamic> data) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/inventory/materials', data: data);
      return true;
    } catch (e) {
      debugPrint('Error upserting material: $e');
      return false;
    }
  }

  static Future<bool> deleteRawMaterial(String id) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/inventory/materials/$id');
      return true;
    } catch (e) {
      debugPrint('Error deleting material: $e');
      return false;
    }
  }

  static Future<bool> recordInventoryTransaction(String materialId, double quantity, String type) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/inventory/transaction', data: {
        'materialId': materialId,
        'quantity': quantity,
        'type': type
      });
      return true;
    } catch (e) {
      debugPrint('Error recording transaction: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getInventoryHistory(String type) async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/inventory/history/$type');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting inventory history ($type): $e');
      return [];
    }
  }

  static Future<bool> saveInventoryHistory(String type, Map<String, dynamic> data) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/inventory/history/$type', data: data);
      return true;
    } catch (e) {
      debugPrint('Error saving inventory history ($type): $e');
      return false;
    }
  }

  static Future<bool> deleteInventoryHistory(String type, String id) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/inventory/history/$type/$id');
      return true;
    } catch (e) {
      debugPrint('Error deleting inventory history: $e');
      return false;
    }
  }

  // ─── RECIPES ──────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/inventory/recipes');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting recipes: $e');
      return [];
    }
  }

  static Future<bool> saveRecipe(Map<String, dynamic> data) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/inventory/recipes', data: data);
      return true;
    } catch (e) {
      debugPrint('Error saving recipe: $e');
      return false;
    }
  }

  static Future<bool> deleteRecipe(String productId, String materialId) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/inventory/recipes/$productId/$materialId');
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      return false;
    }
  }

  // ─── RECURRING EXPENSES ────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRecurringExpenses() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/expenses/recurring');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting recurring: $e');
      return [];
    }
  }

  static Future<bool> saveRecurringExpense(Map<String, dynamic> data) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/expenses/recurring', data: data);
      return true;
    } catch (e) {
      debugPrint('Error saving recurring: $e');
      return false;
    }
  }

  static Future<bool> deleteRecurringExpense(String id) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/expenses/recurring/$id');
      return true;
    } catch (e) {
      debugPrint('Error deleting recurring: $e');
      return false;
    }
  }

  // ─── SUPPLIER PAYMENTS ─────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getSupplierPayments() async {
    try {
      final response = await _dio.get('${ServerConfig.baseUrl}/api/expenses/supplier-payments');
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      debugPrint('Error getting supplier payments: $e');
      return [];
    }
  }

  static Future<bool> saveSupplierPayment(Map<String, dynamic> data) async {
    try {
      await _dio.post('${ServerConfig.baseUrl}/api/expenses/supplier-payments', data: data);
      return true;
    } catch (e) {
      debugPrint('Error saving supplier payment: $e');
      return false;
    }
  }

  static Future<bool> deleteSupplierPayment(String id) async {
    try {
      await _dio.delete('${ServerConfig.baseUrl}/api/expenses/supplier-payments/$id');
      return true;
    } catch (e) {
      debugPrint('Error deleting supplier payment: $e');
      return false;
    }
  }

  // ─── KITCHEN STOCK SYNC ─────────────────────────────────────
  static Future<bool> syncKitchenStock(String productId, int quantity, bool isAvailable, [String? session]) async {
    try {
      await _dio.patch('${ServerConfig.baseUrl}/api/products/$productId/sync', data: {
        'quantity': quantity,
        'isAvailable': isAvailable,
        'session': session,
      });
      return true;
    } catch (e) {
      debugPrint('Error syncing kitchen stock: $e');
      return false;
    }
  }
}
