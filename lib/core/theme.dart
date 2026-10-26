import 'package:flutter/material.dart';

/// Brand colours, shared with the web dashboard.
class Brand {
  static const teal = Color(0xFF0F5257);
  static const amber = Color(0xFFF2A541);
  static const danger = Color(0xFFC0392B);
  static const ok = Color(0xFF2E7D32);
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.teal,
    brightness: brightness,
    secondary: Brand.amber,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
    chipTheme: ChipThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}
