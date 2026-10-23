import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/secure_impl.dart';
import 'data/store.dart';
import 'services/notifications.dart';
import 'services/ocr_service.dart';
import 'ui/app.dart';

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


  final ocr = OcrService();
  runApp(TuGiayToApp(
    store: store,
    ocr: ocr.analyse,
    requestNotificationPermission: reminders.requestPermission,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
  ));
}
