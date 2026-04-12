import 'package:flutter/material.dart';

import '../models/user_role.dart';

// ================= ADMIN =================
import '../screens/admin_dashboard_screen.dart';

// ================= STAFF =================
import '../screens/staff_open_table_screen.dart';

// ================= SERVER =================
import '../screens/server_table_screen.dart';

// ================= KITCHEN =================
import '../screens/kitchen_kds_screen.dart';

// ================= AUTH =================
import '../screens/role_select_screen.dart';

class RoleRouter {
  /// ================= HOME ROUTER =================
  /// USED AFTER LOGIN / APP START
  static Widget home(UserRole? role) {
    switch (role) {
      case UserRole.admin:
        return const AdminDashboardScreen();

      case UserRole.staff:
        return const StaffOpenTableScreen();

      case UserRole.server:
        return const ServerTableScreen();

      case UserRole.kitchen:
        return const KitchenKDSScreen();

      default:
        // 🔐 NOT LOGGED IN / INVALID ROLE
        return const RoleSelectScreen();
    }
  }

  /// ================= BACKWARD SUPPORT =================
  /// OLD CODE SAFETY (if used anywhere)
  static Widget getHome(UserRole role) {
    return home(role);
  }
}
