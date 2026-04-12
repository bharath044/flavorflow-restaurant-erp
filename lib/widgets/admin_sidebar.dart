import 'package:flutter/material.dart';
import '../screens/sales_dashboard_screen.dart';

class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 70,
      color: const Color(0xFFFF6D00),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _icon(context, Icons.dashboard, SalesDashboardScreen()),
          _icon(context, Icons.fastfood, null),
          _icon(context, Icons.people, null),
          _icon(context, Icons.settings, null),
        ],
      ),
    );
  }

  Widget _icon(BuildContext context, IconData icon, Widget? page) {
    return IconButton(
      icon: Icon(icon, color: Colors.white),
      onPressed: page == null
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => page),
              );
            },
    );
  }
}
