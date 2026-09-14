import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/study_plan_model.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/study_schedule_service.dart';

StudyPlan planFor(List<Word> words, {StudyPlanMode mode = StudyPlanMode.free, int bundles = 10}) => StudyPlan(
  wordbookId: 1, dbFileName: 'test.db', wordbookName: 'Test', totalWords: words.length,
  chunkSize: 10, dailyNewTarget: 10, startDate: '2026-09-01', createdAt: '2026-09-01',
  mode: mode, bundleCount: bundles, wordOrder: words.map(StudyScheduleService.wordKey).toList(),
);

List<Word> makeWords(int count) => List.generate(count,
  (i) => Word(id: i + 1, word: 'word${i + 1}', meaning: 'meaning${i + 1}'));

void main() {
  final service = StudyScheduleService();
  final today = DateTime(2026, 9, 2);

  test('uneven free bundles partition every word exactly once', () {
    final words = makeWords(1001);
    final plan = planFor(words);
    final assigned = <String>[];
    for (var bundle = 1; bundle <= 10; bundle++) {
      final keys = service.bundleKeys(words, plan, bundle: bundle);
      expect(keys.length, anyOf(100, 101));
      assigned.addAll(keys);
    }
    expect(assigned.length, 1001);
    expect(assigned.toSet().length, 1001);
  });

  test('free scope changes only on manual selection, not elapsed days', () {
    final words = makeWords(100);
    final plan = planFor(words).copyWith(selectedBundle: 2);
    expect(service.availableWords(words, plan, now: today).map((w) => w.id),
      orderedEquals(List.generate(10, (i) => i + 11)));
    expect(service.availableWords(words, plan, now: DateTime(2027, 9, 2)).map((w) => w.id),
      service.availableWords(words, plan, now: today).map((w) => w.id));
  });

  test('deleting a word does not move the next bundle, new words wait for plan editing', () {
    final words = makeWords(20);
    final plan = planFor(words, bundles: 2).copyWith(selectedBundle: 2);
    final changed = [...words.where((w) => w.id != 2), Word(id: 21, word: 'added', meaning: 'new')];
    expect(service.availableWords(changed, plan).map((w) => w.id),
      orderedEquals(List.generate(10, (i) => i + 11)));
  });

  test('scheduled mode unlocks cumulatively and uses exact daily target slices', () {
    final words = makeWords(25);
    final plan = planFor(words, mode: StudyPlanMode.scheduled);
    expect(service.availableWords(words, plan, now: DateTime(2026, 8, 31)), isEmpty);
    expect(service.availableWords(words, plan, now: today).length, 20);
    expect(service.availableWords(words, plan, now: DateTime(2026, 9, 10)).length, 25);
    expect(service.scheduledKeysOn(words, plan, DateTime(2026, 9, 3)), {'21', '22', '23', '24', '25'});
    expect(service.scheduledKeysOn(words, plan, DateTime(2026, 9, 4)), isEmpty);
  });

  test('replanning starts remaining new words without hiding learned SRS words', () {
    final words = makeWords(30);
    words[0] = words[0].copyWith(srsLevel: 2, nextReviewDate: '2026-09-02');
    final plan = planFor(words, mode: StudyPlanMode.scheduled).copyWith(
      startDate: '2026-09-02', scheduleWordKeys: words.skip(1).map(StudyScheduleService.wordKey).toList());
    final available = service.availableWords(words, plan, now: today);
    expect(available.length, 11);
    expect(available.first.id, 1);
    expect(service.scheduledKeysOn(words, plan, today), isNot(contains('1')));
    expect(words.first.srsLevel, 2);
  });

  test('review-first allowance does not accumulate after missed days', () {
    final words = makeWords(100);
    final plan = planFor(words, mode: StudyPlanMode.reviewFirst);
    expect(service.availableWords(words, plan, now: today, introducedToday: 3).length, 7);
    expect(service.availableWords(words, plan, now: DateTime(2027, 1, 1)).length, 10);
    expect(service.availableWords(words, plan, now: today, introducedToday: 10), isEmpty);
  });

  test('review-first reduces new words but preserves all learned words', () {
    final words = makeWords(50);
    for (var i = 0; i < 30; i++) {
      words[i] = words[i].copyWith(srsLevel: 1, nextReviewDate: '2026-09-01');
    }
    final plan = planFor(words, mode: StudyPlanMode.reviewFirst);
    final available = service.availableWords(words, plan, now: today);
    expect(available.length, 30);
    expect(available.every((w) => w.srsLevel == 1), isTrue);
    expect(service.adaptiveTarget(10, 6), 8);
    expect(service.adaptiveTarget(10, 10), 5);
    expect(service.adaptiveTarget(10, 20), 3);
  });

  test('overdue and exact SRS dates are disjoint, including outside free scope', () {
    final words = makeWords(20);
    words[18] = words[18].copyWith(srsLevel: 1, nextReviewDate: '2026-09-01');
    words[19] = words[19].copyWith(srsLevel: 1, nextReviewDate: '2026-09-02');
    final plan = planFor(words, bundles: 2);
    expect(service.availableWords(words, plan).length, 10);
    expect(service.overdue(words, today).single.id, 19);
    expect(service.dueOn(words, today).single.id, 20);
    expect(service.dueOn(words, DateTime(2026, 9, 3)), isEmpty);
  });

  test('no plan and paused plan preserve full wordbook scope', () {
    final words = makeWords(20);
    expect(service.availableWords(words, null), words);
    expect(service.availableWords(words, planFor(words).copyWith(status: StudyPlanStatus.paused)), words);
  });

  test('plan revisions preserve past targets across replanning and removal', () {
    final words = makeWords(100);
    final original = planFor(words, mode: StudyPlanMode.scheduled);
    final revised = original.copyWith(revision: 2, startDate: '2026-09-03', dailyNewTarget: 20);
    final removed = revised.copyWith(revision: 3, status: StudyPlanStatus.paused);
    final versions = [
      for (final entry in [(original, '2026-09-01'), (revised, '2026-09-03'), (removed, '2026-09-05')])
        <String, dynamic>{'dbFileName': 'test.db', 'revision': entry.$1.revision,
          'effectiveFrom': entry.$2, 'data': jsonEncode(entry.$1.toMap())},
    ];
    final past = service.planOnDate(dbFileName: 'test.db', date: today, versions: versions)!;
    expect(past.dailyNewTarget, 10);
    expect(service.scheduledKeysOn(words, past, today).length, 10);
    expect(service.planOnDate(dbFileName: 'test.db', date: DateTime(2026, 9, 4), versions: versions)!.dailyNewTarget, 20);
    expect(service.planOnDate(dbFileName: 'test.db', date: DateTime(2026, 9, 5), versions: versions)!.status, StudyPlanStatus.paused);
    expect(service.planOnDate(dbFileName: 'test.db', date: DateTime(2026, 8, 31), versions: versions), isNull);
  });
}
