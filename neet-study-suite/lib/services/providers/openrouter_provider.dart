import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../models/flashcard.dart';
import '../../models/question.dart';
import 'ai_provider.dart';

class OpenRouterProvider implements AiProvider {
  static const String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';
  // Free models — no credit needed
  static const String _defaultModel = 'meta-llama/llama-3.1-8b-instruct:free';
  static const String _smartModel = 'google/gemma-2-9b-it:free';

  String? _apiKey;

  @override
  String get providerName => 'OpenRouter';
  @override
  String get modelName => _defaultModel;
  @override
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;

  void configure(String apiKey) {
    _apiKey = apiKey.trim();
  }

  @override
  Future<(bool, String)> testConnection() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return (false, 'No API key entered.');
    }
    if (!_apiKey!.startsWith('sk-or-')) {
      return (false, 'OpenRouter keys start with "sk-or-". Get yours free at openrouter.ai/keys');
    }
    try {
      final result = await _chat('Reply with: OK', maxTokens: 10);
      if (result.startsWith('⚠') || result.startsWith('🔑') || result.startsWith('⏳')) {
        return (false, result);
      }
      return (true, '✓ Connected!\nModel: $_defaultModel\nFree tier: no daily limit on free models');
    } catch (e) {
      return (false, 'Connection error: $e');
    }
  }

  @override
  Future<String> getQuickFeedback({
    required String stem, required String correctOption,
    required String correctText, required String selectedOption,
    required String explanation,
  }) async {
    if (!isConfigured) return _localFeedback(selectedOption, correctOption, explanation);
    final isCorrect = selectedOption == correctOption;
    final prompt = isCorrect
        ? 'NEET-PG MCQ.\nQuestion: $stem\nCorrect answer: $correctOption. $correctText\nReference explanation: $explanation\n1-2 sentence reinforcement + high-yield fact about THIS question. Very concise.'
        : 'NEET-PG MCQ.\nQuestion: $stem\nStudent chose: $selectedOption (wrong). Correct answer: $correctOption. $correctText\nReference explanation: $explanation\nIn 1-2 sentences explain why $correctOption is right for THIS question. Very concise.';
    final r = await _chat(prompt, maxTokens: 150);
    if (r.startsWith('⚠') || r.startsWith('⏳')) return _localFeedback(selectedOption, correctOption, explanation);
    return r;
  }

  @override
  Future<String> getDetailedExplanation(Question q) async {
    if (!isConfigured) return _localDetailedFallback(q);
    final r = await _chat(_detailedPrompt(q), maxTokens: 500);
    if (r.startsWith('⚠') || r.startsWith('⏳')) return '$r\n\n${_localDetailedFallback(q)}';
    return r;
  }

  @override
  Future<List<Flashcard>> generateFlashcardsFromQuestion(Question q) async {
    if (!isConfigured) return _localCards(q);
    final r = await _chat(_cardPrompt(q), maxTokens: 400);
    if (r.startsWith('⚠') || r.startsWith('⏳')) return _localCards(q);
    final cards = _parseCards(r, q);
    return cards.isNotEmpty ? cards : _localCards(q);
  }

  @override
  Future<(List<Flashcard>, String?)> generateFlashcardsFromTopic(String topic, String subject) async {
    if (!isConfigured) return (<Flashcard>[], 'API key not configured. Go to Settings.');
    final r = await _chat(_topicPrompt(topic, subject), maxTokens: 600, smart: true);
    if (r.startsWith('⚠') || r.startsWith('⏳') || r.startsWith('🔑')) {
      return (<Flashcard>[], r);
    }
    final cards = _parseCards(r, null, subject: subject);
    if (cards.isEmpty) return (<Flashcard>[], 'AI returned unexpected format. Try again.');
    return (cards, null);
  }

  @override
  Future<String> askTutor(String question, {String? context}) async {
    if (!isConfigured) return 'Configure OpenRouter API key in Settings.';
    final prompt = context != null
        ? 'Context: $context\n\nQuestion: $question\n\nAnswer as NEET-PG medical tutor. 3-5 sentences, precise and exam-focused.'
        : 'NEET-PG: $question\n\nAnswer as medical tutor. 3-5 sentences, precise and exam-focused.';
    return _chat(prompt, maxTokens: 400, smart: true);
  }

  Future<String> _chat(String prompt, {int maxTokens = 300, bool smart = false}) async {
    final model = smart ? _smartModel : _defaultModel;
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'https://github.com/skm9097/neet-pg2026',
          'X-Title': 'NEET-PG Study Suite',
        },
        body: jsonEncode({
          'model': model,
          'messages': [{'role': 'user', 'content': prompt}],
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) return '⚠ No response from model. Try again.';
        return (choices.first['message'] as Map)['content'] as String? ?? '';
      }

      return _parseError(response);
    } catch (e) {
      if (e.toString().contains('TimeoutException')) return '⏳ Request timed out. Check connection.';
      return '⚠ Network error: $e';
    }
  }

  String _parseError(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final msg = (body['error'] as Map?)?.entries
          .firstWhere((e) => e.key == 'message', orElse: () => MapEntry('', response.body))
          .value as String? ?? response.body;
      switch (response.statusCode) {
        case 401: return '🔑 Invalid API key. Get a free key at openrouter.ai/keys';
        case 429: return '⏳ Rate limit hit. Wait a moment and try again.';
        case 402: return '⚠ Insufficient credits. Top up at openrouter.ai or use a free model.';
        default: return '⚠ OpenRouter error ${response.statusCode}: $msg';
      }
    } catch (_) {
      return '⚠ OpenRouter error ${response.statusCode}: ${response.body}';
    }
  }

  String _localFeedback(String sel, String correct, String exp) =>
      sel == correct ? 'Correct! $exp' : 'Incorrect. Correct answer: $correct. $exp';

  String _localDetailedFallback(Question q) =>
      '**Why ${q.correctOption} is correct:**\n${q.explanation}\n\n'
      'Configure AI provider in Settings for full explanations.';

  String _detailedPrompt(Question q) => '''NEET-PG MCQ analysis:
Q: ${q.stem}
A. ${q.optionA}  B. ${q.optionB}  C. ${q.optionC}  D. ${q.optionD}
Correct: ${q.correctOption}. ${q.correctText}

**Why ${q.correctOption} is correct:** (2-3 sentences)
**Why others are wrong:** (1 sentence each for wrong options)
**High-yield NEET pearl:** (1 exam fact)''';

  String _cardPrompt(Question q) => '''Create 2-3 NEET-PG flashcards.
Subject: ${q.subject}. Q: ${q.stem}. Answer: ${q.correctOption}. ${q.correctText}

Return EXACTLY:
CARD 1
FRONT: [cue]
BACK: [answer]
CARD 2
FRONT: ...
BACK: ...''';

  String _topicPrompt(String topic, String subject) => '''Create 5 NEET-PG flashcards for: "$topic" ($subject)

Return EXACTLY:
CARD 1
FRONT: [cue]
BACK: [answer]
CARD 2
FRONT: ...
BACK: ...
(all 5)''';

  List<Flashcard> _parseCards(String text, Question? q, {String? subject}) {
    final cards = <Flashcard>[];
    final matches = RegExp(r'CARD \d+\s*\nFRONT:\s*(.*?)\nBACK:\s*(.*?)(?=\nCARD \d+|$)', dotAll: true)
        .allMatches(text);
    for (final m in matches) {
      final front = m.group(1)?.trim() ?? '';
      final back = m.group(2)?.trim() ?? '';
      if (front.isNotEmpty && back.isNotEmpty) {
        cards.add(Flashcard(
          id: '${DateTime.now().microsecondsSinceEpoch}${cards.length}',
          front: front, back: back,
          subject: q?.subject ?? subject ?? 'General',
          sourceQuestionId: q?.id,
          createdAt: DateTime.now(),
        ));
      }
    }
    return cards;
  }

  List<Flashcard> _localCards(Question q) => [
    Flashcard(
      id: '${q.id}_card', front: q.stem,
      back: '${q.correctOption}. ${q.correctText}\n\n${q.explanation}',
      subject: q.subject, sourceQuestionId: q.id, createdAt: DateTime.now(),
    ),
  ];
}
