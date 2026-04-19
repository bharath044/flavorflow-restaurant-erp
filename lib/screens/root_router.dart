import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../models/user_role.dart';
import 'admin_dashboard_screen.dart';
import 'server_table_screen.dart';
import 'kitchen_screen.dart';
import 'role_select_screen.dart';

class RootRouter extends StatelessWidget {
  const RootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      return const RoleSelectScreen();
    }

    switch (auth.role) {
      case UserRole.admin:
        return const AdminDashboardScreen();
      case UserRole.server:
      case UserRole.staff:
        return const ServerTableScreen();
      case UserRole.kitchen:
        return const KitchenScreen();
      default:
        return const RoleSelectScreen();
    }
  }
}
