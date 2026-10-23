import 'models.dart';
import 'recognition/layout.dart';
import 'recognition/recognizer.dart';

export 'recognition/layout.dart' show OcrPage, OcrLine;
export 'recognition/recognizer.dart' show Recognition, Field, recognize;
export 'recognition/text.dart' show fold;

/// Kết quả nhận dạng dành cho màn hình nhập: giá trị + độ tin cậy từng ô + nguồn.
/// Người dùng luôn xác nhận/sửa trước khi lưu.
class OcrGuess {
  DocType? type;
  String? number;
  String? name;
  DateTime? issueDate;
  DateTime? expiryDate;
  DateTime? birthDate;
  String? plate;
  String? sex;
  String? address;
  String? vehicleClass;
  String? oldId;
  String? url;
  bool noExpiry = false;
  List<String> codes = [];

  /// Độ tin cậy theo ô: 'type', 'number', 'name', 'issue', 'expiry', 'birth', ...
  Map<String, double> conf = {};

  /// Nguồn theo ô: 'QR', 'MRZ', 'OCR', 'suy luận'.
  Map<String, String> source = {};
  double confidence = 0;
  OcrGuess();

  bool get isEmpty => type == null && number == null && name == null && expiryDate == null;

  /// Ngưỡng cần người dùng kiểm tra lại.
  static const review = .7;
  bool low(String key) => conf.containsKey(key) && conf[key]! < review;

  factory OcrGuess.from(Recognition r) {
    final g = OcrGuess()
      ..type = r.type
      ..number = r.get<String>('number')
      ..name = r.get<String>('name')
      ..issueDate = r.get<DateTime>('issue')
      ..expiryDate = r.get<DateTime>('expiry')
      ..birthDate = r.get<DateTime>('birth')
      ..plate = r.get<String>('plate')
      ..sex = r.get<String>('sex')
      ..address = r.get<String>('address')
      ..vehicleClass = r.get<String>('class')
      ..oldId = r.get<String>('oldId')
      ..url = r.get<String>('url')
      ..noExpiry = r.noExpiry
      ..codes = List.of(r.codes);
    if (r.type != null) g.conf['type'] = r.typeConf;
    r.fields.forEach((k, f) {
      g.conf[k] = f.conf.clamp(0, 1).toDouble();
      g.source[k] = f.source;
    });
    final keys = ['type', 'number', 'name', 'expiry'].where(g.conf.containsKey).toList();
    g.confidence = keys.isEmpty ? 0 : keys.map((k) => g.conf[k]!).reduce((a, b) => a + b) / 4;
    return g;
  }

  @override
  String toString() =>
      'OcrGuess($type, $number, $name, issue=$issueDate, exp=$expiryDate${noExpiry ? '(vô hạn)' : ''}, dob=$birthDate, '
      'plate=$plate, sex=$sex, class=$vehicleClass, conf=$conf)';
}

/// Tương thích cũ: nhận dạng từ văn bản thuần (không toạ độ, không QR).
OcrGuess parseDocumentText(String raw, {DateTime? now, List<String> codes = const []}) =>
    OcrGuess.from(recognize([OcrPage.fromText(raw, codes: codes)], now: now));

OcrGuess parsePages(List<OcrPage> pages, {DateTime? now, DocType? hint}) => OcrGuess.from(recognize(pages, now: now, hint: hint));
