import 'package:flutter/material.dart';

/// Warm Clinical design system — earthy, calm, medical-pro.
/// Cream base, deep forest green primary, terracotta energy, gold accents.
class AppTheme {
  // ---- Core palette (Warm Clinical) -----------------------------------------
  static const Color primary = Color(0xFF2F5D50);       // deep forest green
  static const Color primaryLight = Color(0xFFE3EEE9);  // soft green tint
  static const Color primaryDark = Color(0xFF244A40);    // deeper green
  static const Color secondary = Color(0xFFE07A5F);     // terracotta
  static const Color accent = Color(0xFFD9B36A);        // warm gold
  static const Color lavender = Color(0xFF5E8B9E);      // blue-grey (tutor)
  static const Color mint = Color(0xFFE3EEE9);          // green tint
  static const Color skyBlue = Color(0xFF5E8B9E);       // blue-grey
  static const Color rose = Color(0xFFD4644A);          // deep terracotta

  // ---- Tinted surfaces (feature backgrounds) --------------------------------
  static const Color greenSoft = Color(0xFFE3EEE9);
  static const Color greenTint = Color(0xFFEDF4F0);
  static const Color terraSoft = Color(0xFFFBE9E1);
  static const Color goldSoft = Color(0xFFF6EEDB);
  static const Color blueSoft = Color(0xFFE6EFF2);
  static const Color plumSoft = Color(0xFFF1E7EE);

  // ---- Semantic -------------------------------------------------------------
  static const Color correct = Color(0xFF3FB89A);       // calm green-teal
  static const Color incorrect = Color(0xFFEF8A8A);     // soft coral
  static const Color warning = Color(0xFFF5C26B);       // gentle amber

  // ---- Surfaces & neutrals --------------------------------------------------
  static const Color surface = Color(0xFFFAF7F2);       // warm cream
  static const Color surfaceAlt = Color(0xFFFFFBF7);
  static const Color cardBg = Colors.white;
  static const Color ink = Color(0xFF16241F);            // near-black (warm)
  static const Color inkSoft = Color(0xFF3A4742);        // body text
  static const Color inkFaint = Color(0xFF7B8A83);       // muted text
  static const Color line = Color(0xFFECE5D9);           // card borders
  static const Color lineSoft = Color(0xFFF2ECE2);       // soft dividers

  // ---- Gradients ------------------------------------------------------------
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2F5D50), Color(0xFF244A40)],
  );
  static const LinearGradient qbankGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2F5D50), Color(0xFF3A7A68)],
  );
  static const LinearGradient flashcardGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFD9B36A), Color(0xFFC49B4E)],
  );
  static const LinearGradient mockGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFE07A5F), Color(0xFFD4644A)],
  );
  static const LinearGradient tutorGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF5E8B9E), Color(0xFF4A7588)],
  );
  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF2F5D50), Color(0xFF5E8B9E)],
  );

  static LinearGradient gradientFor(int index) {
    const all = [qbankGradient, flashcardGradient, mockGradient, tutorGradient];
    return all[index % all.length];
  }

  // ---- Shadows (earthy) -----------------------------------------------------
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF142821).withValues(alpha: 0.07),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF142821).withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF142821).withValues(alpha: 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> coloredShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ---- Radii ----------------------------------------------------------------
  static const double rSm = 14;
  static const double rMd = 20;
  static const double rLg = 24;
  static const double rXl = 36;

  static BorderRadius get radiusSm => BorderRadius.circular(rSm);
  static BorderRadius get radiusMd => BorderRadius.circular(rMd);
  static BorderRadius get radiusLg => BorderRadius.circular(rLg);
  static BorderRadius get radiusXl => BorderRadius.circular(rXl);

  // ---- ThemeData ------------------------------------------------------------
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: incorrect,
      ),
      scaffoldBackgroundColor: surface,
    );

    return base.copyWith(
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: radiusLg,
          side: const BorderSide(color: line, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide(color: primary.withValues(alpha: 0.3), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: radiusMd),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withValues(alpha: 0.08),
        labelStyle: const TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: radiusMd, borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: line, width: 1)),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: const BorderSide(color: primary, width: 1.8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: 72,
        indicatorColor: primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w600,
          color: states.contains(WidgetState.selected) ? primary : inkFaint,
        )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
          color: states.contains(WidgetState.selected) ? primary : inkFaint,
          size: 24,
        )),
      ),
      textTheme: base.textTheme.copyWith(
        headlineMedium: const TextStyle(fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.8),
        headlineSmall: const TextStyle(fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.5),
        titleLarge: const TextStyle(fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.3),
        titleMedium: const TextStyle(fontWeight: FontWeight.w600, color: ink),
        bodyLarge: const TextStyle(height: 1.55, color: ink),
        bodyMedium: const TextStyle(height: 1.55, color: inkSoft),
      ).apply(bodyColor: ink, displayColor: ink),
      dividerTheme: const DividerThemeData(
        color: line, thickness: 1, space: 1),
    );
  }
}
