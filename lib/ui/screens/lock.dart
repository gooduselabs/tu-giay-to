import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/security.dart';
import '../scope.dart';
import '../theme.dart';

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
    return Scaffold(
      backgroundColor: Palette.night,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(center: Alignment(0, -.4), radius: 1.1, colors: [Color(0xFF1E2636), Palette.night]),
        ),
        child: SafeArea(
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.brass, width: 1.5),
                  color: Palette.brass.withValues(alpha: .08),
                ),
                child: const Icon(Icons.lock_outline, size: 42, color: Palette.brassLight),
              ),
              const SizedBox(height: 24),
              Text(tr('Tủ Giấy Tờ'),
                  style: const TextStyle(fontFamily: serif, fontSize: 30, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(tr('Đã khoá để bảo vệ giấy tờ của bạn'), style: TextStyle(color: Colors.white.withValues(alpha: .6))),
              const SizedBox(height: 36),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Palette.brass, minimumSize: const Size(220, 52)),
                onPressed: _busy ? null : _auth,
                icon: const Icon(Icons.fingerprint),
                label: Text(tr('Mở khoá')),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
