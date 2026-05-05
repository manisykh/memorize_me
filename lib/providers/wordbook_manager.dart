import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../services/database_service.dart';
import '../services/sheets_service.dart';
import '../services/srs_service.dart';
import 'word_list_provider.dart';

class WordbookManager extends ChangeNotifier {
  final DatabaseService _dbService;
  final SheetsService _sheetsService;
  final WordListNotifier _wordListNotifier;
  final SrsService _srsService = SrsService();

  List<Wordbook> _wordbooks = [];
  List<Wordbook> get wordbooks => _wordbooks;

  Wordbook? _activeWordbook;
  Wordbook? get activeWordbook => _activeWordbook;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  int _statsRevision = 0;
  int get statsRevision => _statsRevision;

  WordbookManager(this._dbService, this._sheetsService, this._wordListNotifier);

  Future<void> loadInitialData() async {
    _setLoading(true);

    // 1. 기기에서 마지막 활성 단어장 ID를 불러옵니다.
    final prefs = await SharedPreferences.getInstance();
    final lastActiveId = prefs.getInt('last_active_wordbook_id');

    // 2. 전체 단어장 목록을 DB에서 로드합니다.
    await _loadWordbooks();

    // 3. 저장된 ID가 있다면, 해당 단어장을 찾아 활성화합니다.
    if (lastActiveId != null) {
      final lastActiveWordbook = getWordbookById(lastActiveId);
      if (lastActiveWordbook != null) {
        // setActiveWordbook 내부에서 notifyListeners()가 호출됩니다.
        await setActiveWordbook(lastActiveWordbook);
      } else {
        // 이전에 사용하던 단어장이 삭제된 경우, 첫 번째 단어장을 활성화합니다.
        if (_wordbooks.isNotEmpty) {
          await setActiveWordbook(_wordbooks.first);
        }
      }
    } else if (_wordbooks.isNotEmpty && _activeWordbook == null) {
      // 저장된 ID가 없고, 현재 활성 단어장도 없다면 첫 번째 단어장을 활성화합니다.
      await setActiveWordbook(_wordbooks.first);
    }

    _setLoading(false);
  }

  Future<void> _loadWordbooks() async {
    _wordbooks = await _dbService.getWordbooks();
    _statsRevision++;
    // loadInitialData에서 setActiveWordbook을 관리하므로 여기서는 호출하지 않습니다.
    notifyListeners();
  }

  Wordbook? getWordbookById(int id) {
    try {
      return _wordbooks.firstWhere((wb) => wb.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> setActiveWordbook(Wordbook? wordbook) async {
    _activeWordbook = wordbook;
    if (wordbook != null) {
      await _wordListNotifier.loadWords(wordbook.dbFileName);
    } else {
      _wordListNotifier.clearWords();
    }

    // 활성화된 단어장 ID를 기기에 저장합니다.
    final prefs = await SharedPreferences.getInstance();
    if (wordbook != null) {
      await prefs.setInt('last_active_wordbook_id', wordbook.id!);
    } else {
      await prefs.remove('last_active_wordbook_id');
    }

    _statsRevision++;
    notifyListeners();
  }

  List<Word> getWordsForReview() {
    if (_activeWordbook == null) return [];
    return _srsService.dueWords(_wordListNotifier.words);
  }

  Future<void> updateWordsSrsData(String dbFileName, List<Word> words) async {
    await _dbService.updateWordSrsBatch(dbFileName, words);
    _statsRevision++;
    if (_activeWordbook?.dbFileName == dbFileName) {
      await _wordListNotifier.refreshWords();
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  Future<List<Word>> getAllWordsFrom(Wordbook wordbook) async {
    return await _dbService.getAllWords(wordbook.dbFileName);
  }

  Future<void> updateWordsInWordbook(Wordbook wordbook, List<Word> words) async {
    await _dbService.updateWordSrsBatch(wordbook.dbFileName, words);
    _statsRevision++;
    if (_activeWordbook?.id == wordbook.id) {
      await _wordListNotifier.refreshWords();
    }
    notifyListeners();
  }

  Future<void> deleteWordFrom(Wordbook wordbook, int wordId) async {
    await _dbService.deleteWord(wordbook.dbFileName, wordId);
    _statsRevision++;
    if (_activeWordbook?.id == wordbook.id) {
      await _wordListNotifier.refreshWords();
    }
    notifyListeners();
  }

  Future<Map<Wordbook, List<Word>>> searchAllWordbooks(String query) async {
    if (query.trim().isEmpty) return {};
    _setLoading(true);
    final Map<Wordbook, List<Word>> searchResults = {};
    for (final wordbook in _wordbooks) {
      final foundWords = await _dbService.searchWordsInWordbook(wordbook.dbFileName, query);
      if (foundWords.isNotEmpty) {
        searchResults[wordbook] = foundWords;
      }
    }
    _setLoading(false);
    return searchResults;
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
                if (row.length >= 2) {
                  return Word(word: row[0].toString().trim(), meaning: row[1].toString().trim());
                }
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
      if (!context.mounted) {
        _setLoading(false);
        return;
      }
      final theme = Theme.of(context);
      final nameController = TextEditingController(text: p.basenameWithoutExtension(path));
      final String? newName = await showDialog<String>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('단어장 이름 지정'),
              content: TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '단어장 이름',
                  hintText: '단어장 이름을 입력하세요',
                ),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                onSubmitted: (value) {
                  Navigator.of(dialogContext).pop(value.trim());
                },
              ),
              actions: [
                TextButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                FilledButton(
                  child: const Text('생성'),
                  onPressed: () => Navigator.of(dialogContext).pop(nameController.text.trim()),
                ),
              ],
            ),
      );
      nameController.dispose();
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('파일 처리 중 오류 발생: $e')));
      }
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
        final deleteOriginals = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('병합 완료'),
              content: Text("새로운 단어장 '$newName'이(가) 생성되었습니다.\n병합에 사용된 기존 단어장들을 삭제하시겠습니까?"),
              actions: [
                TextButton(
                  child: const Text('유지'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                  ),
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
        if (!context.mounted) return;
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
        final dbFileName =
            'wordbook_${DateTime.now().millisecondsSinceEpoch}_${sheet.properties?.sheetId}.db';
        final newWordbook = Wordbook(
          name: sheetName,
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
      await _loadWordbooks();
    } catch (e) {
      debugPrint("Error creating multiple wordbooks from sheets: $e");
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      Future.microtask(() => notifyListeners());
    }
  }
}
