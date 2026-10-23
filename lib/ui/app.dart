import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/models.dart';
import '../data/store.dart';
import '../l10n/l10n.dart';
import '../services/media.dart';
import 'scope.dart';
import 'screens/doc_edit.dart';
import 'screens/home.dart';
import 'screens/lock.dart';
import 'screens/profiles.dart';
import 'screens/settings.dart';
import 'theme.dart';
import 'widgets/glyphs.dart';

class TuGiayToApp extends StatelessWidget {
  final AppStore store;
  final OcrFn? ocr;
  final bool platformServices;
  final Future<bool> Function()? requestNotificationPermission;
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final Widget? home; // dùng cho test/golden
  const TuGiayToApp({
    super.key,
    required this.store,
    this.ocr,
    this.platformServices = true,
    this.requestNotificationPermission,
    this.localizationsDelegates,
    this.home,
  });

  static Future<bool> Function()? notificationPermission;

  @override
  Widget build(BuildContext context) {
    notificationPermission = requestNotificationPermission;
    return AppScope(
      store: store,
      ocr: ocr,
      platformServices: platformServices,
      child: ValueListenableBuilder<String>(
        valueListenable: L10n.locale,
        builder: (context, lang, _) => ListenableBuilder(
          listenable: store,
          builder: (context, _) => MaterialApp(
            title: 'Tủ Giấy Tờ',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: store.themeMode,
            locale: Locale(lang),
            supportedLocales: const [Locale('vi'), Locale('en')],
            localizationsDelegates: localizationsDelegates,
            home: home ?? LockGate(child: const HomeShell()),
          ),
        ),
      ),
    );
  }
}

/// Khoá ứng dụng bằng sinh trắc học/mã máy khi mở và khi quay lại sau 30 giây.
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  static bool suppress = false; // tạm tắt khi mở camera/chọn file
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _unlocked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (s == AppLifecycleState.resumed && _pausedAt != null && !LockGate.suppress) {
      if (DateTime.now().difference(_pausedAt!) > const Duration(seconds: 30)) {
        setState(() => _unlocked = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = AppScope.store(context);
    if (store.lockEnabled && !_unlocked) {
      return LockScreen(onUnlocked: () => setState(() => _unlocked = true));
    }
    return widget.child;
  }
}

class HomeShell extends StatefulWidget {
  final int initialTab;
  const HomeShell({super.key, this.initialTab = 0});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late int _tab = widget.initialTab;
  StreamSubscription? _shareSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenShares());
  }

  void _listenShares() {
    if (!AppScope.of(context).platformServices) return;
    try {
      ReceiveSharingIntent.instance.getInitialMedia().then(_handleShared);
      _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_handleShared);
    } catch (_) {}
  }

  Future<void> _handleShared(List<SharedMediaFile> files) async {
    if (files.isEmpty || !mounted) return;
    final picked = <Picked>[];
    for (final f in files) {
      final isPdf = f.path.toLowerCase().endsWith('.pdf') || (f.mimeType ?? '').contains('pdf');
      final isImg = f.type == SharedMediaType.image || (f.mimeType ?? '').startsWith('image/');
      if (!isPdf && !isImg) continue;
      try {
        picked.add((bytes: await File(f.path).readAsBytes(), pdf: isPdf, name: f.path.split('/').last));
      } catch (_) {}
    }
    ReceiveSharingIntent.instance.reset();
    if (picked.isEmpty || !mounted) return;
    await openNewDocument(context, initialFiles: picked);
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [const HomeScreen(), const ProfilesScreen(), const SettingsScreen()];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: _ArchiveNav(
        index: _tab,
        onTap: (i) => setState(() => _tab = i),
        items: [(Ic.drawer, tr('Tủ hồ sơ')), (Ic.people, tr('Gia đình')), (Ic.sliders, tr('Cài đặt'))],
      ),
    );
  }
}

/// Mở màn thêm giấy tờ, kiểm tra hạn mức miễn phí trước.
Future<void> openNewDocument(BuildContext context,
    {List<Picked> initialFiles = const [], String? profileId, DocType? type}) async {
  final store = AppScope.store(context);
  if (!store.canAddDocument) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen(reason: true)));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DocEditScreen(initialFiles: initialFiles, profileId: profileId, initialType: type)));
}

class _ArchiveNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  final List<(Ic, String)> items;
  const _ArchiveNav({required this.index, required this.onTap, required this.items});
  @override
  Widget build(BuildContext context) {
    final a = context.ar;
    return Container(
      decoration: BoxDecoration(color: a.paper, border: Border(top: BorderSide(color: a.ink, width: 1.2))),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Container(
                    decoration: BoxDecoration(border: i == items.length - 1 ? null : Border(right: BorderSide(color: a.rule))),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(children: [
                      Gl(items[i].$1, size: 20, color: i == index ? a.ink : a.inkFaint),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(items[i].$2.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.5, letterSpacing: 1.4, fontWeight: FontWeight.w700,
                                  color: i == index ? a.ink : a.inkFaint)),
                          const SizedBox(height: 4),
                          AnimatedContainer(
                              duration: const Duration(milliseconds: 200), height: 2, width: i == index ? 16 : 0, color: a.cinnabar),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}
