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
      (Icons.auto_awesome_rounded, Icons.auto_awesome_outlined, 'Tutor'),
      (Icons.style_rounded, Icons.style_outlined, 'Decks'),
      (Icons.person_rounded, Icons.person_outlined, 'You'),
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
      case 2: screen = AiTutorScreen(gemini: widget.gemini, tts: widget.tts); break;
      case 3: screen = FlashcardsScreen(gemini: widget.gemini, tts: widget.tts); break;
      case 4: screen = SettingsScreen(gemini: widget.gemini, tts: widget.tts); break;
      case 5: screen = MockTestScreen(gemini: widget.gemini); break;
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

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: Colors.white,
        onRefresh: _loadProgress,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTopBar(),
                    const SizedBox(height: 14),

                    // ── SCREEN 1: Exam countdown hero
                    _buildExamCountdownHero(),
                    const SizedBox(height: 22),

                    // ── Weekly activity section header
                    _sectionRow('Your week', 'Insights'),
                    const SizedBox(height: 12),
                    _buildWeeklyCard(totalAttempted, totalCorrect, accuracy, weeklyData),
                    const SizedBox(height: 22),

                    // ── Today's focus card
                    _buildTodaysFocusCard(totalAttempted),
                    const SizedBox(height: 18),

                    // ── Scroll hint
                    _buildScrollHint(),
                    const SizedBox(height: 18),

                    // ── SCREEN 2: Sheet-style page break
                    _buildPageBreak(),

                    // ── Jump back in grid
                    _sectionRow('Jump back in', null),
                    const SizedBox(height: 12),
                    _buildQuickGrid(),
                    const SizedBox(height: 16),

                    // ── Daily challenge card
                    _buildDailyChallengeCard(),
                    const SizedBox(height: 24),

                    // ── Continue session
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
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final h = DateTime.now().hour;
    final greeting = h < 12 ? 'Good morning' : h < 17 ? 'Good afternoon' : 'Good evening';
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: TextStyle(
                  fontSize: 13.5, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Ready to study?', style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 21, letterSpacing: -0.3, color: AppTheme.ink)),
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
              child: Icon(Icons.notifications_outlined, size: 21, color: AppTheme.inkSoft),
            ),
          ),
          const SizedBox(width: 12),
          TapScale(
            onTap: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => SettingsScreen(gemini: widget.gemini, tts: widget.tts),
            )).then((_) => _loadProgress()),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('S', style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCountdownHero() {
    final examDate = DateTime(2026, 11, 1);
    final now = DateTime.now();
    final diff = examDate.difference(now);
    final daysLeft = diff.inDays;
    final hoursLeft = diff.inHours % 24;
    final minsLeft = diff.inMinutes % 60;

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
              right: -34, bottom: -34,
              child: Icon(Icons.calendar_month_rounded,
                size: 130, color: Colors.white.withValues(alpha: 0.08)),
            ),
            Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.calendar_month_rounded,
                        size: 25, color: AppTheme.accent),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('NEET PG 2026', style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18,
                            color: Colors.white, letterSpacing: -0.3, height: 1.05)),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.flag_rounded, size: 12,
                              color: Colors.white.withValues(alpha: 0.85)),
                            const SizedBox(width: 5),
                            Text('Estimated Nov 2026', style: TextStyle(
                              fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85),
                              fontWeight: FontWeight.w600)),
                          ]),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.check_rounded, size: 13, color: Colors.white),
                        const SizedBox(width: 4),
                        const Text('On track', style: TextStyle(
                          fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _countdownBox('$daysLeft', 'days'),
                    const SizedBox(width: 8),
                    _countdownBox('${hoursLeft.toString().padLeft(2, '0')}', 'hours'),
                    const SizedBox(width: 8),
                    _countdownBox('${minsLeft.toString().padLeft(2, '0')}', 'min'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _countdownBox(String number, String unit) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(number, style: const TextStyle(
              fontWeight: FontWeight.w800, fontSize: 19,
              color: Colors.white, letterSpacing: -0.3)),
            const SizedBox(height: 1),
            Text(unit, style: TextStyle(
              fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  List<int> _buildWeeklyData() {
    final total = _progress.fold(0, (s, p) => s + p.attempted);
    if (total == 0) {
      return [88, 132, 108, 152, 76, 116, 70];
    }
    final base = [88, 132, 108, 152, 76, 116, 70];
    final scale = (total / 742).clamp(0.3, 3.0);
    return base.map((v) => (v * scale).round().clamp(1, 999)).toList();
  }

  Widget _buildWeeklyCard(int attempted, int correct, double accuracy, List<int> week) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final todayIdx = (DateTime.now().weekday - 1) % 7;
    final maxVal = week.reduce(math.max);
    final totalWeek = week.fold(0, (s, v) => s + v);
    final streakDays = _progress.isNotEmpty
        ? math.min(_progress.first.attempted ~/ 3 + 1, 99)
        : 0;

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
            // compact top row
            Row(
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('$totalWeek', style: TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800,
                        letterSpacing: -0.4, color: AppTheme.ink)),
                      const SizedBox(width: 7),
                      Text('Qs this week', style: TextStyle(
                        fontSize: 12, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
                      if (attempted > 0) ...[
                        const SizedBox(width: 6),
                        Text('↑ 12%', style: TextStyle(
                          fontSize: 12.5, color: AppTheme.primary, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.terraSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.local_fire_department_rounded,
                      size: 14, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    Text('$streakDays-day streak',
                      style: TextStyle(
                        fontSize: 12.5, color: AppTheme.secondary, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ],
            ),

            // bar chart with per-day question counts
            const SizedBox(height: 14),
            SizedBox(
              height: 84,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final isToday = i == todayIdx;
                  final count = week[i];
                  final barFraction = maxVal > 0 ? count / maxVal : 0.0;
                  return Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('$count', style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700,
                          color: isToday ? AppTheme.primary : AppTheme.inkFaint)),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: 49,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: AnimatedContainer(
                              duration: Duration(milliseconds: 400 + i * 60),
                              curve: Curves.easeOut,
                              height: 49 * barFraction,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: isToday ? AppTheme.primary : AppTheme.greenSoft,
                                borderRadius: BorderRadius.circular(7),
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

            // footer stats: Accuracy · Time spent · Best day
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
                  _footStat(Icons.access_time_rounded, AppTheme.lavender,
                    'Time spent', _estimateTimeSpent(attempted)),
                  Container(width: 1, height: 34, color: AppTheme.lineSoft),
                  _footStat(Icons.local_fire_department_rounded, AppTheme.secondary,
                    'Best day', '${week.reduce(math.max)}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _estimateTimeSpent(int attempted) {
    final mins = attempted * 2;
    if (mins >= 60) {
      return '${mins ~/ 60}h ${mins % 60}m';
    }
    return '${mins}m';
  }

  Widget _footStat(IconData icon, Color fg, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(
              fontSize: 11.5, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.ink)),
        ],
      ),
    );
  }

  Widget _buildTodaysFocusCard(int attempted) {
    final goalDone = math.min(attempted, 30);
    const goalTotal = 30;
    final progress = goalDone / goalTotal;

    return FadeSlideIn(
      index: 2,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.rLg),
          border: Border.all(color: AppTheme.line),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _ProgressRing(
              size: 58, stroke: 6, value: progress.clamp(0.0, 1.0),
              trackColor: AppTheme.lineSoft, ringColor: AppTheme.primary,
              child: Text('${(progress * 100).round()}%',
                style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily goal', style: TextStyle(
                    fontSize: 12, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text('$goalDone / $goalTotal questions', style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18,
                    color: AppTheme.ink, letterSpacing: -0.2)),
                  const SizedBox(height: 1),
                  Text(
                    goalDone >= goalTotal
                      ? 'Goal complete — keep going!'
                      : '${goalTotal - goalDone} more to keep your streak',
                    style: TextStyle(
                      fontSize: 12, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TapScale(
              onTap: () => _navigateTo(1),
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                  color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollHint() {
    return Column(
      children: [
        Text('Scroll for more', style: TextStyle(
          fontSize: 11.5, color: AppTheme.inkFaint,
          fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Icon(Icons.keyboard_arrow_down_rounded,
          size: 18, color: AppTheme.inkFaint),
      ],
    );
  }

  Widget _buildPageBreak() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Container(
            width: double.infinity, height: 1,
            color: AppTheme.line,
          ),
          const SizedBox(height: 16),
          Container(
            width: 38, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.line,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickGrid() {
    final tiles = [
      _Tile('PYQ Practice', '13,665+ questions', Icons.menu_book_rounded,
        AppTheme.greenTint, AppTheme.primary, 1),
      _Tile('Mock Test', 'Full / mini', Icons.timer_rounded,
        AppTheme.terraSoft, AppTheme.secondary, _mockNavIndex),
      _Tile('Flashcards', 'Spaced repetition', Icons.style_rounded,
        AppTheme.goldSoft, AppTheme.gold, _flashNavIndex),
      _Tile('AI Tutor', 'Ask anything', Icons.auto_awesome_rounded,
        AppTheme.blueSoft, AppTheme.lavender, 2),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.3,
      children: tiles.asMap().entries.map((e) {
        final t = e.value;
        return FadeSlideIn(
          index: e.key + 3,
          child: TapScale(
            onTap: () => _navigateTo(t.navIndex),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.rMd),
                border: Border.all(color: AppTheme.line),
                boxShadow: AppTheme.cardShadow,
              ),
              padding: const EdgeInsets.fromLTRB(13, 12, 10, 12),
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
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.label, style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5,
                          letterSpacing: -0.1, color: AppTheme.ink),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 1),
                        Text(t.sub, style: TextStyle(
                          fontSize: 11.5, color: AppTheme.inkFaint,
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

  static const int _mockNavIndex = 5;
  static const int _flashNavIndex = 3;

  Widget _buildDailyChallengeCard() {
    return FadeSlideIn(
      index: 5,
      child: TapScale(
        onTap: () => _navigateTo(1),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.secondary,
            borderRadius: BorderRadius.circular(AppTheme.rLg),
            boxShadow: AppTheme.coloredShadow(AppTheme.secondary),
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Positioned(
                right: -18, top: -20,
                child: Icon(Icons.bolt_rounded,
                  size: 110, color: Colors.white.withValues(alpha: 0.16)),
              ),
              Row(
                children: [
                  Container(
                    width: 46, height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(Icons.bolt_rounded,
                      size: 25, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily challenge', style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15.5,
                          color: Colors.white)),
                        SizedBox(height: 2),
                        Text('10 high-yield Qs · 2× XP today', style: TextStyle(
                          fontSize: 12, color: Colors.white,
                          fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                    size: 22, color: Colors.white.withValues(alpha: 0.9)),
                ],
              ),
            ],
          ),
        ),
      ),
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

    return TapScale(
      onTap: () => _navigateTo(1),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
          boxShadow: AppTheme.cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        child: Row(children: [
          _ProgressRing(size: 42, stroke: 5, value: pct, trackColor: AppTheme.lineSoft, ringColor: color,
            child: Text('${(pct * 100).round()}', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.ink))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.ink)),
              const SizedBox(height: 2),
              Text('${entry.attempted} questions · ${entry.accuracy.toStringAsFixed(0)}% accuracy',
                style: TextStyle(fontSize: 12, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.inkFaint),
        ]),
      ),
    );
  }

  Widget _sectionRow(String title, String? action) {
    return Row(
      children: [
        Expanded(child: Text(title, style: TextStyle(
          fontWeight: FontWeight.w800, fontSize: 16,
          letterSpacing: -0.3, color: AppTheme.ink))),
        if (action != null)
          Text(action, style: TextStyle(
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
