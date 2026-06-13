import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../../services/app_settings.dart';
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
  final _settings = AppSettings.instance;
  int _selectedIndex = 0;
  List<ProgressEntry> _progress = [];

  // Streak-graph state
  int _weekOffset = 0;            // 0 = this week, -1 = last week, …
  List<DailyStat> _week = [];
  int _streak = 0;
  int _solvedToday = 0;
  bool _hasOlderData = false;
  int _selectedDay = 0;          // index 0..6 within the visible week

  @override
  void initState() {
    super.initState();
    _selectedDay = (DateTime.now().weekday - 1) % 7;
    _settings.addListener(_onSettings);
    _loadData();
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettings);
    super.dispose();
  }

  void _onSettings() { if (mounted) setState(() {}); }

  Future<void> _loadData() async {
    final p = await ProgressService.loadAll();
    final week = await ProgressService.weekStats(_weekOffset);
    final streak = await ProgressService.currentStreak();
    final solvedToday = await ProgressService.solvedToday();
    final older = await ProgressService.hasDataBefore(_weekOffset);
    if (mounted) setState(() {
      _progress = p;
      _week = week;
      _streak = streak;
      _solvedToday = solvedToday;
      _hasOlderData = older;
    });
  }

  Future<void> _changeWeek(int delta) async {
    final next = _weekOffset + delta;
    if (next > 0) return;                  // never go into the future
    if (delta < 0 && !_hasOlderData) return; // no older data to show
    _weekOffset = next;
    final week = await ProgressService.weekStats(_weekOffset);
    final older = await ProgressService.hasDataBefore(_weekOffset);
    if (mounted) setState(() {
      _week = week;
      _hasOlderData = older;
      // keep selection in range; default to last active or today
      _selectedDay = _weekOffset == 0 ? (DateTime.now().weekday - 1) % 7 : 6;
    });
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
        color: AppTheme.cardBg.withValues(alpha: 0.97),
        border: Border(top: BorderSide(color: AppTheme.line)),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
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
                      _loadData();
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
        .then((_) => _loadData());
  }

  // Nav indices for the quick-grid tiles (bottom nav order differs).
  static const int _mockNavIndex = 5;
  static const int _flashNavIndex = 3;

  Widget _buildDashboard() {
    final totalAttempted = _progress.fold(0, (s, p) => s + p.attempted);
    final totalCorrect = _progress.fold(0, (s, p) => s + p.correct);
    final accuracy = totalAttempted > 0 ? totalCorrect / totalAttempted * 100 : 0.0;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: AppTheme.primary,
        backgroundColor: AppTheme.cardBg,
        onRefresh: _loadData,
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

                    // SCREEN 1 — exam countdown
                    _buildExamCountdownHero(),
                    const SizedBox(height: 22),

                    // weekly streak graph (swipeable)
                    _sectionRow('Your week', null),
                    const SizedBox(height: 12),
                    _buildStreakCard(accuracy),
                    const SizedBox(height: 22),

                    // Today's focus (daily goal)
                    _buildTodaysFocusCard(),
                    const SizedBox(height: 18),

                    _buildScrollHint(),
                    const SizedBox(height: 18),

                    // SCREEN 2
                    _buildPageBreak(),
                    _sectionRow('Jump back in', null),
                    const SizedBox(height: 12),
                    _buildQuickGrid(),
                    const SizedBox(height: 16),
                    _buildDailyChallengeCard(),
                    const SizedBox(height: 24),

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
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_settings.greeting(), style: TextStyle(
                  fontSize: 13.5, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Ready to study?',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 21, letterSpacing: -0.3, color: AppTheme.ink)),
              ],
            ),
          ),
          TapScale(
            onTap: _openSettings,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.line),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Icon(Icons.settings_outlined, size: 21, color: AppTheme.inkSoft),
            ),
          ),
          const SizedBox(width: 12),
          TapScale(
            onTap: _openSettings,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(_avatarInitials(),
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openSettings() => Navigator.push(context, MaterialPageRoute(
    builder: (_) => SettingsScreen(gemini: widget.gemini, tts: widget.tts),
  )).then((_) => _loadData());

  String _avatarInitials() {
    final parts = _settings.userName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'S';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Widget _buildExamCountdownHero() {
    final now = DateTime.now();
    final diff = _settings.examDate.difference(now);
    final past = diff.isNegative;
    final daysLeft = past ? 0 : diff.inDays;
    final hoursLeft = past ? 0 : diff.inHours % 24;
    final minsLeft = past ? 0 : diff.inMinutes % 60;

    return FadeSlideIn(
      child: _PulseGlow(
        color: AppTheme.primary,
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.qbankGradient,
            borderRadius: BorderRadius.circular(AppTheme.rLg),
            boxShadow: AppTheme.coloredShadow(AppTheme.primary),
          ),
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              // Animated floating particles
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.rLg),
                  child: const _HeroParticles(),
                ),
              ),
              Positioned(
                right: -34, bottom: -34,
                child: Icon(Icons.calendar_month_rounded,
                  size: 130, color: Colors.white.withValues(alpha: 0.06)),
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
                          Text(_settings.examName, style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18,
                            color: Colors.white, letterSpacing: -0.3, height: 1.05),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.flag_rounded, size: 12,
                              color: Colors.white.withValues(alpha: 0.85)),
                            const SizedBox(width: 5),
                            Text(_examDateLabel(),
                              style: TextStyle(
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
                      child: Row(mainAxisSize: MainAxisSize.min, children: const [
                        Icon(Icons.bolt_rounded, size: 13, color: Colors.white),
                        SizedBox(width: 4),
                        Text('On track', style: TextStyle(
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
                    _countdownBox(hoursLeft.toString().padLeft(2, '0'), 'hours'),
                    const SizedBox(width: 8),
                    _countdownBox(minsLeft.toString().padLeft(2, '0'), 'min'),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  String _examDateLabel() {
    final d = _settings.examDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
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

  // ── Weekly streak graph: real per-day data, swipeable, selectable bars ──
  Widget _buildStreakCard(double overallAccuracy) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final goal = _settings.dailyGoal;
    final maxVal = _week.fold(0, (m, d) => math.max(m, d.solved));
    final selIdx = _selectedDay.clamp(0, 6);
    final sel = _week.isNotEmpty ? _week[selIdx] : DailyStat(day: _zeroDay);
    final todayIdx = (DateTime.now().weekday - 1) % 7;

    return FadeSlideIn(
      index: 1,
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v > 200) _changeWeek(-1);      // swipe right → older week
          if (v < -200) _changeWeek(1);      // swipe left → newer week
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.rLg),
            border: Border.all(color: AppTheme.line),
            boxShadow: AppTheme.cardShadow,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // top row: streak + week navigation
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.terraSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.local_fire_department_rounded,
                        size: 15, color: AppTheme.secondary),
                      const SizedBox(width: 4),
                      Text('$_streak-day streak', style: TextStyle(
                        fontSize: 12.5, color: AppTheme.secondary, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const Spacer(),
                  _weekNavBtn(Icons.chevron_left_rounded, _hasOlderData, () => _changeWeek(-1)),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 76,
                    child: Text(_weekLabel(), textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.inkSoft)),
                  ),
                  const SizedBox(width: 4),
                  _weekNavBtn(Icons.chevron_right_rounded, _weekOffset < 0, () => _changeWeek(1)),
                ],
              ),

              const SizedBox(height: 14),
              // bars — tap to select; color reflects whether daily goal was met
              SizedBox(
                height: 92,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final stat = _week.length > i ? _week[i] : DailyStat(day: _zeroDay);
                    final selected = i == selIdx;
                    final met = stat.solved >= goal && stat.solved > 0;
                    final barColor = stat.solved == 0
                        ? AppTheme.lineSoft
                        : met ? AppTheme.primary : AppTheme.greenSoft;
                    final frac = maxVal > 0 ? stat.solved / maxVal : 0.0;
                    return Expanded(
                      child: TapScale(
                        scale: 0.92,
                        onTap: () => setState(() => _selectedDay = i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${stat.solved}', style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w700,
                              color: selected ? AppTheme.primary : AppTheme.inkFaint)),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 52,
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 350 + i * 50),
                                  curve: Curves.easeOut,
                                  height: math.max(52 * frac, stat.solved > 0 ? 6 : 3),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  decoration: BoxDecoration(
                                    color: barColor,
                                    borderRadius: BorderRadius.circular(7),
                                    border: selected
                                        ? Border.all(color: AppTheme.primary, width: 2)
                                        : null,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Container(
                              width: 22, alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: (selected && i == todayIdx && _weekOffset == 0)
                                    ? AppTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(days[i], style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: selected ? AppTheme.primary : AppTheme.inkFaint)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // footer: selected day's solved / accuracy / time
              Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.only(top: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: AppTheme.lineSoft))),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedDayLabel(sel),
                      style: TextStyle(fontSize: 11.5, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _footStat(Icons.check_circle_outline_rounded, AppTheme.primary,
                          'Solved', '${sel.solved}'),
                        Container(width: 1, height: 34, color: AppTheme.lineSoft),
                        _footStat(Icons.track_changes_rounded, AppTheme.lavender,
                          'Accuracy', sel.solved > 0 ? '${sel.accuracy.toStringAsFixed(0)}%' : '—'),
                        Container(width: 1, height: 34, color: AppTheme.lineSoft),
                        _footStat(Icons.access_time_rounded, AppTheme.secondary,
                          'Time spent', sel.solved > 0 ? sel.timeLabel : '—'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _weekNavBtn(IconData icon, bool enabled, VoidCallback onTap) {
    return TapScale(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: enabled ? AppTheme.greenTint : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, size: 18,
          color: enabled ? AppTheme.primary : AppTheme.inkFaint.withValues(alpha: 0.4)),
      ),
    );
  }

  String _weekLabel() {
    if (_weekOffset == 0) return 'This week';
    if (_weekOffset == -1) return 'Last week';
    if (_week.isEmpty) return '';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final a = _week.first.day, b = _week.last.day;
    return '${a.day} ${months[a.month - 1]}–${b.day} ${months[b.month - 1]}';
  }

  String _selectedDayLabel(DailyStat sel) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = sel.day;
    if (d == _zeroDay) return 'No activity';
    return '${weekdays[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
  }

  Widget _footStat(IconData icon, Color fg, String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11, color: AppTheme.inkFaint, fontWeight: FontWeight.w600))),
          ]),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 16.5, color: AppTheme.ink)),
        ],
      ),
    );
  }

  Widget _buildTodaysFocusCard() {
    final goal = _settings.dailyGoal;
    final done = math.min(_solvedToday, goal);
    final progress = goal > 0 ? done / goal : 0.0;

    return FadeSlideIn(
      index: 2,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
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
                  Text('Today\'s goal', style: TextStyle(
                    fontSize: 12, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 1),
                  Text('$_solvedToday / $goal questions', style: TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18,
                    color: AppTheme.ink, letterSpacing: -0.2)),
                  const SizedBox(height: 1),
                  Text(
                    _solvedToday >= goal
                      ? 'Goal complete — keep going!'
                      : '${goal - _solvedToday} more to keep your streak',
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
          Container(width: double.infinity, height: 1, color: AppTheme.line),
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
                color: AppTheme.cardBg,
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

  Widget _buildDailyChallengeCard() {
    return FadeSlideIn(
      index: 5,
      child: TapScale(
        onTap: () => _navigateTo(1),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.mockGradient,
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
                    child: const Icon(Icons.bolt_rounded, size: 25, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Daily challenge', style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15.5, color: Colors.white)),
                        SizedBox(height: 2),
                        Text('10 high-yield Qs · 2× XP today', style: TextStyle(
                          fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
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
          color: AppTheme.cardBg,
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

final DateTime _zeroDay = DateTime(2000);

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

// ── Pulsing glow wrapper: breathing colored box-shadow ──────────────────────
class _PulseGlow extends StatefulWidget {
  final Color color;
  final Widget child;
  const _PulseGlow({required this.color, required this.child});

  @override
  State<_PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<_PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final spread = 4.0 + _anim.value * 10.0;
        final blur = 12.0 + _anim.value * 18.0;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.rLg),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.25 + _anim.value * 0.25),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ── Floating particle overlay for hero card ──────────────────────────────────
class _HeroParticles extends StatefulWidget {
  const _HeroParticles();

  @override
  State<_HeroParticles> createState() => _HeroParticlesState();
}

class _HeroParticlesState extends State<_HeroParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final _rng = math.Random(42);
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    _particles = List.generate(14, (i) => _Particle(_rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlePainter(_particles, _ctrl.value),
        );
      },
    );
  }
}

class _Particle {
  final double x;    // 0..1 initial horizontal position
  final double y;    // 0..1 initial vertical position
  final double size;
  final double speed;
  final double phase; // 0..1 animation phase offset

  _Particle(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        size = 2.0 + rng.nextDouble() * 3.0,
        speed = 0.3 + rng.nextDouble() * 0.5,
        phase = rng.nextDouble();
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t; // 0..1 from AnimationController

  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final p in particles) {
      final progress = (t * p.speed + p.phase) % 1.0;
      // drift upward, wrap around
      final dy = (p.y - progress * 0.6) % 1.0;
      final wobble = math.sin((progress + p.phase) * math.pi * 2) * 0.04;
      final dx = (p.x + wobble) % 1.0;

      final alpha = (math.sin(progress * math.pi) * 0.45).clamp(0.0, 1.0);
      paint.color = Colors.white.withValues(alpha: alpha);

      canvas.drawCircle(
        Offset(dx * size.width, dy * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.t != t;
}

extension StringExt on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}
