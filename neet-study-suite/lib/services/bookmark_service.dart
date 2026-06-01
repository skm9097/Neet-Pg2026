import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bookmark.dart';
import '../models/question.dart';

class BookmarkService {
  static const String _key = 'bookmarks';

  static Future<List<Bookmark>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<void> add(Question q, {String? note}) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await loadAll();
    if (bookmarks.any((b) => b.questionId == q.id)) return;

    bookmarks.add(Bookmark(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      questionId: q.id,
      questionStem: q.stem,
      subject: q.subject,
      note: note,
      createdAt: DateTime.now(),
    ));
    await prefs.setString(_key, jsonEncode(bookmarks.map(_toMap).toList()));
  }

  static Future<void> remove(String questionId) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await loadAll();
    bookmarks.removeWhere((b) => b.questionId == questionId);
    await prefs.setString(_key, jsonEncode(bookmarks.map(_toMap).toList()));
  }

  static Future<bool> isBookmarked(String questionId) async {
    final bookmarks = await loadAll();
    return bookmarks.any((b) => b.questionId == questionId);
  }

  static Future<void> updateNote(String questionId, String note) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = await loadAll();
    final idx = bookmarks.indexWhere((b) => b.questionId == questionId);
    if (idx >= 0) {
      bookmarks[idx] = bookmarks[idx].copyWith(note: note);
      await prefs.setString(_key, jsonEncode(bookmarks.map(_toMap).toList()));
    }
  }

  static Map<String, dynamic> _toMap(Bookmark b) => {
    'id': b.id,
    'questionId': b.questionId,
    'questionStem': b.questionStem,
    'subject': b.subject,
    'note': b.note,
    'createdAt': b.createdAt.toIso8601String(),
  };

  static Bookmark _fromMap(Map<String, dynamic> m) => Bookmark(
    id: m['id'] as String,
    questionId: m['questionId'] as String,
    questionStem: m['questionStem'] as String,
    subject: m['subject'] as String,
    note: m['note'] as String?,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}
