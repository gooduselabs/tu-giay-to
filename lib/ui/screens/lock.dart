import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/security.dart' show Biometric;
import '../scope.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/glyphs.dart';

/// Màn khoá: như tủ hồ sơ đã niêm phong — dải niêm son đỏ chéo góc.
class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  const LockScreen({super.key, required this.onUnlocked});
  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _auth());
  }

  Future<void> _auth() async {
    if (!AppScope.of(context).platformServices) return;
    setState(() => _busy = true);
    final ok = await Biometric.authenticate(tr('Mở khoá Tủ Giấy Tờ'));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) widget.onUnlocked();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildTheme(Brightness.dark),
      child: Builder(builder: (context) {
        final a = context.ar;
        return Scaffold(
          body: NotebookBackground(
            child: SafeArea(
              child: Stack(children: [
                Positioned(
                  right: -40,
                  top: 120,
                  child: Transform.rotate(
                    angle: .5,
                    child: Container(
                      width: 320,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      color: a.cinnabar.withValues(alpha: .85),
                      child: Text(tr('NIÊM PHONG · ĐÃ KHOÁ · NIÊM PHONG'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: a.paper, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 40, 28, 32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('SỔ LƯU TRỮ GIA ĐÌNH'), style: TextStyle(fontSize: 10.5, letterSpacing: 2, fontWeight: FontWeight.w700, color: a.inkSoft)),
                    const SizedBox(height: 6),
                    Container(height: 1.2, width: 120, color: a.ink),
                    const Spacer(),
                    Gl(Ic.lock, size: 46, color: a.cinnabar, weight: 1.2),
                    const SizedBox(height: 20),
                    Text(tr('Tủ Giấy Tờ'), style: TextStyle(fontFamily: serif, fontSize: 46, height: 1, color: a.ink)),
                    const SizedBox(height: 10),
                    Text(tr('Đã khoá để bảo vệ giấy tờ của bạn'),
                        style: TextStyle(fontFamily: serif, fontStyle: FontStyle.italic, fontSize: 16, color: a.inkSoft)),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: a.ink, foregroundColor: a.paper, minimumSize: const Size.fromHeight(54)),
                        onPressed: _busy ? null : _auth,
                        icon: Gl(Ic.fingerprint, size: 20, color: a.paper),
                        label: Text(tr('Mở khoá')),
                      ),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }
}
