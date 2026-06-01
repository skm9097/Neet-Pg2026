import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../../services/providers/ai_provider.dart';
import '../../core/theme/app_theme.dart';

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

  AiProviderType _selectedProvider = AiProviderType.gemini;
  bool _showKey = false;
  bool _ttsEnabled = true;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final typeName = prefs.getString('ai_provider_type') ?? 'gemini';
    if (mounted) setState(() {
      _selectedProvider = AiProviderType.values.firstWhere(
        (t) => t.name == typeName, orElse: () => AiProviderType.gemini);
      _geminiCtrl.text = prefs.getString('gemini_api_key') ?? '';
      _groqCtrl.text = prefs.getString('groq_api_key') ?? '';
      _openrouterCtrl.text = prefs.getString('openrouter_api_key') ?? '';
      _ttsEnabled = widget.tts.isEnabled;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
              title: const Text('Text-to-Speech'),
              subtitle: const Text('Reads questions and feedback aloud'),
              value: _ttsEnabled,
              onChanged: (v) async {
                await widget.tts.setEnabled(v);
                if (mounted) setState(() => _ttsEnabled = v);
              },
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Data'),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Clear Progress Data'),
              subtitle: const Text('Reset all study statistics'),
              onTap: _confirmClearProgress,
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('NEET-PG Study Suite v1.0.3',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
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
                    const Chip(
                      label: Text('Active', style: TextStyle(fontSize: 10, color: Colors.white)),
                      backgroundColor: AppTheme.correct,
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
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
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
            color: recommended ? AppTheme.correct : Colors.grey,
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
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
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

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(
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
