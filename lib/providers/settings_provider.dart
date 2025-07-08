import 'package:flutter/foundation.dart';
import '../models/word_model.dart';

// 시험지 생성에 사용되는 시험 유형
enum SelfTestType { wordToMeaning, meaningToWord, random }

// 시험지 내보내기 옵션
enum ExportOption { testOnly, answersOnly, both }

class AppSettings {
  final int wordCount;
  final SelfTestType testType;
  final ExportOption exportOption;

  AppSettings({
    this.wordCount = 20,
    this.testType = SelfTestType.random,
    this.exportOption = ExportOption.both,
  });

  AppSettings copyWith({int? wordCount, SelfTestType? testType, ExportOption? exportOption}) =>
      AppSettings(
        wordCount: wordCount ?? this.wordCount,
        testType: testType ?? this.testType,
        exportOption: exportOption ?? this.exportOption,
      );
}

class SettingsNotifier extends ChangeNotifier {
  AppSettings _settings = AppSettings();
  AppSettings get settings => _settings;

  void resetWordCountToMax(List<dynamic> words) {
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

  void setTestType(SelfTestType type) {
    _settings = _settings.copyWith(testType: type);
    notifyListeners();
  }

  void setExportOption(ExportOption option) {
    _settings = _settings.copyWith(exportOption: option);
    notifyListeners();
  }
}
