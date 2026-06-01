import 'package:flutter/material.dart';

class AppTheme {
  static const Color primary = Color(0xFF1565C0);       // deep blue
  static const Color primaryLight = Color(0xFF1E88E5);
  static const Color secondary = Color(0xFF00897B);     // teal
  static const Color accent = Color(0xFFFF6F00);        // amber
  static const Color correct = Color(0xFF2E7D32);
  static const Color incorrect = Color(0xFFC62828);
  static const Color surface = Color(0xFFF5F7FA);
  static const Color cardBg = Colors.white;

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: primary,
      secondary: secondary,
      surface: surface,
    ),
    scaffoldBackgroundColor: surface,
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.blue[50]!,
      labelStyle: const TextStyle(color: primary, fontSize: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
      titleLarge: TextStyle(fontWeight: FontWeight.w600),
      titleMedium: TextStyle(fontWeight: FontWeight.w500),
      bodyMedium: TextStyle(height: 1.5),
    ),
    useMaterial3: true,
  );
}
