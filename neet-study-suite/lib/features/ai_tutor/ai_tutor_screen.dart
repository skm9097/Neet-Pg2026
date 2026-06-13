import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
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
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _messages.isEmpty ? _buildEmptyState() : _buildChatList()),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppTheme.rXl)),
      child: Container(
        decoration: const BoxDecoration(gradient: AppTheme.tutorGradient),
        child: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              // decorative blobs
              Positioned(top: -18, right: -18, child: _headerBlob(90, 0.15)),
              Positioned(bottom: -30, left: -20, child: _headerBlob(110, 0.10)),
              Positioned(top: 18, left: 60, child: _headerBlob(28, 0.08)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Row(children: [
                  TapScale(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [BoxShadow(
                        color: Colors.white.withValues(alpha: 0.15),
                        blurRadius: 12, spreadRadius: 2)],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('AI Tutor', style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white)),
                      Text('Your personal study buddy', style: TextStyle(
                        fontSize: 12, color: Colors.white70)),
                    ]),
                  ),
                  _headerBtn(widget.tts.isEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    () async { await widget.tts.toggle(); setState(() {}); }),
                  if (_messages.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _headerBtn(Icons.delete_outline_rounded, () => setState(() => _messages.clear())),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerBlob(double size, double opacity) => Container(
    width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity)),
  );

  Widget _headerBtn(IconData icon, VoidCallback onTap) => TapScale(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, size: 18, color: Colors.white),
    ),
  );

  Widget _buildEmptyState() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        const SizedBox(height: 16),
        const Center(child: _PulsingAiOrb()),
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
                  color: AppTheme.cardBg,
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
                      color: msg.isUser ? AppTheme.primary : AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(18).copyWith(
                        bottomRight: msg.isUser ? const Radius.circular(5) : null,
                        bottomLeft: msg.isUser ? null : const Radius.circular(5),
                      ),
                      border: msg.isUser ? null : Border.all(color: AppTheme.line),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: msg.isUser
                        ? Text(msg.text, style: const TextStyle(
                            color: Colors.white, height: 1.55, fontSize: 14.5))
                        : _MarkdownResponse(text: msg.text),
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
            color: AppTheme.cardBg,
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
        color: AppTheme.cardBg,
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
                style: TextStyle(color: AppTheme.ink, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Ask me anything medical…',
                  hintStyle: TextStyle(color: AppTheme.inkFaint, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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

// ─── Markdown renderer for AI responses ───────────────────────────────────────

class _MarkdownResponse extends StatelessWidget {
  final String text;
  const _MarkdownResponse({required this.text});

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: TextStyle(color: AppTheme.ink, fontSize: 14.5, height: 1.6),
        h1: TextStyle(color: AppTheme.ink, fontSize: 19, fontWeight: FontWeight.w800, height: 1.4),
        h2: TextStyle(color: AppTheme.ink, fontSize: 17, fontWeight: FontWeight.w700, height: 1.4),
        h3: TextStyle(color: AppTheme.ink, fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
        h4: TextStyle(color: AppTheme.inkSoft, fontSize: 14, fontWeight: FontWeight.w600),
        strong: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w700),
        em: TextStyle(color: AppTheme.inkSoft, fontStyle: FontStyle.italic),
        code: TextStyle(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppTheme.secondary,
          backgroundColor: AppTheme.terraSoft,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppTheme.terraSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.line),
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppTheme.greenTint,
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: AppTheme.primary, width: 3)),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        blockquote: TextStyle(color: AppTheme.inkSoft, fontSize: 14, height: 1.5),
        listBullet: TextStyle(color: AppTheme.primary, fontSize: 14),
        tableHead: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w700, fontSize: 13),
        tableBody: TextStyle(color: AppTheme.ink, fontSize: 13),
        tableBorder: TableBorder.all(color: AppTheme.line, width: 1),
        tableHeadAlign: TextAlign.left,
        tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.line, width: 1))),
        a: TextStyle(color: AppTheme.primary, decoration: TextDecoration.underline),
        h1Padding: const EdgeInsets.only(top: 8, bottom: 4),
        h2Padding: const EdgeInsets.only(top: 6, bottom: 2),
        h3Padding: const EdgeInsets.only(top: 4, bottom: 2),
        blockSpacing: 8,
        listIndent: 16,
      ),
    );
  }
}

// ─── Pulsing AI orb for empty state ───────────────────────────────────────────

class _PulsingAiOrb extends StatefulWidget {
  const _PulsingAiOrb();
  @override
  State<_PulsingAiOrb> createState() => _PulsingAiOrbState();
}

class _PulsingAiOrbState extends State<_PulsingAiOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) {
        final g = _pulse.value;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 114 + g * 16, height: 114 + g * 16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.lavender.withValues(alpha: 0.07 + g * 0.06),
              ),
            ),
            Container(
              width: 98 + g * 8, height: 98 + g * 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.lavender.withValues(alpha: 0.11 + g * 0.08),
              ),
            ),
            Container(
              width: 82, height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF5E8B9E), Color(0xFF4A7588)],
                ),
                boxShadow: [BoxShadow(
                  color: const Color(0xFF5E8B9E).withValues(alpha: 0.28 + g * 0.22),
                  blurRadius: 18 + g * 14, spreadRadius: 2 + g * 6,
                )],
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 36),
            ),
          ],
        );
      },
    );
  }
}

// ─── Typing animation ─────────────────────────────────────────────────────────

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
          final t = (_c.value - i * 0.22).abs() % 1.0;
          final scale = 0.55 + 0.45 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          final opacity = 0.4 + 0.6 * (t < 0.5 ? t * 2 : (1 - t) * 2);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3.5),
            child: Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.lavender, AppTheme.primary]),
                    shape: BoxShape.circle)),
              ),
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
