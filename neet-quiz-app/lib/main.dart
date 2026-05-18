import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/gemini_service.dart';
import 'services/tts_service.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final savedKey = prefs.getString('gemini_api_key') ?? '';

  final gemini = GeminiService();
  if (savedKey.isNotEmpty) gemini.setApiKey(savedKey);

  final tts = TtsService();
  await tts.init();

  runApp(NeetQuizApp(gemini: gemini, tts: tts));
}

class NeetQuizApp extends StatelessWidget {
  final GeminiService gemini;
  final TtsService tts;

  const NeetQuizApp({super.key, required this.gemini, required this.tts});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEET-PG Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          secondary: Color(0xFF06B6D4),
          surface: Color(0xFF1A1A2E),
          error: Color(0xFFEF4444),
        ),
        scaffoldBackgroundColor: const Color(0xFF0D0D1A),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: HomeScreen(gemini: gemini, tts: tts),
    );
  }
}
