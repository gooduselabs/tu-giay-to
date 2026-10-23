import 'dates.dart';
import 'text.dart';

/// Dữ liệu trong mã QR mặt trước CCCD gắn chip (2021) / thẻ Căn cước (2024).
/// Dạng chuẩn: số CCCD|số CMND cũ|họ tên|ngày sinh ddMMyyyy|giới tính|địa chỉ|ngày cấp ddMMyyyy
/// Thực tế có biến thể: thiếu CMND (||), thêm trường cuối, khoảng trắng thừa, ngày có dấu '/'.
class CccdQr {
  final String number;
  final String? oldId;
  final String? name;
  final DateTime? birth;
  final String? sex;
  final String? address;
  final DateTime? issue;
  CccdQr({required this.number, this.oldId, this.name, this.birth, this.sex, this.address, this.issue});
  @override
  String toString() => 'CccdQr($number, $oldId, $name, $birth, $sex, $address, $issue)';
}

CccdQr? parseCccdQr(String payload) {
  final raw = payload.trim();
  if (!raw.contains('|')) return null;
  final parts = raw.split('|').map((p) => p.trim()).toList();
  if (parts.length < 4) return null;
  final ni = parts.indexWhere((p) => RegExp(r'^\d{12}$').hasMatch(p));
  if (ni < 0 || ni > 1) return null;
  final number = parts[ni];
  final rest = parts.sublist(ni + 1);
  String? oldId;
  if (rest.isNotEmpty && RegExp(r'^\d{9}$').hasMatch(rest.first)) oldId = rest.first;
  final dates = <(int, DateTime)>[];
  for (var i = 0; i < rest.length; i++) {
    if (RegExp(r'^\d{8}$|^\d{1,2}/\d{1,2}/\d{4}$').hasMatch(rest[i])) {
      final d = parseDmyCompact(rest[i]);
      if (d != null) dates.add((i, d));
    }
  }
  String? sex;
  for (final p in rest) {
    final f = fold(p);
    if (f == 'NAM' || f == 'MALE' || f == 'M') sex = 'Nam';
    if (f == 'NU' || f == 'FEMALE' || f == 'F') sex = 'Nữ';
  }
  String? name;
  for (final p in rest) {
    if (looksLikeName(p) && fold(p) != 'NAM' && !p.contains(',')) {
      name = p;
      break;
    }
  }
  String? address;
  for (final p in rest) {
    if (p == name || p.length < 6) continue;
    if (RegExp(r'^\d+$').hasMatch(p)) continue;
    if (p.contains(',') || p.length > 15) {
      if (address == null || p.length > address.length) address = p;
    }
  }
  // Ngày sinh: ngày đầu tiên (trước giới tính). Ngày cấp: ngày cuối cùng nếu khác ngày sinh.
  final birth = dates.isNotEmpty ? dates.first.$2 : null;
  final issue = dates.length > 1 ? dates.last.$2 : null;
  if (name == null && birth == null) return null;
  return CccdQr(number: number, oldId: oldId, name: name, birth: birth, sex: sex, address: address, issue: issue);
}

/// Phân loại thô nội dung QR/mã vạch bất kỳ.
enum QrKind { cccd, url, text }

QrKind qrKind(String payload) {
  if (parseCccdQr(payload) != null) return QrKind.cccd;
  if (RegExp(r'^(https?://|www\.)', caseSensitive: false).hasMatch(payload.trim())) return QrKind.url;
  return QrKind.text;
}
