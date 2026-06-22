import 'package:google_generative_ai/google_generative_ai.dart';
import '../../models/flashcard.dart';
import '../../models/question.dart';
import 'ai_provider.dart';

class GeminiProvider implements AiProvider {
  static const String _primary = 'gemini-2.5-flash';
  static const String _fallback = 'gemini-2.0-flash';

  GenerativeModel? _model;
  String? _apiKey;
  String _activeModel = _primary;

  @override
  String get providerName => 'Google Gemini';
  @override
  String get modelName => _activeModel;
  @override
  bool get isConfigured => _model != null && (_apiKey?.isNotEmpty ?? false);

  void configure(String apiKey) {
    _apiKey = apiKey.trim();
    _activeModel = _primary;
    _model = GenerativeModel(model: _activeModel, apiKey: _apiKey!);
  }

  @override
  Future<(bool, String)> testConnection() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return (false, 'No API key entered.');
    }
    if (!_apiKey!.startsWith('AIza')) {
      return (false, 'Gemini keys start with "AIza". Check you copied the full key.');
    }
    for (final model in [_primary, _fallback]) {
      try {
        final m = GenerativeModel(model: model, apiKey: _apiKey!);
        final r = await m.generateContent([Content.text('Reply with: OK')]);
        if (r.text?.isNotEmpty ?? false) {
          _activeModel = model;
          _model = m;
          return (true, '✓ Connected! Model: $model\nFree tier: 10 req/min • 250 req/day');
        }
      } on GenerativeAIException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('not found') || msg.contains('does not exist')) continue;
        if (msg.contains('api_key_invalid') || msg.contains('api key not valid')) {
          return (false, 'Invalid API key — check you copied it correctly from AI Studio.');
        }
        if (msg.contains('quota') || msg.contains('resource_exhausted')) {
          return (false, 'Rate limit hit (10 req/min on free tier). Wait 1 minute and retry.\n\nTip: Switch to Groq for 14,400 req/day instead.');
        }
        return (false, 'Gemini error: ${e.message}');
      } catch (e) {
        return (false, 'Connection error: $e\n\nCheck your internet connection.');
      }
    }
    return (false, 'No compatible Gemini model found. Try switching to Groq or OpenRouter.');
  }

  @override
  Future<String> getQuickFeedback({
    required String stem, required String correctOption,
    required String correctText, required String selectedOption,
    required String explanation,
  }) async {
    if (_model == null) return _localFeedback(selectedOption, correctOption, explanation);
    final isCorrect = selectedOption == correctOption;
    final prompt = isCorrect
        ? 'NEET-PG MCQ.\nQuestion: $stem\nCorrect answer: $correctOption. $correctText\nReference explanation: $explanation\nGive 1-2 sentence reinforcement + high-yield fact about THIS question. Concise.'
        : 'NEET-PG MCQ.\nQuestion: $stem\nStudent chose: $selectedOption (wrong). Correct answer: $correctOption. $correctText\nReference explanation: $explanation\nIn 1-2 sentences explain why $correctOption is right for THIS question. Concise.';
    try {
      final r = await _model!.generateContent([Content.text(prompt)]);
      return r.text?.trim() ?? _localFeedback(selectedOption, correctOption, explanation);
    } on GenerativeAIException catch (e) {
      if (_isRateLimit(e)) return '⏳ Rate limit hit. ${_localFeedback(selectedOption, correctOption, explanation)}';
      return _localFeedback(selectedOption, correctOption, explanation);
    } catch (_) {
      return _localFeedback(selectedOption, correctOption, explanation);
    }
  }

  @override
  Future<String> getDetailedExplanation(Question q) async {
    if (_model == null) return _localDetailedFallback(q);
    try {
      final r = await _model!.generateContent([Content.text(_detailedPrompt(q))]);
      return r.text?.trim() ?? _localDetailedFallback(q);
    } on GenerativeAIException catch (e) {
      if (_isRateLimit(e)) return '⏳ Rate limit (10 req/min). Wait 1 min or switch to Groq in Settings.\n\n${_localDetailedFallback(q)}';
      return '⚠ ${e.message}\n\n${_localDetailedFallback(q)}';
    } catch (e) {
      return '⚠ $e\n\n${_localDetailedFallback(q)}';
    }
  }

  @override
  Future<List<Flashcard>> generateFlashcardsFromQuestion(Question q) async {
    if (_model == null) return _localCards(q);
    try {
      final r = await _model!.generateContent([Content.text(_cardPrompt(q))]);
      final cards = _parseCards(r.text ?? '', q);
      return cards.isNotEmpty ? cards : _localCards(q);
    } catch (_) {
      return _localCards(q);
    }
  }

  @override
  Future<(List<Flashcard>, String?)> generateFlashcardsFromTopic(String topic, String subject) async {
    if (_model == null) return (<Flashcard>[], 'API key not configured.');
    try {
      final r = await _model!.generateContent([Content.text(_topicPrompt(topic, subject))]);
      final cards = _parseCards(r.text ?? '', null, subject: subject);
      if (cards.isEmpty) return (<Flashcard>[], 'AI returned empty response. Try again.');
      return (cards, null);
    } on GenerativeAIException catch (e) {
      if (_isRateLimit(e)) return (<Flashcard>[], '⏳ Rate limit hit. Wait 1 min or switch to Groq in Settings.');
      return (<Flashcard>[], 'Gemini error: ${e.message}');
    } catch (e) {
      return (<Flashcard>[], 'Error: $e');
    }
  }

  @override
  Future<String> askTutor(String question, {String? context}) async {
    if (_model == null) return 'Configure API key in Settings.';
    final prompt = context != null
        ? 'Context: $context\n\nQuestion: $question\n\nAnswer as NEET-PG medical tutor. 3-5 sentences, precise and exam-focused.'
        : 'NEET-PG: $question\n\nAnswer as medical tutor. 3-5 sentences, precise and exam-focused.';
    try {
      final r = await _model!.generateContent([Content.text(prompt)]);
      return r.text?.trim() ?? 'No response. Try again.';
    } on GenerativeAIException catch (e) {
      if (_isRateLimit(e)) return '⏳ Rate limit (10 req/min free tier). Wait 1 minute or switch to Groq in Settings for 30 req/min.';
      if (_isInvalidKey(e)) return '🔑 Invalid API key. Go to Settings and re-enter your key.';
      return '⚠ ${e.message}';
    } catch (e) {
      return '⚠ Connection error: $e';
    }
  }

  bool _isRateLimit(GenerativeAIException e) {
    final m = e.message.toLowerCase();
    return m.contains('quota') || m.contains('rate') || m.contains('resource_exhausted') || m.contains('429');
  }

  bool _isInvalidKey(GenerativeAIException e) {
    final m = e.message.toLowerCase();
    return m.contains('api_key_invalid') || m.contains('api key not valid');
  }

  String _localFeedback(String sel, String correct, String exp) =>
      sel == correct ? 'Correct! $exp' : 'Incorrect. Correct answer: $correct. $exp';

  String _localDetailedFallback(Question q) =>
      '**Why ${q.correctOption} is correct:**\n${q.explanation}\n\n'
      'Configure AI provider in Settings for full explanations.';

  String _detailedPrompt(Question q) => '''NEET-PG analysis:
Q: ${q.stem}
A. ${q.optionA}  B. ${q.optionB}  C. ${q.optionC}  D. ${q.optionD}
Correct: ${q.correctOption}. ${q.correctText}

**Why ${q.correctOption} is correct:** (2-3 sentences)
**Why others are wrong:** (1 sentence each for wrong options)
**High-yield NEET pearl:** (1 exam fact)''';

  String _cardPrompt(Question q) => '''Create 2-3 NEET-PG flashcards.
Subject: ${q.subject}
Q: ${q.stem}
Answer: ${q.correctOption}. ${q.correctText}
Explanation: ${q.explanation}

Return EXACTLY:
CARD 1
FRONT: [cue]
BACK: [answer]
CARD 2
FRONT: ...
BACK: ...''';

  String _topicPrompt(String topic, String subject) => '''Create 5 NEET-PG flashcards for: "$topic" (Subject: $subject)
High-yield for exam.

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
