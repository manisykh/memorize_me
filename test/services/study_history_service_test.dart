import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/models/wordbook_model.dart';
import 'package:memorize_app/models/study_plan_model.dart';
import 'package:memorize_app/services/database_service.dart';
import 'package:memorize_app/services/study_history_service.dart';

class MemoryStudyDatabase extends DatabaseService {
  final Map<String, Map<String, dynamic>> records = {};
  bool failWrites = false;
  @override
  Future<List<Map<String, dynamic>>> getStudySessions() async => records.values.toList();
  @override
  Future<void> saveStudySession(Map<String, dynamic> data) async {
    if (failWrites) throw StateError('simulated write failure');
    records[data['id'] as String] = jsonDecode(jsonEncode(data)) as Map<String, dynamic>;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MemoryStudyDatabase database;
  late StudyHistoryService service;
  late DateTime now;
  final book = Wordbook(id: 1, name: 'Book', dbFileName: 'book.db', source: WordbookSource.localCsv);
  final word = Word(id: 1, word: 'word', meaning: 'meaning');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    database = MemoryStudyDatabase();
    now = DateTime(2026, 9, 2, 10);
    service = StudyHistoryService.forTesting(database, now: () => now);
  });
  tearDown(() async { await service.pendingWrites; service.dispose(); });

  StudySessionRecorder start({StudyHistoryMode mode = StudyHistoryMode.spelling, int expectedCount = 1}) =>
    service.start(wordbook: book, mode: mode, expectedCount: expectedCount);

  test('partial sessions persist without increasing completed-session totals', () async {
    final recorder = start(expectedCount: 2);
    recorder.answer(word, success: false, nextReviewDate: '2026-09-02');
    recorder.complete();
    await service.pendingWrites;
    final record = service.sessions.single;
    expect(record.completed, isFalse);
    expect(service.completedSessions, isEmpty);
    expect(record.answers.single.nextReviewDate, '2026-09-02');
    expect((await service.load(book.dbFileName)).spelling.sessionCount, 0);
    expect(service.introducedKeys(book.dbFileName, now), {'1'});
  });

  test('retry and completion are upserts, answer reveal does not add attempts', () async {
    final recorder = start();
    recorder.answer(word, success: false);
    recorder.answer(word, success: false);
    recorder.answer(word, success: true, retry: true);
    recorder.complete();
    recorder.complete();
    await service.pendingWrites;
    expect(database.records.length, 1);
    final summary = (await service.load(book.dbFileName)).spelling;
    expect(summary.sessionCount, 1);
    expect(summary.latestSuccess, 1);
    expect(service.sessions.single.answers.single.attempts, 2);
  });

  test('cross-midnight retry keeps both dates and counts first exposure once', () async {
    now = DateTime(2026, 9, 2, 23, 58);
    final recorder = start();
    now = DateTime(2026, 9, 2, 23, 59);
    recorder.answer(word, success: false);
    now = DateTime(2026, 9, 3, 0, 1);
    recorder.answer(word, success: true, retry: true);
    recorder.complete();
    await service.pendingWrites;
    final record = StudySessionRecord.fromMap(database.records.values.single);
    expect(record.startedAt.minute, 58);
    expect(record.answersOn(DateTime(2026, 9, 2)).single.success, isFalse);
    expect(record.answersOn(DateTime(2026, 9, 3)).single.success, isTrue);
    expect(record.answersOn(now).single.attempts, 1);
    expect(service.introducedKeys(book.dbFileName, DateTime(2026, 9, 2)), {'1'});
    expect(service.introducedKeys(book.dbFileName, now), isEmpty);
  });

  test('same word in multiple modes counts once per day but sessions remain distinct', () async {
    final first = start(mode: StudyHistoryMode.flashcard);
    first.answer(word, success: true);
    first.complete();
    final second = start(mode: StudyHistoryMode.multipleChoice);
    second.answer(word, success: false);
    second.complete();
    await service.pendingWrites;
    expect(service.studiedKeysOn(now).length, 1);
    expect(service.introducedKeys(book.dbFileName, now).length, 1);
    expect(service.sessions.length, 2);
    expect((await service.load(book.dbFileName)).multipleChoice.sessionCount, 1);
  });

  test('undo removes answer and first exposure, completion cannot be counted twice', () async {
    final recorder = start(mode: StudyHistoryMode.flashcard);
    recorder.answer(word, success: true);
    recorder.undo(word);
    recorder.complete();
    await service.pendingWrites;
    expect(service.studiedKeysOn(now), isEmpty);
    expect(service.introducedKeys(book.dbFileName, now), isEmpty);
    expect((await service.load(book.dbFileName)).flashcard.sessionCount, 0);
  });

  test('legacy totals stay undated and add new completed sessions', () async {
    SharedPreferences.setMockInitialValues({
      'study_history_v1_book.db': jsonEncode({'spelling': {
        'sessionCount': 3, 'latestTotal': 10, 'latestSuccess': 8, 'latestFailure': 2,
      }}),
    });
    expect((await service.load(book.dbFileName)).spelling.sessionCount, 3);
    expect(service.sessions, isEmpty);
    final recorder = start();
    recorder.answer(word, success: true);
    recorder.complete();
    await service.pendingWrites;
    final history = (await service.load(book.dbFileName)).spelling;
    expect(history.sessionCount, 4);
    expect(history.latestTotal, 1);
  });

  test('stored sessions restore without duplicating counts', () async {
    final recorder = start();
    recorder.answer(word, success: true);
    recorder.complete();
    await service.pendingWrites;
    final restored = StudyHistoryService.forTesting(database);
    expect((await restored.load(book.dbFileName)).spelling.sessionCount, 1);
    await restored.ensureLoaded();
    expect(restored.sessions.length, 1);
    expect(restored.completedSessions.length, 1);
    restored.dispose();
  });

  test('bundle totals separate bundles and plan revisions, and omit unfinished sessions', () async {
    final plan = StudyPlan(wordbookId: 1, dbFileName: 'book.db', wordbookName: 'Book',
      totalWords: 10, chunkSize: 5, dailyNewTarget: 5, startDate: '2026-09-03',
      createdAt: '2026-09-03', mode: StudyPlanMode.free, bundleCount: 2);
    void record(StudyPlan value, {bool complete = true}) {
      final recorder = service.start(wordbook: book, mode: StudyHistoryMode.flashcard,
        expectedCount: 1, plan: value);
      recorder.answer(word, success: true);
      if (complete) recorder.complete();
    }
    record(plan);
    record(plan.copyWith(selectedBundle: 2));
    record(plan.copyWith(revision: 2));
    record(plan, complete: false);
    await service.pendingWrites;
    expect(service.bundleHistory(plan, 1).flashcard.sessionCount, 1);
    expect(service.bundleHistory(plan, 2).flashcard.sessionCount, 1);
    expect((await service.load('book.db')).flashcard.sessionCount, 3);
  });

  test('failed writes stay retryable and a different successful session does not hide the error', () async {
    database.failWrites = true;
    final first = start();
    first.answer(word, success: false);
    await service.pendingWrites;
    expect(service.lastError, isNotNull);
    database.failWrites = false;
    final second = start();
    second.answer(Word(id: 2, word: 'second', meaning: 'meaning'), success: true);
    await service.pendingWrites;
    expect(service.lastError, isNotNull);
    await service.retrySaving();
    expect(service.lastError, isNull);
    expect(database.records.length, 2);
  });
}
