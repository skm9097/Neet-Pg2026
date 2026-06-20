import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';

class SettingsScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;

  const SettingsScreen({super.key, required this.gemini, required this.tts});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyCtrl = TextEditingController();
  bool _obscure = true;
  bool _saved = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _keyCtrl.text = widget.gemini.apiKey;
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveKey() async {
    final key = _keyCtrl.text.trim();
    if (key.isNotEmpty && !key.startsWith('AIza')) {
      setState(() => _error = 'Gemini API keys start with "AIza..."');
      return;
    }
    setState(() => _error = null);
    widget.gemini.setApiKey(key);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', key);
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _saved = false);
  }

  Future<void> _clearKey() async {
    _keyCtrl.clear();
    widget.gemini.setApiKey('');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('gemini_api_key');
    setState(() {
      _error = null;
      _saved = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            title: 'AI Feedback',
            children: [
              _buildApiKeyTile(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'Voice',
            children: [
              _buildVoiceToggle(),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            title: 'About',
            children: [
              _buildInfoTile(
                icon: Icons.quiz_rounded,
                label: 'Question Source',
                value: 'GitHub · skm9097/neet-pg2026',
              ),
              _buildInfoTile(
                icon: Icons.smart_toy_rounded,
                label: 'AI Model',
                value: GeminiService.modelName,
              ),
              _buildInfoTile(
                icon: Icons.school_rounded,
                label: 'Exam',
                value: 'NEET-PG 2026',
              ),
              _buildInfoTile(
                icon: Icons.style_rounded,
                label: 'Marking Scheme',
                value: '+4 correct / −1 wrong',
              ),
              _buildInfoTile(
                icon: Icons.code_rounded,
                label: 'App Version',
                value: '1.2.0',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF7C3AED),
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A4A)),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildApiKeyTile() {
    final isConfigured = widget.gemini.isConfigured;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.vpn_key_rounded,
                    color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Gemini API Key',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConfigured
                          ? 'Configured — AI feedback active'
                          : 'Not set — using built-in feedback',
                      style: TextStyle(
                        fontSize: 12,
                        color: isConfigured
                            ? const Color(0xFF10B981)
                            : Colors.white38,
                      ),
                    ),
                  ],
                ),
              ),
              if (isConfigured)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0D1A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _error != null
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF2A2A4A),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keyCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'AIzaSy...',
                      hintStyle: TextStyle(color: Colors.white30),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white38,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 6),
            Text(_error!,
                style:
                    const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
          ],
          const SizedBox(height: 4),
          Text(
            'Free key at aistudio.google.com · Stored only on your device',
            style: TextStyle(
                fontSize: 11, color: Colors.white.withOpacity(0.35)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveKey,
                  icon: _saved
                      ? const Icon(Icons.check, size: 18)
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saved ? 'Saved!' : 'Save Key'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _saved
                        ? const Color(0xFF10B981)
                        : const Color(0xFF7C3AED),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              if (isConfigured) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _clearKey,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceToggle() {
    final on = widget.tts.enabled;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: const Color(0xFF7C3AED),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Read aloud (TTS)',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'Speak questions and AI feedback automatically',
                  style: TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
          Switch(
            value: on,
            activeColor: const Color(0xFF7C3AED),
            onChanged: (v) async {
              await widget.tts.setEnabled(v);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(
      {required IconData icon,
      required String label,
      required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 14)),
          const Spacer(),
          Text(value,
              style: const TextStyle(color: Colors.white38, fontSize: 13)),
        ],
      ),
    );
  }
}
