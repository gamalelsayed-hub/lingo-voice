import 'levels.dart';

class VocabQuestion {
  const VocabQuestion(this.word, this.answer, this.options);

  final String word;
  final String answer;
  final List<String> options;
}

class PlacementItem {
  const PlacementItem(this.level, this.readAloud, this.vocab);

  final CefrLevel level;
  final String readAloud;
  final List<VocabQuestion> vocab;
}

const placementItems = [
  PlacementItem(CefrLevel.a1, 'My name is Ali and I like tea.', [
    VocabQuestion('apple', 'تفاحة', ['تفاحة', 'كرسي', 'سيارة', 'قلم']),
    VocabQuestion('house', 'بيت', ['شارع', 'بيت', 'باب', 'نافذة']),
  ]),
  PlacementItem(
    CefrLevel.a2,
    'I usually take the bus to work in the morning.',
    [
      VocabQuestion('borrow', 'يستعير', ['يبيع', 'يستعير', 'يسرق', 'يرمي']),
      VocabQuestion('weather', 'الطقس', ['الوقت', 'الطريق', 'الطقس', 'الماء']),
    ],
  ),
  PlacementItem(
    CefrLevel.b1,
    'If I had more time, I would travel around the world.',
    [
      VocabQuestion('achieve', 'يحقق', ['يحقق', 'يتجاهل', 'يؤجل', 'يخسر']),
      VocabQuestion('although', 'بالرغم من', [
        'لذلك',
        'بالرغم من',
        'بسبب',
        'بعد ذلك',
      ]),
    ],
  ),
  PlacementItem(
    CefrLevel.b2,
    'The government has announced new measures to reduce pollution.',
    [
      VocabQuestion('reluctant', 'متردد', ['متحمس', 'متردد', 'غاضب', 'مشهور']),
      VocabQuestion('sustainable', 'مستدام', [
        'مؤقت',
        'مكلف',
        'مستدام',
        'خطير',
      ]),
    ],
  ),
  PlacementItem(
    CefrLevel.c1,
    'Despite considerable opposition, the proposal was eventually approved.',
    [
      VocabQuestion('meticulous', 'دقيق جداً', [
        'مهمل',
        'دقيق جداً',
        'سريع',
        'كسول',
      ]),
      VocabQuestion('ambiguous', 'غامض', ['واضح', 'غامض', 'قديم', 'مضحك']),
    ],
  ),
  PlacementItem(
    CefrLevel.c2,
    "The novelist's idiosyncratic prose defies conventional categorisation.",
    [
      VocabQuestion('ubiquitous', 'منتشر في كل مكان', [
        'نادر',
        'منتشر في كل مكان',
        'مخفي',
        'ممنوع',
      ]),
      VocabQuestion('ephemeral', 'قصير الأمد', [
        'أبدي',
        'ثقيل',
        'قصير الأمد',
        'عميق',
      ]),
    ],
  ),
];
