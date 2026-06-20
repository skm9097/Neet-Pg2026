import 'package:flutter/material.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';
import '../services/github_service.dart';
import '../services/progress_service.dart';
import '../models/quiz_config.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'interactive_screen.dart';

class HomeScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;

  const HomeScreen({super.key, required this.gemini, required this.tts});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ProgressEntry> _progress = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final entries = await ProgressService.loadAll();
    if (mounted) setState(() => _progress = entries);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildApiKeyBanner(),
                    const SizedBox(height: 24),
                    _buildInteractiveBanner(),
                    const SizedBox(height: 20),
                    _sectionTitle('Quiz Mode'),
                    const SizedBox(height: 12),
                    _buildModuleGrid(),
                    if (_progress.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _sectionTitle('Your Progress'),
                      const SizedBox(height: 12),
                      _buildProgressSection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A0A3A), Color(0xFF0D0D1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEET-PG 2026',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI-powered voice quiz',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _openSettings,
            icon: Icon(
              widget.gemini.isConfigured
                  ? Icons.check_circle
                  : Icons.settings_rounded,
              color: widget.gemini.isConfigured
                  ? const Color(0xFF10B981)
                  : Colors.white60,
            ),
            tooltip: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyBanner() {
    if (widget.gemini.isConfigured) return const SizedBox.shrink();
    return GestureDetector(
      onTap: _openSettings,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF2D1B00),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFFBBF24), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap to add Gemini API key for AI feedback (works without it too)',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 13),
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Colors.white70,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildInteractiveBanner() {
    return GestureDetector(
      onTap: _openInteractive,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1B0A3A), Color(0xFF0A1F3A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                    color: const Color(0xFF7C3AED).withOpacity(0.5)),
              ),
              child: const Icon(Icons.mic_rounded,
                  color: Color(0xFF7C3AED), size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AI Tutor — Push to Talk',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Hold mic · Ask any NEET-PG question · Get spoken answer',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.55),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Color(0xFF7C3AED), size: 18),
          ],
        ),
      ),
    );
  }

  void _openInteractive() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            InteractiveScreen(gemini: widget.gemini, tts: widget.tts),
      ),
    );
  }

  Widget _buildModuleGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ModuleCard(
                icon: Icons.calendar_month_rounded,
                label: 'By Year',
                subtitle: '2018 – 2025',
                color: const Color(0xFF7C3AED),
                onTap: () => _showYearPicker(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModuleCard(
                icon: Icons.biotech_rounded,
                label: 'By Subject',
                subtitle: '19 NBE subjects',
                color: const Color(0xFF0891B2),
                onTap: () => _showSubjectPicker(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ModuleCard(
                icon: Icons.shuffle_rounded,
                label: 'Mixed',
                subtitle: 'All years & subjects',
                color: const Color(0xFF059669),
                onTap: () => _showCountPicker(ModuleType.mixed),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ModuleCard(
                icon: Icons.tune_rounded,
                label: 'Custom',
                subtitle: 'Pick count + source',
                color: const Color(0xFFD97706),
                onTap: () => _showCustomPicker(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(gemini: widget.gemini, tts: widget.tts),
      ),
    );
    setState(() {});
  }

  void _showYearPicker() {
    String selected = '2025';
    int count = 20;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select Year',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GitHubService.years
                    .map((y) => ChoiceChip(
                          label: Text(y),
                          selected: selected == y,
                          onSelected: (_) => setLocal(() => selected = y),
                          selectedColor: const Color(0xFF7C3AED),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 20),
              _CountSelector(
                  count: count, onChanged: (v) => setLocal(() => count = v)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startQuiz(QuizConfig(
                      moduleType: ModuleType.byYear,
                      year: selected,
                      questionCount: count,
                    ));
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Quiz'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubjectPicker() {
    String? selected;
    int count = 20;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, sc) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Subject',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    controller: sc,
                    children: GitHubService.subjects
                        .map((s) => ListTile(
                              title: Text(
                                  GitHubService.subjectDisplayNames[s] ?? s),
                              selected: selected == s,
                              selectedTileColor:
                                  const Color(0xFF7C3AED).withOpacity(0.2),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              onTap: () => setLocal(() => selected = s),
                              trailing: selected == s
                                  ? const Icon(Icons.check_circle,
                                      color: Color(0xFF7C3AED))
                                  : null,
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),
                _CountSelector(
                    count: count, onChanged: (v) => setLocal(() => count = v)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: selected == null
                        ? null
                        : () {
                            Navigator.pop(ctx);
                            _startQuiz(QuizConfig(
                              moduleType: ModuleType.bySubject,
                              subject: selected,
                              questionCount: count,
                            ));
                          },
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start Quiz'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCountPicker(ModuleType type) {
    int count = 20;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mixed Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(
                'Questions pulled from all years and subjects.',
                style: TextStyle(color: Colors.white.withOpacity(0.6)),
              ),
              const SizedBox(height: 20),
              _CountSelector(
                  count: count, onChanged: (v) => setLocal(() => count = v)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _startQuiz(
                        QuizConfig(moduleType: type, questionCount: count));
                  },
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Quiz'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomPicker() {
    // Custom = choose a year or subject then count
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Custom Quiz',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            ListTile(
              leading:
                  const Icon(Icons.calendar_month, color: Color(0xFF7C3AED)),
              title: const Text('Pick a Year'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              tileColor: const Color(0xFF0D0D1A),
              onTap: () {
                Navigator.pop(ctx);
                _showYearPicker();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.biotech, color: Color(0xFF0891B2)),
              title: const Text('Pick a Subject'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              tileColor: const Color(0xFF0D0D1A),
              onTap: () {
                Navigator.pop(ctx);
                _showSubjectPicker();
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading:
                  const Icon(Icons.shuffle, color: Color(0xFF059669)),
              title: const Text('Mixed'),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              tileColor: const Color(0xFF0D0D1A),
              onTap: () {
                Navigator.pop(ctx);
                _showCountPicker(ModuleType.mixed);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startQuiz(QuizConfig config) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          config: config,
          gemini: widget.gemini,
          tts: widget.tts,
        ),
      ),
    );
    _loadProgress();
  }

  Widget _buildProgressSection() {
    return Column(
      children: _progress.take(5).map((e) {
        final label = _progressLabel(e.source);
        final pct = (e.accuracy * 100).round();
        final color = e.accuracy >= 0.7
            ? const Color(0xFF10B981)
            : e.accuracy >= 0.5
                ? const Color(0xFFFBBF24)
                : const Color(0xFFEF4444);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2A2A4A)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${e.attempted} attempted · ${e.correct} correct',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$pct%',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color),
                  ),
                  Text(
                    '${e.neetScore > 0 ? "+" : ""}${e.neetScore} pts',
                    style: TextStyle(fontSize: 11, color: color.withOpacity(0.7)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _progressLabel(String source) {
    if (source.startsWith('year_')) return 'Year ${source.substring(5)}';
    if (source.startsWith('subject_')) {
      final slug = source.substring(8);
      return GitHubService.subjectDisplayNames[slug] ?? slug;
    }
    return 'Mixed';
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 14),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountSelector extends StatelessWidget {
  final int count;
  final ValueChanged<int> onChanged;

  const _CountSelector({required this.count, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Number of Questions: $count',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [10, 20, 50, 100]
              .map((n) => ChoiceChip(
                    label: Text('$n'),
                    selected: count == n,
                    onSelected: (_) => onChanged(n),
                    selectedColor: const Color(0xFF7C3AED),
                  ))
              .toList(),
        ),
      ],
    );
  }
}
