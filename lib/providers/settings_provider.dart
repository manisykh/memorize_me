// lib/providers/settings_provider.dart

import 'package:flutter/foundation.dart';
import '../models/word_model.dart';

// ▼▼▼ [수정] sentenceCompletion 추가 ▼▼▼
enum SelfTestType { wordToMeaning, meaningToWord, sentenceCompletion, random }

enum ExportOption { testOnly, answersOnly, both }

class AppSettings {
  final int wordCount;
  final SelfTestType testType;
  final ExportOption exportOption;
  final double fontSize;

  AppSettings({
    this.wordCount = 20,
    this.testType = SelfTestType.random,
    this.exportOption = ExportOption.both,
    this.fontSize = 12.0,
  });

  AppSettings copyWith({
    int? wordCount,
    SelfTestType? testType,
    ExportOption? exportOption,
    double? fontSize,
  }) => AppSettings(
    wordCount: wordCount ?? this.wordCount,
    testType: testType ?? this.testType,
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

  void setTestType(SelfTestType type) {
    _settings = _settings.copyWith(testType: type);
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
