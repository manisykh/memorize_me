import 'dart:convert';

String? _stringOrNull(dynamic value) {
  if (value == null) return null;
  return value.toString().trim();
}

String _stringOrEmpty(dynamic value) {
  return _stringOrNull(value) ?? '';
}

class AiQuizResponse {
  final List<AiQuestion> questions;
  final int requestedQuestionCount;
  final int droppedDuplicateCount;

  AiQuizResponse({
    required this.questions,
    this.requestedQuestionCount = 0,
    this.droppedDuplicateCount = 0,
  });

  int get answerableQuestionCount {
    var count = 0;
    for (final question in questions) {
      if (question.type == 'reading_section') {
        count += question.questions?.length ?? 0;
      } else {
        count++;
      }
    }
    return count;
  }

  factory AiQuizResponse.fromJson(Map<String, dynamic> json) {
    final dynamic questionsData = json['questions'];
    List<AiQuestion> questionsList = [];
    if (questionsData is List) {
      questionsList =
          questionsData
              .whereType<Map<String, dynamic>>()
              .map(AiQuestion.fromJson)
              .toList();
    } else if (questionsData is Map) {
      questionsList = [AiQuestion.fromJson(Map<String, dynamic>.from(questionsData))];
    }
    return AiQuizResponse(questions: questionsList);
  }

  static AiQuizResponse parse(String jsonString) {
    final cleanedJson = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
    final decoded = jsonDecode(cleanedJson);
    return AiQuizResponse.fromJson(decoded);
  }
}

class AiQuestion {
  final String type;
  final String? passage, script, question, answer, explanation;
  final List<String>? options;
  final List<AiReadingSubQuestion>? questions;

  AiQuestion({
    required this.type,
    this.passage,
    this.script,
    this.question,
    this.options,
    this.answer,
    this.questions,
    this.explanation,
  });

  factory AiQuestion.fromJson(Map<String, dynamic> json) {
    var subQuestionsList = json['questions'] as List?;
    return AiQuestion(
      type: _stringOrEmpty(json['type']),
      passage: _stringOrNull(json['passage']),
      script: _stringOrNull(json['script']),
      question: _stringOrNull(json['question']),
      options: json['options'] is List
          ? (json['options'] as List).map(_stringOrEmpty).toList()
          : null,
      answer: _stringOrNull(json['answer']),
      explanation: _stringOrNull(json['explanation']),
      questions:
          subQuestionsList
              ?.whereType<Map<String, dynamic>>()
              .map(AiReadingSubQuestion.fromJson)
              .toList(),
    );
  }
}

class AiReadingSubQuestion {
  final String question;
  final List<String> options;
  final String answer;
  final String? explanation;

  AiReadingSubQuestion({
    required this.question,
    required this.options,
    required this.answer,
    this.explanation,
  });

  factory AiReadingSubQuestion.fromJson(Map<String, dynamic> json) {
    return AiReadingSubQuestion(
      question: _stringOrEmpty(json['question']),
      options:
          json['options'] is List
              ? (json['options'] as List).map(_stringOrEmpty).toList()
              : const [],
      answer: _stringOrEmpty(json['answer']),
      explanation: _stringOrNull(json['explanation']),
    );
  }
}
