// providers/quiz_session_provider.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../providers/settings_provider.dart';
import '../screens/quiz_helpers.dart';

// 퀴즈 결과 저장을 위한 모델
class QuizResult {
  final QuizItem item;
  final String userAnswer;
  final bool isCorrect;
  QuizResult({required this.item, required this.userAnswer, required this.isCorrect});
}

class QuizSessionProvider extends ChangeNotifier {
  final List<Word> _allWords;
  final AppSettings _settings;

  QuizSessionProvider(this._allWords, this._settings) {
    _startSession();
  }

  List<QuizItem> _sessionItems = [];
  List<QuizItem> get sessionItems => _sessionItems;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  final List<QuizResult> _results = [];
  List<QuizResult> get results => _results;

  bool _answerSubmitted = false;
  bool get answerSubmitted => _answerSubmitted;

  bool get isSessionFinished => _currentIndex >= _sessionItems.length;
  int get correctAnswers => _results.where((r) => r.isCorrect).length;

  void _startSession() {
    final words = List<Word>.from(_allWords)..shuffle();
    final wordCount = _settings.wordCount.clamp(1, _allWords.length);
    final sessionWords = words.take(wordCount).toList();

    _sessionItems =
        sessionWords.map((word) {
          return QuizItem(word: word, questionType: TestType.meaningToWord);
        }).toList();
    notifyListeners();
  }

  void submitAnswer(String userAnswer) {
    if (_answerSubmitted) return;

    final currentItem = _sessionItems[_currentIndex];
    // ▼▼▼ 수정된 부분 ▼▼▼
    // 정답은 word 필드에서 중괄호를 제거하여 생성합니다.
    final correctAnswer = currentItem.word.word.replaceAll('{', '').replaceAll('}', '');
    // ▲▲▲ 수정된 부분 ▲▲▲

    final bool isCorrect = userAnswer.trim().toLowerCase() == correctAnswer.trim().toLowerCase();

    _results.add(QuizResult(item: currentItem, userAnswer: userAnswer, isCorrect: isCorrect));
    _answerSubmitted = true;
    notifyListeners();
  }

  void nextQuestion() {
    if (_currentIndex < _sessionItems.length - 1) {
      _currentIndex++;
      _answerSubmitted = false;
    } else {
      _currentIndex++;
    }
    notifyListeners();
  }
}
