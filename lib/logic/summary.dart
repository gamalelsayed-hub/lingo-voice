import '../data/common_words.dart';
import '../data/levels.dart';
import 'text_utils.dart';

/// One sentence the learner said, with its English translation.
class SpokenSentence {
  SpokenSentence({required this.arabic, required this.english, DateTime? at})
    : at = at ?? DateTime.now();

  final String arabic;
  final String english;
  final DateTime at;
}

/// Words in [english] that are probably new for a learner at [level].
List<String> newWordsFor(String english, CefrLevel level) {
  final known = commonEnglishWords.take(level.knownCommonWords).toSet();
  return englishWords(english)
      .where((w) => w.length >= level.minNewWordLength && !known.contains(w))
      .toSet()
      .toList();
}

/// Picks the most useful sentences to read back in the smart summary:
/// sentences with new words that are not too long for the learner's level.
List<SpokenSentence> selectKeySentences(
  List<SpokenSentence> sentences,
  CefrLevel level,
) {
  final seen = <String>{};
  final unique = <SpokenSentence>[];
  for (final s in sentences) {
    final key = englishWords(s.english).join(' ');
    if (key.isEmpty || !seen.add(key)) continue;
    unique.add(s);
  }

  double score(SpokenSentence s) {
    final count = englishWords(s.english).length;
    final fit = count <= level.maxWords
        ? count / level.maxWords
        : level.maxWords / count;
    return newWordsFor(s.english, level).length * 2 + fit;
  }

  final ranked = [...unique]..sort((a, b) => score(b).compareTo(score(a)));
  final chosen = ranked.take(level.summaryCount).toSet();
  // Read them back in the order they were said.
  return unique.where(chosen.contains).toList();
}

/// Counts new words across [sentences], most frequent first.
List<MapEntry<String, int>> countNewWords(
  List<SpokenSentence> sentences,
  CefrLevel level,
) {
  final counts = <String, int>{};
  for (final s in sentences) {
    for (final w in newWordsFor(s.english, level)) {
      counts[w] = (counts[w] ?? 0) + 1;
    }
  }
  return counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
}
