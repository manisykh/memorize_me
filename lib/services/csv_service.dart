import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'database_service.dart';
import '../models/word_model.dart';

enum ImportOption { append, replace }

class CsvService {
  final DatabaseService _dbService;
  CsvService(this._dbService);

  Future<bool> importCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null) {
      final path = result.files.single.path!;
      final csvString = await File(path).readAsString();
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      if (context.mounted) {
        final option = await showDialog<ImportOption>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('가져오기 옵션'),
                content: const Text('기존 단어장을 어떻게 처리할까요?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(ImportOption.append),
                    child: const Text('추가하기'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(ImportOption.replace),
                    child: const Text('새로 교체하기'),
                  ),
                ],
              ),
        );
        if (option != null) {
          if (option == ImportOption.replace) {
            await _dbService.deleteAllWords();
          }
          final words =
              csvTable
                  .skip(1)
                  .map((row) {
                    if (row.length >= 2) {
                      return Word(word: row[0].toString(), meaning: row[1].toString());
                    }
                    return null;
                  })
                  .where((word) => word != null)
                  .cast<Word>()
                  .toList();

          for (final word in words) {
            await _dbService.addWord(word);
          }
          return true;
        }
      }
    }
    return false;
  }

  Future<void> exportCsv() async {
    final words = await _dbService.getAllWords();
    if (words.isEmpty) {
      return;
    }
    final List<List<dynamic>> data = [
      ['word', 'meaning'],
      ...words.map((w) => [w.word, w.meaning]),
    ];
    final String csvString = const ListToCsvConverter().convert(data);
    final path = '${(await getTemporaryDirectory()).path}/words_export.csv';
    await File(path).writeAsString(csvString);
    await Share.shareXFiles([XFile(path)], text: '내보낸 단어장');
  }
}
