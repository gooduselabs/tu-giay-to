import 'text.dart';

DateTime? mkDate(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2200) return null;
  final dt = DateTime(y, m, d);
  return dt.month == m && dt.day == d ? dt : null;
}

const _g = r'[0-9OoQDIl|!SBZ]';
final _dmy = RegExp('(?<![0-9])($_g{1,2})\\s*[/\\-.,\\\\]\\s*($_g{1,2})\\s*[/\\-.,\\\\]\\s*($_g{4})(?![0-9])');
final _words = RegExp(r'NGAY\s*(\d{1,2})\s*THANG\s*(\d{1,2})\s*NAM\s*(\d{4})');
final _spaced = RegExp(r'(?<![0-9])(\d{2})\s+(\d{2})\s+(\d{4})(?![0-9])');
final _compact = RegExp(r'(?<![0-9])(\d{2})(\d{2})(\d{4})(?![0-9])');

/// Mọi ngày trong chuỗi, theo thứ tự xuất hiện.
/// Hỗ trợ dd/mm/yyyy, dd-mm-yyyy, dd.mm.yyyy (kể cả nhiễu OCR như O→0, l→1, khoảng trắng),
/// "ngày 12 tháng 3 năm 2020". [loose] cho phép thêm "12 03 2020" và "12032020"
/// (chỉ dùng khi đã biết đây là ô ngày tháng).
List<DateTime> datesIn(String s, {bool loose = false}) {
  final found = <(int, DateTime)>[];
  for (final m in _dmy.allMatches(s)) {
    final d = mkDate(int.parse(asDigits(m[3]!)), int.tryParse(asDigits(m[2]!)) ?? 0, int.tryParse(asDigits(m[1]!)) ?? 0);
    if (d != null) found.add((m.start, d));
  }
  final f = fold(s);
  if (f.length == s.length) {
    for (final m in _words.allMatches(f)) {
      final d = mkDate(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
      if (d != null) found.add((m.start, d));
    }
  } else {
    for (final m in _words.allMatches(f)) {
      final d = mkDate(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
      if (d != null) found.add((0, d));
    }
  }
  if (loose && found.isEmpty) {
    for (final re in [_spaced, _compact]) {
      for (final m in re.allMatches(s)) {
        final d = mkDate(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
        if (d != null) found.add((m.start, d));
      }
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final x in found) x.$2];
}

/// ddMMyyyy (QR CCCD) hoặc dd/MM/yyyy.
DateTime? parseDmyCompact(String s) {
  final t = s.trim();
  final m = RegExp(r'^(\d{2})(\d{2})(\d{4})$').firstMatch(t);
  if (m != null) return mkDate(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
  final ds = datesIn(t);
  return ds.isEmpty ? null : ds.first;
}
