import 'dart:math';
import 'dart:convert';

import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import 'srs_service.dart';

class StudyScheduleService {
  final SrsService srs = SrsService();

  StudyPlan? planOnDate({required String dbFileName, required DateTime date,
    required List<Map<String, dynamic>> versions, StudyPlan? fallback}) {
    final matching = versions.where((v) => v['dbFileName'] == dbFileName &&
        (v['effectiveFrom'] as String).compareTo(studyDateKey(date)) <= 0).toList()
      ..sort((a, b) {
        final day = (a['effectiveFrom'] as String).compareTo(b['effectiveFrom'] as String);
        return day == 0 ? (a['revision'] as int).compareTo(b['revision'] as int) : day;
      });
    if (matching.isNotEmpty) {
      return StudyPlan.fromMap(
        jsonDecode(matching.last['data'] as String) as Map<String, dynamic>);
    }
    return fallback != null && fallback.startDate.compareTo(studyDateKey(date)) <= 0 ? fallback : null;
  }

  static String wordKey(Word word) => word.id?.toString() ?? '${word.word}\u001f${word.meaning}';

  List<String> orderedKeys(List<Word> words, StudyPlan plan) {
    if (plan.wordOrder.isNotEmpty) return plan.wordOrder;
    final ordered = List<Word>.from(words)..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
    return ordered.map(wordKey).toList();
  }

  Set<String> bundleKeys(List<Word> words, StudyPlan plan, {int? bundle}) {
    final keys = orderedKeys(words, plan);
    if (keys.isEmpty || plan.chunkCount == 0) return {};
    final index = (bundle ?? plan.currentChunk()).clamp(1, plan.chunkCount).toInt() - 1;
    return keys.sublist(
      (keys.length * index / plan.chunkCount).floor(),
      (keys.length * (index + 1) / plan.chunkCount).floor(),
    ).toSet();
  }

  int adaptiveTarget(int dailyTarget, int reviewCount) {
    if (reviewCount >= max(30, dailyTarget * 3)) return 0;
    if (reviewCount >= dailyTarget * 2) return max(1, (dailyTarget * .25).ceil());
    if (reviewCount >= dailyTarget) return max(1, (dailyTarget * .5).ceil());
    if (reviewCount >= (dailyTarget * .6).ceil()) return max(1, (dailyTarget * .75).ceil());
    return dailyTarget;
  }

  List<Word> availableWords(List<Word> words, StudyPlan? plan, {
    DateTime? now, int introducedToday = 0,
  }) {
    if (plan == null || plan.status != StudyPlanStatus.active) return words;
    if (plan.mode == StudyPlanMode.free) {
      final keys = bundleKeys(words, plan);
      return words.where((w) => keys.contains(wordKey(w))).toList();
    }
    final keys = orderedKeys(words, plan);
    final byKey = {for (final w in words) wordKey(w): w};
    Set<String> available;
    if (plan.mode == StudyPlanMode.scheduled) {
      available = (plan.scheduleWordKeys ?? keys).take(plan.unlockedNewLimit(now: now)).toSet();
    } else {
      final due = srs.dueWords(words, baseDate: now).length;
      final target = max(0, adaptiveTarget(plan.dailyNewTarget, due) - introducedToday);
      available = keys.where((k) => byKey[k] != null && srs.isNewWord(byKey[k]!)).take(target).toSet();
    }
    return words.where((w) => !srs.isNewWord(w) || available.contains(wordKey(w))).toList();
  }

  Set<String> scheduledKeysOn(List<Word> words, StudyPlan plan, DateTime date) {
    if (plan.mode != StudyPlanMode.scheduled || plan.status != StudyPlanStatus.active) return {};
    final day = plan.elapsedDays(now: date) - 1;
    if (day < 0) return {};
    final keys = plan.scheduleWordKeys ?? orderedKeys(words, plan);
    final start = day * plan.dailyNewTarget;
    if (start >= keys.length) return {};
    return keys.skip(start).take(plan.dailyNewTarget).toSet();
  }

  List<Word> dueOn(List<Word> words, DateTime date) => words.where((word) {
    final due = srs.reviewDateFor(word);
    return due != null && studyDateKey(due) == studyDateKey(date);
  }).toList();

  List<Word> overdue(List<Word> words, DateTime today) => words.where((word) {
    final due = srs.reviewDateFor(word);
    return due != null && due.isBefore(studyDay(today));
  }).toList();
}
