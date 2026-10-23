import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/expiry.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../theme.dart';

final dmy = DateFormat('dd/MM/yyyy');

/// Chỉ che số các giấy tờ định danh cá nhân.
const _sensitive = {DocType.cccd, DocType.passport, DocType.driverLicense, DocType.bhyt};

String maskNumber(String n, {bool reveal = false}) {
  final s = n.replaceAll(' ', '');
  if (reveal || s.length <= 6) return n;
  return '${s.substring(0, 4)} •••• ${s.substring(s.length - 4)}';
}

String statusText(Document d) {
  final left = daysLeft(d);
  if (left == null) return tr('Không thời hạn');
  if (left < 0) return tr('Quá hạn {n} ngày', {'n': -left});
  if (left == 0) return tr('Hết hạn hôm nay');
  if (left > 60) {
    final months = (left / 30.4).floor();
    return tr('Còn {n} tháng', {'n': months});
  }
  return tr('Còn {n} ngày', {'n': left});
}

class StatusPill extends StatelessWidget {
  final Document doc;
  final bool onDark;
  const StatusPill(this.doc, {super.key, this.onDark = true});
  @override
  Widget build(BuildContext context) {
    final u = urgencyOf(doc);
    final c = urgencyColor(u);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: onDark ? Colors.black.withValues(alpha: .28) : c.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: c.withValues(alpha: onDark ? .9 : .5)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(statusText(doc),
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w600, color: onDark ? Colors.white : c, letterSpacing: .2)),
      ]),
    );
  }
}

/// Thẻ giấy tờ phong cách "ví da": gradient theo loại, đường chỉ khâu, hoa văn guilloche.
class WalletCard extends StatelessWidget {
  final Document doc;
  final String? ownerName;
  final bool compact;
  final bool reveal;
  final VoidCallback? onTap;
  const WalletCard({super.key, required this.doc, this.ownerName, this.compact = false, this.reveal = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final g = doc.type.gradient;
    final radius = BorderRadius.circular(compact ? 20 : 24);
    final title = doc.title.isEmpty ? doc.type.label : doc.title;
    final white70 = Colors.white.withValues(alpha: .72);
    final content = Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 16 : 20, 18, compact ? 14 : 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(doc.type.icon, size: 16, color: Palette.brassLight),
          const SizedBox(width: 6),
          Text(doc.type.short,
              style: const TextStyle(
                  color: Palette.brassLight, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          if (doc.isSample) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(6)),
              child: Text(tr('MẪU'),
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ),
          ],
          const Spacer(),
          StatusPill(doc),
        ]),
        SizedBox(height: compact ? 10 : 18),
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontFamily: serif, color: Colors.white, fontSize: compact ? 19 : 23, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        if (doc.number.isNotEmpty)
          Text(maskNumber(doc.number, reveal: reveal || !_sensitive.contains(doc.type)),
              style: TextStyle(
                  color: Colors.white.withValues(alpha: .92),
                  fontSize: compact ? 14 : 16,
                  letterSpacing: 1.6,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        const Spacer(),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('CHỦ SỞ HỮU'), style: TextStyle(color: white70, fontSize: 9, letterSpacing: 1.5)),
              const SizedBox(height: 2),
              Text((ownerName ?? doc.holderName).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: .8)),
            ]),
          ),
          if (doc.expiryDate != null)
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(tr('HẾT HẠN'), style: TextStyle(color: white70, fontSize: 9, letterSpacing: 1.5)),
              const SizedBox(height: 2),
              Text(dmy.format(doc.expiryDate!),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()])),
            ]),
          if (doc.attachments.isNotEmpty) ...[
            const SizedBox(width: 12),
            Icon(Icons.attach_file, size: 15, color: white70),
            Text('${doc.attachments.length}', style: TextStyle(color: white70, fontSize: 12)),
          ],
        ]),
      ]),
    );

    return AspectRatio(
      aspectRatio: compact ? 2.2 : 1.586,
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: g),
            boxShadow: [
              BoxShadow(color: g.first.withValues(alpha: .35), blurRadius: 18, offset: const Offset(0, 8)),
            ],
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: CustomPaint(
              painter: _LeatherPainter(radius: compact ? 20 : 24),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

class _LeatherPainter extends CustomPainter {
  final double radius;
  _LeatherPainter({required this.radius});
  @override
  void paint(Canvas canvas, Size size) {
    final clip = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(clip);
    // Guilloche: các vòng tròn đồng tâm lệch nhau.
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8
      ..color = Colors.white.withValues(alpha: .07);
    final c1 = Offset(size.width * .92, size.height * .1);
    for (var r = 20.0; r < size.width; r += 9) {
      canvas.drawCircle(c1 + Offset(math.sin(r / 30) * 6, math.cos(r / 30) * 6), r, p);
    }
    // Ánh sáng chéo.
    final sheen = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: .10), Colors.transparent, Colors.black.withValues(alpha: .12)],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, sheen);
    canvas.restore();
    // Đường chỉ khâu.
    final stitch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = Palette.brassLight.withValues(alpha: .45);
    final inner = RRect.fromRectAndRadius((Offset.zero & size).deflate(7), Radius.circular(radius - 6));
    final path = Path()..addRRect(inner);
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 9) {
        canvas.drawPath(m.extractPath(d, d + 4.5), stitch);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LeatherPainter old) => old.radius != radius;
}
