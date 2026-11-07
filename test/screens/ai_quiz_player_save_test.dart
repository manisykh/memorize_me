import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/ai_quiz_model.dart';
import 'package:memorize_app/models/saved_ai_quiz.dart';
import 'package:memorize_app/screens/ai_quiz_player_screen.dart';
import 'package:memorize_app/services/ai_quiz_library_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('저장 다이얼로그를 닫은 뒤 퀴즈를 안전하게 저장한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final library = AiQuizLibraryService();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: library,
        child: MaterialApp(
          home: AiQuizPlayerScreen(
            quizResponse: AiQuizResponse(
              questions: [
                AiQuestion(
                  type: 'vocabulary',
                  question: '알맞은 답을 고르세요.',
                  options: const ['A', 'B', 'C', 'D'],
                  answer: 'A',
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('퀴즈 저장'));
    await tester.pumpAndSettle();
    expect(find.text('AI 퀴즈 저장'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '내 AI 퀴즈');
    await tester.tap(find.widgetWithText(FilledButton, '저장'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(library.items, hasLength(1));
    expect(library.items.single.title, '내 AI 퀴즈');
    expect(library.items.single.category, AiQuizCategory.vocabulary);
    expect(find.text('AI 퀴즈를 저장했습니다.'), findsOneWidget);
  });
}
