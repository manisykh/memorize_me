// lib/providers/word_list_provider.dart (수정된 전체 코드)

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

  // ▼▼▼ [추가] DB에서 단어 목록을 다시 불러와 상태를 갱신하는 메서드 ▼▼▼
  Future<void> refreshWords() async {
    if (_activeDbFileName != null) {
      // 현재 활성화된 DB 파일 이름으로 단어 목록을 다시 로드합니다.
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

    final wordStrings = wordsToUpdate.map((w) => w.word).toList();

    final sentenceMap = await aiService.generateSentencesForWords(
      wordStrings,
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
