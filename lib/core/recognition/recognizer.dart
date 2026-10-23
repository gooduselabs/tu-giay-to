import '../expiry.dart';
import '../models.dart';
import 'dates.dart';
import 'layout.dart';
import 'mrz.dart';
import 'qr.dart';
import 'text.dart';

/// Một trường nhận dạng được: giá trị + độ tin cậy (0–1) + nguồn ('QR', 'MRZ', 'OCR', 'suy luận').
class Field<T> {
  final T value;
  final double conf;
  final String source;
  const Field(this.value, this.conf, this.source);
  @override
  String toString() => '$value(${conf.toStringAsFixed(2)} $source)';
}

/// Kết quả gộp từ mọi ảnh/trang của một giấy tờ. Người dùng luôn xác nhận trước khi lưu.
class Recognition {
  DocType? type;
  double typeConf = 0;
  final fields = <String, Field<Object>>{};
  bool noExpiry = false;
  final codes = <String>[];
  MrzResult? mrz;
  CccdQr? qr;

  /// Ghi trường nếu chưa có hoặc độ tin cậy mới cao hơn.
  void put(String key, Object? value, double conf, String source) {
    if (value == null || (value is String && value.trim().isEmpty)) return;
    final old = fields[key];
    if (old == null || conf > old.conf) fields[key] = Field<Object>(value, conf, source);
  }

  T? get<T>(String key) => fields[key]?.value as T?;
  double conf(String key) => fields[key]?.conf ?? 0;
}

// ---------------------------------------------------------------- phân loại

const _kw = <DocType, Map<String, double>>{
  DocType.cccd: {
    'CAN CUOC CONG DAN': 5, 'CAN CUOC': 3, 'CITIZEN IDENTITY CARD': 5, 'IDENTITY CARD': 3, 'CHUNG MINH NHAN DAN': 4,
    'SO DINH DANH CA NHAN': 4, 'PERSONAL IDENTIFICATION NUMBER': 4, 'QUE QUAN': 2, 'PLACE OF ORIGIN': 2,
    'NOI THUONG TRU': 2, 'NOI CU TRU': 2, 'PLACE OF RESIDENCE': 2, 'DAC DIEM NHAN DANG': 3, 'PERSONAL IDENTIFICATION': 2,
    'NOI DANG KY KHAI SINH': 2, 'PLACE OF BIRTH': 1, 'CUC TRUONG CUC CANH SAT': 2, 'NGON TRO TRAI': 2, 'LEFT INDEX FINGER': 2,
  },
  DocType.driverLicense: {
    'GIAY PHEP LAI XE': 6, 'DRIVER S LICENSE': 5, 'DRIVERS LICENSE': 5, 'DRIVER LICENSE': 5, 'DRIVING LICENCE': 5,
    'NGAY TRUNG TUYEN': 4, 'BEGINNING DATE': 3, 'HANG CLASS': 3, 'LAI XE': 2,
  },
  DocType.vehicleReg: {
    'CHUNG NHAN DANG KY XE': 6, 'DANG KY XE': 4, 'VEHICLE REGISTRATION': 4, 'TEN CHU XE': 3, 'SO KHUNG': 2, 'SO MAY': 2,
    'NHAN HIEU': 1.5, 'SO LOAI': 1.5, 'BIEN SO DANG KY': 3, 'DUNG TICH': 1, 'DANG KY LAN DAU': 2, 'MAU SON': 2,
  },
  DocType.inspection: {
    'CHUNG NHAN KIEM DINH': 6, 'KIEM DINH': 4, 'DANG KIEM': 3, 'AN TOAN KY THUAT': 3, 'BAO VE MOI TRUONG': 2,
    'INSPECTION CERTIFICATE': 5, 'HAN KIEM DINH': 4, 'CO HIEU LUC DEN HET NGAY': 2, 'TEM KIEM DINH': 3,
  },
  DocType.vehicleInsurance: {
    'TRACH NHIEM DAN SU': 6, 'BAO HIEM BAT BUOC': 4, 'TNDS': 4, 'CHU XE CO GIOI': 3, 'THOI HAN BAO HIEM': 3,
    'PHI BAO HIEM': 2, 'BIEN KIEM SOAT': 2, 'BAO HIEM': 1, 'INSURANCE': 1, 'MOTOR INSURANCE': 3,
  },
  DocType.passport: {'HO CHIEU': 5, 'PASSPORT': 5, 'PASSPORT NO': 3, 'NOI CAP': 0.5},
  DocType.bhyt: {
    'BAO HIEM Y TE': 6, 'BHYT': 4, 'HEALTH INSURANCE': 4, 'NOI DANG KY KCB': 4, 'KCB BAN DAU': 4, 'BAO HIEM XA HOI': 2,
    'THE BAO HIEM Y TE': 3,
  },
  DocType.warranty: {'PHIEU BAO HANH': 6, 'BAO HANH': 4, 'WARRANTY': 4, 'GUARANTEE': 3, 'IMEI': 2, 'SERIAL': 2, 'S N': 1},
};

/// Chấm điểm loại giấy tờ từ từ khoá + tín hiệu QR/MRZ. Trả về (loại, độ tin cậy).
(DocType?, double) classify(List<OcrPage> pages, {MrzResult? mrz, CccdQr? qr}) {
  final sq = pages.map((p) => p.lines.map((l) => l.sq).join(' | ')).join(' | ');
  final score = <DocType, double>{};
  _kw.forEach((type, kws) {
    var s = 0.0;
    kws.forEach((k, w) {
      if (fuzzyContains(sq, k)) s += w;
    });
    score[type] = s;
  });
  // "Bảo hiểm y tế" cũng chứa "bảo hiểm" → không cộng nhầm cho bảo hiểm xe.
  if ((score[DocType.bhyt] ?? 0) >= 6) score[DocType.vehicleInsurance] = (score[DocType.vehicleInsurance] ?? 0) - 1;
  // Đăng kiểm cũng có biển số/ chủ xe… → ưu tiên khi có "kiểm định".
  final text = pages.map((p) => p.text).join('\n').toUpperCase();
  if (RegExp(r'\b[A-Z]{2}\d{13}\b').hasMatch(text.replaceAll(' ', ''))) score[DocType.bhyt] = (score[DocType.bhyt] ?? 0) + 3;
  if (qr != null) score[DocType.cccd] = (score[DocType.cccd] ?? 0) + 12;
  if (mrz != null) {
    if (mrz.isPassport) score[DocType.passport] = (score[DocType.passport] ?? 0) + 12;
    if (mrz.isVnId || (mrz.format == 'TD1' && mrz.number.length == 12)) score[DocType.cccd] = (score[DocType.cccd] ?? 0) + 12;
  }
  final ranked = score.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final top = ranked.first, second = ranked.length > 1 ? ranked[1].value : 0.0;
  if (top.value < 3) return (null, 0);
  final margin = top.value - second;
  final conf = (top.value >= 12 ? .97 : (.45 + margin * .07 + top.value * .02)).clamp(.3, .97).toDouble();
  return (top.key, conf);
}

// ---------------------------------------------------------------- bộ chấp nhận giá trị

String? _acceptName(String s) {
  var t = s.replaceAll(RegExp(r'^[^A-Za-zÀ-ỹ]+'), '').trim();
  t = t.replaceAll(RegExp(r'\s{2,}'), ' ');
  if (!looksLikeName(t)) return null;
  // nhãn bị đọc thành tên? (ví dụ "Ngày sinh")
  const bad = ['NGAY SINH', 'DATE OF', 'QUOC TICH', 'GIOI TINH', 'FULL NAME', 'HO VA TEN', 'NATIONALITY', 'CONG HOA',
    'DOC LAP', 'VIET NAM', 'CAN CUOC', 'CITIZEN', 'NOI CU TRU', 'QUE QUAN'];
  final f = squash(fold(t));
  if (bad.any(f.contains)) return null;
  return titleCase(t);
}

DateTime? _acceptDate(String s) {
  final ds = datesIn(s, loose: true);
  return ds.isEmpty ? null : ds.first;
}

DateTime? _acceptLastDate(String s) {
  final ds = datesIn(s, loose: true);
  return ds.isEmpty ? null : ds.last;
}

String? Function(String) _digits(int n, {bool Function(String)? ok}) => (s) => digitRun(s, n, accept: ok);

final _plateRe = RegExp(r'(?<![A-Z0-9])(\d{2}\s?[A-Z][A-Z0-9]?)\s*[-–.\s]?\s*(\d{3}\s?\.?\s?\d{2}|\d{4,5})(?![0-9])');

String? acceptPlate(String s) {
  final up = s.toUpperCase();
  final m = _plateRe.firstMatch(up);
  if (m == null) return null;
  final head = m[1]!.replaceAll(' ', '');
  var tail = m[2]!.replaceAll(RegExp(r'[\s.]'), '');
  if (tail.length == 5) tail = '${tail.substring(0, 3)}.${tail.substring(3)}';
  return '$head-$tail';
}

String? _acceptCode(String s) {
  final m = RegExp(r'[A-Z0-9][A-Z0-9\-]{4,}').firstMatch(s.toUpperCase().replaceAll(RegExp(r'(?<=[A-Z]{2})\s(?=\d)'), ''));
  final v = m?.group(0);
  if (v == null || !RegExp(r'\d').hasMatch(v)) return null;
  return v;
}

const _classes = ['A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'C1E', 'D1E', 'D2E', 'BE', 'CE', 'DE', 'C1', 'D1', 'D2', 'FB2', 'FC', 'FD', 'FE', 'A', 'B', 'C', 'D', 'E', 'F'];

String? _acceptClass(String s) {
  final up = s.toUpperCase().replaceAll('8', 'B').replaceAll('O', '0');
  final toks = RegExp(r'[A-Z0-9]+').allMatches(up).map((m) => m[0]!).toList();
  final found = <String>[];
  for (final t in toks) {
    if (_classes.contains(t) && !found.contains(t)) found.add(t);
  }
  return found.isEmpty ? null : found.join(', ');
}

String? _acceptSex(String s) {
  final f = squash(fold(s));
  if (RegExp(r'^(NU|FEMALE)\b').hasMatch(f)) return 'Nữ';
  if (RegExp(r'^(NAM|MALE)\b').hasMatch(f)) return 'Nam';
  return null;
}

String? _acceptText(String s) {
  final t = s.trim();
  return t.length >= 6 && RegExp(r'[A-Za-zÀ-ỹ]').hasMatch(t) ? t : null;
}

// ---------------------------------------------------------------- mẫu theo loại

const _expiryLabels = ['CO GIA TRI DEN', 'GIA TRI DEN', 'DATE OF EXPIRY', 'EXPIRY DATE', 'EXPIRES', 'VALID UNTIL', 'HET HAN', 'CO GIA TRI'];
const _nameLabels = ['HO CHU DEM VA TEN', 'HO VA TEN KHAI SINH', 'HO VA TEN', 'HO TEN', 'FULL NAME', 'NAME', 'TEN'];
const _birthLabels = ['NGAY THANG NAM SINH', 'NGAY SINH', 'DATE OF BIRTH', 'NAM SINH'];
const _stop = [..._nameLabels, ..._birthLabels, ..._expiryLabels, 'GIOI TINH', 'SEX', 'QUOC TICH', 'NATIONALITY', 'QUE QUAN',
  'PLACE OF ORIGIN', 'NOI THUONG TRU', 'NOI CU TRU', 'PLACE OF RESIDENCE', 'SO', 'NO', 'HANG', 'CLASS', 'NOI CU TRU'];

bool _noExpiry(OcrPage p) => pageHas(p, 'KHONG THOI HAN') || pageHas(p, 'KHONG CO THOI HAN') || pageHas(p, 'UNLIMITED');

void _people(Recognition r, OcrPage p) {
  final n = valueNear(p, _nameLabels, _acceptName, stopLabels: _stop);
  if (n != null) r.put('name', n.value, n.conf, 'OCR');
  final b = valueNear(p, _birthLabels, _acceptDate, stopLabels: _stop);
  if (b != null) r.put('birth', b.value, b.conf, 'OCR');
}

void _cccd(Recognition r, OcrPage p) {
  // Số định danh 12 số: bắt đầu bằng mã tỉnh 001–096.
  bool province(String d) => d.startsWith('0') && int.parse(d.substring(0, 3)) <= 96;
  final no = valueNear(p, ['SO DINH DANH CA NHAN', 'PERSONAL IDENTIFICATION NUMBER', 'SO CCCD', 'SO', 'NO'], _digits(12, ok: province), stopLabels: _stop);
  if (no != null) {
    r.put('number', no.value, no.conf + .05, 'OCR');
  } else {
    final any = digitRun(p.text, 12, accept: province);
    if (any != null) r.put('number', any, .55, 'OCR');
  }
  _people(r, p);
  final sex = valueNear(p, ['GIOI TINH', 'SEX'], _acceptSex, stopLabels: _stop);
  if (sex != null) r.put('sex', sex.value, sex.conf, 'OCR');
  final addr = valueNear(p, ['NOI THUONG TRU', 'NOI CU TRU', 'PLACE OF RESIDENCE'], _acceptText, stopLabels: _stop, below: 1);
  if (addr != null) r.put('address', addr.value, addr.conf - .1, 'OCR');
  final exp = valueNear(p, _expiryLabels, _acceptDate, stopLabels: _stop);
  if (exp != null) r.put('expiry', exp.value, exp.conf, 'OCR');
  // Ngày cấp (mặt sau): "Ngày, tháng, năm / Date, month, year: 12/11/2021" — không nhầm với ngày sinh.
  final iss = valueNear(p, ['NGAY THANG NAM CAP', 'NGAY CAP', 'DATE OF ISSUE', 'NGAY THANG NAM', 'DATE MONTH YEAR'], _acceptDate,
      exclude: ['SINH', 'BIRTH', 'HET HAN', 'GIA TRI'], stopLabels: _stop);
  if (iss != null) r.put('issue', iss.value, iss.conf, 'OCR');
  if (_noExpiry(p)) r.noExpiry = true;
}

/// "Hà Nội, ngày 12 tháng 03 năm 2020" — ngày ký/cấp ở cuối giấy tờ.
DateTime? _signedDate(OcrPage p) {
  for (final l in p.lines.reversed) {
    if (RegExp(r'NGAY\s*\d{1,2}\s*THANG\s*\d{1,2}\s*NAM\s*\d{4}').hasMatch(l.sq)) {
      final d = datesIn(l.text);
      if (d.isNotEmpty) return d.first;
    }
  }
  return null;
}

void _gplx(Recognition r, OcrPage p) {
  final no = valueNear(p, ['SO', 'NO', 'SO GPLX'], _digits(12), stopLabels: _stop);
  if (no != null) {
    r.put('number', no.value, no.conf + .05, 'OCR');
  } else {
    final any = digitRun(p.text, 12);
    if (any != null) r.put('number', any, .55, 'OCR');
  }
  _people(r, p);
  final cls = valueNear(p, ['HANG', 'CLASS'], _acceptClass, stopLabels: _stop, below: 1);
  if (cls != null) r.put('class', cls.value, cls.conf, 'OCR');
  final exp = valueNear(p, _expiryLabels, _acceptDate, stopLabels: _stop);
  if (exp != null) r.put('expiry', exp.value, exp.conf, 'OCR');
  final sig = _signedDate(p);
  if (sig != null) r.put('issue', sig, .7, 'OCR');
  final pass = valueNear(p, ['NGAY TRUNG TUYEN', 'BEGINNING DATE', 'NGAY CAP', 'DATE OF ISSUE'], _acceptDate, stopLabels: _stop);
  if (pass != null) r.put('issue', pass.value, pass.conf - .15, 'OCR');
  if (_noExpiry(p)) r.noExpiry = true;
}

void _vehicleReg(Recognition r, OcrPage p) {
  final plate = valueNear(p, ['BIEN SO DANG KY', 'BIEN SO', 'BIEN KIEM SOAT', 'NUMBER PLATE', 'PLATE'], acceptPlate, stopLabels: _stop);
  if (plate != null) r.put('plate', plate.value, plate.conf, 'OCR');
  final anyPlate = acceptPlate(p.text);
  if (anyPlate != null) r.put('plate', anyPlate, .5, 'OCR');
  final owner = valueNear(p, ['TEN CHU XE', 'CHU XE', 'OWNER S FULL NAME', 'OWNER'], _acceptName, stopLabels: _stop);
  if (owner != null) r.put('name', owner.value, owner.conf, 'OCR');
  final no = valueNear(p, ['SO', 'NO'], (s) => RegExp(r'^\s*(\d{5,8})\b').firstMatch(asDigits(s.replaceAll(' ', '')))?.group(1), stopLabels: _stop);
  if (no != null) r.put('number', no.value, no.conf - .1, 'OCR');
  final first = valueNear(p, ['DANG KY LAN DAU NGAY', 'DANG KY LAN DAU', 'FIRST REGISTRATION'], _acceptDate, stopLabels: _stop);
  if (first != null) r.put('issue', first.value, first.conf - .05, 'OCR');
  final sig = _signedDate(p);
  if (sig != null) r.put('issue', sig, .7, 'OCR');
  final exp = valueNear(p, ['CO GIA TRI DEN', 'GIA TRI DEN', 'HET HAN'], _acceptDate, stopLabels: _stop);
  if (exp != null) r.put('expiry', exp.value, exp.conf, 'OCR');
}

void _inspection(Recognition r, OcrPage p) {
  final plate = valueNear(p, ['BIEN DANG KY', 'BIEN SO DANG KY', 'BIEN SO', 'REGISTRATION NUMBER'], acceptPlate, stopLabels: _stop);
  if (plate != null) r.put('plate', plate.value, plate.conf, 'OCR');
  final anyPlate = acceptPlate(p.text);
  if (anyPlate != null) r.put('plate', anyPlate, .5, 'OCR');
  final no = valueNear(p, ['SO SERI', 'SERI', 'SERIAL NO', 'SO GIAY CHUNG NHAN', 'SO'], _acceptCode, stopLabels: _stop);
  if (no != null) r.put('number', no.value, no.conf - .05, 'OCR');
  final exp = valueNear(p, ['CO HIEU LUC DEN HET NGAY', 'CO HIEU LUC DEN', 'HIEU LUC DEN', 'HAN KIEM DINH', 'VALID UNTIL', 'HET HAN'], _acceptDate,
      stopLabels: _stop);
  if (exp != null) r.put('expiry', exp.value, exp.conf + .05, 'OCR');
  final iss = valueNear(p, ['NGAY KIEM DINH', 'NGAY CAP', 'DATE OF ISSUE'], _acceptDate, stopLabels: _stop);
  if (iss != null) r.put('issue', iss.value, iss.conf, 'OCR');
  final sig = _signedDate(p);
  if (sig != null) r.put('issue', sig, .65, 'OCR');
}

void _insurance(Recognition r, OcrPage p) {
  final plate = valueNear(p, ['BIEN KIEM SOAT', 'BIEN SO XE', 'BIEN SO', 'BKS'], acceptPlate, stopLabels: _stop);
  if (plate != null) r.put('plate', plate.value, plate.conf, 'OCR');
  final anyPlate = acceptPlate(p.text);
  if (anyPlate != null) r.put('plate', anyPlate, .5, 'OCR');
  final no = valueNear(p, ['SO GIAY CHUNG NHAN', 'SO GCN', 'SO SERI', 'SO HOP DONG', 'SO', 'NO'], _acceptCode, stopLabels: _stop);
  if (no != null) r.put('number', no.value, no.conf - .1, 'OCR');
  final owner = valueNear(p, ['TEN CHU XE', 'CHU XE', 'NGUOI DUOC BAO HIEM', 'TEN TO CHUC CA NHAN', 'BEN MUA BAO HIEM'], _acceptName, stopLabels: _stop);
  if (owner != null) r.put('name', owner.value, owner.conf, 'OCR');
  // "Thời hạn bảo hiểm: Từ 10 giờ 00, ngày 01/11/2025 đến 10 giờ 00, ngày 01/11/2026"
  final period = _range(p, ['THOI HAN BAO HIEM', 'THOI HAN', 'HIEU LUC', 'PERIOD OF INSURANCE']);
  if (period != null) {
    if (period.length >= 2) {
      r.put('issue', period.first, .82, 'OCR');
      r.put('expiry', period.last, .86, 'OCR');
    } else {
      r.put('expiry', period.last, .6, 'OCR');
    }
  }
  final to = valueNear(p, ['DEN NGAY', 'DEN'], _acceptDate, stopLabels: _stop);
  if (to != null) r.put('expiry', to.value, to.conf - .1, 'OCR');
}

/// Khoảng thời gian "từ … đến …" có thể trải trên 2 dòng: gom ngày ở dòng nhãn và dòng kế tiếp.
List<DateTime>? _range(OcrPage p, List<String> labels) {
  for (var i = 0; i < p.lines.length; i++) {
    if (!labels.any((lb) => matchLabel(p.lines[i], i, lb) != null)) continue;
    final ds = datesIn(p.lines[i].text);
    if (ds.length < 2 && i + 1 < p.lines.length) ds.addAll(datesIn(p.lines[i + 1].text));
    if (ds.isNotEmpty) return ds;
  }
  return null;
}

void _bhyt(Recognition r, OcrPage p) {
  String? code(String s) {
    final t = s.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), '');
    final m = RegExp(r'([A-Z0-9]{2})([0-9OQDILSBZ]{13})(?![0-9])').firstMatch(t);
    if (m != null) {
      final head = asAlpha(m[1]!);
      if (RegExp(r'^[A-Z]{2}$').hasMatch(head)) return head + asDigits(m[2]!);
    }
    return digitRun(s, 10); // mã số BHXH 10 số (thẻ mẫu mới)
  }

  final no = valueNear(p, ['MA SO BHXH', 'MA SO', 'MA THE', 'SO THE'], code, stopLabels: _stop);
  if (no != null) {
    r.put('number', no.value, no.conf + .05, 'OCR');
  } else {
    final any = code(p.text);
    if (any != null) r.put('number', any, .55, 'OCR');
  }
  _people(r, p);
  final valid = _range(p, ['GIA TRI SU DUNG', 'HAN THE', 'THOI HAN SU DUNG', 'GIA TRI DEN']);
  if (valid != null) {
    if (valid.length >= 2) r.put('issue', valid.first, .78, 'OCR');
    r.put('expiry', valid.last, .84, 'OCR');
  }
  final to = valueNear(p, ['DEN NGAY', 'DEN'], _acceptDate, stopLabels: _stop);
  if (to != null) r.put('expiry', to.value, to.conf - .1, 'OCR');
}

void _passport(Recognition r, OcrPage p) {
  final no = valueNear(p, ['SO HO CHIEU', 'PASSPORT NO', 'SO PASSPORT'],
      (s) => RegExp(r'\b([A-Z][0-9OIL]{7,8})\b').firstMatch(s.toUpperCase())?.group(1)?.let((v) => v[0] + asDigits(v.substring(1))),
      stopLabels: _stop);
  if (no != null) r.put('number', no.value, no.conf, 'OCR');
  _people(r, p);
  final exp = valueNear(p, ['CO GIA TRI DEN', 'NGAY HET HAN', 'DATE OF EXPIRY'], _acceptDate, stopLabels: _stop);
  if (exp != null) r.put('expiry', exp.value, exp.conf, 'OCR');
  final iss = valueNear(p, ['NGAY CAP', 'DATE OF ISSUE'], _acceptDate, stopLabels: _stop);
  if (iss != null) r.put('issue', iss.value, iss.conf, 'OCR');
}

void _warranty(Recognition r, OcrPage p) {
  final no = valueNear(p, ['SO SERI', 'SERIAL NUMBER', 'SERIAL', 'IMEI', 'S N', 'SN', 'MA MAY'], _acceptCode, stopLabels: _stop);
  if (no != null) r.put('number', no.value, no.conf, 'OCR');
  final exp = valueNear(p, ['BAO HANH DEN', 'HAN BAO HANH', 'HET HAN BAO HANH', 'NGAY HET HAN', 'WARRANTY UNTIL', 'EXPIRY'], _acceptDate,
      stopLabels: _stop);
  if (exp != null) r.put('expiry', exp.value, exp.conf, 'OCR');
  final buy = valueNear(p, ['NGAY MUA', 'NGAY BAN', 'NGAY XUAT', 'NGAY KICH HOAT', 'PURCHASE DATE', 'NGAY'], _acceptDate,
      exclude: ['DEN', 'HET HAN'], stopLabels: _stop);
  if (buy != null) r.put('issue', buy.value, buy.conf - .05, 'OCR');
  // "Thời hạn bảo hành: 12 tháng" + ngày mua → ngày hết hạn
  for (final l in p.lines) {
    final m = RegExp(r'BAO HANH\s*(\d{1,3})\s*(THANG|NAM|MONTHS?|YEARS?)').firstMatch(l.sq);
    if (m != null) r.put('warrantyMonths', int.parse(m[1]!) * (m[2]!.startsWith('NAM') || m[2]!.startsWith('YEAR') ? 12 : 1), .7, 'OCR');
  }
}

void _generic(Recognition r, OcrPage p) {
  _people(r, p);
  final exp = valueNear(p, [..._expiryLabels, 'HIEU LUC DEN', 'DEN NGAY'], _acceptLastDate, stopLabels: _stop);
  if (exp != null) r.put('expiry', exp.value, exp.conf - .1, 'OCR');
  final iss = valueNear(p, ['NGAY CAP', 'DATE OF ISSUE'], _acceptDate, stopLabels: _stop);
  if (iss != null) r.put('issue', iss.value, iss.conf - .1, 'OCR');
  final no = valueNear(p, ['SO', 'NO', 'MA SO'], _acceptCode, stopLabels: _stop);
  if (no != null) r.put('number', no.value, no.conf - .2, 'OCR');
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

// ---------------------------------------------------------------- bộ gộp

/// Nhận dạng một giấy tờ từ nhiều ảnh (mặt trước + mặt sau + trang PDF).
/// Thứ tự tin cậy: QR (≈0.98) → MRZ có chữ số kiểm tra (≈0.95) → mẫu OCR theo nhãn (0.6–0.85) → suy luận (≤0.5).
Recognition recognize(List<OcrPage> pages, {DateTime? now, DocType? hint}) {
  final today = now ?? DateTime.now();
  final r = Recognition();

  // 1) QR / mã vạch
  for (final p in pages) {
    for (final c in p.codes) {
      if (!r.codes.contains(c)) r.codes.add(c);
      r.qr ??= parseCccdQr(c);
    }
  }
  final qr = r.qr;
  if (qr != null) {
    r.put('number', qr.number, .99, 'QR');
    r.put('name', qr.name, .98, 'QR');
    r.put('birth', qr.birth, .98, 'QR');
    r.put('sex', qr.sex, .98, 'QR');
    r.put('address', qr.address, .95, 'QR');
    r.put('issue', qr.issue, .97, 'QR');
    r.put('oldId', qr.oldId, .97, 'QR');
  }

  // 2) MRZ
  for (final p in pages) {
    r.mrz ??= parseMrz(p.lines.map((l) => l.text).toList(), now: today);
  }
  final mrz = r.mrz;

  // 3) Phân loại
  final (t, tc) = classify(pages, mrz: mrz, qr: qr);
  r.type = t ?? hint;
  r.typeConf = t == null ? (hint == null ? 0 : .5) : tc;

  if (mrz != null) {
    final c = mrz.valid ? .95 : (.55 + .08 * mrz.checksPassed);
    r.put('number', mrz.number, c, 'MRZ');
    r.put('birth', mrz.birth, c, 'MRZ');
    r.put('expiry', mrz.expiry, c, 'MRZ');
    r.put('sex', mrz.sex == 'M' ? 'Nam' : (mrz.sex == 'F' ? 'Nữ' : null), c, 'MRZ');
    // Tên MRZ không dấu: chỉ dùng khi không có tên có dấu đáng tin hơn.
    if (mrz.fullName.isNotEmpty) r.put('name', titleCase(mrz.fullName), .62, 'MRZ');
  }

  // 4) Mẫu OCR theo loại, từng trang
  for (final p in pages) {
    switch (r.type) {
      case DocType.cccd:
        _cccd(r, p);
      case DocType.driverLicense:
        _gplx(r, p);
      case DocType.vehicleReg:
        _vehicleReg(r, p);
      case DocType.inspection:
        _inspection(r, p);
      case DocType.vehicleInsurance:
        _insurance(r, p);
      case DocType.bhyt:
        _bhyt(r, p);
      case DocType.passport:
        _passport(r, p);
      case DocType.warranty:
        _warranty(r, p);
      case DocType.other:
      case null:
        _generic(r, p);
    }
  }

  // 5) Đối chiếu chéo & suy luận
  final ocrName = r.fields['name'];
  if (mrz != null && ocrName != null && ocrName.source == 'OCR' && fold(ocrName.value as String) == fold(titleCase(mrz.fullName))) {
    r.fields['name'] = Field<Object>(ocrName.value, .93, 'OCR+MRZ');
  }
  if (mrz != null && qr != null && mrz.number == qr.number) r.fields['number'] = Field<Object>(qr.number, .995, 'QR+MRZ');
  final num = r.get<String>('number');
  if (r.type == DocType.cccd && num != null && num.length == 12 && r.get<DateTime>('birth') != null) {
    // Chữ số 5–6 của số định danh là 2 số cuối năm sinh — tăng/giảm độ tin cậy.
    final yy = (r.get<DateTime>('birth')!.year % 100).toString().padLeft(2, '0');
    final f = r.fields['number']!;
    r.fields['number'] = Field<Object>(f.value, num.substring(4, 6) == yy ? (f.conf + .1).clamp(0, .995) : f.conf - .15, f.source);
  }
  if (r.type == DocType.cccd && r.get<DateTime>('expiry') == null && !r.noExpiry) {
    final b = r.get<DateTime>('birth'), i = r.get<DateTime>('issue');
    if (b != null && i != null) {
      final e = cccdExpiryFor(b, i);
      if (e == null) {
        r.noExpiry = true;
      } else {
        r.put('expiry', e, (r.conf('birth') < r.conf('issue') ? r.conf('birth') : r.conf('issue')) - .05, 'suy luận');
      }
    }
  }
  if (r.type == DocType.warranty && r.get<DateTime>('expiry') == null) {
    final i = r.get<DateTime>('issue'), m = r.get<int>('warrantyMonths');
    if (i != null && m != null) r.put('expiry', DateTime(i.year, i.month + m, i.day), .6, 'suy luận');
  }
  // QR khác: URL tra cứu (hoá đơn điện tử, GPLX PET…) hoặc chuỗi có số 12 chữ số.
  for (final c in r.codes) {
    if (qrKind(c) == QrKind.url) r.put('url', c.trim(), .9, 'QR');
    if (r.type == DocType.driverLicense && qr == null) {
      final d = RegExp(r'(?<!\d)\d{12}(?!\d)').firstMatch(c)?.group(0);
      if (d != null) r.put('number', d, .9, 'QR');
    }
  }
  if (r.noExpiry) r.fields.remove('expiry');
  if (!r.noExpiry && r.get<DateTime>('expiry') == null && r.type != DocType.vehicleReg) {
    final all = pages.expand((p) => datesIn(p.text)).where((d) => d.isAfter(today)).toList()..sort();
    if (all.isNotEmpty) r.put('expiry', all.last, .35, 'suy luận');
  }
  // Loại xe: số giấy tờ mặc định là biển số khi không đọc được số seri.
  if (r.type?.belongsToVehicle == true && r.get<String>('number') == null && r.get<String>('plate') != null) {
    r.put('number', r.get<String>('plate'), r.conf('plate') - .05, r.fields['plate']!.source);
  }
  return r;
}
