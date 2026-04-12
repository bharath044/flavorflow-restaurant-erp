import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import '../services/auth_provider.dart';
import 'billing_screen.dart';
import 'role_select_screen.dart';
import 'qr_scanner_screen.dart';

class StaffOpenTableScreen extends StatelessWidget {
  const StaffOpenTableScreen({super.key});

  static const Color brandOrange = Color(0xFFFF6A00);
  static const Color freeGreen = Color(0xFF4CAF50);

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final tables = List.generate(12, (i) => "T${i + 1}");

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: brandOrange,
        centerTitle: true,
        elevation: 3,
        automaticallyImplyLeading: false,
        title: const Text(
          "SELECT TABLE",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.4,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.exit_to_app, color: Colors.white),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          itemCount: tables.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.25,
          ),
          itemBuilder: (context, index) {
            final tableNo = tables[index];
            final status = orderProvider.getTableStatus(tableNo);
            final bool isRunning = status == TableStatus.running;

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BillingScreen(
                        tableNo: tableNo,
                        onToggleTheme: () {},
                      ),
                    ),
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isRunning ? brandOrange : freeGreen,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        tableNo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isRunning ? "RUNNING" : "FREE",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final String? tableNo = await Navigator.push<String>(
            context,
            MaterialPageRoute(builder: (_) => const QrScannerScreen()),
          );
          
          if (tableNo != null && context.mounted) {
            await context.read<OrderProvider>().fetchOrderForTable(tableNo);
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BillingScreen(
                    tableNo: tableNo,
                    onToggleTheme: () {},
                  ),
                ),
              );
            }
          }
        },
        backgroundColor: brandOrange,
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('SCAN TABLE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}