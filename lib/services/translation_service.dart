import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../data/levels.dart';
import 'claude_translator.dart';
import 'google_web_translator.dart';
import 'store.dart';

/// Translates between Arabic and English on the phone, with Google ML Kit.
/// The language models (about 30 MB each) are downloaded once.
class TranslationService {
  TranslationService._();

  static final instance = TranslationService._();

  final _toEnglish = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.arabic,
    targetLanguage: TranslateLanguage.english,
  );
  final _toArabic = OnDeviceTranslator(
    sourceLanguage: TranslateLanguage.english,
    targetLanguage: TranslateLanguage.arabic,
  );
  final _models = OnDeviceTranslatorModelManager();

  Future<bool> modelsReady() async =>
      await _models.isModelDownloaded(TranslateLanguage.arabic.bcpCode) &&
      await _models.isModelDownloaded(TranslateLanguage.english.bcpCode);

  /// Downloads the Arabic and English models. Throws with the real reason
  /// when the download fails.
  Future<void> downloadModels() async {
    for (final language in [
      TranslateLanguage.arabic,
      TranslateLanguage.english,
    ]) {
      final code = language.bcpCode;
      if (await _models.isModelDownloaded(code)) continue;
      try {
        await _models.downloadModel(code, isWifiRequired: false);
      } catch (_) {
        // Fall back to the translator's own download, which uses ML Kit's
        // default conditions.
      }
    }
    if (await modelsReady()) return;
    await _toEnglish.translateText('مرحبا');
    await _toArabic.translateText('hello');
    if (!await modelsReady()) {
      throw Exception('models still missing after download');
    }
  }

  final _web = GoogleWebTranslator();

  /// Which translator produced the last English sentence.
  String lastSource = 'device';

  /// Translates with Claude when an API key is set, otherwise with free
  /// online Google Translate, and falls back to the on-device model when
  /// there is no internet or the online service fails.
  Future<String> toEnglish(String arabic, CefrLevel level) async {
    final key = Store.instance.claudeApiKey;
    if (key.isNotEmpty) {
      try {
        final english = await ClaudeTranslator(key).toEnglish(arabic, level);
        lastSource = 'claude';
        lastClaudeError = null;
        return english;
      } catch (e) {
        lastClaudeError = '$e';
      }
    }
    try {
      final english = await _web.translate(arabic, from: 'ar', to: 'en');
      lastSource = 'google';
      return english;
    } catch (_) {
      lastSource = 'device';
      return _toEnglish.translateText(arabic);
    }
  }

  /// Why the last Claude translation failed, if it did.
  String? lastClaudeError;

  Future<String> toArabic(String english) async {
    try {
      return await _web.translate(english, from: 'en', to: 'ar');
    } catch (_) {
      return _toArabic.translateText(english);
    }
  }
}
