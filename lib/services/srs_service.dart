// lib/services/srs_service.dart (신규 파일)

import 'dart:math';
import 'package:intl/intl.dart';
import '../models/word_model.dart';

// 사용자가 느끼는 난이도
enum SrsDifficulty { again, hard, good, easy }

class SrsService {
  // 간격 반복 주기 (일)
  // 1일 -> 3일 -> 7일 -> 15일 ...
  final List<int> _srsIntervals = const [1, 3, 7, 15, 30, 60, 120];

  /// 단어와 사용자가 선택한 난이도를 기반으로
  /// 다음 복습 날짜와 새로운 SRS 레벨이 적용된 Word 객체를 반환합니다.
  Word updateWordSrs(Word word, SrsDifficulty difficulty) {
    int newSrsLevel;
    int intervalDays;

    switch (difficulty) {
      case SrsDifficulty.again:
        // '다시'를 누르면 레벨 1로 초기화하고, 10분 후 다시 보도록 설정 (예시)
        // 실제 구현에서는 다음 세션에 바로 나오도록 처리
        newSrsLevel = 1;
        intervalDays = 0; // 즉시 복습 또는 다음 세션
        break;
      case SrsDifficulty.hard:
        // '어려움'을 누르면 레벨 상승폭을 줄임 (현재 레벨 유지 또는 약간만 증가)
        newSrsLevel = word.srsLevel; // 레벨 유지
        intervalDays = _getIntervalForLevel(newSrsLevel);
        break;
      case SrsDifficulty.good:
        // '보통'을 누르면 정상적으로 레벨 1 증가
        newSrsLevel = word.srsLevel + 1;
        intervalDays = _getIntervalForLevel(newSrsLevel);
        break;
      case SrsDifficulty.easy:
        // '쉬움'을 누르면 레벨을 더 많이 증가
        newSrsLevel = word.srsLevel + 2;
        intervalDays = _getIntervalForLevel(newSrsLevel);
        break;
    }

    final nextReviewDate = DateTime.now().add(Duration(days: intervalDays));

    return word.copyWith(
      srsLevel: newSrsLevel,
      nextReviewDate: DateFormat('yyyy-MM-dd').format(nextReviewDate),
    );
  }

  int _getIntervalForLevel(int level) {
    if (level <= 0) return 0;
    // 정의된 최대 간격을 초과하지 않도록 함
    final index = min(level - 1, _srsIntervals.length - 1);
    return _srsIntervals[index];
  }
}
