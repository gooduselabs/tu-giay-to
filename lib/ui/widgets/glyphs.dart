import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Bộ icon nét mảnh tự vẽ (lưới 24, nét 1.4) — thay cho Material icons.
enum Ic {
  close, add, chevronRight, chevronDown, search, folder, folderOpen, person, people, personAdd, bell, share, lock,
  fingerprint, pen, calendar, idCard, licence, registration, inspection, shield, passport, ribbon, medical, docOther,
  car, motorbike, house, device, grid, sliders, language, cloud, cloudUp, restore, image, camera, pdf, hash, book,
  pin, coin, bulb, sun, moon, auto, key, scan, trash, check, expand, heart, infinity, spark, clip, seal, external,
  brightness, drawer, menu,
}

class Gl extends StatelessWidget {
  final Ic icon;
  final double? size;
  final Color? color;
  final double weight;
  const Gl(this.icon, {super.key, this.size, this.color, this.weight = 1.4});
  @override
  Widget build(BuildContext context) {
    final t = IconTheme.of(context);
    final s = size ?? t.size ?? 24;
    return SizedBox(
      width: s,
      height: s,
      child: CustomPaint(painter: _GP(icon, color ?? t.color ?? Colors.black, weight)),
    );
  }
}

class _GP extends CustomPainter {
  final Ic g;
  final Color color;
  final double w;
  _GP(this.g, this.color, this.w);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 24;
    canvas.scale(k);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * (24 / size.width).clamp(.8, 1.6)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;
    void l(double a, double b, double c, double d) => canvas.drawLine(Offset(a, b), Offset(c, d), p);
    void r(double x, double y, double ww, double hh, [double rad = 1]) =>
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, ww, hh), Radius.circular(rad)), p);
    void c(double x, double y, double rr) => canvas.drawCircle(Offset(x, y), rr, p);
    void dot(double x, double y, [double rr = 1.1]) => canvas.drawCircle(Offset(x, y), rr, fill);
    void arc(double x, double y, double rr, double s, double sw) =>
        canvas.drawArc(Rect.fromCircle(center: Offset(x, y), radius: rr), s, sw, false, p);
    void pl(List<double> v, {bool close = false}) {
      final path = Path()..moveTo(v[0], v[1]);
      for (var i = 2; i < v.length; i += 2) {
        path.lineTo(v[i], v[i + 1]);
      }
      if (close) path.close();
      canvas.drawPath(path, p);
    }

    const pi = math.pi;
    switch (g) {
      case Ic.close: l(6, 6, 18, 18); l(18, 6, 6, 18);
      case Ic.add: l(12, 5, 12, 19); l(5, 12, 19, 12);
      case Ic.chevronRight: pl([9, 6, 15, 12, 9, 18]);
      case Ic.chevronDown: pl([6, 9, 12, 15, 18, 9]);
      case Ic.search: c(10.5, 10.5, 5.5); l(14.5, 14.5, 19.5, 19.5);
      case Ic.folder: pl([3, 7, 3, 19, 21, 19, 21, 8.5, 11.5, 8.5, 9.5, 5.5, 3, 5.5, 3, 7]); l(3, 10.5, 21, 10.5);
      case Ic.folderOpen: pl([3, 18.5, 3, 5.5, 9.5, 5.5, 11.5, 8, 19, 8, 19, 10.5]); pl([3, 18.5, 6, 10.5, 22, 10.5, 19, 18.5, 3, 18.5]);
      case Ic.person: c(12, 8, 3.6); arc(12, 21, 7, pi, pi);
      case Ic.people: c(9, 8.5, 3.2); arc(9, 20.5, 6, pi, pi); arc(16, 8.5, 3, -pi / 2, pi); arc(17, 20.5, 5, -pi / 2, pi / 2);
      case Ic.personAdd: c(10, 8, 3.4); arc(10, 21, 6.5, pi, pi); l(19, 6, 19, 12); l(16, 9, 22, 9);
      case Ic.bell: pl([6, 17, 6, 11]); arc(12, 11, 6, pi, pi); pl([18, 11, 18, 17]); l(4.5, 17, 19.5, 17); arc(12, 18.5, 2, 0, pi);
      case Ic.share: pl([12, 15, 12, 3.5]); pl([8, 7.5, 12, 3.5, 16, 7.5]); pl([8, 10, 5, 10, 5, 20.5, 19, 20.5, 19, 10, 16, 10]);
      case Ic.lock: r(5, 10.5, 14, 10); arc(12, 10.5, 4.2, pi, pi); l(7.8, 10.5, 7.8, 9.5); l(16.2, 10.5, 16.2, 9.5); l(12, 14.5, 12, 16.5);
      case Ic.fingerprint:
        arc(12, 12, 8, pi * 1.1, pi * .8); arc(12, 13, 5.5, pi, pi); arc(12, 14, 3, pi, pi); l(9, 14, 9, 19); l(15, 14, 15, 18);
        l(6.5, 13, 6.5, 17); l(17.5, 13, 17.5, 16); l(12, 14, 12, 20);
      case Ic.pen: pl([4, 20, 5, 15.5, 15.5, 5, 19, 8.5, 8.5, 19, 4, 20]); l(13.5, 7, 17, 10.5);
      case Ic.calendar: r(4, 5.5, 16, 14.5); l(4, 10, 20, 10); l(8.5, 3.5, 8.5, 7); l(15.5, 3.5, 15.5, 7); dot(8.5, 14); dot(12, 14); dot(15.5, 14);
      case Ic.idCard: r(2.5, 5.5, 19, 13); c(8, 11, 2); arc(8, 17.5, 3.5, pi, pi); l(13, 10, 18.5, 10); l(13, 13, 18.5, 13); l(13, 16, 16.5, 16);
      case Ic.licence: r(2.5, 5.5, 19, 13); pl([6, 14.5, 7, 11.5, 12, 11.5, 13, 14.5]); l(5.5, 14.5, 13.5, 14.5); dot(7.5, 15.8, .9); dot(11.5, 15.8, .9); l(15.5, 10, 19, 10); l(15.5, 13, 19, 13);
      case Ic.registration: pl([6, 3, 15, 3, 19, 7, 19, 21, 6, 21, 6, 3]); pl([15, 3, 15, 7, 19, 7]); l(9, 11, 16, 11); l(9, 14, 16, 14); l(9, 17, 13, 17);
      case Ic.inspection: r(5, 4.5, 14, 16.5); r(9, 3, 6, 3, .5); pl([8.5, 12, 10.5, 14, 15.5, 9.5]); l(8.5, 17.5, 15.5, 17.5);
      case Ic.shield: pl([12, 3, 19.5, 6, 19.5, 11.5]); arc(12, 11.5, 7.5, 0, pi / 2 * 1.0); pl([12, 3, 4.5, 6, 4.5, 11.5]); arc(12, 11.5, 7.5, pi / 2, pi / 2); pl([9, 12, 11.2, 14.2, 15.5, 9.8]);
      case Ic.passport: r(5, 3, 14, 18); c(12, 10.5, 3.5); l(8.5, 10.5, 15.5, 10.5); arc(12, 10.5, 3.5, -pi / 2, pi); l(9, 17, 15, 17);
      case Ic.ribbon: c(12, 9, 5.5); c(12, 9, 2.5); pl([8.5, 13.2, 7, 21, 12, 18.5, 17, 21, 15.5, 13.2]);
      case Ic.medical: r(4, 4, 16, 16); pl([10, 7.5, 14, 7.5, 14, 10, 16.5, 10, 16.5, 14, 14, 14, 14, 16.5, 10, 16.5, 10, 14, 7.5, 14, 7.5, 10, 10, 10, 10, 7.5]);
      case Ic.docOther: pl([6, 3, 15, 3, 19, 7, 19, 21, 6, 21, 6, 3]); l(9, 12, 16, 12); l(9, 16, 16, 16);
      case Ic.car: pl([3.5, 16.5, 3.5, 12.5, 6, 7, 18, 7, 20.5, 12.5, 20.5, 16.5]); l(3.5, 16.5, 20.5, 16.5); l(4, 12.5, 20, 12.5); c(7.5, 17.5, 1.8); c(16.5, 17.5, 1.8);
      case Ic.motorbike: c(5.5, 16, 3); c(18.5, 16, 3); pl([5.5, 16, 10, 10, 14.5, 10, 18.5, 16]); pl([13, 7, 15.5, 7, 17, 11]); l(9, 13, 13, 13);
      case Ic.house: pl([3.5, 11, 12, 4, 20.5, 11]); pl([5.5, 9.5, 5.5, 20, 18.5, 20, 18.5, 9.5]); r(10, 14, 4, 6, .3);
      case Ic.device: r(3, 4.5, 18, 12); l(9, 20, 15, 20); l(12, 16.5, 12, 20);
      case Ic.grid: r(4, 4, 6.5, 6.5); r(13.5, 4, 6.5, 6.5); r(4, 13.5, 6.5, 6.5); r(13.5, 13.5, 6.5, 6.5);
      case Ic.sliders: l(4, 7, 20, 7); l(4, 12, 20, 12); l(4, 17, 20, 17); dot(9, 7, 2); dot(15, 12, 2); dot(7, 17, 2);
      case Ic.language: pl([4, 6, 12, 6]); l(8, 4, 8, 6); pl([5, 13, 9, 6]); pl([6, 9, 11, 13]); pl([12, 20, 15.5, 11, 19, 20]); l(13.3, 17, 17.7, 17);
      case Ic.cloud: arc(8, 14, 4, pi / 2, pi); arc(12.5, 10.5, 5, pi * 1.05, pi * .95); arc(17, 14.5, 3.5, -pi / 2, pi); l(8, 18, 17, 18);
      case Ic.cloudUp: arc(8, 14, 4, pi / 2, pi); arc(12.5, 10.5, 5, pi * 1.05, pi * .95); arc(17, 14.5, 3.5, -pi / 2, pi); l(8, 18, 10, 18); l(14, 18, 17, 18); l(12, 21, 12, 13); pl([9.5, 15.5, 12, 13, 14.5, 15.5]);
      case Ic.restore: arc(12, 12, 7.5, -pi * .9, pi * 1.65); pl([3.5, 6, 4.8, 9.6, 8.4, 8.6]); pl([12, 8, 12, 12, 15, 14]);
      case Ic.image: r(3.5, 4.5, 17, 15); pl([3.5, 17, 9, 11.5, 13, 15.5, 15.5, 13, 20.5, 18]); c(15.5, 9, 1.6);
      case Ic.camera: r(3, 7, 18, 12.5); pl([8, 7, 9.5, 4.5, 14.5, 4.5, 16, 7]); c(12, 13, 3.5);
      case Ic.pdf: pl([6, 3, 15, 3, 19, 7, 19, 21, 6, 21, 6, 3]); pl([15, 3, 15, 7, 19, 7]); pl([8.5, 17, 8.5, 12.5, 10.5, 12.5, 10.5, 14.5, 8.5, 14.5]); pl([12.5, 12.5, 12.5, 17, 13.5, 17]); arc(13.5, 14.75, 2.25, -pi / 2, pi); pl([16.5, 17, 16.5, 12.5, 18, 12.5]);
      case Ic.hash: l(9.5, 4, 8, 20); l(16, 4, 14.5, 20); l(5, 9, 19.5, 9); l(4.5, 15, 19, 15);
      case Ic.book: pl([12, 6.5, 12, 20]); pl([12, 6.5, 8, 5, 3.5, 5.5, 3.5, 19, 8, 18.5, 12, 20]); pl([12, 6.5, 16, 5, 20.5, 5.5, 20.5, 19, 16, 18.5, 12, 20]);
      case Ic.pin: arc(12, 9.5, 5.5, pi * .8, pi * 1.4); pl([7.6, 12.8, 12, 20.5, 16.4, 12.8]); c(12, 9.5, 2);
      case Ic.coin: c(12, 12, 8); c(12, 12, 5.5); l(12, 9.5, 12, 14.5);
      case Ic.bulb: arc(12, 9.5, 5.5, pi * .75, pi * 1.5); pl([8.2, 13.4, 9.5, 16.5, 14.5, 16.5, 15.8, 13.4]); l(9.8, 19, 14.2, 19); l(10.8, 21, 13.2, 21);
      case Ic.sun: c(12, 12, 4); for (var i = 0; i < 8; i++) { final a = i * pi / 4; l(12 + 6.5 * math.cos(a), 12 + 6.5 * math.sin(a), 12 + 8.5 * math.cos(a), 12 + 8.5 * math.sin(a)); }
      case Ic.moon: arc(12, 12, 8, pi * .35, pi * 1.45); arc(16.5, 8.5, 6, pi * .55, pi * .95);
      case Ic.auto: c(12, 12, 8); canvas.drawArc(Rect.fromCircle(center: const Offset(12, 12), radius: 8), -pi / 2, pi, true, fill);
      case Ic.key: c(8, 12, 4); pl([12, 12, 21, 12, 21, 15]); l(17.5, 12, 17.5, 14.5);
      case Ic.scan: pl([4, 8.5, 4, 4, 8.5, 4]); pl([15.5, 4, 20, 4, 20, 8.5]); pl([20, 15.5, 20, 20, 15.5, 20]); pl([8.5, 20, 4, 20, 4, 15.5]); l(7, 12, 17, 12);
      case Ic.trash: l(4, 6.5, 20, 6.5); pl([9, 6.5, 9.5, 4, 14.5, 4, 15, 6.5]); pl([6, 6.5, 7, 20.5, 17, 20.5, 18, 6.5]); l(10, 10, 10, 17); l(14, 10, 14, 17);
      case Ic.check: pl([5, 12.5, 10, 17.5, 19, 7]);
      case Ic.expand: pl([4, 9, 4, 4, 9, 4]); pl([15, 4, 20, 4, 20, 9]); pl([20, 15, 20, 20, 15, 20]); pl([9, 20, 4, 20, 4, 15]);
      case Ic.heart: final path = Path()..moveTo(12, 20)..cubicTo(3, 14, 2.5, 8.5, 6.5, 6)..cubicTo(9, 4.5, 11, 6, 12, 7.8)..cubicTo(13, 6, 15, 4.5, 17.5, 6)..cubicTo(21.5, 8.5, 21, 14, 12, 20); canvas.drawPath(path, p);
      case Ic.infinity: final path = Path()..moveTo(12, 12)..cubicTo(9, 7, 4, 8, 4, 12)..cubicTo(4, 16, 9, 17, 12, 12)..cubicTo(15, 7, 20, 8, 20, 12)..cubicTo(20, 16, 15, 17, 12, 12); canvas.drawPath(path, p);
      case Ic.spark: pl([12, 3, 13.6, 10.4, 21, 12, 13.6, 13.6, 12, 21, 10.4, 13.6, 3, 12, 10.4, 10.4, 12, 3], close: true);
      case Ic.clip: final path = Path()..moveTo(15.5, 7)..lineTo(15.5, 16)..arcToPoint(const Offset(8.5, 16), radius: const Radius.circular(3.5))..lineTo(8.5, 6)..arcToPoint(const Offset(13, 6), radius: const Radius.circular(2.25))..lineTo(13, 15.5)..arcToPoint(const Offset(11, 15.5), radius: const Radius.circular(1)); canvas.drawPath(path, p..strokeCap = StrokeCap.round); 
      case Ic.seal: c(12, 12, 8.5); c(12, 12, 6.3); pl([12, 8, 13.2, 10.8, 16, 11, 13.8, 12.9, 14.5, 15.8, 12, 14.3, 9.5, 15.8, 10.2, 12.9, 8, 11, 10.8, 10.8], close: true);
      case Ic.external: pl([13.5, 4, 20, 4, 20, 10.5]); l(20, 4, 11, 13); pl([17, 13.5, 17, 20, 4, 20, 4, 7, 10.5, 7]);
      case Ic.brightness: c(12, 12, 4.5); canvas.drawArc(Rect.fromCircle(center: const Offset(12, 12), radius: 4.5), -pi / 2, pi, true, fill); for (var i = 0; i < 8; i++) { final a = i * pi / 4; l(12 + 7 * math.cos(a), 12 + 7 * math.sin(a), 12 + 8.8 * math.cos(a), 12 + 8.8 * math.sin(a)); }
      case Ic.drawer: r(3.5, 3.5, 17, 17); l(3.5, 12, 20.5, 12); l(10, 7.5, 14, 7.5); l(10, 16, 14, 16);
      case Ic.menu: l(4, 7, 20, 7); l(4, 12, 20, 12); l(4, 17, 14, 17);
    }
  }

  @override
  bool shouldRepaint(covariant _GP o) => o.g != g || o.color != color || o.w != w;
}
