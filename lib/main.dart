import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/secure_impl.dart';
import 'data/store.dart';
import 'services/cloud_backup.dart';
import 'services/notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'services/ocr_service.dart';
import 'ui/app.dart';

/// Tác vụ nền: sao lưu tự động lên Google Drive (không tương tác).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      final pw = await CloudBackup.readPassword();
      if (pw == null || !CloudBackup.configured) return true;
      final vault = EncryptedFileVault();
      await vault.init();
      final store = AppStore(db: SqlCipherPersistence(), vault: vault);
      await store.load();
      if (store.driveAuto == 'off' || store.driveEmail == null) return true;
      await CloudBackup.backupNow(store, pw, interactive: false);
      return true;
    } catch (_) {
      return false; // workmanager sẽ thử lại theo backoff
    }
  });
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('vi');
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  final reminders = LocalReminders();
  try {
    await reminders.init();
  } catch (_) {}
  final vault = EncryptedFileVault();
  await vault.init();
  final store = AppStore(db: SqlCipherPersistence(), vault: vault, reminders: reminders);
  await store.load();
  reminders.hour = store.reminderHour;
  unawaited(store.resync());
  try {
    await Workmanager().initialize(callbackDispatcher);
  } catch (_) {}
  store.onDataChanged = () {
    if (store.driveAuto == 'change' && store.driveEmail != null) CloudBackup.scheduleAfterChange();
  };

  final ocr = OcrService();
  runApp(TuGiayToApp(
    store: store,
    ocr: ocr.analyse,
    requestNotificationPermission: reminders.requestPermission,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  ));
}
