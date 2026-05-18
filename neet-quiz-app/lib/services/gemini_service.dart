import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  GenerativeModel? _model;
  String _apiKey = '';
  ChatSession? _chatSession;

  bool get isConfigured => _apiKey.isNotEmpty;
  String get apiKey => _apiKey;

  void setApiKey(String key) {
    _apiKey = key.trim();
    _chatSession = null;
    if (_apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: _apiKey,
      );
    } else {
      _model = null;
    }
  }

  // ── Quiz answer feedback ──────────────────────────────────────────────────

  Future<String> getAnswerFeedback({
    required String questionStem,
    required String correctOption,
    required String correctText,
    required String userOption,
    required String userText,
    required String explanation,
  }) async {
    final isCorrect = userOption == correctOption;

    if (_model == null) {
      return _localFeedback(
        isCorrect: isCorrect,
        correctOption: correctOption,
        correctText: correctText,
        explanation: explanation,
      );
    }

    final prompt = '''You are an enthusiastic NEET-PG exam tutor speaking aloud to a student.

Question: $questionStem

Correct Answer: $correctOption. $correctText
Student Selected: $userOption. $userText
Key fact: $explanation

${isCorrect ? 'The student got it RIGHT.' : 'The student got it WRONG.'}

In 2 to 3 spoken sentences:
1. Tell them whether they got it right or wrong (be encouraging either way).
2. Explain WHY the correct answer is correct using the key fact.
Keep it conversational, clinical, and concise. No markdown, no bullet points — plain speech only.''';

    try {
      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text?.trim() ??
          _localFeedback(
            isCorrect: isCorrect,
            correctOption: correctOption,
            correctText: correctText,
            explanation: explanation,
          );
    } catch (_) {
      return _localFeedback(
        isCorrect: isCorrect,
        correctOption: correctOption,
        correctText: correctText,
        explanation: explanation,
      );
    }
  }

  String _localFeedback({
    required bool isCorrect,
    required String correctOption,
    required String correctText,
    required String explanation,
  }) {
    if (isCorrect) {
      return 'Correct! $correctOption: $correctText. $explanation';
    }
    return 'Not quite. The correct answer is $correctOption: $correctText. $explanation';
  }

  // ── Interactive tutor chat ────────────────────────────────────────────────

  ChatSession _getChat() {
    if (_chatSession != null) return _chatSession!;
    _chatSession = _model!.startChat(history: [
      Content('user', [
        TextPart(
          'You are an expert NEET-PG 2026 medical tutor having a voice conversation '
          'with a student. The student asks you questions about medicine, surgery, '
          'physiology, pharmacology, and all other NEET-PG subjects. '
          'Rules: respond in 2 to 4 plain spoken sentences only — no markdown, no '
          'bullet points, no numbered lists. Be clinically precise, high-yield, and '
          'encouraging. Relate answers to the NEET-PG exam where relevant.',
        ),
      ]),
      Content('model', [TextPart('Understood, ready to help.')]),
    ]);
    return _chatSession!;
  }

  Future<String> chat(String userMessage) async {
    if (_model == null) {
      return 'Please add your Gemini API key in Settings to use the AI tutor.';
    }
    try {
      final response =
          await _getChat().sendMessage(Content.text(userMessage));
      return response.text?.trim() ??
          'Sorry, I could not generate a response. Please try again.';
    } catch (e) {
      return 'Something went wrong: ${e.toString().split('\n').first}';
    }
  }

  void clearChat() => _chatSession = null;
}
