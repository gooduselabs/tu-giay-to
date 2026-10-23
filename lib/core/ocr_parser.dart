import 'models.dart';

/// Kết quả nhận dạng — người dùng luôn xác nhận/sửa trước khi lưu.
class OcrGuess {
  DocType? type;
  String? number;
  String? name;
  DateTime? issueDate;
  DateTime? expiryDate;
  DateTime? birthDate;
  String? plate;
  double confidence = 0;
  OcrGuess();
  bool get isEmpty =>
      type == null && number == null && name == null && expiryDate == null;
  @override
  String toString() =>
      'OcrGuess($type, $number, $name, issue=$issueDate, exp=$expiryDate, dob=$birthDate, plate=$plate)';
}

const _from = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
const _to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';

/// Bỏ dấu tiếng Việt + viết hoa, để so khớp từ khoá ổn định với lỗi OCR.
String fold(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final c = String.fromCharCode(r);
    final i = _from.indexOf(c);
    b.write(i >= 0 ? _to[i] : c);
  }
  return b.toString().toUpperCase();
}

DocType? detectType(String folded) {
  bool has(List<String> ks) => ks.any(folded.contains);
  final compact = folded.replaceAll(' ', '');
  if (RegExp(r'P<[A-Z]{3}').hasMatch(compact) ||
      has(['PASSPORT', 'HO CHIEU'])) {
    return DocType.passport;
  }
  if (has(['BAO HIEM Y TE', 'BHYT', 'HEALTH INSURANCE'])) return DocType.bhyt;
  if (has(['KIEM DINH', 'DANG KIEM', 'INSPECTION CERTIFICATE', 'TEM KIEM'])) {
    return DocType.inspection;
  }
  if (has(['BAO HIEM', 'TRACH NHIEM DAN SU', 'TNDS', 'INSURANCE'])) {
    return DocType.vehicleInsurance;
  }
  if (has(['GIAY PHEP LAI XE', 'DRIVER', 'LAI XE'])) {
    return DocType.driverLicense;
  }
  if (has(['DANG KY XE', 'DANG KY O TO', 'DANG KY MO TO', 'VEHICLE REGISTRATION', 'BIEN SO DANG KY'])) {
    return DocType.vehicleReg;
  }
  if (has(['CAN CUOC', 'CITIZEN IDENTITY', 'IDENTITY CARD', 'CHUNG MINH NHAN DAN'])) {
    return DocType.cccd;
  }
  if (has(['BAO HANH', 'WARRANTY', 'GUARANTEE'])) return DocType.warranty;
  return null;
}

final _date = RegExp(r'(\d{1,2})\s*[/\-.]\s*(\d{1,2})\s*[/\-.]\s*(\d{4})');

DateTime? _mk(int y, int m, int d) {
  if (m < 1 || m > 12 || d < 1 || d > 31 || y < 1900 || y > 2200) return null;
  final dt = DateTime(y, m, d);
  return dt.month == m ? dt : null;
}

List<DateTime> datesIn(String s) => _date
    .allMatches(s)
    .map((m) =>
        _mk(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!)))
    .whereType<DateTime>()
    .toList();

DateTime? _labelledDate(List<String> lines, List<String> labels) {
  for (var i = 0; i < lines.length; i++) {
    final f = fold(lines[i]);
    if (labels.any(f.contains)) {
      final same = datesIn(lines[i]);
      if (same.isNotEmpty) return same.last;
      if (i + 1 < lines.length) {
        final next = datesIn(lines[i + 1]);
        if (next.isNotEmpty) return next.first;
      }
    }
  }
  return null;
}

String? _labelledName(List<String> lines) {
  const labels = ['HO VA TEN', 'HO, CHU DEM VA TEN', 'HO TEN', 'FULL NAME', 'TEN CHU XE', 'CHU XE', 'NAME'];
  for (var i = 0; i < lines.length; i++) {
    final f = fold(lines[i]);
    if (labels.any(f.contains)) {
      final idx = lines[i].indexOf(':');
      var cand = idx >= 0 ? lines[i].substring(idx + 1).trim() : '';
      // Bỏ phần nhãn tiếng Anh sau dấu "/".
      if (cand.contains('/')) cand = cand.split('/').last.trim();
      if (cand.length < 3 && i + 1 < lines.length) cand = lines[i + 1].trim();
      if (_looksLikeName(cand)) return _titleName(cand);
    }
  }
  return null;
}

bool _looksLikeName(String s) {
  if (s.length < 4 || s.length > 40) return false;
  if (RegExp(r'\d').hasMatch(s)) return false;
  return s.trim().split(RegExp(r'\s+')).length >= 2;
}

String _titleName(String s) => s
    .trim()
    .split(RegExp(r'\s+'))
    .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase())
    .join(' ');

/// Phân tích MRZ hộ chiếu (TD3, 2 dòng x 44 ký tự).
OcrGuess? parseMrz(String text) {
  final lines = text
      .split('\n')
      .map((l) => l.replaceAll(' ', '').toUpperCase().replaceAll('«', '<'))
      .where((l) => l.length >= 40 && l.contains('<'))
      .toList();
  final l1i = lines.indexWhere((l) => l.startsWith('P'));
  if (l1i < 0 || l1i + 1 >= lines.length) return null;
  final l1 = lines[l1i], l2 = lines[l1i + 1].padRight(44, '<');
  final g = OcrGuess()..type = DocType.passport;
  final names = l1.length > 5 ? l1.substring(5).split('<<') : <String>[];
  if (names.isNotEmpty) {
    final sur = names[0].replaceAll('<', ' ').trim();
    final given = names.length > 1 ? names[1].replaceAll('<', ' ').trim() : '';
    final full = '$sur $given'.trim();
    if (full.isNotEmpty) g.name = _titleName(full);
  }
  final no = l2.substring(0, 9).replaceAll('<', '');
  if (no.isNotEmpty) g.number = no;
  DateTime? yymmdd(String s, {required bool future}) {
    if (!RegExp(r'^\d{6}$').hasMatch(s)) return null;
    final yy = int.parse(s.substring(0, 2));
    final now = DateTime.now().year % 100;
    final century = future ? 2000 : (yy > now ? 1900 : 2000);
    return _mk(century + yy, int.parse(s.substring(2, 4)), int.parse(s.substring(4, 6)));
  }
  g.birthDate = yymmdd(l2.substring(13, 19), future: false);
  g.expiryDate = yymmdd(l2.substring(21, 27), future: true);
  g.confidence = 0.9;
  return g;
}

OcrGuess parseDocumentText(String raw, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final lines =
      raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final folded = fold(raw);
  final g = OcrGuess()..type = detectType(folded);

  if (g.type == DocType.passport) {
    final m = parseMrz(raw);
    if (m != null) return m;
  }

  final compact = raw.replaceAll(RegExp(r'[ \t]'), '');
  switch (g.type) {
    case DocType.cccd:
    case DocType.driverLicense:
      g.number = RegExp(r'(?<!\d)\d{12}(?!\d)').firstMatch(compact)?.group(0);
      break;
    case DocType.passport:
      g.number = RegExp(r'\b[A-Z]\d{7,8}\b').firstMatch(raw)?.group(0);
      break;
    case DocType.bhyt:
      g.number = RegExp(r'\b[A-Z]{2}\d{13}\b').firstMatch(compact.toUpperCase())?.group(0) ??
          RegExp(r'\b[A-Z]{2}\d{13}\b').firstMatch(raw.toUpperCase())?.group(0);
      break;
    case DocType.vehicleReg:
    case DocType.inspection:
    case DocType.vehicleInsurance:
      final plate = RegExp(r'\b\d{2}[A-Z]{1,2}\d?\s*[-–]?\s*\d{3}\.?\d{2}\b')
          .firstMatch(raw.toUpperCase())
          ?.group(0);
      g.plate = plate?.replaceAll(RegExp(r'\s'), '');
      final serial = _labelledValue(lines, ['SO SERI', 'SO GIAY CHUNG NHAN', 'SO DANG KY', 'SO:', 'SERI', 'NO.']);
      g.number = serial ?? g.plate;
      break;
    case DocType.warranty:
      g.number = _labelledValue(lines, ['SERIAL', 'IMEI', 'SO SERI', 'S/N']);
      break;
    default:
      g.number = RegExp(r'(?<!\d)\d{9,12}(?!\d)').firstMatch(compact)?.group(0);
  }

  g.name = _labelledName(lines);
  g.birthDate = _labelledDate(lines, ['NGAY SINH', 'DATE OF BIRTH', 'NGAY, THANG, NAM SINH']);
  g.issueDate = _labelledDate(lines, ['NGAY CAP', 'DATE OF ISSUE', 'CAP NGAY', 'NGAY KIEM DINH', 'NGAY MUA']);
  g.expiryDate = _labelledDate(lines, [
    'CO GIA TRI DEN', 'GIA TRI DEN', 'DATE OF EXPIRY', 'EXPIRY', 'EXPIRES', 'HET HAN',
    'HIEU LUC DEN', 'HAN KIEM DINH', 'GIA TRI SU DUNG DEN', 'BAO HANH DEN', 'DEN NGAY', 'VALID UNTIL',
  ]);

  if (g.expiryDate == null) {
    // Thử: ngày muộn nhất trong tương lai (thường là ngày hết hạn).
    final future = datesIn(raw).where((d) => d.isAfter(today)).toList()..sort();
    if (future.isNotEmpty) g.expiryDate = future.last;
  }
  var score = 0.0;
  if (g.type != null) score += .4;
  if (g.number != null) score += .25;
  if (g.name != null) score += .15;
  if (g.expiryDate != null) score += .2;
  g.confidence = score;
  return g;
}

String? _labelledValue(List<String> lines, List<String> labels) {
  for (var i = 0; i < lines.length; i++) {
    final f = fold(lines[i]);
    for (final lb in labels) {
      final at = f.indexOf(lb);
      if (at >= 0) {
        var rest = lines[i].substring(at + lb.length).replaceFirst(RegExp(r'^[\s:./]+'), '').trim();
        if (rest.isEmpty && i + 1 < lines.length) rest = lines[i + 1].trim();
        final tok = RegExp(r'[A-Z0-9][A-Z0-9\-.]{4,}').firstMatch(rest.toUpperCase())?.group(0);
        if (tok != null) return tok;
      }
    }
  }
  return null;
}
