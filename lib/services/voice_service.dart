import 'package:flutter_tts/flutter_tts.dart';

/// Speaks English (and Arabic, when the phone has an Arabic voice).
class VoiceService {
  VoiceService._();

  static final instance = VoiceService._();

  final _tts = FlutterTts();
  bool? _hasArabic;

  Future<void> init() async {
    await _tts.awaitSpeakCompletion(true);
    _hasArabic ??= await _tts.isLanguageAvailable('ar') == true;
  }

  bool get hasArabic => _hasArabic ?? false;

  Future<void> english(String text, {double rate = 0.45}) async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(rate);
    await _tts.speak(text);
  }

  Future<void> arabic(String text) async {
    if (!hasArabic) return;
    await _tts.setLanguage('ar');
    await _tts.setSpeechRate(0.5);
    await _tts.speak(text);
  }

  Future<void> stop() => _tts.stop();
}
