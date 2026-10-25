/// A voice flashcard built from a word the learner used.
class Flashcard {
  Flashcard({
    required this.word,
    required this.meaning,
    required this.example,
    this.box = 0,
    DateTime? due,
  }) : due = due ?? DateTime.now();

  final String word;
  String meaning;
  String example;

  /// Leitner box: 0 is new, higher means better known.
  int box;
  DateTime due;

  /// Days until the next review for each box.
  static const intervals = [0, 1, 3, 7, 14, 30];

  bool isDue(DateTime now) => !due.isAfter(now);

  /// Moves the card up a box when [known], back to the start otherwise.
  void review({required bool known, DateTime? now}) {
    now ??= DateTime.now();
    box = known ? (box + 1).clamp(0, intervals.length - 1) : 0;
    due = known
        ? now.add(Duration(days: intervals[box]))
        : now.add(const Duration(minutes: 10));
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'meaning': meaning,
    'example': example,
    'box': box,
    'due': due.toIso8601String(),
  };

  factory Flashcard.fromJson(Map<String, dynamic> j) => Flashcard(
    word: j['word'] as String,
    meaning: j['meaning'] as String? ?? '',
    example: j['example'] as String? ?? '',
    box: j['box'] as int? ?? 0,
    due: DateTime.tryParse(j['due'] as String? ?? ''),
  );
}
