import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_widgets.dart';

class AiTutorScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;
  const AiTutorScreen({super.key, required this.gemini, required this.tts});

  @override
  State<AiTutorScreen> createState() => _AiTutorScreenState();
}

class _AiTutorScreenState extends State<AiTutorScreen> {
  final List<_Message> _messages = [];
  final _ctrl = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  static const List<(String, IconData)> _suggestions = [
    ('Explain digitalis toxicity', Icons.favorite_rounded),
    ('Features of Cushing syndrome', Icons.medical_information_rounded),
    ('Type 1 vs Type 2 diabetes', Icons.compare_arrows_rounded),
    ('High-yield ECG findings', Icons.monitor_heart_rounded),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_Message(isUser: true, text: text));
      _ctrl.clear();
      _sending = true;
    });
    _scrollToBottom();
    String response;
    if (!widget.gemini.isConfigured) {
      response = 'Please add your AI provider key in ⚙ Settings. I support Gemini, Groq, and OpenRouter!';
    } else {
      response = await widget.gemini.askTutor(text);
    }
    if (mounted) {
      setState(() {
        _messages.add(_Message(isUser: false, text: response));
        _sending = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _messages.isEmpty ? _buildEmptyState() : _buildChatList()),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.line)),
      ),
      child: Row(children: [
        TapScale(
          onTap: () => Navigator.pop(context),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.greenTint, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.arrow_back_rounded, size: 20, color: AppTheme.primary),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(13),
            boxShadow: AppTheme.coloredShadow(AppTheme.primary),
          ),
          child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Tutor', style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.ink)),
            Text('Your personal study buddy', style: TextStyle(
              fontSize: 12, color: AppTheme.inkFaint)),
          ]),
        ),
        _headerBtn(widget.tts.isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
          () async { await widget.tts.toggle(); setState(() {}); }),
        if (_messages.isNotEmpty) ...[
          const SizedBox(width: 8),
          _headerBtn(Icons.delete_outline_rounded, () => setState(() => _messages.clear())),
        ],
      ]),
    );
  }

  Widget _headerBtn(IconData icon, VoidCallback onTap) => TapScale(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(color: AppTheme.greenTint, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 18, color: AppTheme.inkFaint),
    ),
  );

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 86, height: 86,
            decoration: BoxDecoration(
              color: AppTheme.primary, shape: BoxShape.circle,
              boxShadow: AppTheme.coloredShadow(AppTheme.primary)),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 38),
          ),
        ),
        const SizedBox(height: 18),
        Text('Hi! I\'m your AI Tutor', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800,
            color: AppTheme.ink, letterSpacing: -0.3)),
        const SizedBox(height: 8),
        Text(
          'Ask me about any medical concept, exam topic, or paste a tricky question.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.inkFaint, height: 1.55, fontSize: 14),
        ),
        const SizedBox(height: 24),
        Row(children: [
          Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppTheme.accent),
          SizedBox(width: 6),
          Text('Try asking', style: TextStyle(
            fontWeight: FontWeight.w700, color: AppTheme.inkSoft, fontSize: 13)),
        ]),
        const SizedBox(height: 12),
        ..._suggestions.asMap().entries.map((e) => FadeSlideIn(
          index: e.key,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: TapScale(
              onTap: () => _send(e.value.$1),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppTheme.rMd),
                  border: Border.all(color: AppTheme.line),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.greenTint, borderRadius: BorderRadius.circular(10)),
                    child: Icon(e.value.$2, size: 18, color: AppTheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(e.value.$1, style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.ink))),
                  Icon(Icons.north_east_rounded, size: 15, color: AppTheme.inkFaint),
                ]),
              ),
            ),
          ),
        )),
      ],
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == _messages.length) return _buildTypingIndicator();
        return _buildMessage(_messages[i]);
      },
    );
  }

  Widget _buildMessage(_Message msg) {
    return FadeSlideIn(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 9),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: msg.isUser ? AppTheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(18).copyWith(
                        bottomRight: msg.isUser ? const Radius.circular(5) : null,
                        bottomLeft: msg.isUser ? null : const Radius.circular(5),
                      ),
                      border: msg.isUser ? null : Border.all(color: AppTheme.line),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Text(msg.text, style: TextStyle(
                      color: msg.isUser ? Colors.white : AppTheme.ink,
                      height: 1.55, fontSize: 14.5)),
                  ),
                  if (!msg.isUser)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: TapScale(
                        onTap: () => widget.tts.speak(msg.text),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.volume_up_rounded, size: 13, color: AppTheme.inkFaint),
                          SizedBox(width: 4),
                          Text('Read aloud', style: TextStyle(fontSize: 11, color: AppTheme.inkFaint)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
            if (msg.isUser) ...[
              const SizedBox(width: 9),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: AppTheme.greenSoft, shape: BoxShape.circle),
                child: Icon(Icons.person_rounded, size: 14, color: AppTheme.primary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
          child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: const Radius.circular(5)),
            border: Border.all(color: AppTheme.line),
            boxShadow: AppTheme.cardShadow,
          ),
          child: const _TypingDots(),
        ),
      ]),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.line),
              ),
              child: TextField(
                controller: _ctrl,
                maxLines: 4, minLines: 1,
                decoration: InputDecoration(
                  hintText: 'Ask me anything medical…',
                  hintStyle: TextStyle(color: AppTheme.inkFaint, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          TapScale(
            onTap: _sending ? null : () => _send(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _sending ? AppTheme.inkFaint : AppTheme.primary,
                shape: BoxShape.circle,
                boxShadow: _sending ? null : AppTheme.coloredShadow(AppTheme.primary),
              ),
              child: Icon(_sending ? Icons.more_horiz_rounded : Icons.send_rounded,
                color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_c.value - i * 0.2) % 1.0;
          final scale = 0.6 + 0.4 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 7, height: 7,
                decoration: BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle)),
            ),
          );
        }),
      ),
    );
  }
}

class _Message {
  final bool isUser;
  final String text;
  const _Message({required this.isUser, required this.text});
}
