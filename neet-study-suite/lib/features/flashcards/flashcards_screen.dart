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
  bool _loading = true;

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
    if (mounted) setState(() {
      _allCards = all;
      _dueCards = due;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
                ? const Center(child: CircularProgressIndicator(color: AppTheme.secondary))
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
    final labels = ['Review', 'All Cards', 'Generate'];
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
    if (_allCards.isEmpty) {
      return SoftEmptyState(
        icon: Icons.style_rounded,
        color: AppTheme.secondary,
        title: 'No flashcards yet',
        message: 'Create cards manually or let AI generate high-yield cards from any topic.',
        action: _ctaButton('Generate Flashcards', () => _tabs.animateTo(2)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      itemCount: _allCards.length,
      itemBuilder: (_, i) => FadeSlideIn(index: i, child: _buildCardTile(_allCards[i])),
    );
  }

  Widget _buildCardTile(Flashcard card) {
    final isDue = card.isDue;
    final color = isDue ? AppTheme.accent : AppTheme.correct;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SoftCard(
        onTap: () => _showCardDetail(card),
        onLongPress: () => _confirmDelete(card),
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          IconBadge(
            icon: isDue ? Icons.schedule_rounded : Icons.check_circle_rounded,
            color: color, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: AppTheme.ink, height: 1.35)),
                const SizedBox(height: 6),
                SoftChip(
                  label: GithubService.subjectDisplayNames[card.subject] ?? card.subject,
                  color: AppTheme.secondary),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(children: [
            Text(isDue ? 'Due' : 'In ${card.interval}d',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ]),
      ),
    );
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

  void _showCardDetail(Flashcard card) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.rXl))),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 5,
              decoration: BoxDecoration(color: AppTheme.inkFaint.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 18),
            SoftChip(label: GithubService.subjectDisplayNames[card.subject] ?? card.subject, color: AppTheme.secondary),
            const SizedBox(height: 16),
            const Text('FRONT', style: TextStyle(color: AppTheme.inkFaint, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(card.front, style: const TextStyle(fontSize: 16, height: 1.5, color: AppTheme.ink, fontWeight: FontWeight.w500)),
            const SizedBox(height: 18),
            const Text('BACK', style: TextStyle(color: AppTheme.inkFaint, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 1)),
            const SizedBox(height: 6),
            Text(card.back, style: const TextStyle(fontSize: 15.5, height: 1.55, color: AppTheme.ink)),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _miniStat('Ease', card.easeFactor.toStringAsFixed(2)),
                _miniStat('Interval', '${card.interval}d'),
                _miniStat('Reps', '${card.repetitions}'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value) => Column(children: [
    Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.secondary, fontSize: 16)),
    Text(label, style: const TextStyle(color: AppTheme.inkSoft, fontSize: 11)),
  ]);

  Future<void> _confirmDelete(Flashcard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.radiusLg),
        title: const Text('Delete Card?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(card.front, maxLines: 2, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.incorrect),
            onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
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
                style: const TextStyle(color: AppTheme.inkSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
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
        color: isBack ? null : Colors.white,
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
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
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
          const Text('How well did you remember?',
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
        const Text('Topic', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          decoration: const InputDecoration(hintText: 'e.g. Thyroid hormones, Vitamin D, Beta blockers'),
        ),
        const SizedBox(height: 16),
        const Text('Subject', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink, fontSize: 14)),
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
            child: Row(children: const [
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
