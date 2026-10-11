import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/services/word_data_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (var stage = 1; stage <= 6; stage++) {
    test('필수 영어단어 $stage단계에 유효한 단어가 1000개 있다', () async {
      final source = await rootBundle.loadString(
        'assets/builtin_essential_english_stage_$stage.csv',
      );
      final words = WordDataParser.parseCsv(source);

      expect(words, hasLength(1000));
      expect(words.every((word) => word.word.isNotEmpty), isTrue);
      expect(words.every((word) => word.meaning.isNotEmpty), isTrue);
      expect(
        words.every(
          (word) =>
              RegExp(r"^[A-Za-z]+(?:[ .'-][A-Za-z]+)*$").hasMatch(word.word),
        ),
        isTrue,
        reason: '영문 철자에는 문자와 정상적인 단어 구분 기호만 사용할 수 있습니다.',
      );
      expect(
        words.every((word) => _hasBalancedBrackets(word.meaning)),
        isTrue,
        reason: '뜻의 소괄호·대괄호·중괄호는 반드시 닫혀야 합니다.',
      );
      expect(
        words.every(
          (word) =>
              !word.meaning.contains(RegExp(r',\s*,')) &&
              !word.meaning.endsWith('[') &&
              !word.meaning.endsWith('('),
        ),
        isTrue,
        reason: '뜻에 빈 항목이나 잘린 괄호가 없어야 합니다.',
      );
    });
  }
}

bool _hasBalancedBrackets(String value) {
  const pairs = <String, String>{')': '(', ']': '[', '}': '{'};
  const opening = <String>{'(', '[', '{'};
  final stack = <String>[];
  for (final rune in value.runes) {
    final character = String.fromCharCode(rune);
    if (opening.contains(character)) {
      stack.add(character);
      continue;
    }
    final expectedOpening = pairs[character];
    if (expectedOpening == null) continue;
    if (stack.isEmpty || stack.removeLast() != expectedOpening) return false;
  }
  return stack.isEmpty;
}
