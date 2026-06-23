import 'dart:async';
import 'package:flutter/material.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'services/app_settings.dart';
import 'services/github_sync_service.dart';
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
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _settings.addListener(_onSettingsChanged);
    // Auto-flush offline mistake queue every 5 minutes while app is open.
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      GithubSyncService.flushOfflineQueue(widget.gemini);
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() => setState(() {});

  // Rebuild when the OS light/dark setting flips (matters for ThemeMode.system).
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEET-PG Study Suite',
      theme: AppTheme.themeFor(Brightness.light),
      darkTheme: AppTheme.themeFor(Brightness.dark),
      themeMode: _settings.themeMode,
      debugShowCheckedModeBanner: false,
      home: HomeScreen(gemini: widget.gemini, tts: widget.tts),
    );
  }
}
