import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../app.dart';
import '../widgets/glyphs.dart';
import 'package:flutter/services.dart';

import '../../core/labels.dart';
import '../../core/models.dart';
import '../../l10n/l10n.dart';
import '../../services/security.dart' as sec;
import '../scope.dart';
import '../theme.dart';
import '../widgets/dossier.dart';

/// Xuất trình nhanh: toàn màn hình, tăng độ sáng tối đa, yêu cầu sinh trắc học nếu bật khoá.
class QuickShowScreen extends StatefulWidget {
  final Document doc;
  const QuickShowScreen({super.key, required this.doc});
  @override
  State<QuickShowScreen> createState() => _QuickShowScreenState();
}

class _QuickShowScreenState extends State<QuickShowScreen> {
  bool _authed = false;
  bool _failed = false;
  int _page = 0;
  final _images = <Future<Uint8List>>[];
  bool _platform = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_images.isEmpty) {
      final store = AppScope.store(context);
      _platform = AppScope.of(context).platformServices;
      for (final a in widget.doc.attachments.where((a) => a.kind == AttachmentKind.image)) {
        _images.add(store.readAttachment(a));
      }
      _start();
    }
  }

  Future<void> _start() async {
    final scope = AppScope.of(context);
    final needAuth = scope.notifier!.lockEnabled && scope.platformServices;
    if (needAuth) {
      final ok = await LockGate.controller.confirm(() => sec.Biometric.authenticate(tr('Xác thực để xuất trình giấy tờ')));
      if (!mounted) return;
      if (!ok) {
        setState(() => _failed = true);
        return;
      }
    }
    setState(() => _authed = true);
    if (scope.platformServices) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await sec.Brightness.boost();
    }
  }

  @override
  void dispose() {
    if (_platform) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      sec.Brightness.reset();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doc;
    final owner = AppScope.store(context).profiles[d.profileId]?.name;
    final pages = _images.isEmpty ? 1 : _images.length;
    return Theme(
      data: buildTheme(Brightness.light),
      child: Scaffold(
      backgroundColor: const Color(0xFFFFFDF8),
      body: SafeArea(
        child: !_authed
            ? Center(
                child: _failed
                    ? Column(mainAxisSize: MainAxisSize.min, children: [
                        const Gl(Ic.lock, size: 48, color: Palette.inkSoft),
                        const SizedBox(height: 12),
                        Text(tr('Chưa xác thực'), style: const TextStyle(color: Palette.ink, fontSize: 18)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: () { setState(() => _failed = false); _start(); }, child: Text(tr('Thử lại'))),
                      ])
                    : const CircularProgressIndicator())
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(children: [
                    IconButton(
                        icon: const Gl(Ic.close, color: Palette.ink),
                        onPressed: () => Navigator.of(context).pop()),
                    const Spacer(),
                    const Gl(Ic.brightness, size: 18, color: Palette.cinnabar),
                    const SizedBox(width: 6),
                    Text(tr('Độ sáng tối đa'), style: const TextStyle(color: Palette.inkSoft, fontSize: 13)),
                  ]),
                ),
                Expanded(
                  child: PageView.builder(
                    itemCount: pages,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (c, i) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: _images.isEmpty
                            ? DossierCard(doc: d, ownerName: owner, reveal: true)
                            : FutureBuilder<Uint8List>(
                                future: _images[i],
                                builder: (c, s) => s.hasData
                                    ? InteractiveViewer(
                                        maxScale: 5,
                                        child: ClipRRect(
                                            borderRadius: BorderRadius.circular(3), child: Image.memory(s.data!)))
                                    : const CircularProgressIndicator(),
                              ),
                      ),
                    ),
                  ),
                ),
                if (pages > 1)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < pages; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.all(4),
                        width: i == _page ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: i == _page ? Palette.cinnabar : Palette.manila, borderRadius: BorderRadius.circular(4)),
                      ),
                  ]),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(color: const Color(0xFFF2ECDF), border: Border.all(color: const Color(0xFFC9B47F))),
                  child: Column(children: [
                    Row(children: [
                      Text(d.type.label.toUpperCase(),
                          style: const TextStyle(color: Palette.cinnabar, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(fileNumber(d), style: const TextStyle(color: Palette.inkSoft, fontSize: 11, fontFeatures: tabular)),
                    ]),
                    const SizedBox(height: 6),
                    FittedBox(
                      child: Text(d.number.isEmpty ? '—' : d.number,
                          style: const TextStyle(
                              color: Palette.ink, fontFamily: serif, fontSize: 40, fontWeight: FontWeight.w500, letterSpacing: 3,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ),
                    if (d.holderName.isNotEmpty || owner != null)
                      Text((d.holderName.isNotEmpty ? d.holderName : owner!).toUpperCase(),
                          style: const TextStyle(color: Palette.ink, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    if (d.expiryDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(tr('Có giá trị đến {d}', {'d': dmy.format(d.expiryDate!)}),
                            style: const TextStyle(color: Palette.inkSoft)),
                      ),
                  ]),
                ),
              ]),
      ),
    ));
  }
}
