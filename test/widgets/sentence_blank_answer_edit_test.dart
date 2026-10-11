import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/models/wordbook_model.dart';
import 'package:memorize_app/screens/add_edit_word_screen.dart';

void main() {
  testWidgets('수동 빈칸 표현을 미리 보고 예문에 없는 표현은 막는다', (tester) async {
    final book = Wordbook(
      name: '테스트',
      dbFileName: 'test.db',
      source: WordbookSource.manual,
    );
    final word = Word(
      word: 'go',
      meaning: '가다',
      exampleSentence: 'He went home and will go again.',
    );
    await tester.pumpWidget(MaterialApp(
      home: AddEditWordScreen(wordbook: book, word: word),
    ));

    final blankField = find.byKey(const Key('sentence_blank_answer'));
    await tester.scrollUntilVisible(
      blankField, 180, scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(blankField, 'go');
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(find.text('출제 미리보기: He went home and will _________ again.'), findsOneWidget);

    await tester.enterText(blankField, 'gone');
    await tester.pump();
    await tester.tap(find.text('저장'));
    await tester.pump();
    expect(find.text('예문에 있는 표현을 입력해주세요.'), findsOneWidget);
  });
}
