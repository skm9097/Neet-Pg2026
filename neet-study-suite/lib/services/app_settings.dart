import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, persisted user preferences — profile name, exam countdown target,
/// daily question goal, and theme mode. A [ChangeNotifier] singleton so any
/// widget can listen and rebuild when the user edits settings.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings instance = AppSettings._();

  String userName = '';
  String examName = 'NEET PG 2026';
  DateTime examDate = DateTime(2026, 11, 1);
  int dailyGoal = 30;
  ThemeMode themeMode = ThemeMode.system;

  static const _kName = 'profile_name';
  static const _kExamName = 'exam_name';
  static const _kExamDate = 'exam_date';
  static const _kGoal = 'daily_goal';
  static const _kTheme = 'theme_mode';

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    userName = p.getString(_kName) ?? '';
    examName = p.getString(_kExamName) ?? 'NEET PG 2026';
    final d = p.getString(_kExamDate);
    if (d != null) examDate = DateTime.tryParse(d) ?? examDate;
    dailyGoal = p.getInt(_kGoal) ?? 30;
    themeMode = _parseTheme(p.getString(_kTheme));
    notifyListeners();
  }

  ThemeMode _parseTheme(String? s) {
    switch (s) {
      case 'light': return ThemeMode.light;
      case 'dark': return ThemeMode.dark;
      default: return ThemeMode.system;
    }
  }

  Future<void> setName(String v) async {
    userName = v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kName, userName);
    notifyListeners();
  }

  Future<void> setExamName(String v) async {
    examName = v.trim().isEmpty ? 'NEET PG 2026' : v.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kExamName, examName);
    notifyListeners();
  }

  Future<void> setExamDate(DateTime v) async {
    examDate = v;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kExamDate, v.toIso8601String());
    notifyListeners();
  }

  Future<void> setDailyGoal(int v) async {
    dailyGoal = v.clamp(5, 500);
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kGoal, dailyGoal);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, m.name);
    notifyListeners();
  }

  /// Greeting prefixed by time of day, suffixed with the user's name if set.
  String greeting() {
    final h = DateTime.now().hour;
    final base = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return userName.isEmpty ? base : '$base, $userName';
  }
}
