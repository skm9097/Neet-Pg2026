import 'package:flutter/material.dart';
import '../models/question.dart';
import '../services/progress_service.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';

class ResultScreen extends StatefulWidget {
  final int total;
  final int correct;
  final List<Map<String, dynamic>> history;
  final String? source;
  final GeminiService? gemini;
  final TtsService? tts;

  const ResultScreen({
    super.key,
    required this.total,
    required this.correct,
    required this.history,
    this.source,
    this.gemini,
    this.tts,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _showReview = false;
  final Map<int, String> _aiExplanations = {};
  final Set<int> _loadingAi = {};

  @override
  void initState() {
    super.initState();
    if (widget.source != null && widget.total > 0) {
      ProgressService.record(widget.source!, widget.total, widget.correct);
    }
  }

  Future<void> _explainWithAi(int index, Question q) async {
    if (widget.gemini == null || _loadingAi.contains(index)) return;
    setState(() => _loadingAi.add(index));
    final detail = await widget.gemini!.getDetailedExplanation(
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
      _aiExplanations[index] = detail;
      _loadingAi.remove(index);
    });
  }

  int get _wrong => widget.total - widget.correct;
  int get _neetScore => (widget.correct * 4) - _wrong;
  double get _accuracy => widget.total > 0 ? widget.correct / widget.total : 0;

  Color get _scoreColor {
    if (_accuracy >= 0.75) return const Color(0xFF10B981);
    if (_accuracy >= 0.5) return const Color(0xFFFBBF24);
    return const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SafeArea(
        child: _showReview ? _buildReview() : _buildSummary(),
      ),
    );
  }

  Widget _buildSummary() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildScoreCircle(),
          const SizedBox(height: 32),
          _buildStatCards(),
          const SizedBox(height: 32),
          _buildMarkingBreakdown(),
          const SizedBox(height: 32),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildScoreCircle() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: CircularProgressIndicator(
                value: _accuracy,
                strokeWidth: 12,
                backgroundColor: const Color(0xFF1A1A2E),
                valueColor: AlwaysStoppedAnimation<Color>(_scoreColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${widget.correct}/${widget.total}',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: _scoreColor,
                  ),
                ),
                Text(
                  '${(_accuracy * 100).round()}%',
                  style: TextStyle(
                    fontSize: 15,
                    color: _scoreColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _label,
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          _subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String get _label {
    if (_accuracy >= 0.85) return 'Outstanding!';
    if (_accuracy >= 0.70) return 'Well Done!';
    if (_accuracy >= 0.55) return 'Keep Going!';
    return 'More Practice Needed';
  }

  String get _subtitle {
    if (_accuracy >= 0.70) return 'You\'re on track for NEET-PG 2026.';
    return 'Review the explanations and retry.';
  }

  Widget _buildStatCards() {
    return Row(
      children: [
        _StatCard(
          label: 'Correct',
          value: '${widget.correct}',
          color: const Color(0xFF10B981),
          icon: Icons.check_circle,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Wrong',
          value: '$_wrong',
          color: const Color(0xFFEF4444),
          icon: Icons.cancel,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Skipped',
          value: '0',
          color: Colors.white38,
          icon: Icons.remove_circle_outline,
        ),
      ],
    );
  }

  Widget _buildMarkingBreakdown() {
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
          const Text(
            'NEET-PG Marking (+4 / −1)',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white70),
          ),
          const SizedBox(height: 16),
          _markRow('Correct (×4)', '+${widget.correct * 4}',
              const Color(0xFF10B981)),
          const SizedBox(height: 8),
          _markRow('Wrong (×1)', '−$_wrong', const Color(0xFFEF4444)),
          const Divider(height: 24, color: Color(0xFF2A2A4A)),
          _markRow(
            'Net Score',
            '$_neetScore marks',
            _neetScore >= 0 ? const Color(0xFF7C3AED) : const Color(0xFFEF4444),
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _markRow(String label, String value, Color color,
      {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white60,
                fontSize: bold ? 15 : 14,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: bold ? 16 : 14,
                fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => setState(() => _showReview = true),
            icon: const Icon(Icons.list_alt_rounded),
            label: const Text('Review All Questions'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context)
                  .popUntil((route) => route.isFirst);
            },
            icon: const Icon(Icons.home_rounded),
            label: const Text('Back to Home'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              side: const BorderSide(color: Color(0xFF2A2A4A)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReview() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _showReview = false),
              ),
              const Text(
                'Question Review',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: widget.history.length,
            itemBuilder: (_, i) {
              final entry = widget.history[i];
              final q = entry['question'] as Question;
              final isCorrect = entry['isCorrect'] as bool;
              final selected = entry['selected'] as String;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? const Color(0xFF064E3B).withOpacity(0.4)
                      : const Color(0xFF450A0A).withOpacity(0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isCorrect
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : const Color(0xFFEF4444).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isCorrect ? Icons.check_circle : Icons.cancel,
                          color: isCorrect
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Q${i + 1} · ${q.topic}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(q.stem,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.white, height: 1.4)),
                    const SizedBox(height: 10),
                    _reviewOption('Your answer', selected,
                        q.optionText(selected),
                        isCorrect
                            ? const Color(0xFF10B981)
                            : const Color(0xFFEF4444)),
                    if (!isCorrect) ...[
                      const SizedBox(height: 6),
                      _reviewOption('Correct answer', q.correctOption,
                          q.correctText, const Color(0xFF10B981)),
                    ],
                    if (q.explanation.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          q.explanation,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.7),
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    if (widget.gemini != null) ...[
                      const SizedBox(height: 10),
                      _buildAiBlock(i, q),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAiBlock(int index, Question q) {
    final explanation = _aiExplanations[index];
    final loading = _loadingAi.contains(index);

    if (explanation != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF15172B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded,
                    size: 15, color: Color(0xFF7C3AED)),
                const SizedBox(width: 6),
                const Text(
                  'AI Explanation',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7C3AED)),
                ),
                const Spacer(),
                if (widget.tts?.enabled ?? false)
                  GestureDetector(
                    onTap: () => widget.tts?.speak(explanation),
                    child: const Icon(Icons.volume_up_rounded,
                        size: 16, color: Color(0xFF7C3AED)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              explanation,
              style: const TextStyle(
                  fontSize: 12.5, color: Colors.white, height: 1.5),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: loading ? null : () => _explainWithAi(index, q),
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF7C3AED)),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 16),
        label: Text(loading ? 'Asking Gemini…' : 'Explain with AI',
            style: const TextStyle(fontSize: 13)),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF7C3AED),
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: BorderSide(color: const Color(0xFF7C3AED).withOpacity(0.4)),
        ),
      ),
    );
  }

  Widget _reviewOption(
      String label, String opt, String text, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.45),
              fontWeight: FontWeight.w500),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(opt,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style:
                  TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.8)),
              overflow: TextOverflow.ellipsis,
              maxLines: 2),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: Colors.white.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}
