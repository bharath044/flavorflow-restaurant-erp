import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/order_provider.dart';
import 'billing_screen.dart';

class ServerOrdersSheet extends StatelessWidget {
  const ServerOrdersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = context
    .watch<OrderProvider>()
    .activeOrders
    .where((o) => o.tableNo != "TAKEAWAY")
    .toList();


    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: orders.isEmpty
            ? const Center(child: Text("No server orders"))
            : ListView.builder(
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];

                  return Card(
                    child: ListTile(
                      title: Text("Table ${order.tableNo}"),
                      subtitle:
                          Text("${order.items.length} items"),
                      trailing:
                          const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        Navigator.pop(context); // close sheet

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BillingScreen(
                              tableNo: order.tableNo,
                              onToggleTheme: () {},
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
