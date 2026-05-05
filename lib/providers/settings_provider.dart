// lib/providers/settings_provider.dart

import 'package:flutter/foundation.dart';
import '../models/word_model.dart';

enum SelfTestType { wordToMeaning, meaningToWord, sentenceCompletion }

enum TestQuestionFormat { shortAnswer, multipleChoice }

enum ExportOption { testOnly, answersOnly, both }

class AppSettings {
  final int wordCount;
  final Set<SelfTestType> testTypes;
  final TestQuestionFormat questionFormat;
  final ExportOption exportOption;
  final double fontSize;
  final bool includeTranslation; // ▼▼▼ [추가] 해석 포함 여부 설정
  final bool includeSpellingHint;

  AppSettings({
    this.wordCount = 20,
    this.testTypes = const {SelfTestType.wordToMeaning, SelfTestType.meaningToWord},
    this.questionFormat = TestQuestionFormat.shortAnswer,
    this.exportOption = ExportOption.both,
    this.fontSize = 12.0,
    this.includeTranslation = true, // ▼▼▼ [추가] 기본값은 true (보이게)
    this.includeSpellingHint = false,
  });

  AppSettings copyWith({
    int? wordCount,
    Set<SelfTestType>? testTypes,
    TestQuestionFormat? questionFormat,
    ExportOption? exportOption,
    double? fontSize,
    bool? includeTranslation, // ▼▼▼ [추가]
    bool? includeSpellingHint,
  }) => AppSettings(
    wordCount: wordCount ?? this.wordCount,
    testTypes: testTypes ?? this.testTypes,
    questionFormat: questionFormat ?? this.questionFormat,
    exportOption: exportOption ?? this.exportOption,
    fontSize: fontSize ?? this.fontSize,
    includeTranslation: includeTranslation ?? this.includeTranslation, // ▼▼▼ [추가]
    includeSpellingHint: includeSpellingHint ?? this.includeSpellingHint,
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

  void updateTestTypes(Set<SelfTestType> types) {
    _settings = _settings.copyWith(testTypes: types);
    notifyListeners();
  }

  void setQuestionFormat(TestQuestionFormat format) {
    _settings = _settings.copyWith(questionFormat: format);
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

  // ▼▼▼ [추가] 해석 포함 여부를 설정하는 메서드
  void setIncludeTranslation(bool value) {
    _settings = _settings.copyWith(includeTranslation: value);
    notifyListeners();
  }

  void setIncludeSpellingHint(bool value) {
    _settings = _settings.copyWith(includeSpellingHint: value);
    notifyListeners();
  }
}
