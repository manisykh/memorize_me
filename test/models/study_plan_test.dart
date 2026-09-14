import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/study_plan_model.dart';

void main() {
  final legacy = <String, dynamic>{
    'id': 1, 'wordbookId': 2, 'dbFileName': 'book.db', 'wordbookName': 'Book',
    'totalWords': 25, 'chunkSize': 10, 'dailyNewTarget': 10,
    'startDate': '2026-09-01', 'createdAt': '2026-09-01', 'status': 'active',
  };

  test('legacy plans remain scheduled with their original dates and limits', () {
    final plan = StudyPlan.fromMap(legacy);
    expect(plan.mode, StudyPlanMode.scheduled);
    expect(plan.unlockedNewLimit(now: DateTime(2026, 9, 2)), 20);
    expect(plan.targetEndDate(), DateTime(2026, 9, 3));
    expect(plan.wordOrder, isEmpty);
    expect(plan.scheduleWordKeys, isNull);
  });

  test('all mode settings and stable word ordering survive serialization', () {
    for (final mode in StudyPlanMode.values) {
      final original = StudyPlan.fromMap(legacy).copyWith(mode: mode, bundleCount: 4,
        selectedBundle: 3, revision: 4, wordOrder: ['3', '1', '2'], scheduleWordKeys: ['1', '2']);
      final restored = StudyPlan.fromMap(original.toMap());
      expect(restored.toMap(), original.toMap());
      expect(restored.mode, mode);
    }
  });

  test('empty remaining schedule has no target work and selected bundle is clamped', () {
    final plan = StudyPlan.fromMap(legacy).copyWith(scheduleWordKeys: []);
    expect(plan.estimatedTotalDays(), 0);
    expect(plan.unlockedNewLimit(now: DateTime(2026, 9, 2)), 0);
    expect(plan.copyWith(mode: StudyPlanMode.free, bundleCount: 2, selectedBundle: 99).currentChunk(), 2);
  });

  test('calendar days cross month/year boundaries without time-of-day drift', () {
    final plan = StudyPlan.fromMap(legacy).copyWith(startDate: '2026-12-31');
    expect(plan.elapsedDays(now: DateTime(2027, 1, 1, 23, 59)), 2);
    expect(plan.targetEndDate(), DateTime(2027, 1, 2));
  });
}
