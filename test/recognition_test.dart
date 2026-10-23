import 'package:flutter_test/flutter_test.dart';
import 'package:tu_giay_to/core/models.dart';
import 'package:tu_giay_to/core/ocr_parser.dart';
import 'package:tu_giay_to/core/recognition/dates.dart';
import 'package:tu_giay_to/core/recognition/mrz.dart';
import 'package:tu_giay_to/core/recognition/qr.dart';
import 'package:tu_giay_to/core/recognition/text.dart';

/// Dữ liệu mẫu hư cấu, định dạng giống giấy tờ thật.
void main() {
  final now = DateTime(2026, 10, 23);
  OcrGuess text(String t, {List<String> codes = const []}) => parseDocumentText(t, now: now, codes: codes);
  OcrPage page(String t, {List<String> codes = const []}) => OcrPage.fromText(t, codes: codes);

  group('Ngày tháng', () {
    test('các định dạng và nhiễu OCR', () {
      expect(datesIn('12/05/1990'), [DateTime(1990, 5, 12)]);
      expect(datesIn('12-05-1990 và 1.6.2030'), [DateTime(1990, 5, 12), DateTime(2030, 6, 1)]);
      expect(datesIn('l2/O5/199O'), [DateTime(1990, 5, 12)], reason: 'l→1, O→0');
      expect(datesIn('12 / 05 / 1990'), [DateTime(1990, 5, 12)]);
      expect(datesIn('Hà Nội, ngày 12 tháng 3 năm 2020'), [DateTime(2020, 3, 12)]);
      expect(datesIn('31/02/2020'), isEmpty, reason: 'ngày không tồn tại');
      expect(datesIn('12 05 1990'), isEmpty);
      expect(datesIn('12 05 1990', loose: true), [DateTime(1990, 5, 12)]);
      expect(parseDmyCompact('10041990'), DateTime(1990, 4, 10));
    });
  });

  group('QR CCCD', () {
    test('chuẩn 7 trường', () {
      final q = parseCccdQr('001090012345|012345678|Lê Minh Khôi|10041990|Nam|Số 12 ngõ 34 Láng Hạ, Thành Công, Ba Đình, Hà Nội|12112021')!;
      expect(q.number, '001090012345');
      expect(q.oldId, '012345678');
      expect(q.name, 'Lê Minh Khôi');
      expect(q.birth, DateTime(1990, 4, 10));
      expect(q.sex, 'Nam');
      expect(q.address, contains('Ba Đình'));
      expect(q.issue, DateTime(2021, 11, 12));
    });
    test('thiếu CMND cũ, thẻ Căn cước 2024, nữ, có trường thừa', () {
      final q = parseCccdQr('079195001234||Trần Thị Mai Anh|05031995|Nữ|Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh|01072024|')!;
      expect(q.number, '079195001234');
      expect(q.oldId, isNull);
      expect(q.name, 'Trần Thị Mai Anh');
      expect(q.sex, 'Nữ');
      expect(q.issue, DateTime(2024, 7, 1));
    });
    test('không phải QR CCCD', () {
      expect(parseCccdQr('https://hoadon.example.vn/tra-cuu?ma=ABC'), isNull);
      expect(parseCccdQr('12345|abc'), isNull);
      expect(qrKind('https://gplx.example.gov.vn/x'), QrKind.url);
    });
    test('mặt trước có QR: tính hạn theo mốc tuổi 25/40/60', () {
      final g = text('CĂN CƯỚC\nIDENTITY CARD',
          codes: ['001090012345|012345678|Lê Minh Khôi|10041990|Nam|Số 12 Láng Hạ, Ba Đình, Hà Nội|12112021']);
      expect(g.type, DocType.cccd);
      expect(g.number, '001090012345');
      expect(g.name, 'Lê Minh Khôi');
      expect(g.birthDate, DateTime(1990, 4, 10));
      expect(g.issueDate, DateTime(2021, 11, 12));
      expect(g.expiryDate, DateTime(2030, 4, 10), reason: 'cấp năm 31 tuổi → hết hạn ở mốc 40');
      expect(g.source['number'], 'QR');
      expect(g.conf['number']!, greaterThan(.95));
    });
    test('cấp sau 58 tuổi → không thời hạn', () {
      final g = text('', codes: ['001060000111||Phạm Văn Bình|01011960|Nam|Hà Nội, Việt Nam|05052021']);
      expect(g.noExpiry, isTrue);
      expect(g.expiryDate, isNull);
    });
  });

  group('MRZ', () {
    test('chữ số kiểm tra ICAO', () {
      expect(mrzCheck('520727'), 3);
      expect(mrzCheck('L898902C3'), 6);
    });

    final td1 = buildTd1(
        docNumber9: '090012345', optional1: '001090012345', dob: '900410', sex: 'M', exp: '300410', surname: 'LE', given: 'MINH KHOI');

    test('TD1 mặt sau CCCD hợp lệ', () {
      final m = parseMrz(td1, now: now)!;
      expect(m.format, 'TD1');
      expect(m.valid, isTrue);
      expect(m.number, '001090012345');
      expect(m.birth, DateTime(1990, 4, 10));
      expect(m.expiry, DateTime(2030, 4, 10));
      expect(m.sex, 'M');
      expect(m.fullName, 'LE MINH KHOI');
    });

    test('TD1 bị nhiễu OCR (O/0, I/1, «, khoảng trắng, K thay <) vẫn sửa được', () {
      final noisy = [
        td1[0].replaceAll('0', 'O').replaceFirst('<<', '«<'),
        '${td1[1].substring(0, 3).replaceAll('0', 'O')}${td1[1].substring(3).replaceAll('1', 'I')}',
        td1[2].replaceAll('<<<<', '<K<<'),
      ].map((l) => '${l.substring(0, 10)} ${l.substring(10)}').toList();
      final m = parseMrz(['Đặc điểm nhân dạng: Sẹo chấm', ...noisy], now: now)!;
      expect(m.birth, DateTime(1990, 4, 10));
      expect(m.expiry, DateTime(2030, 4, 10));
      expect(m.number, '001090012345');
      expect(m.checksPassed, greaterThanOrEqualTo(3));
      expect(m.fullName, 'LE MINH KHOI');
    });

    test('TD3 hộ chiếu', () {
      final l = buildTd3(number: 'C1234567', dob: '920903', sex: 'F', exp: '320301', surname: 'PHAM', given: 'THU HA');
      final m = parseMrz(l, now: now)!;
      expect(m.isPassport, isTrue);
      expect(m.valid, isTrue);
      expect(m.number, 'C1234567');
      expect(m.birth, DateTime(1992, 9, 3));
      expect(m.expiry, DateTime(2032, 3, 1));
      // số hộ chiếu bị đọc "CI234567" → sửa nhờ chữ số kiểm tra
      final bad = parseMrz([l[0], l[1].replaceFirst('C1', 'CI')], now: now)!;
      expect(bad.number, 'C1234567');
    });

    test('mặt sau CCCD: MRZ + ngày cấp, tên có dấu lấy từ OCR nếu khớp', () {
      final g = parsePages([
        page('Đặc điểm nhân dạng / Personal identification: Nốt ruồi 1cm\n'
            'Ngày, tháng, năm / Date, month, year: 12/11/2021\n'
            'CỤC TRƯỞNG CỤC CẢNH SÁT QUẢN LÝ HÀNH CHÍNH VỀ TRẬT TỰ XÃ HỘI\n${td1.join('\n')}'),
        page('CĂN CƯỚC CÔNG DÂN\nHọ và tên / Full name:\nLÊ MINH KHÔI\nNgày sinh / Date of birth: 10/04/1990'),
      ], now: now);
      expect(g.type, DocType.cccd);
      expect(g.number, '001090012345');
      expect(g.name, 'Lê Minh Khôi');
      expect(g.source['name'], 'OCR+MRZ');
      expect(g.issueDate, DateTime(2021, 11, 12));
      expect(g.birthDate, DateTime(1990, 4, 10));
      expect(g.expiryDate, DateTime(2030, 4, 10));
    });
  });

  group('Mẫu OCR theo loại', () {
    test('CCCD mẫu cũ (2016) không QR', () {
      final g = text('''CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM
CĂN CƯỚC CÔNG DÂN
Số: 001090012345
Họ và tên: NGUYỄN VĂN MẪU
Ngày sinh: 12/05/1990
Giới tính: Nam   Quốc tịch: Việt Nam
Quê quán: Đông Anh, Hà Nội
Nơi thường trú: Số 5 Kim Mã, Ba Đình, Hà Nội
Có giá trị đến: 12/05/2030''');
      expect(g.type, DocType.cccd);
      expect(g.number, '001090012345');
      expect(g.name, 'Nguyễn Văn Mẫu');
      expect(g.sex, 'Nam');
      expect(g.address, contains('Kim Mã'));
      expect(g.expiryDate, DateTime(2030, 5, 12));
    });

    test('thẻ Căn cước 2024 — nhãn song ngữ, giá trị ở dòng dưới, nhiễu OCR', () {
      final g = text('''CĂN CƯỚC
IDENTITY CARD
Số định danh cá nhân / Personal identification number
O79195OO1234
Họ, chữ đệm và tên khai sinh / Full name
TRẦN THỊ MAI ANH
Ngày sinh / Date of birth
05/O3/1995
Giới tính / Sex   Nữ
Nơi cư trú / Place of residence
Phường Bến Nghé, Quận 1, TP. Hồ Chí Minh
Có giá trị đến / Date of expiry
05/03/2035''');
      expect(g.type, DocType.cccd);
      expect(g.number, '079195001234');
      expect(g.name, 'Trần Thị Mai Anh');
      expect(g.birthDate, DateTime(1995, 3, 5));
      expect(g.expiryDate, DateTime(2035, 3, 5));
    });

    test('layout có toạ độ: giá trị nằm bên phải nhãn (khối OCR tách rời)', () {
      final p = OcrPage([
        OcrLine('CĂN CƯỚC CÔNG DÂN', 300, 40, 700, 70),
        OcrLine('Số / No.:', 300, 100, 400, 125),
        OcrLine('038092000777', 420, 98, 640, 127),
        OcrLine('Ngày sinh / Date of birth:', 300, 200, 560, 225),
        OcrLine('01/02/1992', 580, 199, 720, 226),
        OcrLine('Có giá trị đến:', 40, 600, 200, 620),
        OcrLine('01/02/2032', 40, 625, 160, 645),
        OcrLine('Ngày cấp nhầm 09/09/2099', 900, 900, 1000, 920),
      ]);
      final g = parsePages([p], now: now);
      expect(g.number, '038092000777');
      expect(g.birthDate, DateTime(1992, 2, 1));
      expect(g.expiryDate, DateTime(2032, 2, 1), reason: 'lấy ngày ngay dưới nhãn, không lấy ngày xa nhất');
    });

    test('GPLX thẻ PET', () {
      final g = text('''CỘNG HÒA XÃ HỘI CHỦ NGHĨA VIỆT NAM
GIẤY PHÉP LÁI XE / DRIVER'S LICENSE
Số/No: 010123456789
Họ tên/Full name: LÊ MINH KHÔI
Ngày sinh/Date of Birth: 10/04/1990
Quốc tịch/Nationality: VIỆT NAM
Hạng/Class: B2
Ngày trúng tuyển/Beginning date: 03/2015
Hà Nội, ngày 15 tháng 08 năm 2019
Có giá trị đến/Expires: 15/08/2029''');
      expect(g.type, DocType.driverLicense);
      expect(g.number, '010123456789');
      expect(g.name, 'Lê Minh Khôi');
      expect(g.vehicleClass, 'B2');
      expect(g.issueDate, DateTime(2019, 8, 15));
      expect(g.expiryDate, DateTime(2029, 8, 15));
    });

    test('GPLX hạng A1 không thời hạn, nhiễu', () {
      final g = text('''GlẤY PHÉP LÁl XE
DRIVER'S LICENSE
Số/No: 79O1234567 89
Họ tên/Full name: TRẦN THỊ MAI ANH
Hạng / Class: A1
Có giá trị đến/Expires: Không thời hạn''');
      expect(g.type, DocType.driverLicense);
      expect(g.number, '790123456789');
      expect(g.vehicleClass, 'A1');
      expect(g.noExpiry, isTrue);
      expect(g.expiryDate, isNull);
    });

    test('GPLX có QR (PET mới) lấy số từ QR', () {
      final g = text('GIẤY PHÉP LÁI XE\nHạng: B\nCó giá trị đến: 01/01/2036', codes: ['GPLX:011234567890;B']);
      expect(g.number, '011234567890');
      expect(g.source['number'], 'QR');
    });

    test('cà-vẹt (giấy đăng ký xe)', () {
      final g = text('''CHỨNG NHẬN ĐĂNG KÝ XE Ô TÔ
Số: 045123
Tên chủ xe: NGUYỄN VĂN MẪU
Nhãn hiệu: TOYOTA   Số loại: VIOS
Số khung: RL4BT9F35K1234567
Biển số đăng ký: 30A - 123.45
Đăng ký lần đầu ngày: 05/09/2019''');
      expect(g.type, DocType.vehicleReg);
      expect(g.plate, '30A-123.45');
      expect(g.number, '045123');
      expect(g.name, 'Nguyễn Văn Mẫu');
      expect(g.issueDate, DateTime(2019, 9, 5));
      expect(g.expiryDate, isNull);
    });

    test('đăng kiểm — "Có hiệu lực đến hết ngày" và biển số xe máy', () {
      final g = text('''GIẤY CHỨNG NHẬN KIỂM ĐỊNH
AN TOÀN KỸ THUẬT VÀ BẢO VỆ MÔI TRƯỜNG
Biển đăng ký: 29H1 - 234.56
Số seri: KC 2914563
Ngày kiểm định: 28/04/2025
Có hiệu lực đến hết ngày: 27/10/2026''');
      expect(g.type, DocType.inspection);
      expect(g.plate, '29H1-234.56');
      expect(g.number, 'KC2914563');
      expect(g.expiryDate, DateTime(2026, 10, 27));
      expect(g.issueDate, DateTime(2025, 4, 28));
    });

    test('bảo hiểm TNDS — thời hạn từ… đến…', () {
      final g = text('''GIẤY CHỨNG NHẬN BẢO HIỂM BẮT BUỘC
TRÁCH NHIỆM DÂN SỰ CỦA CHỦ XE CƠ GIỚI
Số: TN-2025-778812
Tên chủ xe: NGUYỄN VĂN MẪU
Biển kiểm soát: 30A-123.45
Thời hạn bảo hiểm: Từ 10 giờ 00, ngày 01/11/2025
đến 10 giờ 00, ngày 01/11/2026''');
      expect(g.type, DocType.vehicleInsurance);
      expect(g.plate, '30A-123.45');
      expect(g.number, 'TN-2025-778812');
      expect(g.issueDate, DateTime(2025, 11, 1));
      expect(g.expiryDate, DateTime(2026, 11, 1));
    });

    test('BHYT — mã 2 chữ + 13 số, nhiễu', () {
      final g = text('''THẺ BẢO HIỂM Y TẾ
Mã số: HS 4O1 0123456789
Họ và tên: LÊ MINH KHÔI
Ngày sinh: 10/04/1990
Nơi đăng ký KCB ban đầu: Bệnh viện Bạch Mai
Giá trị sử dụng: từ 01/01/2026 đến 31/12/2026''');
      expect(g.type, DocType.bhyt);
      expect(g.number, 'HS4010123456789');
      expect(g.name, 'Lê Minh Khôi');
      expect(g.issueDate, DateTime(2026, 1, 1));
      expect(g.expiryDate, DateTime(2026, 12, 31));
    });

    test('phiếu bảo hành — suy ra hạn từ số tháng', () {
      final g = text('''PHIẾU BẢO HÀNH
Sản phẩm: Máy giặt
Serial: 7Q2K550912
Ngày mua: 15/03/2026
Thời hạn bảo hành: 24 tháng''');
      expect(g.type, DocType.warranty);
      expect(g.number, '7Q2K550912');
      expect(g.expiryDate, DateTime(2028, 3, 15));
      expect(g.source['expiry'], 'suy luận');
      expect(g.low('expiry'), isTrue, reason: 'suy luận → cần kiểm tra');
    });

    test('hộ chiếu chỉ OCR (MRZ mờ)', () {
      final g = text('''HỘ CHIẾU / PASSPORT
Số hộ chiếu / Passport No: C1234567
Họ và tên / Full name: PHẠM THU HÀ
Ngày sinh / Date of birth: 03/09/1992
Có giá trị đến / Date of expiry: 01/03/2032''');
      expect(g.type, DocType.passport);
      expect(g.number, 'C1234567');
      expect(g.name, 'Phạm Thu Hà');
      expect(g.expiryDate, DateTime(2032, 3, 1));
    });
  });

  group('Phân loại & độ tin cậy', () {
    test('chấm điểm loại, chịu lỗi chính tả OCR', () {
      expect(text('CAN CUÓC CÔNG DAN').type, DocType.cccd);
      expect(text('GIÂY PHEP LAI XE').type, DocType.driverLicense);
      expect(text('THE BAO HIEM Y TE\nNơi đăng ký KCB').type, DocType.bhyt, reason: 'không nhầm thành bảo hiểm xe');
      expect(text('Bánh mì 20.000đ').type, isNull);
    });
    test('trường đoán (không nhãn) bị đánh dấu cần kiểm tra', () {
      final g = text('CĂN CƯỚC CÔNG DÂN\n001090012345\n01/01/2031');
      expect(g.number, '001090012345');
      expect(g.low('number'), isTrue);
      expect(g.low('expiry'), isTrue);
    });
    test('fold xử lý dấu tổ hợp NFD', () {
      expect(fold('Ca\u0306n cu\u031bo\u031b\u0301c'), 'CAN CUOC');
    });
  });
}
