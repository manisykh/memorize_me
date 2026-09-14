import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/srs_service.dart';

void main() {
  final service = SrsService();
  final now = DateTime(2026, 9, 3);
  final initial = Word(id: 1, word: 'word', meaning: 'meaning', srsLevel: 3,
    incorrectCount: 2, correctStreak: 3, lastReviewedAt: '2026-09-01', nextReviewDate: '2026-09-03');

  test('clean first answer advances once and clears only its quiz mode', () {
    final updated = service.updateQuizSrs(word: initial.copyWith(pendingMcqReview: 1, pendingSpellingReview: 1),
      spelling: false, cleanCorrect: true, now: now);
    expect(updated.srsLevel, 4);
    expect(updated.nextReviewDate, '2026-09-18');
    expect(updated.pendingMcqReview, 0);
    expect(updated.pendingSpellingReview, 1);
    final again = service.updateQuizSrs(word: updated, spelling: false, cleanCorrect: true, now: now);
    expect(again.srsLevel, updated.srsLevel);
    expect(again.nextReviewDate, updated.nextReviewDate);
  });

  test('wrong, skip and retry success use one penalty from the question snapshot', () {
    final wrong = service.updateQuizSrs(word: initial, spelling: true, cleanCorrect: false, now: now);
    final retry = service.updateQuizSrs(word: initial, spelling: true, cleanCorrect: false, now: now);
    expect(wrong.srsLevel, 2);
    expect(wrong.nextReviewDate, '2026-09-03');
    expect(wrong.incorrectCount, 3);
    expect(retry.toMap(), wrong.toMap());
    expect(retry.pendingSpellingReview, 1);
    expect(retry.correctStreak, 0);
  });

  test('later clean retry session schedules tomorrow without same-day level inflation', () {
    final wrong = service.updateQuizSrs(word: initial, spelling: true, cleanCorrect: false, now: now);
    final clean = service.updateQuizSrs(word: wrong, spelling: true, cleanCorrect: true, now: now);
    expect(clean.srsLevel, wrong.srsLevel);
    expect(clean.nextReviewDate, '2026-09-04');
    expect(clean.pendingSpellingReview, 0);
  });

  test('a new word cannot go below zero and flashcards preserve quiz flags', () {
    final wrong = service.updateQuizSrs(word: Word(id: 1, word: 'new', meaning: 'new'),
      spelling: false, cleanCorrect: false, now: now);
    expect(wrong.srsLevel, 0);
    final card = service.updateWordSrs(word: wrong, source: SrsUpdateSource.flashcard, difficulty: SrsDifficulty.good);
    expect(card.pendingMcqReview, 1);
    expect(card.pendingSpellingReview, 0);
  });
}
