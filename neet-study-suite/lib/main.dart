import 'package:flutter/material.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'features/home/home_screen.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final gemini = GeminiService();
  final tts = TtsService();

  await gemini.restoreFromPrefs();
  await tts.init();

  runApp(NeetStudySuiteApp(gemini: gemini, tts: tts));
}

class NeetStudySuiteApp extends StatelessWidget {
  final GeminiService gemini;
  final TtsService tts;
  const NeetStudySuiteApp({super.key, required this.gemini, required this.tts});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEET-PG Study Suite',
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: HomeScreen(gemini: gemini, tts: tts),
    );
  }
}
