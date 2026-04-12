/// WEB STUB — dart:io is not available on web.
/// All platform flags return false / safe defaults.

bool get platformIsWindows => false;
bool get platformIsLinux   => false;
bool get platformIsMacOS   => false;
bool get platformIsAndroid => false;
bool get platformIsIOS     => false;
bool get platformIsDesktop => false;
bool get platformIsMobile  => false;

String get platformHostname => 'web-client';

/// Returns empty string on web — caller must fall back to path_provider.
Future<String> getHiveDirPath() async => '';
