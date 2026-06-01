import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TtsService {
  static const String _prefKey = 'tts_enabled';

  final FlutterTts _tts = FlutterTts();
  bool _enabled = true;
  bool _initialized = false;

  bool get isEnabled => _enabled;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_prefKey) ?? true;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  Future<void> speak(String text) async {
    if (!_enabled) return;
    await stop();
    await _tts.speak(text);
  }

  Future<void> stop() async => _tts.stop();

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
}
