import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product.dart';
import '../models/table_order.dart';
import '../models/invoice.dart';

class ApiService {
  static final _supabase = Supabase.instance.client;

  // ─── INVOICES ──────────────────────────────────────────────
  static Future<bool> saveInvoice(Invoice invoice) async {
    try {
      await _supabase.from('invoices').insert({
        'id': invoice.id,
        'data': invoice.toJson(),
        'total': invoice.totalAmount,
        'gst_total': invoice.gstAmount,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      debugPrint('Error saving invoice to Supabase: $e');
      return false;
    }
  }

  static Future<List<Invoice>> getInvoices({String? from, String? to}) async {
    try {
      var query = _supabase.from('invoices').select();
      if (from != null) query = query.gte('created_at', from);
      if (to != null) query = query.lte('created_at', to);
      
      final response = await query.order('created_at', ascending: false);
      return (response as List).map((json) => Invoice.fromJson(json['data'])).toList();
    } catch (e) {
      debugPrint('Error getting invoices: $e');
      return [];
    }
  }

  static Future<bool> updateInvoice(String id, Map<String, dynamic> data) async {
    try {
      await _supabase.from('invoices').update({'data': data}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating invoice: $e');
      return false;
    }
  }

  static Future<bool> deleteInvoice(String id) async {
    try {
      await _supabase.from('invoices').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting invoice: $e');
      return false;
    }
  }

  static Future<double> getTodaySales() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await _supabase
          .from('invoices')
          .select('total')
          .gte('created_at', today);
      
      double total = 0;
      for (var row in (response as List)) {
        total += (row['total'] as num).toDouble();
      }
      return total;
    } catch (e) {
      debugPrint('Error getting today sales: $e');
      return 0.0;
    }
  }

  static Future<double> getGstTotal() async {
    try {
      final response = await _supabase.from('invoices').select('gst_total');
      double total = 0;
      for (var row in (response as List)) {
        total += (row['gst_total'] as num?)?.toDouble() ?? 0;
      }
      return total;
    } catch (e) {
      debugPrint('Error getting GST total: $e');
      return 0.0;
    }
  }

  // ─── PRODUCTS ──────────────────────────────────────────────
  static Future<List<Product>> getProducts() async {
    try {
      final response = await _supabase.from('products').select().order('name');
      return (response as List).map((p) => Product.fromMap(p)).toList();
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  static Future<List<Product>> getPublicProducts() => getProducts();

  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _supabase.from('categories').select();
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  static Future<bool> createProduct(Map<String, dynamic> data, {File? imageFile, Uint8List? imageBytes}) async {
    try {
      String? imageUrl;
      if (imageFile != null || imageBytes != null) {
        imageUrl = await _uploadImage(imageFile, imageBytes);
      }

      await _supabase.from('products').insert({
        ...data,
        'image_url': imageUrl,
      });
      return true;
    } catch (e) {
      debugPrint('Error creating product: $e');
      return false;
    }
  }

  static Future<bool> updateProductMetadata(String id, Map<String, dynamic> data, {File? imageFile, Uint8List? imageBytes}) async {
    try {
      String? imageUrl;
      if (imageFile != null || imageBytes != null) {
        imageUrl = await _uploadImage(imageFile, imageBytes);
      }

      final updateData = {...data};
      if (imageUrl != null) updateData['image_url'] = imageUrl;

      await _supabase.from('products').update(updateData).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating product: $e');
      return false;
    }
  }

  static Future<bool> deleteProduct(String id) async {
    try {
      await _supabase.from('products').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting product: $e');
      return false;
    }
  }

  static Future<String?> _uploadImage(File? file, Uint8List? bytes) async {
    try {
      final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'public/$fileName';
      
      if (file != null) {
        await _supabase.storage.from('product-images').upload(path, file);
      } else if (bytes != null) {
        await _supabase.storage.from('product-images').uploadBinary(path, bytes);
      }

      return _supabase.storage.from('product-images').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }

  // ─── ORDERS ────────────────────────────────────────────────
  static Future<TableOrder?> getOrderForTable(String tableNo) async {
    try {
      final response = await _supabase.from('table_orders').select().eq('table_no', tableNo).maybeSingle();
      if (response == null) return null;
      return TableOrder.fromMap(response);
    } catch (e) {
      debugPrint('Error getting order: $e');
      return null;
    }
  }

  static Future<bool> upsertOrder(TableOrder order) async {
    try {
      await _supabase.from('table_orders').upsert(order.toMap(), onConflict: 'table_no');
      return true;
    } catch (e) {
      debugPrint('Error upserting order: $e');
      return false;
    }
  }

  static Future<List<TableOrder>> getActiveOrders() async {
    try {
      final response = await _supabase.from('table_orders').select().neq('status', 'billed');
      return (response as List).map((o) => TableOrder.fromMap(o)).toList();
    } catch (e) {
      debugPrint('Error getting active orders: $e');
      return [];
    }
  }

  static Future<bool> updateOrderStatus(String tableNo, String status) async {
    try {
      await _supabase.from('table_orders').update({'status': status}).eq('table_no', tableNo);
      return true;
    } catch (e) {
      debugPrint('Error updating order status: $e');
      return false;
    }
  }

  static Future<bool> clearTableOrder(String tableNo) async {
    try {
      await _supabase.from('table_orders').delete().eq('table_no', tableNo);
      return true;
    } catch (e) {
      debugPrint('Error clearing table order: $e');
      return false;
    }
  }

  // ─── TABLES ────────────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getTables() async {
    try {
      final response = await _supabase.from('tables').select().order('table_no');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting tables: $e');
      return [];
    }
  }

  static Future<bool> addTable(String tableNo, String label) async {
    try {
      await _supabase.from('tables').insert({'table_no': tableNo, 'label': label});
      return true;
    } catch (e) {
      debugPrint('Error adding table: $e');
      return false;
    }
  }

  static Future<bool> deleteTable(String tableNo) async {
    try {
      await _supabase.from('tables').delete().eq('table_no', tableNo);
      return true;
    } catch (e) {
      debugPrint('Error deleting table: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> getQrForTable(String tableNo) async {
    // Note: Since we don't have a backend to generate QR strings, we return a mock URL
    // for CustomerOrderScreen web orientation
    return {
      'url': 'https://flavorflow.vercel.app/menu/$tableNo',
    };
  }

  // ─── WEB ORDERS (CUSTOMER MENU) ─────────────────────────
  static Future<int> placeCustomerOrder({
    required String tableNo,
    required String customerName,
    required String customerPhone,
    required List<Map<String, dynamic>> items,
    String note = '',
  }) async {
    try {
      final response = await _supabase.from('customer_orders').insert({
        'table_no': tableNo,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'items': items,
        'note': note,
      }).select().single();
      
      return response['id'] as int;
    } catch (e) {
      debugPrint('Error placing customer order: $e');
      return -1;
    }
  }

  static Future<List<Map<String, dynamic>>> getCustomerOrders() async {
    try {
      final response = await _supabase.from('customer_orders')
        .select()
        .or('status.eq.pending,status.eq.accepted');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting customer orders: $e');
      return [];
    }
  }

  static Future<bool> acceptCustomerOrder(int id) async {
    try {
      await _supabase.from('customer_orders').update({'status': 'accepted'}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error accepting customer order: $e');
      return false;
    }
  }

  static Future<bool> cancelCustomerOrder(int id) async {
    try {
      await _supabase.from('customer_orders').update({'status': 'cancelled'}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error cancelling customer order: $e');
      return false;
    }
  }

  static Future<bool> updateCustomerOrder({required int id, required List<Map<String, dynamic>> items, String note = ''}) async {
    try {
      await _supabase.from('customer_orders').update({'items': items, 'note': note}).eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error updating customer order: $e');
      return false;
    }
  }

  // ─── EXPENSES ───────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getExpenses() async {
    try {
      final response = await _supabase.from('expenses').select().order('date', ascending: false);
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting expenses: $e');
      return [];
    }
  }

  static Future<bool> upsertExpense(Map<String, dynamic> data) async {
    try {
      await _supabase.from('expenses').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Error upserting expense: $e');
      return false;
    }
  }

  static Future<bool> deleteExpense(String id) async {
    try {
      await _supabase.from('expenses').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting expense: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getRecurringExpenses() async {
    try {
      final response = await _supabase.from('recurring_expenses').select();
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting recurring: $e');
      return [];
    }
  }

  static Future<bool> saveRecurringExpense(Map<String, dynamic> data) async {
    try {
      await _supabase.from('recurring_expenses').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Error saving recurring: $e');
      return false;
    }
  }

  static Future<bool> deleteRecurringExpense(String id) async {
    try {
      await _supabase.from('recurring_expenses').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting recurring: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getSupplierPayments() async {
    try {
      final response = await _supabase.from('supplier_payments').select();
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting supplier payments: $e');
      return [];
    }
  }

  static Future<bool> saveSupplierPayment(Map<String, dynamic> data) async {
    try {
      await _supabase.from('supplier_payments').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Error saving supplier payment: $e');
      return false;
    }
  }

  static Future<bool> deleteSupplierPayment(String id) async {
    try {
      await _supabase.from('supplier_payments').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting supplier payment: $e');
      return false;
    }
  }

  // ─── INVENTORY ──────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRawMaterials() async {
    try {
      final response = await _supabase.from('raw_materials').select().order('name');
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting materials: $e');
      return [];
    }
  }

  static Future<bool> upsertRawMaterial(Map<String, dynamic> data) async {
    try {
      await _supabase.from('raw_materials').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Error upserting material: $e');
      return false;
    }
  }

  static Future<bool> deleteRawMaterial(String id) async {
    try {
      await _supabase.from('raw_materials').delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting material: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getInventoryHistory(String type) async {
    try {
      final table = type == 'stock_in' ? 'inventory_stock_in' : (type == 'wastage' ? 'inventory_wastage' : 'inventory_adjustments');
      final response = await _supabase.from(table).select();
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting inventory history: $e');
      return [];
    }
  }

  static Future<bool> saveInventoryHistory(String type, Map<String, dynamic> data) async {
    try {
      final table = type == 'stock_in' ? 'inventory_stock_in' : (type == 'wastage' ? 'inventory_wastage' : 'inventory_adjustments');
      await _supabase.from(table).upsert(data);
      return true;
    } catch (e) {
      debugPrint('Error saving inventory history: $e');
      return false;
    }
  }

  static Future<bool> deleteInventoryHistory(String type, String id) async {
    try {
      final table = type == 'stock_in' ? 'inventory_stock_in' : (type == 'wastage' ? 'inventory_wastage' : 'inventory_adjustments');
      await _supabase.from(table).delete().eq('id', id);
      return true;
    } catch (e) {
      debugPrint('Error deleting inventory history: $e');
      return false;
    }
  }

  static Future<bool> recordInventoryTransaction(String materialId, double quantity, String type) async {
    try {
      await _supabase.rpc('update_stock', params: {'mat_id': materialId, 'qty': quantity, 'type': type});
      return true;
    } catch (e) {
      debugPrint('Error recording transaction: $e');
      return false;
    }
  }

  // ─── RECIPES ───────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getRecipes() async {
    try {
      final response = await _supabase.from('recipes').select();
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting recipes: $e');
      return [];
    }
  }

  static Future<bool> saveRecipe(Map<String, dynamic> data) async {
    try {
      await _supabase.from('recipes').upsert(data);
      return true;
    } catch (e) {
      debugPrint('Error saving recipe: $e');
      return false;
    }
  }

  static Future<bool> deleteRecipe(String productId, String materialId) async {
    try {
      await _supabase.from('recipes').delete().match({'product_id': productId, 'material_id': materialId});
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      return false;
    }
  }

  // ─── KITCHEN SYNC ─────────────────────────────────────
  static Future<bool> syncKitchenStock(String productId, int quantity, bool isAvailable, [String? session]) async {
    try {
      await _supabase.from('products').update({
        'quantity': quantity,
        'is_available': isAvailable,
      }).eq('id', productId);
      return true;
    } catch (e) {
      debugPrint('Error syncing kitchen stock: $e');
      return false;
    }
  }
}
