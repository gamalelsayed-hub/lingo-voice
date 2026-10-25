import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/levels.dart';
import '../logic/srs.dart';
import '../logic/summary.dart';
import '../logic/text_utils.dart';
import 'background_service.dart';
import 'speech_service.dart';
import 'store.dart';
import 'translation_service.dart';
import 'voice_service.dart';

/// A word picked for the learner in a summary.
class NewWord {
  NewWord(this.word, this.meaning);

  final String word;
  final String meaning;
}

class SessionSummary {
  SessionSummary(this.sentences, this.words);

  final List<SpokenSentence> sentences;
  final List<NewWord> words;
}

/// Runs one listening session: hears the learner's Arabic, translates it,
/// and either says each sentence in English right away (instant mode) or
/// reads back a smart summary when the learner goes quiet, every few
/// minutes, or at the end. It keeps running in the background with a
/// notification, so it outlives the listening screen.
class ListenSession extends ChangeNotifier {
  ListenSession._(this.level);

  static bool _buttonsWired = false;

  /// The running session, if any.
  static ListenSession? _current;

  /// Returns the running session, or a new one for [level].
  static ListenSession forLevel(CefrLevel level) {
    if (!_buttonsWired) {
      _buttonsWired = true;
      BackgroundService.onButton((id) {
        final session = _current;
        if (session == null) return;
        if (id == BackgroundService.stopButton) session.stop();
        if (id == BackgroundService.summaryButton) session.summarize();
      });
    }
    final current = _current;
    if (current != null && current.listening) return current;
    return _current = ListenSession._(level);
  }

  static bool get isRunning => _current?.listening ?? false;

  /// How long the learner must be quiet before the summary is read.
  static const silenceDelay = Duration(seconds: 6);

  final CefrLevel level;
  final _store = Store.instance;
  final _speech = SpeechService.instance;
  final _translator = TranslationService.instance;
  final _voice = VoiceService.instance;

  final List<SpokenSentence> history = [];
  final List<SpokenSentence> _pending = [];
  SessionSummary? lastSummary;
  String partial = '';
  bool listening = false;
  bool speaking = false;
  String? error;

  /// A hint for the learner, e.g. why nothing was spoken.
  String? notice;
  Timer? _timer;
  Timer? _silenceTimer;

  /// New flashcards created during this session.
  int newCards = 0;

  bool get instantMode => _store.instantMode;

  set instantMode(bool value) {
    _store.instantMode = value;
    notifyListeners();
  }

  Future<void> start() async {
    error = null;
    if (!await _speech.init()) {
      error = 'لم نتمكن من تشغيل الميكروفون. تأكد من إعطاء الإذن للتطبيق.';
      notifyListeners();
      return;
    }
    await _voice.init();
    try {
      await BackgroundService.start();
    } catch (e) {
      notice = 'ما قدرنا نشغّل الاستماع في الخلفية ($e). خلّ التطبيق مفتوح.';
    }
    listening = true;
    notifyListeners();
    await _speech.startContinuous(
      locale: _store.dialect,
      onSentence: _onSentence,
      onPartial: (p) {
        partial = p;
        _silenceTimer?.cancel();
        notifyListeners();
      },
    );
    final minutes = _store.summaryMinutes;
    if (minutes > 0) {
      _timer = Timer.periodic(Duration(minutes: minutes), (_) {
        if (!instantMode) summarize();
      });
    }
  }

  /// Stops listening and, in summary mode, reads the final summary.
  Future<void> stop() async {
    if (!listening) return;
    _timer?.cancel();
    _silenceTimer?.cancel();
    listening = false;
    partial = '';
    notifyListeners();
    await _speech.stop();
    await summarize(speak: !instantMode);
    await BackgroundService.stop();
  }

  /// In summary mode with "after I stop talking", reads the summary once
  /// the learner has been quiet for [silenceDelay].
  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    if (instantMode || _store.summaryMinutes != -1) return;
    _silenceTimer = Timer(silenceDelay, () {
      if (listening && !speaking && partial.isEmpty) summarize();
    });
  }

  int _translating = 0;

  Future<void> _waitForTranslations() async {
    for (var i = 0; i < 50 && _translating > 0; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<void> _onSentence(String arabic) async {
    _translating++;
    try {
      await _addSentence(arabic);
    } finally {
      _translating--;
    }
  }

  Future<void> _addSentence(String arabic) async {
    partial = '';
    String english;
    try {
      english = await _translator.toEnglish(arabic, level);
    } catch (e) {
      error = 'تعذرت الترجمة: $e';
      notifyListeners();
      return;
    }
    final claudeError = _translator.lastClaudeError;
    if (_store.claudeApiKey.isNotEmpty && claudeError != null) {
      notice =
          'ترجمة Claude ما اشتغلت، فاستخدمنا ترجمة الجوال. السبب: $claudeError';
    }
    final sentence = SpokenSentence(arabic: arabic, english: english);
    history.add(sentence);
    _pending.add(sentence);
    notifyListeners();
    BackgroundService.update(english);
    _restartSilenceTimer();
    if (instantMode) {
      await _say(() => _voice.english(english, rate: level.speechRate));
    }
  }

  /// Builds a summary of what was said since the last one, saves recurring
  /// words as flashcards and, if [speak], reads it aloud. With nothing new,
  /// the last summary is read again.
  Future<void> summarize({bool speak = true}) async {
    if (speaking) return;
    _silenceTimer?.cancel();
    if (listening && partial.isNotEmpty) {
      // Count what is being said right now, even if the sentence is not
      // finished.
      _speech.flush();
      partial = '';
      await _waitForTranslations();
    }
    if (_pending.isEmpty) {
      if (!speak) return;
      if (lastSummary == null) {
        notice =
            'ما سمعت جمل كاملة بعد. تكلم جملة أو جملتين بالعربي، '
            'وانتظر حتى تظهر تحت في "ما قلته"، ثم اضغط الملخص.';
        notifyListeners();
        return;
      }
      await _speakSummary(lastSummary!);
      return;
    }
    final batch = List.of(_pending);
    _pending.clear();

    final key = selectKeySentences(batch, level);
    final words = <NewWord>[];
    for (final entry in countNewWords(batch, level).take(5)) {
      words.add(NewWord(entry.key, await _safeArabic(entry.key)));
    }
    await _saveRecurringWords(batch);
    lastSummary = SessionSummary(key, words);
    notifyListeners();

    if (speak) await _speakSummary(lastSummary!);
  }

  Future<void> _speakSummary(SessionSummary summary) => _say(() async {
    for (final s in summary.sentences) {
      for (final part in splitForLevel(s.english, level.maxWords)) {
        if (!await _voice.english(part, rate: level.speechRate)) return;
      }
    }
    if (summary.words.isEmpty) return;
    await _voice.english('New words.', rate: level.speechRate);
    for (final w in summary.words) {
      await _voice.english(w.word, rate: level.speechRate);
      await _voice.arabic(w.meaning);
    }
  });

  Future<void> _say(Future<void> Function() talk) async {
    notice = null;
    _voice.lastError = null;
    speaking = true;
    notifyListeners();
    if (listening) {
      await _speech.pause();
      // Give the recognizer a moment to release the audio.
      await Future.delayed(const Duration(milliseconds: 400));
    }
    try {
      await talk();
      final voiceError = _voice.lastError;
      if (voiceError != null) {
        notice = _voice.hasEnglish
            ? 'الجوال ما قدر ينطق ($voiceError). تأكد أن صوت الوسائط مرتفع.'
            : 'الجوال ما فيه صوت إنجليزي. ثبّت "Speech Services by Google" '
                  'من المتجر، وحمّل الصوت الإنجليزي من إعدادات تحويل النص إلى كلام.';
      }
    } finally {
      speaking = false;
      notifyListeners();
      if (listening) await _speech.resume();
    }
  }

  Future<String> _safeArabic(String english) async {
    try {
      return await _translator.toArabic(english);
    } catch (_) {
      return '';
    }
  }

  /// A word becomes a flashcard once it has come up in at least two
  /// sentences, across all sessions.
  Future<void> _saveRecurringWords(List<SpokenSentence> batch) async {
    final counts = _store.wordCounts;
    final examples = <String, String>{};
    for (final s in batch) {
      for (final w in newWordsFor(s.english, level)) {
        counts[w] = (counts[w] ?? 0) + 1;
        examples[w] = s.english;
      }
    }
    _store.wordCounts = counts;

    final cards = _store.cards;
    final existing = cards.map((c) => c.word).toSet();
    for (final w in examples.keys) {
      if (counts[w]! < 2 || existing.contains(w)) continue;
      cards.add(
        Flashcard(
          word: w,
          meaning: await _safeArabic(w),
          example: examples[w]!,
        ),
      );
      newCards++;
    }
    _store.cards = cards;
  }

  /// Adds a word from the summary straight to the flashcards.
  void addCard(NewWord word, String example) {
    final cards = _store.cards;
    if (cards.any((c) => c.word == word.word)) return;
    cards.add(
      Flashcard(word: word.word, meaning: word.meaning, example: example),
    );
    _store.cards = cards;
    newCards++;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _silenceTimer?.cancel();
    if (listening) {
      _speech.stop();
      BackgroundService.stop();
    }
    _voice.stop();
    super.dispose();
  }
}
