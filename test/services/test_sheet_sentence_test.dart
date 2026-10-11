import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/providers/settings_provider.dart';
import 'package:memorize_app/services/test_sheet_service.dart';

void main() {
  test('해석 표시와 관계없이 수동 입력 예문을 문장 완성에 사용할 수 있다', () {
    final word = Word(
      word: 'apple',
      meaning: '사과',
      exampleSentence: 'I ate an apple today.',
    );

    expect(TestSheetService.canUseSentenceCompletion(word), isTrue);
  });

  test('해석이 있으면 해석 포함 문장 완성에 사용할 수 있다', () {
    final word = Word(
      word: 'apple',
      meaning: '사과',
      exampleSentence: 'I ate an apple today.',
      exampleSentenceTranslation: '오늘 사과를 먹었다.',
    );

    expect(TestSheetService.canUseSentenceCompletion(word), isTrue);
  });

  test('예문에 대상 단어가 없으면 빈칸을 만들 수 없다', () {
    final word = Word(
      word: 'apple',
      meaning: '사과',
      exampleSentence: 'I ate a banana today.',
      exampleSentenceTranslation: '오늘 바나나를 먹었다.',
    );

    expect(TestSheetService.canUseSentenceCompletion(word), isFalse);
  });

  test('문장 완성만 선택하면 가능한 단어만 출제하고 단어 쓰기를 섞지 않는다', () {
    final words = [
      Word(
        word: 'apple',
        meaning: '사과',
        exampleSentence: 'I ate an apple.',
        exampleSentenceTranslation: '나는 사과를 먹었다.',
      ),
      Word(word: 'book', meaning: '책'),
      Word(
        word: 'banana',
        meaning: '바나나',
        exampleSentence: 'I ate a banana.',
        exampleSentenceTranslation: '나는 바나나를 먹었다.',
      ),
      Word(word: 'pear', meaning: '배', exampleSentence: 'I ate a pear.'),
    ];

    final questions = TestSheetService().prepareTestData(
      words,
      AppSettings(wordCount: 4, testTypes: {SelfTestType.sentenceCompletion}),
    );

    expect(questions, hasLength(3));
    expect(
      questions.every(
        (item) => item['type'] == SelfTestType.sentenceCompletion,
      ),
      isTrue,
    );
    expect(
      questions.every(
        (item) => (item['question'] as String).contains('_________'),
      ),
      isTrue,
    );
  });

  test('해석 표시가 켜져 있어도 해석 없는 예문을 문장 완성으로 출제한다', () {
    final questions = TestSheetService().prepareTestData(
      [Word(word: 'pear', meaning: '배', exampleSentence: 'I ate a pear.')],
      AppSettings(
        testTypes: {SelfTestType.sentenceCompletion},
        includeTranslation: true,
      ),
    );

    expect(questions.single['type'], SelfTestType.sentenceCompletion);
    expect(questions.single['translation'], isNull);
  });

  test('출제 가능한 예문이 없으면 선택하지 않은 유형으로 대체하지 않는다', () {
    expect(
      () => TestSheetService().prepareTestData([
        Word(word: 'book', meaning: '책'),
      ], AppSettings(testTypes: {SelfTestType.sentenceCompletion})),
      throwsStateError,
    );
  });

  test('복수 유형에서도 선택하지 않은 유형은 출제하지 않는다', () {
    final settings = AppSettings(
      wordCount: 2,
      testTypes: {SelfTestType.wordToMeaning, SelfTestType.sentenceCompletion},
    );
    final questions = TestSheetService().prepareTestData([
      Word(
        word: 'apple',
        meaning: '사과',
        exampleSentence: 'I ate an apple.',
        exampleSentenceTranslation: '나는 사과를 먹었다.',
      ),
      Word(word: 'book', meaning: '책'),
    ], settings);

    expect(questions, hasLength(2));
    expect(
      questions.every((item) => settings.testTypes.contains(item['type'])),
      isTrue,
    );
  });

  test('같은 예문에 두 단어가 있으면 단어마다 출제할 수 있다', () {
    final words = [
      Word(
        word: 'apple',
        meaning: '사과',
        exampleSentence: 'I read a book about an apple.',
      ),
      Word(
        word: 'book',
        meaning: '책',
        exampleSentence: 'I read a book about an apple.',
      ),
    ];

    final questions = TestSheetService().prepareTestData(
      words,
      AppSettings(
        wordCount: 2,
        testTypes: {SelfTestType.sentenceCompletion},
        repeatSharedSentences: true,
      ),
    );

    expect(questions, hasLength(2));
    expect(questions.map((item) => item['answer']).toSet(), {'apple', 'book'});
    expect(
      questions.every(
        (item) => item['type'] == SelfTestType.sentenceCompletion,
      ),
      isTrue,
    );
  });

  test('같은 예문은 한 문제만 출제할 수 있다', () {
    final words = [
      Word(
        word: 'apple',
        meaning: '사과',
        exampleSentence: 'I read a book about an apple.',
      ),
      Word(
        word: 'book',
        meaning: '책',
        exampleSentence: ' I   read a book about an apple. ',
      ),
    ];

    final questions = TestSheetService().prepareTestData(
      words,
      AppSettings(
        wordCount: 2,
        testTypes: {SelfTestType.sentenceCompletion},
        repeatSharedSentences: false,
      ),
    );

    expect(questions, hasLength(1));
    expect(questions.single['type'], SelfTestType.sentenceCompletion);
  });

  test('공유 예문에 대상 단어가 없으면 출제하지 않는다', () {
    final words = [
      Word(word: 'apple', meaning: '사과', exampleSentence: 'I ate an apple.'),
      Word(word: 'book', meaning: '책', exampleSentence: 'I ate an apple.'),
    ];

    for (final repeat in [true, false]) {
      final questions = TestSheetService().prepareTestData(
        words,
        AppSettings(
          wordCount: 2,
          testTypes: {SelfTestType.sentenceCompletion},
          repeatSharedSentences: repeat,
        ),
      );
      expect(questions.map((item) => item['answer']), ['apple']);
    }
  });

  test('명사 복수형과 동사 활용형을 실제 문장 형태로 출제한다', () {
    final cases = <(String, String, String)>[
      ('baby', 'The babies are sleeping.', 'babies'),
      ('child', 'The children are playing.', 'children'),
      ('study', 'She studies every day.', 'studies'),
      ('study', 'He studied yesterday.', 'studied'),
      ('stop', 'The bus stopped here.', 'stopped'),
      ('make', 'She is making dinner.', 'making'),
      ('go', 'He went home.', 'went'),
      ('run', 'They are running.', 'running'),
      ('die', 'The plant is dying.', 'dying'),
      ('teach', 'She taught the class.', 'taught'),
      ('forget', 'I had forgotten the date.', 'forgotten'),
      ('analysis', 'The analyses were useful.', 'analyses'),
      ('criterion', 'The criteria changed.', 'criteria'),
      ('panic', 'He panicked yesterday.', 'panicked'),
      ('see', 'She is seeing a doctor.', 'seeing'),
      ('begin', 'The class is beginning.', 'beginning'),
      ('visit', 'They visited the museum.', 'visited'),
    ];

    for (final (lemma, sentence, answer) in cases) {
      final word = Word(word: lemma, meaning: '뜻', exampleSentence: sentence);
      expect(
        TestSheetService.canUseSentenceCompletion(word),
        isTrue,
        reason: '$lemma / $sentence',
      );
      final question =
          TestSheetService().prepareTestData([
            word,
          ], AppSettings(testTypes: {SelfTestType.sentenceCompletion})).single;
      expect(question['answer'], answer, reason: '$lemma / $sentence');
      expect(question['question'], sentence.replaceFirst(answer, '_________'));
    }
  });

  test('활용형이 다른 단어의 일부일 뿐이면 출제하지 않는다', () {
    final word = Word(
      word: 'baby',
      meaning: '아기',
      exampleSentence: 'The babysitter arrived.',
    );
    expect(TestSheetService.canUseSentenceCompletion(word), isFalse);
  });

  test('반복 등장하는 활용형은 하나만 빈칸으로 만든다', () {
    final word = Word(
      word: 'baby',
      meaning: '아기',
      exampleSentence: 'Babies love babies.',
    );
    final question =
        TestSheetService().prepareTestData([
          word,
        ], AppSettings(testTypes: {SelfTestType.sentenceCompletion})).single;
    expect(question['answer'], 'Babies');
    expect(question['question'], '_________ love babies.');
  });

  test('원형과 활용형이 함께 있으면 예문에서 먼저 등장하는 형태를 묻는다', () {
    final word = Word(
      word: 'go',
      meaning: '가다',
      exampleSentence: 'He went home and will go again.',
    );
    final question =
        TestSheetService().prepareTestData([
          word,
        ], AppSettings(testTypes: {SelfTestType.sentenceCompletion})).single;
    expect(question['answer'], 'went');
    expect(question['question'], 'He _________ home and will go again.');
    expect(TestSheetService.hasMultipleSentenceForms(word), isTrue);
  });

  test('수동 빈칸 표현은 자동 인식보다 우선하고 DB 맵을 왕복한다', () {
    final original = Word(
      word: 'go',
      meaning: '가다',
      exampleSentence: 'He went home and will go again.',
      sentenceBlankAnswer: 'go',
    );
    final restored = Word.fromMap(original.toMap());
    expect(restored.sentenceBlankAnswer, 'go');
    expect(TestSheetService.hasMultipleSentenceForms(restored), isFalse);
    final question = TestSheetService().prepareTestData([restored], AppSettings(
      testTypes: {SelfTestType.sentenceCompletion},
    )).single;
    expect(question['answer'], 'go');
    expect(question['question'], 'He went home and will _________ again.');
  });

  test('예문 변경으로 수동 지정 표현이 사라지면 출제 대상에서 제외한다', () {
    final word = Word(
      word: 'go', meaning: '가다',
      exampleSentence: 'She goes home.', sentenceBlankAnswer: 'went',
    );
    expect(TestSheetService.canUseSentenceCompletion(word), isFalse);
    expect(TestSheetService.sentenceCompletionCandidates(
      [word], repeatSharedSentences: true,
    ), isEmpty);
  });

  test('자동 활용형을 못 찾아도 수동 표현으로 문장 완성을 출제한다', () {
    final word = Word(
      word: 'look after', meaning: '돌보다',
      exampleSentence: 'She looked after her sister.',
      sentenceBlankAnswer: 'looked after',
    );
    final question = TestSheetService().prepareTestData([word], AppSettings(
      testTypes: {SelfTestType.sentenceCompletion},
    )).single;
    expect(question['answer'], 'looked after');
    expect(question['question'], 'She _________ her sister.');
  });
}
