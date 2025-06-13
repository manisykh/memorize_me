import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/csv_service.dart';
import '../models/word_model.dart';

class WordListNotifier extends ChangeNotifier {
  final DatabaseService _dbService;
  List<Word> _words = [];
  List<Word> get words => _words;

  WordListNotifier(this._dbService) {
    loadWords();
  }

  Future<void> loadWords() async {
    _words = await _dbService.getAllWords();
    notifyListeners();
  }

  Future<void> addWord(Word word) async {
    await _dbService.addWord(word);
    await loadWords();
  }

  Future<void> updateWord(Word word) async {
    await _dbService.updateWord(word);
    await loadWords();
  }

  Future<void> deleteWord(int id) async {
    await _dbService.deleteWord(id);
    await loadWords();
  }

  Future<void> importFromCsv(BuildContext context, CsvService csvService) async {
    bool success = await csvService.importCsv(context);
    if (success) {
      await loadWords();
    }
  }
}
