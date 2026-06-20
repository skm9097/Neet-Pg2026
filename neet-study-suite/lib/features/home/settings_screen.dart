import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../../services/app_settings.dart';
import '../../services/github_sync_service.dart';
import '../../services/providers/ai_provider.dart';
import 'sync_status_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_widgets.dart';

class SettingsScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;
  const SettingsScreen({super.key, required this.gemini, required this.tts});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // One controller per provider
  final _geminiCtrl = TextEditingController();
  final _groqCtrl = TextEditingController();
  final _openrouterCtrl = TextEditingController();

  // Profile + study preferences
  final _settings = AppSettings.instance;
  final _nameCtrl = TextEditingController();
  final _examNameCtrl = TextEditingController();

  // GitHub Sync
  final _patCtrl = TextEditingController();
  bool _showPat = false;
  bool _syncBusy = false;
  String? _syncResult;
  bool _syncSuccess = false;
  int _pendingMistakes = 0;

  AiProviderType _selectedProvider = AiProviderType.gemini;
  bool _showKey = false;
  bool _ttsEnabled = true;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = _settings.userName;
    _examNameCtrl.text = _settings.examName;
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final typeName = prefs.getString('ai_provider_type') ?? 'gemini';
    final pat = await GithubSyncService.getPat();
    final pending = await GithubSyncService.pendingCount();
    if (mounted) setState(() {
      _selectedProvider = AiProviderType.values.firstWhere(
        (t) => t.name == typeName, orElse: () => AiProviderType.gemini);
      _geminiCtrl.text = prefs.getString('gemini_api_key') ?? '';
      _groqCtrl.text = prefs.getString('groq_api_key') ?? '';
      _openrouterCtrl.text = prefs.getString('openrouter_api_key') ?? '';
      _ttsEnabled = widget.tts.isEnabled;
      _patCtrl.text = pat ?? '';
      _pendingMistakes = pending;
    });
  }

  TextEditingController get _activeCtrl {
    switch (_selectedProvider) {
      case AiProviderType.gemini: return _geminiCtrl;
      case AiProviderType.groq: return _groqCtrl;
      case AiProviderType.openrouter: return _openrouterCtrl;
    }
  }

  String get _prefKey {
    switch (_selectedProvider) {
      case AiProviderType.gemini: return 'gemini_api_key';
      case AiProviderType.groq: return 'groq_api_key';
      case AiProviderType.openrouter: return 'openrouter_api_key';
    }
  }

  Future<void> _saveAndTest() async {
    final key = _activeCtrl.text.trim();
    if (key.isEmpty) {
      setState(() { _testResult = 'Enter your API key first.'; _testSuccess = false; });
      return;
    }

    // Save key + active provider
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, key);
    await prefs.setString('ai_provider_type', _selectedProvider.name);
    widget.gemini.setProvider(_selectedProvider, key);

    setState(() { _testing = true; _testResult = null; });
    final (success, message) = await widget.gemini.testConnection();
    if (mounted) setState(() {
      _testing = false;
      _testSuccess = success;
      _testResult = message;
    });
  }

  @override
  void dispose() {
    _geminiCtrl.dispose();
    _groqCtrl.dispose();
    _openrouterCtrl.dispose();
    _nameCtrl.dispose();
    _examNameCtrl.dispose();
    _patCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.syncFrom(context);
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          const CompactGradientHeader(
            title: 'Settings',
            subtitle: 'Profile, AI, sync & preferences',
            icon: Icons.tune_rounded,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              children: [
                _sectionHeader('Profile'),
                _buildProfileCard(),
                const SizedBox(height: 16),
                _sectionHeader('Exam & Goal'),
                _buildStudyCard(),
                const SizedBox(height: 16),
                _sectionHeader('Appearance'),
                _buildAppearanceCard(),
                const SizedBox(height: 16),
                _sectionHeader('AI Provider'),
                _buildProviderPicker(),
                const SizedBox(height: 12),
                _buildKeyCard(),
                const SizedBox(height: 8),
                _buildComparisonCard(),
                const SizedBox(height: 16),
                _sectionHeader('Voice (TTS)'),
                Card(
                  child: SwitchListTile(
                    title: const Text('Text-to-Speech', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Reads questions and feedback aloud'),
                    activeColor: AppTheme.primary,
                    value: _ttsEnabled,
                    onChanged: (v) async {
                      await widget.tts.setEnabled(v);
                      if (mounted) setState(() => _ttsEnabled = v);
                    },
                  ),
                ),
                const SizedBox(height: 16),
                _sectionHeader('GitHub Sync'),
                _buildGithubSyncCard(),
                const SizedBox(height: 16),
                _sectionHeader('Data'),
                Card(
                  child: ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.incorrect.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.delete_outline_rounded, color: AppTheme.incorrect, size: 20),
                    ),
                    title: const Text('Clear Progress Data', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Reset all study statistics'),
                    onTap: _confirmClearProgress,
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text('NEET-PG Study Suite v1.7.0',
                    style: TextStyle(color: AppTheme.inkFaint, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: Center(child: Text(
                  _initials(_nameCtrl.text),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17))),
              ),
              const SizedBox(width: 14),
              const Expanded(child: Text('Your name', style: TextStyle(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Aarav',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              onChanged: (v) {
                _settings.setName(v);
                setState(() {}); // refresh avatar initials
              },
            ),
            const SizedBox(height: 6),
            Text('Used for your greeting on the home screen.',
              style: TextStyle(color: AppTheme.inkFaint, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '🙂';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  Widget _buildStudyCard() {
    final daysLeft = _settings.examDate.difference(DateTime.now()).inDays;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Exam name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 8),
            TextField(
              controller: _examNameCtrl,
              decoration: const InputDecoration(
                hintText: 'NEET PG 2026',
                prefixIcon: Icon(Icons.school_outlined),
              ),
              onChanged: (v) => _settings.setExamName(v),
            ),
            const SizedBox(height: 16),
            const Text('Exam date', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            const SizedBox(height: 8),
            TapScale(
              onTap: _pickExamDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(
                  color: AppTheme.greenTint,
                  borderRadius: AppTheme.radiusMd,
                  border: Border.all(color: AppTheme.line),
                ),
                child: Row(children: [
                  Icon(Icons.event_rounded, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_formatDate(_settings.examDate),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  Text(daysLeft >= 0 ? '$daysLeft days left' : 'past',
                    style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 12.5)),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(child: Text('Daily goal',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5))),
              Text('${_settings.dailyGoal} questions / day',
                style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [10, 20, 30, 50, 75, 100].map((n) {
                final active = _settings.dailyGoal == n;
                return TapScale(
                  onTap: () { _settings.setDailyGoal(n); setState(() {}); },
                  child: Container(
                    width: 54, height: 40, alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppTheme.primary : AppTheme.greenTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('$n', style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: active ? Colors.white : AppTheme.primary)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExamDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _settings.examDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2030, 12, 31),
    );
    if (picked != null) {
      await _settings.setExamDate(picked);
      if (mounted) setState(() {});
    }
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Widget _buildAppearanceCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: ThemeMode.values.map((m) {
            final active = _settings.themeMode == m;
            final label = m == ThemeMode.system ? 'System' : m == ThemeMode.light ? 'Light' : 'Dark';
            final icon = m == ThemeMode.system ? Icons.brightness_auto_rounded
              : m == ThemeMode.light ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
            return Expanded(
              child: TapScale(
                onTap: () { _settings.setThemeMode(m); setState(() {}); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: active ? AppTheme.primary : AppTheme.greenTint,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(children: [
                    Icon(icon, size: 22, color: active ? Colors.white : AppTheme.primary),
                    const SizedBox(height: 6),
                    Text(label, style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 12.5,
                      color: active ? Colors.white : AppTheme.primary)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildProviderPicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: AiProviderType.values.map((type) {
            final isActive = widget.gemini.activeProviderType == type;
            return RadioListTile<AiProviderType>(
              value: type,
              groupValue: _selectedProvider,
              title: Row(
                children: [
                  Text(type.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  if (isActive)
                    Chip(
                      label: const Text('Active', style: TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: AppTheme.primary,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              subtitle: Text(type.freeTierInfo, style: const TextStyle(fontSize: 11)),
              onChanged: (v) => setState(() {
                _selectedProvider = v!;
                _testResult = null;
              }),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildKeyCard() {
    final provider = _selectedProvider;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${provider.displayName} API Key',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showGetKeyDialog(provider),
                  icon: const Icon(Icons.help_outline, size: 16),
                  label: const Text('How to get', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _activeCtrl,
              obscureText: !_showKey,
              decoration: InputDecoration(
                hintText: provider.keyHint,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showKey = !_showKey),
                ),
              ),
              onChanged: (_) => setState(() => _testResult = null),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _testing ? null : _saveAndTest,
                icon: _testing
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.wifi_tethering),
                label: Text(_testing ? 'Testing…' : 'Save & Test Connection'),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _testSuccess ? Colors.green[50] : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _testSuccess ? AppTheme.correct : AppTheme.incorrect),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _testSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _testSuccess ? AppTheme.correct : AppTheme.incorrect,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_testResult!,
                      style: TextStyle(
                        color: _testSuccess ? AppTheme.correct : AppTheme.incorrect,
                        fontSize: 13, height: 1.4,
                      ))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonCard() {
    return Card(
      color: AppTheme.greenTint,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.compare, size: 16, color: AppTheme.primary),
                SizedBox(width: 6),
                Text('Free Tier Comparison', style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            _compareRow('Google Gemini', '10 req/min', '250/day', false),
            _compareRow('Groq', '30 req/min', '14,400/day', true),
            _compareRow('OpenRouter', '~20 req/min', 'Unlimited (free models)', true),
            const SizedBox(height: 8),
            const Text(
              'Recommendation: Use Groq for best free-tier quota.\nAll providers give the same quality medical explanations.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compareRow(String name, String rpm, String rpd, bool recommended) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
          Expanded(child: Text(rpm, style: const TextStyle(fontSize: 12))),
          Expanded(child: Text(rpd, style: TextStyle(
            fontSize: 12,
            color: recommended ? AppTheme.primary : AppTheme.inkFaint,
            fontWeight: recommended ? FontWeight.bold : FontWeight.normal,
          ))),
        ],
      ),
    );
  }

  void _showGetKeyDialog(AiProviderType provider) {
    final steps = _getKeySteps(provider);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Get ${provider.displayName} Key'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Website: ${provider.signupUrl}',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 12),
              ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 10,
                      backgroundColor: AppTheme.primary,
                      child: Text('${e.key + 1}',
                        style: const TextStyle(fontSize: 10, color: Colors.white))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  List<String> _getKeySteps(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.gemini:
        return [
          'Go to aistudio.google.com',
          'Sign in with your Google account',
          'Click "Get API key" → "Create API key"',
          'Copy the key (starts with AIza...)',
          'Paste it above and tap Save & Test',
        ];
      case AiProviderType.groq:
        return [
          'Go to console.groq.com',
          'Sign up for a free account',
          'Click "API Keys" in the left menu',
          'Click "Create API key"',
          'Copy the key (starts with gsk_...)',
          'Paste it above and tap Save & Test',
          'Free tier: 30 req/min, 14,400 req/day — very generous!',
        ];
      case AiProviderType.openrouter:
        return [
          'Go to openrouter.ai/keys',
          'Sign up for a free account',
          'Click "Create Key"',
          'Copy the key (starts with sk-or-...)',
          'Paste it above and tap Save & Test',
          'Free models available with no credit card needed',
        ];
    }
  }

  Widget _buildGithubSyncCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.cloud_sync_rounded, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              const Text('Push mistakes to GitHub repo',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
            ]),
            const SizedBox(height: 6),
            Text(
              'When you answer a question wrong, the app enriches it via AI and pushes a .md file to your repo for the Windows desktop app to display.',
              style: TextStyle(color: AppTheme.inkFaint, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 14),
            const Text('Personal Access Token (PAT)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 4),
            Text('Create at github.com → Settings → Developer settings → Tokens (classic). Needs "contents: write" scope on skm9097/neet-pg2026.',
              style: TextStyle(color: AppTheme.inkFaint, fontSize: 11.5, height: 1.4)),
            const SizedBox(height: 8),
            TextField(
              controller: _patCtrl,
              obscureText: !_showPat,
              decoration: InputDecoration(
                hintText: 'ghp_xxxxxxxxxxxxxxxxxxxx',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showPat ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showPat = !_showPat),
                ),
              ),
              onChanged: (_) => setState(() => _syncResult = null),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _syncBusy ? null : _savePat,
                  icon: const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Token'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _syncBusy || _pendingMistakes == 0 ? null : _flushSync,
                  icon: _syncBusy
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_rounded, size: 18),
                  label: Text(_syncBusy
                      ? 'Syncing…'
                      : _pendingMistakes > 0
                          ? 'Sync ($_pendingMistakes pending)'
                          : 'Nothing pending'),
                ),
              ),
            ]),
            if (_syncResult != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _syncSuccess
                      ? AppTheme.correct.withValues(alpha: 0.10)
                      : AppTheme.incorrect.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _syncSuccess ? AppTheme.correct : AppTheme.incorrect),
                ),
                child: Row(children: [
                  Icon(
                    _syncSuccess ? Icons.check_circle_outline : Icons.error_outline,
                    color: _syncSuccess ? AppTheme.correct : AppTheme.incorrect,
                    size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_syncResult!,
                    style: TextStyle(
                      color: _syncSuccess ? AppTheme.correct : AppTheme.incorrect,
                      fontSize: 12, height: 1.4))),
                ]),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SyncStatusScreen(gemini: widget.gemini))),
                icon: Icon(Icons.history_rounded, size: 16, color: AppTheme.primary),
                label: Text('View Sync Activity', style: TextStyle(color: AppTheme.primary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePat() async {
    final pat = _patCtrl.text.trim();
    await GithubSyncService.setPat(pat);
    if (mounted) setState(() {
      _syncResult = pat.isEmpty ? 'Token cleared.' : 'Token saved.';
      _syncSuccess = true;
    });
  }

  Future<void> _flushSync() async {
    setState(() { _syncBusy = true; _syncResult = null; });
    try {
      final pushed = await GithubSyncService.flushOfflineQueue(widget.gemini);
      final remaining = await GithubSyncService.pendingCount();
      if (mounted) setState(() {
        _pendingMistakes = remaining;
        _syncSuccess = true;
        _syncResult = pushed > 0
            ? 'Pushed $pushed mistake${pushed == 1 ? '' : 's'} to GitHub.'
            : 'Nothing to push.';
      });
    } catch (e) {
      if (mounted) setState(() {
        _syncSuccess = false;
        _syncResult = 'Sync failed: $e';
      });
    } finally {
      if (mounted) setState(() => _syncBusy = false);
    }
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: TextStyle(
      fontWeight: FontWeight.bold, color: AppTheme.primary, fontSize: 13,
      letterSpacing: 0.5,
    )),
  );

  Future<void> _confirmClearProgress() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear Progress?'),
        content: const Text('This resets all study statistics. Flashcards and bookmarks are unaffected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirm == true) {
      await ProgressService.clearAll();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Progress cleared')));
    }
  }
}
