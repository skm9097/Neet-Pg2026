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

/// One calendar day of practice activity.
class DailyStat {
  final DateTime day; // normalised to midnight, local
  final int solved;
  final int correct;
  final int timeSec;

  const DailyStat({
    required this.day,
    this.solved = 0,
    this.correct = 0,
    this.timeSec = 0,
  });

  double get accuracy => solved > 0 ? correct / solved * 100 : 0;
  bool get isActive => solved > 0;

  String get timeLabel {
    final m = timeSec ~/ 60;
    if (m >= 60) return '${m ~/ 60}h ${m % 60}m';
    return '${m}m';
  }
}

class ProgressService {
  static const String _prefix = 'progress_';
  static const String _dailyKey = 'daily_stats';

  /// Records a completed session against its [source] (year/subject/mock) and
  /// also logs it against today's [DailyStat] for the streak graph.
  static Future<void> record(
    String source,
    int attempted,
    int correct, {
    Duration? timeSpent,
  }) async {
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
    // Estimate ~40s per question when an explicit duration isn't supplied.
    final secs = timeSpent?.inSeconds ?? attempted * 40;
    await _recordDaily(prefs, attempted, correct, secs);
  }

  static Future<void> _recordDaily(
    SharedPreferences prefs, int solved, int correct, int secs) async {
    final map = _loadDailyMap(prefs);
    final key = _dayKey(DateTime.now());
    final cur = map[key] ?? {'solved': 0, 'correct': 0, 'timeSec': 0};
    map[key] = {
      'solved': (cur['solved'] as int) + solved,
      'correct': (cur['correct'] as int) + correct,
      'timeSec': (cur['timeSec'] as int) + secs,
    };
    await prefs.setString(_dailyKey, jsonEncode(map));
  }

  static Map<String, dynamic> _loadDailyMap(SharedPreferences prefs) {
    final raw = prefs.getString(_dailyKey);
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>);
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime _midnight(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Returns the 7 [DailyStat]s for a week. [weekOffset] 0 = current week
  /// (Mon–Sun), -1 = previous week, etc.
  static Future<List<DailyStat>> weekStats(int weekOffset) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadDailyMap(prefs);
    final now = _midnight(DateTime.now());
    // Monday of the target week.
    final monday = now
        .subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: weekOffset * 7));
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final entry = map[_dayKey(day)];
      if (entry == null) return DailyStat(day: day);
      return DailyStat(
        day: day,
        solved: entry['solved'] as int? ?? 0,
        correct: entry['correct'] as int? ?? 0,
        timeSec: entry['timeSec'] as int? ?? 0,
      );
    });
  }

  /// Consecutive days (ending today or yesterday) with at least one solved Q.
  static Future<int> currentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadDailyMap(prefs);
    if (map.isEmpty) return 0;
    int streak = 0;
    var cursor = _midnight(DateTime.now());
    // Allow the streak to count even if today hasn't been used yet.
    final todayActive = (map[_dayKey(cursor)]?['solved'] as int? ?? 0) > 0;
    if (!todayActive) cursor = cursor.subtract(const Duration(days: 1));
    while ((map[_dayKey(cursor)]?['solved'] as int? ?? 0) > 0) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Questions solved today (for the daily-goal ring).
  static Future<int> solvedToday() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadDailyMap(prefs);
    return map[_dayKey(DateTime.now())]?['solved'] as int? ?? 0;
  }

  /// True when the earliest logged week is at/after the given offset, so the
  /// graph can stop the user swiping into empty weeks.
  static Future<bool> hasDataBefore(int weekOffset) async {
    final prefs = await SharedPreferences.getInstance();
    final map = _loadDailyMap(prefs);
    if (map.isEmpty) return false;
    final now = _midnight(DateTime.now());
    final mondayOfWeek = now
        .subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: weekOffset * 7));
    for (final k in map.keys) {
      final parts = k.split('-').map(int.parse).toList();
      final d = DateTime(parts[0], parts[1], parts[2]);
      if (d.isBefore(mondayOfWeek)) return true;
    }
    return false;
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
    final keys = prefs.getKeys()
        .where((k) => k.startsWith(_prefix) || k == _dailyKey)
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }
}
