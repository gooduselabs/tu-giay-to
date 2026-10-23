import 'package:flutter/material.dart';
import '../../core/labels.dart';
import '../../core/models.dart';
import '../theme.dart';
import 'glyphs.dart';

/// Nền giấy dó có vân hạt (ảnh noise lát gạch) — không gradient.
class NotebookBackground extends StatelessWidget {
  final Widget child;
  const NotebookBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: a.paper,
        image: DecorationImage(
          image: const AssetImage('assets/grain.png'),
          repeat: ImageRepeat.repeat,
          scale: 2,
          opacity: a.dark ? .35 : .55,
        ),
      ),
      child: child,
    );
  }
}

/// Tiêu đề mục kiểu sổ cái: số thứ tự + chữ in hoa giãn + đường kẻ mảnh.
class SectionLabel extends StatelessWidget {
  final String text;
  final String? index;
  final Widget? trailing;
  final EdgeInsets padding;
  const SectionLabel(this.text, {super.key, this.index, this.trailing, this.padding = const EdgeInsets.fromLTRB(20, 26, 20, 10)});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return Padding(
      padding: padding,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        if (index != null) ...[
          Text(index!, style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 13, color: a.cinnabar)),
          const SizedBox(width: 8),
        ],
        Text(text.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 2, fontWeight: FontWeight.w700, color: a.ink)),
        const SizedBox(width: 10),
        Expanded(child: Container(height: 1, color: a.rule)),
        if (trailing != null) ...[const SizedBox(width: 6), trailing!],
      ]),
    );
  }
}

/// Ấn triện vuông (thành viên) hoặc khung glyph (tài sản).
class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;
  const ProfileAvatar(this.profile, {super.key, this.size = 44});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    if (profile.isPerson) {
      final initial = profile.name.trim().split(RegExp(r'\s+')).last.characters.first.toUpperCase();
      return Transform.rotate(
        angle: -.04,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: a.cinnabar.withValues(alpha: a.dark ? .85 : .92), borderRadius: BorderRadius.circular(3)),
          padding: EdgeInsets.all(size * .07),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: a.paper.withValues(alpha: .85), width: 1.2), borderRadius: BorderRadius.circular(2)),
            alignment: Alignment.center,
            child: Text(initial, style: TextStyle(fontFamily: serif, color: a.paper, fontSize: size * .46, fontWeight: FontWeight.w600, height: 1)),
          ),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(border: Border.all(color: a.ink.withValues(alpha: .7)), borderRadius: BorderRadius.circular(2)),
      alignment: Alignment.center,
      child: Gl(profile.kind.icon, size: size * .55, color: a.ink),
    );
  }
}

class EmptyState extends StatelessWidget {
  final Ic icon;
  final String title;
  final String body;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 40, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Gl(icon, size: 40, color: a.cinnabar, weight: 1.2),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(body, style: TextStyle(color: a.inkSoft, height: 1.5)),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    );
  }
}

/// Dòng sổ cái: nhãn trái, giá trị phải, kẻ mảnh dưới.
class LedgerRow extends StatelessWidget {
  final String k;
  final String v;
  final bool mono;
  final bool last;
  final Color? color;
  const LedgerRow(this.k, this.v, {super.key, this.mono = false, this.last = false, this.color});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: a.rule))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 128, child: Text(k, style: TextStyle(fontSize: 12.5, color: a.inkSoft))),
        Expanded(
          child: SelectableText(v,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600, color: color ?? a.ink, letterSpacing: mono ? 1 : 0, fontFeatures: tabular)),
        ),
      ]),
    );
  }
}

/// Chuyển trang "mở bìa hồ sơ": trang mới trải xuống từ mép trên.
class FolderRoute<T> extends PageRouteBuilder<T> {
  FolderRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (c, _, _) => builder(c),
          transitionsBuilder: (c, anim, _, child) {
            final t = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
            return FadeTransition(
              opacity: Tween(begin: .0, end: 1.0).animate(CurvedAnimation(parent: anim, curve: const Interval(0, .6))),
              child: AnimatedBuilder(
                animation: t,
                builder: (_, ch) => Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, .0012)
                    ..rotateX((1 - t.value) * -.35),
                  child: ch,
                ),
                child: child,
              ),
            );
          },
        );
}

/// Nút chữ có gạch chân (thay cho nút bo tròn).
class InkLink extends StatelessWidget {
  final String label;
  final Ic? icon;
  final VoidCallback? onTap;
  const InkLink(this.label, {super.key, this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Gl(icon!, size: 16, color: a.cinnabar), const SizedBox(width: 6)],
          Text(label,
              style: TextStyle(
                  color: a.cinnabar, fontWeight: FontWeight.w600, fontSize: 13.5,
                  decoration: TextDecoration.underline, decorationColor: a.cinnabar.withValues(alpha: .5))),
        ]),
      ),
    );
  }
}
