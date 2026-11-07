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
  String? _loadingDbFileName;
  Future<void>? _loadingFuture;
  int _loadGeneration = 0;

  WordListNotifier(this._databaseService);

  List<Word> get words => _words;
  String? get activeDbFileName => _activeDbFileName;

  Future<void> loadWords(String dbFileName, {bool force = false}) async {
    if (!force && _activeDbFileName == dbFileName) return;
    if (!force && _loadingDbFileName == dbFileName) {
      await _loadingFuture;
      return;
    }

    final generation = ++_loadGeneration;
    _loadingDbFileName = dbFileName;
    late final Future<void> loadFuture;
    loadFuture = _databaseService.getAllWords(dbFileName).then((loadedWords) {
      if (generation != _loadGeneration) return;
      _activeDbFileName = dbFileName;
      _words = loadedWords;
      notifyListeners();
    });
    _loadingFuture = loadFuture;

    try {
      await loadFuture;
    } finally {
      if (generation == _loadGeneration) {
        _loadingDbFileName = null;
        _loadingFuture = null;
      }
    }
  }

  Future<void> refreshWords() async {
    if (_activeDbFileName != null) {
      await loadWords(_activeDbFileName!, force: true);
    }
  }

  void clearWords() {
    _loadGeneration++;
    _loadingDbFileName = null;
    _loadingFuture = null;
    _words.clear();
    _activeDbFileName = null;
    notifyListeners();
  }

  void applyUpdatedWords(String dbFileName, Iterable<Word> updatedWords) {
    if (_activeDbFileName != dbFileName) return;
    final updates = <int, Word>{
      for (final word in updatedWords)
        if (word.id != null) word.id!: word,
    };
    if (updates.isEmpty) return;

    var changed = false;
    _words = _words
        .map((word) {
          final replacement = word.id == null ? null : updates[word.id!];
          if (replacement == null) return word;
          changed = true;
          return replacement;
        })
        .toList(growable: false);
    if (changed) notifyListeners();
  }

  void addLoadedWord(String dbFileName, Word word) {
    if (_activeDbFileName != dbFileName) return;
    _words = [word, ..._words];
    notifyListeners();
  }

  void removeLoadedWord(String dbFileName, int wordId) {
    if (_activeDbFileName != dbFileName) return;
    final nextWords = _words.where((word) => word.id != wordId).toList();
    if (nextWords.length == _words.length) return;
    _words = nextWords;
    notifyListeners();
  }

  Future<void> addWord(Word word) async {
    if (_activeDbFileName == null) return;
    final dbFileName = _activeDbFileName!;
    final id = await _databaseService.addWord(dbFileName, word);
    addLoadedWord(dbFileName, word.copyWith(id: id));
  }

  Future<void> updateWord(Word word) async {
    if (_activeDbFileName == null) return;
    final dbFileName = _activeDbFileName!;
    await _databaseService.updateWord(dbFileName, word);
    applyUpdatedWords(dbFileName, [word]);
  }

  Future<void> deleteWord(int id) async {
    if (_activeDbFileName == null) return;
    final dbFileName = _activeDbFileName!;
    await _databaseService.deleteWord(dbFileName, id);
    removeLoadedWord(dbFileName, id);
  }

  Future<void> generateAndUpdateAllSentences(
    AiService aiService,
    AiSettingsProvider aiSettings,
  ) async {
    if (_activeDbFileName == null) return;

    final wordsToUpdate =
        _words
            .where(
              (w) => w.exampleSentence == null || w.exampleSentence!.isEmpty,
            )
            .toList();
    if (wordsToUpdate.isEmpty) return;

    final fallbackResult = await aiService
        .generateSentencesForWordsWithFallback(
          wordsToUpdate,
          aiSettings.requestOptions(
            fallbackEnabled: aiSettings.autoFallbackEnabled,
          ),
        );
    aiSettings.recordUsedOption(fallbackResult.usedOption);
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
    await loadWords(_activeDbFileName!, force: true);
  }
}
