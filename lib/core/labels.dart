import '../ui/widgets/glyphs.dart';
import '../l10n/l10n.dart';
import 'models.dart';

extension DocTypeLabel on DocType {
  String get label => switch (this) {
        DocType.cccd => tr('Căn cước (CCCD)'),
        DocType.driverLicense => tr('Bằng lái xe'),
        DocType.vehicleReg => tr('Đăng ký xe (cà-vẹt)'),
        DocType.inspection => tr('Đăng kiểm'),
        DocType.vehicleInsurance => tr('Bảo hiểm xe'),
        DocType.passport => tr('Hộ chiếu'),
        DocType.warranty => tr('Phiếu bảo hành'),
        DocType.bhyt => tr('Thẻ BHYT'),
        DocType.other => tr('Giấy tờ khác'),
      };

  String get short => switch (this) {
        DocType.cccd => 'CCCD',
        DocType.driverLicense => 'GPLX',
        DocType.vehicleReg => tr('CÀ-VẸT'),
        DocType.inspection => tr('ĐĂNG KIỂM'),
        DocType.vehicleInsurance => tr('BẢO HIỂM'),
        DocType.passport => 'PASSPORT',
        DocType.warranty => tr('BẢO HÀNH'),
        DocType.bhyt => 'BHYT',
        DocType.other => tr('KHÁC'),
      };

  Ic get icon => switch (this) {
        DocType.cccd => Ic.idCard,
        DocType.driverLicense => Ic.licence,
        DocType.vehicleReg => Ic.registration,
        DocType.inspection => Ic.inspection,
        DocType.vehicleInsurance => Ic.shield,
        DocType.passport => Ic.passport,
        DocType.warranty => Ic.ribbon,
        DocType.bhyt => Ic.medical,
        DocType.other => Ic.docOther,
      };

  /// Mã ngăn hồ sơ (in trên tab bìa).
  String get code => switch (this) {
        DocType.cccd => 'CC',
        DocType.driverLicense => 'LX',
        DocType.vehicleReg => 'DK',
        DocType.inspection => 'KD',
        DocType.vehicleInsurance => 'BH',
        DocType.passport => 'HC',
        DocType.warranty => 'BN',
        DocType.bhyt => 'YT',
        DocType.other => 'TL',
      };
}

extension ProfileKindLabel on ProfileKind {
  String get label => switch (this) {
        ProfileKind.person => tr('Thành viên'),
        ProfileKind.car => tr('Ô tô'),
        ProfileKind.motorbike => tr('Xe máy'),
        ProfileKind.house => tr('Nhà'),
        ProfileKind.device => tr('Thiết bị'),
        ProfileKind.other => tr('Khác'),
      };

  Ic get icon => switch (this) {
        ProfileKind.person => Ic.person,
        ProfileKind.car => Ic.car,
        ProfileKind.motorbike => Ic.motorbike,
        ProfileKind.house => Ic.house,
        ProfileKind.device => Ic.device,
        ProfileKind.other => Ic.grid,
      };
}

/// Số hồ sơ ổn định từ id, ví dụ "KD·0427".
String fileNumber(Document d) {
  var h = 0;
  for (final c in d.id.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return '${d.type.code}·${(h % 9000 + 1000)}';
}
