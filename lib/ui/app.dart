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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        height: 68,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.style_outlined), selectedIcon: const Icon(Icons.style), label: tr('Giấy tờ')),
          NavigationDestination(
              icon: const Icon(Icons.people_outline), selectedIcon: const Icon(Icons.people), label: tr('Hồ sơ')),
          NavigationDestination(
              icon: const Icon(Icons.tune_outlined), selectedIcon: const Icon(Icons.tune), label: tr('Cài đặt')),
        ],
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
