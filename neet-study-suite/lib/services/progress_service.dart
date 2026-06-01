import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressEntry {
  final String source;
  final int attempted;
  final int correct;

  const ProgressEntry({
    required this.source,
    required this.attempted,
    required this.correct,
  });

  double get accuracy => attempted > 0 ? correct / attempted * 100 : 0;
  int get neetScore => correct * 4 - (attempted - correct);
}

class ProgressService {
  static const String _prefix = 'progress_';

  static Future<void> record(String source, int attempted, int correct) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefix$source';
    final existing = prefs.getString(key);
    if (existing != null) {
      final data = jsonDecode(existing) as Map<String, dynamic>;
      await prefs.setString(key, jsonEncode({
        'attempted': (data['attempted'] as int) + attempted,
        'correct': (data['correct'] as int) + correct,
      }));
    } else {
      await prefs.setString(key, jsonEncode({'attempted': attempted, 'correct': correct}));
    }
  }

  static Future<List<ProgressEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <ProgressEntry>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final data = jsonDecode(prefs.getString(key)!) as Map<String, dynamic>;
      entries.add(ProgressEntry(
        source: key.substring(_prefix.length),
        attempted: data['attempted'] as int,
        correct: data['correct'] as int,
      ));
    }
    entries.sort((a, b) => b.attempted.compareTo(a.attempted));
    return entries;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) await prefs.remove(k);
  }
}
