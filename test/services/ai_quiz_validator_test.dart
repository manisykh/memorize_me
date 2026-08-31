import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/ai_quiz_model.dart';
import 'package:memorize_app/services/ai_quiz_validator.dart';
import 'package:memorize_app/services/custom_api_exception.dart';

AiQuestion question(String stem, {List<String>? options, String answer = 'A'}) {
  return AiQuestion(
    type: 'vocabulary',
    question: stem,
    options: options ?? const ['A', 'B', 'C', 'D'],
    answer: answer,
  );
}

void main() {
  test('코드 펜스로 감싼 AI JSON과 독해 하위 문항 수를 파싱한다', () {
    const source = '''```json
{"questions":[{"type":"reading_section","passage":"Text","questions":[
{"question":"Q1","options":["A","B","C","D"],"answer":"A"},
{"question":"Q2","options":["E","F","G","H"],"answer":"E"}
]}]}
```''';

    final response = AiQuizResponse.parse(source);
    expect(response.answerableQuestionCount, 2);
  });

  test('문장 부호와 대소문자만 다른 중복 문제를 제거하고 부분 결과를 허용한다', () {
    final response = AiQuizResponse(
      questions: [
        question('Choose the answer?'),
        question(' choose the ANSWER! ', options: const ['E', 'F', 'G', 'H'], answer: 'E'),
      ],
    );

    final result = AiQuizValidator.sanitize(
      response,
      expectedAnswerableCount: 2,
    );

    expect(result.answerableQuestionCount, 1);
    expect(result.droppedDuplicateCount, 1);
    expect(result.requestedQuestionCount, 2);
  });

  test('선택지가 4개가 아니거나 정답이 선택지에 없으면 거부한다', () {
    expect(
      () => AiQuizValidator.sanitize(
        AiQuizResponse(questions: [question('Bad', options: const ['A', 'B'])]),
      ),
      throwsA(isA<CustomApiException>()),
    );
    expect(
      () => AiQuizValidator.sanitize(
        AiQuizResponse(questions: [question('Bad answer', answer: 'Z')]),
      ),
      throwsA(isA<CustomApiException>()),
    );
  });
}
