import 'package:flutter/material.dart';
import '../core/expiry.dart';

/// Art direction "Hồ sơ lưu trữ": giấy dó ngà, mực xanh than, son đỏ con dấu,
/// bìa hồ sơ màu manila, đường kẻ sổ cái. Không gradient, không bóng đổ.
class Palette {
  static const paper = Color(0xFFF2ECDF);
  static const ink = Color(0xFF1F2A37);
  static const inkSoft = Color(0xFF5E6672);
  static const cinnabar = Color(0xFFB0392B);
  static const red = cinnabar;
  static const ochre = Color(0xFFA9782A);
  static const olive = Color(0xFF52683F);
  static const manila = Color(0xFFE3D2A6);
  static const brass = ochre;
  static const night = Color(0xFF1E1D1A);

  static const profileColors = [
    Color(0xFF1F2A37), Color(0xFFB0392B), Color(0xFF52683F), Color(0xFFA9782A),
    Color(0xFF4A5A6E), Color(0xFF7A4B3A), Color(0xFF6B6250), Color(0xFF2F4F4F),
  ];
}

@immutable
class Archive extends ThemeExtension<Archive> {
  final Color paper, paperDeep, card, ink, inkSoft, inkFaint, rule, ruleStrong, cinnabar, manila, manilaEdge, ochre, olive;
  final bool dark;
  const Archive({
    required this.paper, required this.paperDeep, required this.card, required this.ink, required this.inkSoft,
    required this.inkFaint, required this.rule, required this.ruleStrong, required this.cinnabar, required this.manila,
    required this.manilaEdge, required this.ochre, required this.olive, required this.dark,
  });

  static const light = Archive(
    paper: Color(0xFFF2ECDF), paperDeep: Color(0xFFE9E1CF), card: Color(0xFFFAF6EC),
    ink: Color(0xFF1F2A37), inkSoft: Color(0xFF5E6672), inkFaint: Color(0xFF9A9584),
    rule: Color(0xFFD8CDB6), ruleStrong: Color(0xFFB9AB8E),
    cinnabar: Color(0xFFB0392B), manila: Color(0xFFE3D2A6), manilaEdge: Color(0xFFC9B47F),
    ochre: Color(0xFFA9782A), olive: Color(0xFF52683F), dark: false,
  );

  /// "Kho lưu trữ về đêm": giấy than chì ấm, không đen tuyền.
  static const night = Archive(
    paper: Color(0xFF1E1D1A), paperDeep: Color(0xFF262420), card: Color(0xFF2A2824),
    ink: Color(0xFFE8E0CF), inkSoft: Color(0xFFADA593), inkFaint: Color(0xFF7A7365),
    rule: Color(0xFF3A3731), ruleStrong: Color(0xFF575146),
    cinnabar: Color(0xFFD9604B), manila: Color(0xFF4A4232), manilaEdge: Color(0xFF6A5D42),
    ochre: Color(0xFFCF9F4E), olive: Color(0xFF8DA572), dark: true,
  );

  @override
  Archive copyWith() => this;
  @override
  Archive lerp(ThemeExtension<Archive>? other, double t) => t < .5 ? this : (other as Archive? ?? this);
}

extension ArchiveX on BuildContext {
  Archive get ar => Theme.of(this).extension<Archive>()!;
}

/// Màu trạng thái hạn (dùng cho con dấu).
Color urgencyColor(Urgency u, [Archive a = Archive.light]) => switch (u) {
      Urgency.expired => a.cinnabar,
      Urgency.red => a.cinnabar,
      Urgency.yellow => a.ochre,
      Urgency.green => a.olive,
      Urgency.none => a.inkFaint,
    };

const serif = 'Lora';
const sans = 'BeVietnamPro';
const tabular = [FontFeature.tabularFigures(), FontFeature.liningFigures()];

ThemeData buildTheme(Brightness b) {
  final a = b == Brightness.dark ? Archive.night : Archive.light;
  final scheme = ColorScheme.fromSeed(seedColor: a.ink, brightness: b).copyWith(
    primary: a.ink, onPrimary: a.paper, secondary: a.cinnabar, surface: a.paper, onSurface: a.ink,
    surfaceContainerHighest: a.paperDeep, outline: a.ruleStrong, outlineVariant: a.rule, error: a.cinnabar,
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: sans);
  final text = base.textTheme.apply(bodyColor: a.ink, displayColor: a.ink, fontFamily: sans);
  final sq = RoundedRectangleBorder(borderRadius: BorderRadius.circular(2));
  return base.copyWith(
    extensions: [a],
    scaffoldBackgroundColor: a.paper,
    splashFactory: InkSparkle.constantTurbulenceSeedSplashFactory,
    textTheme: text.copyWith(
      displayLarge: TextStyle(fontFamily: serif, fontSize: 64, height: 1, fontWeight: FontWeight.w500, color: a.ink, fontFeatures: tabular),
      displaySmall: TextStyle(fontFamily: serif, fontSize: 36, height: 1.05, fontWeight: FontWeight.w500, letterSpacing: -.8, color: a.ink),
      headlineSmall: TextStyle(fontFamily: serif, fontSize: 24, height: 1.15, fontWeight: FontWeight.w500, color: a.ink),
      titleLarge: TextStyle(fontFamily: serif, fontSize: 20, fontWeight: FontWeight.w500, color: a.ink),
      titleMedium: TextStyle(fontFamily: sans, fontSize: 15, fontWeight: FontWeight.w600, color: a.ink),
      bodyMedium: TextStyle(fontFamily: sans, fontSize: 14, height: 1.45, color: a.ink),
      bodySmall: TextStyle(fontFamily: sans, fontSize: 12.5, height: 1.4, color: a.inkSoft),
      labelSmall: TextStyle(fontFamily: sans, fontSize: 10.5, letterSpacing: 1.6, fontWeight: FontWeight.w600, color: a.inkSoft),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: a.paper, surfaceTintColor: Colors.transparent, foregroundColor: a.ink, elevation: 0,
      scrolledUnderElevation: 0, centerTitle: false, toolbarHeight: 56,
      titleTextStyle: TextStyle(fontFamily: sans, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600, color: a.inkSoft),
      shape: Border(bottom: BorderSide(color: a.rule)),
    ),
    cardTheme: CardThemeData(color: a.card, elevation: 0, margin: EdgeInsets.zero, shape: sq.copyWith(side: BorderSide(color: a.rule))),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      labelStyle: TextStyle(color: a.inkSoft, fontSize: 13),
      floatingLabelStyle: TextStyle(color: a.cinnabar, fontSize: 12, letterSpacing: .4),
      hintStyle: TextStyle(color: a.inkFaint),
      border: UnderlineInputBorder(borderSide: BorderSide(color: a.ruleStrong)),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: a.ruleStrong)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: a.ink, width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      isDense: true,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.transparent, selectedColor: a.ink,
      labelStyle: TextStyle(fontFamily: sans, color: a.ink, fontSize: 13),
      side: BorderSide(color: a.ruleStrong), shape: sq, showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: a.ink, foregroundColor: a.paper, minimumSize: const Size(48, 50), shape: sq, elevation: 0,
        textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 14.5, letterSpacing: .3),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48), foregroundColor: a.ink, side: BorderSide(color: a.ink.withValues(alpha: .6)), shape: sq,
        textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 13.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: a.cinnabar, shape: sq,
          textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 13.5)),
    ),
    dividerTheme: DividerThemeData(color: a.rule, space: 1, thickness: 1),
    listTileTheme: ListTileThemeData(iconColor: a.ink, textColor: a.ink, contentPadding: const EdgeInsets.symmetric(horizontal: 0)),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? a.paper : a.inkSoft),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? a.cinnabar : Colors.transparent),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? a.cinnabar : a.ruleStrong),
    ),
    dialogTheme: DialogThemeData(backgroundColor: a.card, shape: sq, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: a.card, surfaceTintColor: Colors.transparent, shape: sq),
    popupMenuTheme: PopupMenuThemeData(color: a.card, shape: sq.copyWith(side: BorderSide(color: a.rule)), elevation: 0),
    snackBarTheme: SnackBarThemeData(backgroundColor: a.ink, contentTextStyle: TextStyle(color: a.paper, fontFamily: sans), shape: sq, behavior: SnackBarBehavior.floating),
    datePickerTheme: DatePickerThemeData(backgroundColor: a.card, surfaceTintColor: Colors.transparent, shape: sq),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: a.cinnabar),
  );
}
