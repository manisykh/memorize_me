import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/ai_quiz_model.dart';
import 'package:memorize_app/services/test_sheet_service.dart';

void main() {
  test('독해 HTML은 지문을 한 번만 넣고 하위 문제를 연속 배치한다', () {
    const passage = 'This passage must appear exactly once.';
    final questions = [
      AiQuestion(
        type: 'reading_section',
        passage: passage,
        questions: List.generate(
          5,
          (index) => AiReadingSubQuestion(
            question: '질문 ${index + 1}',
            options: const ['A', 'B', 'C', 'D'],
            answer: 'A',
          ),
        ),
      ),
    ];

    final html = TestSheetService().generateAiQuizHtmlForTest('독해', questions);

    expect(RegExp(RegExp.escape(passage)).allMatches(html).length, 1);
    expect(RegExp('reading-0').allMatches(html).length, 5);
    expect(html, contains('reading-first'));
    expect(html, contains('reading-last'));
  });
}
