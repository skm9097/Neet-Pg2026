import 'package:flutter/material.dart';
import '../../models/question.dart';
import '../../models/quiz_attempt.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/github_service.dart';
import '../../services/markdown_parser.dart';
import '../../services/bookmark_service.dart';
import '../../services/flashcard_service.dart';
import '../../core/theme/app_theme.dart';
import 'result_screen.dart';

class QuizScreen extends StatefulWidget {
  final String mode;    // 'year', 'subject', 'mixed'
  final String source;  // year string or subject key
  final int count;
  final GeminiService gemini;
  final TtsService tts;

  const QuizScreen({
    super.key,
    required this.mode,
    required this.source,
    required this.count,
    required this.gemini,
    required this.tts,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<Question> _questions = [];
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;
  String? _selected;
  bool _answered = false;
  String? _feedback;
  bool _loadingFeedback = false;
  String? _detailedExplanation;
  bool _loadingDetailed = false;
  bool _bookmarked = false;
  final List<QuizAttempt> _attempts = [];

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    widget.tts.stop();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final service = GithubService();
      List<Question> all = [];

      if (widget.mode == 'year') {
        final md = await service.fetchYearMarkdown(widget.source);
        all = MarkdownParser.parse(md, source: widget.source);
      } else if (widget.mode == 'subject') {
        final md = await service.fetchSubjectMarkdown(widget.source);
        all = MarkdownParser.parse(md, source: widget.source);
      } else {
        // Mixed: fetch a random year
        final years = GithubService.availableYears;
        years.shuffle();
        for (final y in years.take(2)) {
          try {
            final md = await service.fetchYearMarkdown(y);
            all.addAll(MarkdownParser.parse(md, source: y));
          } catch (_) {}
          if (all.length >= widget.count * 2) break;
        }
      }

      if (all.isEmpty) throw Exception('No questions found.');
      all.shuffle();
      final questions = all.take(widget.count).toList();

      if (mounted) {
        setState(() {
          _questions = questions;
          _loading = false;
        });
        _speakQuestion();
        _checkBookmark();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _speakQuestion() {
    if (_questions.isEmpty) return;
    final q = _questions[_currentIndex];
    final text = '${q.stem}. A: ${q.optionA}. B: ${q.optionB}. C: ${q.optionC}. D: ${q.optionD}.';
    widget.tts.speak(text);
  }

  Future<void> _checkBookmark() async {
    if (_questions.isEmpty) return;
    final b = await BookmarkService.isBookmarked(_questions[_currentIndex].id);
    if (mounted) setState(() => _bookmarked = b);
  }

  Future<void> _answer(String option) async {
    if (_answered) return;
    final q = _questions[_currentIndex];
    final isCorrect = option == q.correctOption;

    setState(() {
      _selected = option;
      _answered = true;
      _loadingFeedback = true;
    });

    _attempts.add(QuizAttempt(
      questionId: q.id,
      selectedOption: option,
      isCorrect: isCorrect,
      subject: q.subject,
    ));

    final feedback = await widget.gemini.getQuickFeedback(
      stem: q.stem,
      correctOption: q.correctOption,
      correctText: q.correctText,
      selectedOption: option,
      explanation: q.explanation,
    );

    if (mounted) {
      setState(() { _feedback = feedback; _loadingFeedback = false; });
      widget.tts.speak(feedback);
    }
  }

  Future<void> _loadDetailedExplanation() async {
    if (_detailedExplanation != null) return;
    final q = _questions[_currentIndex];
    setState(() => _loadingDetailed = true);
    final exp = await widget.gemini.getDetailedExplanation(q);
    if (mounted) setState(() { _detailedExplanation = exp; _loadingDetailed = false; });
  }

  Future<void> _generateFlashcards() async {
    final q = _questions[_currentIndex];
    final cards = await widget.gemini.generateFlashcardsFromQuestion(q);
    await FlashcardService.addCards(cards);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${cards.length} flashcard(s) added!')));
    }
  }

  void _next() {
    widget.tts.stop();
    if (_currentIndex < _questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selected = null;
        _answered = false;
        _feedback = null;
        _loadingFeedback = false;
        _detailedExplanation = null;
        _loadingDetailed = false;
        _bookmarked = false;
      });
      _speakQuestion();
      _checkBookmark();
    } else {
      _showResults();
    }
  }

  void _skip() {
    if (_answered) return;
    final q = _questions[_currentIndex];
    _attempts.add(QuizAttempt(
      questionId: q.id,
      selectedOption: null,
      isCorrect: false,
      subject: q.subject,
    ));
    _next();
  }

  void _showResults() {
    final source = widget.mode == 'year'
        ? 'year_${widget.source}'
        : widget.mode == 'subject'
            ? 'subject_${widget.source}'
            : 'mixed';

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultScreen(
        attempts: _attempts,
        questions: _questions,
        source: source,
        gemini: widget.gemini,
        tts: widget.tts,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(
      appBar: AppBar(title: const Text('Loading...')),
      body: const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Fetching questions...'),
        ],
      )),
    );

    if (_error != null) return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Could not load questions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () { setState(() { _loading = true; _error = null; }); _loadQuestions(); },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      )),
    );

    final q = _questions[_currentIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Q ${_currentIndex + 1} / ${_questions.length}'),
        actions: [
          IconButton(
            icon: Icon(widget.tts.isEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              await widget.tts.toggle();
              setState(() {});
            },
          ),
          if (widget.tts.isEnabled)
            IconButton(icon: const Icon(Icons.replay), onPressed: _speakQuestion),
          IconButton(
            icon: Icon(_bookmarked ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () async {
              if (_bookmarked) {
                await BookmarkService.remove(q.id);
              } else {
                await BookmarkService.add(q);
              }
              setState(() => _bookmarked = !_bookmarked);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentIndex + 1) / _questions.length),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSubjectChip(q),
                  const SizedBox(height: 12),
                  _buildStemCard(q),
                  const SizedBox(height: 16),
                  ...['A', 'B', 'C', 'D'].map((opt) => _buildOptionButton(q, opt)),
                  if (_answered) ...[
                    const SizedBox(height: 16),
                    _buildFeedbackCard(q),
                    const SizedBox(height: 12),
                    _buildActionRow(q),
                  ],
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildSubjectChip(Question q) {
    final subjectLabel = GithubService.subjectDisplayNames[q.subject] ?? q.subject;
    return Row(
      children: [
        Chip(label: Text(subjectLabel)),
        if (q.year != null) ...[
          const SizedBox(width: 8),
          Chip(label: Text(q.year!)),
        ],
      ],
    );
  }

  Widget _buildStemCard(Question q) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(q.stem, style: const TextStyle(fontSize: 16, height: 1.6)),
      ),
    );
  }

  Widget _buildOptionButton(Question q, String opt) {
    final isSelected = _selected == opt;
    final isCorrect = opt == q.correctOption;
    Color? bgColor;
    Color? textColor;
    Widget? trailing;

    if (_answered) {
      if (isCorrect) {
        bgColor = AppTheme.correct;
        textColor = Colors.white;
        trailing = const Icon(Icons.check_circle, color: Colors.white);
      } else if (isSelected && !isCorrect) {
        bgColor = AppTheme.incorrect;
        textColor = Colors.white;
        trailing = const Icon(Icons.cancel, color: Colors.white);
      }
    } else if (isSelected) {
      bgColor = AppTheme.primary;
      textColor = Colors.white;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        color: bgColor,
        child: InkWell(
          onTap: _answered ? null : () => _answer(opt),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgColor != null ? Colors.white24 : Colors.blue[50],
                  ),
                  child: Center(child: Text(opt, style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor ?? AppTheme.primary,
                  ))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(q.optionText(opt),
                  style: TextStyle(color: textColor, height: 1.4))),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(Question q) {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppTheme.primary),
                SizedBox(width: 6),
                Text('AI Feedback', style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.primary)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loadingFeedback)
              const Center(child: CircularProgressIndicator(strokeWidth: 2))
            else
              Text(_feedback ?? q.explanation, style: const TextStyle(height: 1.5)),
            if (_detailedExplanation != null) ...[
              const Divider(height: 24),
              Text(_detailedExplanation!, style: const TextStyle(height: 1.5)),
            ],
            if (_loadingDetailed)
              const Center(child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: CircularProgressIndicator(strokeWidth: 2),
              )),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(Question q) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (_detailedExplanation == null && !_loadingDetailed)
          OutlinedButton.icon(
            onPressed: _loadDetailedExplanation,
            icon: const Icon(Icons.school, size: 18),
            label: const Text('Explain in Detail'),
          ),
        OutlinedButton.icon(
          onPressed: _generateFlashcards,
          icon: const Icon(Icons.style, size: 18),
          label: const Text('Make Flashcard'),
        ),
        if (widget.tts.isEnabled && _detailedExplanation != null)
          OutlinedButton.icon(
            onPressed: () => widget.tts.speak(_detailedExplanation!),
            icon: const Icon(Icons.volume_up, size: 18),
            label: const Text('Read'),
          ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        children: [
          if (!_answered)
            TextButton(onPressed: _skip, child: const Text('Skip')),
          const Spacer(),
          FilledButton.icon(
            onPressed: _answered ? _next : null,
            icon: Icon(_currentIndex < _questions.length - 1
                ? Icons.arrow_forward : Icons.done_all),
            label: Text(_currentIndex < _questions.length - 1
                ? 'Next Question' : 'See Results'),
          ),
        ],
      ),
    );
  }
}
