import 'dart:convert';
import 'dart:math';

enum StudyPlanStatus { active, paused }

enum StudyPlanMode { free, scheduled, reviewFirst }

extension StudyPlanModeLabel on StudyPlanMode {
  String get label => switch (this) {
    StudyPlanMode.free => '자유모드',
    StudyPlanMode.scheduled => '일정 달성 모드',
    StudyPlanMode.reviewFirst => '복습 우선 모드',
  };

  String get description => switch (this) {
    StudyPlanMode.free => '날짜에 쫓기지 않고 원하는 묶음을 직접 선택합니다.',
    StudyPlanMode.scheduled => '날짜별 새 단어 목표를 세우고 1회 학습 완료를 목표로 합니다.',
    StudyPlanMode.reviewFirst => '복습이 많으면 새 단어를 줄입니다. 쉬었던 날의 분량은 쌓이지 않습니다.',
  };
}

String studyDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime studyDay(DateTime date) => DateTime(date.year, date.month, date.day);

class StudyPlan {
  final int? id;
  final int? wordbookId;
  final String dbFileName;
  final String wordbookName;
  final int totalWords;
  final int chunkSize;
  final int dailyNewTarget;
  final String startDate;
  final StudyPlanStatus status;
  final String createdAt;
  final StudyPlanMode mode;
  final int bundleCount;
  final int selectedBundle;
  final int revision;
  final List<String> wordOrder;
  final List<String>? scheduleWordKeys;

  const StudyPlan({
    this.id, required this.wordbookId, required this.dbFileName,
    required this.wordbookName, required this.totalWords, required this.chunkSize,
    required this.dailyNewTarget, required this.startDate,
    this.status = StudyPlanStatus.active, required this.createdAt,
    this.mode = StudyPlanMode.scheduled, this.bundleCount = 0,
    this.selectedBundle = 1, this.revision = 1, this.wordOrder = const [],
    this.scheduleWordKeys,
  });

  int get chunkCount => totalWords <= 0 ? 0 :
      (bundleCount > 0 ? bundleCount : (totalWords / max(1, chunkSize)).ceil())
          .clamp(1, totalWords).toInt();
  int get scheduleTotal => scheduleWordKeys?.length ?? totalWords;
  DateTime get startDateValue => DateTime.parse(startDate);

  int elapsedDays({DateTime? now}) {
    final today = studyDay(now ?? DateTime.now());
    final start = startDateValue;
    // Calendar days must not change with daylight-saving offsets.
    return DateTime.utc(today.year, today.month, today.day)
        .difference(DateTime.utc(start.year, start.month, start.day)).inDays + 1;
  }

  int unlockedNewLimit({DateTime? now}) {
    if (status != StudyPlanStatus.active) return totalWords;
    if (mode == StudyPlanMode.free) {
      if (chunkCount == 0) return 0;
      return (totalWords * currentChunk() / chunkCount).floor() -
          (totalWords * (currentChunk() - 1) / chunkCount).floor();
    }
    if (mode == StudyPlanMode.reviewFirst) return min(dailyNewTarget, totalWords);
    return (max(0, elapsedDays(now: now)) * dailyNewTarget).clamp(0, scheduleTotal).toInt();
  }

  int currentChunk({DateTime? now}) {
    if (mode != StudyPlanMode.scheduled) {
      return chunkCount == 0 ? 0 : selectedBundle.clamp(1, chunkCount).toInt();
    }
    final days = estimatedTotalDays();
    return days <= 0 ? 0 : elapsedDays(now: now).clamp(1, days).toInt();
  }

  int estimatedTotalDays() => dailyNewTarget <= 0 || scheduleTotal <= 0
      ? 0 : (scheduleTotal / dailyNewTarget).ceil();

  DateTime targetEndDate() {
    final start = startDateValue;
    return DateTime(start.year, start.month, start.day + max(0, estimatedTotalDays() - 1));
  }

  String get progressLabel => switch (mode) {
    StudyPlanMode.free => '${currentChunk()}/$chunkCount 묶음',
    StudyPlanMode.scheduled => '${currentChunk()}/${estimatedTotalDays()}일차',
    StudyPlanMode.reviewFirst => '새 단어 하루 최대 $dailyNewTarget개',
  };

  String get scopeLabel => '${mode.label} · $progressLabel';

  StudyPlan copyWith({
    int? id, int? wordbookId, String? dbFileName, String? wordbookName,
    int? totalWords, int? chunkSize, int? dailyNewTarget, String? startDate,
    StudyPlanStatus? status, String? createdAt, StudyPlanMode? mode,
    int? bundleCount, int? selectedBundle, int? revision, List<String>? wordOrder,
    List<String>? scheduleWordKeys,
  }) => StudyPlan(
    id: id ?? this.id, wordbookId: wordbookId ?? this.wordbookId,
    dbFileName: dbFileName ?? this.dbFileName, wordbookName: wordbookName ?? this.wordbookName,
    totalWords: totalWords ?? this.totalWords, chunkSize: chunkSize ?? this.chunkSize,
    dailyNewTarget: dailyNewTarget ?? this.dailyNewTarget, startDate: startDate ?? this.startDate,
    status: status ?? this.status, createdAt: createdAt ?? this.createdAt,
    mode: mode ?? this.mode, bundleCount: bundleCount ?? this.bundleCount,
    selectedBundle: selectedBundle ?? this.selectedBundle, revision: revision ?? this.revision,
    wordOrder: wordOrder ?? this.wordOrder, scheduleWordKeys: scheduleWordKeys ?? this.scheduleWordKeys,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'wordbookId': wordbookId, 'dbFileName': dbFileName,
    'wordbookName': wordbookName, 'totalWords': totalWords, 'chunkSize': chunkSize,
    'dailyNewTarget': dailyNewTarget, 'startDate': startDate, 'status': status.name,
    'createdAt': createdAt, 'mode': mode.name, 'bundleCount': bundleCount,
    'selectedBundle': selectedBundle, 'revision': revision,
    'wordOrder': jsonEncode(wordOrder),
    'scheduleWordKeys': scheduleWordKeys == null ? null : jsonEncode(scheduleWordKeys),
  };

  factory StudyPlan.fromMap(Map<String, dynamic> map) {
    List<String> readKeys(String key) =>
        (jsonDecode(map[key] as String? ?? '[]') as List).cast<String>();
    return StudyPlan(
      id: map['id'] as int?, wordbookId: map['wordbookId'] as int?,
      dbFileName: map['dbFileName'] as String,
      wordbookName: map['wordbookName'] as String? ?? '단어장',
      totalWords: map['totalWords'] as int? ?? 0,
      chunkSize: map['chunkSize'] as int? ?? 20,
      dailyNewTarget: map['dailyNewTarget'] as int? ?? 20,
      startDate: map['startDate'] as String,
      status: StudyPlanStatus.values.firstWhere((v) => v.name == map['status'], orElse: () => StudyPlanStatus.active),
      createdAt: map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      mode: StudyPlanMode.values.firstWhere((v) => v.name == map['mode'], orElse: () => StudyPlanMode.scheduled),
      bundleCount: map['bundleCount'] as int? ?? 0,
      selectedBundle: map['selectedBundle'] as int? ?? 1,
      revision: map['revision'] as int? ?? 1,
      wordOrder: readKeys('wordOrder'),
      scheduleWordKeys: map['scheduleWordKeys'] == null ? null : readKeys('scheduleWordKeys'),
    );
  }
}
