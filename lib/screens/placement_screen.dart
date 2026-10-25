import 'package:flutter/material.dart';

import '../data/levels.dart';
import '../data/placement_data.dart';
import '../logic/placement.dart';
import '../logic/text_utils.dart';
import '../services/speech_service.dart';
import '../services/store.dart';
import '../services/voice_service.dart';

/// Placement test: for each level, read one sentence aloud and answer two
/// vocabulary questions. The test stops at the first level the learner fails.
class PlacementScreen extends StatefulWidget {
  const PlacementScreen({super.key});

  @override
  State<PlacementScreen> createState() => _PlacementScreenState();
}

class _PlacementScreenState extends State<PlacementScreen> {
  final _scores = <CefrLevel, LevelScore>{};
  int _item = 0;

  /// -1 is the reading step, 0.. are vocabulary questions.
  int _step = -1;
  bool _listening = false;
  String? _heard;
  CefrLevel? _result;

  PlacementItem get _current => placementItems[_item];
  LevelScore get _score =>
      _scores.putIfAbsent(_current.level, () => LevelScore());

  Future<void> _read() async {
    final speech = SpeechService.instance;
    if (!await speech.init()) {
      _snack('لم نتمكن من تشغيل الميكروفون. تقدر تتخطى هذه الخطوة.');
      return;
    }
    setState(() {
      _listening = true;
      _heard = null;
    });
    final heard = await speech.listenOnce('en_US');
    if (!mounted) return;
    setState(() {
      _listening = false;
      _heard = heard;
      _score.pronunciation = wordMatchScore(_current.readAloud, heard);
    });
  }

  Future<void> _listenToSentence() async {
    final voice = VoiceService.instance;
    await voice.init();
    await voice.english(_current.readAloud, rate: 0.45);
  }

  void _answer(String option) {
    final q = _current.vocab[_step];
    _score.vocabTotal++;
    if (option == q.answer) _score.vocabCorrect++;
    _next();
  }

  void _next() {
    setState(() {
      _heard = null;
      if (_step + 1 < _current.vocab.length) {
        _step++;
        return;
      }
      final last = _item + 1 >= placementItems.length;
      if (!_score.passed || last) {
        _result = placementLevel(_scores);
        Store.instance.level = _result;
        return;
      }
      _item++;
      _step = -1;
    });
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('اختبار تحديد المستوى')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _result != null
            ? _buildResult(context)
            : _step < 0
            ? _buildReading(context)
            : _buildVocab(context),
      ),
    );
  }

  Widget _buildReading(BuildContext context) {
    final theme = Theme.of(context);
    final pron = _score.pronunciation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: _item / placementItems.length),
        const SizedBox(height: 24),
        Text('اقرأ هذه الجملة بصوت واضح:', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            _current.readAloud,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _listenToSentence,
          icon: const Icon(Icons.volume_up),
          label: const Text('اسمع النطق الصحيح'),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _listening ? null : _read,
          icon: Icon(_listening ? Icons.hearing : Icons.mic),
          label: Text(_listening ? 'أسمعك...' : 'اضغط واقرأ'),
        ),
        if (_heard != null) ...[
          const SizedBox(height: 16),
          Text('سمعت: "$_heard"', textDirection: TextDirection.ltr),
          if (pron != null)
            Text(
              'النتيجة: ${(pron * 100).round()}%',
              style: theme.textTheme.titleMedium,
            ),
        ],
        const Spacer(),
        Row(
          children: [
            TextButton(onPressed: _next, child: const Text('تخطَّ')),
            const Spacer(),
            FilledButton(
              onPressed: _heard == null ? null : _next,
              child: const Text('التالي'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVocab(BuildContext context) {
    final q = _current.vocab[_step];
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: _item / placementItems.length),
        const SizedBox(height: 24),
        Text('ما معنى هذه الكلمة؟', style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Text(
          q.word,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall,
        ),
        IconButton(
          icon: const Icon(Icons.volume_up),
          onPressed: () async {
            await VoiceService.instance.init();
            await VoiceService.instance.english(q.word);
          },
        ),
        const SizedBox(height: 16),
        for (final option in q.options)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => _answer(option),
              child: Text(option, style: const TextStyle(fontSize: 18)),
            ),
          ),
        TextButton(onPressed: () => _answer(''), child: const Text('لا أعرف')),
      ],
    );
  }

  Widget _buildResult(BuildContext context) {
    final level = _result!;
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.emoji_events, size: 72),
        const SizedBox(height: 16),
        Text(
          'مستواك',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        Text(
          level.code,
          textAlign: TextAlign.center,
          style: theme.textTheme.displayLarge,
        ),
        Text(
          level.arabicName,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 24),
        Text(
          'بنختار لك الجمل والكلمات المناسبة لهذا المستوى، ونسرّع النطق كل ما تقدمت.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ابدأ التعلم'),
        ),
      ],
    );
  }
}
