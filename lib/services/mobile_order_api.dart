import 'dart:convert';
import 'package:http/http.dart' as http;

class MobileOrderApi {
  static Future<bool> sendOrder(
    String desktopIp,
    Map<String, dynamic> order,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('http://$desktopIp:4040/order'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(order),
      );

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
