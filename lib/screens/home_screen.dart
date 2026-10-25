import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ota_update/ota_update.dart';

import '../data/levels.dart';
import '../services/listen_session.dart';
import '../services/store.dart';
import '../services/translation_service.dart';
import '../services/update_service.dart';
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
  AppUpdate? _update;
  bool _checkingUpdate = false;

  /// Download progress in percent while an update is downloading.
  int? _updateProgress;

  @override
  void initState() {
    super.initState();
    _checkModels();
    _checkForUpdate(quiet: true);
  }

  Future<void> _checkForUpdate({bool quiet = false}) async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    String? message;
    try {
      final update = await UpdateService.instance.check();
      if (mounted) setState(() => _update = update);
      if (update == null) message = 'عندك آخر نسخة.';
    } catch (e) {
      message = 'ما قدرنا نفحص التحديثات: $e';
    }
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
    if (!quiet && message != null) _snack(message);
  }

  void _installUpdate() {
    final update = _update;
    if (update == null) return;
    setState(() => _updateProgress = 0);
    UpdateService.instance
        .install(update)
        .listen(
          (event) {
            if (!mounted) return;
            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                setState(
                  () => _updateProgress = int.tryParse(event.value ?? ''),
                );
              case OtaStatus.INSTALLING:
              case OtaStatus.INSTALLATION_DONE:
                setState(() => _updateProgress = null);
              default:
                setState(() => _updateProgress = null);
                _snack(
                  'فشل التحديث (${event.status.name}): ${event.value ?? ''}',
                );
            }
          },
          onError: (Object e) {
            if (!mounted) return;
            setState(() => _updateProgress = null);
            _snack('فشل التحديث: $e');
          },
        );
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _chooseLevel() async {
    final chosen = await showDialog<CefrLevel>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر مستواك'),
        children: [
          for (final level in CefrLevel.values)
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(level),
              child: Text(
                '${level.code}  ${level.arabicName}',
                style: TextStyle(
                  fontWeight: level == _store.level ? FontWeight.bold : null,
                  fontSize: 17,
                ),
              ),
            ),
        ],
      ),
    );
    if (chosen == null) return;
    setState(() => _store.level = chosen);
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
            icon: _checkingUpdate
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Badge(
                    isLabelVisible: _update != null,
                    child: const Icon(Icons.system_update),
                  ),
            tooltip: 'فحص التحديثات',
            onPressed: _update != null
                ? _installUpdate
                : () => _checkForUpdate(),
          ),
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
          if (_update != null)
            Card(
              color: theme.colorScheme.primaryContainer,
              child: ListTile(
                leading: const Icon(Icons.system_update, size: 32),
                title: const Text('في نسخة جديدة من التطبيق'),
                subtitle: _updateProgress != null
                    ? LinearProgressIndicator(value: _updateProgress! / 100)
                    : const Text('اضغط تحديث، وبعدها وافق على التثبيت.'),
                trailing: FilledButton(
                  onPressed: _updateProgress != null ? null : _installUpdate,
                  child: const Text('تحديث'),
                ),
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.school, size: 36),
                    title: Text(
                      level == null
                          ? 'لم تحدد مستواك بعد'
                          : 'مستواك: ${level.code} (${level.arabicName})',
                    ),
                    subtitle: Text(
                      level == null
                          ? 'سوِّ اختبار قصير (5 دقائق تقريباً) أو اختر مستواك بنفسك'
                          : 'تقدر تعيد الاختبار أو تغيّر المستوى في أي وقت',
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => _open(const PlacementScreen()),
                        child: Text(
                          level == null ? 'ابدأ الاختبار' : 'أعد الاختبار',
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _chooseLevel,
                        child: const Text('اختر مستواك بنفسك'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!_modelsReady)
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.download),
                title: const Text('حمّل ترجمة بدون نت (اختياري)'),
                subtitle: const Text(
                  'الترجمة المجانية تحتاج نت. حمّل هذي (حوالي 60 ميجا، مرة واحدة) عشان التطبيق يترجم حتى لو انقطع النت.',
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
              label: Text(
                ListenSession.isRunning ? 'يسمعك الآن (افتح)' : 'ابدأ الاستماع',
                style: const TextStyle(fontSize: 22),
              ),
              onPressed: level == null
                  ? null
                  : () => _open(ListenScreen(level: level, autoStart: true)),
            ),
          ),
          if (level == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'لازم تحدد مستواك أولاً.',
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
    final keyController = TextEditingController(text: _store.claudeApiKey);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
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
                  for (final m in const [-1, 5, 0])
                    ChoiceChip(
                      label: Text(switch (m) {
                        -1 => 'بعد ما أسكت',
                        0 => 'في النهاية فقط',
                        _ => 'كل $m دقائق',
                      }),
                      selected: _store.summaryMinutes == m,
                      onSelected: (_) =>
                          setSheet(() => _store.summaryMinutes = m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'اختياري ومدفوع: ترجمة Claude',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Text(
                'الترجمة الأساسية مجانية ولا تحتاج شي. لو حبيت ترجمة أذكى، '
                'حط مفتاح API من console.anthropic.com (مدفوع)، وإلا اتركها فاضية.',
              ),
              TextField(
                controller: keyController,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(hintText: 'sk-ant-...'),
                onChanged: (value) => _store.claudeApiKey = value,
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
    ).whenComplete(() => setState(() {}));
  }
}
