// providers/word_list_provider.dart

import 'package:flutter/material.dart';
import '../models/wordbook_model.dart';
import '../services/database_service.dart';
import '../services/csv_service.dart';
import '../models/word_model.dart';

class WordListNotifier extends ChangeNotifier {
  final DatabaseService _dbService;
  Wordbook? _activeWordbook; // 현재 활성화된 단어장 정보 (비공개)

  // ▼▼▼ 수정된 부분 ▼▼▼
  // 외부에서 _activeWordbook을 읽을 수 있도록 public getter를 추가합니다.
  Wordbook? get activeWordbook => _activeWordbook;
  // ▲▲▲ 수정된 부분 ▲▲▲

  List<Word> _words = [];
  List<Word> get words => _words;

  WordListNotifier(this._dbService);

  Future<void> switchWordbook(Wordbook? newWordbook) async {
    _activeWordbook = newWordbook;
    if (_activeWordbook == null) {
      _words = [];
    } else {
      await loadWords();
    }
    notifyListeners();
  }

  Future<void> loadWords() async {
    if (_activeWordbook == null) return;
    _words = await _dbService.getAllWords(_activeWordbook!.dbFileName);
    notifyListeners();
  }

  Future<void> addWord(Word word) async {
    if (_activeWordbook == null) return;
    await _dbService.addWord(_activeWordbook!.dbFileName, word);
    await loadWords();
  }

  Future<void> updateWord(Word word) async {
    if (_activeWordbook == null) return;
    await _dbService.updateWord(_activeWordbook!.dbFileName, word);
    await loadWords();
  }

  Future<void> deleteWord(int id) async {
    if (_activeWordbook == null) return;
    await _dbService.deleteWord(_activeWordbook!.dbFileName, id);
    await loadWords();
  }

  Future<void> deleteAllWords() async {
    if (_activeWordbook == null) return;
    await _dbService.deleteAllWords(_activeWordbook!.dbFileName);
    await loadWords();
  }

  Future<void> importFromCsv(BuildContext context, CsvService csvService) async {
    if (_activeWordbook == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('먼저 단어장을 선택해주세요.')));
      return;
    }
    bool success = await csvService.importCsv(context, _activeWordbook!.dbFileName);
    if (success) {
      await loadWords();
    }
  }
}
