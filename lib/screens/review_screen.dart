import 'package:flutter/material.dart';

import '../data/levels.dart';
import '../logic/srs.dart';
import '../services/store.dart';
import '../services/voice_service.dart';

/// Voice flashcards. "Hands-free" plays every due card aloud, for review
/// while walking; otherwise the learner grades each card.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.level});

  final CefrLevel level;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final _store = Store.instance;
  final _voice = VoiceService.instance;
  late List<Flashcard> _all;
  late List<Flashcard> _due;
  int _index = 0;
  bool _revealed = false;
  bool _handsFree = false;

  @override
  void initState() {
    super.initState();
    _all = _store.cards;
    final now = DateTime.now();
    _due = _all.where((c) => c.isDue(now)).toList();
    _voice.init().then((_) => _playCurrent());
  }

  @override
  void dispose() {
    _handsFree = false;
    _voice.stop();
    super.dispose();
  }

  Flashcard? get _card => _index < _due.length ? _due[_index] : null;

  Future<void> _playCurrent({bool full = false}) async {
    final card = _card;
    if (card == null) return;
    await _voice.english(card.word, rate: widget.level.speechRate);
    if (!full) return;
    await Future.delayed(const Duration(seconds: 2));
    await _voice.arabic(card.meaning);
    if (card.example.isNotEmpty) {
      await _voice.english(card.example, rate: widget.level.speechRate);
    }
  }

  void _grade(bool known) {
    _card!.review(known: known);
    _store.cards = _all;
    setState(() {
      _index++;
      _revealed = false;
    });
    _playCurrent();
  }

  Future<void> _runHandsFree() async {
    setState(() => _handsFree = true);
    for (var i = _index; i < _due.length && _handsFree && mounted; i++) {
      setState(() {
        _index = i;
        _revealed = true;
      });
      await _playCurrent(full: true);
      await Future.delayed(const Duration(seconds: 2));
    }
    if (mounted) setState(() => _handsFree = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = _card;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المراجعة'),
        actions: [
          if (_due.isNotEmpty)
            TextButton.icon(
              onPressed: _handsFree
                  ? () => setState(() => _handsFree = false)
                  : _runHandsFree,
              icon: Icon(_handsFree ? Icons.pause : Icons.directions_walk),
              label: Text(_handsFree ? 'إيقاف' : 'بدون يدين'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: card == null
            ? Center(
                child: Text(
                  _all.isEmpty
                      ? 'لا توجد بطاقات بعد. تكلم في وضع الاستماع، والكلمات اللي تتكرر في كلامك تصير بطاقات هنا.'
                      : 'خلصت مراجعة اليوم! ارجع بكرة.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${_index + 1} من ${_due.length}',
                    textAlign: TextAlign.center,
                  ),
                  const Spacer(),
                  Text(
                    card.word,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.volume_up, size: 32),
                    onPressed: () => _playCurrent(full: _revealed),
                  ),
                  if (_revealed) ...[
                    Text(
                      card.meaning,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      card.example,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                  const Spacer(),
                  if (!_revealed)
                    FilledButton(
                      onPressed: () {
                        setState(() => _revealed = true);
                        _playCurrent(full: true);
                      },
                      child: const Text('اكشف المعنى'),
                    )
                  else if (!_handsFree)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _grade(false),
                            child: const Text('ما عرفتها'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _grade(true),
                            child: const Text('عرفتها'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
      ),
    );
  }
}
