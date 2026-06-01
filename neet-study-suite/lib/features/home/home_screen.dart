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
import '../../core/widgets/soft_widgets.dart';

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
      body: _buildDashboard(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.06),
            blurRadius: 20, offset: const Offset(0, -4),
          )],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          backgroundColor: Colors.transparent,
          onDestinationSelected: (i) {
            if (i == 0) {
              setState(() => _selectedIndex = 0);
              _loadProgress();
              return;
            }
            _navigateTo(i);
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.menu_book_rounded), label: 'QBank'),
            NavigationDestination(icon: Icon(Icons.style_rounded), label: 'Cards'),
            NavigationDestination(icon: Icon(Icons.timer_rounded), label: 'Mock'),
            NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'Tutor'),
          ],
        ),
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
      color: AppTheme.primary,
      onRefresh: _loadProgress,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHero(totalAttempted, accuracy)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            sliver: SliverList(delegate: SliverChildListDelegate([
              _sectionTitle('Study Modes', 'Pick how you want to learn today'),
              const SizedBox(height: 16),
              _buildModesGrid(),
              const SizedBox(height: 28),
              if (_progress.isNotEmpty) ...[
                _sectionTitle('Your Progress', 'Keep the momentum going'),
                const SizedBox(height: 14),
                ..._progress.take(5).toList().asMap().entries.map(
                  (e) => FadeSlideIn(index: e.key,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildProgressTile(e.value),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _buildExamCountdown(),
            ])),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(int attempted, double accuracy) {
    return Stack(
      children: [
        GradientHeader(
          gradient: AppTheme.heroGradient,
          height: attempted > 0 ? 270 : 240,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_greeting(), style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        const Text('Ready to study?',
                          style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                      ],
                    ),
                  ),
                  TapScale(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SettingsScreen(gemini: widget.gemini, tts: widget.tts),
                    )).then((_) => _loadProgress()),
                    child: Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.settings_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(children: [
                _heroPill(Icons.menu_book_rounded, '13,665+ Questions'),
                const SizedBox(width: 10),
                _heroPill(Icons.auto_awesome_rounded, 'AI-Powered'),
              ]),
            ],
          ),
        ),
        if (attempted > 0)
          Positioned(left: 20, right: 20, bottom: 0,
            child: Transform.translate(offset: const Offset(0, 28),
              child: _buildStatStrip(attempted, accuracy))),
      ],
    );
  }

  Widget _heroPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: Colors.white),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _buildStatStrip(int attempted, double accuracy) {
    final correct = _progress.fold(0, (s, p) => s + p.correct);
    final neet = correct * 4 - (attempted - correct);
    return SoftCard(
      shadow: AppTheme.softShadow,
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(children: [
        _statCell('${accuracy.toStringAsFixed(0)}%', 'Accuracy', AppTheme.primary),
        _divider(),
        _statCell('$attempted', 'Solved', AppTheme.secondary),
        _divider(),
        _statCell('${neet >= 0 ? '+' : ''}$neet', 'NEET Score', neet >= 0 ? AppTheme.correct : AppTheme.incorrect),
      ]),
    );
  }

  Widget _statCell(String value, String label, Color color) => Expanded(
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 11.5, color: AppTheme.inkSoft, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _divider() => Container(width: 1, height: 34, color: AppTheme.primary.withValues(alpha: 0.08));

  Widget _sectionTitle(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.ink, letterSpacing: -0.4)),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(fontSize: 13, color: AppTheme.inkSoft)),
    ],
  );

  Widget _buildModesGrid() {
    final modes = [
      _Mode('QBank', 'Practice by year, subject or mix', Icons.menu_book_rounded, AppTheme.qbankGradient, 1),
      _Mode('Flashcards', 'Spaced repetition & AI cards', Icons.style_rounded, AppTheme.flashcardGradient, 2),
      _Mode('Mock Test', 'Timed full-length exams', Icons.timer_rounded, AppTheme.mockGradient, 3),
      _Mode('AI Tutor', 'Ask anything, anytime', Icons.auto_awesome_rounded, AppTheme.tutorGradient, 4),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.95,
      children: modes.asMap().entries.map((e) =>
        FadeSlideIn(index: e.key, child: _buildModeCard(e.value))).toList(),
    );
  }

  Widget _buildModeCard(_Mode mode) {
    return TapScale(
      onTap: () => _navigateTo(mode.navIndex),
      child: Container(
        decoration: BoxDecoration(
          gradient: mode.gradient,
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          boxShadow: AppTheme.coloredShadow(mode.gradient.colors.first),
        ),
        child: Stack(
          children: [
            Positioned(right: -18, bottom: -18,
              child: Icon(mode.icon, size: 110, color: Colors.white.withValues(alpha: 0.12))),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(mode.icon, color: Colors.white, size: 24),
                  ),
                  const Spacer(),
                  Text(mode.title, style: const TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  Text(mode.subtitle, style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88), fontSize: 11.5, height: 1.3)),
                ],
              ),
            ),
          ],
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
    final isGood = entry.accuracy >= 60;
    final color = isGood ? AppTheme.correct : entry.accuracy >= 40 ? AppTheme.warning : AppTheme.incorrect;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        IconBadge(
          icon: entry.source.startsWith('subject_') ? Icons.category_rounded : Icons.calendar_today_rounded,
          color: AppTheme.primary, size: 44),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink)),
              const SizedBox(height: 6),
              SoftProgressBar(value: entry.accuracy / 100, color: color, height: 6),
              const SizedBox(height: 5),
              Text('${entry.attempted} questions • ${entry.accuracy.toStringAsFixed(0)}% accuracy',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.inkSoft)),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SoftChip(
          label: '${entry.neetScore >= 0 ? '+' : ''}${entry.neetScore}',
          color: entry.neetScore >= 0 ? AppTheme.correct : AppTheme.incorrect,
        ),
      ]),
    );
  }

  Widget _buildExamCountdown() {
    final examDate = DateTime(2026, 11, 1);
    final daysLeft = examDate.difference(DateTime.now()).inDays;
    return SoftCard(
      gradient: AppTheme.mintGradient,
      shadow: AppTheme.coloredShadow(AppTheme.secondary),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.flag_rounded, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('NEET-PG 2026', style: TextStyle(
                fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
              const SizedBox(height: 2),
              Text('~$daysLeft days to go • You\'ve got this!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5)),
            ],
          ),
        ),
      ]),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning 🌅';
    if (h < 17) return 'Good afternoon ☀️';
    return 'Good evening 🌙';
  }
}

class _Mode {
  final String title;
  final String subtitle;
  final IconData icon;
  final LinearGradient gradient;
  final int navIndex;
  const _Mode(this.title, this.subtitle, this.icon, this.gradient, this.navIndex);
}

extension StringExt on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}
