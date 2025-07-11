// lib/providers/flashcard_settings_provider.dart (수정된 전체 코드)

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 플래시카드 앞면에 무엇을 보여줄지 정의
enum FlashcardFrontType { word, meaning }

// ▼▼▼ [추가] 플래시카드에 표시할 단어를 필터링하는 옵션 ▼▼▼
enum WordFilter { all, newWords, reviewWords }

class FlashcardSettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // --- 설정 변수 ---
  FlashcardFrontType _frontType = FlashcardFrontType.word;
  WordFilter _wordFilter = WordFilter.all;
  bool _isRandom = true;

  FlashcardSettingsProvider() {
    loadSettings();
  }

  // --- 외부에서 설정값을 읽기 위한 Getters ---
  FlashcardFrontType get frontType => _frontType;
  WordFilter get wordFilter => _wordFilter;
  bool get isRandom => _isRandom;

  // --- 설정 저장 및 불러오기 ---
  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> loadSettings() async {
    await _initPrefs();
    _frontType =
        FlashcardFrontType.values[_prefs!.getInt('flashcard_front_type') ??
            FlashcardFrontType.word.index];
    _wordFilter =
        WordFilter.values[_prefs!.getInt('flashcard_word_filter') ?? WordFilter.all.index];
    _isRandom = _prefs!.getBool('flashcard_is_random') ?? true;
    notifyListeners();
  }

  // --- 설정 변경 함수 ---
  void setFrontType(FlashcardFrontType newType) {
    if (_frontType == newType) return;
    _frontType = newType;
    _prefs?.setInt('flashcard_front_type', newType.index);
    notifyListeners();
  }

  void setWordFilter(WordFilter newFilter) {
    if (_wordFilter == newFilter) return;
    _wordFilter = newFilter;
    _prefs?.setInt('flashcard_word_filter', newFilter.index);
    notifyListeners();
  }

  void setIsRandom(bool newIsRandom) {
    if (_isRandom == newIsRandom) return;
    _isRandom = newIsRandom;
    _prefs?.setBool('flashcard_is_random', newIsRandom);
    notifyListeners();
  }
}
