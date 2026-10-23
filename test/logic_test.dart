import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tu_giay_to/core/backup_codec.dart';
import 'package:tu_giay_to/core/expiry.dart';
import 'package:tu_giay_to/core/models.dart';
import 'package:tu_giay_to/core/ocr_parser.dart';
import 'package:tu_giay_to/data/persistence.dart';
import 'package:tu_giay_to/data/store.dart';

void main() {
  final now = DateTime(2026, 10, 23);

  group('OCR parser', () {
    test('fold removes Vietnamese diacritics', () {
      expect(fold('Căn cước công dân Đặng'), 'CAN CUOC CONG DAN DANG');
    });

    test('CCCD front', () {
      const text = '''CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM
Độc lập - Tự do - Hạnh phúc
CĂN CƯỚC CÔNG DÂN
Citizen Identity Card
Số / No.: 001090012345
Họ và tên / Full name:
NGUYỄN VĂN MẪU
Ngày sinh / Date of birth: 12/05/1990
Có giá trị đến: 12/05/2030''';
      final g = parseDocumentText(text, now: now);
      expect(g.type, DocType.cccd);
      expect(g.number, '001090012345');
      expect(g.name, 'Nguyễn Văn Mẫu');
      expect(g.birthDate, DateTime(1990, 5, 12));
      expect(g.expiryDate, DateTime(2030, 5, 12));
    });

    test('passport MRZ', () {
      const text = '''HỘ CHIẾU / PASSPORT
P<VNMPHAM<<THU<HA<<<<<<<<<<<<<<<<<<<<<<<<<<<
C1234567<4VNM9209038F3203011<<<<<<<<<<<<<<02''';
      final g = parseDocumentText(text, now: now);
      expect(g.type, DocType.passport);
      expect(g.number, 'C1234567');
      expect(g.name, 'Pham Thu Ha');
      expect(g.birthDate, DateTime(1992, 9, 3));
      expect(g.expiryDate, DateTime(2032, 3, 1));
    });

    test('inspection certificate', () {
      const text = '''GIẤY CHỨNG NHẬN KIỂM ĐỊNH
AN TOÀN KỸ THUẬT VÀ BẢO VỆ MÔI TRƯỜNG
Biển đăng ký: 30A-123.45
Số seri: KD 2914563
Có hiệu lực đến hết ngày: 28/10/2026''';
      final g = parseDocumentText(text, now: now);
      expect(g.type, DocType.inspection);
      expect(g.plate, '30A-123.45');
      expect(g.expiryDate, DateTime(2026, 10, 28));
    });

    test('BHYT and warranty and driver licence', () {
      expect(parseDocumentText('THẺ BẢO HIỂM Y TẾ\nMã số: HS4010123456789\nGiá trị sử dụng đến 31/12/2026', now: now).number,
          'HS4010123456789');
      expect(parseDocumentText('PHIẾU BẢO HÀNH\nSerial: 7Q2K550912\nBảo hành đến 01/06/2027', now: now).type,
          DocType.warranty);
      final dl = parseDocumentText('GIẤY PHÉP LÁI XE / DRIVER\'S LICENSE\nSố/No: 010123456789\nCó giá trị đến: 15/08/2029', now: now);
      expect(dl.type, DocType.driverLicense);
      expect(dl.number, '010123456789');
      expect(dl.expiryDate, DateTime(2029, 8, 15));
    });

    test('vehicle registration and insurance', () {
      expect(parseDocumentText('CHỨNG NHẬN ĐĂNG KÝ XE Ô TÔ\nBiển số đăng ký 30A-123.45', now: now).type, DocType.vehicleReg);
      expect(parseDocumentText('GIẤY CHỨNG NHẬN BẢO HIỂM BẮT BUỘC TRÁCH NHIỆM DÂN SỰ CỦA CHỦ XE CƠ GIỚI', now: now).type,
          DocType.vehicleInsurance);
    });
  });

  group('Expiry', () {
    test('urgency colours', () {
      Document d(int days, [List<int>? r]) => Document(
          id: 'x', profileId: 'p', type: DocType.inspection, expiryDate: now.add(Duration(days: days)), reminderDays: r);
      expect(urgencyOf(d(-1), now: now), Urgency.expired);
      expect(urgencyOf(d(5), now: now), Urgency.red);
      expect(urgencyOf(d(20), now: now), Urgency.yellow);
      expect(urgencyOf(d(90), now: now), Urgency.green);
      expect(urgencyOf(d(150, [180, 30]), now: now), Urgency.yellow); // hộ chiếu 6 tháng
    });

    test('CCCD milestones', () {
      final b = DateTime(1990, 5, 12);
      expect(cccdExpiryFor(b, DateTime(2016, 4, 10)), DateTime(2030, 5, 12)); // 40 tuổi
      expect(cccdExpiryFor(b, DateTime(2029, 1, 1)), DateTime(2050, 5, 12)); // trong 2 năm trước mốc 40 -> 60
      expect(cccdExpiryFor(b, DateTime(2049, 1, 1)), isNull); // sát 60 -> vô thời hạn
      expect(nextCccdMilestone(DateTime(2016, 2, 20), now: now)!.age, 14);
    });

    test('reminder times', () {
      final d = Document(id: 'x', profileId: 'p', type: DocType.inspection, expiryDate: DateTime(2026, 12, 1));
      final r = reminderTimes(d, now: now);
      expect(r.map((x) => x.daysBefore), [30, 7, 0]);
      expect(r.first.at, DateTime(2026, 11, 1, 9));
    });
  });

  group('Backup', () {
    test('roundtrip + wrong password', () async {
      final bytes = await BackupCodec.encode(
          data: {'a': 1}, files: {'f.enc': Uint8List.fromList([1, 2, 3])}, password: 'mat-khau-123', iterations: 1000);
      final r = await BackupCodec.decode(bytes, 'mat-khau-123');
      expect(r.data['a'], 1);
      expect(r.files['f.enc'], [1, 2, 3]);
      expect(() => BackupCodec.decode(bytes, 'sai'), throwsA(isA<FormatException>()));
    });

    test('store export/import', () async {
      final s = AppStore(db: MemoryPersistence(), vault: MemoryVault());
      await s.load();
      final p = Profile(id: 'p1', name: 'A');
      await s.saveProfile(p);
      final att = await s.addAttachment(Uint8List.fromList([9, 9]), AttachmentKind.image, 'Mặt trước');
      await s.saveDocument(Document(id: 'd1', profileId: 'p1', type: DocType.cccd, attachments: [att]));
      final b = await s.exportBackup('12345678');
      final s2 = AppStore(db: MemoryPersistence(), vault: MemoryVault());
      await s2.load();
      expect(await s2.importBackup(b, '12345678'), 1);
      expect(await s2.readAttachment(s2.docs['d1']!.attachments.first), [9, 9]);
    });

    test('free limit', () async {
      final s = AppStore(db: MemoryPersistence(), vault: MemoryVault());
      await s.load();
      for (var i = 0; i < 10; i++) {
        await s.saveDocument(Document(id: '$i', profileId: 'p', type: DocType.other));
      }
      expect(() => s.saveDocument(Document(id: 'x', profileId: 'p', type: DocType.other)),
          throwsA(isA<LimitReachedException>()));
      await s.setSetting('pro', '1');
      await s.saveDocument(Document(id: 'x', profileId: 'p', type: DocType.other));
      expect(s.docs.length, 11);
    });
  });
}
