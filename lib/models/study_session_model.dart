import 'study_plan_model.dart';

enum StudyHistoryMode { flashcard, multipleChoice, spelling }

extension StudyHistoryModeLabel on StudyHistoryMode {
  String get label => switch (this) {
    StudyHistoryMode.flashcard => '플래시카드',
    StudyHistoryMode.multipleChoice => '객관식 퀴즈',
    StudyHistoryMode.spelling => '스펠링 퀴즈',
  };
}

class StudyAttemptRecord {
  final DateTime at;
  final bool success;
  const StudyAttemptRecord({required this.at, required this.success});
  Map<String, dynamic> toMap() => {'at': at.toIso8601String(), 'success': success};
  factory StudyAttemptRecord.fromMap(Map<String, dynamic> map) => StudyAttemptRecord(
    at: DateTime.parse(map['at'] as String).toLocal(), success: map['success'] == true);
}

class StudyAnswerRecord {
  final String wordKey;
  final String word;
  final bool success;
  final bool wasNew;
  final int attempts;
  final DateTime at;
  final String? nextReviewDate;
  final List<StudyAttemptRecord> attemptLog;
  final bool skipped;
  final bool hadPriorQuizMistake;

  const StudyAnswerRecord({required this.wordKey, required this.word,
    required this.success, required this.wasNew, required this.at,
    this.attempts = 1, this.nextReviewDate, this.attemptLog = const [], this.skipped = false,
    this.hadPriorQuizMistake = false});

  bool get needsQuizReview => skipped || !success || attempts > 1 ||
      attemptLog.any((attempt) => !attempt.success);

  DateTime get firstStudiedAt => attemptLog.isEmpty ? at : attemptLog.first.at;

  StudyAnswerRecord? onDate(DateTime date) {
    if (attemptLog.isEmpty) return studyDateKey(at) == studyDateKey(date) ? this : null;
    final matching = attemptLog.where((a) => studyDateKey(a.at) == studyDateKey(date)).toList();
    if (matching.isEmpty) return null;
    return StudyAnswerRecord(wordKey: wordKey, word: word,
      success: matching.last.success, wasNew: wasNew && studyDateKey(firstStudiedAt) == studyDateKey(date),
      at: matching.last.at, attempts: matching.length, attemptLog: matching,
      nextReviewDate: nextReviewDate, skipped: skipped, hadPriorQuizMistake: hadPriorQuizMistake);
  }

  Map<String, dynamic> toMap() => {
    'wordKey': wordKey, 'word': word, 'success': success, 'wasNew': wasNew,
    'attempts': attempts, 'at': at.toIso8601String(), 'nextReviewDate': nextReviewDate,
    'attemptLog': attemptLog.map((a) => a.toMap()).toList(),
    'skipped': skipped,
    'hadPriorQuizMistake': hadPriorQuizMistake,
  };

  factory StudyAnswerRecord.fromMap(Map<String, dynamic> map) => StudyAnswerRecord(
    wordKey: map['wordKey'] as String, word: map['word'] as String,
    success: map['success'] == true, wasNew: map['wasNew'] == true,
    skipped: map['skipped'] == true,
    hadPriorQuizMistake: map['hadPriorQuizMistake'] == true,
    attempts: map['attempts'] as int? ?? 1,
    at: DateTime.parse(map['at'] as String).toLocal(), nextReviewDate: map['nextReviewDate'] as String?,
    attemptLog: (map['attemptLog'] as List? ?? const []).map((a) =>
      StudyAttemptRecord.fromMap(Map<String, dynamic>.from(a as Map))).toList(),
  );
}

class StudySessionRecord {
  final String id;
  final String dbFileName;
  final String wordbookName;
  final StudyHistoryMode mode;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int expectedCount;
  final StudyPlanMode? planMode;
  final int? planRevision;
  final int? bundle;
  final List<StudyAnswerRecord> answers;

  const StudySessionRecord({required this.id, required this.dbFileName,
    required this.wordbookName, required this.mode, required this.startedAt,
    required this.expectedCount, required this.answers, this.completedAt,
    this.planMode, this.planRevision, this.bundle});

  bool get completed => completedAt != null;
  int get successCount => answers.where((a) => a.success).length;
  List<StudyAnswerRecord> answersOn(DateTime date) =>
      answers.map((a) => a.onDate(date)).whereType<StudyAnswerRecord>().toList();

  Map<String, dynamic> toMap() => {
    'id': id, 'dbFileName': dbFileName, 'wordbookName': wordbookName,
    'mode': mode.name, 'startedAt': startedAt.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(), 'expectedCount': expectedCount,
    'planMode': planMode?.name, 'planRevision': planRevision, 'bundle': bundle,
    'answers': answers.map((a) => a.toMap()).toList(),
  };

  factory StudySessionRecord.fromMap(Map<String, dynamic> map) => StudySessionRecord(
    id: map['id'] as String, dbFileName: map['dbFileName'] as String,
    wordbookName: map['wordbookName'] as String,
    mode: StudyHistoryMode.values.byName(map['mode'] as String),
    startedAt: DateTime.parse(map['startedAt'] as String).toLocal(),
    completedAt: map['completedAt'] == null ? null : DateTime.parse(map['completedAt'] as String).toLocal(),
    expectedCount: map['expectedCount'] as int,
    planMode: map['planMode'] == null ? null : StudyPlanMode.values.byName(map['planMode'] as String),
    planRevision: map['planRevision'] as int?, bundle: map['bundle'] as int?,
    answers: (map['answers'] as List).map((a) => StudyAnswerRecord.fromMap(Map<String, dynamic>.from(a as Map))).toList(),
  );
}
