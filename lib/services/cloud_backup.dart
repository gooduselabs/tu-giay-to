import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:workmanager/workmanager.dart';

import '../config/google_config.dart';
import '../data/store.dart';
import 'drive_backup.dart';

/// Điều phối sao lưu Google Drive: thủ công, khôi phục, tự động (workmanager).
class CloudBackup {
  static const _pwKey = 'tgt_auto_backup_pw';
  static const _storage = FlutterSecureStorage();
  static const taskName = 'tgt-drive-backup';

  static bool? debugConfigured; // cho golden test
  static bool get configured => debugConfigured ?? GoogleConfig.isConfigured;

  static DriveApi api({bool interactive = true}) =>
      DriveApi(() => GoogleDriveAuth.token(interactive: interactive));

  static String fileName(DateTime t) => 'tu-giay-to-${DateFormat('yyyyMMdd-HHmmss').format(t)}.tgtbak';

  static Future<DriveFile> backupNow(AppStore store, String password, {bool interactive = true}) async {
    final bytes = await store.exportBackup(password);
    final f = await api(interactive: interactive).upload(bytes, fileName(DateTime.now()));
    await store.setSetting('drive_last', DateTime.now().toIso8601String());
    await store.setSetting('dirty', '0');
    return f;
  }

  static Future<int> restore(AppStore store, DriveFile f, String password) async {
    final bytes = await api().download(f.id);
    return store.importBackup(bytes, password);
  }

  /// Mật khẩu cho sao lưu tự động, lưu trong Keystore/Keychain (chỉ khi người dùng bật).
  static Future<void> savePassword(String? pw) =>
      pw == null ? _storage.delete(key: _pwKey) : _storage.write(key: _pwKey, value: pw);
  static Future<String?> readPassword() => _storage.read(key: _pwKey);

  /// mode: off | daily | change
  static Future<void> applySchedule(String mode) async {
    if (defaultTargetPlatform != TargetPlatform.android && defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await Workmanager().cancelByUniqueName('$taskName-daily');
      if (mode == 'daily') {
        await Workmanager().registerPeriodicTask('$taskName-daily', taskName,
            frequency: const Duration(hours: 24),
            constraints: Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true));
      }
    } catch (_) {}
  }

  /// Gọi khi dữ liệu thay đổi (chế độ "sau khi thay đổi"): dồn trong 15 phút rồi chạy 1 lần.
  static Future<void> scheduleAfterChange() async {
    try {
      await Workmanager().registerOneOffTask('$taskName-change', taskName,
          initialDelay: const Duration(minutes: 15),
          existingWorkPolicy: ExistingWorkPolicy.replace,
          constraints: Constraints(networkType: NetworkType.connected));
    } catch (_) {}
  }
}
