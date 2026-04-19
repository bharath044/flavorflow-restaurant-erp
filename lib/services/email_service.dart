// WEB-SAFE STUB
class EmailService {
  static Future<void> sendEmail(String to, String subject, String body) async {}
  
  static Future<void> sendReport(
    dynamic file,
    String date,
    String to, {
    Map<String, dynamic>? summary,
    List<Map<String, dynamic>>? items,
    double? expense,
  }) async {}
}
