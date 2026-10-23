import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import '../core/backup_codec.dart';
import '../core/lock_controller.dart';
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

/// Khoá ứng dụng bằng sinh trắc học/mã máy. Logic nằm trong [LockController].
class LockGate extends StatefulWidget {
  final Widget child;
  const LockGate({super.key, required this.child});
  static LockController get controller => appLock;

  /// Bọc mọi thao tác mở Activity khác (camera, chọn file, chia sẻ, xác thực).
  static Future<T> guard<T>(Future<T> Function() action) => controller.guard(action);
  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final c = LockGate.controller;
  AppStore? _store;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = c.changes.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final s = AppScope.store(context);
    if (_store == null) {
      c.enabled = s.lockEnabled;
      c.grace = s.lockGrace;
      c.lockNow();
    } else {
      // Bật/tắt trong Cài đặt: người dùng vừa xác thực nên không khoá lại ngay.
      if (c.enabled != s.lockEnabled) c.setEnabled(s.lockEnabled);
      c.grace = s.lockGrace;
    }
    _store = s;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // "inactive" (hộp thoại hệ thống che lên) không tính là rời ứng dụng.
    if (s == AppLifecycleState.paused || s == AppLifecycleState.hidden) c.onBackground();
    if (s == AppLifecycleState.resumed) c.onForeground();
  }

  @override
  Widget build(BuildContext context) {
    AppScope.store(context);
    if (c.locked) return LockScreen(onUnlocked: () => setState(() {}));
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
    final store = AppScope.store(context);
    final picked = <Picked>[];
    Uint8List? backup;
    for (final f in files) {
      final lower = f.path.toLowerCase();
      final isPdf = lower.endsWith('.pdf') || (f.mimeType ?? '').contains('pdf');
      final isImg = f.type == SharedMediaType.image || (f.mimeType ?? '').startsWith('image/');
      try {
        final bytes = await File(f.path).readAsBytes();
        if (lower.endsWith('.${Media.backupExt}') || BackupCodec.looksLike(bytes)) {
          backup ??= bytes;
        } else if (isPdf || isImg) {
          picked.add((bytes: bytes, pdf: isPdf, name: f.path.split('/').last));
        }
      } catch (_) {}
    }
    ReceiveSharingIntent.instance.reset();
    if (!mounted) return;
    if (backup != null) {
      await restoreFlow(context, store, backup);
      return;
    }
    if (picked.isEmpty) return;
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
