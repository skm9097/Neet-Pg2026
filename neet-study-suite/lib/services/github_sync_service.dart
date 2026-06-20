import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/question.dart';
import '../models/quiz_attempt.dart';
import 'gemini_service.dart';

// ─── Log entry ────────────────────────────────────────────────────────────────

class SyncLogEntry {
  final DateTime timestamp;
  final bool success;
  final String detail;
  final String action; // 'push' | 'queue' | 'error' | 'session'

  const SyncLogEntry({
    required this.timestamp,
    required this.success,
    required this.detail,
    required this.action,
  });

  Map<String, dynamic> toJson() => {
    'ts': timestamp.toIso8601String(),
    'success': success,
    'detail': detail,
    'action': action,
  };

  factory SyncLogEntry.fromJson(Map<String, dynamic> m) => SyncLogEntry(
    timestamp: DateTime.parse(m['ts'] as String),
    success: m['success'] as bool,
    detail: m['detail'] as String,
    action: (m['action'] as String?) ?? 'push',
  );
}

// ─── Private types ────────────────────────────────────────────────────────────

class _Enrichment {
  final String keyFact;
  final String whyWrong;
  final String errorType;
  final List<String> tags;
  const _Enrichment({
    required this.keyFact,
    required this.whyWrong,
    required this.errorType,
    required this.tags,
  });
}

class _PendingMistake {
  final String questionId;
  final String subject;
  final String stem;
  final String optionA, optionB, optionC, optionD;
  final String correctOption;
  final String wrongOption;
  final String explanation;
  final String sessionId;
  final String timestamp;

  const _PendingMistake({
    required this.questionId,
    required this.subject,
    required this.stem,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.wrongOption,
    required this.explanation,
    required this.sessionId,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'questionId': questionId, 'subject': subject, 'stem': stem,
    'optionA': optionA, 'optionB': optionB, 'optionC': optionC, 'optionD': optionD,
    'correctOption': correctOption, 'wrongOption': wrongOption,
    'explanation': explanation, 'sessionId': sessionId, 'timestamp': timestamp,
  };

  factory _PendingMistake.fromJson(Map<String, dynamic> m) => _PendingMistake(
    questionId: m['questionId'] as String,
    subject: m['subject'] as String,
    stem: m['stem'] as String,
    optionA: m['optionA'] as String,
    optionB: m['optionB'] as String,
    optionC: m['optionC'] as String,
    optionD: m['optionD'] as String,
    correctOption: m['correctOption'] as String,
    wrongOption: m['wrongOption'] as String,
    explanation: m['explanation'] as String,
    sessionId: m['sessionId'] as String,
    timestamp: m['timestamp'] as String,
  );

  String optionText(String opt) {
    switch (opt) {
      case 'A': return optionA;
      case 'B': return optionB;
      case 'C': return optionC;
      case 'D': return optionD;
      default: return '';
    }
  }
}

// ─── Main service ─────────────────────────────────────────────────────────────

class GithubSyncService {
  static const String _kPat = 'github_pat';
  static const String _kQueue = 'github_sync_queue';
  static const String _kLog = 'github_sync_log';
  static const String _kOwner = 'skm9097';
  static const String _kRepo = 'neet-pg2026';
  static const String _kBranch = 'main';
  static const String _kBase =
      'https://api.github.com/repos/$_kOwner/$_kRepo/contents';
  static const int _maxLogEntries = 200;

  // ── PAT storage ─────────────────────────────────────────────────────────────

  static Future<String?> getPat() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPat);
  }

  static Future<void> setPat(String pat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPat, pat.trim());
  }

  // ── Public API ───────────────────────────────────────────────────────────────

  // Called on wrong answer during quiz — fire and forget.
  static void queueMistake({
    required Question question,
    required String wrongOption,
    required String sessionId,
    required GeminiService gemini,
  }) {
    _processMistake(
      question: question,
      wrongOption: wrongOption,
      sessionId: sessionId,
      gemini: gemini,
    );
  }

  // Called after mock test with multiple wrong answers — fire and forget.
  static void processBatchMistakes({
    required List<QuizAttempt> attempts,
    required List<Question> questions,
    required String sessionId,
    required GeminiService gemini,
    required int correct,
    required Duration timeTaken,
  }) {
    _processBatch(
      attempts: attempts,
      questions: questions,
      sessionId: sessionId,
      gemini: gemini,
      correct: correct,
      timeTaken: timeTaken,
    );
  }

  // Drain offline queue — called by timer and manually from settings.
  static Future<int> flushOfflineQueue(GeminiService gemini) async {
    final pat = await getPat();
    if (pat == null || pat.isEmpty) return 0;

    final pending = await _loadQueue();
    if (pending.isEmpty) return 0;

    int pushed = 0;
    final remaining = <_PendingMistake>[];
    for (final m in pending) {
      try {
        _Enrichment? enrichment;
        if (gemini.isConfigured) {
          enrichment = await _enrichSingle(_pendingToQuestion(m), m.wrongOption, gemini);
        }
        final path = await _pushMistake(
          q: _pendingToQuestion(m),
          wrongOption: m.wrongOption,
          sessionId: m.sessionId,
          enrichment: enrichment,
          timestamp: DateTime.parse(m.timestamp),
          pat: pat,
        );
        await _appendLog(SyncLogEntry(
          timestamp: DateTime.now(),
          success: true,
          detail: path,
          action: 'push',
        ));
        pushed++;
      } catch (e) {
        await _appendLog(SyncLogEntry(
          timestamp: DateTime.now(),
          success: false,
          detail: '${m.questionId}: $e',
          action: 'error',
        ));
        remaining.add(m);
      }
    }
    await _saveQueue(remaining);
    return pushed;
  }

  static Future<int> pendingCount() async {
    final q = await _loadQueue();
    return q.length;
  }

  static Future<List<SyncLogEntry>> getSyncLog() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLog);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => SyncLogEntry.fromJson(e as Map<String, dynamic>))
          .toList()
          .reversed
          .toList(); // newest first
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLog);
  }

  // ── Internal: single mistake processing ──────────────────────────────────────

  static Future<void> _processMistake({
    required Question question,
    required String wrongOption,
    required String sessionId,
    required GeminiService gemini,
  }) async {
    final pat = await getPat();
    try {
      _Enrichment? enrichment;
      if (pat != null && pat.isNotEmpty && gemini.isConfigured) {
        enrichment = await _enrichSingle(question, wrongOption, gemini);
      }

      if (pat != null && pat.isNotEmpty) {
        final path = await _pushMistake(
          q: question,
          wrongOption: wrongOption,
          sessionId: sessionId,
          enrichment: enrichment,
          timestamp: DateTime.now(),
          pat: pat,
        );
        await _appendLog(SyncLogEntry(
          timestamp: DateTime.now(),
          success: true,
          detail: path,
          action: 'push',
        ));
      } else {
        await _enqueue(question, wrongOption, sessionId);
        await _appendLog(SyncLogEntry(
          timestamp: DateTime.now(),
          success: true,
          detail: '${question.id} queued (no PAT configured)',
          action: 'queue',
        ));
      }
    } catch (e) {
      await _enqueue(question, wrongOption, sessionId);
      await _appendLog(SyncLogEntry(
        timestamp: DateTime.now(),
        success: false,
        detail: '${question.id}: $e',
        action: 'error',
      ));
    }
  }

  static Future<void> _enqueue(Question q, String wrongOption, String sessionId) =>
      _addToQueue(_PendingMistake(
        questionId: q.id,
        subject: q.subject,
        stem: q.stem,
        optionA: q.optionA,
        optionB: q.optionB,
        optionC: q.optionC,
        optionD: q.optionD,
        correctOption: q.correctOption,
        wrongOption: wrongOption,
        explanation: q.explanation,
        sessionId: sessionId,
        timestamp: DateTime.now().toIso8601String(),
      ));

  // ── Internal: batch processing ────────────────────────────────────────────────

  static Future<void> _processBatch({
    required List<QuizAttempt> attempts,
    required List<Question> questions,
    required String sessionId,
    required GeminiService gemini,
    required int correct,
    required Duration timeTaken,
  }) async {
    final pat = await getPat();
    if (pat == null || pat.isEmpty) return;

    final questionMap = {for (final q in questions) q.id: q};
    final wrongPairs = <(Question, String)>[];
    for (final a in attempts) {
      if (!a.isCorrect && a.selectedOption != null) {
        final q = questionMap[a.questionId];
        if (q != null) wrongPairs.add((q, a.selectedOption!));
      }
    }
    if (wrongPairs.isEmpty) return;

    final enrichments = gemini.isConfigured
        ? await _enrichBatch(wrongPairs, gemini)
        : List<_Enrichment?>.filled(wrongPairs.length, null);

    final pushed = <String>[];
    final now = DateTime.now();

    for (int i = 0; i < wrongPairs.length; i++) {
      final (q, wrongOpt) = wrongPairs[i];
      final enrich = i < enrichments.length ? enrichments[i] : null;
      try {
        final path = await _pushMistake(
          q: q,
          wrongOption: wrongOpt,
          sessionId: sessionId,
          enrichment: enrich,
          timestamp: now,
          pat: pat,
        );
        pushed.add(path);
        await _appendLog(SyncLogEntry(
          timestamp: DateTime.now(),
          success: true,
          detail: path,
          action: 'push',
        ));
      } catch (e) {
        // Queue so "Sync Now" retries it later — batch failures used to be
        // logged and lost.
        await _enqueue(q, wrongOpt, sessionId);
        await _appendLog(SyncLogEntry(
          timestamp: DateTime.now(),
          success: false,
          detail: '${q.id}: $e (queued for retry)',
          action: 'error',
        ));
      }
    }

    if (pushed.isNotEmpty) {
      try {
        await _pushSessionLog(
          sessionId: sessionId,
          attempts: attempts,
          questions: questions,
          correct: correct,
          timeTaken: timeTaken,
          pushed: pushed,
          pat: pat,
        );
        await _appendLog(SyncLogEntry(
          timestamp: DateTime.now(),
          success: true,
          detail: 'sessions/${_dateStr(now)}_$sessionId.json',
          action: 'session',
        ));
      } catch (e) {
        await _appendLog(SyncLogEntry(
          timestamp: DateTime.now(),
          success: false,
          detail: 'session log failed: $e',
          action: 'error',
        ));
      }
    }
  }

  // ── LLM enrichment ────────────────────────────────────────────────────────────

  static Future<_Enrichment?> _enrichSingle(
      Question q, String wrongOption, GeminiService gemini) async {
    final prompt = _singlePrompt(
      stem: q.stem,
      optionA: q.optionA,
      optionB: q.optionB,
      optionC: q.optionC,
      optionD: q.optionD,
      wrongOption: wrongOption,
      wrongText: q.optionText(wrongOption),
      correctOption: q.correctOption,
      correctText: q.correctText,
      subject: q.subject,
    );
    try {
      return _parseOne(await gemini.askTutor(prompt));
    } catch (_) {
      return null;
    }
  }

  static Future<List<_Enrichment?>> _enrichBatch(
      List<(Question, String)> pairs, GeminiService gemini) async {
    final buf = StringBuffer(
      'A student got these questions wrong in a mock test. '
      'For each, provide key_fact, why_wrong, error_type, and tags.\n\n',
    );
    for (int i = 0; i < pairs.length; i++) {
      final (q, wrongOpt) = pairs[i];
      buf.writeln('${i + 1}. ${q.id}: ${q.stem} '
          '→ Student: $wrongOpt) ${q.optionText(wrongOpt)}, '
          'Correct: ${q.correctOption}) ${q.correctText}');
    }
    buf.writeln('\nRespond as a JSON array, one object per question in order. '
        'No backticks. Each: '
        '{"key_fact":"...","why_wrong":"...","error_type":"...","tags":[...]}');
    try {
      return _parseBatch(await gemini.askTutor(buf.toString()), pairs.length);
    } catch (_) {
      return List.filled(pairs.length, null);
    }
  }

  static String _singlePrompt({
    required String stem,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String wrongOption,
    required String wrongText,
    required String correctOption,
    required String correctText,
    required String subject,
  }) =>
      'A NEET PG student answered this question wrong.\n\n'
      'Question: $stem\n'
      'Options: A) $optionA  B) $optionB  C) $optionC  D) $optionD\n'
      'Their answer: $wrongOption) $wrongText\n'
      'Correct answer: $correctOption) $correctText\n'
      'Subject: $subject\n\n'
      'Respond in JSON only, no backticks:\n'
      '{"key_fact":"2-3 sentence explanation of the correct answer and mechanism",'
      '"why_wrong":"1-2 sentences explaining the specific mistake",'
      '"error_type":"conceptual | recall | silly",'
      '"tags":["keyword1","keyword2","keyword3"]}';

  static _Enrichment? _parseOne(String raw) {
    try {
      final s = raw.indexOf('{');
      final e = raw.lastIndexOf('}');
      if (s < 0 || e < 0) return null;
      final m = jsonDecode(raw.substring(s, e + 1)) as Map<String, dynamic>;
      return _Enrichment(
        keyFact: (m['key_fact'] as String?) ?? '',
        whyWrong: (m['why_wrong'] as String?) ?? '',
        errorType: _sanitizeErrorType(m['error_type'] as String?),
        tags: ((m['tags'] as List<dynamic>?) ?? []).map((t) => t.toString()).toList(),
      );
    } catch (_) {
      return null;
    }
  }

  static List<_Enrichment?> _parseBatch(String raw, int count) {
    try {
      final s = raw.indexOf('[');
      final e = raw.lastIndexOf(']');
      if (s < 0 || e < 0) return List.filled(count, null);
      final list = jsonDecode(raw.substring(s, e + 1)) as List<dynamic>;
      return list.map((item) {
        try {
          final m = item as Map<String, dynamic>;
          return _Enrichment(
            keyFact: (m['key_fact'] as String?) ?? '',
            whyWrong: (m['why_wrong'] as String?) ?? '',
            errorType: _sanitizeErrorType(m['error_type'] as String?),
            tags: ((m['tags'] as List<dynamic>?) ?? []).map((t) => t.toString()).toList(),
          );
        } catch (_) {
          return null;
        }
      }).toList();
    } catch (_) {
      return List.filled(count, null);
    }
  }

  static String _sanitizeErrorType(String? raw) {
    if (raw == null) return 'recall';
    final v = raw.trim().toLowerCase();
    if (v == 'conceptual' || v == 'silly') return v;
    return 'recall';
  }

  // ── Markdown file builder ──────────────────────────────────────────────────────

  static String _buildMarkdown({
    required String questionId,
    required String subject,
    required String stem,
    required String optionA,
    required String optionB,
    required String optionC,
    required String optionD,
    required String correctOption,
    required String wrongOption,
    required String explanation,
    required _Enrichment? enrichment,
    required String sessionId,
    required DateTime timestamp,
    required int timesWrong,
    required int timesCorrect,
    String? firstWrongIso,
    List<String> priorAttemptRows = const [],
    String? existingTags,
    String? existingErrorType,
    String? existingKeyFact,
    String? existingWhyWrong,
  }) {
    String optText(String opt) {
      switch (opt) {
        case 'A': return optionA;
        case 'B': return optionB;
        case 'C': return optionC;
        case 'D': return optionD;
        default: return '';
      }
    }

    const notYet = '_Not yet analyzed — will be filled on desktop sync._';
    bool real(String? s) =>
        s != null && s.isNotEmpty && !s.contains('Not yet analyzed');

    final folder = _subjectFolder(subject);
    final iso = timestamp.toIso8601String();
    final firstIso = (firstWrongIso != null && firstWrongIso.isNotEmpty) ? firstWrongIso : iso;

    // Precedence: fresh enrichment > existing value > raw fallback.
    final tags = (enrichment != null && enrichment.tags.isNotEmpty)
        ? '[${enrichment.tags.join(', ')}]'
        : (existingTags != null && existingTags != '[]' ? existingTags : '[]');
    final errorType = (enrichment != null && enrichment.errorType.isNotEmpty)
        ? enrichment.errorType
        : (existingErrorType ?? 'recall');
    final keyFact = (enrichment != null && enrichment.keyFact.isNotEmpty)
        ? enrichment.keyFact
        : (real(existingKeyFact) ? existingKeyFact! : explanation);
    final whyWrong = (enrichment != null && enrichment.whyWrong.isNotEmpty)
        ? enrichment.whyWrong
        : (real(existingWhyWrong) ? existingWhyWrong! : notYet);
    final dt = _dtLabel(timestamp);

    // History: renumber prior rows, append new one.
    final rows = <String>[];
    for (int i = 0; i < priorAttemptRows.length; i++) {
      rows.add(_renumberRow(priorAttemptRows[i], i + 1));
    }
    rows.add(
        '| ${rows.length + 1} | $dt | $wrongOption) ${optText(wrongOption)} | $sessionId |');

    // Compact bullet-point format — fast to scan passively.
    final historyLines = rows.map((r) => '  $r').join('\n');

    return '''---
id: $questionId
subject: $folder
tags: $tags
error_type: $errorType
first_wrong: $firstIso
last_wrong: $iso
times_wrong: $timesWrong
times_correct: $timesCorrect
is_resolved: false
---

## $questionId — $subject

- **Q:** $stem
- **Got wrong:** $wrongOption) ${optText(wrongOption)}
- **Correct:** $correctOption) ${optText(correctOption)} ✅
- **Key fact:** $keyFact
- **Why wrong:** $whyWrong
- **Tags:** $tags | **Error type:** $errorType
- **Attempts:** ×$timesWrong wrong, ×$timesCorrect correct

<details><summary>History (${rows.length})</summary>

| # | Date | Answer | Session |
|---|---|---|---|
$historyLines

</details>
''';
  }

  // ── GitHub Contents API ───────────────────────────────────────────────────────

  static Map<String, String> _ghHeaders(String pat) => {
    'Authorization': 'Bearer $pat',
    'Content-Type': 'application/json',
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28',
  };

  static Future<void> _pushFile({
    required String path,
    required String content,
    required String message,
    required String pat,
  }) async {
    final url = Uri.parse('$_kBase/$path');
    final headers = _ghHeaders(pat);

    // On a 409/422 sha conflict (another device wrote between our GET and
    // PUT), re-fetch the sha once and retry instead of failing the push.
    for (int attempt = 0; attempt < 2; attempt++) {
      String? sha;
      final getResp = await http.get(url, headers: headers);
      if (getResp.statusCode == 200) {
        final data = jsonDecode(getResp.body) as Map<String, dynamic>;
        sha = data['sha'] as String?;
      }

      final body = <String, dynamic>{
        'message': message,
        'content': base64Encode(utf8.encode(content)),
        'branch': _kBranch,
      };
      if (sha != null) body['sha'] = sha;

      final putResp = await http.put(url, headers: headers, body: jsonEncode(body));
      if (putResp.statusCode == 200 || putResp.statusCode == 201) return;
      if ((putResp.statusCode == 409 || putResp.statusCode == 422) && attempt == 0) continue;
      throw Exception('GitHub ${putResp.statusCode}: ${putResp.body.length > 200 ? putResp.body.substring(0, 200) : putResp.body}');
    }
  }

  /// Push a mistake with update-in-place semantics: fetch the existing file
  /// for this question (if any), merge counters + attempt history + any prior
  /// LLM enrichment, and write the merged document back. Retries once on a
  /// sha conflict.
  static Future<String> _pushMistake({
    required Question q,
    required String wrongOption,
    required String sessionId,
    required _Enrichment? enrichment,
    required DateTime timestamp,
    required String pat,
  }) async {
    final path = _mistakePath(q.subject, q.id);
    final url = Uri.parse('$_kBase/$path');
    final headers = _ghHeaders(pat);

    for (int attempt = 0; attempt < 2; attempt++) {
      String? sha;
      String? existing;
      final getResp = await http.get(url, headers: headers);
      if (getResp.statusCode == 200) {
        final data = jsonDecode(getResp.body) as Map<String, dynamic>;
        sha = data['sha'] as String?;
        final b64 = (data['content'] as String?)?.replaceAll(RegExp(r'\s'), '');
        if (b64 != null && b64.isNotEmpty) {
          try {
            existing = utf8.decode(base64Decode(b64));
          } catch (_) {
            existing = null; // unreadable — treat as new file
          }
        }
      }

      final priorWrong =
          existing != null ? (int.tryParse(_fmValue(existing, 'times_wrong') ?? '') ?? 0) : 0;
      final priorCorrect =
          existing != null ? (int.tryParse(_fmValue(existing, 'times_correct') ?? '') ?? 0) : 0;

      final content = _buildMarkdown(
        questionId: q.id,
        subject: q.subject,
        stem: q.stem,
        optionA: q.optionA,
        optionB: q.optionB,
        optionC: q.optionC,
        optionD: q.optionD,
        correctOption: q.correctOption,
        wrongOption: wrongOption,
        explanation: q.explanation,
        enrichment: enrichment,
        sessionId: sessionId,
        timestamp: timestamp,
        timesWrong: priorWrong + 1,
        timesCorrect: priorCorrect,
        firstWrongIso: existing != null ? _fmValue(existing, 'first_wrong') : null,
        priorAttemptRows: existing != null ? _attemptRows(existing) : const [],
        existingTags: existing != null ? _fmValue(existing, 'tags') : null,
        existingErrorType: existing != null ? _fmValue(existing, 'error_type') : null,
        existingKeyFact: existing != null ? _mdSection(existing, 'Key Fact') : null,
        existingWhyWrong:
            existing != null ? _mdSection(existing, 'Why You Got It Wrong') : null,
      );

      final body = <String, dynamic>{
        'message': priorWrong > 0
            ? 'mistake: ${q.id} again (x${priorWrong + 1})'
            : 'mistake: ${q.id} ${_subjectFolder(q.subject)}',
        'content': base64Encode(utf8.encode(content)),
        'branch': _kBranch,
      };
      if (sha != null) body['sha'] = sha;

      final putResp = await http.put(url, headers: headers, body: jsonEncode(body));
      if (putResp.statusCode == 200 || putResp.statusCode == 201) return path;
      if ((putResp.statusCode == 409 || putResp.statusCode == 422) && attempt == 0) continue;
      throw Exception('GitHub ${putResp.statusCode}: ${putResp.body.length > 200 ? putResp.body.substring(0, 200) : putResp.body}');
    }
    throw Exception('GitHub push conflict persisted for $path');
  }

  // ── Merge helpers (parse bits of an existing mistake file) ───────────────────

  static String? _fmValue(String content, String key) {
    final m = RegExp('^${RegExp.escape(key)}' r':\s*(.*)$', multiLine: true)
        .firstMatch(content);
    final v = m?.group(1)?.trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  static String _mdSection(String content, String name) {
    final re = RegExp(r'(?:^|\n)##\s+' '${RegExp.escape(name)}' r'[^\n]*\n([\s\S]*?)(?=\n##\s|$)');
    final m = re.firstMatch(content);
    return m?.group(1)?.trim() ?? '';
  }

  /// Data rows (not header/separator) of the `## Attempts` table.
  static List<String> _attemptRows(String content) {
    final sec = _mdSection(content, 'Attempts');
    if (sec.isEmpty) return [];
    return sec
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('|'))
        .where((l) {
          final cells = l.split('|');
          if (cells.length < 7) return false;
          final first = cells[1].trim();
          return first != '#' && !RegExp(r'^[-: ]*$').hasMatch(first);
        })
        .toList();
  }

  static String _renumberRow(String row, int n) {
    final cells = row.split('|');
    if (cells.length > 1) cells[1] = ' $n ';
    return cells.join('|');
  }

  static Future<void> _pushSessionLog({
    required String sessionId,
    required List<QuizAttempt> attempts,
    required List<Question> questions,
    required int correct,
    required Duration timeTaken,
    required List<String> pushed,
    required String pat,
  }) async {
    final total = attempts.length;
    final wrong = attempts.where((a) => !a.isCorrect && a.selectedOption != null).length;
    final skipped = attempts.where((a) => a.selectedOption == null).length;
    final accuracy = total > 0 ? correct / total * 100 : 0.0;

    final bySubject = <String, Map<String, int>>{};
    for (final a in attempts) {
      bySubject.putIfAbsent(a.subject, () => {'total': 0, 'correct': 0, 'wrong': 0, 'skipped': 0});
      bySubject[a.subject]!['total'] = (bySubject[a.subject]!['total'] ?? 0) + 1;
      if (a.isCorrect) {
        bySubject[a.subject]!['correct'] = (bySubject[a.subject]!['correct'] ?? 0) + 1;
      } else if (a.selectedOption != null) {
        bySubject[a.subject]!['wrong'] = (bySubject[a.subject]!['wrong'] ?? 0) + 1;
      } else {
        bySubject[a.subject]!['skipped'] = (bySubject[a.subject]!['skipped'] ?? 0) + 1;
      }
    }

    final now = DateTime.now();
    final log = {
      'session_id': sessionId,
      'type': sessionId.contains('mock') ? 'mock-test' : 'practice',
      'started_at': now.subtract(timeTaken).toIso8601String(),
      'ended_at': now.toIso8601String(),
      'total_questions': total,
      'correct': correct,
      'wrong': wrong,
      'skipped': skipped,
      'score_percent': double.parse(accuracy.toStringAsFixed(1)),
      'subject_breakdown': bySubject.entries.map((e) => {'subject': e.key, ...e.value}).toList(),
      'mistakes_pushed': pushed,
    };

    final path = 'sessions/${_dateStr(now)}_$sessionId.json';
    await _pushFile(
      path: path,
      content: const JsonEncoder.withIndent('  ').convert(log),
      message: 'session: $sessionId',
      pat: pat,
    );
  }

  // ── Offline queue ─────────────────────────────────────────────────────────────

  static Future<List<_PendingMistake>> _loadQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kQueue);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => _PendingMistake.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveQueue(List<_PendingMistake> queue) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQueue, jsonEncode(queue.map((m) => m.toJson()).toList()));
  }

  static Future<void> _addToQueue(_PendingMistake m) async {
    final queue = await _loadQueue();
    if (queue.length < 500) queue.add(m);
    await _saveQueue(queue);
  }

  // ── Sync log ──────────────────────────────────────────────────────────────────

  static Future<void> _appendLog(SyncLogEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLog);
    List<dynamic> list = [];
    if (raw != null) {
      try { list = jsonDecode(raw) as List<dynamic>; } catch (_) {}
    }
    list.add(entry.toJson());
    // Keep newest _maxLogEntries
    if (list.length > _maxLogEntries) {
      list = list.sublist(list.length - _maxLogEntries);
    }
    await prefs.setString(_kLog, jsonEncode(list));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static String _subjectFolder(String subject) {
    if (subject.isEmpty || subject == 'General') return 'general';
    return subject.toLowerCase().replaceAll(' ', '-');
  }

  static String _dateStr(DateTime dt) =>
      '${dt.year}-${_p(dt.month)}-${_p(dt.day)}';

  static String _dtLabel(DateTime dt) =>
      '${dt.year}-${_p(dt.month)}-${_p(dt.day)} ${_p(dt.hour)}:${_p(dt.minute)}';

  static String _p(int n) => n.toString().padLeft(2, '0');

  // One file per question (Sync Protocol v2). Repeat mistakes update the same
  // file in place — increment times_wrong, append an attempt row — instead of
  // creating a new date-prefixed file whose card would collide on id and reset
  // the counters on the desktop.
  static String _mistakePath(String subject, String questionId) {
    final folder = _subjectFolder(subject);
    final safeId = questionId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    return 'mistakes/$folder/$safeId.md';
  }

  static Question _pendingToQuestion(_PendingMistake m) => Question(
    id: m.questionId,
    stem: m.stem,
    optionA: m.optionA,
    optionB: m.optionB,
    optionC: m.optionC,
    optionD: m.optionD,
    correctOption: m.correctOption,
    explanation: m.explanation,
    subject: m.subject,
  );
}
