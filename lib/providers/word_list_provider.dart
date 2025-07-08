import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../providers/ai_settings_provider.dart'; // AI 설정을 가져오기 위해 추가
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

  // ▼▼▼ [수정] AiSettingsProvider를 인자로 받아 모델 이름을 전달하도록 변경 ▼▼▼
  Future<void> generateAndUpdateAllSentences(
    AiService aiService,
    AiSettingsProvider aiSettings,
  ) async {
    if (_activeDbFileName == null) return;

    final wordsToUpdate =
        _words.where((w) => w.exampleSentence == null || w.exampleSentence!.isEmpty).toList();
    if (wordsToUpdate.isEmpty) return;

    final wordStrings = wordsToUpdate.map((w) => w.word).toList();

    // 현재 설정된 모델 이름을 함께 전달합니다.
    final sentenceMap = await aiService.generateSentencesForWords(
      wordStrings,
      aiSettings.selectedModel,
    );

    for (final word in wordsToUpdate) {
      if (sentenceMap.containsKey(word.word)) {
        final updatedWord = Word(
          id: word.id,
          word: word.word,
          meaning: word.meaning,
          exampleSentence: sentenceMap[word.word],
        );
        await _databaseService.updateWord(_activeDbFileName!, updatedWord);
      }
    }
    await loadWords(_activeDbFileName!);
  }
}
