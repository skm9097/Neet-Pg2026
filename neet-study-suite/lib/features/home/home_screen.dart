import 'dart:math' as math;
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
      backgroundColor: AppTheme.surface,
      body: _buildDashboard(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      (Icons.home_rounded, Icons.home_outlined, 'Home'),
      (Icons.menu_book_rounded, Icons.menu_book_outlined, 'Practice'),
      (Icons.style_rounded, Icons.style_outlined, 'Cards'),
      (Icons.timer_rounded, Icons.timer_outlined, 'Mock'),
      (Icons.auto_awesome_rounded, Icons.auto_awesome_outlined, 'Tutor'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: Border(top: BorderSide(color: AppTheme.line)),
        boxShadow: [BoxShadow(
          color: AppTheme.ink.withValues(alpha: 0.04),
          blurRadius: 16, offset: const Offset(0, -4),
        )],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final active = _selectedIndex == i;
              return Expanded(
                child: TapScale(
                  onTap: () {
                    if (i == 0) {
                      setState(() => _selectedIndex = 0);
                      _loadProgress();
                    } else {
                      _navigateTo(i);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52, height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: active ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Icon(
                          active ? items[i].$1 : items[i].$2,
                          size: 21,
                          color: active ? Colors.white : AppTheme.inkFaint,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(items[i].$3, style: TextStyle(
                        fontSize: 11,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        color: active ? AppTheme.primary : AppTheme.inkFaint,
                      )),
                    ],
                  ),
                ),
              );
            }),
          ),
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
    final weeklyData = _buildWeeklyData();

    return RefreshIndicator(
      color: AppTheme.primary,
      backgroundColor: Colors.white,
      onRefresh: _loadProgress,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 16),
                  _buildHeroCard(totalAttempted, accuracy),
                  const SizedBox(height: 20),
                  _buildWeeklyCard(totalAttempted, totalCorrect, weeklyData),
                  const SizedBox(height: 22),
                  _sectionRow('Jump back in', null),
                  const SizedBox(height: 12),
                  _buildQuickGrid(),
                  const SizedBox(height: 22),
                  if (_progress.isNotEmpty) ...[
                    _sectionRow('Continue session', 'See all'),
                    const SizedBox(height: 12),
                    ..._progress.take(3).toList().asMap().entries.map(
                      (e) => FadeSlideIn(
                        index: e.key,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildContinueRow(e.value),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  _buildExamCountdown(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: const TextStyle(
                fontSize: 13.5, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              const Text('Ready to study?', style: TextStyle(
                fontFamily: 'Roboto', fontWeight: FontWeight.w800,
                fontSize: 22, letterSpacing: -0.4, color: AppTheme.ink)),
            ],
          ),
        ),
        TapScale(
          onTap: () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => SettingsScreen(gemini: widget.gemini, tts: widget.tts),
          )).then((_) => _loadProgress()),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.line),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(Icons.settings_outlined, size: 20, color: AppTheme.inkSoft),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard(int attempted, double accuracy) {
    final goalDone = math.min(attempted, 30);
    final goalTotal = 30;
    final progress = goalDone / goalTotal;

    return FadeSlideIn(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          boxShadow: AppTheme.coloredShadow(AppTheme.primary),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Positioned(
              right: -30, bottom: -30,
              child: Icon(Icons.local_hospital_rounded,
                size: 120, color: Colors.white.withValues(alpha: 0.08)),
            ),
            Row(
              children: [
                _ProgressRing(size: 58, stroke: 6, value: progress.clamp(0.0, 1.0),
                  child: Text('${(progress * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Today\'s goal', style: TextStyle(
                        fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600,
                        height: 1)),
                      const SizedBox(height: 3),
                      Text('$goalDone / $goalTotal questions', style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white,
                        letterSpacing: -0.3)),
                      const SizedBox(height: 2),
                      Text(
                        goalDone >= goalTotal
                          ? 'Goal complete — keep going! 🎉'
                          : '${goalTotal - goalDone} more to keep your streak',
                        style: TextStyle(
                          fontSize: 11.5, color: Colors.white.withValues(alpha: 0.82))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                TapScale(
                  onTap: () => _navigateTo(1),
                  child: Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                      color: AppTheme.primary, size: 24),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Generate plausible-looking weekly bar data from progress
  List<double> _buildWeeklyData() {
    final total = _progress.fold(0, (s, p) => s + p.attempted);
    if (total == 0) {
      return [0.5, 0.8, 0.65, 0.9, 0.45, 0.7, 0.3];
    }
    final seed = total % 7;
    final base = [0.4, 0.7, 0.55, 0.85, 0.4, 0.6, 0.25];
    return List.generate(7, (i) => (base[(i + seed) % 7]).clamp(0.1, 1.0));
  }

  Widget _buildWeeklyCard(int attempted, int correct, List<double> week) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIdx = (DateTime.now().weekday - 1) % 7;
    final accuracy = attempted > 0 ? correct / attempted * 100 : 0.0;
    final neet = correct * 4 - (attempted - correct);

    return FadeSlideIn(
      index: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          border: Border.all(color: AppTheme.line),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // header row
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$attempted', style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800,
                        letterSpacing: -0.5, color: AppTheme.ink)),
                      const SizedBox(width: 6),
                      const Text('Qs solved', style: TextStyle(
                        fontSize: 12, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
                      if (attempted > 0) ...[
                        const SizedBox(width: 6),
                        const Text('↑ keep going!', style: TextStyle(
                          fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppTheme.terraSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.local_fire_department_rounded,
                      size: 13, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      '${_progress.isNotEmpty ? math.min(_progress.first.attempted ~/ 3 + 1, 99) : 0}-day streak',
                      style: const TextStyle(
                        fontSize: 12, color: AppTheme.secondary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),

            // bar chart
            const SizedBox(height: 14),
            SizedBox(
              height: 56,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final isToday = i == todayIdx;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: week[i],
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 400 + i * 60),
                              curve: Curves.easeOut,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: isToday ? AppTheme.primary : AppTheme.greenSoft,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(days[i], style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isToday ? AppTheme.primary : AppTheme.inkFaint)),
                      ],
                    ),
                  );
                }),
              ),
            ),

            // footer stats
            Container(
              margin: const EdgeInsets.only(top: 14),
              padding: const EdgeInsets.only(top: 14),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppTheme.lineSoft))),
              child: Row(
                children: [
                  _footStat(Icons.track_changes_rounded, AppTheme.primary,
                    'Accuracy', '${accuracy.toStringAsFixed(0)}%'),
                  Container(width: 1, height: 34, color: AppTheme.lineSoft),
                  _footStat(Icons.bookmark_rounded, const Color(0xFFB98A2E),
                    'Saved', '${_progress.length * 3}'),
                  Container(width: 1, height: 34, color: AppTheme.lineSoft),
                  _footStat(Icons.emoji_events_rounded, AppTheme.secondary,
                    'NEET', '${neet >= 0 ? '+' : ''}$neet'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footStat(IconData icon, Color fg, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(
              fontSize: 11, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.ink,
            letterSpacing: -0.3)),
        ],
      ),
    );
  }

  Widget _buildQuickGrid() {
    final tiles = [
      _Tile('PYQ Practice', '13,665+ questions', Icons.menu_book_rounded,
        AppTheme.greenTint, AppTheme.primary, 1),
      _Tile('Mock Test', 'Full / mini exam', Icons.timer_rounded,
        AppTheme.terraSoft, AppTheme.secondary, 3),
      _Tile('Flashcards', 'Spaced repetition', Icons.style_rounded,
        AppTheme.goldSoft, const Color(0xFFB98A2E), 2),
      _Tile('AI Tutor', 'Ask anything', Icons.auto_awesome_rounded,
        AppTheme.blueSoft, AppTheme.lavender, 4),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.85,
      children: tiles.asMap().entries.map((e) {
        final t = e.value;
        return FadeSlideIn(
          index: e.key + 2,
          child: TapScale(
            onTap: () => _navigateTo(t.navIndex),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.rMd),
                border: Border.all(color: AppTheme.line),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.fromLTRB(13, 13, 10, 13),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: t.bg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(t.icon, size: 21, color: t.fg),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.label, style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5,
                          letterSpacing: -0.1, color: AppTheme.ink),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(t.sub, style: const TextStyle(
                          fontSize: 11, color: AppTheme.inkFaint,
                          fontWeight: FontWeight.w600),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildContinueRow(ProgressEntry entry) {
    final label = entry.source.startsWith('year_')
        ? 'Year ${entry.source.substring(5)}'
        : entry.source.startsWith('subject_')
            ? entry.source.substring(8).replaceAll('-', ' ').capitalize()
            : entry.source.capitalize();
    final pct = (entry.accuracy / 100).clamp(0.0, 1.0);
    final color = entry.accuracy >= 70
        ? AppTheme.primary : entry.accuracy >= 45 ? AppTheme.accent : AppTheme.secondary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        border: Border.all(color: AppTheme.line),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(children: [
        _ProgressRing(size: 42, stroke: 5, value: pct, trackColor: AppTheme.lineSoft, ringColor: color,
          child: Text('${entry.accuracy.toStringAsFixed(0)}', style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w800, color: color))),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(
              fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.ink)),
            const SizedBox(height: 2),
            Text('${entry.attempted} questions · ${entry.accuracy.toStringAsFixed(0)}% accuracy',
              style: const TextStyle(fontSize: 12, color: AppTheme.inkFaint, fontWeight: FontWeight.w500)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.inkFaint),
      ]),
    );
  }

  Widget _buildExamCountdown() {
    final examDate = DateTime(2026, 11, 1);
    final daysLeft = examDate.difference(DateTime.now()).inDays;
    return FadeSlideIn(
      index: 6,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          boxShadow: AppTheme.coloredShadow(AppTheme.primary),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.flag_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NEET-PG 2026', style: TextStyle(
                fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
              const SizedBox(height: 2),
              Text('~$daysLeft days to go · You\'ve got this!',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sectionRow(String title, String? action) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(
          fontWeight: FontWeight.w800, fontSize: 16,
          letterSpacing: -0.3, color: AppTheme.ink))),
        if (action != null)
          Text(action, style: const TextStyle(
            fontSize: 13, color: AppTheme.primary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _Tile {
  final String label, sub;
  final IconData icon;
  final Color bg, fg;
  final int navIndex;
  const _Tile(this.label, this.sub, this.icon, this.bg, this.fg, this.navIndex);
}

/// Circular progress ring drawn purely with CustomPaint.
class _ProgressRing extends StatelessWidget {
  final double size;
  final double stroke;
  final double value;
  final Color trackColor;
  final Color ringColor;
  final Widget? child;

  const _ProgressRing({
    required this.size,
    required this.stroke,
    required this.value,
    this.trackColor = const Color(0x33FFFFFF),
    this.ringColor = Colors.white,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              value: value.clamp(0.0, 1.0),
              trackColor: trackColor,
              ringColor: ringColor,
              strokeWidth: stroke,
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color trackColor;
  final Color ringColor;
  final double strokeWidth;
  const _RingPainter({
    required this.value, required this.trackColor,
    required this.ringColor, required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final arcPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.value != value || old.ringColor != ringColor;
}

extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}
