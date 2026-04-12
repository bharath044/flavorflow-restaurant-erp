import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class BackupService {
  static Future<void> dailyBackup() async {
    /// ❌ WEB DOES NOT SUPPORT FILE SYSTEM
    if (kIsWeb) return;

    final baseDir = await getApplicationDocumentsDirectory();

    final dbFile = File(
      join(baseDir.path, 'RestaurantBilling', 'database', 'billing.db'),
    );

    if (!dbFile.existsSync()) return;

    final backupDir =
        Directory(join(baseDir.path, 'RestaurantBilling', 'backups'));

    await backupDir.create(recursive: true);

    final now = DateTime.now();
    final backupName =
        'billing_${now.year}_${now.month}_${now.day}.db';

    final backupFile = File(join(backupDir.path, backupName));

    /// already backed up today
    if (backupFile.existsSync()) return;

    await dbFile.copy(backupFile.path);

    /// keep last 30 days onlyz
    for (final f in backupDir.listSync()) {
      if (f is File) {
        final age = DateTime.now().difference(f.lastModifiedSync()).inDays;
        if (age > 30) {
          f.deleteSync();
        }
      }
    }
  }
}
