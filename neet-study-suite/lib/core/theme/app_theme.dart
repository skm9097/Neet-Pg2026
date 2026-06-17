import 'package:flutter/material.dart';

/// Warm Clinical design system — earthy, calm, medical-pro.
/// Cream base, deep forest green primary, terracotta energy, gold accents.
///
/// Colours are **brightness-aware**: the neutral and accent tokens are getters
/// that resolve against [_brightness], which the app root sets each build pass
/// (see `main.dart`). This lets the whole app — which references `AppTheme.*`
/// statics directly — switch between light and dark without touching screens.
class AppTheme {
  AppTheme._();

  // ---- Active brightness ----------------------------------------------------
  static Brightness _brightness = Brightness.light;
  static bool get isDark => _brightness == Brightness.dark;
  static void setBrightness(Brightness b) => _brightness = b;

  /// Call at the top of any screen's build() to keep the static in sync with
  /// the current widget-tree theme (handles dark/light correctly on every rebuild).
  static void syncFrom(BuildContext context) =>
      setBrightness(Theme.of(context).brightness);

  static Color _pick(Color light, Color dark) => isDark ? dark : light;

  // ---- Brand accents --------------------------------------------------------
  // Lightened on dark so they read against the dark surface and tinted chips.
  static Color get primary => _pick(const Color(0xFF2F5D50), const Color(0xFF5FA68F));
  static const Color primaryLight = Color(0xFFE3EEE9);
  static Color get primaryDark => _pick(const Color(0xFF244A40), const Color(0xFF3A7A68));
  static Color get secondary => _pick(const Color(0xFFE07A5F), const Color(0xFFEC8E76));
  static Color get accent => _pick(const Color(0xFFD9B36A), const Color(0xFFE3C485));
  static Color get lavender => _pick(const Color(0xFF5E8B9E), const Color(0xFF7FA8B8));
  static Color get mint => greenSoft;
  static Color get skyBlue => lavender;
  static Color get rose => _pick(const Color(0xFFD4644A), const Color(0xFFE08066));

  // Gold used as an icon foreground (flashcards) — kept distinct for contrast.
  static Color get gold => _pick(const Color(0xFFB98A2E), const Color(0xFFE3C485));

  // ---- Tinted surfaces (feature backgrounds) --------------------------------
  static Color get greenSoft => _pick(const Color(0xFFE3EEE9), const Color(0xFF1F3A30));
  static Color get greenTint => _pick(const Color(0xFFEDF4F0), const Color(0xFF1B3128));
  static Color get terraSoft => _pick(const Color(0xFFFBE9E1), const Color(0xFF3A2620));
  static Color get goldSoft => _pick(const Color(0xFFF6EEDB), const Color(0xFF34301E));
  static Color get blueSoft => _pick(const Color(0xFFE6EFF2), const Color(0xFF1E2F35));
  static Color get plumSoft => _pick(const Color(0xFFF1E7EE), const Color(0xFF2F2330));

  // ---- Semantic -------------------------------------------------------------
  static Color get correct => _pick(const Color(0xFF3FB89A), const Color(0xFF52C9AB));
  static Color get incorrect => _pick(const Color(0xFFEF8A8A), const Color(0xFFF09A9A));
  static Color get warning => _pick(const Color(0xFFF5C26B), const Color(0xFFF7CE85));

  // ---- Surfaces & neutrals --------------------------------------------------
  static Color get surface => _pick(const Color(0xFFFAF7F2), const Color(0xFF121B18));
  static Color get surfaceAlt => _pick(const Color(0xFFFFFBF7), const Color(0xFF16211C));
  static Color get cardBg => _pick(Colors.white, const Color(0xFF1B2723));
  static Color get ink => _pick(const Color(0xFF16241F), const Color(0xFFECF1EE));
  static Color get inkSoft => _pick(const Color(0xFF3A4742), const Color(0xFFB7C3BD));
  static Color get inkFaint => _pick(const Color(0xFF7B8A83), const Color(0xFF84938C));
  static Color get line => _pick(const Color(0xFFECE5D9), const Color(0xFF2B3A34));
  static Color get lineSoft => _pick(const Color(0xFFF2ECE2), const Color(0xFF233029));

  // ---- Gradients ------------------------------------------------------------
  // Colored hero/button backgrounds — carry white foreground in both modes.
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

  // ---- Shadows --------------------------------------------------------------
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.07),
      blurRadius: 30,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> coloredShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: isDark ? 0.34 : 0.28),
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
  /// Builds the [ThemeData] for [b]. Sets [_brightness] first so the token
  /// getters resolve to the matching palette while the theme is assembled.
  static ThemeData themeFor(Brightness b) {
    setBrightness(b);
    final base = ThemeData(
      useMaterial3: true,
      brightness: b,
      fontFamily: 'Roboto',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: b,
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
          side: BorderSide(color: line, width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
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
        labelStyle: TextStyle(color: primary, fontSize: 12, fontWeight: FontWeight.w600),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: radiusMd, borderSide: BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: line, width: 1)),
        focusedBorder: OutlineInputBorder(
          borderRadius: radiusMd,
          borderSide: BorderSide(color: primary, width: 1.8)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cardBg,
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
        headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: ink, letterSpacing: -0.8),
        headlineSmall: TextStyle(fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.5),
        titleLarge: TextStyle(fontWeight: FontWeight.w700, color: ink, letterSpacing: -0.3),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: ink),
        bodyLarge: TextStyle(height: 1.55, color: ink),
        bodyMedium: TextStyle(height: 1.55, color: inkSoft),
      ).apply(bodyColor: ink, displayColor: ink),
      dividerTheme: DividerThemeData(
        color: line, thickness: 1, space: 1),
    );
  }

  /// Light theme (kept for any callers that referenced it directly).
  static ThemeData get light => themeFor(Brightness.light);
  static ThemeData get dark => themeFor(Brightness.dark);
}
