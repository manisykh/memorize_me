import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/models/wordbook_model.dart';
import 'package:memorize_app/services/word_data_parser.dart';
import 'package:memorize_app/services/wordbook_xlsx_service.dart';

void main() {
  test('직접 만든 단어장 출처를 저장하고 복원한다', () {
    final original = Wordbook(
      name: '수업 중 기록',
      dbFileName: 'manual.db',
      source: WordbookSource.manual,
    );

    final restored = Wordbook.fromMap(original.toMap());

    expect(restored.source, WordbookSource.manual);
    expect(restored.name, '수업 중 기록');
  });

  test('공유 XLSX에 대표 뜻과 추가 뜻을 기록하고 다시 파싱할 수 있다', () {
    final bytes = const WordbookXlsxService().buildBytes([
      Word(word: 'den', meaning: 'the home of a wild animal',
        additionalMeanings: ['(야생 동물이 사는) 굴']),
      Word(word: 'tumble', meaning: '뒹굴다, 구르다'),
    ]);
    final sheet = Excel.decodeBytes(bytes).tables['단어장']!;
    final rows = sheet.rows.map((row) =>
      row.map<Object?>((cell) => cell?.value?.toString()).toList(),
    ).toList();

    expect(rows.first.take(3), ['단어', '대표 뜻', '추가 뜻 1']);
    final words = WordDataParser.parseMappedRows(rows,
      wordColumn: 0, primaryMeaningColumn: 1,
      additionalMeaningColumns: [2]);
    expect(words, hasLength(2));
    expect(words[0].word, 'den');
    expect(words[0].meaning, 'the home of a wild animal');
    expect(words[0].additionalMeanings, ['(야생 동물이 사는) 굴']);
    expect(words[1].word, 'tumble');
    expect(words[1].additionalMeanings, isEmpty);
  });

  test('빈 단어장은 XLSX를 만들지 않는다', () {
    expect(() => const WordbookXlsxService().buildBytes([]), throwsStateError);
  });

  test('예문과 해석이 있는 단어는 기본 내보내기에 포함된다', () {
    final bytes = const WordbookXlsxService().buildBytes([
      Word(word: 'apple', meaning: '사과',
        exampleSentence: 'I ate an apple.',
        exampleSentenceTranslation: '나는 사과를 먹었다.'),
      Word(word: 'book', meaning: '책'),
    ]);
    final rows = Excel.decodeBytes(bytes).tables['단어장']!.rows;

    expect(rows.first.map((cell) => cell?.value?.toString()),
        ['단어', '대표 뜻', '예문', '예문 해석']);
    expect(rows[1][2]?.value?.toString(), 'I ate an apple.');
    expect(rows[1][3]?.value?.toString(), '나는 사과를 먹었다.');
    expect(rows[2][2]?.value?.toString() ?? '', '');
  });

  test('선택 해제한 열은 XLSX에 포함하지 않는다', () {
    final bytes = const WordbookXlsxService().buildBytes([
      Word(word: 'den', meaning: '굴', additionalMeanings: ['den'],
        exampleSentence: 'The fox is in its den.',
        exampleSentenceTranslation: '여우가 굴에 있다.'),
    ], options: const WordbookXlsxExportOptions(
      includeAdditionalMeanings: false,
      includeExampleTranslation: false,
    ));
    final rows = Excel.decodeBytes(bytes).tables['단어장']!.rows;

    expect(rows.first.map((cell) => cell?.value?.toString()),
        ['단어', '대표 뜻', '예문']);
    expect(rows[1][2]?.value?.toString(), 'The fox is in its den.');
  });
}
