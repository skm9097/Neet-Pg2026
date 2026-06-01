import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/question.dart';
import '../../models/quiz_attempt.dart';
import '../../services/gemini_service.dart';
import '../../services/github_service.dart';
import '../../services/markdown_parser.dart';
import '../../services/progress_service.dart';
import '../../core/theme/app_theme.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mock Test'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Start Test'), Tab(text: 'Analytics')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildStartTab(), _buildAnalyticsTab()],
      ),
    );
  }

  Widget _buildStartTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModeCard(
            icon: Icons.timer,
            title: 'Full Mock Test',
            subtitle: '200 Questions • 3.5 Hours (NEET-PG format)',
            color: AppTheme.primary,
            onTap: () => _startTest(200, Duration(hours: 3, minutes: 30)),
          ),
          const SizedBox(height: 12),
          _buildModeCard(
            icon: Icons.flash_on,
            title: 'Quick Test (50 Qs)',
            subtitle: '50 Questions • 50 Minutes',
            color: AppTheme.secondary,
            onTap: () => _startTest(50, Duration(minutes: 50)),
          ),
          const SizedBox(height: 12),
          _buildModeCard(
            icon: Icons.subject,
            title: 'Subject Test (30 Qs)',
            subtitle: '30 Questions • 30 Minutes',
            color: AppTheme.accent,
            onTap: () => _startTest(30, Duration(minutes: 30)),
          ),
          const SizedBox(height: 24),
          const Text('Marking Scheme',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _SchemeRow('Correct answer', '+4 marks', AppTheme.correct),
                  _SchemeRow('Wrong answer', '−1 mark', AppTheme.incorrect),
                  _SchemeRow('Unattempted', '0 marks', Colors.grey),
                  _SchemeRow('Blind guess EV', '+0.25 expected', Colors.blue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required IconData icon, required String title, required String subtitle,
    required Color color, required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No data yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Complete quizzes to see your analytics here.',
              style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _tabs.animateTo(0),
              child: const Text('Start a Test'),
            ),
          ],
        ),
      );
    }

    final totalAttempted = _history.fold(0, (s, p) => s + p.attempted);
    final totalCorrect = _history.fold(0, (s, p) => s + p.correct);
    final overallAccuracy = totalAttempted > 0 ? totalCorrect / totalAttempted * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(totalAttempted, totalCorrect, overallAccuracy),
          const SizedBox(height: 16),
          const Text('By Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _buildAccuracyChart(),
          const SizedBox(height: 16),
          const Text('Weak Areas',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.incorrect)),
          const SizedBox(height: 8),
          ..._history.where((p) => p.accuracy < 50).map(_buildWeakAreaTile),
          if (_history.every((p) => p.accuracy >= 50))
            const Card(
              color: Color(0xFFE8F5E9),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: AppTheme.correct),
                    SizedBox(width: 12),
                    Text('No weak areas! Keep it up.', style: TextStyle(color: AppTheme.correct)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(int attempted, int correct, double accuracy) {
    final neetScore = correct * 4 - (attempted - correct);
    return Card(
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('$attempted', 'Attempted', Colors.white),
            _statItem('${accuracy.toStringAsFixed(0)}%', 'Accuracy', Colors.white),
            _statItem('${neetScore >= 0 ? '+' : ''}$neetScore', 'NEET Score', Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String value, String label, Color color) => Column(
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
    ],
  );

  Widget _buildAccuracyChart() {
    final data = _history.take(10).toList();
    if (data.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          barGroups: List.generate(data.length, (i) {
            final pct = data[i].accuracy;
            return BarChartGroupData(x: i, barRods: [
              BarChartRodData(
                toY: pct,
                color: pct >= 70 ? AppTheme.correct : pct >= 50 ? AppTheme.accent : AppTheme.incorrect,
                width: 16, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ]);
          }),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.toInt()}%', style: const TextStyle(fontSize: 10)))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(drawVerticalLine: false),
          maxY: 100,
        ),
      ),
    );
  }

  Widget _buildWeakAreaTile(ProgressEntry entry) {
    final label = entry.source.startsWith('year_')
        ? 'Year ${entry.source.substring(5)}'
        : entry.source.startsWith('subject_')
            ? entry.source.substring(8)
            : entry.source;

    return Card(
      color: Colors.red[50],
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.warning_amber, color: AppTheme.incorrect),
        title: Text(label),
        subtitle: Text('${entry.accuracy.toStringAsFixed(0)}% accuracy'),
        trailing: Text('${entry.attempted} Qs'),
      ),
    );
  }

  Future<void> _startTest(int count, Duration duration) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _TimedTestScreen(
        count: count, duration: duration, gemini: widget.gemini,
      )),
    );
    _loadHistory();
  }
}

class _SchemeRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SchemeRow(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    ),
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

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _endTime = _startTime.add(widget.duration);
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    try {
      final service = GithubService();
      final years = GithubService.availableYears;
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
    final source = 'mock_${widget.count}q';
    ProgressService.record(source, attempts.length, correct);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => _MockResultScreen(
        attempts: attempts, questions: _questions, timeTaken: DateTime.now().difference(_startTime),
      )),
    );
  }

  Duration get _timeRemaining {
    final rem = _endTime.difference(DateTime.now());
    return rem.isNegative ? Duration.zero : rem;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(
      body: Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Loading test...')],
      )),
    );
    if (_error != null) return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(child: Text(_error!)),
    );

    final q = _questions[_current];
    final rem = _timeRemaining;
    final isLowTime = rem.inMinutes < 10;

    return Scaffold(
      appBar: AppBar(
        title: Text('Q ${_current + 1}/${_questions.length}'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text(
              '${rem.inMinutes.toString().padLeft(2, '0')}:${(rem.inSeconds % 60).toString().padLeft(2, '0')}',
              style: TextStyle(
                color: isLowTime ? Colors.red[300] : Colors.white,
                fontWeight: FontWeight.bold, fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_current + 1) / _questions.length),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(q.stem, style: const TextStyle(fontSize: 16, height: 1.6)),
                  )),
                  const SizedBox(height: 12),
                  ...['A', 'B', 'C', 'D'].map((opt) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      color: _answers[_current] == opt ? AppTheme.primary : null,
                      child: InkWell(
                        onTap: () => setState(() => _answers[_current] = opt),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: _answers[_current] == opt
                                    ? Colors.white24 : Colors.blue[50],
                                child: Text(opt, style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _answers[_current] == opt
                                      ? Colors.white : AppTheme.primary,
                                )),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(q.optionText(opt),
                                style: TextStyle(
                                  color: _answers[_current] == opt ? Colors.white : null,
                                ))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            if (_current > 0)
              OutlinedButton.icon(
                onPressed: () => setState(() => _current--),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Prev'),
              ),
            const Spacer(),
            if (_current < _questions.length - 1)
              FilledButton.icon(
                onPressed: () => setState(() => _current++),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Next'),
              )
            else
              FilledButton.icon(
                onPressed: _submit,
                icon: const Icon(Icons.done_all, size: 18),
                label: const Text('Submit Test'),
              ),
          ],
        ),
      ),
    );
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
      appBar: AppBar(title: const Text('Test Results')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Card(
              color: AppTheme.primary,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Text('$_neetScore / $_maxScore',
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)),
                    const Text('NEET Score', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat('${_accuracy.toStringAsFixed(0)}%', 'Accuracy', Colors.white),
                        _stat('$_correct', 'Correct', Colors.greenAccent),
                        _stat('$_incorrect', 'Wrong', Colors.redAccent),
                        _stat('$_unattempted', 'Skipped', Colors.white60),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Time: ${timeTaken.inMinutes}m ${timeTaken.inSeconds % 60}s',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSubjectBreakdown(),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                icon: const Icon(Icons.home),
                label: const Text('Back to Home'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String val, String label, Color color) => Column(
    children: [
      Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: color.withOpacity(0.7), fontSize: 11)),
    ],
  );

  Widget _buildSubjectBreakdown() {
    final Map<String, List<bool>> bySubject = {};
    for (final a in attempts) {
      if (a.selectedOption == null) continue;
      bySubject.putIfAbsent(a.subject, () => []).add(a.isCorrect);
    }
    if (bySubject.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subject Performance',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...bySubject.entries.map((entry) {
          final pct = entry.value.where((v) => v).length / entry.value.length * 100;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(GithubService.subjectDisplayNames[entry.key] ?? entry.key,
                      style: const TextStyle(fontSize: 13)),
                    Text('${pct.toStringAsFixed(0)}%  (${entry.value.length} Qs)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold,
                        color: pct >= 70 ? AppTheme.correct : pct >= 50 ? AppTheme.accent : AppTheme.incorrect)),
                  ],
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: pct / 100, backgroundColor: Colors.grey[200],
                  color: pct >= 70 ? AppTheme.correct : pct >= 50 ? AppTheme.accent : AppTheme.incorrect,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
