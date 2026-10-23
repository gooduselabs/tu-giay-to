import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/models.dart';
import 'theme.dart';

/// Ảnh minh hoạ giấy tờ MẪU (hư cấu, không giống mẫu thật) để demo trình xem.
Future<Uint8List?> sampleArt(DocType type, String side) async {
  const w = 1012.0, h = 638.0;
  final rec = ui.PictureRecorder();
  final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
  final passport = type == DocType.passport;
  final base = passport ? const Color(0xFFF3EEE3) : const Color(0xFFEFF3F6);
  c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, w, h), const Radius.circular(36)), Paint()..color = base);
  final guil = Paint()
    ..style = PaintingStyle.stroke
    ..color = (passport ? const Color(0xFF8E3B46) : const Color(0xFF3D6A8F)).withValues(alpha: .10);
  for (var r = 30.0; r < 700; r += 14) {
    c.drawCircle(Offset(w * .78 + math.sin(r / 40) * 10, h * .55), r, guil);
  }
  void text(String s, double x, double y, {double size = 26, FontWeight wt = FontWeight.w500, Color color = Palette.ink, String fam = sans}) {
    final tp = TextPainter(
        text: TextSpan(text: s, style: TextStyle(fontFamily: fam, fontSize: size, fontWeight: wt, color: color)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: w - x - 30);
    tp.paint(c, Offset(x, y));
  }

  final band = passport ? const Color(0xFF8E3B46) : const Color(0xFF1F3A5F);
  c.drawRect(const Rect.fromLTWH(0, 0, w, 96), Paint()..color = band);
  text(passport ? 'HỘ CHIẾU MẪU · SAMPLE PASSPORT' : 'THẺ MẪU · SAMPLE ID CARD', 40, 26,
      size: 34, wt: FontWeight.w700, color: Colors.white);
  if (side == 'Mặt sau') {
    text('Đặc điểm nhận dạng: —', 60, 150);
    text('Ngày cấp: 10/04/2016', 60, 200);
    c.drawRect(const Rect.fromLTWH(60, 280, 260, 200), Paint()..color = const Color(0xFFD5DCE3));
    text('Vân tay (minh hoạ)', 70, 490, size: 20, color: Palette.inkSoft);
    final mrz = Paint()..color = Palette.ink.withValues(alpha: .7);
    for (var i = 0; i < 3; i++) {
      c.drawRect(Rect.fromLTWH(60, 540 + i * 26.0, w - 120, 4), mrz);
    }
  } else {
    // Ảnh chân dung minh hoạ.
    c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(50, 140, 230, 300), const Radius.circular(16)),
        Paint()..color = const Color(0xFFCCD5DE));
    c.drawCircle(const Offset(165, 245), 58, Paint()..color = const Color(0xFF9AA8B6));
    c.drawOval(const Rect.fromLTWH(85, 310, 160, 150), Paint()..color = const Color(0xFF9AA8B6));
    final rows = passport
        ? [('Số / No.', 'C1234567'), ('Họ và tên / Full name', 'PHẠM THU HÀ'), ('Ngày sinh / Date of birth', '03/09/1992'), ('Có giá trị đến / Date of expiry', '—')]
        : [('Số / No.', '001090012345'), ('Họ và tên / Full name', 'LÊ MINH KHÔI'), ('Ngày sinh / Date of birth', '12/05/1990'), ('Có giá trị đến / Date of expiry', '—')];
    var y = 140.0;
    for (final r in rows) {
      text(r.$1, 320, y, size: 20, color: Palette.inkSoft);
      text(r.$2, 320, y + 26, size: 32, wt: FontWeight.w700);
      y += 82;
    }
  }
  // Watermark MẪU.
  c.save();
  c.translate(w / 2, h / 2 + 20);
  c.rotate(-.35);
  final tp = TextPainter(
      text: TextSpan(
          text: 'MẪU · SAMPLE',
          style: TextStyle(fontFamily: serif, fontSize: 120, fontWeight: FontWeight.w700, color: Palette.red.withValues(alpha: .16))),
      textDirection: TextDirection.ltr)
    ..layout();
  tp.paint(c, Offset(-tp.width / 2, -tp.height / 2));
  c.restore();

  final img = await rec.endRecording().toImage(w.toInt(), h.toInt());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}
