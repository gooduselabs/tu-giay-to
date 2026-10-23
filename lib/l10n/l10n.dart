import 'package:flutter/foundation.dart';
import 'en.dart';

/// Bản địa hoá đơn giản: chuỗi tiếng Việt là khoá, `en.dart` chứa bản dịch.
/// Thiếu bản dịch -> hiển thị tiếng Việt.
class L10n {
  static final ValueNotifier<String> locale = ValueNotifier('vi');
  static bool get isEn => locale.value == 'en';
}

String tr(String vi, [Map<String, Object>? args]) {
  var s = L10n.isEn ? (enStrings[vi] ?? vi) : vi;
  args?.forEach((k, v) => s = s.replaceAll('{$k}', '$v'));
  return s;
}
