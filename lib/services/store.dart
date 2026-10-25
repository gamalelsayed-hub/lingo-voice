import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../data/levels.dart';
import '../logic/srs.dart';

/// Arabic dialects offered for speech recognition.
const arabicDialects = {
  'ar_EG': 'مصري',
  'ar_SA': 'سعودي',
  'ar_AE': 'إماراتي',
  'ar_JO': 'أردني / شامي',
  'ar_MA': 'مغربي',
};

/// Everything the app remembers, kept on the device only.
class Store {
  Store._(this._prefs);

  static late Store instance;

  static Future<void> load() async {
    instance = Store._(await SharedPreferences.getInstance());
  }

  final SharedPreferences _prefs;

  CefrLevel? get level {
    final code = _prefs.getString('level');
    return code == null ? null : cefrFromCode(code);
  }

  set level(CefrLevel? value) => value == null
      ? _prefs.remove('level')
      : _prefs.setString('level', value.code);

  String get dialect => _prefs.getString('dialect') ?? 'ar_EG';
  set dialect(String value) => _prefs.setString('dialect', value);

  /// When the smart summary is read: -1 after the learner goes quiet,
  /// 0 only at the end, otherwise every that many minutes.
  int get summaryMinutes => _prefs.getInt('summaryEvery') ?? -1;
  set summaryMinutes(int value) => _prefs.setInt('summaryEvery', value);

  /// Claude API key for better translations; empty means on-device only.
  /// Kept in the app's private storage on this phone.
  String get claudeApiKey => _prefs.getString('claudeApiKey') ?? '';
  set claudeApiKey(String value) =>
      _prefs.setString('claudeApiKey', value.trim());

  bool get instantMode => _prefs.getBool('instantMode') ?? false;
  set instantMode(bool value) => _prefs.setBool('instantMode', value);

  List<Flashcard> get cards {
    final raw = _prefs.getString('cards');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((j) => Flashcard.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  set cards(List<Flashcard> value) => _prefs.setString(
    'cards',
    jsonEncode(value.map((c) => c.toJson()).toList()),
  );

  /// How many times each new word has come up across all sessions.
  Map<String, int> get wordCounts {
    final raw = _prefs.getString('wordCounts');
    if (raw == null) return {};
    return (jsonDecode(raw) as Map<String, dynamic>).map(
      (k, v) => MapEntry(k, v as int),
    );
  }

  set wordCounts(Map<String, int> value) =>
      _prefs.setString('wordCounts', jsonEncode(value));
}
