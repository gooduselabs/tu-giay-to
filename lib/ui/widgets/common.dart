import 'package:flutter/material.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../theme.dart';

/// Nền giấy kẻ dòng rất nhạt + lề đỏ kiểu sổ tay.
class NotebookBackground extends StatelessWidget {
  final Widget child;
  const NotebookBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(painter: _RulePainter(dark), child: child);
  }
}

class _RulePainter extends CustomPainter {
  final bool dark;
  _RulePainter(this.dark);
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = (dark ? Colors.white : Palette.ink).withValues(alpha: dark ? .025 : .04)
      ..strokeWidth = 1;
    for (double y = 28; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final margin = Paint()
      ..color = Palette.red.withValues(alpha: dark ? .10 : .14)
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(12, 0), Offset(12, size.height), margin);
  }

  @override
  bool shouldRepaint(covariant _RulePainter old) => old.dark != dark;
}

class SectionLabel extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionLabel(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface.withValues(alpha: .6);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 10),
      child: Row(children: [
        Container(width: 18, height: 1.4, color: Palette.brass),
        const SizedBox(width: 8),
        Text(text.toUpperCase(),
            style: TextStyle(fontSize: 11.5, letterSpacing: 1.8, fontWeight: FontWeight.w700, color: c)),
        const Spacer(),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;
  const ProfileAvatar(this.profile, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final c = Palette.profileColors[profile.colorIndex % Palette.profileColors.length];
    final initials = profile.isPerson
        ? profile.name.trim().split(RegExp(r'\s+')).last.characters.first.toUpperCase()
        : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, .35)!]),
        border: Border.all(color: Palette.brassLight.withValues(alpha: .7), width: 1.2),
      ),
      alignment: Alignment.center,
      child: initials != null
          ? Text(initials,
              style: TextStyle(fontFamily: serif, color: Colors.white, fontSize: size * .42, fontWeight: FontWeight.w600))
          : Icon(profile.kind.icon, color: Colors.white, size: size * .5),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(shape: BoxShape.circle, color: Palette.brass.withValues(alpha: .14)),
          child: Icon(icon, size: 38, color: Palette.brass),
        ),
        const SizedBox(height: 18),
        Text(title, style: t.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(body,
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurface.withValues(alpha: .65))),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}
