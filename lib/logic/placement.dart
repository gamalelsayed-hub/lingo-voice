import '../data/levels.dart';

/// Result of one level of the placement test.
class LevelScore {
  LevelScore({this.pronunciation, this.vocabCorrect = 0, this.vocabTotal = 0});

  /// 0.0 - 1.0, or null if the learner skipped the reading.
  double? pronunciation;
  int vocabCorrect;
  int vocabTotal;

  double get combined {
    final vocab = vocabTotal == 0 ? 0.0 : vocabCorrect / vocabTotal;
    final pron = pronunciation;
    return pron == null ? vocab : 0.4 * pron + 0.6 * vocab;
  }

  bool get passed => combined >= 0.6;
}

/// The learner's level is the highest level they passed without failing an
/// easier one. Everyone starts at least at A1.
CefrLevel placementLevel(Map<CefrLevel, LevelScore> scores) {
  var result = CefrLevel.a1;
  for (final level in CefrLevel.values) {
    final s = scores[level];
    if (s == null || !s.passed) break;
    result = level;
  }
  return result;
}
