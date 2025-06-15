// providers/wordbook_manager.dart

import 'package:flutter/material.dart';
import '../models/wordbook_model.dart';
import '../services/database_service.dart';
import '../services/sheets_service.dart';
import 'word_list_provider.dart';

class WordbookManager extends ChangeNotifier {
  final DatabaseService _dbService;
  final SheetsService _sheetsService;
  final WordListNotifier _wordListNotifier; // WordListNotifier를 직접 제어

  List<Wordbook> _wordbooks = [];
  List<Wordbook> get wordbooks => _wordbooks;

  Wordbook? _activeWordbook;
  Wordbook? get activeWordbook => _activeWordbook;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  WordbookManager(this._dbService, this._sheetsService, this._wordListNotifier) {
    // 앱 시작 시 단어장 목록을 불러옵니다.
    loadWordbooks();
  }

  // DB에서 모든 단어장 목록을 불러와 상태를 업데이트합니다.
  Future<void> loadWordbooks() async {
    _setLoading(true);
    _wordbooks = await _dbService.getWordbooks();
    // 이전에 활성화된 단어장이 있었다면, 그 단어장을 다시 활성화합니다.
    // (나중에는 SharedPreferences에 마지막으로 사용한 단어장 ID를 저장하여 불러올 수 있습니다.)
    if (_wordbooks.isNotEmpty && _activeWordbook == null) {
      await setActiveWordbook(_wordbooks.first);
    }
    _setLoading(false);
  }

  // 특정 단어장을 활성화합니다.
  Future<void> setActiveWordbook(Wordbook? wordbook) async {
    _activeWordbook = wordbook;
    // WordListNotifier에게 활성화된 단어장을 전달하여 단어 목록을 변경하도록 합니다.
    await _wordListNotifier.switchWordbook(wordbook);
    notifyListeners();
  }

  // 새로운 단어장을 생성합니다.
  Future<void> createNewWordbook({
    required String name,
    required String spreadsheetId,
    required String sheetName,
  }) async {
    _setLoading(true);
    try {
      // 1. 단어장 메타데이터 생성
      final dbFileName = 'wordbook_${DateTime.now().millisecondsSinceEpoch}.db';
      final newWordbook = Wordbook(
        name: name,
        spreadsheetId: spreadsheetId,
        sheetName: sheetName,
        dbFileName: dbFileName,
      );
      final savedWordbook = await _dbService.addWordbook(newWordbook);

      // 2. 구글 시트에서 단어 가져오기
      final words = await _sheetsService.getWordsFromSheet(spreadsheetId, sheetName);

      // 3. 가져온 단어를 새로운 로컬 DB에 저장하기
      if (words != null) {
        for (final word in words) {
          await _dbService.addWord(savedWordbook.dbFileName, word);
        }
      }

      // 4. 전체 단어장 목록 새로고침 및 새로 만든 단어장 활성화
      await loadWordbooks();
      await setActiveWordbook(savedWordbook);
    } catch (e) {
      debugPrint("Error creating new wordbook: $e");
      // 사용자에게 오류 메시지를 보여주는 로직 추가 가능
    } finally {
      _setLoading(false);
    }
  }

  // 단어장을 삭제합니다.
  Future<void> deleteWordbook(Wordbook wordbook) async {
    _setLoading(true);
    // 삭제하려는 단어장이 현재 활성화된 단어장이라면, 활성 단어장을 null로 변경
    if (_activeWordbook?.id == wordbook.id) {
      await setActiveWordbook(null);
    }

    await _dbService.deleteWordbook(wordbook.id!, wordbook.dbFileName);
    await loadWordbooks(); // 목록 새로고침
    _setLoading(false);
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }
}
