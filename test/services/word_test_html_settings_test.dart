import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/providers/settings_provider.dart';
import 'package:memorize_app/services/test_sheet_service.dart';

void main() {
  test('단어 시험지 HTML에 선택한 글자 크기를 반영한다', () {
    final settings = AppSettings(fontSize: 18);
    final testData = <Map<String, dynamic>>[
      {
        'type': SelfTestType.wordToMeaning,
        'question': 'resilient',
        'answer': '회복력 있는',
      },
    ];

    final html = TestSheetService().generateWordTestHtmlForTest(
      '글자 크기 확인',
      testData,
      settings,
    );

    expect(html, contains('html { font-size: 18px; }'));
  });
}
