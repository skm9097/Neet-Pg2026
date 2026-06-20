import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _speaking = false;
  bool _enabled = true;

  static const String _prefKey = 'tts_enabled';

  bool get isSpeaking => _speaking;
  bool get enabled => _enabled;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.47);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.05);
    _tts.setStartHandler(() => _speaking = true);
    _tts.setCompletionHandler(() => _speaking = false);
    _tts.setCancelHandler(() => _speaking = false);

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;

    _initialized = true;
  }

  /// Toggle voice mode on/off. Persists the choice and stops any
  /// in-progress speech when turning off.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (!value) await stop();
  }

  Future<bool> toggle() async {
    await setEnabled(!_enabled);
    return _enabled;
  }

  Future<void> speak(String text) async {
    if (!_enabled) return;
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
