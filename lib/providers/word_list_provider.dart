import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../providers/ai_settings_provider.dart';
import '../services/ai_service.dart';
import '../services/database_service.dart';

class WordListNotifier extends ChangeNotifier {
  final DatabaseService _databaseService;
  String? _activeDbFileName;
  List<Word> _words = [];

  WordListNotifier(this._databaseService);

  List<Word> get words => _words;

  Future<void> loadWords(String dbFileName) async {
    _activeDbFileName = dbFileName;
    _words = await _databaseService.getAllWords(dbFileName);
    notifyListeners();
  }

  Future<void> refreshWords() async {
    if (_activeDbFileName != null) {
      await loadWords(_activeDbFileName!);
    }
  }

  void clearWords() {
    _words.clear();
    _activeDbFileName = null;
    notifyListeners();
  }

  Future<void> addWord(Word word) async {
    if (_activeDbFileName == null) return;
    await _databaseService.addWord(_activeDbFileName!, word);
    await loadWords(_activeDbFileName!);
  }

  Future<void> updateWord(Word word) async {
    if (_activeDbFileName == null) return;
    await _databaseService.updateWord(_activeDbFileName!, word);
    await loadWords(_activeDbFileName!);
  }

  Future<void> deleteWord(int id) async {
    if (_activeDbFileName == null) return;
    await _databaseService.deleteWord(_activeDbFileName!, id);
    await loadWords(_activeDbFileName!);
  }

  Future<void> generateAndUpdateAllSentences(
    AiService aiService,
    AiSettingsProvider aiSettings,
  ) async {
    if (_activeDbFileName == null) return;

    final wordsToUpdate =
        _words.where((w) => w.exampleSentence == null || w.exampleSentence!.isEmpty).toList();
    if (wordsToUpdate.isEmpty) return;

    // Word 객체 리스트(wordsToUpdate)를 직접 전달하도록 수정
    final sentenceMap = await aiService.generateSentencesForWords(
      wordsToUpdate,
      aiSettings.selectedModel,
    );

    for (final word in wordsToUpdate) {
      if (sentenceMap.containsKey(word.word)) {
        final updatedWord = word.copyWith(exampleSentence: sentenceMap[word.word]);
        await _databaseService.updateWord(_activeDbFileName!, updatedWord);
      }
    }
    await loadWords(_activeDbFileName!);
  }
}
