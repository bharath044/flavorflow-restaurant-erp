import 'package:flutter/material.dart';

enum AdminPage {
  dashboard,
  reports,
  monthlyComparison,
  weekly,
  topProducts,
  categories,
  addProduct,
  monthlyReport,
}

class NavigationProvider extends ChangeNotifier {
  AdminPage _page = AdminPage.dashboard;

  AdminPage get page => _page;

  void go(AdminPage newPage) {
    _page = newPage;
    notifyListeners();
  }

  void reset() {
    _page = AdminPage.dashboard;
    notifyListeners();
  }
}
