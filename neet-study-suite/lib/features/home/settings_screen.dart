import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/progress_service.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;
  const SettingsScreen({super.key, required this.gemini, required this.tts});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyController = TextEditingController();
  bool _showKey = false;
  bool _ttsEnabled = true;
  bool _testing = false;
  String? _testResult;
  bool _testSuccess = false;

  static const String _keyPref = 'gemini_api_key';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref) ?? '';
    if (mounted) setState(() {
      _keyController.text = key;
      _ttsEnabled = widget.tts.isEnabled;
    });
  }

  Future<void> _saveAndTest() async {
    final key = _keyController.text.trim();

    if (key.isEmpty) {
      setState(() { _testResult = 'Please enter your API key first.'; _testSuccess = false; });
      return;
    }
    if (!key.startsWith('AIza')) {
      setState(() {
        _testResult = 'Key looks wrong — Gemini keys start with "AIza". Make sure you copied the full key from AI Studio.';
        _testSuccess = false;
      });
      return;
    }

    // Save key first
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key);
    widget.gemini.configure(key);

    // Now test it live
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
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader('Gemini AI'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('API Key', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text(
                    'Get your free key at aistudio.google.com → API keys → Create API key',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyController,
                    obscureText: !_showKey,
                    decoration: InputDecoration(
                      hintText: 'AIza...',
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
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.wifi_tethering),
                      label: Text(_testing ? 'Testing connection…' : 'Save & Test Connection'),
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
                          color: _testSuccess ? AppTheme.correct : AppTheme.incorrect,
                          width: 1,
                        ),
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
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                color: _testSuccess ? AppTheme.correct : AppTheme.incorrect,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Model: ${widget.gemini.isConfigured ? widget.gemini.activeModel : GeminiService.modelName}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const Spacer(),
                      if (widget.gemini.isConfigured && _testResult == null)
                        const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, size: 8, color: AppTheme.correct),
                            SizedBox(width: 4),
                            Text('Active', style: TextStyle(fontSize: 12, color: AppTheme.correct)),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildFreeTierNote(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _buildTroubleshootCard(),
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
            child: Text('NEET-PG Study Suite v1.0.1',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTierNote() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 14, color: AppTheme.primary),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Free tier: 10 requests/min • 250 requests/day',
              style: TextStyle(fontSize: 11, color: AppTheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootCard() {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      title: const Text('Troubleshooting', style: TextStyle(fontSize: 13, color: Colors.grey)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _troubleRow('Key starts with "AIzaSy..."', 'Check you copied the full key'),
              _troubleRow('"API key not valid"', 'Key may be deleted or restricted — regenerate in AI Studio'),
              _troubleRow('"Rate limit"', 'Free tier allows 10 requests/min — wait and retry'),
              _troubleRow('"Model not found"', 'App will auto-try fallback model (gemini-2.0-flash)'),
              _troubleRow('No internet', 'Gemini requires an active connection'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _troubleRow(String error, String fix) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 12)),
          Expanded(child: RichText(text: TextSpan(
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            children: [
              TextSpan(text: '$error: ', style: const TextStyle(fontWeight: FontWeight.w600)),
              TextSpan(text: fix),
            ],
          ))),
        ],
      ),
    );
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
