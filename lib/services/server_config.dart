class ServerConfig {
  /// 🌐 SUPABASE CONFIGURATION
  static const String supabaseUrl = 'https://jpjbkfokaygbflvalvvg.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpwamJrZm9rYXlnYmZsdmFsdnZnIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY1NTkzODksImV4cCI6MjA5MjEzNTM4OX0.XFM_vbkWFXqxRLU8Pc97oYuCDZbPuIy2pdgVVFouzoc';

  /// Legacy helper for display logic (optional)
  static String get baseUrl => supabaseUrl;
  
  static String get serverIp => 'Supabase Cloud';

  static Future<void> loadIp() async {}
  static Future<void> saveIp(String ip) async {}
}
