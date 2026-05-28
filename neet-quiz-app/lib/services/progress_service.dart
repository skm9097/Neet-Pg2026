import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProgressEntry {
  final String source;
  final int attempted;
  final int correct;
  final DateTime lastDate;

  const ProgressEntry({
    required this.source,
    required this.attempted,
    required this.correct,
    required this.lastDate,
  });

  int get wrong => attempted - correct;
  double get accuracy => attempted > 0 ? correct / attempted : 0;
  int get neetScore => (correct * 4) - wrong;

  Map<String, dynamic> toJson() => {
        'attempted': attempted,
        'correct': correct,
        'lastDate': lastDate.toIso8601String(),
      };

  factory ProgressEntry.fromJson(String source, Map<String, dynamic> json) =>
      ProgressEntry(
        source: source,
        attempted: json['attempted'] as int,
        correct: json['correct'] as int,
        lastDate: DateTime.parse(json['lastDate'] as String),
      );
}

class ProgressService {
  static const String _prefix = 'progress_';

  static String _key(String source) => '$_prefix$source';

  static Future<void> record(String source, int attempted, int correct) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(source);
    final existing = prefs.getString(key);
    int totalAttempted = attempted;
    int totalCorrect = correct;
    if (existing != null) {
      final prev = jsonDecode(existing) as Map<String, dynamic>;
      totalAttempted += prev['attempted'] as int;
      totalCorrect += prev['correct'] as int;
    }
    await prefs.setString(
      key,
      jsonEncode({
        'attempted': totalAttempted,
        'correct': totalCorrect,
        'lastDate': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<List<ProgressEntry>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = <ProgressEntry>[];
    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_prefix)) continue;
      final raw = prefs.getString(key);
      if (raw == null) continue;
      try {
        final source = key.substring(_prefix.length);
        final json = jsonDecode(raw) as Map<String, dynamic>;
        entries.add(ProgressEntry.fromJson(source, json));
      } catch (_) {
        continue;
      }
    }
    entries.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return entries;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
