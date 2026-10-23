import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/expiry.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';
import 'glyphs.dart';

final dmy = DateFormat('dd/MM/yyyy');
const _sensitive = {DocType.cccd, DocType.passport, DocType.driverLicense, DocType.bhyt};

String maskNumber(String n, {bool reveal = false}) {
  final s = n.replaceAll(' ', '');
  if (reveal || s.length <= 6) return n;
  return '${s.substring(0, 3)} ··· ${s.substring(s.length - 4)}';
}

String shownNumber(Document d, {bool reveal = false}) => maskNumber(d.number, reveal: reveal || !_sensitive.contains(d.type));

String statusText(Document d) {
  final left = daysLeft(d);
  if (left == null) return tr('Không thời hạn');
  if (left < 0) return tr('Quá hạn {n} ngày', {'n': -left});
  if (left == 0) return tr('Hết hạn hôm nay');
  return tr('Còn {n} ngày', {'n': left});
}

String stampText(Urgency u) => switch (u) {
      Urgency.expired => tr('QUÁ HẠN'),
      Urgency.red => tr('SẮP HẾT'),
      Urgency.yellow => tr('SẮP HẾT'),
      Urgency.green => tr('CÒN HẠN'),
      Urgency.none => tr('VÔ THỜI HẠN'),
    };

/// Dấu mộc cao su: viền kép, xoay nhẹ, mực son loang. [animate] = hiệu ứng "đóng dấu".
class Stamp extends StatelessWidget {
  final Urgency urgency;
  final double scale;
  final bool animate;
  final double angle;
  const Stamp(this.urgency, {super.key, this.scale = 1, this.animate = false, this.angle = -.11});

  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    final c = urgencyColor(urgency, a);
    final body = Transform.rotate(
      angle: angle,
      child: CustomPaint(
        painter: _StampPainter(c),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 9 * scale, vertical: 5 * scale),
          child: Text(stampText(urgency),
              style: TextStyle(
                  fontFamily: sans, fontSize: 11 * scale, fontWeight: FontWeight.w700, letterSpacing: 1.8 * scale,
                  color: c.withValues(alpha: .88))),
        ),
      ),
    );
    if (!animate) return body;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (_, t, child) => Opacity(
          opacity: t.clamp(0, 1), child: Transform.scale(scale: 1.6 - .6 * t, child: child)),
      child: body,
    );
  }
}

class _StampPainter extends CustomPainter {
  final Color c;
  _StampPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..color = c.withValues(alpha: .85)
      ..strokeWidth = 1.6;
    final outer = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(3));
    final inner = outer.deflate(2.6);
    // Viền ngoài đứt quãng như mực in không đều.
    final path = Path()..addRRect(outer);
    final rnd = math.Random(s.width.toInt());
    for (final m in path.computeMetrics()) {
      double d = 0;
      while (d < m.length) {
        final seg = 6 + rnd.nextDouble() * 18;
        canvas.drawPath(m.extractPath(d, d + seg), p);
        d += seg + (rnd.nextDouble() < .3 ? 1.5 : 0);
      }
    }
    canvas.drawRRect(inner, p..strokeWidth = .8);
  }

  @override
  bool shouldRepaint(covariant _StampPainter o) => o.c != c;
}

/// Số ngày còn lại bằng chữ số lớn dạng bảng.
class Countdown extends StatelessWidget {
  final Document doc;
  final double size;
  final CrossAxisAlignment align;
  const Countdown(this.doc, {super.key, this.size = 34, this.align = CrossAxisAlignment.end});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    final left = daysLeft(doc);
    final u = urgencyOf(doc);
    final c = u == Urgency.green || u == Urgency.none ? a.ink : urgencyColor(u, a);
    final big = left == null ? '—' : (left < 0 ? '−${-left}' : left.toString().padLeft(2, '0'));
    final unit = left == null ? tr('không hạn') : (left < 0 ? tr('ngày quá') : tr('ngày'));
    return Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: [
      Text(big,
          style: TextStyle(fontFamily: serif, fontSize: size, height: 1, fontWeight: FontWeight.w500, color: c, fontFeatures: tabular)),
      Text(unit.toUpperCase(), style: TextStyle(fontSize: 9.5, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: a.inkSoft)),
    ]);
  }
}

/// Bìa hồ sơ manila có tab nhãn + số hồ sơ, như phiếu trong tủ lưu trữ.
class DossierCard extends StatefulWidget {
  final Document doc;
  final String? ownerName;
  final String? ownerSub;
  final bool compact;
  final bool reveal;
  final bool animateStamp;
  final VoidCallback? onTap;
  const DossierCard(
      {super.key, required this.doc, this.ownerName, this.ownerSub, this.compact = false, this.reveal = false, this.animateStamp = false, this.onTap});
  @override
  State<DossierCard> createState() => _DossierCardState();
}

class _DossierCardState extends State<DossierCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    final d = widget.doc;
    final u = urgencyOf(d);
    final title = d.title.isEmpty ? d.type.label : d.title;
    final tabStyle = TextStyle(fontSize: 10, letterSpacing: 1.6, fontWeight: FontWeight.w700, color: a.ink.withValues(alpha: .78));

    final tab = AnimatedSlide(
      duration: const Duration(milliseconds: 140),
      offset: Offset(0, _down ? -.12 : 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 5, 14, 4),
        decoration: BoxDecoration(
          color: a.manila,
          border: Border(top: BorderSide(color: a.manilaEdge), left: BorderSide(color: a.manilaEdge), right: BorderSide(color: a.manilaEdge)),
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(3), topRight: Radius.circular(10)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Gl(d.type.icon, size: 13, color: a.ink.withValues(alpha: .8)),
          const SizedBox(width: 6),
          Text(d.type.short, style: tabStyle),
          Container(width: 1, height: 9, margin: const EdgeInsets.symmetric(horizontal: 8), color: a.manilaEdge),
          Text(fileNumber(d), style: tabStyle.copyWith(fontWeight: FontWeight.w500, letterSpacing: .8, fontFeatures: tabular)),
          if (d.isSample) ...[
            const SizedBox(width: 8),
            Text(tr('MẪU'), style: tabStyle.copyWith(color: a.cinnabar)),
          ],
        ]),
      ),
    );

    final body = Container(
      decoration: BoxDecoration(
        color: Color.alphaBlend(a.manila.withValues(alpha: a.dark ? .55 : .42), a.card),
        border: Border.all(color: a.manilaEdge),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomLeft: Radius.circular(2), bottomRight: Radius.circular(2)),
      ),
      child: CustomPaint(
        painter: _RulesPainter(a.manilaEdge.withValues(alpha: .35), widget.compact ? 0 : 3),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, widget.compact ? 12 : 16, 14, widget.compact ? 12 : 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: serif, fontSize: widget.compact ? 19 : 24, height: 1.15, fontWeight: FontWeight.w500, color: a.ink)),
                  const SizedBox(height: 3),
                  Text([widget.ownerName ?? d.holderName, if ((widget.ownerSub ?? '').isNotEmpty) widget.ownerSub!].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: a.inkSoft)),
                ]),
              ),
              const SizedBox(width: 8),
              Padding(padding: const EdgeInsets.only(top: 4), child: Stamp(u, animate: widget.animateStamp, scale: widget.compact ? .9 : 1)),
            ]),
            SizedBox(height: widget.compact ? 10 : 18),
            Container(height: 1, color: a.manilaEdge.withValues(alpha: .8)),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: _field(a, tr('SỐ'), d.number.isEmpty ? '—' : shownNumber(d, reveal: widget.reveal))),
              Expanded(child: _field(a, tr('HẾT HẠN'), d.expiryDate == null ? '—' : dmy.format(d.expiryDate!))),
              if (d.attachments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 10, bottom: 2),
                  child: Row(children: [
                    Gl(Ic.clip, size: 14, color: a.inkSoft),
                    Text('${d.attachments.length}', style: TextStyle(fontSize: 12, color: a.inkSoft, fontFeatures: tabular)),
                  ]),
                ),
              Countdown(d, size: widget.compact ? 28 : 40),
            ]),
          ]),
        ),
      ),
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        scale: _down ? .985 : 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(left: 0), child: tab),
          Transform.translate(offset: const Offset(0, -1), child: body),
        ]),
      ),
    );
  }

  Widget _field(Archive a, String k, String v) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: TextStyle(fontSize: 9.5, letterSpacing: 1.4, fontWeight: FontWeight.w600, color: a.inkSoft)),
        const SizedBox(height: 2),
        Text(v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: .4, color: a.ink, fontFeatures: tabular)),
      ]);
}

class _RulesPainter extends CustomPainter {
  final Color c;
  final int lines;
  _RulesPainter(this.c, this.lines);
  @override
  void paint(Canvas canvas, Size s) {
    if (lines == 0) return;
    final p = Paint()..color = c..strokeWidth = .7;
    for (var i = 1; i <= lines; i++) {
      final y = s.height * i / (lines + 1.4);
      canvas.drawLine(Offset(16, y), Offset(s.width - 16, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant _RulesPainter o) => false;
}
