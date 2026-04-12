import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> initDesktopDatabase() async {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}
