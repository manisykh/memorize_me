enum StudyPlanStatus { active, paused }

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

  const StudyPlan({
    this.id,
    required this.wordbookId,
    required this.dbFileName,
    required this.wordbookName,
    required this.totalWords,
    required this.chunkSize,
    required this.dailyNewTarget,
    required this.startDate,
    this.status = StudyPlanStatus.active,
    required this.createdAt,
  });

  int get chunkCount {
    return estimatedTotalDays();
  }

  DateTime get startDateValue => DateTime.parse(startDate);

  int elapsedDays({DateTime? now}) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final start = DateTime(startDateValue.year, startDateValue.month, startDateValue.day);
    return today.difference(start).inDays + 1;
  }

  int unlockedNewLimit({DateTime? now}) {
    if (status != StudyPlanStatus.active || dailyNewTarget <= 0) return totalWords;
    final days = elapsedDays(now: now).clamp(1, totalWords).toInt();
    final unlocked = days * dailyNewTarget;
    return unlocked.clamp(0, totalWords).toInt();
  }

  int currentChunk({DateTime? now}) {
    final totalDays = estimatedTotalDays();
    if (totalDays <= 0) return 0;
    return elapsedDays(now: now).clamp(1, totalDays).toInt();
  }

  int estimatedTotalDays() {
    if (dailyNewTarget <= 0 || totalWords <= 0) return 0;
    return (totalWords / dailyNewTarget).ceil();
  }

  DateTime targetEndDate() {
    final totalDays = estimatedTotalDays();
    if (totalDays <= 1) return startDateValue;
    return startDateValue.add(Duration(days: totalDays - 1));
  }

  StudyPlan copyWith({
    int? id,
    int? wordbookId,
    String? dbFileName,
    String? wordbookName,
    int? totalWords,
    int? chunkSize,
    int? dailyNewTarget,
    String? startDate,
    StudyPlanStatus? status,
    String? createdAt,
  }) {
    return StudyPlan(
      id: id ?? this.id,
      wordbookId: wordbookId ?? this.wordbookId,
      dbFileName: dbFileName ?? this.dbFileName,
      wordbookName: wordbookName ?? this.wordbookName,
      totalWords: totalWords ?? this.totalWords,
      chunkSize: chunkSize ?? this.chunkSize,
      dailyNewTarget: dailyNewTarget ?? this.dailyNewTarget,
      startDate: startDate ?? this.startDate,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'wordbookId': wordbookId,
      'dbFileName': dbFileName,
      'wordbookName': wordbookName,
      'totalWords': totalWords,
      'chunkSize': chunkSize,
      'dailyNewTarget': dailyNewTarget,
      'startDate': startDate,
      'status': status.name,
      'createdAt': createdAt,
    };
  }

  factory StudyPlan.fromMap(Map<String, dynamic> map) {
    final statusName = map['status'] as String? ?? StudyPlanStatus.active.name;
    final status = StudyPlanStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => StudyPlanStatus.active,
    );

    return StudyPlan(
      id: map['id'] as int?,
      wordbookId: map['wordbookId'] as int?,
      dbFileName: map['dbFileName'] as String,
      wordbookName: map['wordbookName'] as String? ?? '단어장',
      totalWords: map['totalWords'] as int? ?? 0,
      chunkSize: map['chunkSize'] as int? ?? 20,
      dailyNewTarget: map['dailyNewTarget'] as int? ?? 20,
      startDate: map['startDate'] as String,
      status: status,
      createdAt: map['createdAt'] as String? ?? DateTime.now().toIso8601String(),
    );
  }
}
