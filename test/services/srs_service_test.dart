import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/srs_service.dart';

void main() {
  final service = SrsService();
  final baseDate = DateTime(2026, 8, 13);

  test('SRS 단계와 복습 예정일을 구분한다', () {
    final fresh = Word(word: 'fresh', meaning: '새로운');
    final due = Word(
      word: 'due',
      meaning: '기한인',
      srsLevel: 2,
      nextReviewDate: '2026-08-12',
    );
    final learning = Word(
      word: 'learning',
      meaning: '학습 중',
      srsLevel: 3,
      nextReviewDate: '2026-08-20',
    );
    final mature = Word(
      word: 'mature',
      meaning: '안정 기억',
      srsLevel: 5,
      nextReviewDate: '2026-09-01',
    );

    expect(service.stageFor(fresh, baseDate: baseDate), SrsStage.newWord);
    expect(service.stageFor(due, baseDate: baseDate), SrsStage.due);
    expect(service.stageFor(learning, baseDate: baseDate), SrsStage.learning);
    expect(service.stageFor(mature, baseDate: baseDate), SrsStage.mature);
  });

  test('오래 밀리고 많이 틀린 단어가 복습 목록 앞에 온다', () {
    final words = [
      Word(
        id: 1,
        word: 'recent',
        meaning: '최근',
        srsLevel: 2,
        nextReviewDate: '2026-08-13',
      ),
      Word(
        id: 2,
        word: 'overdue',
        meaning: '기한 초과',
        srsLevel: 2,
        incorrectCount: 3,
        nextReviewDate: '2026-08-10',
      ),
    ];

    expect(service.dueWords(words, baseDate: baseDate).first.id, 2);
  });

  test('정답과 오답이 기억 단계 및 기록을 올바르게 갱신한다', () {
    final word = Word(
      word: 'memory',
      meaning: '기억',
      srsLevel: 2,
      correctStreak: 2,
      incorrectCount: 1,
    );

    final correct = service.updateWordSrs(
      word: word,
      source: SrsUpdateSource.flashcard,
      difficulty: SrsDifficulty.good,
    );
    final incorrect = service.updateWordSrs(
      word: word,
      source: SrsUpdateSource.spellingQuiz,
    );

    expect(correct.srsLevel, 3);
    expect(correct.correctStreak, 3);
    expect(correct.incorrectCount, 1);
    expect(incorrect.srsLevel, 0);
    expect(incorrect.correctStreak, 0);
    expect(incorrect.incorrectCount, 2);
  });

  test('SRS 간격은 최고 단계 이후에도 마지막 간격으로 제한된다', () {
    expect(service.intervalDaysForLevel(0), 0);
    expect(service.intervalDaysForLevel(3), 7);
    expect(service.intervalDaysForLevel(99), 120);
  });
}
