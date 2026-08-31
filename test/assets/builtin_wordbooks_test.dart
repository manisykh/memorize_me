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
    });
  }
}
