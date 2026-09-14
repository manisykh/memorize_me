import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/study_session_model.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/quiz_review_service.dart';

void main() {
  const service = QuizReviewService();
  final word = Word(id: 1, word: 'word', meaning: 'meaning');
  StudySessionRecord session(String id, StudyHistoryMode mode, {bool success = false,
      bool retry = false, bool skipped = false, bool completed = true,
      bool prior = false, String db = 'book.db', int hour = 10}) {
    final at = DateTime(2026, 9, 3, hour);
    return StudySessionRecord(id: id, dbFileName: db, wordbookName: 'Book', mode: mode,
      startedAt: at, completedAt: completed ? at : null, expectedCount: 1,
      answers: [StudyAnswerRecord(wordKey: '1', word: 'word', success: success,
        wasNew: false, at: at, skipped: skipped, hadPriorQuizMistake: prior,
        attempts: retry ? 2 : 1, attemptLog: [
          if (retry) StudyAttemptRecord(at: at.subtract(const Duration(seconds: 5)), success: false),
          StudyAttemptRecord(at: at, success: success),
        ])]);
  }
  List<QuizReviewEntry> entries(List<StudySessionRecord> sessions, {bool cumulative = false,
      Word? value}) => service.entries(dbFileName: 'book.db', words: [value ?? word],
        sessions: sessions, cumulative: cumulative);

  test('flashcard unknown and generic SRS due never enter quiz mistakes', () {
    final due = word.copyWith(incorrectCount: 8, nextReviewDate: '2026-09-03');
    final records = [session('card', StudyHistoryMode.flashcard)];
    expect(entries(records, value: due), isEmpty);
    expect(entries(records, value: due, cumulative: true), isEmpty);
  });

  test('both modes stay separate, clean MCQ clears only MCQ and archive stays', () {
    final records = [session('mcq', StudyHistoryMode.multipleChoice),
      session('spell', StudyHistoryMode.spelling),
      session('pass', StudyHistoryMode.multipleChoice, success: true, hour: 11)];
    final pending = entries(records).single;
    expect(pending.pendingModes, {StudyHistoryMode.spelling});
    expect(pending.historyModes, {StudyHistoryMode.multipleChoice, StudyHistoryMode.spelling});
    records.add(session('spell-pass', StudyHistoryMode.spelling, success: true, hour: 12));
    expect(entries(records), isEmpty);
    expect(entries(records, cumulative: true).single.events.length, 2);
  });

  test('retry correct and skip remain pending with their history labels', () {
    final retry = entries([session('retry', StudyHistoryMode.spelling, success: true, retry: true)]).single;
    expect(retry.pendingModes, {StudyHistoryMode.spelling});
    expect(retry.events.single.label, '재도전 정답');
    final skip = entries([session('skip', StudyHistoryMode.spelling, skipped: true)]).single;
    expect(skip.events.single.label, '스킵 / 정답 확인');
    final restored = StudySessionRecord.fromMap(
      session('skip', StudyHistoryMode.spelling, skipped: true).toMap());
    expect(restored.answers.single.skipped, isTrue);
  });

  test('interrupted quiz keeps mistakes but never mixes another wordbook', () {
    final records = [session('interrupted', StudyHistoryMode.multipleChoice, completed: false),
      session('other', StudyHistoryMode.spelling, db: 'other.db')];
    expect(entries(records).single.pendingModes, {StudyHistoryMode.multipleChoice});
  });

  test('legacy pending flag and known prior mistake survive first clean review', () {
    expect(entries([], value: word.copyWith(pendingMcqReview: 1)).single.pendingModes,
      {StudyHistoryMode.multipleChoice});
    final clean = [session('clean', StudyHistoryMode.multipleChoice, success: true, prior: true)];
    expect(entries(clean), isEmpty);
    final archive = entries(clean, cumulative: true).single;
    expect(archive.historyModes, {StudyHistoryMode.multipleChoice});
    expect(archive.events, isEmpty); // Do not invent an old date or result.
  });

  test('out-of-order loading still uses the latest mode-specific outcome', () {
    expect(entries([session('new', StudyHistoryMode.spelling, success: true, hour: 12),
      session('old', StudyHistoryMode.spelling, hour: 9)]), isEmpty);
  });
}
