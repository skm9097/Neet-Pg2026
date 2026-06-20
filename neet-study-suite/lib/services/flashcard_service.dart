import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard.dart';

class FlashcardService {
  static const String _key = 'flashcards';

  static Future<List<Flashcard>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => _fromMap(e as Map<String, dynamic>)).toList();
  }

  static Future<void> save(List<Flashcard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(cards.map(_toMap).toList()));
  }

  static Future<void> addCards(List<Flashcard> newCards) async {
    final existing = await loadAll();
    final ids = existing.map((c) => c.id).toSet();
    final toAdd = newCards.where((c) => !ids.contains(c.id)).toList();
    await save([...existing, ...toAdd]);
  }

  static Future<void> updateCard(Flashcard updated) async {
    final cards = await loadAll();
    final idx = cards.indexWhere((c) => c.id == updated.id);
    if (idx >= 0) {
      cards[idx] = updated;
      await save(cards);
    }
  }

  static Future<void> deleteCard(String id) async {
    final cards = await loadAll();
    cards.removeWhere((c) => c.id == id);
    await save(cards);
  }

  /// Bulk-delete cards by id (used by multi-select).
  static Future<void> deleteCards(Iterable<String> ids) async {
    final set = ids.toSet();
    final cards = await loadAll();
    cards.removeWhere((c) => set.contains(c.id));
    await save(cards);
  }

  /// Delete whole decks — every card whose subject is in [subjects].
  static Future<void> deleteBySubjects(Set<String> subjects) async {
    final cards = await loadAll();
    cards.removeWhere((c) => subjects.contains(c.subject));
    await save(cards);
  }

  /// Cards grouped by subject ("deck"), each list newest first.
  static Future<Map<String, List<Flashcard>>> loadDecks() async {
    final all = await loadAll();
    final decks = <String, List<Flashcard>>{};
    for (final c in all) {
      decks.putIfAbsent(c.subject, () => []).add(c);
    }
    return decks;
  }

  static Future<List<Flashcard>> getDueCards() async {
    final all = await loadAll();
    return all.where((c) => c.isDue).toList()
      ..sort((a, b) {
        if (a.nextReviewDate == null) return -1;
        if (b.nextReviewDate == null) return 1;
        return a.nextReviewDate!.compareTo(b.nextReviewDate!);
      });
  }

  static Future<Map<String, int>> getStatsBySubject() async {
    final all = await loadAll();
    final Map<String, int> stats = {};
    for (final c in all) {
      stats[c.subject] = (stats[c.subject] ?? 0) + 1;
    }
    return stats;
  }

  static Map<String, dynamic> _toMap(Flashcard c) => {
    'id': c.id,
    'front': c.front,
    'back': c.back,
    'subject': c.subject,
    'sourceQuestionId': c.sourceQuestionId,
    'easeFactor': c.easeFactor,
    'interval': c.interval,
    'repetitions': c.repetitions,
    'nextReviewDate': c.nextReviewDate?.toIso8601String(),
    'createdAt': c.createdAt.toIso8601String(),
  };

  static Flashcard _fromMap(Map<String, dynamic> m) => Flashcard(
    id: m['id'] as String,
    front: m['front'] as String,
    back: m['back'] as String,
    subject: m['subject'] as String,
    sourceQuestionId: m['sourceQuestionId'] as String?,
    easeFactor: (m['easeFactor'] as num).toDouble(),
    interval: m['interval'] as int,
    repetitions: m['repetitions'] as int,
    nextReviewDate: m['nextReviewDate'] != null
        ? DateTime.parse(m['nextReviewDate'] as String) : null,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}
