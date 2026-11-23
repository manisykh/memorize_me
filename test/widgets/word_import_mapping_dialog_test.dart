import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/widgets/word_import_mapping_dialog.dart';

void main() {
  testWidgets('좁은 화면에서 긴 열 이름도 드롭다운 밖으로 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showWordImportMappingDialog(
                        context,
                        sheets: {
                          'Unit10': [
                            [
                              'word',
                              'meaning with a very long description that should be clipped',
                            ],
                            ['pollute', '오염시키다'],
                          ],
                        },
                      ),
                  child: const Text('열 선택'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열 선택'));
    await tester.pumpAndSettle();

    expect(find.text('단어 열'), findsOneWidget);
    expect(find.text('대표 뜻 열'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('제목 행 설정 전후에도 가져오기 창 너비가 유지된다', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => showWordImportMappingDialog(
                        context,
                        sheets: {
                          'Word2': [
                            ['영단어', '뜻'],
                            ['failure', '실패, 실패자'],
                            ['think of', '~을 생각해보다, ~을 고려하다'],
                          ],
                        },
                      ),
                  child: const Text('가져오기 열기'),
                ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('가져오기 열기'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    final widthBefore =
        tester.widget<AlertDialog>(dialog).constraints!.maxWidth;
    expect(widthBefore, 520);

    await tester.tap(find.text('첫 행을 제목으로 제외'));
    await tester.pumpAndSettle();

    final widthAfter = tester.widget<AlertDialog>(dialog).constraints!.maxWidth;
    expect(widthAfter, widthBefore);
    expect(tester.takeException(), isNull);
  });
}
