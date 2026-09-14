import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/ai_quiz_model.dart';
import 'package:memorize_app/services/ai_quiz_validator.dart';
import 'package:memorize_app/services/ai_difficulty_profile.dart';
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
        question(
          ' choose the ANSWER! ',
          options: const ['E', 'F', 'G', 'H'],
          answer: 'E',
        ),
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
        AiQuizResponse(
          questions: [
            question('Bad', options: const ['A', 'B']),
          ],
        ),
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

  test('모든 문항이 허용된 단어장 단어를 실제로 사용해야 한다', () {
    final valid = AiQuestion(
      type: 'vocabulary',
      targetWord: 'harvest',
      question: 'Which word means 수확하다?',
      options: const ['harvest', 'borrow', 'float', 'whisper'],
      answer: 'harvest',
    );
    expect(
      AiQuizValidator.sanitize(
        AiQuizResponse(questions: [valid]),
        allowedTargetWords: const ['harvest'],
        expectedTypes: const {'vocabulary'},
      ).answerableQuestionCount,
      1,
    );

    final missingFromContent = AiQuestion(
      type: 'vocabulary',
      targetWord: 'harvest',
      question: 'Choose the best word.',
      options: const ['borrow', 'float', 'whisper', 'answer'],
      answer: 'answer',
    );
    expect(
      () => AiQuizValidator.sanitize(
        AiQuizResponse(questions: [missingFromContent]),
        allowedTargetWords: const ['harvest'],
      ),
      throwsA(isA<CustomApiException>()),
    );
  });

  test('요청하지 않은 문제 유형과 단어장 밖의 targetWord를 거부한다', () {
    final invalid = AiQuestion(
      type: 'grammar',
      targetWord: 'invented',
      question: 'Choose invented.',
      options: const ['invented', 'A', 'B', 'C'],
      answer: 'invented',
    );
    expect(
      () => AiQuizValidator.sanitize(
        AiQuizResponse(questions: [invalid]),
        allowedTargetWords: const ['harvest'],
        expectedTypes: const {'vocabulary'},
      ),
      throwsA(isA<CustomApiException>()),
    );
  });

  test('난이도별 문장 길이 차이는 기록하되 퀴즈 생성을 차단하지 않는다', () {
    final tooShort = AiQuestion(
      type: 'vocabulary',
      questionFormat: 'meaning_in_context',
      targetWord: 'protect',
      question: 'Choose protect.',
      options: const ['protect', 'open', 'visit', 'carry'],
      answer: 'protect',
    );

    final result = AiQuizValidator.sanitize(
      AiQuizResponse(questions: [tooShort]),
      allowedTargetWords: const ['protect'],
      difficultyProfile: AiDifficultyProfiles.forLevel(1),
      requireFormatDiversity: true,
    );

    expect(result.answerableQuestionCount, 1);
    expect(result.difficultyMismatchCount, 1);
  });

  test('4문제 이상이면 최소 2개의 세부 문제 유형을 요구한다', () {
    final questions = List.generate(
      4,
      (index) => AiQuestion(
        type: 'vocabulary',
        questionFormat: 'meaning_in_context',
        targetWord: 'protect',
        question:
            'People protect the small animal from heavy rain number $index.',
        options: ['protect', 'open$index', 'visit$index', 'carry$index'],
        answer: 'protect',
      ),
    );

    expect(
      () => AiQuizValidator.sanitize(
        AiQuizResponse(questions: questions),
        allowedTargetWords: const ['protect'],
        requireFormatDiversity: true,
      ),
      throwsA(isA<CustomApiException>()),
    );
  });

  test('종합 4문제 이상이면 최소 2개의 상위 문제 영역을 요구한다', () {
    final questions = List.generate(
      4,
      (index) => AiQuestion(
        type: 'vocabulary',
        questionFormat: index.isEven ? 'meaning_in_context' : 'synonym',
        targetWord: 'protect',
        question:
            'People protect the small animal from heavy rain number $index.',
        options: ['protect', 'open$index', 'visit$index', 'carry$index'],
        answer: 'protect',
      ),
    );

    expect(
      () => AiQuizValidator.sanitize(
        AiQuizResponse(questions: questions),
        allowedTargetWords: const ['protect'],
        requireFormatDiversity: true,
        requireTypeDiversity: true,
      ),
      throwsA(isA<CustomApiException>()),
    );
  });
}
