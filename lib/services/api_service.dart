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
      return (response as List).map((p) => Product.fromMap({
        ...p,
        'isAvailable': p['is_available'],
        'image': p['image_url'],
      })).toList();
    } catch (e) {
      debugPrint('Error getting products: $e');
      return [];
    }
  }

  static Future<List<Product>> getPublicProducts() => getProducts();

  static Future<bool> createProduct(Map<String, dynamic> data, {File? imageFile, Uint8List? imageBytes}) async {
    try {
      String? imageUrl;
      if (imageFile != null || imageBytes != null) {
        imageUrl = await _uploadImage(imageFile, imageBytes);
      }

      await _supabase.from('products').insert({
        'id': data['id'],
        'name': data['name'],
        'price': data['price'],
        'category': data['category'],
        'image_url': imageUrl ?? data['image'],
        'quantity': data['quantity'] ?? 0,
        'is_available': data['isAvailable'] ?? true,
        'description': data['description'] ?? '',
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

      await _supabase.from('products').update({
        'name': data['name'],
        'price': data['price'],
        'category': data['category'],
        'image_url': imageUrl ?? data['image'],
        'quantity': data['quantity'] ?? 0,
        'is_available': data['isAvailable'] ?? true,
        'description': data['description'] ?? '',
      }).eq('id', id);
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
      final path = fileName;
      
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
    return {
      'url': 'https://flavorflow-restaurant-erp.vercel.app/menu/$tableNo',
    };
  }

  // ─── CATEGORIES ───────────────────────────────────────────
  static Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      final response = await _supabase.from('categories').select();
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      debugPrint('Error getting categories: $e');
      return [];
    }
  }

  static Future<bool> addCategory(String name) async {
    try {
      await _supabase.from('categories').insert({'name': name});
      return true;
    } catch (e) {
      debugPrint('Error adding category: $e');
      return false;
    }
  }

  static Future<bool> deleteCategory(String name) async {
    try {
      await _supabase.from('categories').delete().eq('name', name);
      return true;
    } catch (e) {
      debugPrint('Error deleting category: $e');
      return false;
    }
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
}
