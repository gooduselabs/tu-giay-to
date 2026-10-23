import 'dates.dart';
import 'text.dart';

/// Kết quả đọc vùng MRZ (ICAO 9303): TD1 (thẻ, 3 dòng × 30) hoặc TD3 (hộ chiếu, 2 dòng × 44).
class MrzResult {
  final String format; // 'TD1' | 'TD3'
  final String docCode;
  final String country;
  final String number; // số giấy tờ (TD1 VN: số định danh 12 số nếu có)
  final String rawDocNumber;
  final DateTime? birth;
  final DateTime? expiry;
  final String? sex; // 'M' | 'F'
  final String surname;
  final String given;
  final int checksPassed;
  final int checksTotal;
  MrzResult({
    required this.format,
    required this.docCode,
    required this.country,
    required this.number,
    required this.rawDocNumber,
    required this.birth,
    required this.expiry,
    required this.sex,
    required this.surname,
    required this.given,
    required this.checksPassed,
    required this.checksTotal,
  });
  bool get valid => checksPassed == checksTotal;
  String get fullName => '$surname $given'.trim();
  bool get isPassport => format == 'TD3' && docCode.startsWith('P');
  bool get isVnId => format == 'TD1' && country == 'VNM' && (docCode.startsWith('I') || docCode.startsWith('C'));
  @override
  String toString() => 'MRZ($format $docCode $country $number $birth $expiry $sex $fullName $checksPassed/$checksTotal)';
}

int _val(String c) {
  final u = c.codeUnitAt(0);
  if (u >= 48 && u <= 57) return u - 48;
  if (u >= 65 && u <= 90) return u - 55;
  return 0; // '<'
}

/// Chữ số kiểm tra ICAO (trọng số 7-3-1).
int mrzCheck(String s) {
  const w = [7, 3, 1];
  var sum = 0;
  for (var i = 0; i < s.length; i++) {
    sum += _val(s[i]) * w[i % 3];
  }
  return sum % 10;
}

bool _ok(String field, String cd) => cd.length == 1 && RegExp(r'\d').hasMatch(cd) && mrzCheck(field) == int.parse(cd);

/// Chuẩn hoá một dòng OCR thành dòng MRZ: hoa, bỏ khoảng trắng, sửa ký tự nhồi '<' bị đọc sai.
String cleanMrzLine(String s) {
  var t = s.toUpperCase().replaceAll(RegExp(r'\s+'), '');
  t = t.replaceAll(RegExp('[«‹\u2039\u00ab]'), '<');
  // Chuỗi ký tự nhồi hay bị đọc thành K, C, L, E… khi đứng thành dãy cạnh '<'.
  t = t.replaceAllMapped(RegExp(r'(?<=<)[KCLE](?=<)'), (_) => '<');
  t = t.replaceAllMapped(RegExp(r'<[KCLE]{1,2}$'), (m) => '<' * m[0]!.length);
  t = t.replaceAll(RegExp(r'[^A-Z0-9<]'), '');
  return t;
}

/// Sửa trường số theo vị trí, rồi thử đảo các ký tự dễ nhầm cho tới khi khớp chữ số kiểm tra.
(String, bool) _fixNumeric(String f, String cd) {
  final v = asDigits(f), c = asDigits(cd);
  return (v, _ok(v, c));
}

(String, bool) _fixAlnum(String f, String cd) {
  final c = asDigits(cd);
  if (_ok(f, c)) return (f, true);
  const swaps = {'O': '0', '0': 'O', 'I': '1', '1': 'I', 'S': '5', '5': 'S', 'B': '8', '8': 'B', 'Z': '2', '2': 'Z', 'D': '0', 'G': '6', '6': 'G'};
  for (var i = 0; i < f.length; i++) {
    final s = swaps[f[i]];
    if (s == null) continue;
    final t = f.substring(0, i) + s + f.substring(i + 1);
    if (_ok(t, c)) return (t, true);
  }
  // Số hộ chiếu VN: 1 chữ cái + 7 số — ép theo khuôn rồi thử lại.
  if (RegExp(r'^[A-Z0-9]{8}<?$').hasMatch(f)) {
    final t = asAlpha(f[0]) + asDigits(f.substring(1));
    if (_ok(t, c)) return (t, true);
  }
  return (f, false);
}

DateTime? _yymmdd(String s, {required bool future, DateTime? now}) {
  if (!RegExp(r'^\d{6}$').hasMatch(s)) return null;
  final yy = int.parse(s.substring(0, 2));
  final cur = (now ?? DateTime.now()).year % 100;
  final century = future ? (yy >= 70 ? 1900 : 2000) : (yy > cur ? 1900 : 2000);
  return mkDate(century + yy, int.parse(s.substring(2, 4)), int.parse(s.substring(4, 6)));
}

(String, String) _names(String s) {
  final t = s.replaceAll(RegExp(r'<+$'), '');
  final parts = t.split('<<');
  final sur = asAlpha(parts.first).replaceAll('<', ' ').trim();
  final given = parts.length > 1 ? asAlpha(parts.sublist(1).join(' ')).replaceAll('<', ' ').replaceAll(RegExp(r'\s+'), ' ').trim() : '';
  return (sur, given);
}

String _fit(String s, int n) => s.length >= n ? s.substring(0, n) : s.padRight(n, '<');

/// Tìm và đọc MRZ trong các dòng OCR. Trả về null nếu không thấy.
MrzResult? parseMrz(List<String> lines, {DateTime? now}) {
  final c = lines.map(cleanMrzLine).toList();
  // TD3: dòng bắt đầu bằng P + dòng sau dài ~44
  for (var i = 0; i + 1 < c.length; i++) {
    final a = c[i], b = c[i + 1];
    if (a.length >= 38 && a.length <= 48 && a.startsWith('P') && a.contains('<<') && b.length >= 38 && b.length <= 48) {
      final r = _td3(_fit(a, 44), _fit(b, 44), now);
      if (r != null) return r;
    }
  }
  // TD1: 3 dòng ~30, dòng đầu bắt đầu bằng I/A/C
  for (var i = 0; i + 2 < c.length; i++) {
    final a = c[i], b = c[i + 1], d = c[i + 2];
    bool len(String x) => x.length >= 26 && x.length <= 34;
    if (len(a) && len(b) && len(d) && RegExp(r'^[IAC][A-Z<]').hasMatch(a)) {
      final r = _td1(_fit(a, 30), _fit(b, 30), _fit(d, 30), now);
      if (r != null) return r;
    }
  }
  // TD1 khi OCR gộp/tách dòng: thử nối toàn bộ dòng có '<' rồi cắt 90 ký tự.
  final joined = c.where((l) => l.contains('<') || RegExp(r'^\d{6,}').hasMatch(l)).join();
  final at = joined.indexOf(RegExp(r'[IAC][A-Z<][A-Z]{3}'));
  if (at >= 0 && joined.length - at >= 85) {
    final s = _fit(joined.substring(at), 90);
    return _td1(s.substring(0, 30), s.substring(30, 60), s.substring(60, 90), now);
  }
  return null;
}

MrzResult? _td1(String l1, String l2, String l3, DateTime? now) {
  final docCode = l1.substring(0, 2).replaceAll('<', '');
  final country = asAlpha(l1.substring(2, 5));
  var passed = 0;
  final (docNo, okNo) = _fixAlnum(l1.substring(5, 14), l1.substring(14, 15));
  final opt1 = l1.substring(15, 30);
  final (dob, okDob) = _fixNumeric(l2.substring(0, 6), l2.substring(6, 7));
  final sex = l2.substring(7, 8);
  final (exp, okExp) = _fixNumeric(l2.substring(8, 14), l2.substring(14, 15));
  final opt2 = l2.substring(18, 29);
  final composite = '${l1.substring(5, 14).replaceRange(0, 9, docNo)}${l1.substring(14, 15)}$opt1'
      '$dob${l2.substring(6, 7)}$exp${l2.substring(14, 15)}$opt2';
  final okComp = _ok(composite, asDigits(l2.substring(29, 30)));
  for (final ok in [okNo, okDob, okExp, okComp]) {
    if (ok) passed++;
  }
  if (passed == 0 && !RegExp(r'^\d{6}$').hasMatch(dob)) return null;
  // VN: số định danh 12 chữ số nằm trong vùng tuỳ chọn của dòng 1.
  final full = RegExp(r'\d{12}').firstMatch(asDigits(opt1.replaceAll('<', ' ')))?.group(0);
  final (sur, given) = _names(l3);
  return MrzResult(
    format: 'TD1',
    docCode: docCode,
    country: country,
    number: full ?? docNo.replaceAll('<', ''),
    rawDocNumber: docNo.replaceAll('<', ''),
    birth: _yymmdd(dob, future: false, now: now),
    expiry: _yymmdd(exp, future: true, now: now),
    sex: sex == 'M' || sex == 'F' ? sex : null,
    surname: sur,
    given: given,
    checksPassed: passed,
    checksTotal: 4,
  );
}

MrzResult? _td3(String l1, String l2, DateTime? now) {
  final docCode = l1.substring(0, 2).replaceAll('<', '');
  final country = asAlpha(l1.substring(2, 5));
  final (sur, given) = _names(l1.substring(5));
  var passed = 0;
  final (docNo, okNo) = _fixAlnum(l2.substring(0, 9), l2.substring(9, 10));
  final (dob, okDob) = _fixNumeric(l2.substring(13, 19), l2.substring(19, 20));
  final sex = l2.substring(20, 21);
  final (exp, okExp) = _fixNumeric(l2.substring(21, 27), l2.substring(27, 28));
  final composite = '$docNo${l2.substring(9, 10)}$dob${l2.substring(19, 20)}$exp${l2.substring(27, 43)}';
  final okComp = _ok(composite, asDigits(l2.substring(43, 44)));
  for (final ok in [okNo, okDob, okExp, okComp]) {
    if (ok) passed++;
  }
  return MrzResult(
    format: 'TD3',
    docCode: docCode,
    country: country,
    number: docNo.replaceAll('<', ''),
    rawDocNumber: docNo.replaceAll('<', ''),
    birth: _yymmdd(dob, future: false, now: now),
    expiry: _yymmdd(exp, future: true, now: now),
    sex: sex == 'M' || sex == 'F' ? sex : null,
    surname: sur,
    given: given,
    checksPassed: passed,
    checksTotal: 4,
  );
}

/// Dựng MRZ hợp lệ (dùng cho kiểm thử và ảnh mẫu).
List<String> buildTd1({
  required String docNumber9,
  required String optional1,
  required String dob,
  required String sex,
  required String exp,
  required String surname,
  required String given,
  String code = 'ID',
  String country = 'VNM',
}) {
  final l1 = '${_fit(code, 2)}$country${_fit(docNumber9, 9)}${mrzCheck(_fit(docNumber9, 9))}${_fit(optional1, 15)}';
  final head = '$dob${mrzCheck(dob)}$sex$exp${mrzCheck(exp)}$country';
  final opt2 = _fit('', 11);
  final comp = mrzCheck('${l1.substring(5, 30)}$dob${mrzCheck(dob)}$exp${mrzCheck(exp)}$opt2');
  final l2 = '$head$opt2$comp';
  final l3 = _fit('${surname.replaceAll(' ', '<')}<<${given.replaceAll(' ', '<')}', 30);
  return [l1, l2, l3];
}

List<String> buildTd3({
  required String number,
  required String dob,
  required String sex,
  required String exp,
  required String surname,
  required String given,
  String country = 'VNM',
  String personal = '',
}) {
  final l1 = _fit('P<$country${surname.replaceAll(' ', '<')}<<${given.replaceAll(' ', '<')}', 44);
  final no = _fit(number, 9);
  final pn = _fit(personal, 14);
  final body = '$no${mrzCheck(no)}$country$dob${mrzCheck(dob)}$sex$exp${mrzCheck(exp)}$pn${mrzCheck(pn)}';
  final comp = mrzCheck('$no${mrzCheck(no)}$dob${mrzCheck(dob)}$exp${mrzCheck(exp)}$pn${mrzCheck(pn)}');
  return [l1, '$body$comp'];
}
