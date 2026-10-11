import '../models/study_plan_model.dart';
import '../models/study_session_model.dart';
import '../models/word_model.dart';
import 'srs_service.dart';
import 'study_schedule_service.dart';

/// The single source of truth for the home tab's daily learning gauge.
///
/// Counts are based on unique word keys, so studying the same word through a
/// flashcard, a multiple-choice quiz, and a spelling quiz never inflates the
/// daily scope.
class TodayLearningSummary {
  final List<Word> baseWords;
  final List<Word> additionalWords;
  final List<Word> scopeWords;
  final List<Word> completedWords;
  final List<Word> remainingWords;
  final int mistakeCount;
  final int overlappingMistakeCount;

  const TodayLearningSummary({
    required this.baseWords,
    required this.additionalWords,
    required this.scopeWords,
    required this.completedWords,
    required this.remainingWords,
    required this.mistakeCount,
    required this.overlappingMistakeCount,
  });

  int get baseCount => baseWords.length;
  int get additionalCount => additionalWords.length;
  int get totalCount => scopeWords.length;
  int get completedCount => completedWords.length;
  int get remainingCount => remainingWords.length;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  static const empty = TodayLearningSummary(
    baseWords: [],
    additionalWords: [],
    scopeWords: [],
    completedWords: [],
    remainingWords: [],
    mistakeCount: 0,
    overlappingMistakeCount: 0,
  );
}

class TodayLearningSummaryService {
  final SrsService _srs;
  final StudyScheduleService _schedule;

  TodayLearningSummaryService({SrsService? srs, StudyScheduleService? schedule})
    : _srs = srs ?? SrsService(),
      _schedule = schedule ?? StudyScheduleService();

  TodayLearningSummary build({
    required List<Word> words,
    required String? dbFileName,
    required StudyPlan? plan,
    required int plannedNewWordCount,
    required List<StudySessionRecord> sessions,
    DateTime? baseDate,
  }) {
    if (dbFileName == null || words.isEmpty) {
      return TodayLearningSummary.empty;
    }

    final day = studyDay(baseDate ?? DateTime.now());
    final byKey = <String, Word>{
      for (final word in words) StudyScheduleService.wordKey(word): word,
    };
    final mistakeKeys = _mistakeKeys(
      sessions: sessions,
      dbFileName: dbFileName,
      day: day,
    ).intersection(byKey.keys.toSet());
    final introducedKeys = _introducedKeys(
      sessions: sessions,
      dbFileName: dbFileName,
      day: day,
    ).intersection(byKey.keys.toSet());

    final baseKeys = _baseKeys(
      words: words,
      byKey: byKey,
      plan: plan,
      plannedNewWordCount: plannedNewWordCount,
      mistakeKeys: mistakeKeys,
      introducedKeys: introducedKeys,
      day: day,
    );
    final additionalKeys = mistakeKeys.difference(baseKeys);
    final scopeKeys = <String>{...baseKeys, ...additionalKeys};
    final completedKeys = <String>{
      for (final key in scopeKeys)
        if (_isCompletedToday(byKey[key]!, day)) key,
    };

    List<Word> select(Set<String> keys) => [
      for (final word in words)
        if (keys.contains(StudyScheduleService.wordKey(word))) word,
    ];

    return TodayLearningSummary(
      baseWords: select(baseKeys),
      additionalWords: select(additionalKeys),
      scopeWords: select(scopeKeys),
      completedWords: select(completedKeys),
      remainingWords: select(scopeKeys.difference(completedKeys)),
      mistakeCount: mistakeKeys.length,
      overlappingMistakeCount: mistakeKeys.intersection(baseKeys).length,
    );
  }

  Set<String> _baseKeys({
    required List<Word> words,
    required Map<String, Word> byKey,
    required StudyPlan? plan,
    required int plannedNewWordCount,
    required Set<String> mistakeKeys,
    required Set<String> introducedKeys,
    required DateTime day,
  }) {
    final activePlan =
        plan != null && plan.status == StudyPlanStatus.active ? plan : null;
    final keys = <String>{};

    if (activePlan?.mode == StudyPlanMode.free) {
      keys.addAll(_schedule.bundleKeys(words, activePlan!));
      return keys.intersection(byKey.keys.toSet());
    }

    if (activePlan?.mode == StudyPlanMode.scheduled) {
      keys.addAll(_schedule.scheduledKeysOn(words, activePlan!, day));
    }

    // A review that was already waiting when the day opened is part of the
    // basic goal. A word made due by today's mistake is classified as an
    // addition unless it was already in the planned set above.
    keys.addAll(
      words
          .where(
            (word) =>
                _srs.isDueForReview(word, baseDate: day) &&
                !mistakeKeys.contains(StudyScheduleService.wordKey(word)),
          )
          .map(StudyScheduleService.wordKey),
    );

    if (activePlan?.mode != StudyPlanMode.scheduled) {
      keys.addAll(introducedKeys);
      final remainingSlots =
          (plannedNewWordCount - introducedKeys.length)
              .clamp(0, plannedNewWordCount)
              .toInt();
      keys.addAll(
        words
            .where(_srs.isNewWord)
            .map(StudyScheduleService.wordKey)
            .where((key) => !keys.contains(key))
            .take(remainingSlots),
      );
    }

    return keys.intersection(byKey.keys.toSet());
  }

  Set<String> _mistakeKeys({
    required List<StudySessionRecord> sessions,
    required String dbFileName,
    required DateTime day,
  }) => {
    for (final session in sessions)
      if (session.dbFileName == dbFileName)
        for (final answer in session.answersOn(day))
          if (answer.needsQuizReview) answer.wordKey,
  };

  Set<String> _introducedKeys({
    required List<StudySessionRecord> sessions,
    required String dbFileName,
    required DateTime day,
  }) => {
    for (final session in sessions)
      if (session.dbFileName == dbFileName)
        for (final answer in session.answersOn(day))
          if (answer.wasNew) answer.wordKey,
  };

  bool _isCompletedToday(Word word, DateTime day) {
    return _srs.wasReviewedToday(word, baseDate: day) &&
        !_srs.isDueForReview(word, baseDate: day);
  }
}
