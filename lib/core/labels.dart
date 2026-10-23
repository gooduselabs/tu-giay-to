import 'package:flutter/material.dart';
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

  IconData get icon => switch (this) {
        DocType.cccd => Icons.badge_outlined,
        DocType.driverLicense => Icons.directions_car_filled_outlined,
        DocType.vehicleReg => Icons.description_outlined,
        DocType.inspection => Icons.fact_check_outlined,
        DocType.vehicleInsurance => Icons.shield_outlined,
        DocType.passport => Icons.travel_explore,
        DocType.warranty => Icons.verified_outlined,
        DocType.bhyt => Icons.local_hospital_outlined,
        DocType.other => Icons.folder_open_outlined,
      };

  /// Bảng màu "ví da" cho từng loại thẻ.
  List<Color> get gradient => switch (this) {
        DocType.cccd => const [Color(0xFF1F3A5F), Color(0xFF3D6A8F)],
        DocType.driverLicense => const [Color(0xFF2F4A3A), Color(0xFF5B7D5E)],
        DocType.vehicleReg => const [Color(0xFF4A3B2A), Color(0xFF8A6A45)],
        DocType.inspection => const [Color(0xFF3C2F4F), Color(0xFF6E5A8A)],
        DocType.vehicleInsurance => const [Color(0xFF14444A), Color(0xFF2F7F80)],
        DocType.passport => const [Color(0xFF5A1E2A), Color(0xFF8E3B46)],
        DocType.warranty => const [Color(0xFF3A3A3A), Color(0xFF6B6B6B)],
        DocType.bhyt => const [Color(0xFF1C4F6E), Color(0xFF3F8FB0)],
        DocType.other => const [Color(0xFF473F33), Color(0xFF7A6D58)],
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

  IconData get icon => switch (this) {
        ProfileKind.person => Icons.person_outline,
        ProfileKind.car => Icons.directions_car_outlined,
        ProfileKind.motorbike => Icons.two_wheeler,
        ProfileKind.house => Icons.home_outlined,
        ProfileKind.device => Icons.devices_other_outlined,
        ProfileKind.other => Icons.category_outlined,
      };
}
