import 'dart:typed_data';

import '../core/models.dart';
import 'store.dart';

/// Dữ liệu MẪU (hư cấu) để xem thử & chụp màn hình. Mọi bản ghi gắn isSample.
/// [art] tạo ảnh minh hoạ "MẪU" cho mặt trước/sau (có thể null trong test).
Future<void> seedSamples(AppStore s,
    {DateTime? now, Future<Uint8List?> Function(DocType, String side)? art}) async {
  final t = now ?? DateTime.now();
  DateTime inDays(int d) => DateTime(t.year, t.month, t.day).add(Duration(days: d));
  Profile pr(String name, ProfileKind k, String sub, int color, [DateTime? b]) => Profile(
      id: s.newId(), name: name, kind: k, subtitle: sub, colorIndex: color, birthDate: b, isSample: true);

  final khoi = pr('Lê Minh Khôi', ProfileKind.person, 'Chủ hộ', 0, DateTime(1990, 5, 12));
  final ha = pr('Phạm Thu Hà', ProfileKind.person, 'Vợ', 1, DateTime(1992, 9, 3));
  final an = pr('Lê Bảo An', ProfileKind.person, 'Con', 2, DateTime(2016, 2, 20));
  final car = pr('Ô tô gia đình', ProfileKind.car, '30A-123.45 · Sedan 5 chỗ', 3);
  final bike = pr('Xe máy', ProfileKind.motorbike, '29X1-678.90', 4);
  final house = pr('Căn hộ', ProfileKind.house, 'Chung cư · Hà Nội', 5);
  final fridge = pr('Tủ lạnh', ProfileKind.device, 'Inverter 360L', 6);
  for (final p in [khoi, ha, an, car, bike, house, fridge]) {
    await s.saveProfile(p);
  }

  Future<List<Attachment>> atts(DocType type, List<String> sides) async {
    final out = <Attachment>[];
    for (final side in sides) {
      final bytes = await art?.call(type, side);
      if (bytes != null) out.add(await s.addAttachment(bytes, AttachmentKind.image, side));
    }
    return out;
  }

  final docs = [
    Document(id: s.newId(), profileId: khoi.id, type: DocType.cccd, title: 'Căn cước công dân',
        number: '001090012345', holderName: 'Lê Minh Khôi', issueDate: DateTime(2016, 4, 10),
        expiryDate: inDays(20), attachments: await atts(DocType.cccd, ['Mặt trước', 'Mặt sau'])),
    Document(id: s.newId(), profileId: car.id, type: DocType.inspection, title: 'Đăng kiểm ô tô',
        number: 'KĐ 2914563', holderName: 'Lê Minh Khôi', issueDate: inDays(-360), expiryDate: inDays(5),
        notes: 'Đặt lịch trước khi đến trung tâm đăng kiểm.'),
    Document(id: s.newId(), profileId: car.id, type: DocType.vehicleInsurance, title: 'Bảo hiểm TNDS ô tô',
        number: 'TNDS-24-778812', holderName: 'Lê Minh Khôi', issueDate: inDays(-368), expiryDate: inDays(-3)),
    Document(id: s.newId(), profileId: ha.id, type: DocType.passport, title: 'Hộ chiếu',
        number: 'C1234567', holderName: 'Phạm Thu Hà', issueDate: DateTime(2017, 3, 1),
        expiryDate: inDays(150), attachments: await atts(DocType.passport, ['Trang thông tin'])),
    Document(id: s.newId(), profileId: an.id, type: DocType.bhyt, title: 'Thẻ BHYT học sinh',
        number: 'HS4010123456789', holderName: 'Lê Bảo An', expiryDate: inDays(25)),
    Document(id: s.newId(), profileId: bike.id, type: DocType.vehicleInsurance, title: 'Bảo hiểm xe máy',
        number: 'XM-88123', holderName: 'Phạm Thu Hà', expiryDate: inDays(64)),
    Document(id: s.newId(), profileId: khoi.id, type: DocType.driverLicense, title: 'Bằng lái B',
        number: '010123456789', holderName: 'Lê Minh Khôi', issueDate: DateTime(2019, 8, 15),
        expiryDate: inDays(410)),
    Document(id: s.newId(), profileId: fridge.id, type: DocType.warranty, title: 'Bảo hành tủ lạnh',
        number: 'SN 7Q2K-55-0912', expiryDate: inDays(210), notes: 'Giữ kèm hoá đơn mua hàng.'),
    Document(id: s.newId(), profileId: car.id, type: DocType.vehicleReg, title: 'Giấy đăng ký ô tô',
        number: '30A-123.45', holderName: 'Lê Minh Khôi', issueDate: DateTime(2021, 6, 2)),
    Document(id: s.newId(), profileId: house.id, type: DocType.other, title: 'Hợp đồng điện',
        number: 'PD-0021345', notes: 'Mã khách hàng điện lực.'),
  ];
  for (final d in docs) {
    d.isSample = true;
    await s.saveDocument(d);
  }
}
