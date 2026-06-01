import 'package:flutter/material.dart';

/// Calming, fluid, human-centered design system for the NEET-PG Study Suite.
/// Muted blues, teals, lavenders, mint, soft peach, warm neutrals.
class AppTheme {
  // ---- Core palette -------------------------------------------------------
  static const Color primary = Color(0xFF6C7DF0);       // soft periwinkle-blue
  static const Color primaryLight = Color(0xFF8B9AF5);
  static const Color primaryDark = Color(0xFF4A5BD4);
  static const Color secondary = Color(0xFF4FC4B8);     // soft teal
  static const Color accent = Color(0xFFFFB088);        // warm peach
  static const Color lavender = Color(0xFFB3A4E8);
  static const Color mint = Color(0xFF8FE3C2);
  static const Color skyBlue = Color(0xFF7FC4F0);
  static const Color rose = Color(0xFFF5A3B5);

  // ---- Semantic -----------------------------------------------------------
  static const Color correct = Color(0xFF3FB89A);       // calm green-teal
  static const Color incorrect = Color(0xFFEF8A8A);     // soft coral (not harsh red)
  static const Color warning = Color(0xFFF5C26B);       // gentle amber

  // ---- Surfaces & neutrals ------------------------------------------------
  static const Color surface = Color(0xFFF6F5FB);       // warm lavender-tinted white
  static const Color surfaceAlt = Color(0xFFFBFAFD);
  static const Color cardBg = Colors.white;
  static const Color ink = Color(0xFF2B2D42);           // soft near-black for text
  static const Color inkSoft = Color(0xFF6B6E8A);       // muted text
  static const Color inkFaint = Color(0xFFA9ABC4);

  // ---- Gradients ----------------------------------------------------------
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6C7DF0), Color(0xFF8B6CF0), Color(0xFF6CB8F0)],
  );

  static const LinearGradient qbankGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF6C7DF0), Color(0xFF7FA8F5)],
  );
  static const LinearGradient flashcardGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF4FC4B8), Color(0xFF8FE3C2)],
  );
  static const LinearGradient mockGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFFFB088), Color(0xFFF5A3B5)],
  );
  static const LinearGradient tutorGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFFB3A4E8), Color(0xFF8B9AF5)],
  );
  static const LinearGradient mintGradient = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF8FE3C2), Color(0xFF7FC4F0)],
  );

  static LinearGradient gradientFor(int index) {
    const all = [qbankGradient, flashcardGradient, mockGradient, tutorGradient];
    return all[index % all.length];
  }

  // ---- Shadows ------------------------------------------------------------
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF6C7DF0).withValues(alpha: 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF2B2D42).withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> coloredShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.28),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  // ---- Radii --------------------------------------------------------------
  static const double rSm = 14;
  static const double rMd = 20;
  static const double rLg = 28;
  static const double rXl = 36;

  static BorderRadius get radiusSm => BorderRadius.circular(rSm);
  static BorderRadius get radiusMd => BorderRadius.circular(rMd);
  static BorderRadius get radiusLg => BorderRadius.circular(rLg);
  static BorderRadius get radiusXl => BorderRadius.circular(rXl);

  // ---- ThemeData ----------------------------------------------------------
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
        shape: RoundedRectangleBorder(borderRadius: radiusLg),
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
          borderRadius: radiusMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: primary.withValues(alpha: 0.12), width: 1.2)),
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
          fontWeight: FontWeight.w600,
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
      dividerTheme: DividerThemeData(
        color: primary.withValues(alpha: 0.08), thickness: 1, space: 1),
    );
  }
}
