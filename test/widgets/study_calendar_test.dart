import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:memorize_app/models/study_plan_model.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/models/wordbook_model.dart';
import 'package:memorize_app/providers/word_list_provider.dart';
import 'package:memorize_app/providers/wordbook_manager.dart';
import 'package:memorize_app/services/database_service.dart';
import 'package:memorize_app/services/study_history_service.dart';
import 'package:memorize_app/widgets/study_calendar.dart';

class CalendarDatabase extends DatabaseService {
  final List<Map<String, dynamic>> records = [];
  @override
  Future<List<Map<String, dynamic>>> getStudySessions() async => records;
  @override
  Future<List<Map<String, dynamic>>> getStudyPlanVersions() async => [];
  @override
  Future<void> saveStudySession(Map<String, dynamic> data) async {}
}

class CalendarManager extends WordbookManager {
  final List<Wordbook> books;
  bool failRead = false;
  CalendarManager(super.db, super.notifier, this.books);
  @override
  List<Wordbook> get wordbooks => books;
  @override
  Wordbook? get activeWordbook => books.first;
  @override
  StudyPlan? planFor(Wordbook? wordbook) => null;
  @override
  Future<List<Word>> getAllWordsFrom(Wordbook wordbook) async {
    if (failRead) throw StateError('read failed');
    return [
      Word(
        id: 1,
        word: 'sample',
        meaning: 'example',
        srsLevel: 1,
        nextReviewDate: studyDateKey(DateTime.now()),
      ),
    ];
  }
}

void main() {
  testWidgets(
    'calendar fits a narrow screen with larger text and filters wordbooks',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = CalendarDatabase();
      final notifier = WordListNotifier(db);
      final history = StudyHistoryService.forTesting(db);
      final books = [
        for (var i = 1; i <= 2; i++)
          Wordbook(
            id: i,
            name: 'Book $i',
            dbFileName: '$i.db',
            source: WordbookSource.localCsv,
          ),
      ];
      final manager = CalendarManager(db, notifier, books);
      // Read-only test: do not await fake-zone futures from teardown.
      addTearDown(() {
        manager.dispose();
        notifier.dispose();
        history.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<WordbookManager>.value(
          value: manager,
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: StudyCalendar(history: history),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('학습 달력'), findsOneWidget);
      expect(find.text('학습 완료'), findsOneWidget);
      expect(find.text('복습 예정'), findsOneWidget);
      expect(find.text('학습 계획'), findsOneWidget);
      expect(find.text('Book 1 · 전체 단어장'), findsOneWidget);
      expect(find.text('복습 1개'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('전체'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('전체 단어장 · 2개'), findsOneWidget);
      expect(find.text('복습 2개'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('다음 달'));
      await tester.tap(find.byTooltip('다음 달'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text('복습 2개'), findsOneWidget);
    },
  );

  testWidgets('calendar read failure offers a working retry', (tester) async {
    final db = CalendarDatabase();
    final notifier = WordListNotifier(db);
    final history = StudyHistoryService.forTesting(db);
    final manager = CalendarManager(db, notifier, [
      Wordbook(
        id: 1,
        name: 'Book',
        dbFileName: 'book.db',
        source: WordbookSource.localCsv,
      ),
    ])..failRead = true;
    addTearDown(() {
      manager.dispose();
      notifier.dispose();
      history.dispose();
    });
    await tester.pumpWidget(
      ChangeNotifierProvider<WordbookManager>.value(
        value: manager,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: StudyCalendar(history: history)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('학습 일정을 불러오지 못했습니다.'), findsOneWidget);
    manager.failRead = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );
    expect(find.text('Book · 전체 단어장'), findsOneWidget);
    expect(find.text('복습 1개'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'calendar lists completed sessions only, including after restart',
    (tester) async {
      final db = CalendarDatabase();
      final now = DateTime.now();
      for (final complete in [false, true]) {
        db.records.add(
          StudySessionRecord(
            id: '$complete',
            dbFileName: 'book.db',
            wordbookName: 'Book',
            mode: StudyHistoryMode.multipleChoice,
            startedAt: now,
            completedAt: complete ? now : null,
            expectedCount: 1,
            answers: [
              StudyAnswerRecord(
                wordKey: '1',
                word: 'sample',
                success: true,
                wasNew: false,
                at: now,
              ),
            ],
          ).toMap(),
        );
      }
      final notifier = WordListNotifier(db);
      final history = StudyHistoryService.forTesting(db);
      final manager = CalendarManager(db, notifier, [
        Wordbook(
          id: 1,
          name: 'Book',
          dbFileName: 'book.db',
          source: WordbookSource.localCsv,
        ),
      ]);
      addTearDown(() {
        manager.dispose();
        notifier.dispose();
        history.dispose();
      });
      await tester.pumpWidget(
        ChangeNotifierProvider<WordbookManager>.value(
          value: manager,
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StudyCalendar(history: history),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('^${studyDateKey(now)}')));
      await tester.pumpAndSettle();
      expect(find.text('완료한 학습'), findsOneWidget);
      expect(find.text('객관식 · 1회'), findsOneWidget);
      expect(find.textContaining('미완료 세션'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
