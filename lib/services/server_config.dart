class ServerConfig {
  /// 🚀 SET TO 'true' TO USE VERCEL CLOUD BACKEND
  static const bool useCloud = false;

  /// 🌐 CLOUD BACKEND URL (Vercel)
  /// Replace with your actual Vercel URL after deployment
  /// e.g. 'https://flavorflow-api.vercel.app'
  static const String _cloudUrl = 'https://YOUR_PROJECT_NAME.vercel.app';

  /// 🏠 LOCAL BACKEND URL
  static const String _localUrl = 'http://192.168.1.37:3000';

  /// ✅ Dynamic Base URL
  static String get baseUrl => useCloud ? _cloudUrl : _localUrl;

  /// Legacy helper (returns URL without protocol if needed, though rarely used now)
  static String get serverIp => baseUrl.replaceAll(RegExp(r'https?://'), '').split(':').first;

  // No longer using SharedPreferences for IP storage 
  // since we are moving to a zero-configuration backend.
  static Future<void> loadIp() async {}
  static Future<void> saveIp(String ip) async {}
}
