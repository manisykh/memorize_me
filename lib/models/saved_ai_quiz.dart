import 'ai_quiz_model.dart';

enum AiQuizCategory { vocabulary, grammar, reading, mixed }

extension AiQuizCategoryLabel on AiQuizCategory {
  String get label => switch (this) {
    AiQuizCategory.vocabulary => '어휘',
    AiQuizCategory.grammar => '문법',
    AiQuizCategory.reading => '독해',
    AiQuizCategory.mixed => '종합',
  };
}

AiQuizCategory classifyAiQuiz(AiQuizResponse quiz) {
  final categories = <AiQuizCategory>{};
  for (final question in quiz.questions) {
    categories.add(switch (question.type) {
      'vocabulary' => AiQuizCategory.vocabulary,
      'grammar' => AiQuizCategory.grammar,
      'reading_section' => AiQuizCategory.reading,
      _ => AiQuizCategory.mixed,
    });
  }
  return categories.length == 1 ? categories.single : AiQuizCategory.mixed;
}

class SavedAiQuiz {
  const SavedAiQuiz({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.quiz,
    required this.category,
    this.sourceTitles = const [],
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final AiQuizResponse quiz;
  final AiQuizCategory category;
  final List<String> sourceTitles;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
    'quiz': quiz.toJson(),
    'category': category.name,
    'sourceTitles': sourceTitles,
  };

  factory SavedAiQuiz.fromJson(Map<String, dynamic> json) {
    final quiz = AiQuizResponse.fromJson(
      Map<String, dynamic>.from(json['quiz'] as Map? ?? const {}),
    );
    final savedCategory = json['category']?.toString();
    return SavedAiQuiz(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '저장된 AI 퀴즈',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      quiz: quiz,
      category: AiQuizCategory.values.firstWhere(
        (category) => category.name == savedCategory,
        orElse: () => classifyAiQuiz(quiz),
      ),
      sourceTitles:
          (json['sourceTitles'] as List?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
    );
  }
}
