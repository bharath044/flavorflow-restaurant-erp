import '../models/invoice.dart';
import 'api_service.dart';

class InvoiceService {
  // ─── DATA PERSISTENCE ──────────────────────────────────────
  
  static Future<bool> save(Map<String, dynamic> data) async {
    // Map existing Map format to Invoice model if needed, 
    // but the app should ideally pass Invoice objects now.
    // For backward compatibility, we'll try to convert.
    try {
      final invoice = Invoice.fromDbMap(data); 
      return await ApiService.saveInvoice(invoice);
    } catch (e) {
      // If it's the old bills format (billNo etc), we might need manual mapping
      // Or just assume the app is updated to use the Invoice model properly.
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getBills() async {
    final list = await ApiService.getInvoices();
    // Return list of maps for legacy UI compatibility
    return list.map((inv) => inv.toJson()).toList();
  }

  // ─── ANALYTICS ─────────────────────────────────────────────

  static Future<double> todaySales(DateTime day) => ApiService.getTodaySales();
  
  static Future<double> gstTotal() => ApiService.getGstTotal();

  // ─── CRUD (LEGACY/ADMIN) ───────────────────────────────────

  static Future<void> deleteBill(dynamic key) async {
    final String id = key.toString();
    await ApiService.deleteInvoice(id);
  }

  static Future<void> updateBill(dynamic key, Map<String, dynamic> updated) async {
    final String id = key.toString();
    await ApiService.updateInvoice(id, updated);
  }

  static Future<List<Map<String, dynamic>>> getAllSafe() async {
    return await getBills();
  }
}
