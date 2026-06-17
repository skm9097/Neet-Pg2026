import 'package:flutter/material.dart';
import '../../models/question.dart';
import '../../models/quiz_attempt.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/github_service.dart';
import '../../services/markdown_parser.dart';
import '../../services/bookmark_service.dart';
import '../../services/flashcard_service.dart';
import '../../services/github_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_widgets.dart';
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
  late final String _sessionId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _sessionId =
        '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}_${widget.mode}-${widget.source}';
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
        final years = [...GithubService.availableYears];
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

    if (!isCorrect) {
      GithubSyncService.queueMistake(
        question: q,
        wrongOption: option,
        sessionId: _sessionId,
        gemini: widget.gemini,
      );
    }

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
        SnackBar(
          content: Text('${cards.length} flashcard(s) added!'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.secondary,
          shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusSm),
        ));
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
    AppTheme.syncFrom(context);
    if (_loading) return _buildLoading();
    if (_error != null) return _buildError();

    final q = _questions[_currentIndex];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(q),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0.06, 0), end: Offset.zero).animate(anim),
                    child: child),
                ),
                child: SingleChildScrollView(
                  key: ValueKey(_currentIndex),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStemCard(q),
                      const SizedBox(height: 18),
                      ...['A', 'B', 'C', 'D'].map((opt) => _buildOptionButton(q, opt)),
                      if (_answered) ...[
                        const SizedBox(height: 14),
                        _buildFeedbackCard(q),
                        const SizedBox(height: 12),
                        _buildActionRow(q),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildLoading() => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppTheme.qbankGradient,
              shape: BoxShape.circle,
              boxShadow: AppTheme.coloredShadow(AppTheme.primary),
            ),
            child: const SizedBox(
              width: 30, height: 30,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
            ),
          ),
          const SizedBox(height: 22),
          Text('Preparing your questions…',
            style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink, fontSize: 15)),
          const SizedBox(height: 4),
          Text('Fetching from the question bank',
            style: TextStyle(color: AppTheme.inkSoft, fontSize: 12.5)),
        ],
      ),
    ),
  );

  Widget _buildError() => Scaffold(
    body: SoftEmptyState(
      icon: Icons.cloud_off_rounded,
      color: AppTheme.incorrect,
      title: 'Could not load questions',
      message: _error ?? 'Check your internet connection and try again.',
      action: FilledButton.icon(
        onPressed: () { setState(() { _loading = true; _error = null; }); _loadQuestions(); },
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Try Again'),
      ),
    ),
  );

  Widget _buildTopBar(Question q) {
    final subjectLabel = GithubService.subjectDisplayNames[q.subject] ?? q.subject;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        children: [
          Row(children: [
            TapScale(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.arrow_back_rounded, size: 20, color: AppTheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Question ${_currentIndex + 1} of ${_questions.length}',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink)),
                  Text(subjectLabel + (q.year != null ? ' · ${q.year}' : ''),
                    style: TextStyle(fontSize: 12, color: AppTheme.inkSoft)),
                ],
              ),
            ),
            _circleAction(
              widget.tts.isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              () async { await widget.tts.toggle(); setState(() {}); },
              active: widget.tts.isEnabled),
            const SizedBox(width: 8),
            _circleAction(
              _bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              () async {
                if (_bookmarked) {
                  await BookmarkService.remove(q.id);
                } else {
                  await BookmarkService.add(q);
                }
                setState(() => _bookmarked = !_bookmarked);
              },
              active: _bookmarked, activeColor: AppTheme.accent),
          ]),
          const SizedBox(height: 14),
          SoftProgressBar(value: (_currentIndex + 1) / _questions.length, height: 7),
        ],
      ),
    );
  }

  Widget _circleAction(IconData icon, VoidCallback onTap, {bool active = false, Color? activeColor}) {
    final color = activeColor ?? AppTheme.primary;
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.14) : AppTheme.inkFaint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, size: 20, color: active ? color : AppTheme.inkSoft),
      ),
    );
  }

  Widget _buildStemCard(Question q) {
    return SoftCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.help_outline_rounded, size: 16, color: AppTheme.primary.withValues(alpha: 0.5)),
            const SizedBox(width: 6),
            Text('QUESTION', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1,
              color: AppTheme.primary.withValues(alpha: 0.6))),
          ]),
          const SizedBox(height: 12),
          Text(q.stem, style: TextStyle(
            fontSize: 16.5, height: 1.6, color: AppTheme.ink, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildOptionButton(Question q, String opt) {
    final isSelected = _selected == opt;
    final isCorrect = opt == q.correctOption;

    Color bg = AppTheme.cardBg;
    Color border = AppTheme.primary.withValues(alpha: 0.10);
    Color circleBg = AppTheme.primary.withValues(alpha: 0.10);
    Color circleText = AppTheme.primary;
    Color textColor = AppTheme.ink;
    IconData? badge;
    Color badgeColor = AppTheme.correct;

    if (_answered) {
      if (isCorrect) {
        bg = AppTheme.correct.withValues(alpha: 0.10);
        border = AppTheme.correct;
        circleBg = AppTheme.correct; circleText = Colors.white;
        textColor = AppTheme.ink;
        badge = Icons.check_rounded; badgeColor = AppTheme.correct;
      } else if (isSelected) {
        bg = AppTheme.incorrect.withValues(alpha: 0.10);
        border = AppTheme.incorrect;
        circleBg = AppTheme.incorrect; circleText = Colors.white;
        badge = Icons.close_rounded; badgeColor = AppTheme.incorrect;
      } else {
        circleBg = AppTheme.inkFaint.withValues(alpha: 0.12);
        circleText = AppTheme.inkSoft;
        textColor = AppTheme.inkSoft;
      }
    } else if (isSelected) {
      border = AppTheme.primary;
      bg = AppTheme.primary.withValues(alpha: 0.06);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TapScale(
        onTap: _answered ? null : () => _answer(opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppTheme.rMd),
            border: Border.all(color: border, width: isSelected || (_answered && isCorrect) ? 1.8 : 1.2),
            boxShadow: (_answered && isCorrect) || (isSelected)
                ? AppTheme.coloredShadow(border).map((s) => s.copyWith(blurRadius: 14)).toList()
                : AppTheme.cardShadow,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 34, height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(shape: BoxShape.circle, color: circleBg),
                child: Text(opt, style: TextStyle(fontWeight: FontWeight.w800, color: circleText, fontSize: 15)),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(q.optionText(opt),
                style: TextStyle(color: textColor, height: 1.4, fontSize: 14.5,
                  fontWeight: (_answered && isCorrect) ? FontWeight.w600 : FontWeight.w500))),
              if (badge != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(color: badgeColor, shape: BoxShape.circle),
                  child: Icon(badge, color: Colors.white, size: 15)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedbackCard(Question q) {
    final isCorrect = _selected == q.correctOption;
    return FadeSlideIn(
      child: SoftCard(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: isCorrect
              ? [AppTheme.correct.withValues(alpha: 0.10), AppTheme.greenSoft.withValues(alpha: 0.12)]
              : [AppTheme.primary.withValues(alpha: 0.07), AppTheme.lavender.withValues(alpha: 0.10)],
        ),
        shadow: const [],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: (isCorrect ? AppTheme.correct : AppTheme.primary).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(isCorrect ? Icons.celebration_rounded : Icons.lightbulb_rounded,
                  size: 16, color: isCorrect ? AppTheme.correct : AppTheme.primary),
              ),
              const SizedBox(width: 8),
              Text(isCorrect ? 'Nice work!' : 'Let\'s learn this',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14,
                  color: isCorrect ? AppTheme.correct : AppTheme.primary)),
              const Spacer(),
              SoftChip(label: 'AI', icon: Icons.auto_awesome_rounded, color: AppTheme.lavender),
            ]),
            const SizedBox(height: 12),
            if (_loadingFeedback)
              Row(children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Thinking…', style: TextStyle(color: AppTheme.inkSoft)),
              ])
            else
              Text(_feedback ?? q.explanation, style: TextStyle(height: 1.55, color: AppTheme.ink, fontSize: 14)),
            if (_detailedExplanation != null) ...[
              Divider(height: 26, color: AppTheme.ink.withValues(alpha: 0.06)),
              Text(_detailedExplanation!, style: TextStyle(height: 1.55, color: AppTheme.ink, fontSize: 14)),
            ],
            if (_loadingDetailed)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionRow(Question q) {
    return Wrap(
      spacing: 10, runSpacing: 10,
      children: [
        if (_detailedExplanation == null && !_loadingDetailed)
          _pillButton(Icons.school_rounded, 'Explain in detail', AppTheme.primary, _loadDetailedExplanation),
        _pillButton(Icons.style_rounded, 'Make flashcard', AppTheme.secondary, _generateFlashcards),
        if (widget.tts.isEnabled && _detailedExplanation != null)
          _pillButton(Icons.volume_up_rounded, 'Read aloud', AppTheme.lavender,
            () => widget.tts.speak(_detailedExplanation!)),
      ],
    );
  }

  Widget _pillButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _currentIndex >= _questions.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.rLg)),
        boxShadow: [BoxShadow(
          color: AppTheme.ink.withValues(alpha: 0.07),
          blurRadius: 22, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (!_answered)
              TapScale(
                onTap: _skip,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.inkFaint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppTheme.rMd)),
                  child: Text('Skip', style: TextStyle(
                    color: AppTheme.inkSoft, fontWeight: FontWeight.w600)),
                ),
              ),
            if (!_answered) const SizedBox(width: 12),
            Expanded(
              child: TapScale(
                onTap: _answered ? _next : null,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _answered ? 1 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 17),
                    decoration: BoxDecoration(
                      gradient: AppTheme.qbankGradient,
                      borderRadius: BorderRadius.circular(AppTheme.rMd),
                      boxShadow: _answered ? AppTheme.coloredShadow(AppTheme.primary) : null,
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(isLast ? 'See Results' : 'Next Question',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                      const SizedBox(width: 8),
                      Icon(isLast ? Icons.done_all_rounded : Icons.arrow_forward_rounded,
                        color: Colors.white, size: 21),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
