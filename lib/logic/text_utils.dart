import 'dart:math';

final _wordPattern = RegExp(r"[a-z]+(?:'[a-z]+)?");

/// Lowercase English words in [text], punctuation removed.
List<String> englishWords(String text) => _wordPattern
    .allMatches(text.toLowerCase())
    .map((m) => m.group(0)!)
    .toList();

/// How closely [spoken] matches [expected], from 0.0 to 1.0, based on the
/// longest common subsequence of words. Used to grade pronunciation.
double wordMatchScore(String expected, String spoken) {
  final a = englishWords(expected);
  final b = englishWords(spoken);
  if (a.isEmpty) return 0;
  final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      dp[i][j] = a[i - 1] == b[j - 1]
          ? dp[i - 1][j - 1] + 1
          : max(dp[i - 1][j], dp[i][j - 1]);
    }
  }
  return dp[a.length][b.length] / max(a.length, b.length);
}

/// Splits a long translated sentence into shorter pieces for beginners.
List<String> splitForLevel(String sentence, int maxWords) {
  if (englishWords(sentence).length <= maxWords) return [sentence.trim()];
  final parts = sentence
      .split(RegExp(r'[,;]|\s(?=(?:and|but|because|so)\s)'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  return parts.length > 1 ? parts : [sentence.trim()];
}
