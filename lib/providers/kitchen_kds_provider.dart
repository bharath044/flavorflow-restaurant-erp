import 'package:flutter/material.dart';

class KitchenKdsProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _orders = [];

  List<Map<String, dynamic>> get orders => _orders;

  void addOrder(Map<String, dynamic> order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  void markPrepared(String orderId) {
    _orders.removeWhere((o) => o['orderId'] == orderId);
    notifyListeners();
  }
}
