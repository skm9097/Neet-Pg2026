import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/flashcard.dart';
import '../models/question.dart';

class GeminiService {
  // Primary model to try. Falls back to _fallbackModel on "not found" errors.
  static const String modelName = 'gemini-2.5-flash';
  static const String _fallbackModel = 'gemini-2.0-flash';

  GenerativeModel? _model;
  String? _apiKey;
  String _activeModel = modelName;

  void configure(String apiKey) {
    _apiKey = apiKey.trim();
    _activeModel = modelName;
    _model = GenerativeModel(model: _activeModel, apiKey: _apiKey!);
  }

  bool get isConfigured => _model != null && _apiKey != null && _apiKey!.isNotEmpty;
  String get activeModel => _activeModel;

  /// Makes a real test call. Returns (success, message) so UI can show result.
  Future<(bool, String)> testConnection() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      return (false, 'No API key entered. Paste your key and tap Save first.');
    }
    if (!_apiKey!.startsWith('AIza')) {
      return (false, 'Key looks wrong — Gemini keys start with "AIza". Check you copied the full key.');
    }

    // Try primary model first, then fallback
    for (final model in [modelName, _fallbackModel]) {
      try {
        final testModel = GenerativeModel(model: model, apiKey: _apiKey!);
        final response = await testModel.generateContent([
          Content.text('Reply with exactly: OK'),
        ]);
        final text = response.text ?? '';
        if (text.isNotEmpty) {
          // Switch to whichever model worked
          _activeModel = model;
          _model = testModel;
          return (true, '✓ Connected! Using model: $model');
        }
      } on GenerativeAIException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('not found') || msg.contains('does not exist') || msg.contains('invalid model')) {
          // This model doesn't exist, try next
          continue;
        }
        if (msg.contains('api_key_invalid') || msg.contains('api key not valid')) {
          return (false, 'Invalid API key. Check you copied it correctly from AI Studio.');
        }
        if (msg.contains('quota') || msg.contains('rate limit') || msg.contains('resource_exhausted')) {
          return (false, 'Rate limit hit (free tier: 10 requests/min). Wait 1 minute and try again.');
        }
        if (msg.contains('permission') || msg.contains('forbidden')) {
          return (false, 'API key does not have permission to use Gemini. Enable the Gemini API in your Google Cloud project.');
        }
        return (false, 'Gemini error: ${e.message}');
      } catch (e) {
        return (false, 'Connection error: $e\n\nCheck your internet connection.');
      }
    }
    return (false, 'No compatible model found. Models tried: $modelName, $_fallbackModel.\nCheck ai.google.dev for current model names.');
  }

  Future<String> getQuickFeedback({
    required String stem,
    required String correctOption,
    required String correctText,
    required String selectedOption,
    required String explanation,
  }) async {
    if (_model == null) return _localFeedback(selectedOption, correctOption, explanation);

    final isCorrect = selectedOption == correctOption;
    final prompt = isCorrect
        ? 'NEET-PG MCQ: "$stem"\nCorrect: $correctOption. $correctText\n'
          'Explanation: $explanation\n'
          'Give 1–2 sentence reinforcement and a high-yield fact. Be concise.'
        : 'NEET-PG MCQ: "$stem"\nStudent chose: $selectedOption. Correct: $correctOption. $correctText\n'
          'Explanation: $explanation\n'
          'In 1–2 sentences, explain why the correct answer is right. Be concise.';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? _localFeedback(selectedOption, correctOption, explanation);
    } on GenerativeAIException catch (e) {
      if (_isRateLimit(e)) return '⏳ Rate limit hit — showing built-in answer.\n\n${_localFeedback(selectedOption, correctOption, explanation)}';
      return _localFeedback(selectedOption, correctOption, explanation);
    } catch (_) {
      return _localFeedback(selectedOption, correctOption, explanation);
    }
  }

  Future<String> getDetailedExplanation(Question q) async {
    if (_model == null) return _localDetailedFallback(q);

    final prompt = '''NEET-PG question analysis:

Question: ${q.stem}
A. ${q.optionA}
B. ${q.optionB}
C. ${q.optionC}
D. ${q.optionD}
Correct answer: ${q.correctOption}. ${q.correctText}

Provide a structured explanation:
**Why ${q.correctOption} is correct:**
(2–3 sentences)

**Why the other options are wrong:**
(one sentence each for wrong options only)

**High-yield NEET pearl:**
(one memorable exam fact)''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? _localDetailedFallback(q);
    } on GenerativeAIException catch (e) {
      if (_isRateLimit(e)) return '⏳ Rate limit reached (free tier: 10 req/min). Try again in a minute.\n\n${_localDetailedFallback(q)}';
      return '⚠ AI error: ${e.message}\n\n${_localDetailedFallback(q)}';
    } catch (e) {
      return '⚠ Error: $e\n\n${_localDetailedFallback(q)}';
    }
  }

  Future<List<Flashcard>> generateFlashcardsFromQuestion(Question q) async {
    if (_model == null) return _localFlashcardsFromQuestion(q);

    final prompt = '''Create 2–3 flashcards from this NEET-PG MCQ for spaced repetition.
Subject: ${q.subject}
Question: ${q.stem}
Correct answer: ${q.correctOption}. ${q.correctText}
Explanation: ${q.explanation}

Return EXACTLY this format (no extra text):
CARD 1
FRONT: [concise question/cue]
BACK: [concise answer/fact]
CARD 2
FRONT: ...
BACK: ...''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final cards = _parseFlashcardResponse(response.text ?? '', q);
      return cards.isNotEmpty ? cards : _localFlashcardsFromQuestion(q);
    } on GenerativeAIException catch (_) {
      return _localFlashcardsFromQuestion(q);
    } catch (_) {
      return _localFlashcardsFromQuestion(q);
    }
  }

  Future<(List<Flashcard>, String?)> generateFlashcardsFromTopic(String topic, String subject) async {
    if (_model == null) return (<Flashcard>[], 'API key not configured. Go to Settings.');

    final prompt = '''Create 5 NEET-PG flashcards for topic: "$topic" (Subject: $subject).
Make them high-yield for the exam.

Return EXACTLY this format:
CARD 1
FRONT: [concise question/cue]
BACK: [concise answer/fact]
CARD 2
FRONT: ...
BACK: ...
(continue for all 5)''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      final cards = _parseFlashcardResponse(response.text ?? '', null, subject: subject);
      if (cards.isEmpty) return (<Flashcard>[], 'AI returned empty response. Try again.');
      return (cards, null);
    } on GenerativeAIException catch (e) {
      if (_isRateLimit(e)) return (<Flashcard>[], 'Rate limit hit (10 req/min on free tier). Wait 1 minute and retry.');
      return (<Flashcard>[], 'Gemini error: ${e.message}');
    } catch (e) {
      return (<Flashcard>[], 'Error: $e');
    }
  }

  Future<String> askTutor(String question, {String? context}) async {
    if (_model == null) return 'API key not set. Go to ⚙ Settings and enter your Gemini API key.';

    final prompt = context != null
        ? 'Context: $context\n\nQuestion: $question\n\nAnswer as a NEET-PG medical tutor in 3–5 sentences. Be precise and exam-focused.'
        : 'NEET-PG question: $question\n\nAnswer as a medical tutor in 3–5 sentences. Be precise and exam-focused.';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ?? 'No response received. Please try again.';
    } on GenerativeAIException catch (e) {
      if (_isRateLimit(e)) return '⏳ Rate limit reached (free tier: 10 requests/min). Please wait 1 minute and ask again.';
      if (_isInvalidKey(e)) return '🔑 Invalid API key. Go to Settings and check your key.';
      return '⚠ Gemini error: ${e.message}';
    } catch (e) {
      return '⚠ Connection error: $e\n\nCheck your internet connection.';
    }
  }

  bool _isRateLimit(GenerativeAIException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('quota') || msg.contains('rate') || msg.contains('resource_exhausted') || msg.contains('429');
  }

  bool _isInvalidKey(GenerativeAIException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('api_key_invalid') || msg.contains('api key not valid') || msg.contains('400');
  }

  String _localFeedback(String selected, String correct, String explanation) {
    if (selected == correct) return 'Correct! $explanation';
    return 'Incorrect. The correct answer is $correct. $explanation';
  }

  String _localDetailedFallback(Question q) =>
    '**Why ${q.correctOption} is correct:**\n${q.explanation}\n\n'
    '**High-yield NEET pearl:**\nConfigure Gemini API key in Settings for full AI explanations.';

  List<Flashcard> _parseFlashcardResponse(String text, Question? q, {String? subject}) {
    final cards = <Flashcard>[];
    final cardBlocks = RegExp(
      r'CARD \d+\s*\nFRONT:\s*(.*?)\nBACK:\s*(.*?)(?=\nCARD \d+|$)',
      dotAll: true,
    ).allMatches(text);

    for (final match in cardBlocks) {
      final front = match.group(1)?.trim() ?? '';
      final back = match.group(2)?.trim() ?? '';
      if (front.isNotEmpty && back.isNotEmpty) {
        cards.add(Flashcard(
          id: '${DateTime.now().microsecondsSinceEpoch}${cards.length}',
          front: front,
          back: back,
          subject: q?.subject ?? subject ?? 'General',
          sourceQuestionId: q?.id,
          createdAt: DateTime.now(),
        ));
      }
    }
    return cards;
  }

  List<Flashcard> _localFlashcardsFromQuestion(Question q) => [
    Flashcard(
      id: '${q.id}_card',
      front: q.stem,
      back: '${q.correctOption}. ${q.correctText}\n\n${q.explanation}',
      subject: q.subject,
      sourceQuestionId: q.id,
      createdAt: DateTime.now(),
    ),
  ];
}
