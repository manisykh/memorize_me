import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/ai_service.dart';
import 'package:memorize_app/services/api_key_service.dart';

void main() {
  final service = AiService(ApiKeyService());

  test('기존 예문의 빈 해석 제안을 연결한다', () {
    final original = Word(
      word: 'apple', meaning: '사과',
      exampleSentence: 'I ate an apple.',
    );
    final suggestions = service.parseWordReviewSuggestions(
      '{"items":[{"index":0,"word":"apple","meaning":"사과",'
      '"sentence":"I ate an apple.","translation":"나는 사과를 먹었다."}]}',
      [original],
    );

    expect(suggestions.single.translation, '나는 사과를 먹었다.');
    expect(suggestions.single.index, 0);
  });

  test('기존 예문을 지우거나 예문을 임의 생성한 응답은 제외한다', () {
    final originals = [
      Word(word: 'apple', meaning: '사과', exampleSentence: 'I ate an apple.'),
      Word(word: 'book', meaning: '책'),
    ];

    expect(
      () => service.parseWordReviewSuggestions(
        '{"items":['
        '{"index":0,"word":"apple","meaning":"사과","sentence":"","translation":""},'
        '{"index":1,"word":"book","meaning":"책","sentence":"A book is here.","translation":"책이 있다."}'
        ']}',
        originals,
      ),
      throwsA(isA<CustomApiException>()),
    );
  });

  test('같은 항목의 잘못된 제안 뒤에 정상 제안이 오면 정상 제안을 사용한다', () {
    final original = Word(
      word: 'apple',
      meaning: '사과',
      exampleSentence: 'I ate an apple.',
    );
    final suggestions = service.parseWordReviewSuggestions(
      '{"items":['
      '{"index":0,"word":"apple","meaning":"사과","sentence":"","translation":""},'
      '{"index":0,"word":"apple","meaning":"사과","sentence":"I ate an apple.",'
      '"translation":"나는 사과를 먹었다."}'
      ']}',
      [original],
    );

    expect(suggestions.single.translation, '나는 사과를 먹었다.');
  });
}
