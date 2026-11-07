import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/ai_quiz_model.dart';
import '../models/saved_ai_quiz.dart';

class AiQuizLibraryService extends ChangeNotifier {
  static const _storageKey = 'saved_ai_quizzes_v1';

  final List<SavedAiQuiz> _items = [];
  bool _loaded = false;

  List<SavedAiQuiz> get items => List.unmodifiable(_items);
  bool get loaded => _loaded;

  Future<void> load() async {
    if (_loaded) return;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    _items.clear();
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List;
        _items.addAll(
          decoded
              .whereType<Map>()
              .map(
                (value) =>
                    SavedAiQuiz.fromJson(Map<String, dynamic>.from(value)),
              )
              .where((item) => item.id.isNotEmpty),
        );
      } catch (_) {
        _items.clear();
      }
    }
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _loaded = true;
    notifyListeners();
  }

  Future<SavedAiQuiz> save({
    required String title,
    required AiQuizResponse quiz,
    AiQuizCategory? category,
  }) async {
    await load();
    final now = DateTime.now();
    final item = SavedAiQuiz(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? '저장된 AI 퀴즈' : title.trim(),
      createdAt: now,
      quiz: quiz,
      category: category ?? classifyAiQuiz(quiz),
    );
    _items.insert(0, item);
    await _persist();
    notifyListeners();
    return item;
  }

  Future<SavedAiQuiz> merge({
    required List<SavedAiQuiz> quizzes,
    required String title,
  }) async {
    if (quizzes.length < 2) {
      throw ArgumentError('두 개 이상의 퀴즈를 선택해야 합니다.');
    }
    final questions = <AiQuestion>[];
    final seen = <String>{};
    for (final saved in quizzes) {
      for (final question in saved.quiz.questions) {
        final fingerprint = jsonEncode(question.toJson());
        if (seen.add(fingerprint)) questions.add(question);
      }
    }
    final merged = AiQuizResponse(
      questions: questions,
      requestedQuestionCount: questions.fold<int>(
        0,
        (total, question) =>
            total +
            (question.type == 'reading_section'
                ? question.questions?.length ?? 0
                : 1),
      ),
    );
    await load();
    final now = DateTime.now();
    final item = SavedAiQuiz(
      id: now.microsecondsSinceEpoch.toString(),
      title: title.trim().isEmpty ? '합친 AI 퀴즈' : title.trim(),
      createdAt: now,
      quiz: merged,
      category: classifyAiQuiz(merged),
      sourceTitles: quizzes.map((quiz) => quiz.title).toList(),
    );
    _items.insert(0, item);
    await _persist();
    notifyListeners();
    return item;
  }

  Future<void> delete(String id) async {
    await load();
    _items.removeWhere((item) => item.id == id);
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(_items.map((item) => item.toJson()).toList()),
    );
  }
}
