import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/levels.dart';
import '../services/store.dart';
import '../services/translation_service.dart';
import '../services/voice_service.dart';
import 'listen_screen.dart';
import 'placement_screen.dart';
import 'review_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = Store.instance;
  bool _modelsReady = false;
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _checkModels();
  }

  Future<void> _checkModels() async {
    final ready = await TranslationService.instance.modelsReady();
    if (mounted) setState(() => _modelsReady = ready);
  }

  Future<void> _downloadModels() async {
    setState(() => _downloading = true);
    Object? error;
    try {
      await TranslationService.instance.downloadModels();
    } catch (e) {
      error = e;
    }
    if (!mounted) return;
    setState(() {
      _downloading = false;
      _modelsReady = error == null;
    });
    if (error != null) _showDownloadError(error);
  }

  void _showDownloadError(Object error) {
    final details = error is PlatformException
        ? '${error.code}: ${error.message}'
        : error.toString();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ما قدرنا نحمّل الترجمة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تأكد أن خدمات Google Play محدّثة وأن التطبيق غير مقيّد في توفير البيانات، ثم حاول مرة ثانية. '
              'لو تكرر الخطأ، أرسل لنا النص التالي:',
            ),
            const SizedBox(height: 8),
            SelectableText(details, textDirection: TextDirection.ltr),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: details)),
            child: const Text('نسخ الخطأ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('حسناً'),
          ),
        ],
      ),
    );
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final level = _store.level;
    final now = DateTime.now();
    final cards = _store.cards;
    final due = cards.where((c) => c.isDue(now)).length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تعلّم الإنجليزية بصوتك'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'الإعدادات',
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.school, size: 36),
              title: Text(
                level == null
                    ? 'لم تحدد مستواك بعد'
                    : 'مستواك: ${level.code} (${level.arabicName})',
              ),
              subtitle: Text(
                level == null
                    ? 'ابدأ باختبار قصير (5 دقائق تقريباً)'
                    : 'تقدر تعيد الاختبار في أي وقت',
              ),
              trailing: FilledButton.tonal(
                onPressed: () => _open(const PlacementScreen()),
                child: Text(level == null ? 'ابدأ الاختبار' : 'أعد الاختبار'),
              ),
            ),
          ),
          if (!_modelsReady)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.download),
                title: const Text('حمّل الترجمة على الجهاز'),
                subtitle: const Text(
                  'مرة واحدة فقط (حوالي 60 ميجا). بعدها الترجمة تعمل بدون إنترنت.',
                ),
                trailing: _downloading
                    ? const CircularProgressIndicator()
                    : FilledButton(
                        onPressed: _downloadModels,
                        child: const Text('تحميل'),
                      ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: FilledButton.icon(
              icon: const Icon(Icons.mic, size: 48),
              label: const Text(
                'ابدأ الاستماع',
                style: TextStyle(fontSize: 22),
              ),
              onPressed: level == null || !_modelsReady
                  ? null
                  : () => _open(ListenScreen(level: level)),
            ),
          ),
          if (level == null || !_modelsReady)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'لازم تحدد مستواك وتحمّل الترجمة أولاً.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.style, size: 36),
              title: const Text('بطاقات المراجعة الصوتية'),
              subtitle: Text('${cards.length} بطاقة، منها $due جاهزة للمراجعة'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _open(ReviewScreen(level: level ?? CefrLevel.a1)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'التطبيق لا يسجّل الصوت. يحوّل كلامك إلى نص على جهازك فقط، '
            'وشغّله وأنت تتكلم أنت، حتى لا يلتقط كلام الآخرين.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _testVoice(BuildContext context) async {
    final voice = VoiceService.instance;
    final messenger = ScaffoldMessenger.of(context);
    voice.lastError = null;
    final ok = await voice.english('Hello! This is your English voice.');
    final message = ok && voice.lastError == null
        ? (voice.hasEnglish
              ? 'لو سمعت الجملة، الصوت شغال.'
              : 'الجوال ما فيه صوت إنجليزي مثبت.')
        : 'الجوال ما قدر ينطق: ${voice.lastError}';
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'لهجتك العربية',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in arabicDialects.entries)
                    ChoiceChip(
                      label: Text(e.value),
                      selected: _store.dialect == e.key,
                      onSelected: (_) => setSheet(() => _store.dialect = e.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'الملخص الذكي',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [0, 5, 10])
                    ChoiceChip(
                      label: Text(m == 0 ? 'في النهاية فقط' : 'كل $m دقائق'),
                      selected: _store.summaryMinutes == m,
                      onSelected: (_) =>
                          setSheet(() => _store.summaryMinutes = m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.record_voice_over),
                label: const Text('جرّب صوت التطبيق'),
                onPressed: () => _testVoice(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
