import 'package:csv/csv.dart';

import '../models/word_model.dart';

class WordDataParser {
  const WordDataParser._();

  static List<Word> parseCsv(
    String source, {
    bool skipHeader = true,
    int offset = 0,
    int? count,
  }) {
    final normalized = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    return parseRows(
      rows,
      skipHeader: skipHeader,
      offset: offset,
      count: count,
    );
  }

  static List<Word> parseRows(
    Iterable<List<Object?>> rows, {
    bool skipHeader = true,
    int offset = 0,
    int? count,
  }) {
    Iterable<List<Object?>> selectedRows = rows;
    if (skipHeader && selectedRows.isNotEmpty) {
      selectedRows = selectedRows.skip(1);
    }
    selectedRows = selectedRows.skip(offset);
    if (count != null) selectedRows = selectedRows.take(count);

    return selectedRows.map(_wordFromRow).whereType<Word>().toList();
  }

  static List<Word> parseMappedRows(
    Iterable<List<Object?>> rows, {
    required int wordColumn,
    required int primaryMeaningColumn,
    List<int> additionalMeaningColumns = const [],
    bool skipHeader = true,
  }) {
    Iterable<List<Object?>> selectedRows = rows;
    if (skipHeader && selectedRows.isNotEmpty) {
      selectedRows = selectedRows.skip(1);
    }

    return selectedRows
        .map(
          (row) => _wordFromMappedRow(
            row,
            wordColumn: wordColumn,
            primaryMeaningColumn: primaryMeaningColumn,
            additionalMeaningColumns: additionalMeaningColumns,
          ),
        )
        .whereType<Word>()
        .toList();
  }

  static Word? _wordFromRow(List<Object?> row) {
    if (row.length < 2) return null;
    final word = row[0]?.toString().trim() ?? '';
    final meaning = row[1]?.toString().trim() ?? '';
    if (word.isEmpty || meaning.isEmpty) return null;
    return Word(word: word, meaning: meaning);
  }

  static Word? _wordFromMappedRow(
    List<Object?> row, {
    required int wordColumn,
    required int primaryMeaningColumn,
    required List<int> additionalMeaningColumns,
  }) {
    final word = _cellText(row, wordColumn);
    final meaning = _cellText(row, primaryMeaningColumn);
    if (word.isEmpty || meaning.isEmpty) return null;

    final seen = <String>{meaning.toLowerCase()};
    final additionalMeanings = <String>[];
    for (final column in additionalMeaningColumns) {
      final value = _cellText(row, column);
      if (value.isEmpty || !seen.add(value.toLowerCase())) continue;
      additionalMeanings.add(value);
    }

    return Word(
      word: word,
      meaning: meaning,
      additionalMeanings: additionalMeanings,
    );
  }

  static String _cellText(List<Object?> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index]?.toString().trim() ?? '';
  }
}
