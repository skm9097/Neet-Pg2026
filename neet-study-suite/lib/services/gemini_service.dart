import 'package:shared_preferences/shared_preferences.dart';
import '../models/flashcard.dart';
import '../models/question.dart';
import 'providers/ai_provider.dart';
import 'providers/gemini_provider.dart';
import 'providers/groq_provider.dart';
import 'providers/openrouter_provider.dart';

export 'providers/ai_provider.dart' show AiProviderType;

// Named GeminiService for backwards compat with all existing screen imports.
// Internally it's a multi-provider facade.
class GeminiService {
  final GeminiProvider _gemini = GeminiProvider();
  final GroqProvider _groq = GroqProvider();
  final OpenRouterProvider _openRouter = OpenRouterProvider();

  AiProviderType _activeType = AiProviderType.gemini;
  AiProvider get _active {
    switch (_activeType) {
      case AiProviderType.gemini: return _gemini;
      case AiProviderType.groq: return _groq;
      case AiProviderType.openrouter: return _openRouter;
    }
  }

  static const String modelName = 'gemini-2.5-flash'; // shown in old settings references
  String get activeModel => _active.modelName;
  String get activeProviderName => _active.providerName;
  AiProviderType get activeProviderType => _activeType;

  bool get isConfigured => _active.isConfigured;

  // Called on app start with saved keys
  void configure(String apiKey) => _configureProvider(_activeType, apiKey);

  // Full multi-provider setup
  void setProvider(AiProviderType type, String apiKey) {
    _activeType = type;
    _configureProvider(type, apiKey);
  }

  void _configureProvider(AiProviderType type, String apiKey) {
    switch (type) {
      case AiProviderType.gemini: _gemini.configure(apiKey); break;
      case AiProviderType.groq: _groq.configure(apiKey); break;
      case AiProviderType.openrouter: _openRouter.configure(apiKey); break;
    }
  }

  // Restore all saved keys + active provider from SharedPreferences
  Future<void> restoreFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final typeName = prefs.getString('ai_provider_type') ?? 'gemini';
    _activeType = AiProviderType.values.firstWhere(
      (t) => t.name == typeName, orElse: () => AiProviderType.gemini);

    final geminiKey = prefs.getString('gemini_api_key') ?? '';
    final groqKey = prefs.getString('groq_api_key') ?? '';
    final openrouterKey = prefs.getString('openrouter_api_key') ?? '';

    if (geminiKey.isNotEmpty) _gemini.configure(geminiKey);
    if (groqKey.isNotEmpty) _groq.configure(groqKey);
    if (openrouterKey.isNotEmpty) _openRouter.configure(openrouterKey);
  }

  Future<(bool, String)> testConnection() => _active.testConnection();

  Future<String> getQuickFeedback({
    required String stem,
    required String correctOption,
    required String correctText,
    required String selectedOption,
    required String explanation,
  }) => _active.getQuickFeedback(
    stem: stem, correctOption: correctOption, correctText: correctText,
    selectedOption: selectedOption, explanation: explanation,
  );

  Future<String> getDetailedExplanation(Question q) => _active.getDetailedExplanation(q);

  Future<List<Flashcard>> generateFlashcardsFromQuestion(Question q) =>
      _active.generateFlashcardsFromQuestion(q);

  Future<(List<Flashcard>, String?)> generateFlashcardsFromTopic(String topic, String subject) =>
      _active.generateFlashcardsFromTopic(topic, subject);

  Future<String> askTutor(String question, {String? context}) =>
      _active.askTutor(question, context: context);
}
