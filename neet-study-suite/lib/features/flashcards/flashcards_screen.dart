import 'package:flutter/material.dart';
import '../../models/flashcard.dart';
import '../../services/flashcard_service.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/github_service.dart';
import '../../core/theme/app_theme.dart';

class FlashcardsScreen extends StatefulWidget {
  final GeminiService gemini;
  final TtsService tts;
  const FlashcardsScreen({super.key, required this.gemini, required this.tts});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  List<Flashcard> _allCards = [];
  List<Flashcard> _dueCards = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final all = await FlashcardService.loadAll();
    final due = await FlashcardService.getDueCards();
    if (mounted) setState(() {
      _allCards = all;
      _dueCards = due;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: 'Review (${_dueCards.length})'),
            const Tab(text: 'All Cards'),
            const Tab(text: 'Generate'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddCardDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _buildReviewTab(),
                _buildAllCardsTab(),
                _buildGenerateTab(),
              ],
            ),
    );
  }

  Widget _buildReviewTab() {
    if (_dueCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 64, color: AppTheme.correct),
            const SizedBox(height: 16),
            const Text('All caught up!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('${_allCards.length} total cards • Come back later for more reviews.',
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _tabs.animateTo(2),
              child: const Text('Generate More Cards'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Text('${_dueCards.length} cards due for review',
                style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),
        Expanded(
          child: _FlashcardReviewSession(
            cards: _dueCards,
            tts: widget.tts,
            onComplete: () => _load(),
          ),
        ),
      ],
    );
  }

  Widget _buildAllCardsTab() {
    if (_allCards.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.style_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No flashcards yet'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => _tabs.animateTo(2),
              child: const Text('Generate Flashcards'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _allCards.length,
      itemBuilder: (_, i) => _buildCardTile(_allCards[i]),
    );
  }

  Widget _buildCardTile(Flashcard card) {
    final isDue = card.isDue;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isDue ? Colors.orange[100] : Colors.green[100],
          child: Icon(
            isDue ? Icons.schedule : Icons.check,
            color: isDue ? Colors.orange : Colors.green, size: 18,
          ),
        ),
        title: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(card.subject, style: const TextStyle(fontSize: 12)),
        trailing: Text(
          isDue ? 'Due' : 'In ${card.interval}d',
          style: TextStyle(color: isDue ? Colors.orange : Colors.grey, fontSize: 12),
        ),
        onTap: () => _showCardDetail(card),
        onLongPress: () => _confirmDelete(card),
      ),
    );
  }

  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('AI Flashcard Generator',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Generate spaced repetition cards using Gemini AI.',
            style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          _TopicFlashcardGenerator(gemini: widget.gemini, onGenerated: _load),
        ],
      ),
    );
  }

  void _showAddCardDialog() {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    String selectedSubject = 'General';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Flashcard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: frontCtrl, decoration: const InputDecoration(labelText: 'Front (question/cue)')),
            const SizedBox(height: 8),
            TextField(controller: backCtrl, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Back (answer/fact)')),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedSubject,
              items: ['General', ...GithubService.availableSubjects]
                  .map((s) => DropdownMenuItem(value: s,
                    child: Text(GithubService.subjectDisplayNames[s] ?? s)))
                  .toList(),
              onChanged: (v) => selectedSubject = v!,
              decoration: const InputDecoration(labelText: 'Subject'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (frontCtrl.text.trim().isEmpty || backCtrl.text.trim().isEmpty) return;
              await FlashcardService.addCards([
                Flashcard(
                  id: DateTime.now().microsecondsSinceEpoch.toString(),
                  front: frontCtrl.text.trim(),
                  back: backCtrl.text.trim(),
                  subject: selectedSubject,
                  createdAt: DateTime.now(),
                ),
              ]);
              if (mounted) { Navigator.pop(context); _load(); }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showCardDetail(Flashcard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(GithubService.subjectDisplayNames[card.subject] ?? card.subject)),
            const SizedBox(height: 12),
            const Text('Front', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(card.front, style: const TextStyle(fontSize: 16, height: 1.5)),
            const Divider(height: 24),
            const Text('Back', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(card.back, style: const TextStyle(fontSize: 16, height: 1.5)),
            const SizedBox(height: 12),
            Text('Ease: ${card.easeFactor.toStringAsFixed(2)} • '
              'Interval: ${card.interval}d • Reps: ${card.repetitions}',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(Flashcard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Card?'),
        content: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) { await FlashcardService.deleteCard(card.id); _load(); }
  }
}

class _FlashcardReviewSession extends StatefulWidget {
  final List<Flashcard> cards;
  final TtsService tts;
  final VoidCallback onComplete;
  const _FlashcardReviewSession({required this.cards, required this.tts, required this.onComplete});

  @override
  State<_FlashcardReviewSession> createState() => _FlashcardReviewSessionState();
}

class _FlashcardReviewSessionState extends State<_FlashcardReviewSession> {
  int _index = 0;
  bool _flipped = false;
  int _reviewed = 0;

  @override
  Widget build(BuildContext context) {
    if (_index >= widget.cards.length) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.done_all, size: 64, color: AppTheme.correct),
            const SizedBox(height: 16),
            Text('Session complete! $_reviewed cards reviewed.',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            FilledButton(onPressed: widget.onComplete, child: const Text('Done')),
          ],
        ),
      );
    }

    final card = widget.cards[_index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: LinearProgressIndicator(value: _index / widget.cards.length),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('${_index + 1} / ${widget.cards.length}',
            style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GestureDetector(
              onTap: () {
                setState(() => _flipped = !_flipped);
                if (_flipped) widget.tts.speak(card.back);
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _flipped ? _buildCardFace(card.back, Colors.blue[50]!, 'Answer', key: const ValueKey('back'))
                    : _buildCardFace(card.front, Colors.white, 'Question — tap to flip', key: const ValueKey('front')),
              ),
            ),
          ),
        ),
        if (_flipped) _buildRatingButtons(card),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCardFace(String text, Color color, String hint, {required Key key}) {
    return Card(
      key: key,
      color: color,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 16),
              Text(text, style: const TextStyle(fontSize: 18, height: 1.6), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingButtons(Flashcard card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          const Text('How well did you remember?',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _ratingButton('Again', 0, Colors.red, card),
              const SizedBox(width: 8),
              _ratingButton('Hard', 2, Colors.orange, card),
              const SizedBox(width: 8),
              _ratingButton('Good', 4, AppTheme.correct, card),
              const SizedBox(width: 8),
              _ratingButton('Easy', 5, AppTheme.secondary, card),
            ],
          ),
        ],
      ),
    );
  }

  Widget _ratingButton(String label, int quality, Color color, Flashcard card) {
    return Expanded(
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: color, padding: EdgeInsets.zero),
        onPressed: () async {
          final updated = card.withSm2Update(quality);
          await FlashcardService.updateCard(updated);
          setState(() { _index++; _flipped = false; _reviewed++; });
          widget.tts.stop();
        },
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _TopicFlashcardGenerator extends StatefulWidget {
  final GeminiService gemini;
  final VoidCallback onGenerated;
  const _TopicFlashcardGenerator({required this.gemini, required this.onGenerated});

  @override
  State<_TopicFlashcardGenerator> createState() => _TopicFlashcardGeneratorState();
}

class _TopicFlashcardGeneratorState extends State<_TopicFlashcardGenerator> {
  final _ctrl = TextEditingController();
  String _subject = 'General';
  bool _generating = false;
  String? _status;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _ctrl,
          decoration: const InputDecoration(
            labelText: 'Topic (e.g., "Thyroid hormones", "Vitamin D")',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _subject,
          decoration: const InputDecoration(labelText: 'Subject', border: OutlineInputBorder()),
          items: ['General', ...GithubService.availableSubjects]
              .map((s) => DropdownMenuItem(value: s,
                child: Text(GithubService.subjectDisplayNames[s] ?? s)))
              .toList(),
          onChanged: (v) => setState(() => _subject = v!),
        ),
        const SizedBox(height: 16),
        if (!widget.gemini.isConfigured)
          const Card(
            color: Color(0xFFFFF3E0),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(child: Text('Set your Gemini API key in Settings to use AI generation.',
                    style: TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
        if (widget.gemini.isConfigured) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome),
              label: Text(_generating ? 'Generating...' : 'Generate 5 Flashcards with AI'),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 12),
            Text(_status!, style: TextStyle(
              color: _status!.startsWith('✓') ? AppTheme.correct : Colors.red)),
          ],
        ],
      ],
    );
  }

  Future<void> _generate() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() { _generating = true; _status = null; });
    final (cards, error) = await widget.gemini.generateFlashcardsFromTopic(
      _ctrl.text.trim(), _subject);
    if (error != null) {
      setState(() { _status = error; _generating = false; });
      return;
    }
    await FlashcardService.addCards(cards);
    setState(() { _status = '✓ ${cards.length} flashcards created!'; _generating = false; });
    widget.onGenerated();
  }
}
