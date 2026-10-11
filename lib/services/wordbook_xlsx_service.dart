import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';

class WordbookXlsxExportOptions {
  final bool includeAdditionalMeanings;
  final bool includeExampleSentence;
  final bool includeExampleTranslation;

  const WordbookXlsxExportOptions({
    this.includeAdditionalMeanings = true,
    this.includeExampleSentence = true,
    this.includeExampleTranslation = true,
  });
}

class WordbookXlsxService {
  const WordbookXlsxService();

  List<int> buildBytes(List<Word> words, {
    WordbookXlsxExportOptions options = const WordbookXlsxExportOptions(),
  }) {
    if (words.isEmpty) throw StateError('공유할 단어가 없습니다.');

    final workbook = Excel.createExcel();
    final sheet = workbook['단어장'];
    final extraColumns = options.includeAdditionalMeanings ? words.fold<int>(0, (count, word) =>
        word.additionalMeanings.length > count
            ? word.additionalMeanings.length
            : count) : 0;
    final includeSentence = options.includeExampleSentence &&
        words.any((word) => word.exampleSentence?.trim().isNotEmpty ?? false);
    final includeTranslation = options.includeExampleTranslation &&
        words.any((word) => word.exampleSentenceTranslation?.trim().isNotEmpty ?? false);
    sheet.appendRow([
      TextCellValue('단어'),
      TextCellValue('대표 뜻'),
      for (var index = 0; index < extraColumns; index++)
        TextCellValue('추가 뜻 ${index + 1}'),
      if (includeSentence) TextCellValue('예문'),
      if (includeTranslation) TextCellValue('예문 해석'),
    ]);
    for (final word in words) {
      sheet.appendRow([
        TextCellValue(word.word),
        TextCellValue(word.meaning),
        for (var index = 0; index < extraColumns; index++)
          TextCellValue(
            index < word.additionalMeanings.length
                ? word.additionalMeanings[index]
                : '',
          ),
        if (includeSentence) TextCellValue(word.exampleSentence ?? ''),
        if (includeTranslation) TextCellValue(word.exampleSentenceTranslation ?? ''),
      ]);
    }
    sheet.setColumnWidth(0, 24);
    sheet.setColumnWidth(1, 38);
    for (var index = 0; index < extraColumns; index++) {
      sheet.setColumnWidth(index + 2, 38);
    }
    var nextColumn = extraColumns + 2;
    if (includeSentence) sheet.setColumnWidth(nextColumn++, 60);
    if (includeTranslation) sheet.setColumnWidth(nextColumn, 60);
    workbook.delete('Sheet1');
    workbook.setDefaultSheet('단어장');
    final bytes = workbook.save();
    if (bytes == null) throw StateError('XLSX 파일을 만들지 못했습니다.');
    return bytes;
  }

  Future<void> share(Wordbook wordbook, List<Word> words, {
    WordbookXlsxExportOptions options = const WordbookXlsxExportOptions(),
  }) async {
    final bytes = buildBytes(words, options: options);
    final safeName = wordbook.name.replaceAll(
      RegExp(r'[\\/:*?"<>|\x00-\x1F]'),
      '_',
    ).trim();
    final directory = await getTemporaryDirectory();
    final temporary = await directory.createTemp('wordbook_share_');
    final file = File(path.join(
      temporary.path,
      '단어장_${safeName.isEmpty ? '공유' : safeName}.xlsx',
    ));
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          ),
        ],
        text: '${wordbook.name} 단어장',
      ),
    );
  }
}
