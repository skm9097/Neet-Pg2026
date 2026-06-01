import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/github_service.dart';
import '../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Question Bank'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'By Year'), Tab(text: 'By Subject'), Tab(text: 'Mixed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_buildYearTab(), _buildSubjectTab(), _buildMixedTab()],
      ),
    );
  }

  Widget _buildYearTab() {
    return _buildPickerLayout(
      title: 'Select Year',
      options: GithubService.availableYears,
      selected: _selectedYear,
      onSelect: (y) => setState(() => _selectedYear = y),
      onStart: _selectedYear == null ? null : () => _startQuiz('year', _selectedYear!),
    );
  }

  Widget _buildSubjectTab() {
    return _buildPickerLayout(
      title: 'Select Subject',
      options: GithubService.availableSubjects,
      selected: _selectedSubject,
      onSelect: (s) => setState(() => _selectedSubject = s),
      displayName: (s) => GithubService.subjectDisplayNames[s] ?? s,
      onStart: _selectedSubject == null ? null : () => _startQuiz('subject', _selectedSubject!),
    );
  }

  Widget _buildMixedTab() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Mixed Practice', style: TextStyle(
            fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Randomly selected questions from all years.',
            style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _buildCountPicker(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _startQuiz('mixed', ''),
              icon: const Icon(Icons.shuffle),
              label: const Text('Start Mixed Quiz'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerLayout({
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String> onSelect,
    String Function(String)? displayName,
    VoidCallback? onStart,
  }) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemCount: options.length,
            itemBuilder: (_, i) {
              final opt = options[i];
              final label = displayName != null ? displayName(opt) : opt;
              final isSelected = opt == selected;
              return Card(
                color: isSelected ? AppTheme.primary : null,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  title: Text(label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight: isSelected ? FontWeight.bold : null,
                    )),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.white)
                      : null,
                  onTap: () => onSelect(opt),
                ),
              );
            },
          ),
        ),
        if (selected != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildCountPicker(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow),
                label: Text('Start Quiz  ($_questionCount Qs)'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCountPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Questions: $_questionCount',
          style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _countOptions.map((n) => ChoiceChip(
            label: Text('$n'),
            selected: _questionCount == n,
            onSelected: (_) => setState(() => _questionCount = n),
          )).toList(),
        ),
      ],
    );
  }

  Future<void> _startQuiz(String mode, String source) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizScreen(
        mode: mode,
        source: source,
        count: _questionCount,
        gemini: widget.gemini,
        tts: widget.tts,
      )),
    );
  }
}
