// lib/providers/wordbook_manager.dart (수정된 전체 코드)

import 'dart:io';
// ▼▼▼ [추가] 'min' 함수를 사용하기 위해 dart:math를 import 합니다. ▼▼▼
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../services/database_service.dart';
import '../services/sheets_service.dart';
import 'word_list_provider.dart';

class WordbookManager extends ChangeNotifier {
  final DatabaseService _dbService;
  final SheetsService _sheetsService;
  final WordListNotifier _wordListNotifier;

  List<Wordbook> _wordbooks = [];
  List<Wordbook> get wordbooks => _wordbooks;

  Wordbook? _activeWordbook;
  Wordbook? get activeWordbook => _activeWordbook;

  List<String> _incorrectWordbookNames = [];
  List<String> get incorrectWordbookNames => _incorrectWordbookNames;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  WordbookManager(this._dbService, this._sheetsService, this._wordListNotifier);

  Future<void> loadInitialData() async {
    _setLoading(true);
    await Future.wait([_loadWordbooks(), loadIncorrectWordbookNames()]);
    _setLoading(false);
  }

  Future<void> _loadWordbooks() async {
    _wordbooks = await _dbService.getWordbooks();
    if (_wordbooks.isNotEmpty && _activeWordbook == null) {
      await setActiveWordbook(_wordbooks.first);
    }
    notifyListeners();
  }

  Wordbook? getWordbookById(int id) {
    try {
      return _wordbooks.firstWhere((wb) => wb.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> loadIncorrectWordbookNames() async {
    _incorrectWordbookNames = await _dbService.getIncorrectWordbookNames();
    notifyListeners();
  }

  Future<List<Word>> getIncorrectWords(String name) async {
    return await _dbService.getIncorrectWords(name);
  }

  Future<void> addIncorrectWordsToNote(String wordbookName, List<Word> words) async {
    await _dbService.addIncorrectWords(wordbookName, words);
    await loadIncorrectWordbookNames();
  }

  Future<void> deleteIncorrectWordbook(String name) async {
    _setLoading(true);
    await _dbService.deleteIncorrectWordbook(name);
    await loadIncorrectWordbookNames();
    _setLoading(false);
  }

  Future<void> setActiveWordbook(Wordbook? wordbook) async {
    _activeWordbook = wordbook;
    if (wordbook != null) {
      await _wordListNotifier.loadWords(wordbook.dbFileName);
    } else {
      _wordListNotifier.clearWords();
    }
    notifyListeners();
  }

  Future<void> createNewWordbook({
    required String name,
    required String spreadsheetId,
    required String sheetName,
  }) async {
    _setLoading(true);
    try {
      final dbFileName = 'wordbook_${DateTime.now().millisecondsSinceEpoch}.db';
      final newWordbook = Wordbook(
        name: name,
        spreadsheetId: spreadsheetId,
        sheetName: sheetName,
        dbFileName: dbFileName,
        source: WordbookSource.googleSheet,
      );
      final savedWordbook = await _dbService.addWordbook(newWordbook);
      final words = await _sheetsService.getWordsFromSheet(spreadsheetId, sheetName);
      if (words != null) {
        await _dbService.addWordsInBatch(savedWordbook.dbFileName, words);
      }
      await _loadWordbooks();
      await setActiveWordbook(savedWordbook);
    } catch (e) {
      debugPrint("Error creating new wordbook: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createNewWordbookFromCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;
    _setLoading(true);
    try {
      final file = result.files.single;
      final path = file.path!;
      final csvString = await File(path).readAsString();
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      final List<Word> words =
          csvTable
              .skip(1)
              .map((row) {
                if (row.length >= 2)
                  return Word(word: row[0].toString().trim(), meaning: row[1].toString().trim());
                return null;
              })
              .where((word) => word != null && word.word.isNotEmpty && word.meaning.isNotEmpty)
              .cast<Word>()
              .toList();

      if (words.isEmpty && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CSV 파일에서 유효한 단어를 찾을 수 없습니다.')));
        _setLoading(false);
        return;
      }
      final theme = Theme.of(context);
      final nameController = TextEditingController(text: p.basenameWithoutExtension(path));
      final String? newName = await showCupertinoDialog<String>(
        context: context,
        builder:
            (dialogContext) => CupertinoAlertDialog(
              title: const Text('단어장 이름 지정'),
              content: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: CupertinoTextField(
                  controller: nameController,
                  placeholder: '단어장 이름을 입력하세요',
                  style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('취소'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('생성'),
                  onPressed: () => Navigator.of(dialogContext).pop(nameController.text.trim()),
                ),
              ],
            ),
      );
      if (newName == null || newName.isEmpty) {
        _setLoading(false);
        return;
      }
      final dbFileName = 'wordbook_${DateTime.now().millisecondsSinceEpoch}.db';
      final newWordbook = Wordbook(
        name: newName,
        dbFileName: dbFileName,
        source: WordbookSource.localCsv,
      );
      final savedWordbook = await _dbService.addWordbook(newWordbook);
      await _dbService.addWordsInBatch(savedWordbook.dbFileName, words);
      await _loadWordbooks();
      await setActiveWordbook(savedWordbook);
    } catch (e) {
      debugPrint("Error creating wordbook from CSV: $e");
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('파일 처리 중 오류 발생: $e')));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteWordbook(Wordbook wordbook) async {
    _setLoading(true);
    if (_activeWordbook?.id == wordbook.id) {
      await setActiveWordbook(null);
    }
    await _dbService.deleteWordbook(wordbook.id!, wordbook.dbFileName);
    await _loadWordbooks();
    _setLoading(false);
  }

  Future<void> mergeWordbooks(Set<int> wordbookIds, String newName, BuildContext context) async {
    _setLoading(true);
    try {
      final List<Word> mergedWords = [];
      final Set<String> uniqueWordTexts = {};

      final List<Wordbook> booksToMerge =
          _wordbooks.where((wb) => wordbookIds.contains(wb.id)).toList();

      for (final book in booksToMerge) {
        final wordsFromDb = await _dbService.getAllWords(book.dbFileName);
        for (var word in wordsFromDb) {
          if (uniqueWordTexts.add(word.word.trim().toLowerCase())) {
            mergedWords.add(word);
          }
        }
      }

      final dbFileName = 'wordbook_${DateTime.now().millisecondsSinceEpoch}.db';
      final newWordbook = Wordbook(
        name: newName,
        dbFileName: dbFileName,
        source: WordbookSource.localCsv,
      );
      final savedWordbook = await _dbService.addWordbook(newWordbook);

      await _dbService.addWordsInBatch(savedWordbook.dbFileName, mergedWords);

      if (context.mounted) {
        final deleteOriginals = await showCupertinoDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return CupertinoAlertDialog(
              title: const Text('병합 완료'),
              content: Text("새로운 단어장 '$newName'이(가) 생성되었습니다.\n병합에 사용된 기존 단어장들을 삭제하시겠습니까?"),
              actions: [
                CupertinoDialogAction(
                  child: const Text('유지'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  child: const Text('삭제'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        );

        if (deleteOriginals == true) {
          for (final bookToDelete in booksToMerge) {
            await deleteWordbook(bookToDelete);
          }
        }
        await _loadWordbooks();
        await setActiveWordbook(savedWordbook);
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("Error merging wordbooks: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createMultipleWordbooksFromSheets(
    List<sheets.Sheet> selectedSheets,
    String spreadsheetId,
  ) async {
    _setLoading(true);
    try {
      for (final sheet in selectedSheets) {
        final sheetName = sheet.properties?.title;
        if (sheetName == null || sheetName.isEmpty) continue;

        // 기존의 단일 생성 로직을 재사용합니다.
        final dbFileName =
            'wordbook_${DateTime.now().millisecondsSinceEpoch}_${sheet.properties?.sheetId}.db';
        final newWordbook = Wordbook(
          name: sheetName, // 시트 이름을 단어장 이름으로 사용
          spreadsheetId: spreadsheetId,
          sheetName: sheetName,
          dbFileName: dbFileName,
          source: WordbookSource.googleSheet,
        );

        final savedWordbook = await _dbService.addWordbook(newWordbook);
        final words = await _sheetsService.getWordsFromSheet(spreadsheetId, sheetName);
        if (words != null) {
          await _dbService.addWordsInBatch(savedWordbook.dbFileName, words);
        }
      }
      // 모든 작업이 끝난 후 단어장 목록을 새로고침합니다.
      await _loadWordbooks();
    } catch (e) {
      debugPrint("Error creating multiple wordbooks from sheets: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateWord(Word word) async {
    if (activeWordbook == null) return;
    await _dbService.updateWord(activeWordbook!.dbFileName, word);
    await _wordListNotifier.refreshWords();
  }

  Future<List<Word>> getAllWordsFrom(Wordbook wordbook) async {
    // DatabaseService를 통해 필터링 없이 모든 단어를 가져옵니다.
    return await _dbService.getAllWords(wordbook.dbFileName);
  }

  Future<List<Word>> getWordsForSrsSession() async {
    if (activeWordbook == null) return [];

    final allWords = await _dbService.getAllWords(activeWordbook!.dbFileName);
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return allWords.where((word) {
      return word.nextReviewDate == null || word.nextReviewDate!.compareTo(todayString) <= 0;
    }).toList();
  }

  Future<void> updateWordSrsStatus(Word word, bool knowsIt, Wordbook wordbook) async {
    // ▼▼▼ [수정] 전역 activeWordbook 대신, 인자로 받은 특정 wordbook을 사용합니다. ▼▼▼

    final List<int> srsIntervals = [1, 3, 7, 15, 30, 60, 120];
    int newSrsLevel;
    String nextReviewDate;
    final today = DateTime.now();

    if (knowsIt) {
      newSrsLevel = word.srsLevel + 1;
      final interval = srsIntervals[min(newSrsLevel - 1, srsIntervals.length - 1)];
      nextReviewDate = DateFormat('yyyy-MM-dd').format(today.add(Duration(days: interval)));
    } else {
      newSrsLevel = 1;
      nextReviewDate = DateFormat('yyyy-MM-dd').format(today.add(const Duration(days: 1)));
    }

    final updatedWord = word.copyWith(srsLevel: newSrsLevel, nextReviewDate: nextReviewDate);
    // ▼▼▼ [수정] 인자로 받은 wordbook의 DB 파일에 정확히 업데이트합니다. ▼▼▼
    await _dbService.updateWord(wordbook.dbFileName, updatedWord);
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      Future.microtask(() => notifyListeners());
    }
  }
}
