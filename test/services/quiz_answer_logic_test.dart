import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/quiz_answer_logic.dart';

void main() {
  test('스펠링은 대소문자, 공백, 하이픈 차이를 무시한다', () {
    expect(
      QuizAnswerLogic.evaluateSpelling(
        input: 'ICE cream',
        answer: 'ice-cream',
        isRetry: false,
      ),
      SpellingAttemptResult.correctFirstTry,
    );
  });

  test('첫 오답은 확정 오답이 아니라 재도전 상태로 남는다', () {
    expect(
      QuizAnswerLogic.evaluateSpelling(
        input: 'wrong',
        answer: 'correct',
        isRetry: false,
      ),
      SpellingAttemptResult.incorrect,
    );
  });

  test('재도전 정답은 첫 시도 정답과 구분된다', () {
    expect(
      QuizAnswerLogic.evaluateSpelling(
        input: 'memory',
        answer: 'memory',
        isRetry: true,
      ),
      SpellingAttemptResult.correctOnRetry,
    );
  });

  test('객관식은 ID를 우선 사용하고 ID가 없으면 내용으로 비교한다', () {
    final answer = Word(id: 1, word: 'book', meaning: '책');
    expect(
      QuizAnswerLogic.isCorrectChoice(
        selected: Word(id: 1, word: 'other', meaning: '다른 값'),
        answer: answer,
      ),
      isTrue,
    );
    expect(
      QuizAnswerLogic.isCorrectChoice(
        selected: Word(word: 'book', meaning: '책'),
        answer: Word(word: 'book', meaning: '책'),
      ),
      isTrue,
    );
  });

  test('마지막 문제 뒤에는 다음 인덱스가 없다', () {
    expect(QuizAnswerLogic.nextIndex(currentIndex: 0, totalCount: 3), 1);
    expect(QuizAnswerLogic.nextIndex(currentIndex: 2, totalCount: 3), isNull);
    expect(QuizAnswerLogic.nextIndex(currentIndex: 0, totalCount: 0), isNull);
  });
}
