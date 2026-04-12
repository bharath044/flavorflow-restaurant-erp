import 'package:hive/hive.dart';

class ReportSettingsService {
  static const _boxName = 'report_settings';

  static Future<void> init() async {
    await Hive.openBox(_boxName);
  }

  // ✅ Updated to include safety check to prevent "Box not found" errors
  static Box get _box {
    if (!Hive.isBoxOpen(_boxName)) {
      throw Exception('$_boxName box not opened. Ensure init() is called and awaited.');
    }
    return Hive.box(_boxName);
  }

  static String get email =>
      _box.get('email', defaultValue: 'owner@gmail.com');

  static int get hour =>
      _box.get('hour', defaultValue: 23);

  static int get minute =>
      _box.get('minute', defaultValue: 30);

  static Future<void> save({
    required String email,
    required int hour,
    required int minute,
  }) async {
    await _box.put('email', email);
    await _box.put('hour', hour);
    await _box.put('minute', minute);
  }
}