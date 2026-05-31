// lib/services/srs_service.dart

import 'dart:math';

import 'package:intl/intl.dart';

import '../models/word_model.dart';

enum SrsDifficulty { again, good }

enum SrsUpdateSource { flashcard, spellingQuiz }

enum SrsStage { newWord, due, learning, mature }

enum LearningFocus { review, newWords, quiz, rest }

class LearningFocusRecommendation {
  final LearningFocus focus;
  final String title;
  final String description;
  final String actionLabel;

  const LearningFocusRecommendation({
    required this.focus,
    required this.title,
    required this.description,
    required this.actionLabel,
  });
}

class DailyLearningPlan {
  final List<Word> dueWords;
  final List<Word> newWords;
  final List<Word> learningWords;
  final List<Word> matureWords;

  const DailyLearningPlan({
    required this.dueWords,
    required this.newWords,
    required this.learningWords,
    required this.matureWords,
  });

  bool get hasReview => dueWords.isNotEmpty;
  bool get hasNewWords => newWords.isNotEmpty;
  bool get canTakeQuiz => dueWords.isNotEmpty || learningWords.isNotEmpty;
  int get suggestedNewWordBatchSize => newWords.length;
}

class SrsService {
  // New words have no nextReviewDate yet. After the first exposure, review
  // intervals progress through short-term reinforcement before spacing out.
  final List<int> _srsIntervals = const [0, 1, 3, 7, 15, 30, 60, 120];

  DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? reviewDateFor(Word word) {
    final value = word.nextReviewDate;
    if (value == null || value.isEmpty) return null;
    try {
      final parsed = DateTime.parse(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  DateTime? lastReviewedAtFor(Word word) {
    final value = word.lastReviewedAt;
    if (value == null || value.isEmpty) return null;
    try {
      final parsed = DateTime.parse(value);
      return DateTime(parsed.year, parsed.month, parsed.day);
    } catch (_) {
      return null;
    }
  }

  bool wasReviewedToday(Word word, {DateTime? baseDate}) {
    final reviewedAt = lastReviewedAtFor(word);
    if (reviewedAt == null) return false;
    final targetDate = baseDate ?? today();
    return reviewedAt.year == targetDate.year &&
        reviewedAt.month == targetDate.month &&
        reviewedAt.day == targetDate.day;
  }

  bool isNewWord(Word word) {
    return word.srsLevel == 0 && reviewDateFor(word) == null && word.correctStreak == 0;
  }

  bool isDueForReview(Word word, {DateTime? baseDate}) {
    final reviewDate = reviewDateFor(word);
    if (reviewDate == null) return false;
    final targetDate = baseDate ?? today();
    return !reviewDate.isAfter(targetDate);
  }

  SrsStage stageFor(Word word, {DateTime? baseDate}) {
    if (isDueForReview(word, baseDate: baseDate)) return SrsStage.due;
    if (isNewWord(word)) return SrsStage.newWord;
    if (word.srsLevel >= 5) return SrsStage.mature;
    return SrsStage.learning;
  }

  int reviewPriority(Word word, {DateTime? baseDate}) {
    final targetDate = baseDate ?? today();
    final reviewDate = reviewDateFor(word);
    final overdueDays = reviewDate == null ? 0 : targetDate.difference(reviewDate).inDays;
    return (overdueDays * 100) + (word.incorrectCount * 10) - word.srsLevel;
  }

  List<Word> dueWords(List<Word> words, {DateTime? baseDate}) {
    final targetDate = baseDate ?? today();
    final due = words.where((word) => isDueForReview(word, baseDate: targetDate)).toList();
    due.sort(
      (a, b) =>
          reviewPriority(b, baseDate: targetDate).compareTo(reviewPriority(a, baseDate: targetDate)),
    );
    return due;
  }

  DailyLearningPlan buildDailyPlan(List<Word> words, {DateTime? baseDate}) {
    final targetDate = baseDate ?? today();
    final newWords = <Word>[];
    final dueWords = <Word>[];
    final learningWords = <Word>[];
    final matureWords = <Word>[];

    for (final word in words) {
      switch (stageFor(word, baseDate: targetDate)) {
        case SrsStage.newWord:
          newWords.add(word);
          break;
        case SrsStage.due:
          dueWords.add(word);
          break;
        case SrsStage.learning:
          learningWords.add(word);
          break;
        case SrsStage.mature:
          matureWords.add(word);
          break;
      }
    }

    dueWords.sort(
      (a, b) =>
          reviewPriority(b, baseDate: targetDate).compareTo(reviewPriority(a, baseDate: targetDate)),
    );
    newWords.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));

    return DailyLearningPlan(
      dueWords: dueWords,
      newWords: newWords,
      learningWords: learningWords,
      matureWords: matureWords,
    );
  }

  String labelForStage(SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return '새 단어';
      case SrsStage.due:
        return '오늘 복습';
      case SrsStage.learning:
        return '학습 중';
      case SrsStage.mature:
        return '안정 기억';
    }
  }

  String descriptionForStage(SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return '아직 SRS 일정에 들어가기 전이라 첫 노출이 필요한 단어';
      case SrsStage.due:
        return '복습 예정일이 오늘이거나 이미 지나서 지금 다시 봐야 하는 단어';
      case SrsStage.learning:
        return '한 번 이상 학습했고 다음 복습일을 기다리는 단어';
      case SrsStage.mature:
        return '복습 간격이 길어졌고 비교적 안정적으로 기억 중인 단어';
    }
  }

  String reasonForWord(Word word, {DateTime? baseDate}) {
    final stage = stageFor(word, baseDate: baseDate);
    final reviewDate = reviewDateFor(word);
    switch (stage) {
      case SrsStage.newWord:
        return '첫 학습 전';
      case SrsStage.due:
        if (reviewDate == null) return '오늘 복습 대상';
        final targetDate = baseDate ?? today();
        final overdueDays = targetDate.difference(reviewDate).inDays;
        if (overdueDays > 0) return '$overdueDays일 밀림';
        return '오늘 복습일';
      case SrsStage.learning:
        if (reviewDate == null) return '다음 복습 대기';
        return '${DateFormat('M/d').format(reviewDate)} 복습 예정';
      case SrsStage.mature:
        if (reviewDate == null) return '장기 기억 단계';
        return '${DateFormat('M/d').format(reviewDate)} 복습 예정';
    }
  }

  LearningFocusRecommendation recommendationForPlan(DailyLearningPlan plan) {
    if (plan.hasReview) {
      return LearningFocusRecommendation(
        focus: LearningFocus.review,
        title: '오늘은 복습이 먼저입니다',
        description:
            '${plan.dueWords.length}개의 단어가 오늘 다시 보길 기다리고 있어요. 밀린 단어부터 붙잡으면 기억 흐름이 더 안정적으로 이어집니다.',
        actionLabel: '오늘 복습 시작',
      );
    }

    if (plan.hasNewWords) {
      final batchSize = plan.suggestedNewWordBatchSize;
      return LearningFocusRecommendation(
        focus: LearningFocus.newWords,
        title: '새 단어를 SRS에 올릴 타이밍입니다',
        description:
            '${plan.newWords.length}개의 새 단어가 기다리고 있어요. 먼저 $batchSize개부터 시작하면 부담 없이 루틴이 이어집니다.',
        actionLabel: '새 단어 $batchSize개 시작',
      );
    }

    if (plan.canTakeQuiz) {
      return LearningFocusRecommendation(
        focus: LearningFocus.quiz,
        title: '짧은 테스트로 기억을 확인해보세요',
        description:
            '학습 중인 단어가 남아 있어요. 바로 떠오르는지 확인하면 다음 복습 우선순위가 더 선명해집니다.',
        actionLabel: '짧은 테스트 시작',
      );
    }

    return const LearningFocusRecommendation(
      focus: LearningFocus.rest,
      title: '오늘 학습은 깔끔하게 비었습니다',
      description: '지금은 급한 복습이 없어요. 새 단어장을 보거나 전체 카드를 가볍게 훑어보는 정도면 충분합니다.',
      actionLabel: '전체 카드 보기',
    );
  }

  int intervalDaysForLevel(int level) => _getIntervalForLevel(level);

  Word updateWordSrs({
    required Word word,
    required SrsUpdateSource source,
    SrsDifficulty? difficulty,
  }) {
    int newSrsLevel;
    int newCorrectStreak;
    var newIncorrectCount = word.incorrectCount;

    if (source == SrsUpdateSource.spellingQuiz) {
      newSrsLevel = 0;
      newCorrectStreak = 0;
      newIncorrectCount++;
    } else {
      if (difficulty == SrsDifficulty.good) {
        newSrsLevel = word.srsLevel + 1;
        newCorrectStreak = word.correctStreak + 1;
      } else {
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
      lastReviewedAt: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      correctStreak: newCorrectStreak,
      incorrectCount: newIncorrectCount,
    );
  }

  int _getIntervalForLevel(int level) {
    if (level < 0) return 0;
    final index = min(level, _srsIntervals.length - 1);
    return _srsIntervals[index];
  }
}
