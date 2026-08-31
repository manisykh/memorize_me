import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/word_model.dart';
import '../widgets/word_import_mapping_dialog.dart';
import 'word_data_parser.dart';

class LocalWordFileImport {
  const LocalWordFileImport({
    required this.fileName,
    required this.fileType,
    required this.words,
  });

  final String fileName;
  final String fileType;
  final List<Word> words;
}

class LocalWordFileService {
  const LocalWordFileService();

  Future<LocalWordFileImport?> pickAndPreview(BuildContext context) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty || !context.mounted) return null;

    final file = picked.files.single;
    final extension = p.extension(file.name).toLowerCase();
    final bytes = file.bytes ?? (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null) throw StateError('선택한 파일을 읽을 수 없습니다.');

    final sheets = <String, List<List<Object?>>>{};
    if (extension == '.csv') {
      final source = await _decodeCsv(bytes);
      sheets['CSV'] = const CsvToListConverter(eol: '\n').convert(source);
    } else {
      final workbook = Excel.decodeBytes(bytes);
      for (final entry in workbook.tables.entries) {
        final table = entry.value;
        if (table == null || table.rows.isEmpty) continue;
        sheets[entry.key] =
            table.rows
                .map(
                  (row) => row.map<Object?>((cell) => cell?.value?.toString()).toList(),
                )
                .toList();
      }
    }

    if (sheets.isEmpty) throw StateError('가져올 수 있는 데이터가 없습니다.');
    final selection = await showWordImportMappingDialog(context, sheets: sheets);
    if (selection == null) return null;

    final rows = sheets[selection.sheetName] ?? const <List<Object?>>[];
    final words = WordDataParser.parseMappedRows(
      rows,
      wordColumn: selection.mapping.wordColumn,
      primaryMeaningColumn: selection.mapping.primaryMeaningColumn,
      additionalMeaningColumns: selection.mapping.additionalMeaningColumns,
      skipHeader: selection.mapping.skipHeader,
    );

    return LocalWordFileImport(
      fileName: p.basenameWithoutExtension(file.name),
      fileType: extension == '.xlsx' ? 'xlsx' : 'csv',
      words: words,
    );
  }

  Future<String> _decodeCsv(List<int> bytes) async {
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

}
