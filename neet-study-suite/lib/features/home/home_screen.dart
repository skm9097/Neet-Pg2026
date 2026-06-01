import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../qbank/qbank_screen.dart';
import '../flashcards/flashcards_screen.dart';
import '../mock_test/mock_test_screen.dart';
import '../ai_tutor/ai_tutor_screen.dart';
import 'settings_screen.dart';
import '../../core/theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;
  const HomeScreen({super.key, required this.gemini, required this.tts});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  List<ProgressEntry> _progress = [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final p = await ProgressService.loadAll();
    if (mounted) setState(() => _progress = p);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NEET-PG 2026'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => SettingsScreen(
                gemini: widget.gemini, tts: widget.tts,
              )),
            ).then((_) => _loadProgress()),
          ),
        ],
      ),
      body: _selectedIndex == 0 ? _buildDashboard() : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          if (i == 0) {
            setState(() => _selectedIndex = 0);
            _loadProgress();
            return;
          }
          setState(() => _selectedIndex = i);
          _navigateTo(i);
          setState(() => _selectedIndex = 0);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.quiz), label: 'QBank'),
          NavigationDestination(icon: Icon(Icons.style), label: 'Flashcards'),
          NavigationDestination(icon: Icon(Icons.timer), label: 'Mock Test'),
          NavigationDestination(icon: Icon(Icons.smart_toy), label: 'AI Tutor'),
        ],
      ),
    );
  }

  void _navigateTo(int index) {
    Widget screen;
    switch (index) {
      case 1: screen = QBankScreen(gemini: widget.gemini, tts: widget.tts); break;
      case 2: screen = FlashcardsScreen(gemini: widget.gemini, tts: widget.tts); break;
      case 3: screen = MockTestScreen(gemini: widget.gemini); break;
      case 4: screen = AiTutorScreen(gemini: widget.gemini, tts: widget.tts); break;
      default: return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadProgress());
  }

  Widget _buildDashboard() {
    final totalAttempted = _progress.fold(0, (s, p) => s + p.attempted);
    final totalCorrect = _progress.fold(0, (s, p) => s + p.correct);
    final accuracy = totalAttempted > 0 ? totalCorrect / totalAttempted * 100 : 0.0;

    return RefreshIndicator(
      onRefresh: _loadProgress,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(totalAttempted, totalCorrect, accuracy),
            const SizedBox(height: 20),
            _buildQuickActions(),
            const SizedBox(height: 20),
            if (_progress.isNotEmpty) ...[
              Text('Recent Progress', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              ..._progress.take(5).map(_buildProgressTile),
            ],
            const SizedBox(height: 20),
            _buildExamCountdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner(int attempted, int correct, double accuracy) {
    return Card(
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('NEET-PG Study Suite',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('13,665+ Questions • AI-Powered',
                    style: TextStyle(color: Colors.blue[100], fontSize: 13)),
                  if (attempted > 0) ...[
                    const SizedBox(height: 8),
                    Text('${accuracy.toStringAsFixed(1)}% accuracy • $attempted questions done',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.school, color: Colors.white, size: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      (_ActionItem('QBank', Icons.quiz, AppTheme.primaryLight, () => _navigateTo(1))),
      (_ActionItem('Flashcards', Icons.style, AppTheme.secondary, () => _navigateTo(2))),
      (_ActionItem('Mock Test', Icons.timer, AppTheme.accent, () => _navigateTo(3))),
      (_ActionItem('AI Tutor', Icons.smart_toy, const Color(0xFF7B1FA2), () => _navigateTo(4))),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Study Modes', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 2.2,
          children: actions.map((a) => _buildActionCard(a)).toList(),
        ),
      ],
    );
  }

  Widget _buildActionCard(_ActionItem item) {
    return Card(
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(item.icon, color: item.color, size: 28),
              const SizedBox(width: 10),
              Text(item.label, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressTile(ProgressEntry entry) {
    final label = entry.source.startsWith('year_')
        ? 'Year ${entry.source.substring(5)}'
        : entry.source.startsWith('subject_')
            ? entry.source.substring(8).replaceAll('-', ' ').capitalize()
            : entry.source.capitalize();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(label),
        subtitle: Text('${entry.attempted} questions • ${entry.accuracy.toStringAsFixed(0)}% accuracy'),
        trailing: Chip(
          label: Text('${entry.neetScore >= 0 ? '+' : ''}${entry.neetScore}',
            style: TextStyle(
              color: entry.neetScore >= 0 ? AppTheme.correct : AppTheme.incorrect,
              fontSize: 12, fontWeight: FontWeight.bold,
            )),
          backgroundColor: entry.neetScore >= 0
              ? Colors.green[50] : Colors.red[50],
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildExamCountdown() {
    final examDate = DateTime(2026, 11, 1); // approximate NEET-PG 2026 date
    final daysLeft = examDate.difference(DateTime.now()).inDays;
    return Card(
      color: Colors.amber[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: AppTheme.accent),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('NEET-PG 2026', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('~$daysLeft days to go • Stay consistent!',
                  style: const TextStyle(color: AppTheme.accent)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem(this.label, this.icon, this.color, this.onTap);
}

extension StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}
