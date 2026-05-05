// lib/providers/quiz_session_provider.dart

import 'package:flutter/material.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../services/srs_service.dart';
import 'wordbook_manager.dart';

// 퀴즈 결과 저장을 위한 모델
class QuizResult {
  final Word word;
  final String userAnswer;
  final bool isCorrect;
  QuizResult({required this.word, required this.userAnswer, required this.isCorrect});
}

class QuizSessionProvider extends ChangeNotifier {
  final WordbookManager _wordbookManager;
  final Wordbook _wordbook;
  final List<Word> _sessionWords;
  final SrsService _srsService = SrsService();

  int _currentIndex = 0;
  final List<Word> _incorrectWords = [];
  final Map<int, String> _userAnswers = {};
  bool _isFinished = false;
  bool _answerSubmitted = false;

  QuizSessionProvider(this._wordbookManager, this._wordbook, List<Word> sessionWords)
    : _sessionWords = List.from(sessionWords)..shuffle();

  // Getters for UI state
  int get currentIndex => _currentIndex;
  int get totalWords => _sessionWords.length;
  bool get isFinished => _isFinished;
  bool get answerSubmitted => _answerSubmitted;
  Word get currentWord => _sessionWords[_currentIndex];
  bool get isLastWord => _currentIndex == _sessionWords.length - 1;
  List<QuizResult> get results {
    return _userAnswers.entries.map((entry) {
      final word = _sessionWords.firstWhere((w) => w.id == entry.key);
      final isCorrect = entry.value.trim().toLowerCase() == word.word.toLowerCase();
      return QuizResult(word: word, userAnswer: entry.value, isCorrect: isCorrect);
    }).toList();
  }

  int get correctAnswers => results.where((r) => r.isCorrect).length;

  void submitAnswer(String userAnswer) {
    if (_answerSubmitted) return;
    _userAnswers[currentWord.id!] = userAnswer;
    final isCorrect = userAnswer.trim().toLowerCase() == currentWord.word.toLowerCase();

    if (!isCorrect) {
      if (!_incorrectWords.any((w) => w.id == currentWord.id)) {
        _incorrectWords.add(currentWord);
      }
    }

    _answerSubmitted = true;
    notifyListeners();
  }

  void nextWord() {
    if (isLastWord) {
      _isFinished = true;
      _updateSrsForIncorrectWords(); // 퀴즈 종료 시 SRS 업데이트
    } else {
      _currentIndex++;
      _answerSubmitted = false;
    }
    notifyListeners();
  }

  Future<void> _updateSrsForIncorrectWords() async {
    if (_incorrectWords.isEmpty) return;

    List<Word> updatedWords = [];
    for (var word in _incorrectWords) {
      final updatedWord = _srsService.updateWordSrs(
        word: word,
        source: SrsUpdateSource.spellingQuiz,
      );
      updatedWords.add(updatedWord);
    }

    await _wordbookManager.updateWordsSrsData(_wordbook.dbFileName, updatedWords);
  }

  Future<void> saveIncorrectWordsOnExit() async {
    // 아직 처리되지 않은 오답이 있다면 SRS 업데이트
    if (!_isFinished && _userAnswers.isNotEmpty) {
      // Check all answers, not just the ones marked incorrect so far
      final currentIncorrects = _userAnswers.entries
          .where((entry) {
            final word = _sessionWords.firstWhere((w) => w.id == entry.key);
            return entry.value.trim().toLowerCase() != word.word.toLowerCase();
          })
          .map((entry) => _sessionWords.firstWhere((w) => w.id == entry.key));

      _incorrectWords.clear();
      _incorrectWords.addAll(
        currentIncorrects.where((w) => !_incorrectWords.any((iw) => iw.id == w.id)),
      );

      await _updateSrsForIncorrectWords();
    }
  }

  void restart() {
    _currentIndex = 0;
    _incorrectWords.clear();
    _userAnswers.clear();
    _isFinished = false;
    _answerSubmitted = false;
    _sessionWords.shuffle();
    notifyListeners();
  }
}
