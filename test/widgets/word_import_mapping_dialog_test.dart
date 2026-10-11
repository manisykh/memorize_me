import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/widgets/word_import_mapping_dialog.dart';

void main() {
  testWidgets('좁은 화면에서 긴 열 이름도 드롭다운 밖으로 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(builder: (context) => TextButton(
          onPressed: () => showWordImportMappingDialog(
            context,
            sheets: {
              'Unit10': [
                ['word', 'meaning with a very long description that should be clipped'],
                ['pollute', '오염시키다'],
              ],
            },
          ),
          child: const Text('열 선택'),
        )),
      ),
    ));

    await tester.tap(find.text('열 선택'));
    await tester.pumpAndSettle();

    expect(find.text('단어 열'), findsOneWidget);
    expect(find.text('대표 뜻 열'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
