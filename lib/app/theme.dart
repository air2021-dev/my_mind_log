import 'package:flutter/material.dart';

ThemeData buildWarmTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: null, // 추후 폰트 넣을 거면 여기
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      )
    )
  );
}