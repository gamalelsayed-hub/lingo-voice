/// CEFR levels used across the app.
enum CefrLevel { a1, a2, b1, b2, c1, c2 }

extension CefrLevelInfo on CefrLevel {
  String get code => name.toUpperCase();

  String get arabicName => const {
    CefrLevel.a1: 'مبتدئ',
    CefrLevel.a2: 'أساسي',
    CefrLevel.b1: 'متوسط',
    CefrLevel.b2: 'فوق المتوسط',
    CefrLevel.c1: 'متقدم',
    CefrLevel.c2: 'متمكن',
  }[this]!;

  /// How many key sentences the smart summary reads back.
  int get summaryCount => const {
    CefrLevel.a1: 5,
    CefrLevel.a2: 6,
    CefrLevel.b1: 7,
    CefrLevel.b2: 8,
    CefrLevel.c1: 9,
    CefrLevel.c2: 10,
  }[this]!;

  /// Comfortable sentence length (in English words) for this level.
  int get maxWords => const {
    CefrLevel.a1: 7,
    CefrLevel.a2: 10,
    CefrLevel.b1: 14,
    CefrLevel.b2: 18,
    CefrLevel.c1: 24,
    CefrLevel.c2: 30,
  }[this]!;

  /// How many of the most common English words we assume the learner knows.
  int get knownCommonWords => const {
    CefrLevel.a1: 120,
    CefrLevel.a2: 250,
    CefrLevel.b1: 400,
    CefrLevel.b2: 400,
    CefrLevel.c1: 400,
    CefrLevel.c2: 400,
  }[this]!;

  /// Words shorter than this are rarely worth teaching at this level.
  int get minNewWordLength => const {
    CefrLevel.a1: 3,
    CefrLevel.a2: 4,
    CefrLevel.b1: 5,
    CefrLevel.b2: 6,
    CefrLevel.c1: 7,
    CefrLevel.c2: 8,
  }[this]!;

  /// Speech rate for English text-to-speech (0.0 - 1.0 on Android).
  double get speechRate => const {
    CefrLevel.a1: 0.35,
    CefrLevel.a2: 0.4,
    CefrLevel.b1: 0.45,
    CefrLevel.b2: 0.5,
    CefrLevel.c1: 0.5,
    CefrLevel.c2: 0.55,
  }[this]!;
}

CefrLevel cefrFromCode(String? code) => CefrLevel.values.firstWhere(
  (l) => l.code == code,
  orElse: () => CefrLevel.a1,
);
