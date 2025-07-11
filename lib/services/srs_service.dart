// lib/services/srs_service.dart

import 'dart:math';
import 'package:intl/intl.dart';
import '../models/word_model.dart';

// 사용자가 느끼는 난이도 (플래시카드용)
enum SrsDifficulty { again, good }

// 학습 출처
enum SrsUpdateSource { flashcard, spellingQuiz }

class SrsService {
  // 간격 반복 주기 (일)
  // Level 0: 당일, Level 1: 1일, Level 2: 3일, ...
  final List<int> _srsIntervals = const [0, 1, 3, 7, 15, 30, 60, 120];

  /// 단어의 SRS 정보를 업데이트합니다.
  /// 학습 출처(source)에 따라 가중치를 다르게 적용합니다.
  Word updateWordSrs({
    required Word word,
    required SrsUpdateSource source,
    SrsDifficulty? difficulty, // 플래시카드에서만 사용
  }) {
    int newSrsLevel;
    int newCorrectStreak;
    int newIncorrectCount = word.incorrectCount;

    if (source == SrsUpdateSource.spellingQuiz) {
      // 스펠링 퀴즈에서 틀린 경우: 가장 강력한 '모름' 처리
      newSrsLevel = 0; // 즉시 복습 대상
      newCorrectStreak = 0;
      newIncorrectCount++;
    } else {
      // 플래시카드 학습
      if (difficulty == SrsDifficulty.good) {
        // '알고 있음'
        newSrsLevel = word.srsLevel + 1;
        newCorrectStreak = word.correctStreak + 1;
      } else {
        // '모르겠음' (again)
        // 레벨을 한 단계 낮추지만, 0 이하로는 내려가지 않음
        newSrsLevel = max(0, word.srsLevel - 1);
        newCorrectStreak = 0;
        newIncorrectCount++;
      }
    }

    final intervalDays = _getIntervalForLevel(newSrsLevel);
    final nextReviewDate = DateTime.now().add(Duration(days: intervalDays));

    return word.copyWith(
      srsLevel: newSrsLevel,
      nextReviewDate: DateFormat('yyyy-MM-dd').format(nextReviewDate),
      correctStreak: newCorrectStreak,
      incorrectCount: newIncorrectCount,
    );
  }

  int _getIntervalForLevel(int level) {
    if (level < 0) return 0;
    // 정의된 최대 간격을 초과하지 않도록 함
    final index = min(level, _srsIntervals.length - 1);
    return _srsIntervals[index];
  }
}
