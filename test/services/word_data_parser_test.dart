import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/services/word_data_parser.dart';

void main() {
  test('LF와 CRLF CSV를 동일하게 파싱한다', () {
    const lf = 'word,meaning\napple,사과\nbook,책\n';
    const crlf = 'word,meaning\r\napple,사과\r\nbook,책\r\n';

    final fromLf = WordDataParser.parseCsv(lf);
    final fromCrLf = WordDataParser.parseCsv(crlf);

    expect(fromLf.map((word) => word.word), ['apple', 'book']);
    expect(fromCrLf.map((word) => word.word), ['apple', 'book']);
  });

  test('빈 행과 열이 부족한 행을 제외하고 따옴표와 쉼표를 보존한다', () {
    const csv = 'word,meaning\n\ninvalid\n apple ,"사과, 과일"\n,빈 단어\n';
    final words = WordDataParser.parseCsv(csv);

    expect(words, hasLength(1));
    expect(words.single.word, 'apple');
    expect(words.single.meaning, '사과, 과일');
  });

  test('offset과 count는 유효 범위를 지정한다', () {
    const csv = 'word,meaning\none,하나\ntwo,둘\nthree,셋\n';
    final words = WordDataParser.parseCsv(csv, offset: 1, count: 1);

    expect(words.single.word, 'two');
  });

  test('Google Sheets A:B 형태의 행도 같은 규칙으로 파싱한다', () {
    final rows = <List<dynamic>>[
      ['word', 'meaning'],
      ['  cloud ', ' 구름 '],
      ['missing'],
      ['', '빈 단어'],
      ['rain', '비'],
    ];

    final words = WordDataParser.parseRows(rows);
    expect(words.map((word) => word.word), ['cloud', 'rain']);
    expect(words.map((word) => word.meaning), ['구름', '비']);
  });

  test('대표 뜻과 여러 추가 뜻 열을 분리해 파싱한다', () {
    final rows = <List<dynamic>>[
      ['단어', '의미 1', '의미 2'],
      ['den', 'the home of a wild animal', '(야생 동물이 사는) 굴'],
      ['tumble', 'to fall playfully', '뒹굴다, 구르다'],
    ];

    final words = WordDataParser.parseMappedRows(
      rows,
      wordColumn: 0,
      primaryMeaningColumn: 2,
      additionalMeaningColumns: const [1],
    );

    expect(words.first.meaning, '(야생 동물이 사는) 굴');
    expect(words.first.additionalMeanings, ['the home of a wild animal']);
  });

  test('대표 뜻과 중복되거나 비어 있는 추가 뜻은 제외한다', () {
    final rows = <List<dynamic>>[
      ['word', 'meaning', 'meaning 2', 'meaning 3'],
      ['book', '책', '책', ''],
    ];

    final words = WordDataParser.parseMappedRows(
      rows,
      wordColumn: 0,
      primaryMeaningColumn: 1,
      additionalMeaningColumns: const [2, 3],
    );

    expect(words.single.additionalMeanings, isEmpty);
  });
}
