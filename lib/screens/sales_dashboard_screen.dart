import 'package:flutter/material.dart';
import '../services/invoice_service.dart';

class SalesDashboardScreen extends StatelessWidget {
  const SalesDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        title: const Text(
          "Sales Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: InvoiceService.getBills(),
          builder: (context, snapshot) {
            // 🔄 Loading
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            // ❌ Error
            if (snapshot.hasError) {
              return const Center(
                child: Text("Failed to load sales data"),
              );
            }

            final bills = snapshot.data ?? [];

            // 📭 Empty
            if (bills.isEmpty) {
              return const Center(
                child: Text(
                  "No bills found",
                  style: TextStyle(fontSize: 18),
                ),
              );
            }

            // 📋 Bills List
            return ListView.separated(
              itemCount: bills.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final bill = bills[i];

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.receipt_long,
                        color: Color(0xFF1E88E5)),
                    title: Text(
                      bill['billNo'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      bill['date'].toString().substring(0, 19),
                    ),
                    trailing: Text(
                      "₹${bill['total']}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
