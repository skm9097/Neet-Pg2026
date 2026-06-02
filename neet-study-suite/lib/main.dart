import 'package:flutter/material.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'services/app_settings.dart';
import 'features/home/home_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final gemini = GeminiService();
  final tts = TtsService();

  await gemini.restoreFromPrefs();
  await tts.init();
  await AppSettings.instance.load();

  runApp(NeetStudySuiteApp(gemini: gemini, tts: tts));
}

class NeetStudySuiteApp extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;
  const NeetStudySuiteApp({super.key, required this.gemini, required this.tts});

  @override
  State<NeetStudySuiteApp> createState() => _NeetStudySuiteAppState();
}

class _NeetStudySuiteAppState extends State<NeetStudySuiteApp>
    with WidgetsBindingObserver {
  final _settings = AppSettings.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  // Rebuild when the OS light/dark setting flips (matters for ThemeMode.system).
  @override
  void didChangePlatformBrightness() => setState(() {});

  Brightness _effectiveBrightness() {
    switch (_settings.themeMode) {
      case ThemeMode.light: return Brightness.light;
      case ThemeMode.dark: return Brightness.dark;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness;
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _effectiveBrightness();
    // Resolve AppTheme statics to the active palette before building.
    AppTheme.setBrightness(brightness);

    return MaterialApp(
      title: 'NEET-PG Study Suite',
      theme: AppTheme.themeFor(brightness),
      debugShowCheckedModeBanner: false,
      home: HomeScreen(gemini: widget.gemini, tts: widget.tts),
    );
  }
}
