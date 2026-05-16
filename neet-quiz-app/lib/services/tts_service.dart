import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;

  bool get isSpeaking => _speaking;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.47);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    await stop();
    final cleaned = text
        .replaceAll(RegExp(r'\*(image-based)\*'), 'image-based question')
        .replaceAll('*', '')
        .replaceAll('#', '');
    await _tts.speak(cleaned);
  }

  Future<void> stop() async {
    _speaking = false;
    await _tts.stop();
  }

  void dispose() {
    _tts.stop();
  }
}
