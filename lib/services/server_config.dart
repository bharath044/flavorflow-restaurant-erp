class ServerConfig {
  /// 🌐 SUPABASE CONFIGURATION
  static const String supabaseUrl = 'https://jpjbkfokaygbflvalvvg.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_zpUZhmR4M9NXNjthUNAiGA_kgF4tMVL';

  /// Legacy helper for display logic (optional)
  static String get baseUrl => supabaseUrl;
  
  static String get serverIp => 'Supabase Cloud';

  static Future<void> loadIp() async {}
  static Future<void> saveIp(String ip) async {}
}
