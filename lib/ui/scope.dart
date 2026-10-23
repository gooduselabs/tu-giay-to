import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../core/ocr_parser.dart';
import '../data/store.dart';

typedef OcrFn = Future<OcrGuess> Function(List<({Uint8List bytes, bool pdf})> files);

/// Cung cấp store + dịch vụ cho cây widget (dịch vụ có thể null trong test/golden).
class AppScope extends InheritedNotifier<AppStore> {
  final OcrFn? ocr;
  final bool platformServices;
  const AppScope({super.key, required AppStore store, this.ocr, this.platformServices = true, required super.child})
      : super(notifier: store);

  static AppScope of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<AppScope>()!;
  static AppStore store(BuildContext c) => of(c).notifier!;
}
