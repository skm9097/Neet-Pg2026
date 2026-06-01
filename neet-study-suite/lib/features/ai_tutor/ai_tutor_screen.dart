import 'package:flutter/material.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    _messages.add(const _Message(
      isUser: false,
      text: 'Hello! I\'m your NEET-PG AI Tutor powered by Gemini.\n\n'
        'Ask me anything about medical concepts, exam topics, or '
        'explanations. Examples:\n'
        '• "Explain the mechanism of digitalis toxicity"\n'
        '• "What are the classic features of Cushing syndrome?"\n'
        '• "Compare Type 1 vs Type 2 diabetes"\n\n'
        'Or paste a question you\'re confused about!',
    ));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(_Message(isUser: true, text: text));
      _ctrl.clear();
      _sending = true;
    });
    _scrollToBottom();

    String response;
    if (!widget.gemini.isConfigured) {
      response = 'Please configure your Gemini API key in Settings to use the AI Tutor.';
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Tutor'),
        actions: [
          IconButton(
            icon: Icon(widget.tts.isEnabled ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              await widget.tts.toggle();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => setState(() {
              _messages.clear();
              _messages.add(const _Message(isUser: false,
                text: 'Conversation cleared. How can I help you?'));
            }),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!widget.gemini.isConfigured)
            Container(
              color: Colors.amber[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Set Gemini API key in Settings for AI responses.',
                    style: TextStyle(fontSize: 12))),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _buildTypingIndicator();
                return _buildMessage(_messages[i]);
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildMessage(_Message msg) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: msg.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!msg.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.primary,
              child: const Icon(Icons.smart_toy, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: msg.isUser ? AppTheme.primary : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: msg.isUser ? const Radius.circular(4) : null,
                      bottomLeft: msg.isUser ? null : const Radius.circular(4),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Text(msg.text,
                    style: TextStyle(
                      color: msg.isUser ? Colors.white : null,
                      height: 1.5,
                    )),
                ),
                if (!msg.isUser) Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () => widget.tts.speak(msg.text),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.volume_up, size: 14, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (msg.isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppTheme.secondary,
              child: Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppTheme.primary,
            child: Icon(Icons.smart_toy, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Thinking...', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                maxLines: 3,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Ask a medical question...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              onPressed: _sending ? null : _send,
              backgroundColor: _sending ? Colors.grey : AppTheme.primary,
              child: Icon(_sending ? Icons.hourglass_empty : Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _Message {
  final bool isUser;
  final String text;
  const _Message({required this.isUser, required this.text});
}
