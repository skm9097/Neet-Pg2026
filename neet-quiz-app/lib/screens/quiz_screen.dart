import 'dart:math';
import 'package:flutter/material.dart';
import '../models/question.dart';
import '../models/quiz_config.dart';
import '../services/gemini_service.dart';
import '../services/github_service.dart';
import '../services/markdown_parser.dart';
import '../services/tts_service.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final QuizConfig config;
  final GeminiService gemini;
  final TtsService tts;

  const QuizScreen({
    super.key,
    required this.config,
    required this.gemini,
    required this.tts,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  List<Question> _questions = [];
  int _currentIndex = 0;
  String? _selectedOption;
  bool _answered = false;
  String _aiFeedback = '';
  bool _loadingFeedback = false;
  bool _loadingQuestions = true;
  String? _error;
  int _correctCount = 0;
  final List<Map<String, dynamic>> _history = [];

  String _detailedExplanation = '';
  bool _loadingDetailed = false;

  late AnimationController _feedbackAnim;
  late Animation<double> _feedbackFade;

  @override
  void initState() {
    super.initState();
    _feedbackAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _feedbackFade =
        CurvedAnimation(parent: _feedbackAnim, curve: Curves.easeOut);
    _loadQuestions();
  }

  @override
  void dispose() {
    _feedbackAnim.dispose();
    widget.tts.stop();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      _loadingQuestions = true;
      _error = null;
    });
    try {
      final github = GitHubService();
      List<Question> all = [];

      switch (widget.config.moduleType) {
        case ModuleType.byYear:
          final md =
              await github.fetchYearQuestions(widget.config.year!);
          all = MarkdownParser.parse(md, year: widget.config.year);
          break;
        case ModuleType.bySubject:
          final md =
              await github.fetchSubjectQuestions(widget.config.subject!);
          all = MarkdownParser.parse(
              md, subject: widget.config.subject!, year: null);
          break;
        case ModuleType.mixed:
          final tasks = <Future<List<Question>>>[];
          final shuffledYears = [...GitHubService.years]..shuffle(Random());
          for (final y in shuffledYears.take(4)) {
            tasks.add(github
                .fetchYearQuestions(y)
                .then((md) => MarkdownParser.parse(md, year: y))
                .catchError((_) => <Question>[]));
          }
          final results = await Future.wait(tasks);
          for (final r in results) all.addAll(r);
          break;
      }

      all = all
          .where((q) =>
              q.correctOption.isNotEmpty &&
              q.optionA.isNotEmpty &&
              q.optionB.isNotEmpty &&
              q.optionC.isNotEmpty &&
              q.optionD.isNotEmpty &&
              !q.isImageBased)
          .toList();

      all.shuffle(Random());
      if (widget.config.questionCount < all.length) {
        all = all.take(widget.config.questionCount).toList();
      }

      setState(() {
        _questions = all;
        _loadingQuestions = false;
      });

      if (all.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 500));
        _speakQuestion(all[0]);
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingQuestions = false;
      });
    }
  }

  void _speakQuestion(Question q) {
    final idx = _currentIndex + 1;
    final total = _questions.length;
    widget.tts.speak(
      'Question $idx of $total. '
      '${q.topic}. '
      '${q.stem} '
      'Option A: ${q.optionA}. '
      'Option B: ${q.optionB}. '
      'Option C: ${q.optionC}. '
      'Option D: ${q.optionD}.',
    );
  }

  Future<void> _toggleTts() async {
    final on = await widget.tts.toggle();
    if (on) {
      _speakQuestion(_currentQuestion);
    }
    if (mounted) setState(() {});
  }

  Future<void> _fetchDetailedExplanation() async {
    if (_loadingDetailed) return;
    final q = _currentQuestion;
    setState(() => _loadingDetailed = true);
    final detail = await widget.gemini.getDetailedExplanation(
      questionStem: q.stem,
      optionA: q.optionA,
      optionB: q.optionB,
      optionC: q.optionC,
      optionD: q.optionD,
      correctOption: q.correctOption,
      correctText: q.correctText,
      explanation: q.explanation,
    );
    if (!mounted) return;
    setState(() {
      _detailedExplanation = detail;
      _loadingDetailed = false;
    });
  }

  Future<void> _selectOption(String option) async {
    if (_answered) return;
    await widget.tts.stop();

    final q = _currentQuestion;
    final isCorrect = option == q.correctOption;

    setState(() {
      _selectedOption = option;
      _answered = true;
      _loadingFeedback = true;
      if (isCorrect) _correctCount++;
    });

    _history.add({
      'question': q,
      'selected': option,
      'correct': q.correctOption,
      'isCorrect': isCorrect,
    });

    final feedback = await widget.gemini.getAnswerFeedback(
      questionStem: q.stem,
      correctOption: q.correctOption,
      correctText: q.optionText(q.correctOption),
      userOption: option,
      userText: q.optionText(option),
      explanation: q.explanation,
    );

    setState(() {
      _aiFeedback = feedback;
      _loadingFeedback = false;
    });
    _feedbackAnim.forward(from: 0);
    widget.tts.speak(feedback);
  }

  String get _quizSource {
    switch (widget.config.moduleType) {
      case ModuleType.byYear:
        return 'year_${widget.config.year ?? "unknown"}';
      case ModuleType.bySubject:
        return 'subject_${widget.config.subject ?? "unknown"}';
      case ModuleType.mixed:
        return 'mixed';
    }
  }

  void _nextQuestion() {
    widget.tts.stop();
    if (_currentIndex + 1 >= _questions.length) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            total: _questions.length,
            correct: _correctCount,
            history: _history,
            source: _quizSource,
            gemini: widget.gemini,
            tts: widget.tts,
          ),
        ),
      );
      return;
    }
    _feedbackAnim.reset();
    setState(() {
      _currentIndex++;
      _selectedOption = null;
      _answered = false;
      _aiFeedback = '';
      _loadingFeedback = false;
      _detailedExplanation = '';
      _loadingDetailed = false;
    });
    _speakQuestion(_questions[_currentIndex]);
  }

  Question get _currentQuestion => _questions[_currentIndex];

  Color _optionBg(String option) {
    if (!_answered) return const Color(0xFF1A1A2E);
    if (option == _currentQuestion.correctOption) {
      return const Color(0xFF064E3B);
    }
    if (option == _selectedOption) return const Color(0xFF450A0A);
    return const Color(0xFF111122);
  }

  Color _optionBorder(String option) {
    if (!_answered) return const Color(0xFF2A2A4A);
    if (option == _currentQuestion.correctOption) {
      return const Color(0xFF10B981);
    }
    if (option == _selectedOption) return const Color(0xFFEF4444);
    return const Color(0xFF1A1A2E);
  }

  IconData? _optionIcon(String option) {
    if (!_answered) return null;
    if (option == _currentQuestion.correctOption) return Icons.check_circle;
    if (option == _selectedOption) return Icons.cancel;
    return null;
  }

  Color _optionIconColor(String option) {
    if (option == _currentQuestion.correctOption) return const Color(0xFF10B981);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingQuestions) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF7C3AED)),
              const SizedBox(height: 20),
              Text(
                'Fetching questions from GitHub…',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, color: Colors.white38, size: 64),
                const SizedBox(height: 20),
                const Text(
                  'Could not load questions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _loadQuestions,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(
          child: Text('No questions found for this selection.',
              style: TextStyle(color: Colors.white60)),
        ),
      );
    }

    final q = _currentQuestion;
    final progress = (_currentIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(progress),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestionCard(q),
                    const SizedBox(height: 20),
                    _buildOptions(q),
                    if (_answered) ...[
                      const SizedBox(height: 20),
                      _buildFeedbackCard(),
                      const SizedBox(height: 12),
                      _buildExplainSection(),
                      const SizedBox(height: 16),
                      _buildNextButton(),
                    ],
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(double progress) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () {
                  widget.tts.stop();
                  Navigator.pop(context);
                },
              ),
              Expanded(
                child: Text(
                  'Q${_currentIndex + 1} / ${_questions.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white70,
                  ),
                ),
              ),
              if (widget.tts.enabled)
                IconButton(
                  icon: const Icon(Icons.replay_rounded,
                      color: Color(0xFF7C3AED)),
                  onPressed: () => _speakQuestion(_currentQuestion),
                  tooltip: 'Re-read question',
                ),
              IconButton(
                icon: Icon(
                  widget.tts.enabled
                      ? Icons.volume_up_rounded
                      : Icons.volume_off_rounded,
                  color: widget.tts.enabled
                      ? const Color(0xFF7C3AED)
                      : Colors.white38,
                ),
                onPressed: _toggleTts,
                tooltip: widget.tts.enabled ? 'Voice on (tap to mute)' : 'Voice off (tap to enable)',
              ),
            ],
          ),
        ),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: const Color(0xFF1A1A2E),
          valueColor:
              const AlwaysStoppedAnimation<Color>(Color(0xFF7C3AED)),
          minHeight: 3,
        ),
      ],
    );
  }

  Widget _buildQuestionCard(Question q) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2A2A4A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (q.subject.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7C3AED).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: const Color(0xFF7C3AED).withOpacity(0.4)),
                  ),
                  child: Text(
                    q.subject,
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7C3AED),
                        fontWeight: FontWeight.w600),
                  ),
                ),
              if (q.year != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2937),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    q.year!,
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white54),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            q.topic,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white38,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q.stem,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions(Question q) {
    return Column(
      children: ['A', 'B', 'C', 'D'].map((opt) {
        final text = q.optionText(opt);
        final icon = _optionIcon(opt);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _selectOption(opt),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _optionBg(opt),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _optionBorder(opt), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: _answered
                          ? _optionBorder(opt).withOpacity(0.2)
                          : const Color(0xFF2A2A4A),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: _answered
                              ? _optionBorder(opt)
                              : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 15,
                        color: _answered && opt != _currentQuestion.correctOption
                            ? Colors.white54
                            : Colors.white,
                        height: 1.4,
                      ),
                    ),
                  ),
                  if (icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: _optionIconColor(opt), size: 20),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFeedbackCard() {
    return FadeTransition(
      opacity: _feedbackFade,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _selectedOption == _currentQuestion.correctOption
              ? const Color(0xFF064E3B).withOpacity(0.6)
              : const Color(0xFF1C1917),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _selectedOption == _currentQuestion.correctOption
                ? const Color(0xFF10B981).withOpacity(0.4)
                : const Color(0xFF06B6D4).withOpacity(0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _selectedOption == _currentQuestion.correctOption
                    ? const Color(0xFF10B981).withOpacity(0.2)
                    : const Color(0xFF06B6D4).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                size: 20,
                color: _selectedOption == _currentQuestion.correctOption
                    ? const Color(0xFF10B981)
                    : const Color(0xFF06B6D4),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _loadingFeedback
                  ? Row(
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF06B6D4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Thinking…',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 14),
                        ),
                      ],
                    )
                  : Text(
                      _aiFeedback,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExplainSection() {
    if (_detailedExplanation.isNotEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF15172B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 18, color: Color(0xFF7C3AED)),
                const SizedBox(width: 8),
                const Text(
                  'AI Detailed Explanation',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const Spacer(),
                if (widget.tts.enabled)
                  GestureDetector(
                    onTap: () => widget.tts.speak(_detailedExplanation),
                    child: const Icon(Icons.volume_up_rounded,
                        size: 18, color: Color(0xFF7C3AED)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _detailedExplanation,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                height: 1.55,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _loadingDetailed ? null : _fetchDetailedExplanation,
        icon: _loadingDetailed
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF7C3AED)),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(_loadingDetailed
            ? 'Asking Gemini…'
            : 'Explain in detail with AI'),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF7C3AED),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: BorderSide(color: const Color(0xFF7C3AED).withOpacity(0.5)),
        ),
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _currentIndex + 1 >= _questions.length;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _nextQuestion,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF7C3AED),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: Icon(
          isLast ? Icons.flag_rounded : Icons.arrow_forward_rounded,
        ),
        label: Text(
          isLast ? 'See Results' : 'Next Question',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
