/// NATIVE (dart:io) implementation of platform helpers.
/// Used on Android, iOS, Windows, Linux, macOS.
import 'dart:io';

bool get platformIsWindows => Platform.isWindows;
bool get platformIsLinux   => Platform.isLinux;
bool get platformIsMacOS   => Platform.isMacOS;
bool get platformIsAndroid => Platform.isAndroid;
bool get platformIsIOS     => Platform.isIOS;
bool get platformIsDesktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;
bool get platformIsMobile  => Platform.isAndroid || Platform.isIOS;

String get platformHostname {
  try {
    return Platform.localHostname;
  } catch (_) {
    return 'unknown-device';
  }
}

/// Returns the Hive directory path for the current platform.
/// Creates the directory if it doesn't exist (Windows).
/// Returns empty string on non-Windows → caller uses path_provider.
Future<String> getHiveDirPath() async {
  if (Platform.isWindows) {
    final dir = Directory('${Directory.current.path}/hive_windows');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }
  return ''; // Other platforms → use getApplicationDocumentsDirectory()
}
