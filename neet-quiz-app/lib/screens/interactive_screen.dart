import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../services/gemini_service.dart';
import '../services/tts_service.dart';

class InteractiveScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;

  const InteractiveScreen({
    super.key,
    required this.gemini,
    required this.tts,
  });

  @override
  State<InteractiveScreen> createState() => _InteractiveScreenState();
}

class _InteractiveScreenState extends State<InteractiveScreen>
    with SingleTickerProviderStateMixin {
  final SpeechToText _stt = SpeechToText();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _messages = [];

  bool _sttReady = false;
  bool _listening = false;
  bool _thinking = false;
  String _liveText = '';

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = Tween(begin: 1.0, end: 1.18).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _initStt();
    _greet();
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onError: (_) => setState(() => _listening = false),
    );
    setState(() => _sttReady = ok);
  }

  void _greet() {
    const msg = 'Hi! I\'m your NEET-PG tutor. '
        'Hold the mic button and ask me anything — a drug mechanism, '
        'a clinical sign, a pathology concept. I\'ll explain it for the exam.';
    _addMsg(msg, isUser: false);
    widget.tts.speak(msg);
  }

  // ── STT control ────────────────────────────────────────────────────────────

  Future<void> _startListening() async {
    if (!_sttReady || _listening || _thinking) return;
    await widget.tts.stop();
    setState(() {
      _listening = true;
      _liveText = '';
    });
    await _stt.listen(
      onResult: (r) {
        setState(() => _liveText = r.recognizedWords);
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      localeId: 'en_US',
    );
  }

  Future<void> _stopListening() async {
    if (!_listening) return;
    await _stt.stop();
    final text = _liveText.trim();
    setState(() {
      _listening = false;
      _liveText = '';
    });
    if (text.isNotEmpty) await _send(text);
  }

  Future<void> _send(String text) async {
    _addMsg(text, isUser: true);
    setState(() => _thinking = true);
    _scrollDown();

    final reply = await widget.gemini.chat(text);

    setState(() => _thinking = false);
    _addMsg(reply, isUser: false);
    _scrollDown();
    widget.tts.speak(reply);
  }

  void _addMsg(String text, {required bool isUser}) =>
      setState(() => _messages.add(_Msg(text: text, isUser: isUser)));

  void _scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });

  @override
  void dispose() {
    _stt.stop();
    widget.tts.stop();
    widget.gemini.clearChat();
    _scroll.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            widget.tts.stop();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'AI Tutor',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white54),
            tooltip: 'New conversation',
            onPressed: () {
              widget.tts.stop();
              widget.gemini.clearChat();
              setState(() => _messages.clear());
              _greet();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildChat()),
          _buildLiveTextBar(),
          _buildMicBar(),
        ],
      ),
    );
  }

  Widget _buildChat() {
    if (_messages.isEmpty) {
      return const Center(
        child: Text('Starting…',
            style: TextStyle(color: Colors.white38, fontSize: 14)),
      );
    }
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemCount: _messages.length + (_thinking ? 1 : 0),
      itemBuilder: (_, i) {
        if (_thinking && i == _messages.length) return _buildTyping();
        return _buildBubble(_messages[i]);
      },
    );
  }

  Widget _buildBubble(_Msg msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: msg.isUser
              ? const Color(0xFF3B1F6A)
              : const Color(0xFF1A1A2E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(msg.isUser ? 18 : 4),
            bottomRight: Radius.circular(msg.isUser ? 4 : 18),
          ),
          border: msg.isUser
              ? null
              : Border.all(color: const Color(0xFF2A2A4A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!msg.isUser) ...[
              const Icon(Icons.smart_toy_rounded,
                  size: 16, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                msg.text,
                style: TextStyle(
                  color: msg.isUser ? Colors.white : Colors.white.withOpacity(0.9),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),
            if (msg.isUser) ...[
              const SizedBox(width: 8),
              const Icon(Icons.person_rounded,
                  size: 16, color: Color(0xFF9D71EA)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTyping() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          border: Border.all(color: const Color(0xFF2A2A4A)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.smart_toy_rounded,
                size: 16, color: Color(0xFF7C3AED)),
            const SizedBox(width: 10),
            _DotAnimation(),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTextBar() {
    if (!_listening && _liveText.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF7C3AED).withOpacity(0.5)),
      ),
      child: Text(
        _liveText.isEmpty ? 'Listening…' : _liveText,
        style: TextStyle(
          color: _liveText.isEmpty ? Colors.white38 : Colors.white,
          fontSize: 14,
          fontStyle:
              _liveText.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildMicBar() {
    final noKey = !widget.gemini.isConfigured;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D1A),
        border: Border(top: BorderSide(color: Color(0xFF1A1A2E))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (noKey)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'Add Gemini API key in Settings to enable the AI tutor',
                style: TextStyle(
                    color: Colors.amber.withOpacity(0.8), fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Text(
            _listening
                ? 'Release to send'
                : _thinking
                    ? 'Thinking…'
                    : !_sttReady
                        ? 'Microphone unavailable'
                        : 'Hold to speak',
            style: TextStyle(
              color: _listening
                  ? const Color(0xFF10B981)
                  : Colors.white.withOpacity(0.45),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTapDown: noKey || !_sttReady
                ? null
                : (_) => _startListening(),
            onTapUp: (_) => _stopListening(),
            onTapCancel: () => _stopListening(),
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (_, child) => Transform.scale(
                scale: _listening ? _pulse.value : 1.0,
                child: child,
              ),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _listening
                      ? const Color(0xFF10B981)
                      : noKey || !_sttReady
                          ? const Color(0xFF2A2A4A)
                          : const Color(0xFF7C3AED),
                  boxShadow: _listening
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withOpacity(0.5),
                            blurRadius: 24,
                            spreadRadius: 4,
                          )
                        ]
                      : [
                          BoxShadow(
                            color: const Color(0xFF7C3AED).withOpacity(0.35),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ],
                ),
                child: Icon(
                  _listening ? Icons.mic : Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Msg {
  final String text;
  final bool isUser;
  const _Msg({required this.text, required this.isUser});
}

class _DotAnimation extends StatefulWidget {
  @override
  State<_DotAnimation> createState() => _DotAnimationState();
}

class _DotAnimationState extends State<_DotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _dot = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        setState(() => _dot = (_ctrl.value * 3).floor() % 3);
      })
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      ['.  ', '.. ', '...'][_dot],
      style: const TextStyle(
          color: Color(0xFF7C3AED), fontSize: 18, fontWeight: FontWeight.w800),
    );
  }
}
