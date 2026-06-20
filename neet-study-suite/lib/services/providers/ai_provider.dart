import '../../models/flashcard.dart';
import '../../models/question.dart';

enum AiProviderType { gemini, groq, openrouter }

extension AiProviderTypeExt on AiProviderType {
  String get displayName {
    switch (this) {
      case AiProviderType.gemini: return 'Google Gemini';
      case AiProviderType.groq: return 'Groq';
      case AiProviderType.openrouter: return 'OpenRouter';
    }
  }

  String get keyHint {
    switch (this) {
      case AiProviderType.gemini: return 'AIza...';
      case AiProviderType.groq: return 'gsk_...';
      case AiProviderType.openrouter: return 'sk-or-...';
    }
  }

  String get signupUrl {
    switch (this) {
      case AiProviderType.gemini: return 'aistudio.google.com';
      case AiProviderType.groq: return 'console.groq.com';
      case AiProviderType.openrouter: return 'openrouter.ai/keys';
    }
  }

  String get freeTierInfo {
    switch (this) {
      case AiProviderType.gemini: return '10 req/min • 250 req/day';
      case AiProviderType.groq: return '30 req/min • 14,400 req/day (generous!)';
      case AiProviderType.openrouter: return 'Free models available • \$1 credit on signup';
    }
  }
}

abstract class AiProvider {
  String get providerName;
  String get modelName;
  bool get isConfigured;

  Future<(bool, String)> testConnection();
  Future<String> getQuickFeedback({
    required String stem,
    required String correctOption,
    required String correctText,
    required String selectedOption,
    required String explanation,
  });
  Future<String> getDetailedExplanation(Question q);
  Future<List<Flashcard>> generateFlashcardsFromQuestion(Question q);
  Future<(List<Flashcard>, String?)> generateFlashcardsFromTopic(String topic, String subject);
  Future<String> askTutor(String question, {String? context});
}
