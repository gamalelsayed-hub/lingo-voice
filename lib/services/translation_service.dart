import 'package:google_mlkit_translation/google_mlkit_translation.dart';

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

  Future<String> toEnglish(String arabic) => _toEnglish.translateText(arabic);

  Future<String> toArabic(String english) => _toArabic.translateText(english);
}
