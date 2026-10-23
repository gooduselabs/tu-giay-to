// Chụp màn hình bằng golden test: `flutter test --update-goldens test/screenshots_test.dart`
// Ảnh ra test/goldens/*.png (dữ liệu MẪU, hư cấu).
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:tu_giay_to/core/models.dart';
import 'package:tu_giay_to/core/ocr_parser.dart';
import 'package:tu_giay_to/data/persistence.dart';
import 'package:tu_giay_to/data/sample_data.dart';
import 'package:tu_giay_to/data/store.dart';
import 'package:tu_giay_to/ui/app.dart';
import 'package:tu_giay_to/ui/sample_art.dart';
import 'package:tu_giay_to/ui/screens/doc_detail.dart';
import 'package:tu_giay_to/ui/screens/capture.dart';
import 'package:tu_giay_to/ui/screens/doc_edit.dart';
import 'package:tu_giay_to/ui/screens/guide.dart';
import 'package:tu_giay_to/ui/screens/lock.dart';
import 'package:tu_giay_to/ui/screens/profiles.dart';
import 'package:tu_giay_to/ui/screens/quick_show.dart';
import 'package:tu_giay_to/ui/screens/settings.dart';
import 'package:tu_giay_to/ui/screens/viewer.dart';

Future<void> _font(String family, List<String> files) async {
  final l = FontLoader(family);
  for (final f in files) {
    l.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
  }
  await l.load();
}

void main() {
  late AppStore store;
  late Uint8List cardFront;

  setUpAll(() async {
    await initializeDateFormatting('vi');
    await initializeDateFormatting('en');
    await _font('BeVietnamPro', [
      for (final w in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) 'assets/fonts/BeVietnamPro-$w.ttf'
    ]);
    await _font('Lora', ['assets/fonts/Lora.ttf', 'assets/fonts/Lora-Italic.ttf']);
    final root = Platform.environment['FLUTTER_ROOT'] ?? '/workspace/.tools/flutter';
    await _font('MaterialIcons', ['$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
  });

  Future<void> boot(WidgetTester tester, {bool samples = true}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    await tester.runAsync(() async {
      store = AppStore(db: MemoryPersistence(), vault: MemoryVault());
      await store.load();
      if (samples) await seedSamples(store, art: sampleArt);
      cardFront = (await sampleArt(DocType.cccd, 'Mặt trước'))!;
    });
  }

  Future<void> shot(WidgetTester tester, Widget home, String name, {String theme = 'light'}) async {
    await tester.runAsync(() => store.setSetting('theme', theme));
    await tester.pumpWidget(TuGiayToApp(
      store: store,
      platformServices: false,
      home: home,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    ));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 250)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    for (final el in find.byType(Image).evaluate()) {
      final w = el.widget as Image;
      await tester.runAsync(() => precacheImage(w.image, el));
    }
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 5));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  Document byType(DocType t) => store.docs.values.firstWhere((d) => d.type == t);

  testWidgets('screenshots', (tester) async {
    debugDisableShadows = false;
    await boot(tester);
    await shot(tester, const HomeShell(), '01_home');
    await shot(tester, const HomeShell(), '02_home_dark', theme: 'dark');
    await shot(tester, DocDetailScreen(docId: byType(DocType.cccd).id), '03_detail');
    final car = store.profiles.values.firstWhere((p) => p.kind == ProfileKind.car);
    await shot(
        tester,
        DocEditScreen(
          initialFiles: [(bytes: cardFront, pdf: false, name: 'front.jpg')],
          // QR mặt trước (độ tin cậy cao) + ngày hết hạn chỉ đoán được (độ tin cậy thấp → viền vàng)
          initialGuess: parseDocumentText('CĂN CƯỚC\nIDENTITY CARD\n10/04/2040',
              codes: ['001090012345|012345678|Lê Minh Khôi|10041990|Nam|Số 12 Láng Hạ, Ba Đình, Hà Nội|']),
          profileId: store.profiles.values.firstWhere((p) => p.name == 'Lê Minh Khôi').id,
        ),
        '04_add_ocr');
    await shot(
        tester,
        CaptureScreen(
            type: DocType.cccd,
            debugPreview: Container(
                color: const Color(0xFF3A352E),
                alignment: const Alignment(0, -.08),
                child: Transform.rotate(angle: -.03, child: Image.memory(cardFront, width: 350)))),
        '16_capture');
    await shot(tester, QuickShowScreen(doc: byType(DocType.cccd)), '05_quick_show');
    await shot(tester, const HomeShell(initialTab: 1), '06_profiles');
    await shot(tester, ProfileDetailScreen(profileId: car.id), '07_profile_car');
    await shot(tester, const GuideScreen(type: DocType.inspection), '08_guide');
    await shot(tester, const HomeShell(initialTab: 2), '09_settings');
    await tester.runAsync(() async {
      await store.setSetting('lock', '1');
      await store.markBackedUp(DateTime.now().subtract(const Duration(days: 3)));
    });
    await shot(tester, const HomeShell(initialTab: 2), '14_backup');
    // Nhắc sao lưu: cần ít nhất một giấy tờ "thật" (không phải MẪU).
    final real = byType(DocType.cccd)..isSample = false;
    await tester.runAsync(() => store.markBackedUp(DateTime.now().subtract(const Duration(days: 45))));
    await shot(tester, const HomeShell(initialTab: 2), '15_backup_overdue', theme: 'dark');
    real.isSample = true;
    await tester.runAsync(() async {
      await store.setSetting('lock', '0');
      await store.setSetting('backup_last', '');
    });
    await shot(tester, const ProScreen(reason: true), '10_pro');
    await shot(tester, ViewerScreen(doc: byType(DocType.cccd)), '11_viewer');
    await shot(tester, LockScreen(onUnlocked: () {}), '12_lock');
    await shot(tester, DocDetailScreen(docId: byType(DocType.passport).id), '13_detail_dark', theme: 'dark');
    debugDisableShadows = true;
  });
}
