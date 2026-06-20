import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/flashcard.dart';
import '../../services/flashcard_service.dart';
import '../../services/gemini_service.dart';
import '../../services/tts_service.dart';
import '../../services/github_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/soft_widgets.dart';

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
  Map<String, List<Flashcard>> _decks = {};
  bool _loading = true;

  // Deck multi-select
  bool _selectMode = false;
  final Set<String> _selectedDecks = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _tabs.addListener(() => setState(() {}));
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
    final decks = await FlashcardService.loadDecks();
    if (mounted) setState(() {
      _allCards = all;
      _dueCards = due;
      _decks = decks;
      // drop any selections whose deck no longer exists
      _selectedDecks.removeWhere((s) => !decks.containsKey(s));
      if (_selectedDecks.isEmpty) _selectMode = false;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    AppTheme.syncFrom(context);
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            gradient: AppTheme.flashcardGradient,
            height: 196,
            padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _backButton(),
                  const SizedBox(width: 14),
                  const Text('Flashcards', style: TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  const Spacer(),
                  TapScale(
                    onTap: _showAddCardDialog,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                    ),
                  ),
                ]),
                const Spacer(),
                Row(children: [
                  _statPill('${_dueCards.length}', 'due'),
                  const SizedBox(width: 10),
                  _statPill('${_allCards.length}', 'total'),
                ]),
                const SizedBox(height: 14),
                _buildTabSelector(),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.secondary))
                : TabBarView(
                    controller: _tabs,
                    children: [_buildReviewTab(), _buildAllCardsTab(), _buildGenerateTab()],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _backButton() => TapScale(
    onTap: () => Navigator.pop(context),
    child: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
    ),
  );

  Widget _statPill(String value, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(30)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
    ]),
  );

  Widget _buildTabSelector() {
    final labels = ['Review', 'Decks', 'Generate'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = _tabs.index == i;
          return Expanded(
            child: TapScale(
              onTap: () => _tabs.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(13)),
                child: Text(labels[i], textAlign: TextAlign.center, style: TextStyle(
                  color: active ? AppTheme.secondary : Colors.white,
                  fontWeight: FontWeight.w700, fontSize: 12.5)),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReviewTab() {
    if (_dueCards.isEmpty) {
      return SoftEmptyState(
        icon: Icons.spa_rounded,
        color: AppTheme.secondary,
        title: 'All caught up! 🌿',
        message: '${_allCards.length} cards in your deck. Come back later when more are due for review.',
        action: _ctaButton('Generate More Cards', () => _tabs.animateTo(2)),
      );
    }
    return _FlashcardReviewSession(
      cards: _dueCards, tts: widget.tts, onComplete: _load);
  }

  Widget _buildAllCardsTab() {
    if (_decks.isEmpty) {
      return SoftEmptyState(
        icon: Icons.style_rounded,
        color: AppTheme.secondary,
        title: 'No decks yet',
        message: 'Create cards manually or let AI generate high-yield cards from any topic. Cards group into decks by subject.',
        action: _ctaButton('Generate Flashcards', () => _tabs.animateTo(2)),
      );
    }
    final subjects = _decks.keys.toList()
      ..sort((a, b) => _deckName(a).compareTo(_deckName(b)));

    return Column(
      children: [
        if (_selectMode) _buildSelectionBar(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            itemCount: subjects.length,
            itemBuilder: (_, i) => FadeSlideIn(index: i, child: _buildDeckTile(subjects[i])),
          ),
        ),
      ],
    );
  }

  String _deckName(String subject) =>
      GithubService.subjectDisplayNames[subject] ?? subject;

  Widget _buildSelectionBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, size: 18, color: AppTheme.secondary),
        const SizedBox(width: 8),
        Expanded(child: Text('${_selectedDecks.length} deck${_selectedDecks.length == 1 ? '' : 's'} selected',
          style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 13.5))),
        TapScale(
          onTap: () => setState(() { _selectMode = false; _selectedDecks.clear(); }),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text('Cancel', style: TextStyle(
              color: AppTheme.inkSoft, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ),
        const SizedBox(width: 4),
        TapScale(
          onTap: _selectedDecks.isEmpty ? null : _confirmDeleteSelectedDecks,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedDecks.isEmpty ? AppTheme.inkFaint : AppTheme.incorrect,
              borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.delete_rounded, size: 16, color: Colors.white),
              SizedBox(width: 5),
              Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildDeckTile(String subject) {
    final cards = _decks[subject]!;
    final due = cards.where((c) => c.isDue).length;
    final selected = _selectedDecks.contains(subject);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: () {
          if (_selectMode) {
            _toggleDeck(subject);
          } else {
            _openDeck(subject);
          }
        },
        onLongPress: () {
          setState(() {
            _selectMode = true;
            _selectedDecks.add(subject);
          });
        },
        padding: const EdgeInsets.all(16),
        color: selected ? AppTheme.secondary.withValues(alpha: 0.08) : null,
        border: selected ? Border.all(color: AppTheme.secondary, width: 1.6) : null,
        child: Row(children: [
          if (_selectMode) ...[
            Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.secondary : AppTheme.inkFaint, size: 24),
            const SizedBox(width: 12),
          ] else
            IconBadge(icon: Icons.folder_rounded, color: AppTheme.secondary, size: 44),
          if (!_selectMode) const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_deckName(subject),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppTheme.ink)),
                const SizedBox(height: 3),
                Text('${cards.length} card${cards.length == 1 ? '' : 's'}'
                    '${due > 0 ? '  ·  $due due' : ''}',
                  style: TextStyle(fontSize: 12.5, color: AppTheme.inkFaint, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (due > 0 && !_selectMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999)),
              child: Text('$due due', style: TextStyle(
                color: AppTheme.gold, fontWeight: FontWeight.w700, fontSize: 11.5)),
            )
          else if (!_selectMode)
            Icon(Icons.chevron_right_rounded, color: AppTheme.inkFaint, size: 20),
        ]),
      ),
    );
  }

  void _toggleDeck(String subject) {
    setState(() {
      if (_selectedDecks.contains(subject)) {
        _selectedDecks.remove(subject);
        if (_selectedDecks.isEmpty) _selectMode = false;
      } else {
        _selectedDecks.add(subject);
      }
    });
  }

  Future<void> _openDeck(String subject) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => _DeckCardsScreen(subject: subject, tts: widget.tts),
    ));
    _load();
  }

  Future<void> _confirmDeleteSelectedDecks() async {
    final count = _selectedDecks.length;
    final cardCount = _selectedDecks.fold(0, (s, d) => s + (_decks[d]?.length ?? 0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: const Text('Delete decks?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('This removes $count deck${count == 1 ? '' : 's'} '
            'and all $cardCount card${cardCount == 1 ? '' : 's'} inside. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.incorrect),
            onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await FlashcardService.deleteBySubjects({..._selectedDecks});
      setState(() { _selectMode = false; _selectedDecks.clear(); });
      _load();
    }
  }

  Widget _buildGenerateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftCard(
            gradient: AppTheme.flashcardGradient,
            shadow: AppTheme.coloredShadow(AppTheme.secondary),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 26)),
              const SizedBox(width: 16),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('AI Card Generator', style: TextStyle(
                    color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Turn any topic into high-yield spaced-repetition cards.',
                    style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.4)),
                ],
              )),
            ]),
          ),
          const SizedBox(height: 22),
          _TopicFlashcardGenerator(gemini: widget.gemini, onGenerated: _load),
        ],
      ),
    );
  }

  Widget _ctaButton(String label, VoidCallback onTap) => TapScale(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.flashcardGradient,
        borderRadius: BorderRadius.circular(AppTheme.rMd),
        boxShadow: AppTheme.coloredShadow(AppTheme.secondary)),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
    ),
  );

  void _showAddCardDialog() {
    final frontCtrl = TextEditingController();
    final backCtrl = TextEditingController();
    String selectedSubject = 'General';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: const Text('Add Flashcard', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: frontCtrl, decoration: const InputDecoration(labelText: 'Front (question/cue)')),
            const SizedBox(height: 12),
            TextField(controller: backCtrl, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Back (answer/fact)')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedSubject,
              items: ['General', ...GithubService.availableSubjects]
                  .map((s) => DropdownMenuItem(value: s,
                    child: Text(GithubService.subjectDisplayNames[s] ?? s))).toList(),
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

}

/// Lists the cards inside one deck (subject). Tap a card to view it; long-press
/// to enter multi-select and bulk-delete cards.
class _DeckCardsScreen extends StatefulWidget {
  final String subject;
  final TtsService tts;
  const _DeckCardsScreen({required this.subject, required this.tts});

  @override
  State<_DeckCardsScreen> createState() => _DeckCardsScreenState();
}

class _DeckCardsScreenState extends State<_DeckCardsScreen> {
  List<Flashcard> _cards = [];
  bool _selectMode = false;
  final Set<String> _selected = {};

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final decks = await FlashcardService.loadDecks();
    if (mounted) setState(() {
      _cards = decks[widget.subject] ?? [];
      _selected.removeWhere((id) => !_cards.any((c) => c.id == id));
      if (_selected.isEmpty) _selectMode = false;
    });
  }

  String get _title => GithubService.subjectDisplayNames[widget.subject] ?? widget.subject;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          Container(
            color: AppTheme.secondary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(children: [
                  TapScale(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(_title, style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4))),
                  Text('${_cards.length}', style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
          if (_selectMode)
            Container(
              margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.secondary.withValues(alpha: 0.4)),
              ),
              child: Row(children: [
                Expanded(child: Text('${_selected.length} selected',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 13.5))),
                TapScale(
                  onTap: () => setState(() { _selectMode = false; _selected.clear(); }),
                  child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text('Cancel', style: TextStyle(color: AppTheme.inkSoft, fontWeight: FontWeight.w700, fontSize: 13))),
                ),
                const SizedBox(width: 4),
                TapScale(
                  onTap: _selected.isEmpty ? null : _deleteSelected,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _selected.isEmpty ? AppTheme.inkFaint : AppTheme.incorrect,
                      borderRadius: BorderRadius.circular(10)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.delete_rounded, size: 16, color: Colors.white),
                      SizedBox(width: 5),
                      Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                ),
              ]),
            ),
          Expanded(
            child: _cards.isEmpty
                ? SoftEmptyState(
                    icon: Icons.style_rounded, color: AppTheme.secondary,
                    title: 'Deck empty', message: 'All cards in this deck were removed.')
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                    itemCount: _cards.length,
                    itemBuilder: (_, i) => FadeSlideIn(index: i, child: _cardTile(_cards[i])),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _cardTile(Flashcard card) {
    final isDue = card.isDue;
    final selected = _selected.contains(card.id);
    final color = isDue ? AppTheme.accent : AppTheme.correct;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: () => _selectMode ? _toggle(card.id) : _showDetail(card),
        onLongPress: () => setState(() { _selectMode = true; _selected.add(card.id); }),
        color: selected ? AppTheme.secondary.withValues(alpha: 0.08) : null,
        border: selected ? Border.all(color: AppTheme.secondary, width: 1.6) : null,
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          if (_selectMode) ...[
            Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? AppTheme.secondary : AppTheme.inkFaint, size: 24),
            const SizedBox(width: 12),
          ] else ...[
            IconBadge(
              icon: isDue ? Icons.schedule_rounded : Icons.check_circle_rounded,
              color: color, size: 44),
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppTheme.ink, height: 1.35)),
          ),
          if (!_selectMode) ...[
            const SizedBox(width: 10),
            Text(isDue ? 'Due' : 'In ${card.interval}d',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ]),
      ),
    );
  }

  void _toggle(String id) => setState(() {
    if (_selected.contains(id)) {
      _selected.remove(id);
      if (_selected.isEmpty) _selectMode = false;
    } else {
      _selected.add(id);
    }
  });

  Future<void> _deleteSelected() async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: const Text('Delete cards?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remove $n card${n == 1 ? '' : 's'} from this deck? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.incorrect),
            onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await FlashcardService.deleteCards({..._selected});
      setState(() { _selectMode = false; _selected.clear(); });
      _load();
    }
  }

  void _showDetail(Flashcard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.rXl))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 5,
              decoration: BoxDecoration(color: AppTheme.inkFaint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 18),
            Text('FRONT', style: TextStyle(color: AppTheme.inkFaint, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(card.front, style: TextStyle(fontSize: 16, height: 1.5, color: AppTheme.ink, fontWeight: FontWeight.w500)),
            const SizedBox(height: 18),
            Text('BACK', style: TextStyle(color: AppTheme.inkFaint, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(card.back, style: TextStyle(fontSize: 15.5, height: 1.55, color: AppTheme.ink)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: FilledButton.icon(
                onPressed: () { widget.tts.speak(card.back); },
                icon: const Icon(Icons.volume_up_rounded, size: 18),
                label: const Text('Read aloud'))),
              const SizedBox(width: 12),
              TapScale(
                onTap: () async {
                  Navigator.pop(context);
                  await FlashcardService.deleteCard(card.id);
                  _load();
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.incorrect.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.delete_outline_rounded, color: AppTheme.incorrect),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
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
      return SoftEmptyState(
        icon: Icons.emoji_events_rounded,
        color: AppTheme.secondary,
        title: 'Session complete! 🎉',
        message: 'You reviewed $_reviewed card${_reviewed == 1 ? '' : 's'}. Your future self thanks you.',
        action: TapScale(
          onTap: widget.onComplete,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              gradient: AppTheme.flashcardGradient,
              borderRadius: BorderRadius.circular(AppTheme.rMd),
              boxShadow: AppTheme.coloredShadow(AppTheme.secondary)),
            child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    }

    final card = widget.cards[_index];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Card ${_index + 1} of ${widget.cards.length}',
                style: TextStyle(color: AppTheme.inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
              SoftChip(label: GithubService.subjectDisplayNames[card.subject] ?? card.subject, color: AppTheme.secondary),
            ]),
            const SizedBox(height: 10),
            SoftProgressBar(value: _index / widget.cards.length, color: AppTheme.secondary, height: 7),
          ]),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _FlipCard(
              flipped: _flipped,
              onTap: () {
                setState(() => _flipped = !_flipped);
                if (_flipped) widget.tts.speak(card.back);
              },
              front: _cardFace(card.front, false),
              back: _cardFace(card.back, true),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          child: _flipped ? _buildRatingButtons(card) : const SizedBox(width: double.infinity),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _cardFace(String text, bool isBack) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: isBack ? AppTheme.flashcardGradient : null,
        color: isBack ? null : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.rXl),
        boxShadow: isBack ? AppTheme.coloredShadow(AppTheme.secondary) : AppTheme.softShadow,
      ),
      child: Stack(
        children: [
          if (isBack)
            Positioned(right: -20, top: -20,
              child: Icon(Icons.lightbulb_rounded, size: 120, color: Colors.white.withValues(alpha: 0.12))),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isBack ? Colors.white.withValues(alpha: 0.22) : AppTheme.secondary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20)),
                  child: Text(isBack ? 'ANSWER' : 'QUESTION', style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
                    color: isBack ? Colors.white : AppTheme.secondary)),
                ),
                const SizedBox(height: 22),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(text, textAlign: TextAlign.center, style: TextStyle(
                      fontSize: 19, height: 1.5, fontWeight: FontWeight.w600,
                      color: isBack ? Colors.white : AppTheme.ink)),
                  ),
                ),
                const SizedBox(height: 22),
                if (!isBack)
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.touch_app_rounded, size: 15, color: AppTheme.inkFaint),
                    SizedBox(width: 6),
                    Text('Tap to flip', style: TextStyle(color: AppTheme.inkFaint, fontSize: 12.5)),
                  ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButtons(Flashcard card) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Text('How well did you remember?',
            style: TextStyle(color: AppTheme.inkSoft, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(children: [
            _ratingButton('Again', 0, AppTheme.incorrect, card),
            const SizedBox(width: 10),
            _ratingButton('Hard', 2, AppTheme.warning, card),
            const SizedBox(width: 10),
            _ratingButton('Good', 4, AppTheme.correct, card),
            const SizedBox(width: 10),
            _ratingButton('Easy', 5, AppTheme.secondary, card),
          ]),
        ],
      ),
    );
  }

  Widget _ratingButton(String label, int quality, Color color, Flashcard card) {
    return Expanded(
      child: TapScale(
        onTap: () async {
          final updated = card.withSm2Update(quality);
          await FlashcardService.updateCard(updated);
          setState(() { _index++; _flipped = false; _reviewed++; });
          widget.tts.stop();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.4)),
          child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)),
        ),
      ),
    );
  }
}

/// A 3D flip animation between front and back faces.
class _FlipCard extends StatelessWidget {
  final bool flipped;
  final VoidCallback onTap;
  final Widget front;
  final Widget back;
  const _FlipCard({required this.flipped, required this.onTap, required this.front, required this.back});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: flipped ? 1 : 0),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
        builder: (context, t, _) {
          final angle = t * math.pi;
          final showBack = t > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()..setEntry(3, 2, 0.0012)..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: back)
                : front,
          );
        },
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
  bool _statusOk = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Topic', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          decoration: const InputDecoration(hintText: 'e.g. Thyroid hormones, Vitamin D, Beta blockers'),
        ),
        const SizedBox(height: 16),
        Text('Subject', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _subject,
          decoration: const InputDecoration(),
          borderRadius: AppTheme.radiusMd,
          items: ['General', ...GithubService.availableSubjects]
              .map((s) => DropdownMenuItem(value: s,
                child: Text(GithubService.subjectDisplayNames[s] ?? s))).toList(),
          onChanged: (v) => setState(() => _subject = v!),
        ),
        const SizedBox(height: 20),
        if (!widget.gemini.isConfigured)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 20),
              SizedBox(width: 10),
              Expanded(child: Text('Add an AI provider key in Settings to generate cards.',
                style: TextStyle(fontSize: 13, color: AppTheme.ink))),
            ]),
          )
        else ...[
          TapScale(
            onTap: _generating ? null : _generate,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _generating ? null : AppTheme.flashcardGradient,
                color: _generating ? AppTheme.inkFaint : null,
                borderRadius: BorderRadius.circular(AppTheme.rMd),
                boxShadow: _generating ? null : AppTheme.coloredShadow(AppTheme.secondary)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                if (_generating)
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                else
                  const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(_generating ? 'Generating…' : 'Generate 5 Cards with AI',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
            ),
          ),
          if (_status != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: (_statusOk ? AppTheme.correct : AppTheme.incorrect).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Icon(_statusOk ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                  color: _statusOk ? AppTheme.correct : AppTheme.incorrect, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(_status!, style: TextStyle(
                  color: _statusOk ? AppTheme.correct : AppTheme.incorrect, fontSize: 13))),
              ]),
            ),
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
      setState(() { _status = error; _statusOk = false; _generating = false; });
      return;
    }
    await FlashcardService.addCards(cards);
    setState(() { _status = '${cards.length} flashcards created!'; _statusOk = true; _generating = false; });
    widget.onGenerated();
  }
}
