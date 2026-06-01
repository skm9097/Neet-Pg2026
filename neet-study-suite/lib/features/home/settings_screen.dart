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

  static const String _keyPref = 'gemini_api_key';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final key = prefs.getString(_keyPref) ?? '';
    setState(() {
      _keyController.text = key;
      _ttsEnabled = widget.tts.isEnabled;
    });
  }

  Future<void> _saveKey() async {
    final key = _keyController.text.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPref, key);
    if (key.isNotEmpty) widget.gemini.configure(key);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key saved')));
    }
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
                  const Text('Get a free key at aistudio.google.com',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
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
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      FilledButton(onPressed: _saveKey, child: const Text('Save Key')),
                      const SizedBox(width: 8),
                      if (widget.gemini.isConfigured)
                        const Chip(label: Text('✓ Active', style: TextStyle(color: Colors.white)),
                          backgroundColor: AppTheme.correct),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Model: ${GeminiService.modelName}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionHeader('Voice (TTS)'),
          Card(
            child: SwitchListTile(
              title: const Text('Text-to-Speech'),
              subtitle: const Text('Reads questions and feedback aloud'),
              value: _ttsEnabled,
              onChanged: (v) async {
                await widget.tts.setEnabled(v);
                setState(() => _ttsEnabled = v);
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
              onTap: () => _confirmClearProgress(),
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('NEET-PG Study Suite v1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
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
        content: const Text('This will reset all study statistics. Flashcards and bookmarks are unaffected.'),
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
