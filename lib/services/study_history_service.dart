import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/study_plan_model.dart';
import '../models/study_session_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import 'database_service.dart';
import 'srs_service.dart';
import 'study_schedule_service.dart';

export '../models/study_session_model.dart';

class StudyModeHistory {
  final int sessionCount;
  final int latestTotal;
  final int latestSuccess;
  final int latestFailure;

  const StudyModeHistory({
    this.sessionCount = 0,
    this.latestTotal = 0,
    this.latestSuccess = 0,
    this.latestFailure = 0,
  });

  bool get hasSessions => sessionCount > 0;

  Map<String, dynamic> toJson() => {
    'sessionCount': sessionCount,
    'latestTotal': latestTotal,
    'latestSuccess': latestSuccess,
    'latestFailure': latestFailure,
  };

  factory StudyModeHistory.fromJson(Object? value) {
    if (value is! Map) return const StudyModeHistory();
    final map = value;
    int readInt(String key) => (map[key] as num?)?.toInt() ?? 0;
    return StudyModeHistory(
      sessionCount: readInt('sessionCount'),
      latestTotal: readInt('latestTotal'),
      latestSuccess: readInt('latestSuccess'),
      latestFailure: readInt('latestFailure'),
    );
  }
}

class WordbookStudyHistory {
  final StudyModeHistory flashcard;
  final StudyModeHistory multipleChoice;
  final StudyModeHistory spelling;

  const WordbookStudyHistory({
    this.flashcard = const StudyModeHistory(),
    this.multipleChoice = const StudyModeHistory(),
    this.spelling = const StudyModeHistory(),
  });

  bool get hasAnySessions =>
      flashcard.hasSessions || multipleChoice.hasSessions || spelling.hasSessions;

  StudyModeHistory forMode(StudyHistoryMode mode) {
    return switch (mode) {
      StudyHistoryMode.flashcard => flashcard,
      StudyHistoryMode.multipleChoice => multipleChoice,
      StudyHistoryMode.spelling => spelling,
    };
  }

  WordbookStudyHistory copyWithMode(
    StudyHistoryMode mode,
    StudyModeHistory history,
  ) {
    return WordbookStudyHistory(
      flashcard: mode == StudyHistoryMode.flashcard ? history : flashcard,
      multipleChoice:
          mode == StudyHistoryMode.multipleChoice ? history : multipleChoice,
      spelling: mode == StudyHistoryMode.spelling ? history : spelling,
    );
  }

  Map<String, dynamic> toJson() => {
    'flashcard': flashcard.toJson(),
    'multipleChoice': multipleChoice.toJson(),
    'spelling': spelling.toJson(),
  };

  factory WordbookStudyHistory.fromJson(Object? value) {
    if (value is! Map) return const WordbookStudyHistory();
    return WordbookStudyHistory(
      flashcard: StudyModeHistory.fromJson(value['flashcard']),
      multipleChoice: StudyModeHistory.fromJson(value['multipleChoice']),
      spelling: StudyModeHistory.fromJson(value['spelling']),
    );
  }
}

class StudyHistoryService extends ChangeNotifier {
  static final StudyHistoryService instance = StudyHistoryService._();
  static const _keyPrefix = 'study_history_v1_';
  final DatabaseService _database;
  final DateTime Function() _now;
  final Map<String, StudySessionRecord> _sessions = {};
  Future<void>? _loading;
  Future<void> _pendingWrite = Future<void>.value();
  final Map<String, Object> _failedWrites = {};
  Object? lastError;

  StudyHistoryService._() : _database = DatabaseService(), _now = DateTime.now;

  @visibleForTesting
  StudyHistoryService.forTesting(DatabaseService database, {DateTime Function()? now})
      : _database = database, _now = now ?? DateTime.now;

  Future<void> get pendingWrites => _pendingWrite;

  List<StudySessionRecord> get sessions => List.unmodifiable(_sessions.values);

  // Raw responses protect SRS and daily limits after an interrupted session.
  // Only completed sessions belong in the calendar and completion summaries.
  List<StudySessionRecord> get completedSessions =>
      sessions.where((session) => session.completed).toList();

  WordbookStudyHistory bundleHistory(StudyPlan plan, int bundle) {
    final matching = completedSessions.where((s) => s.dbFileName == plan.dbFileName &&
        s.planRevision == plan.revision && s.bundle == bundle).toList()
      ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
    var history = const WordbookStudyHistory();
    for (final session in matching) {
      final old = history.forMode(session.mode);
      history = history.copyWithMode(session.mode, StudyModeHistory(
        sessionCount: old.sessionCount + 1, latestTotal: session.answers.length,
        latestSuccess: session.successCount,
        latestFailure: session.answers.length - session.successCount,
      ));
    }
    return history;
  }

  Future<void> ensureLoaded() => _loading ??= _loadSessions().catchError((Object error) {
    _loading = null;
    throw error;
  });

  Future<void> _loadSessions() async {
    final rows = await _database.getStudySessions();
    for (final row in rows) {
      final session = StudySessionRecord.fromMap(row);
      _sessions.putIfAbsent(session.id, () => session);
    }
  }

  Future<WordbookStudyHistory> load(String dbFileName) async {
    await ensureLoaded();
    final preferences = await SharedPreferences.getInstance();
    final stored = preferences.getString('$_keyPrefix${Uri.encodeComponent(dbFileName)}');
    var history = const WordbookStudyHistory();
    if (stored != null) {
      try {
        history = WordbookStudyHistory.fromJson(jsonDecode(stored));
      } catch (_) {
        // Undated legacy totals must not be turned into invented calendar entries.
      }
    }
    for (final mode in StudyHistoryMode.values) {
      final matching = sessions.where((s) =>
          s.dbFileName == dbFileName && s.mode == mode && s.completed).toList()
        ..sort((a, b) => a.completedAt!.compareTo(b.completedAt!));
      if (matching.isEmpty) continue;
      final latest = matching.last;
      history = history.copyWithMode(mode, StudyModeHistory(
        sessionCount: history.forMode(mode).sessionCount + matching.length,
        latestTotal: latest.answers.length,
        latestSuccess: latest.successCount,
        latestFailure: latest.answers.length - latest.successCount,
      ));
    }
    return history;
  }

  Set<String> introducedKeys(String dbFileName, DateTime date) => {
    for (final session in sessions.where((s) => s.dbFileName == dbFileName))
      for (final answer in session.answersOn(date))
        if (answer.wasNew) answer.wordKey,
  };

  bool wasPreviouslyStudied(String dbFileName, String wordKey, String excludingSession) =>
      sessions.any((s) => s.id != excludingSession && s.dbFileName == dbFileName &&
          s.answers.any((a) => a.wordKey == wordKey));

  Set<String> studiedKeysOn(DateTime date, {String? dbFileName}) => {
    for (final session in sessions.where((s) => dbFileName == null || s.dbFileName == dbFileName))
      for (final answer in session.answersOn(date))
        '${session.dbFileName}:${answer.wordKey}',
  };

  StudySessionRecorder start({
    required Wordbook wordbook, required StudyHistoryMode mode,
    required int expectedCount, StudyPlan? plan,
  }) => StudySessionRecorder._(this, wordbook, mode, expectedCount, plan);

  Future<void> persist(StudySessionRecord session) {
    _sessions[session.id] = session;
    final operation = _pendingWrite.then((_) async {
      await ensureLoaded();
      await _database.saveStudySession(session.toMap());
      _failedWrites.remove(session.id);
      lastError = _failedWrites.values.firstOrNull;
      notifyListeners();
    }).catchError((Object error) {
      _failedWrites[session.id] = error;
      lastError = error;
      notifyListeners();
    });
    _pendingWrite = operation;
    return operation;
  }

  Future<void> retrySaving() async {
    await ensureLoaded();
    for (final session in sessions) {
      await persist(session);
    }
  }

  Future<void> forgetWordbook(String dbFileName) async {
    await _pendingWrite;
    for (final session in sessions.where((s) => s.dbFileName == dbFileName)) {
      _failedWrites.remove(session.id);
    }
    _sessions.removeWhere((_, session) => session.dbFileName == dbFileName);
    lastError = _failedWrites.values.firstOrNull;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('$_keyPrefix${Uri.encodeComponent(dbFileName)}');
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> planVersions() => _database.getStudyPlanVersions();
}

class StudySessionRecorder {
  static int _sequence = 0;
  final StudyHistoryService _service;
  final Wordbook wordbook;
  final StudyHistoryMode mode;
  final int expectedCount;
  final StudyPlan? plan;
  final DateTime startedAt;
  late final String id = '${startedAt.microsecondsSinceEpoch}-${_sequence++}';
  final Map<String, StudyAnswerRecord> _answers = {};
  DateTime? _completedAt;

  StudySessionRecorder._(StudyHistoryService service, this.wordbook, this.mode, this.expectedCount, this.plan)
      : _service = service, startedAt = service._now();

  void answer(Word word, {required bool success, String? nextReviewDate, bool retry = false,
      bool skipped = false}) {
    if (_completedAt != null) return;
    final key = StudyScheduleService.wordKey(word);
    final previous = _answers[key];
    final attempts = <StudyAttemptRecord>[
      ...?previous?.attemptLog,
      if (previous == null || retry) StudyAttemptRecord(at: _service._now(), success: success),
    ];
    _answers[key] = StudyAnswerRecord(
      wordKey: key, word: word.word, success: success,
      wasNew: previous?.wasNew ?? (SrsService().isNewWord(word) &&
          !_service.wasPreviouslyStudied(wordbook.dbFileName, key, id)),
      attempts: previous == null ? 1 : previous.attempts + (retry ? 1 : 0),
      at: _service._now(), attemptLog: attempts,
      nextReviewDate: nextReviewDate ?? previous?.nextReviewDate,
      skipped: skipped,
      hadPriorQuizMistake: mode == StudyHistoryMode.multipleChoice ? word.pendingMcqReview > 0 :
          mode == StudyHistoryMode.spelling && word.pendingSpellingReview > 0,
    );
    _save();
  }

  void undo(Word word) {
    if (_completedAt != null) return;
    _answers.remove(StudyScheduleService.wordKey(word));
    _save();
  }

  void complete() {
    if (_completedAt != null || _answers.isEmpty || _answers.length < expectedCount) return;
    _completedAt = _service._now();
    _save();
  }

  void _save() {
    _service.persist(StudySessionRecord(
      id: id, dbFileName: wordbook.dbFileName, wordbookName: wordbook.name,
      mode: mode, startedAt: startedAt, completedAt: _completedAt,
      expectedCount: expectedCount, answers: List.unmodifiable(_answers.values),
      planMode: plan?.mode, planRevision: plan?.revision,
      bundle: plan?.mode == StudyPlanMode.free ? plan?.currentChunk() : null,
    ));
  }
}
