import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/github_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_widgets.dart';
import 'quiz_screen.dart';

class QBankScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;
  const QBankScreen({super.key, required this.gemini, required this.tts});

  @override
  State<QBankScreen> createState() => _QBankScreenState();
}

class _QBankScreenState extends State<QBankScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  String? _selectedYear;
  String? _selectedSubject;
  int _questionCount = 20;
  static const List<int> _countOptions = [10, 20, 30, 50, 100];

  static List<Color> get _yearColors => [
    AppTheme.primary, AppTheme.secondary, AppTheme.gold,
    AppTheme.lavender, AppTheme.correct, AppTheme.primary,
    const Color(0xFF9B6A8C), AppTheme.secondary, AppTheme.gold,
    AppTheme.lavender, AppTheme.correct,
  ];
  static List<Color> get _subjectColors => [
    AppTheme.primary, AppTheme.secondary, AppTheme.gold,
    AppTheme.lavender, AppTheme.correct, const Color(0xFF9B6A8C),
    AppTheme.primary, AppTheme.secondary,
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [_buildYearTab(), _buildSubjectTab(), _buildMixedTab()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppTheme.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                TapScale(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('Question Bank', style: TextStyle(
                  color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800,
                  letterSpacing: -0.4)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text('Choose how you want to practise',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 13)),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildTabSelector(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    const labels = ['By Year', 'By Subject', 'Mixed'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = _tabs.index == i;
          return Expanded(
            child: TapScale(
              onTap: () => _tabs.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(11)),
                child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(
                  color: active ? AppTheme.primary : Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildYearTab() {
    return _buildPickerLayout(
      options: GithubService.availableYears,
      selected: _selectedYear,
      onSelect: (y) => setState(() => _selectedYear = y),
      colors: _yearColors,
      icon: Icons.calendar_today_rounded,
      onStart: _selectedYear == null ? null : () => _startQuiz('year', _selectedYear!),
    );
  }

  Widget _buildSubjectTab() {
    return _buildPickerLayout(
      options: GithubService.availableSubjects,
      selected: _selectedSubject,
      onSelect: (s) => setState(() => _selectedSubject = s),
      displayName: (s) => GithubService.subjectDisplayNames[s] ?? s,
      colors: _subjectColors,
      icon: Icons.category_rounded,
      onStart: _selectedSubject == null ? null : () => _startQuiz('subject', _selectedSubject!),
    );
  }

  Widget _buildMixedTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.rLg),
              boxShadow: AppTheme.coloredShadow(AppTheme.primary),
            ),
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.shuffle_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Mixed Practice', style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('A random blend from every year — keeps you on your toes.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 26),
          _buildCountPicker(),
          const SizedBox(height: 28),
          _buildStartButton('Start Mixed Quiz', Icons.shuffle_rounded, () => _startQuiz('mixed', '')),
        ],
      ),
    );
  }

  Widget _buildPickerLayout({
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelect,
    required List<Color> colors,
    required IconData icon,
    String Function(String)? displayName,
    VoidCallback? onStart,
  }) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            itemCount: options.length,
            itemBuilder: (_, i) {
              final opt = options[i];
              final label = displayName != null ? displayName(opt) : opt;
              final isSelected = opt == selected;
              final color = colors[i % colors.length];
              final tileBg = i % 2 == 0 ? AppTheme.greenTint : AppTheme.terraSoft;

              return FadeSlideIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TapScale(
                    onTap: () => onSelect(opt),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? color.withValues(alpha: 0.08) : AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(AppTheme.rMd),
                        border: Border.all(
                          color: isSelected ? color : AppTheme.line,
                          width: isSelected ? 1.8 : 1),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Row(children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.14) : tileBg,
                            borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, size: 21,
                            color: isSelected ? color : AppTheme.inkFaint),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Text(label, style: TextStyle(
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 15.5,
                          color: isSelected ? color : AppTheme.ink))),
                        AnimatedScale(
                          scale: isSelected ? 1 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (selected != null) _buildBottomPanel(onStart),
      ],
    );
  }

  Widget _buildBottomPanel(VoidCallback? onStart) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.rXl)),
        border: Border(top: BorderSide(color: AppTheme.line)),
        boxShadow: [BoxShadow(
          color: AppTheme.ink.withValues(alpha: 0.06),
          blurRadius: 20, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildCountPicker(),
            const SizedBox(height: 16),
            _buildStartButton('Start Quiz · $_questionCount Qs', Icons.play_arrow_rounded, onStart),
          ],
        ),
      ),
    );
  }

  Widget _buildCountPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Number of questions', style: TextStyle(
          fontWeight: FontWeight.w700, fontSize: 13.5, color: AppTheme.inkSoft)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: _countOptions.map((n) {
            final active = _questionCount == n;
            return TapScale(
              onTap: () => setState(() => _questionCount = n),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 56, height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? AppTheme.primary : AppTheme.greenTint,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: active ? AppTheme.coloredShadow(AppTheme.primary) : null,
                ),
                child: Text('$n', style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 15,
                  color: active ? Colors.white : AppTheme.primary)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildStartButton(String label, IconData icon, VoidCallback? onTap) {
    return TapScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: onTap == null ? AppTheme.inkFaint : AppTheme.primary,
          borderRadius: BorderRadius.circular(AppTheme.rMd),
          boxShadow: onTap == null ? null : AppTheme.coloredShadow(AppTheme.primary),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.5)),
        ]),
      ),
    );
  }

  Future<void> _startQuiz(String mode, String source) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(
        mode: mode, source: source, count: _questionCount,
        gemini: widget.gemini, tts: widget.tts,
      )),
    );
  }
}
