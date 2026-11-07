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
  final int difficultyMismatchCount;

  AiQuizResponse({
    required this.questions,
    this.requestedQuestionCount = 0,
    this.droppedDuplicateCount = 0,
    this.difficultyMismatchCount = 0,
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
      questionsList = [
        AiQuestion.fromJson(Map<String, dynamic>.from(questionsData)),
      ];
    }
    return AiQuizResponse(
      questions: questionsList,
      requestedQuestionCount:
          (json['requestedQuestionCount'] as num?)?.toInt() ?? 0,
      droppedDuplicateCount:
          (json['droppedDuplicateCount'] as num?)?.toInt() ?? 0,
      difficultyMismatchCount:
          (json['difficultyMismatchCount'] as num?)?.toInt() ?? 0,
    );
  }

  static AiQuizResponse parse(String jsonString) {
    final cleanedJson =
        jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
    final decoded = jsonDecode(cleanedJson);
    return AiQuizResponse.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
    'questions': questions.map((question) => question.toJson()).toList(),
    'requestedQuestionCount': requestedQuestionCount,
    'droppedDuplicateCount': droppedDuplicateCount,
    'difficultyMismatchCount': difficultyMismatchCount,
  };
}

class AiQuestion {
  final String type;
  final String? questionFormat,
      targetWord,
      grammarChapterId,
      passage,
      script,
      question,
      answer,
      explanation;
  final List<String>? options;
  final List<AiReadingSubQuestion>? questions;

  AiQuestion({
    required this.type,
    this.questionFormat,
    this.targetWord,
    this.grammarChapterId,
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
      questionFormat: _stringOrNull(json['questionFormat']),
      targetWord: _stringOrNull(json['targetWord']),
      grammarChapterId: _stringOrNull(json['chapterId']),
      passage: _stringOrNull(json['passage']),
      script: _stringOrNull(json['script']),
      question: _stringOrNull(json['question']),
      options:
          json['options'] is List
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

  Map<String, dynamic> toJson() => {
    'type': type,
    if (questionFormat != null) 'questionFormat': questionFormat,
    if (targetWord != null) 'targetWord': targetWord,
    if (grammarChapterId != null) 'chapterId': grammarChapterId,
    if (passage != null) 'passage': passage,
    if (script != null) 'script': script,
    if (question != null) 'question': question,
    if (options != null) 'options': options,
    if (answer != null) 'answer': answer,
    if (explanation != null) 'explanation': explanation,
    if (questions != null)
      'questions': questions!.map((question) => question.toJson()).toList(),
  };
}

class AiReadingSubQuestion {
  final String questionFormat;
  final String targetWord;
  final String question;
  final List<String> options;
  final String answer;
  final String? explanation;

  AiReadingSubQuestion({
    this.questionFormat = '',
    this.targetWord = '',
    required this.question,
    required this.options,
    required this.answer,
    this.explanation,
  });

  factory AiReadingSubQuestion.fromJson(Map<String, dynamic> json) {
    return AiReadingSubQuestion(
      questionFormat: _stringOrEmpty(json['questionFormat']),
      targetWord: _stringOrEmpty(json['targetWord']),
      question: _stringOrEmpty(json['question']),
      options:
          json['options'] is List
              ? (json['options'] as List).map(_stringOrEmpty).toList()
              : const [],
      answer: _stringOrEmpty(json['answer']),
      explanation: _stringOrNull(json['explanation']),
    );
  }

  Map<String, dynamic> toJson() => {
    'questionFormat': questionFormat,
    'targetWord': targetWord,
    'question': question,
    'options': options,
    'answer': answer,
    if (explanation != null) 'explanation': explanation,
  };
}
