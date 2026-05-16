import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  GenerativeModel? _model;
  String _apiKey = '';

  bool get isConfigured => _apiKey.isNotEmpty;
  String get apiKey => _apiKey;

  void setApiKey(String key) {
    _apiKey = key.trim();
    if (_apiKey.isNotEmpty) {
      _model = GenerativeModel(
        model: 'gemini-1.5-flash-latest',
        apiKey: _apiKey,
      );
    } else {
      _model = null;
    }
  }

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
      final response =
          await _model!.generateContent([Content.text(prompt)]);
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
}
