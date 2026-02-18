import 'package:flutter/material.dart';

/// Warm + minimal theme tuned for a journal app.
///
/// Notes:
/// - Uses a warm seed color for consistent accents.
/// - Keeps surfaces soft and comfortably rounded.
/// - "Glass" feel is achieved via semi-transparent surfaces + subtle borders.
///   (Actual blur should be done with BackdropFilter in specific widgets.)
ThemeData buildWarmTheme() {
  const seed = Color(0xFFFF9F43); // warm orange
  const bg = Color(0xFFFDFCFB); // creamy white

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ),
  );

  final radius = BorderRadius.circular(18);

  return base.copyWith(
    scaffoldBackgroundColor: bg,

    textTheme: base.textTheme.apply(
      fontFamily: null, // 추후 폰트 넣을 거면 여기
      bodyColor: const Color(0xFF1F2937),
      displayColor: const Color(0xFF111827),
    ),

    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
      iconTheme: IconThemeData(color: Color(0xFF111827)),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: const Color(0xFFFFF8F1).withAlpha((255 * 0.88).toInt()),
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: Colors.white.withAlpha((255 * 0.25).toInt())),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white.withOpacity(0.88),
      shape: RoundedRectangleBorder(borderRadius: radius),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: Color(0xFF111827),
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        height: 1.35,
        color: Color(0xFF374151),
      ),
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white.withOpacity(0.94),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(
        fontSize: 14,
        color: Color(0xFF111827),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF111827).withOpacity(0.92),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFF8F1).withAlpha((255 * 0.82).toInt()),
      hintStyle: const TextStyle(color: Color(0xFF6B7280)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: Color(0x14000000)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: seed.withOpacity(0.35), width: 1.4),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: seed.withOpacity(0.35)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    chipTheme: base.chipTheme.copyWith(
      backgroundColor: const Color(0xFFFFF8F1).withAlpha((255 * 0.70).toInt()),
      selectedColor: seed.withOpacity(0.18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      labelStyle: const TextStyle(color: Color(0xFF111827)),
      secondaryLabelStyle: const TextStyle(color: Color(0xFF111827)),
    ),

    dividerTheme: const DividerThemeData(
      thickness: 1,
      color: Color(0x14000000),
      space: 24,
    ),
  );
}