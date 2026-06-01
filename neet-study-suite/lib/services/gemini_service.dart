import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/flashcard.dart';
import '../models/question.dart';

class GeminiService {
  static const String modelName = 'gemini-2.0-flash';

  GenerativeModel? _model;
  String? _apiKey;

  void configure(String apiKey) {
    _apiKey = apiKey;
    _model = GenerativeModel(model: modelName, apiKey: apiKey);
  }

  bool get isConfigured => _model != null && _apiKey != null && _apiKey!.isNotEmpty;

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
        ? 'NEET-PG MCQ: "$stem"\nCorrect answer: $correctOption. $correctText\n'
          'Explanation: $explanation\n'
          'Give 1–2 sentence positive reinforcement and a quick high-yield fact. Be concise.'
        : 'NEET-PG MCQ: "$stem"\nStudent chose: $selectedOption. Correct: $correctOption. $correctText\n'
          'Explanation: $explanation\n'
          'In 1–2 sentences, explain why the correct answer is right and why they may have been confused. Be concise.';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? explanation;
    } catch (_) {
      return _localFeedback(selectedOption, correctOption, explanation);
    }
  }

  Future<String> getDetailedExplanation(Question q) async {
    if (_model == null) return _localDetailedFallback(q);

    final prompt = '''
NEET-PG question analysis:

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
A: (one sentence each)
B: ...
C: ...
D: ...
(skip the correct option)

**High-yield NEET pearl:**
(one memorable fact for the exam)
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? _localDetailedFallback(q);
    } catch (e) {
      return _localDetailedFallback(q);
    }
  }

  Future<List<Flashcard>> generateFlashcardsFromQuestion(Question q) async {
    if (_model == null) return _localFlashcardsFromQuestion(q);

    final prompt = '''
Create 2–3 flashcards from this NEET-PG MCQ for spaced repetition study.
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
BACK: ...
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return _parseFlashcardResponse(response.text ?? '', q);
    } catch (_) {
      return _localFlashcardsFromQuestion(q);
    }
  }

  Future<List<Flashcard>> generateFlashcardsFromTopic(String topic, String subject) async {
    if (_model == null) return [];

    final prompt = '''
Create 5 NEET-PG flashcards for the topic: "$topic" (Subject: $subject).
Make them high-yield for exam.

Return EXACTLY this format:
CARD 1
FRONT: [concise question/cue]
BACK: [concise answer/fact]
CARD 2
FRONT: ...
BACK: ...
(continue for all 5)
''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return _parseFlashcardResponse(response.text ?? '', null, subject: subject, topic: topic);
    } catch (_) {
      return [];
    }
  }

  Future<String> askTutor(String question, {String? context}) async {
    if (_model == null) return 'Please configure your Gemini API key in Settings to use the AI Tutor.';

    final prompt = context != null
        ? 'Context (NEET-PG topic): $context\n\nStudent question: $question\n\nAnswer as a medical tutor in 3–5 sentences. Be precise and exam-focused.'
        : 'NEET-PG student question: $question\n\nAnswer as a medical tutor in 3–5 sentences. Be precise and exam-focused.';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? 'No response received.';
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  String _localFeedback(String selected, String correct, String explanation) {
    if (selected == correct) return 'Correct! $explanation';
    return 'Incorrect. The correct answer is $correct. $explanation';
  }

  String _localDetailedFallback(Question q) {
    return '''**Why ${q.correctOption} is correct:**
${q.explanation}

**High-yield NEET pearl:**
Review this topic carefully — configure Gemini API key for detailed AI explanations.''';
  }

  List<Flashcard> _parseFlashcardResponse(String text, Question? q, {String? subject, String? topic}) {
    final cards = <Flashcard>[];
    final cardBlocks = RegExp(r'CARD \d+\s*\nFRONT:(.*?)\nBACK:(.*?)(?=CARD \d+|$)', dotAll: true)
        .allMatches(text);

    for (final match in cardBlocks) {
      final front = match.group(1)?.trim() ?? '';
      final back = match.group(2)?.trim() ?? '';
      if (front.isNotEmpty && back.isNotEmpty) {
        cards.add(Flashcard(
          id: DateTime.now().microsecondsSinceEpoch.toString() + cards.length.toString(),
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

  List<Flashcard> _localFlashcardsFromQuestion(Question q) {
    return [
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
}
