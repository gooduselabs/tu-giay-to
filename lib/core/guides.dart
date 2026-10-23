import 'models.dart';

/// Hướng dẫn gia hạn/cấp đổi — nội dung CHUNG, mang tính tham khảo.
/// Không ghi mức phí cụ thể: quy định thay đổi theo thời gian & địa phương.
class RenewalGuide {
  final String summary;
  final List<String> bring;
  final List<String> where;
  final String fee;
  final List<String> tips;
  final List<({String label, String url})> links;
  const RenewalGuide({
    required this.summary,
    required this.bring,
    required this.where,
    required this.fee,
    this.tips = const [],
    this.links = const [],
  });
}

const dvc = (label: 'Cổng Dịch vụ công Quốc gia', url: 'https://dichvucong.gov.vn');
const dvcBca = (label: 'Dịch vụ công Bộ Công an', url: 'https://dichvucong.bocongan.gov.vn');

const _feeCheck =
    'Lệ phí/phí theo quy định hiện hành và có thể thay đổi — vui lòng kiểm tra trên Cổng Dịch vụ công hoặc hỏi trực tiếp nơi làm thủ tục trước khi đi.';

RenewalGuide guideFor(DocType t) => switch (t) {
      DocType.cccd => const RenewalGuide(
          summary:
              'Thẻ căn cước/CCCD cần cấp đổi khi công dân đủ 14, 25, 40 và 60 tuổi (thẻ cấp/đổi trong vòng 2 năm trước mốc tuổi vẫn dùng tới mốc tiếp theo). Ngoài ra cần cấp đổi/cấp lại khi thẻ hỏng, mất, thay đổi thông tin.',
          bring: [
            'Thẻ CCCD/căn cước đang dùng (nếu còn)',
            'Giấy tờ chứng minh thông tin thay đổi (nếu có)',
            'Trẻ dưới 14 tuổi: đi cùng cha/mẹ hoặc người giám hộ',
          ],
          where: [
            'Cơ quan quản lý căn cước thuộc Công an nơi cư trú hoặc nơi thuận tiện',
            'Có thể đặt lịch/nộp hồ sơ trực tuyến qua Cổng Dịch vụ công hoặc ứng dụng VNeID (tuỳ thủ tục)',
          ],
          fee: 'Cấp đổi theo mốc tuổi thường không thu lệ phí; các trường hợp khác có thể thu lệ phí. $_feeCheck',
          tips: ['Đi sớm hoặc đặt lịch hẹn để tránh chờ lâu.', 'Kiểm tra kỹ thông tin trên thẻ mới khi nhận.'],
          links: [dvc, dvcBca],
        ),
      DocType.driverLicense => const RenewalGuide(
          summary:
              'Giấy phép lái xe có thời hạn (ví dụ các hạng ô tô) cần đổi trước khi hết hạn. Nếu quá hạn lâu có thể phải sát hạch lại — nên làm sớm.',
          bring: [
            'Giấy phép lái xe đang dùng',
            'Căn cước/CCCD',
            'Giấy khám sức khoẻ của người lái xe theo mẫu, do cơ sở y tế đủ điều kiện cấp (với hạng yêu cầu)',
            'Tờ khai đề nghị đổi giấy phép (thường có sẵn trên dịch vụ công)',
          ],
          where: [
            'Cơ quan có thẩm quyền cấp đổi giấy phép lái xe tại địa phương (thẩm quyền đã có điều chỉnh từ năm 2025 — kiểm tra trên Cổng Dịch vụ công)',
            'Nhiều nơi cho phép nộp hồ sơ trực tuyến qua Cổng Dịch vụ công hoặc VNeID',
          ],
          fee: _feeCheck,
          tips: ['Tích hợp giấy phép lái xe vào VNeID để xuất trình khi cần.'],
          links: [dvc, dvcBca],
        ),
      DocType.vehicleReg => const RenewalGuide(
          summary:
              'Giấy đăng ký xe (cà-vẹt) thường không có hạn, nhưng cần cấp đổi khi hỏng, mất, đổi thông tin chủ xe, đổi màu sơn/cải tạo, hoặc sang tên.',
          bring: [
            'Giấy đăng ký xe hiện tại (nếu còn)',
            'Căn cước/CCCD của chủ xe',
            'Giấy tờ liên quan đến thay đổi (hợp đồng mua bán, giấy cải tạo…)',
            'Tờ khai đăng ký xe',
          ],
          where: ['Cơ quan Công an đăng ký xe nơi cư trú', 'Một số thủ tục làm được trực tuyến trên Cổng Dịch vụ công'],
          fee: _feeCheck,
          tips: ['Xe vay ngân hàng: hỏi ngân hàng về giấy xác nhận/bản sao đăng ký khi cần.'],
          links: [dvc, dvcBca],
        ),
      DocType.inspection => const RenewalGuide(
          summary:
              'Ô tô phải kiểm định (đăng kiểm) định kỳ. Hãy đưa xe đi kiểm định trước ngày hết hạn ghi trên giấy chứng nhận/tem kiểm định.',
          bring: [
            'Xe cần kiểm định',
            'Giấy đăng ký xe (bản chính, hoặc giấy tờ thay thế hợp lệ nếu xe đang thế chấp)',
            'Giấy chứng nhận kiểm định cũ',
            'Căn cước/CCCD của người mang xe đến',
          ],
          where: ['Bất kỳ trung tâm đăng kiểm xe cơ giới nào được phép hoạt động', 'Nên đặt lịch hẹn trước (qua website/ứng dụng của cơ quan đăng kiểm hoặc của trung tâm)'],
          fee: 'Gồm phí kiểm định và lệ phí cấp giấy chứng nhận theo biểu giá hiện hành; có thể kèm phí sử dụng đường bộ. $_feeCheck',
          tips: ['Kiểm tra phạt nguội trước khi đi để tránh bị từ chối kiểm định.', 'Kiểm tra đèn, còi, gạt mưa, lốp trước khi đến.'],
          links: [dvc],
        ),
      DocType.vehicleInsurance => const RenewalGuide(
          summary:
              'Bảo hiểm trách nhiệm dân sự (TNDS) của chủ xe là bắt buộc; bảo hiểm vật chất là tự nguyện. Gia hạn trước khi hết hạn để không bị gián đoạn.',
          bring: ['Thông tin giấy đăng ký xe (biển số, số khung, số máy)', 'Căn cước/CCCD của chủ xe'],
          where: ['Doanh nghiệp bảo hiểm, đại lý hoặc kênh mua trực tuyến của doanh nghiệp bảo hiểm được cấp phép'],
          fee: 'Phí bảo hiểm TNDS bắt buộc theo biểu phí do Nhà nước quy định; bảo hiểm tự nguyện tuỳ doanh nghiệp. Vui lòng kiểm tra trước khi mua.',
          tips: ['Mua tại đơn vị uy tín, lưu giấy chứng nhận (bản giấy hoặc điện tử) vào ứng dụng này.'],
          links: [dvc],
        ),
      DocType.passport => const RenewalGuide(
          summary:
              'Nhiều quốc gia yêu cầu hộ chiếu còn hạn tối thiểu 6 tháng khi nhập cảnh. Nên làm hộ chiếu mới sớm, trước chuyến đi dự kiến.',
          bring: [
            'Căn cước/CCCD',
            'Hộ chiếu cũ (nếu có)',
            'Ảnh chân dung theo quy định (nếu nộp trực tuyến thì tải ảnh lên)',
            'Trẻ em: giấy khai sinh/giấy tờ chứng minh quan hệ, người đại diện hợp pháp đi cùng',
          ],
          where: [
            'Cơ quan Quản lý xuất nhập cảnh thuộc Công an cấp tỉnh hoặc Cục Quản lý xuất nhập cảnh',
            'Có thể nộp hồ sơ trực tuyến qua Cổng Dịch vụ công',
          ],
          fee: _feeCheck,
          tips: ['Kiểm tra yêu cầu thị thực & thời hạn hộ chiếu của nước đến.'],
          links: [dvc, dvcBca],
        ),
      DocType.warranty => const RenewalGuide(
          summary:
              'Phiếu bảo hành không gia hạn được, nhưng hãy kiểm tra thiết bị và gửi bảo hành trước ngày hết hạn nếu có lỗi.',
          bring: ['Phiếu bảo hành / bảo hành điện tử', 'Hoá đơn mua hàng', 'Thiết bị và phụ kiện đi kèm'],
          where: ['Cửa hàng nơi mua', 'Trung tâm bảo hành chính hãng (tra cứu trên website hãng)'],
          fee: 'Thường miễn phí trong điều kiện bảo hành; lỗi ngoài điều kiện có thể tính phí — hỏi trung tâm bảo hành.',
          tips: ['Một số hãng cho phép mua gói bảo hành mở rộng trước khi hết hạn.'],
        ),
      DocType.bhyt => const RenewalGuide(
          summary:
              'Thẻ BHYT (đặc biệt theo hộ gia đình, học sinh – sinh viên) cần đóng tiếp trước khi hết hạn để không gián đoạn quyền lợi.',
          bring: ['Mã số BHXH / thẻ BHYT', 'Căn cước/CCCD'],
          where: [
            'Đại lý thu BHXH, bưu điện, UBND cấp xã, nhà trường (với học sinh – sinh viên)',
            'Gia hạn trực tuyến qua Cổng Dịch vụ công hoặc ứng dụng VssID',
          ],
          fee: 'Mức đóng tính theo quy định hiện hành (phụ thuộc đối tượng, số người trong hộ). Vui lòng kiểm tra trước khi đóng.',
          tips: ['Có thể dùng thẻ BHYT trên VssID/VNeID khi khám chữa bệnh.'],
          links: [dvc, (label: 'Bảo hiểm xã hội Việt Nam', url: 'https://baohiemxahoi.gov.vn')],
        ),
      DocType.other => const RenewalGuide(
          summary: 'Kiểm tra cơ quan/đơn vị đã cấp giấy tờ để biết thủ tục gia hạn.',
          bring: ['Giấy tờ gốc', 'Căn cước/CCCD'],
          where: ['Cơ quan/đơn vị đã cấp giấy tờ', 'Tra cứu thủ tục trên Cổng Dịch vụ công'],
          fee: _feeCheck,
          links: [dvc],
        ),
    };
