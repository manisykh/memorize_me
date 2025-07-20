import 'package:flutter/foundation.dart';
import '../models/word_model.dart';

// 'random'을 제거하고, 사용자가 직접 여러 유형을 선택하게 합니다.
enum SelfTestType { wordToMeaning, meaningToWord, sentenceCompletion }

enum ExportOption { testOnly, answersOnly, both }

class AppSettings {
  final int wordCount;
  final Set<SelfTestType> testTypes; // 단일 선택에서 Set(집합)을 이용한 복수 선택으로 변경
  final ExportOption exportOption;
  final double fontSize;

  AppSettings({
    this.wordCount = 20,
    // 기본값으로 두 가지 유형을 포함하는 Set으로 설정
    this.testTypes = const {SelfTestType.wordToMeaning, SelfTestType.meaningToWord},
    this.exportOption = ExportOption.both,
    this.fontSize = 12.0,
  });

  AppSettings copyWith({
    int? wordCount,
    Set<SelfTestType>? testTypes,
    ExportOption? exportOption,
    double? fontSize,
  }) => AppSettings(
    wordCount: wordCount ?? this.wordCount,
    testTypes: testTypes ?? this.testTypes,
    exportOption: exportOption ?? this.exportOption,
    fontSize: fontSize ?? this.fontSize,
  );
}

class SettingsNotifier extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  void resetWordCountToMax(List<Word> words) {
    final newMaxCount = words.isNotEmpty ? words.length : 1;
    if (_settings.wordCount > newMaxCount) {
      _settings = _settings.copyWith(wordCount: newMaxCount);
      notifyListeners();
    }
  }

  void setWordCount(int count) {
    _settings = _settings.copyWith(wordCount: count);
    notifyListeners();
  }

  // setTestType을 updateTestTypes로 변경하여 복수 선택을 처리
  void updateTestTypes(Set<SelfTestType> types) {
    _settings = _settings.copyWith(testTypes: types);
    notifyListeners();
  }

  void setExportOption(ExportOption option) {
    _settings = _settings.copyWith(exportOption: option);
    notifyListeners();
  }

  void setFontSize(double size) {
    _settings = _settings.copyWith(fontSize: size);
    notifyListeners();
  }
}
