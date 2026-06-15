import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../models/question.dart';
import '../../models/quiz_attempt.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../../services/github_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_widgets.dart';

class ResultScreen extends StatefulWidget {
  final List<QuizAttempt> attempts;
  final List<Question> questions;
  final String source;
  final GeminiService gemini;
  final TtsService tts;

  const ResultScreen({
    super.key,
    required this.attempts,
    required this.questions,
    required this.source,
    required this.gemini,
    required this.tts,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  final Map<int, String> _aiExplanations = {};
  final Set<int> _loadingAi = {};
  bool _progressSaved = false;

  @override
  void initState() {
    super.initState();
    _saveProgress();
  }

  Future<void> _saveProgress() async {
    if (_progressSaved) return;
    _progressSaved = true;
    final correct = widget.attempts.where((a) => a.isCorrect).length;
    await ProgressService.record(widget.source, widget.attempts.length, correct);
  }

  int get _correct => widget.attempts.where((a) => a.isCorrect).length;
  int get _incorrect => widget.attempts.where((a) => !a.isCorrect && a.selectedOption != null).length;
  int get _unattempted => widget.attempts.where((a) => a.selectedOption == null).length;
  double get _accuracy => widget.attempts.isNotEmpty ? _correct / widget.attempts.length * 100 : 0;
  int get _neetScore => _correct * 4 - _incorrect;

  Color get _moodColor => _accuracy >= 70 ? AppTheme.correct : _accuracy >= 45 ? AppTheme.warning : AppTheme.incorrect;
  String get _moodMessage {
    if (_accuracy >= 80) return 'Outstanding! You\'re exam-ready 🎉';
    if (_accuracy >= 65) return 'Great job — keep this up! 💪';
    if (_accuracy >= 45) return 'Good effort — review the misses 📘';
    return 'Every attempt makes you stronger 🌱';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: TabBarView(children: [_buildSummary(), _buildReview()])),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return CompactGradientHeader(
      title: 'Your Results',
      subtitle: 'Score, NEET projection & full review',
      backIcon: Icons.home_rounded,
      onBack: () => Navigator.popUntil(context, (r) => r.isFirst),
      bottom: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.all(4),
        child: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(11)),
          ),
          labelColor: AppTheme.primary,
          unselectedLabelColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          tabs: const [Tab(text: 'Summary'), Tab(text: 'Review All')],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: Column(
        children: [
          FadeSlideIn(child: _buildScoreHero()),
          const SizedBox(height: 18),
          FadeSlideIn(index: 1, child: _buildScoreRow()),
          const SizedBox(height: 14),
          FadeSlideIn(index: 2, child: _buildNeetScore()),
          const SizedBox(height: 18),
          FadeSlideIn(index: 3, child: _buildSubjectBreakdown()),
          const SizedBox(height: 26),
          Row(children: [
            Expanded(child: _outlineBtn('Home', Icons.home_rounded,
              () => Navigator.popUntil(context, (r) => r.isFirst))),
            const SizedBox(width: 12),
            Expanded(child: _gradientBtn('New Quiz', Icons.refresh_rounded,
              () => Navigator.pop(context))),
          ]),
        ],
      ),
    );
  }

  Widget _buildScoreHero() {
    return SoftCard(
      gradient: LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [_moodColor.withValues(alpha: 0.12), _moodColor.withValues(alpha: 0.04)],
      ),
      shadow: const [],
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 78,
            lineWidth: 14,
            animation: true,
            animationDuration: 900,
            percent: (_accuracy / 100).clamp(0.0, 1.0),
            circularStrokeCap: CircularStrokeCap.round,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${_accuracy.toStringAsFixed(0)}%', style: TextStyle(
                  fontSize: 34, fontWeight: FontWeight.w800, color: _moodColor, letterSpacing: -1)),
                Text('accuracy', style: TextStyle(color: AppTheme.inkSoft, fontSize: 13)),
              ],
            ),
            progressColor: _moodColor,
            backgroundColor: _moodColor.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 18),
          Text(_moodMessage, textAlign: TextAlign.center, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink)),
        ],
      ),
    );
  }

  Widget _buildScoreRow() {
    return Row(children: [
      _scoreBox('Correct', _correct, AppTheme.correct, Icons.check_circle_rounded),
      const SizedBox(width: 12),
      _scoreBox('Wrong', _incorrect, AppTheme.incorrect, Icons.cancel_rounded),
      const SizedBox(width: 12),
      _scoreBox('Skipped', _unattempted, AppTheme.inkFaint, Icons.remove_circle_rounded),
    ]);
  }

  Widget _scoreBox(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text('$count', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: TextStyle(color: AppTheme.inkSoft, fontSize: 11.5, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }

  Widget _buildNeetScore() {
    final positive = _neetScore >= 0;
    return SoftCard(
      gradient: positive ? AppTheme.mintGradient : LinearGradient(
        colors: [AppTheme.incorrect.withValues(alpha: 0.85), AppTheme.incorrect]),
      shadow: AppTheme.coloredShadow(positive ? AppTheme.secondary : AppTheme.incorrect),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.military_tech_rounded, color: Colors.white, size: 26),
        const SizedBox(width: 12),
        const Text('NEET Score', style: TextStyle(
          fontWeight: FontWeight.w600, color: Colors.white, fontSize: 15)),
        const SizedBox(width: 10),
        Text('${positive ? '+' : ''}$_neetScore', style: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(width: 6),
        Text('(+4/−1)', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
      ]),
    );
  }

  Widget _buildSubjectBreakdown() {
    final result = MockTestResultHelper.subjectBreakdown(widget.attempts);
    if (result.isEmpty) return const SizedBox.shrink();

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.insights_rounded, size: 18, color: AppTheme.primary),
            SizedBox(width: 8),
            Text('Subject Breakdown', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
          ]),
          const SizedBox(height: 14),
          ...result.entries.map((e) {
            final pct = e.value;
            final color = pct >= 70 ? AppTheme.correct : pct >= 50 ? AppTheme.warning : AppTheme.incorrect;
            final label = GithubService.subjectDisplayNames[e.key] ?? e.key;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                    Text('${pct.toStringAsFixed(0)}%', style: TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
                  ]),
                  const SizedBox(height: 6),
                  SoftProgressBar(value: pct / 100, color: color, height: 7),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReview() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      itemCount: widget.attempts.length,
      itemBuilder: (_, i) {
        final attempt = widget.attempts[i];
        final q = widget.questions.firstWhere((q) => q.id == attempt.questionId,
          orElse: () => widget.questions[i]);
        return FadeSlideIn(index: i, child: _buildReviewCard(i, attempt, q));
      },
    );
  }

  Widget _buildReviewCard(int i, QuizAttempt attempt, Question q) {
    final isCorrect = attempt.isCorrect;
    final skipped = attempt.selectedOption == null;
    final statusColor = isCorrect ? AppTheme.correct : skipped ? AppTheme.inkFaint : AppTheme.incorrect;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  isCorrect ? Icons.check_rounded : skipped ? Icons.remove_rounded : Icons.close_rounded,
                  color: statusColor, size: 16),
              ),
              const SizedBox(width: 10),
              Text('Question ${i + 1}', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
              const Spacer(),
              SoftChip(
                label: isCorrect ? 'Correct' : skipped ? 'Skipped' : 'Wrong',
                color: statusColor),
            ]),
            const SizedBox(height: 12),
            Text(q.stem, style: TextStyle(height: 1.5, color: AppTheme.ink, fontWeight: FontWeight.w500)),
            const SizedBox(height: 12),
            if (attempt.selectedOption != null)
              _answerRow('Your answer', attempt.selectedOption!, q, isCorrect ? AppTheme.correct : AppTheme.incorrect),
            if (!isCorrect)
              _answerRow('Correct', q.correctOption, q, AppTheme.correct),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
              child: Text(q.explanation, style: TextStyle(color: AppTheme.inkSoft, fontSize: 13, height: 1.5)),
            ),
            if (_aiExplanations.containsKey(i)) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.lavender.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                child: Text(_aiExplanations[i]!, style: TextStyle(fontSize: 13, height: 1.5, color: AppTheme.ink)),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 8, children: [
              if (!_aiExplanations.containsKey(i))
                _miniBtn(
                  _loadingAi.contains(i) ? null : () => _explainWithAi(i, q),
                  Icons.auto_awesome_rounded, 'Explain with AI', AppTheme.lavender,
                  loading: _loadingAi.contains(i)),
              if (_aiExplanations.containsKey(i) && widget.tts.isEnabled)
                _miniBtn(() => widget.tts.speak(_aiExplanations[i]!),
                  Icons.volume_up_rounded, 'Read', AppTheme.primary),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _miniBtn(VoidCallback? onTap, IconData icon, String label, Color color, {bool loading = false}) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          loading
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon, size: 15, color: color),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ]),
      ),
    );
  }

  Widget _answerRow(String label, String option, Question q, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text('$option. ${q.optionText(option)}',
          style: TextStyle(fontSize: 13.5, color: color, fontWeight: FontWeight.w600, height: 1.4))),
      ]),
    );
  }

  Widget _outlineBtn(String label, IconData icon, VoidCallback onTap) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.rMd)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _gradientBtn(String label, IconData icon, VoidCallback onTap) {
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: AppTheme.qbankGradient,
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          boxShadow: AppTheme.coloredShadow(AppTheme.primary)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Future<void> _explainWithAi(int index, Question q) async {
    setState(() => _loadingAi.add(index));
    final exp = await widget.gemini.getDetailedExplanation(q);
    if (mounted) {
      setState(() {
        _aiExplanations[index] = exp;
        _loadingAi.remove(index);
      });
    }
  }
}

class MockTestResultHelper {
  static Map<String, double> subjectBreakdown(List<QuizAttempt> attempts) {
    final Map<String, List<bool>> bySubject = {};
    for (final a in attempts) {
      if (a.selectedOption == null) continue;
      bySubject.putIfAbsent(a.subject, () => []).add(a.isCorrect);
    }
    return {
      for (final entry in bySubject.entries)
        entry.key: entry.value.where((v) => v).length / entry.value.length * 100,
    };
  }
}
