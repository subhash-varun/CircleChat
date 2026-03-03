import 'package:flutter/material.dart';

class JjTheme {
  static const Color deep = Color(0xFF0F1115);
  static const Color surface = Color(0xFF1A1D23);
  static const Color surfaceHover = Color(0xFF242833);
  static const Color accent = Color(0xFF4C6EF5);
  static const Color accentSoft = Color(0x334C6EF5);
  static const Color secure = Color(0xFFE03131);
  static const Color text = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFADB5BD);
  static const Color textMuted = Color(0xFF868E96);
  static const Color border = Color(0xFF2A2E37);

  static ThemeData get theme {
    final scheme = const ColorScheme.dark(
      primary: accent,
      onPrimary: text,
      secondary: surfaceHover,
      onSecondary: textSecondary,
      surface: surface,
      onSurface: text,
      error: secure,
      onError: text,
      outline: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: deep,
      colorScheme: scheme,
      dividerColor: border,
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textMuted),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: text,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHover,
        contentTextStyle: const TextStyle(color: text),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
      ),
    );
  }
}
