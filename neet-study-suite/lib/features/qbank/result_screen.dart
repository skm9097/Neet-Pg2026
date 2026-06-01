import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../../models/question.dart';
import '../../models/quiz_attempt.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results')),
      body: DefaultTabController(
        length: 2,
        child: Column(
          children: [
            const TabBar(tabs: [Tab(text: 'Summary'), Tab(text: 'Review All')]),
            Expanded(child: TabBarView(children: [_buildSummary(), _buildReview()])),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircularPercentIndicator(
            radius: 80,
            lineWidth: 12,
            percent: _accuracy / 100,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${_accuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const Text('accuracy', style: TextStyle(color: Colors.grey)),
              ],
            ),
            progressColor: _accuracy >= 70 ? AppTheme.correct : AppTheme.accent,
            backgroundColor: Colors.grey[200]!,
          ),
          const SizedBox(height: 24),
          _buildScoreRow(),
          const SizedBox(height: 16),
          _buildNeetScore(),
          const SizedBox(height: 24),
          _buildSubjectBreakdown(),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  icon: const Icon(Icons.home),
                  label: const Text('Home'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.refresh),
                  label: const Text('New Quiz'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow() {
    return Row(
      children: [
        _scoreBox('Correct', _correct, AppTheme.correct),
        const SizedBox(width: 8),
        _scoreBox('Wrong', _incorrect, AppTheme.incorrect),
        const SizedBox(width: 8),
        _scoreBox('Skipped', _unattempted, Colors.grey),
      ],
    );
  }

  Widget _scoreBox(String label, int count, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Text('$count', style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNeetScore() {
    return Card(
      color: _neetScore >= 0 ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('NEET Score  ', style: TextStyle(fontWeight: FontWeight.w600)),
            Text('${_neetScore >= 0 ? '+' : ''}$_neetScore',
              style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold,
                color: _neetScore >= 0 ? AppTheme.correct : AppTheme.incorrect,
              )),
            const Text('  (+4/−1)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectBreakdown() {
    final result = MockTestResultHelper.subjectBreakdown(widget.attempts);
    if (result.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subject Breakdown',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        ...result.entries.map((e) {
          final pct = e.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 13)),
                    Text('${pct.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold,
                        color: pct >= 70 ? AppTheme.correct : pct >= 50 ? AppTheme.accent : AppTheme.incorrect,
                      )),
                  ],
                ),
                const SizedBox(height: 2),
                LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: Colors.grey[200],
                  color: pct >= 70 ? AppTheme.correct : pct >= 50 ? AppTheme.accent : AppTheme.incorrect,
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReview() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: widget.attempts.length,
      itemBuilder: (_, i) {
        final attempt = widget.attempts[i];
        final q = widget.questions.firstWhere((q) => q.id == attempt.questionId,
          orElse: () => widget.questions[i]);
        return _buildReviewCard(i, attempt, q);
      },
    );
  }

  Widget _buildReviewCard(int i, QuizAttempt attempt, Question q) {
    final isCorrect = attempt.isCorrect;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCorrect ? Icons.check_circle : Icons.cancel,
                  color: isCorrect ? AppTheme.correct : AppTheme.incorrect, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Q${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Text(q.stem, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 8),
            if (attempt.selectedOption != null)
              _answerRow('Your answer', attempt.selectedOption!, q,
                isCorrect ? AppTheme.correct : AppTheme.incorrect),
            if (!isCorrect)
              _answerRow('Correct answer', q.correctOption, q, AppTheme.correct),
            const SizedBox(height: 8),
            Text(q.explanation, style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4)),
            if (_aiExplanations.containsKey(i)) ...[
              const Divider(height: 20),
              Text(_aiExplanations[i]!, style: const TextStyle(fontSize: 13, height: 1.5)),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                if (!_aiExplanations.containsKey(i))
                  OutlinedButton.icon(
                    onPressed: _loadingAi.contains(i) ? null : () => _explainWithAi(i, q),
                    icon: _loadingAi.contains(i)
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 16),
                    label: const Text('Explain with AI'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (_aiExplanations.containsKey(i) && widget.tts.isEnabled)
                  OutlinedButton.icon(
                    onPressed: () => widget.tts.speak(_aiExplanations[i]!),
                    icon: const Icon(Icons.volume_up, size: 16),
                    label: const Text('Read'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _answerRow(String label, String option, Question q, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontSize: 13, color: Colors.grey)),
          Expanded(child: Text('$option. ${q.optionText(option)}',
            style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w600))),
        ],
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
