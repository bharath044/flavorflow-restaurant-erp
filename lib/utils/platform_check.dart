/// Platform-agnostic helper.
/// On web  → platform_check_web.dart  (all false, no dart:io)
/// On native → platform_check_io.dart  (real dart:io Platform values)
export 'platform_check_web.dart'
    if (dart.library.io) 'platform_check_io.dart';
