import 'package:flutter/material.dart';
import '../core/expiry.dart';

/// "Sổ tay giấy tờ cao cấp": giấy kem + mực xanh đen + đồng thau.
class Palette {
  static const paper = Color(0xFFF4EFE6);
  static const paperDeep = Color(0xFFEAE2D3);
  static const ink = Color(0xFF1C2230);
  static const inkSoft = Color(0xFF5B6272);
  static const brass = Color(0xFFB08D57);
  static const brassLight = Color(0xFFD9BE8C);
  static const night = Color(0xFF10141C);
  static const nightCard = Color(0xFF1A202B);
  static const nightLine = Color(0xFF2A3140);
  static const red = Color(0xFFC0483E);
  static const yellow = Color(0xFFD69A2D);
  static const green = Color(0xFF3E8E5E);
  static const grey = Color(0xFF8A8F99);

  static const profileColors = [
    Color(0xFF2E5C8A), Color(0xFF9B4F6B), Color(0xFF3F8F7A), Color(0xFF7A5C2E),
    Color(0xFF5E5A9E), Color(0xFF8A6B3F), Color(0xFF4F6E8A), Color(0xFFA0533A),
  ];
}

Color urgencyColor(Urgency u) => switch (u) {
      Urgency.expired => const Color(0xFF8E2A2A),
      Urgency.red => Palette.red,
      Urgency.yellow => Palette.yellow,
      Urgency.green => Palette.green,
      Urgency.none => Palette.grey,
    };

const serif = 'Lora';
const sans = 'BeVietnamPro';

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final bg = dark ? Palette.night : Palette.paper;
  final surface = dark ? Palette.nightCard : Colors.white;
  final onBg = dark ? const Color(0xFFE9E4DA) : Palette.ink;
  final scheme = ColorScheme.fromSeed(seedColor: Palette.brass, brightness: b).copyWith(
    primary: dark ? Palette.brassLight : Palette.ink,
    onPrimary: dark ? Palette.night : Colors.white,
    secondary: Palette.brass,
    surface: surface,
    onSurface: onBg,
    surfaceContainerHighest: dark ? Palette.nightLine : Palette.paperDeep,
    outlineVariant: dark ? Palette.nightLine : const Color(0xFFDCD2BF),
  );
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: b, fontFamily: sans);
  final text = base.textTheme.apply(bodyColor: onBg, displayColor: onBg, fontFamily: sans);
  return base.copyWith(
    scaffoldBackgroundColor: bg,
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(fontFamily: serif, fontWeight: FontWeight.w600, letterSpacing: -.5),
      headlineMedium: text.headlineMedium?.copyWith(fontFamily: serif, fontWeight: FontWeight.w600, letterSpacing: -.3),
      headlineSmall: text.headlineSmall?.copyWith(fontFamily: serif, fontWeight: FontWeight.w600),
      titleLarge: text.titleLarge?.copyWith(fontFamily: serif, fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      labelSmall: text.labelSmall?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w600),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: onBg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: serif, fontSize: 22, fontWeight: FontWeight.w600, color: onBg),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18), side: BorderSide(color: scheme.outlineVariant)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: scheme.outlineVariant)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Palette.brass, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: surface,
      selectedColor: dark ? Palette.brass.withValues(alpha: .3) : Palette.ink,
      labelStyle: TextStyle(fontFamily: sans, color: onBg, fontSize: 13),
      secondaryLabelStyle: const TextStyle(fontFamily: sans, color: Colors.white, fontSize: 13),
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? Palette.nightCard : Colors.white,
      indicatorColor: Palette.brass.withValues(alpha: .22),
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStatePropertyAll(TextStyle(fontFamily: sans, fontSize: 12, color: onBg)),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Palette.brass,
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: dark ? Palette.brass : Palette.ink,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontFamily: sans, fontWeight: FontWeight.w600, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        foregroundColor: onBg,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    listTileTheme: ListTileThemeData(iconColor: dark ? Palette.brassLight : Palette.inkSoft),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, surfaceTintColor: Colors.transparent),
  );
}
