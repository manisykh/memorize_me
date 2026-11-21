import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';

void main() {
  group('Word.hasExampleSentence', () {
    test('예문이 없거나 공백뿐이면 false를 반환한다', () {
      expect(Word(word: 'apple', meaning: '사과').hasExampleSentence, isFalse);
      expect(
        Word(
          word: 'apple',
          meaning: '사과',
          exampleSentence: '   ',
        ).hasExampleSentence,
        isFalse,
      );
    });

    test('내용이 있는 예문이면 true를 반환한다', () {
      expect(
        Word(
          word: 'apple',
          meaning: '사과',
          exampleSentence: 'I ate an apple.',
        ).hasExampleSentence,
        isTrue,
      );
    });
  });
}
