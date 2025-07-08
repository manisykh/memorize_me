import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 플래시카드 앞면에 무엇을 보여줄지 정의하는 Enum
enum FlashcardFrontType { word, meaning }

class FlashcardSettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  // 기본값은 '단어 먼저 보기'
  FlashcardFrontType _frontType = FlashcardFrontType.word;

  FlashcardSettingsProvider() {
    loadSettings();
  }

  // 외부에서 현재 설정값을 읽기 위한 Getter
  FlashcardFrontType get frontType => _frontType;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // 설정을 휴대폰에 저장
  Future<void> saveSettings() async {
    await _initPrefs();
    _prefs!.setInt('flashcard_front_type', _frontType.index);
    notifyListeners();
  }

  // 저장된 설정을 불러오기
  Future<void> loadSettings() async {
    await _initPrefs();
    _frontType =
        FlashcardFrontType.values[_prefs!.getInt('flashcard_front_type') ??
            FlashcardFrontType.word.index];
    notifyListeners();
  }

  // 설정 변경 함수
  void setFrontType(FlashcardFrontType newType) {
    if (_frontType == newType) return;
    _frontType = newType;
    saveSettings();
  }
}
