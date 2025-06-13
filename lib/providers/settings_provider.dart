import 'package:flutter/foundation.dart';

// 시험 유형 Enum
enum TestType { wordToMeaning, meaningToWord, meaningToWordWithHint, random }

// 내보내기 옵션 Enum
enum ExportOption { testOnly, answersOnly, both }

// 설정 데이터 모델 클래스
class AppSettings {
  final int wordCount;
  final TestType testType;
  final ExportOption exportOption;

  AppSettings({
    this.wordCount = 20,
    this.testType = TestType.random,
    this.exportOption = ExportOption.both,
  });

  AppSettings copyWith({int? wordCount, TestType? testType, ExportOption? exportOption}) =>
      AppSettings(
        wordCount: wordCount ?? this.wordCount,
        testType: testType ?? this.testType,
        exportOption: exportOption ?? this.exportOption,
      );
}

// 설정 상태 관리 클래스
class SettingsNotifier extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  void setWordCount(int count) {
    _settings = _settings.copyWith(wordCount: count);
    notifyListeners();
  }

  void setTestType(TestType type) {
    _settings = _settings.copyWith(testType: type);
    notifyListeners();
  }

  void setExportOption(ExportOption option) {
    _settings = _settings.copyWith(exportOption: option);
    notifyListeners();
  }
}
