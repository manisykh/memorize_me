import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/study_plan_model.dart';
import 'package:memorize_app/models/study_session_model.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/today_learning_summary_service.dart';

void main() {
  final day = DateTime(2026, 10, 5, 12);
  const dbFileName = 'book.db';

  Word wordFor(int id) {
    final completed = id <= 10;
    final wrong = id >= 11;
    return Word(
      id: id,
      word: 'word$id',
      meaning: 'meaning$id',
      srsLevel: completed ? 2 : (wrong ? 1 : 0),
      lastReviewedAt: completed || wrong ? '2026-10-05' : null,
      nextReviewDate:
          completed
              ? '2026-10-08'
              : wrong
              ? '2026-10-05'
              : null,
    );
  }

  StudySessionRecord sessionFor({
    required Iterable<int> successful,
    required Iterable<int> failed,
  }) {
    final answers = <StudyAnswerRecord>[
      for (final id in successful)
        StudyAnswerRecord(
          wordKey: '$id',
          word: 'word$id',
          success: true,
          wasNew: id <= 30,
          at: day,
        ),
      for (final id in failed)
        StudyAnswerRecord(
          wordKey: '$id',
          word: 'word$id',
          success: false,
          wasNew: false,
          at: day,
        ),
    ];
    return StudySessionRecord(
      id: 'session',
      dbFileName: dbFileName,
      wordbookName: 'Book',
      mode: StudyHistoryMode.spelling,
      startedAt: day,
      completedAt: day,
      expectedCount: answers.length,
      answers: answers,
    );
  }

  test('기본 30개와 오답 43개 중 중복 20개를 제거해 오늘 범위 53개를 만든다', () {
    final words = [for (var id = 1; id <= 53; id++) wordFor(id)];
    final plan = StudyPlan(
      wordbookId: 1,
      dbFileName: dbFileName,
      wordbookName: 'Book',
      totalWords: 53,
      chunkSize: 30,
      dailyNewTarget: 30,
      startDate: '2026-10-05',
      createdAt: '2026-10-05',
      mode: StudyPlanMode.scheduled,
      scheduleWordKeys: [for (var id = 1; id <= 53; id++) '$id'],
    );

    final summary = TodayLearningSummaryService().build(
      words: words,
      dbFileName: dbFileName,
      plan: plan,
      plannedNewWordCount: 30,
      sessions: [
        sessionFor(
          successful: List.generate(10, (i) => i + 1),
          failed: [for (var id = 11; id <= 53; id++) id],
        ),
      ],
      baseDate: day,
    );

    expect(summary.baseCount, 30);
    expect(summary.mistakeCount, 43);
    expect(summary.overlappingMistakeCount, 20);
    expect(summary.additionalCount, 23);
    expect(summary.totalCount, 53);
    expect(summary.completedCount, 10);
    expect(summary.remainingCount, 43);
  });

  test('자유 모드 묶음 안의 오답은 분모에 중복 추가하지 않는다', () {
    final words = [for (var id = 1; id <= 100; id++) wordFor(id)];
    final plan = StudyPlan(
      wordbookId: 1,
      dbFileName: dbFileName,
      wordbookName: 'Book',
      totalWords: 100,
      chunkSize: 100,
      dailyNewTarget: 30,
      startDate: '2026-10-05',
      createdAt: '2026-10-05',
      mode: StudyPlanMode.free,
      bundleCount: 1,
    );

    final summary = TodayLearningSummaryService().build(
      words: words,
      dbFileName: dbFileName,
      plan: plan,
      plannedNewWordCount: 30,
      sessions: [
        sessionFor(
          successful: const [],
          failed: [for (var id = 11; id <= 53; id++) id],
        ),
      ],
      baseDate: day,
    );

    expect(summary.baseCount, 100);
    expect(summary.additionalCount, 0);
    expect(summary.totalCount, 100);
    expect(summary.remainingCount, 90);
  });
}
