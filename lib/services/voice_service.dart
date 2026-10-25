import 'package:flutter_tts/flutter_tts.dart';

/// Speaks English (and Arabic, when the phone has an Arabic voice).
class VoiceService {
  VoiceService._();

  static final instance = VoiceService._();

  static const _googleEngine = 'com.google.android.tts';

  final _tts = FlutterTts();
  bool _ready = false;
  bool _hasArabic = false;
  bool _hasEnglish = false;

  /// The last speech error, shown to the learner. Cleared by the caller.
  String? lastError;

  Future<void> init() async {
    if (_ready) return;
    _tts.setErrorHandler((message) => lastError = '$message');
    final engines = (await _tts.getEngines as List?) ?? [];
    if (engines.contains(_googleEngine)) await _tts.setEngine(_googleEngine);
    await _tts.awaitSpeakCompletion(true);
    _hasEnglish = await _tts.isLanguageAvailable('en-US') == true;
    _hasArabic = await _tts.isLanguageAvailable('ar') == true;
    _ready = true;
  }

  bool get hasArabic => _hasArabic;
  bool get hasEnglish => _hasEnglish;

  /// Speaks [text] in English. Returns false if the phone could not speak.
  Future<bool> english(String text, {double rate = 0.45}) async {
    await init();
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    return _speak(text);
  }

  Future<bool> arabic(String text) async {
    await init();
    if (!hasArabic || text.isEmpty) return false;
    await _tts.setLanguage('ar');
    await _tts.setSpeechRate(0.5);
    return _speak(text);
  }

  Future<bool> _speak(String text) async {
    final result = await _tts.speak(text);
    if (result != 1) lastError ??= 'speak returned $result';
    return result == 1;
  }

  Future<void> stop() => _tts.stop();
}
