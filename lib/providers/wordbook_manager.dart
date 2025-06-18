// providers/wordbook_manager.dart (수정 후)

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../services/database_service.dart';
import '../services/sheets_service.dart';
import 'word_list_provider.dart';

class WordbookManager extends ChangeNotifier {
  final DatabaseService _dbService;
  final SheetsService _sheetsService;
  final WordListNotifier _wordListNotifier;

  // --- 기존 단어장 상태 ---
  List<Wordbook> _wordbooks = [];
  List<Wordbook> get wordbooks => _wordbooks;
  Wordbook? _activeWordbook;
  Wordbook? get activeWordbook => _activeWordbook;

  // --- 오답노트 상태 추가 ---
  List<String> _incorrectWordbookNames = [];
  List<String> get incorrectWordbookNames => _incorrectWordbookNames;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  WordbookManager(this._dbService, this._sheetsService, this._wordListNotifier);

  // --- 데이터 로딩 ---
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
  }

  // --- 오답노트 관리 메소드 추가 ---
  Future<void> loadIncorrectWordbookNames() async {
    _incorrectWordbookNames = await _dbService.getIncorrectWordbookNames();
    notifyListeners();
  }

  Future<List<Word>> getIncorrectWords(String name) async {
    return await _dbService.getIncorrectWords(name);
  }

  Future<void> addIncorrectWords(String wordbookName, List<Word> words) async {
    await _dbService.addIncorrectWords(wordbookName, words);
    await loadIncorrectWordbookNames();
  }

  Future<void> deleteIncorrectWordbook(String name) async {
    _setLoading(true);
    await _dbService.deleteIncorrectWordbook(name);
    await loadIncorrectWordbookNames();
    _setLoading(false);
  }

  // --- 기존 단어장 관리 메소드 (수정 없음) ---
  Future<void> setActiveWordbook(Wordbook? wordbook) async {
    _activeWordbook = wordbook;
    await _wordListNotifier.switchWordbook(wordbook);
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

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      Future.microtask(() => notifyListeners());
    }
  }
}
