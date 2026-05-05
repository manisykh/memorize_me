// lib/providers/word_list_provider.dart

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

    final fallbackResult = await aiService.generateSentencesForWordsWithFallback(
      wordsToUpdate,
      aiSettings.requestOptions(
        fallbackEnabled: aiSettings.autoFallbackEnabled,
      ),
    );
    final sentenceMap = fallbackResult.value;

    for (final word in wordsToUpdate) {
      if (sentenceMap.containsKey(word.word)) {
        final sentenceData = sentenceMap[word.word]!;
        final updatedWord = word.copyWith(
          exampleSentence: sentenceData['sentence'],
          exampleSentenceTranslation: sentenceData['translation'],
        );
        await _databaseService.updateWord(_activeDbFileName!, updatedWord);
      }
    }
    await loadWords(_activeDbFileName!);
  }
}
