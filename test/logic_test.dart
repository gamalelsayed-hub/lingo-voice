import 'package:flutter_test/flutter_test.dart';
import 'package:lingo_voice/data/levels.dart';
import 'package:lingo_voice/logic/placement.dart';
import 'package:lingo_voice/logic/srs.dart';
import 'package:lingo_voice/logic/summary.dart';
import 'package:lingo_voice/logic/text_utils.dart';

void main() {
  group('wordMatchScore', () {
    test('perfect reading scores 1', () {
      expect(wordMatchScore('My name is Ali.', 'my name is ali'), 1.0);
    });

    test('missing words lower the score', () {
      expect(wordMatchScore('I like green tea', 'I like tea'), 0.75);
    });

    test('nothing heard scores 0', () {
      expect(wordMatchScore('Hello there', ''), 0.0);
    });
  });

  test('splitForLevel breaks long sentences for beginners', () {
    final parts = splitForLevel(
      'I went to the market yesterday, and I bought vegetables for dinner',
      7,
    );
    expect(parts.length, greaterThan(1));
    expect(splitForLevel('I like tea', 7), ['I like tea']);
  });

  group('placementLevel', () {
    test('stops at the first failed level', () {
      final scores = {
        CefrLevel.a1: LevelScore(
          pronunciation: 1,
          vocabCorrect: 2,
          vocabTotal: 2,
        ),
        CefrLevel.a2: LevelScore(
          pronunciation: 0.8,
          vocabCorrect: 1,
          vocabTotal: 2,
        ),
        CefrLevel.b1: LevelScore(
          pronunciation: 0.1,
          vocabCorrect: 0,
          vocabTotal: 2,
        ),
        CefrLevel.b2: LevelScore(
          pronunciation: 1,
          vocabCorrect: 2,
          vocabTotal: 2,
        ),
      };
      expect(placementLevel(scores), CefrLevel.a2);
    });

    test('skipped reading counts vocabulary only', () {
      final s = LevelScore(vocabCorrect: 2, vocabTotal: 2);
      expect(s.passed, isTrue);
    });

    test('everyone is at least A1', () {
      expect(placementLevel({}), CefrLevel.a1);
    });
  });

  group('smart summary', () {
    SpokenSentence s(String en) => SpokenSentence(arabic: '', english: en);

    test('common words are not new for a beginner', () {
      expect(
        newWordsFor('I want to eat with my friend', CefrLevel.a2),
        isEmpty,
      );
      expect(
        newWordsFor('The meeting with the accountant', CefrLevel.a1),
        containsAll(['meeting', 'accountant']),
      );
    });

    test(
      'keeps at most summaryCount sentences in spoken order, no repeats',
      () {
        final input = [
          for (final w in [
            'apple',
            'banana',
            'cherry',
            'grape',
            'lemon',
            'mango',
            'melon',
            'olive',
            'peach',
            'pear',
            'plum',
            'tomato',
          ])
            s('We discussed the $w budget'),
          s('We discussed the apple budget'),
        ];
        final picked = selectKeySentences(input, CefrLevel.a1);
        expect(picked.length, CefrLevel.a1.summaryCount);
        final indexes = picked.map(input.indexOf).toList();
        expect(indexes, [...indexes]..sort());
      },
    );

    test('prefers sentences with new words', () {
      final input = [
        s('I go home now'),
        s('The invoice and the contract are ready'),
        s('I am good'),
        s('yes'),
        s('ok thanks'),
        s('see you'),
      ];
      final picked = selectKeySentences(input, CefrLevel.a1);
      expect(picked.length, 5);
      final texts = picked.map((p) => p.english);
      expect(texts, contains('The invoice and the contract are ready'));
      expect(texts, isNot(contains('yes')));
    });

    test('counts recurring new words', () {
      final counts = countNewWords([
        s('The invoice is late'),
        s('Send the invoice today'),
      ], CefrLevel.a1);
      expect(counts.first.key, 'invoice');
      expect(counts.first.value, 2);
    });
  });

  group('Flashcard', () {
    final now = DateTime(2026, 10, 25);

    test('known cards move up a box and wait longer', () {
      final c = Flashcard(
        word: 'invoice',
        meaning: 'فاتورة',
        example: '',
        due: now,
      );
      c.review(known: true, now: now);
      expect(c.box, 1);
      expect(c.due, now.add(const Duration(days: 1)));
      c.review(known: true, now: now);
      expect(c.due, now.add(const Duration(days: 3)));
    });

    test('forgotten cards go back to the start', () {
      final c = Flashcard(
        word: 'x',
        meaning: '',
        example: '',
        box: 4,
        due: now,
      );
      c.review(known: false, now: now);
      expect(c.box, 0);
      expect(c.isDue(now.add(const Duration(minutes: 11))), isTrue);
    });

    test('survives a JSON round trip', () {
      final c = Flashcard(
        word: 'w',
        meaning: 'm',
        example: 'e',
        box: 2,
        due: now,
      );
      final back = Flashcard.fromJson(c.toJson());
      expect(
        [back.word, back.meaning, back.example, back.box, back.due],
        ['w', 'm', 'e', 2, now],
      );
    });
  });
}
