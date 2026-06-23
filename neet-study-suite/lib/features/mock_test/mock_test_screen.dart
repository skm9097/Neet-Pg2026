import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/question.dart';
import '../../models/quiz_attempt.dart';
import '../../services/gemini_service.dart';
import '../../services/github_service.dart';
import '../../services/markdown_parser.dart';
import '../../services/progress_service.dart';
import '../../services/github_sync_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_widgets.dart';

class MockTestScreen extends StatefulWidget {
  final GeminiService gemini;
  const MockTestScreen({super.key, required this.gemini});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<ProgressEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _loadHistory();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _loadHistory() async {
    final h = await ProgressService.loadAll();
    if (mounted) setState(() => _history = h);
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.syncFrom(context);
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            gradient: AppTheme.mockGradient,
            height: 186,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _backButton(),
                  const SizedBox(width: 14),
                  const Text('Mock Test', style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                ]),
                const Spacer(),
                Text('Simulate the real exam, track your growth',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5)),
                const SizedBox(height: 14),
                _buildTabSelector(),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_buildStartTab(), _buildAnalyticsTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backButton() => TapScale(
    onTap: () => Navigator.pop(context),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
    ),
  );

  Widget _buildTabSelector() {
    final labels = ['Start Test', 'Analytics'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = _tabs.index == i;
          return Expanded(
            child: TapScale(
              onTap: () => _tabs.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(13)),
                child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(
                  color: active ? AppTheme.secondary : Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStartTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(index: 0, child: _buildModeCard(
            icon: Icons.timer_rounded,
            title: 'Full Mock Test',
            subtitle: '200 Questions · 3.5 Hours',
            tag: 'Exam format',
            gradient: AppTheme.mockGradient,
            color: AppTheme.secondary,
            onTap: () => _startTest(200, const Duration(hours: 3, minutes: 30)),
          )),
          const SizedBox(height: 14),
          FadeSlideIn(index: 1, child: _buildModeCard(
            icon: Icons.flash_on_rounded,
            title: 'Quick Test',
            subtitle: '50 Questions · 50 Minutes',
            tag: 'Daily warm-up',
            gradient: AppTheme.flashcardGradient,
            color: AppTheme.secondary,
            onTap: () => _startTest(50, const Duration(minutes: 50)),
          )),
          const SizedBox(height: 14),
          FadeSlideIn(index: 2, child: _buildModeCard(
            icon: Icons.bolt_rounded,
            title: 'Subject Sprint',
            subtitle: '30 Questions · 30 Minutes',
            tag: 'Focused',
            gradient: AppTheme.tutorGradient,
            color: AppTheme.lavender,
            onTap: () => _startTest(30, const Duration(minutes: 30)),
          )),
          const SizedBox(height: 26),
          Text('Marking Scheme', style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
          const SizedBox(height: 12),
          SoftCard(
            child: Column(children: [
              _SchemeRow(Icons.check_circle_rounded, 'Correct answer', '+4', AppTheme.correct),
              _SchemeRow(Icons.cancel_rounded, 'Wrong answer', '−1', AppTheme.incorrect),
              _SchemeRow(Icons.remove_circle_rounded, 'Unattempted', '0', AppTheme.inkFaint),
              _SchemeRow(Icons.casino_rounded, 'Blind guess EV', '+0.25', AppTheme.primary, last: true),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon, required String title, required String subtitle,
    required String tag, required LinearGradient gradient, required Color color,
    required VoidCallback onTap,
  }) {
    return _SweepBeam(
      child: SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: gradient, borderRadius: BorderRadius.circular(18),
              boxShadow: AppTheme.coloredShadow(color)),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(title, style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                  const SizedBox(width: 8),
                  SoftChip(label: tag, color: color),
                ]),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: AppTheme.inkSoft, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded, size: 15, color: AppTheme.inkFaint),
        ]),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_history.isEmpty) {
      return SoftEmptyState(
        icon: Icons.insights_rounded,
        color: AppTheme.secondary,
        title: 'No data yet',
        message: 'Complete a quiz or mock test to unlock your performance analytics.',
        action: TapScale(
          onTap: () => _tabs.animateTo(0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppTheme.mockGradient,
              borderRadius: BorderRadius.circular(AppTheme.rMd),
              boxShadow: AppTheme.coloredShadow(AppTheme.secondary)),
            child: const Text('Start a Test', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    final totalAttempted = _history.fold(0, (s, p) => s + p.attempted);
    final totalCorrect = _history.fold(0, (s, p) => s + p.correct);
    final overallAccuracy = totalAttempted > 0 ? totalCorrect / totalAttempted * 100 : 0.0;
    final weak = _history.where((p) => p.accuracy < 50).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(child: _buildSummaryCard(totalAttempted, totalCorrect, overallAccuracy)),
          const SizedBox(height: 20),
          Text('Accuracy by Session', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
          const SizedBox(height: 12),
          FadeSlideIn(index: 1, child: SoftCard(child: SizedBox(height: 170, child: _buildAccuracyChart()))),
          const SizedBox(height: 20),
          Row(children: [
            Icon(Icons.priority_high_rounded, size: 18, color: AppTheme.incorrect),
            SizedBox(width: 6),
            Text('Focus Areas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
          ]),
          const SizedBox(height: 12),
          if (weak.isEmpty)
            SoftCard(
              gradient: AppTheme.mintGradient,
              shadow: AppTheme.coloredShadow(AppTheme.secondary),
              child: Row(children: const [
                Icon(Icons.verified_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('No weak areas — you\'re crushing it! 🎯',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
              ]),
            )
          else
            ...weak.asMap().entries.map((e) => FadeSlideIn(index: e.key, child: _buildWeakAreaTile(e.value))),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int attempted, int correct, double accuracy) {
    final neetScore = correct * 4 - (attempted - correct);
    return SoftCard(
      gradient: AppTheme.mockGradient,
      shadow: AppTheme.coloredShadow(AppTheme.secondary),
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _statItem('$attempted', 'Attempted'),
        _whiteDivider(),
        _statItem('${accuracy.toStringAsFixed(0)}%', 'Accuracy'),
        _whiteDivider(),
        _statItem('${neetScore >= 0 ? '+' : ''}$neetScore', 'NEET Score'),
      ]),
    );
  }

  Widget _whiteDivider() => Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.3));

  Widget _statItem(String value, String label) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
  ]);

  Widget _buildAccuracyChart() {
    final data = _history.take(10).toList();
    if (data.isEmpty) return const SizedBox.shrink();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        barGroups: List.generate(data.length, (i) {
          final pct = data[i].accuracy;
          final color = pct >= 70 ? AppTheme.correct : pct >= 50 ? AppTheme.warning : AppTheme.incorrect;
          return BarChartGroupData(x: i, barRods: [
            BarChartRodData(
              toY: pct, color: color, width: 16,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true, toY: 100, color: color.withValues(alpha: 0.08)),
            ),
          ]);
        }),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
            getTitlesWidget: (v, _) => Text('${v.toInt()}', style: TextStyle(fontSize: 10, color: AppTheme.inkFaint)))),
          bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(drawVerticalLine: false),
        maxY: 100,
      ),
    );
  }

  Widget _buildWeakAreaTile(ProgressEntry entry) {
    final label = entry.source.startsWith('year_')
        ? 'Year ${entry.source.substring(5)}'
        : entry.source.startsWith('subject_')
            ? (GithubService.subjectDisplayNames[entry.source.substring(8)] ?? entry.source.substring(8))
            : entry.source;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          IconBadge(icon: Icons.trending_down_rounded, color: AppTheme.incorrect, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
                const SizedBox(height: 6),
                SoftProgressBar(value: entry.accuracy / 100, color: AppTheme.incorrect, height: 6),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text('${entry.accuracy.toStringAsFixed(0)}%',
            style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.incorrect)),
        ]),
      ),
    );
  }

  Future<void> _startTest(int count, Duration duration) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TimedTestScreen(
        count: count, duration: duration, gemini: widget.gemini)),
    );
    _loadHistory();
  }
}

class _SchemeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool last;
  const _SchemeRow(this.icon, this.label, this.value, this.color, {this.last = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: TextStyle(color: AppTheme.ink, fontSize: 14))),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
    ]),
  );
}

class _TimedTestScreen extends StatefulWidget {
  final int count;
  final Duration duration;
  final GeminiService gemini;
  const _TimedTestScreen({required this.count, required this.duration, required this.gemini});

  @override
  State<_TimedTestScreen> createState() => _TimedTestScreenState();
}

class _TimedTestScreenState extends State<_TimedTestScreen> {
  List<Question> _questions = [];
  bool _loading = true;
  String? _error;
  int _current = 0;
  final Map<int, String> _answers = {};
  late DateTime _startTime;
  late DateTime _endTime;
  late final String _sessionId;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _endTime = _startTime.add(widget.duration);
    final dt = _startTime;
    _sessionId =
        '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}_mock-test-${widget.count}q';
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final service = GithubService();
      final years = [...GithubService.availableYears];
      years.shuffle();
      List<Question> all = [];
      for (final y in years.take(3)) {
        try {
          final md = await service.fetchYearMarkdown(y);
          all.addAll(MarkdownParser.parse(md, source: y));
        } catch (_) {}
        if (all.length >= widget.count * 2) break;
      }
      if (all.isEmpty) throw Exception('No questions found');
      all.shuffle();
      if (mounted) setState(() {
        _questions = all.take(widget.count).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _submit() {
    final attempts = List.generate(_questions.length, (i) => QuizAttempt(
      questionId: _questions[i].id,
      selectedOption: _answers[i],
      isCorrect: _answers[i] == _questions[i].correctOption,
      subject: _questions[i].subject,
    ));

    final correct = attempts.where((a) => a.isCorrect).length;
    final timeTaken = DateTime.now().difference(_startTime);
    final source = 'mock_${widget.count}q';
    ProgressService.record(source, attempts.length, correct, timeSpent: timeTaken);

    GithubSyncService.processBatchMistakes(
      attempts: attempts,
      questions: _questions,
      sessionId: _sessionId,
      gemini: widget.gemini,
      correct: correct,
      timeTaken: timeTaken,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _MockResultScreen(
        attempts: attempts, questions: _questions, timeTaken: DateTime.now().difference(_startTime))),
    );
  }

  Duration get _timeRemaining {
    final rem = _endTime.difference(DateTime.now());
    return rem.isNegative ? Duration.zero : rem;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Scaffold(
      body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: AppTheme.mockGradient, shape: BoxShape.circle,
            boxShadow: AppTheme.coloredShadow(AppTheme.secondary)),
          child: const SizedBox(width: 30, height: 30,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))),
        const SizedBox(height: 20),
        Text('Setting up your test…', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink)),
      ])),
    );
    if (_error != null) return Scaffold(
      body: SoftEmptyState(
        icon: Icons.cloud_off_rounded, color: AppTheme.incorrect,
        title: 'Could not load test', message: _error!,
        action: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back'))),
    );

    final q = _questions[_current];
    final rem = _timeRemaining;
    final isLowTime = rem.inMinutes < 10;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(children: [
                Row(children: [
                  TapScale(
                    onTap: () => _confirmExit(),
                    child: Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.secondary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)),
                      child: Icon(Icons.close_rounded, size: 20, color: AppTheme.secondary)),
                  ),
                  const SizedBox(width: 12),
                  Text('Question ${_current + 1} / ${_questions.length}',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isLowTime ? AppTheme.incorrect : AppTheme.secondary).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(30)),
                    child: Row(children: [
                      Icon(Icons.timer_rounded, size: 15, color: isLowTime ? AppTheme.incorrect : AppTheme.secondary),
                      const SizedBox(width: 6),
                      Text('${rem.inMinutes.toString().padLeft(2, '0')}:${(rem.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: TextStyle(color: isLowTime ? AppTheme.incorrect : AppTheme.secondary,
                          fontWeight: FontWeight.w800, fontSize: 14)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                SoftProgressBar(value: (_current + 1) / _questions.length, color: AppTheme.secondary, height: 7),
              ]),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                child: SingleChildScrollView(
                  key: ValueKey(_current),
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SoftCard(
                        padding: const EdgeInsets.all(20),
                        child: Text(q.stem, style: TextStyle(
                          fontSize: 16, height: 1.6, color: AppTheme.ink, fontWeight: FontWeight.w500)),
                      ),
                      const SizedBox(height: 16),
                      ...['A', 'B', 'C', 'D'].map((opt) => _buildOption(q, opt)),
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

  Widget _buildOption(Question q, String opt) {
    final selected = _answers[_current] == opt;
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: TapScale(
        onTap: () => setState(() => _answers[_current] = opt),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: selected ? AppTheme.secondary.withValues(alpha: 0.10) : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.rMd),
            border: Border.all(
              color: selected ? AppTheme.secondary : AppTheme.secondary.withValues(alpha: 0.10),
              width: selected ? 1.8 : 1.2),
            boxShadow: selected ? AppTheme.coloredShadow(AppTheme.secondary) : AppTheme.cardShadow,
          ),
          child: Row(children: [
            Container(
              width: 34, height: 34, alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppTheme.secondary : AppTheme.secondary.withValues(alpha: 0.10)),
              child: Text(opt, style: TextStyle(
                fontWeight: FontWeight.w800, fontSize: 15,
                color: selected ? Colors.white : AppTheme.secondary)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(q.optionText(opt), style: TextStyle(
              color: AppTheme.ink, height: 1.4, fontSize: 14.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500))),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final isLast = _current >= _questions.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.rLg)),
        boxShadow: [BoxShadow(color: AppTheme.ink.withValues(alpha: 0.07), blurRadius: 22, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          if (_current > 0)
            TapScale(
              onTap: () => setState(() => _current--),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: AppTheme.inkFaint.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AppTheme.rMd)),
                child: Icon(Icons.arrow_back_rounded, color: AppTheme.inkSoft, size: 20)),
            ),
          if (_current > 0) const SizedBox(width: 12),
          Expanded(
            child: TapScale(
              onTap: isLast ? _submit : () => setState(() => _current++),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 17),
                decoration: BoxDecoration(
                  gradient: AppTheme.mockGradient,
                  borderRadius: BorderRadius.circular(AppTheme.rMd),
                  boxShadow: AppTheme.coloredShadow(AppTheme.secondary)),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(isLast ? 'Submit Test' : 'Next Question',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
                  const SizedBox(width: 8),
                  Icon(isLast ? Icons.done_all_rounded : Icons.arrow_forward_rounded, color: Colors.white, size: 21),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _confirmExit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: const Text('Quit test?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Your progress in this test won\'t be saved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep Going')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.incorrect),
            onPressed: () => Navigator.pop(context, true), child: const Text('Quit')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context);
  }
}

class _MockResultScreen extends StatelessWidget {
  final List<QuizAttempt> attempts;
  final List<Question> questions;
  final Duration timeTaken;
  const _MockResultScreen({required this.attempts, required this.questions, required this.timeTaken});

  int get _correct => attempts.where((a) => a.isCorrect).length;
  int get _incorrect => attempts.where((a) => !a.isCorrect && a.selectedOption != null).length;
  int get _unattempted => attempts.where((a) => a.selectedOption == null).length;
  double get _accuracy => attempts.isNotEmpty ? _correct / attempts.length * 100 : 0;
  int get _neetScore => _correct * 4 - _incorrect;
  int get _maxScore => attempts.length * 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
          child: Column(
            children: [
              Row(children: [
                TapScale(
                  onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.secondary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(13)),
                    child: Icon(Icons.home_rounded, size: 20, color: AppTheme.secondary)),
                ),
                const SizedBox(width: 12),
                Text('Test Results', style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink)),
              ]),
              const SizedBox(height: 20),
              FadeSlideIn(child: _SweepBeam(
                period: const Duration(seconds: 5),
                child: SoftCard(
                gradient: AppTheme.mockGradient,
                shadow: AppTheme.coloredShadow(AppTheme.secondary),
                padding: const EdgeInsets.all(26),
                child: Column(children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: _neetScore.toDouble()),
                    duration: const Duration(milliseconds: 1600),
                    curve: Curves.easeOutCubic,
                    builder: (_, val, __) => Text(
                      val >= 0 ? '+${val.round()}' : '${val.round()}',
                      style: const TextStyle(
                        color: Colors.white, fontSize: 52, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  ),
                  Text('out of $_maxScore  ·  NEET Score', style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9))),
                  const SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    _stat('${_accuracy.toStringAsFixed(0)}%', 'Accuracy'),
                    _stat('$_correct', 'Correct'),
                    _stat('$_incorrect', 'Wrong'),
                    _stat('$_unattempted', 'Skipped'),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.schedule_rounded, color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                      Text('${timeTaken.inMinutes}m ${timeTaken.inSeconds % 60}s',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12.5)),
                    ]),
                  ),
                ]),
              ))),
              const SizedBox(height: 18),
              FadeSlideIn(index: 1, child: _buildSubjectBreakdown()),
              const SizedBox(height: 24),
              TapScale(
                onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: AppTheme.mockGradient,
                    borderRadius: BorderRadius.circular(AppTheme.rMd),
                    boxShadow: AppTheme.coloredShadow(AppTheme.secondary)),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.home_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Back to Home', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stat(String val, String label) => Column(children: [
    Text(val, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11)),
  ]);

  Widget _buildSubjectBreakdown() {
    final Map<String, List<bool>> bySubject = {};
    for (final a in attempts) {
      if (a.selectedOption == null) continue;
      bySubject.putIfAbsent(a.subject, () => []).add(a.isCorrect);
    }
    if (bySubject.isEmpty) return const SizedBox.shrink();

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.insights_rounded, size: 18, color: AppTheme.secondary),
            SizedBox(width: 8),
            Text('Subject Performance', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
          ]),
          const SizedBox(height: 14),
          ...bySubject.entries.map((entry) {
            final pct = entry.value.where((v) => v).length / entry.value.length * 100;
            final color = pct >= 70 ? AppTheme.correct : pct >= 50 ? AppTheme.warning : AppTheme.incorrect;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(GithubService.subjectDisplayNames[entry.key] ?? entry.key,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                  Text('${pct.toStringAsFixed(0)}%  ·  ${entry.value.length} Qs',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
                ]),
                const SizedBox(height: 6),
                SoftProgressBar(value: pct / 100, color: color, height: 7),
              ]),
            );
          }),
        ],
      ),
    );
  }
}

// ── Periodic diagonal shimmer sweep overlay ──────────────────────────────────

class _SweepBeam extends StatefulWidget {
  final Widget child;
  final Duration period;
  const _SweepBeam({required this.child, this.period = const Duration(seconds: 4)});

  @override
  State<_SweepBeam> createState() => _SweepBeamState();
}

class _SweepBeamState extends State<_SweepBeam> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.rLg),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => CustomPaint(
          foregroundPainter: _BeamPainter(_ctrl.value),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _BeamPainter extends CustomPainter {
  final double t;
  _BeamPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    if (t > 0.60) return;
    final progress = (t / 0.60).clamp(0.0, 1.0);
    final x = -size.width * 0.15 + progress * (size.width * 1.3);
    const halfW = 45.0;
    final rect = Rect.fromLTWH(x - halfW, 0, halfW * 2, size.height);
    final shader = const LinearGradient(
      colors: [Colors.transparent, Color(0x18FFFFFF), Color(0x22FFFFFF), Color(0x18FFFFFF), Colors.transparent],
      stops: [0.0, 0.25, 0.5, 0.75, 1.0],
    ).createShader(rect);

    final path = Path()
      ..moveTo(x - halfW - 18, 0)
      ..lineTo(x + halfW - 18, 0)
      ..lineTo(x + halfW + 18, size.height)
      ..lineTo(x - halfW + 18, size.height)
      ..close();

    canvas.drawPath(path, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _BeamPainter old) => old.t != t;
}
