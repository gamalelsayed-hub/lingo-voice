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

  Future<bool> downloadModels({bool wifiOnly = false}) async {
    final ar = await _models.downloadModel(
      TranslateLanguage.arabic.bcpCode,
      isWifiRequired: wifiOnly,
    );
    final en = await _models.downloadModel(
      TranslateLanguage.english.bcpCode,
      isWifiRequired: wifiOnly,
    );
    return ar && en;
  }

  Future<String> toEnglish(String arabic) => _toEnglish.translateText(arabic);

  Future<String> toArabic(String english) => _toArabic.translateText(english);
}
