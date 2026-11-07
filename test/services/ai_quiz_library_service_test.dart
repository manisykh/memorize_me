import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/ai_quiz_model.dart';
import 'package:memorize_app/models/saved_ai_quiz.dart';
import 'package:memorize_app/services/ai_quiz_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AiQuizResponse quiz(String question) => AiQuizResponse(
    questions: [
      AiQuestion(
        type: 'vocabulary',
        question: question,
        options: const ['A', 'B', 'C', 'D'],
        answer: 'A',
      ),
    ],
  );

  test('저장한 AI 퀴즈를 다시 불러온다', () async {
    final library = AiQuizLibraryService();
    await library.save(title: '첫 퀴즈', quiz: quiz('문제 1'));

    final restored = AiQuizLibraryService();
    await restored.load();

    expect(restored.items, hasLength(1));
    expect(restored.items.single.title, '첫 퀴즈');
    expect(restored.items.single.quiz.questions.single.question, '문제 1');
    expect(restored.items.single.category, AiQuizCategory.vocabulary);
  });

  test('여러 퀴즈를 합치면서 동일 문제를 제거한다', () async {
    final library = AiQuizLibraryService();
    final first = await library.save(title: '첫 퀴즈', quiz: quiz('같은 문제'));
    final second = await library.save(title: '둘째 퀴즈', quiz: quiz('같은 문제'));

    final merged = await library.merge(
      quizzes: [first, second],
      title: '합친 퀴즈',
    );

    expect(merged.quiz.answerableQuestionCount, 1);
    expect(merged.sourceTitles, ['첫 퀴즈', '둘째 퀴즈']);
    expect(merged.category, AiQuizCategory.vocabulary);
  });

  test('서로 다른 유형을 합치면 종합으로 분류한다', () async {
    final library = AiQuizLibraryService();
    final vocabulary = await library.save(title: '어휘', quiz: quiz('어휘 문제'));
    final grammar = await library.save(
      title: '문법',
      quiz: AiQuizResponse(
        questions: [
          AiQuestion(
            type: 'grammar',
            question: '문법 문제',
            options: const ['A', 'B', 'C', 'D'],
            answer: 'A',
          ),
        ],
      ),
    );

    final merged = await library.merge(
      quizzes: [vocabulary, grammar],
      title: '종합 퀴즈',
    );

    expect(merged.category, AiQuizCategory.mixed);
  });

  test('카테고리 정보가 없는 기존 저장 데이터도 자동 분류한다', () {
    final restored = SavedAiQuiz.fromJson({
      'id': 'legacy',
      'title': '기존 퀴즈',
      'createdAt': DateTime(2026).toIso8601String(),
      'quiz': quiz('기존 문제').toJson(),
    });

    expect(restored.category, AiQuizCategory.vocabulary);
  });
}
