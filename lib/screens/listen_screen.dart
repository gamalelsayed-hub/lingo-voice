import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/levels.dart';
import '../services/listen_session.dart';

class ListenScreen extends StatefulWidget {
  const ListenScreen({super.key, required this.level, this.autoStart = false});

  final CefrLevel level;

  /// Starts listening as soon as the screen opens.
  final bool autoStart;

  @override
  State<ListenScreen> createState() => _ListenScreenState();
}

class _ListenScreenState extends State<ListenScreen> {
  late final ListenSession _session = ListenSession.forLevel(widget.level);

  @override
  void initState() {
    super.initState();
    if (widget.autoStart && !_session.listening) _session.start();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final s = _session;
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: Text('الاستماع (${widget.level.code})')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.summarize),
                    label: Text('ملخص ذكي'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.bolt),
                    label: Text('ترجمة فورية'),
                  ),
                ],
                selected: {s.instantMode},
                onSelectionChanged: (v) => s.instantMode = v.first,
              ),
              const SizedBox(height: 8),
              Text(
                s.instantMode ? 'بعد كل جملة تقولها تسمع ترجمتها بالإنجليزي.' : 'التطبيق يسمع بهدوء، ويعطيك أهم جملك بالإنجليزي مع الكلمات الجديدة.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              Center(
                child: SizedBox.square(
                  dimension: 160,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor: s.listening
                          ? theme.colorScheme.error
                          : null,
                    ),
                    onPressed: s.listening ? s.stop : s.start,
                    child: Icon(s.listening ? Icons.stop : Icons.mic, size: 72),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                s.speaking
                    ? 'أتكلم الآن...'
                    : s.listening
                    ? 'أسمعك... تكلم بالعربي براحتك.\n'
                          'تقدر تطلع من التطبيق أو تقفل الشاشة، وبيكمل يسمعك.'
                    : 'اضغط الزر وابدأ الكلام',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (s.partial.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    s.partial,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.outline),
                  ),
                ),
              if (s.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    s.error!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              if (s.notice != null)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  margin: const EdgeInsets.only(top: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(s.notice!),
                  ),
                ),
              if (s.listening && !s.instantMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: s.speaking ? null : s.summarize,
                    icon: const Icon(Icons.headphones),
                    label: const Text('اسمع الملخص الآن'),
                  ),
                ),
              if (s.lastSummary != null) _SummaryCard(session: s),
              if (s.newCards > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('أضفنا ${s.newCards} بطاقة جديدة للمراجعة.'),
                ),
              const SizedBox(height: 16),
              if (s.history.isNotEmpty)
                Text(
                  'ما قلته في هذه الجلسة',
                  style: theme.textTheme.titleMedium,
                ),
              for (final sentence in s.history.reversed)
                Card(
                  child: _SentenceTile(
                    english: sentence.english,
                    arabic: sentence.arabic,
                    session: s,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.session});

  final ListenSession session;

  @override
  Widget build(BuildContext context) {
    final summary = session.lastSummary!;
    final theme = Theme.of(context);
    final example = summary.sentences.isEmpty
        ? ''
        : summary.sentences.first.english;
    return Card(
      color: theme.colorScheme.secondaryContainer,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('آخر ملخص', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final s in summary.sentences)
              _SentenceTile(english: s.english, session: session),
            if (summary.words.isNotEmpty) ...[
              const Divider(),
              Text('كلمات جديدة', style: theme.textTheme.titleSmall),
              Wrap(
                spacing: 6,
                children: [
                  for (final w in summary.words)
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text('${w.word} = ${w.meaning}'),
                      onPressed: () => session.addCard(
                        w,
                        summary.sentences
                            .map((s) => s.english)
                            .firstWhere(
                              (e) => e.toLowerCase().contains(w.word),
                              orElse: () => example,
                            ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// An English sentence with buttons to hear it again and to copy it.
class _SentenceTile extends StatelessWidget {
  const _SentenceTile({
    required this.english,
    required this.session,
    this.arabic,
  });

  final String english;
  final String? arabic;
  final ListenSession session;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsetsDirectional.only(start: 12, end: 4),
      title: arabic == null
          ? Text(english, textDirection: TextDirection.ltr)
          : Text(arabic!),
      subtitle: arabic == null
          ? null
          : Text(english, textDirection: TextDirection.ltr),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            tooltip: 'استمع',
            onPressed: () => session.replay(english),
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'نسخ',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: english));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('تم النسخ')));
            },
          ),
        ],
      ),
    );
  }
}
