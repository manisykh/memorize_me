import 'dart:convert';

class AiQuizResponse {
  final List<AiQuestion> questions;
  AiQuizResponse({required this.questions});

  factory AiQuizResponse.fromJson(Map<String, dynamic> json) {
    final dynamic questionsData = json['questions'];
    List<AiQuestion> questionsList = [];
    if (questionsData is List) {
      questionsList =
          questionsData.map((i) => AiQuestion.fromJson(i as Map<String, dynamic>)).toList();
    } else if (questionsData is Map) {
      questionsList = [AiQuestion.fromJson(questionsData as Map<String, dynamic>)];
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
      type: json['type'],
      passage: json['passage'],
      script: json['script'],
      question: json['question'],
      options: json['options'] != null ? List<String>.from(json['options']) : null,
      answer: json['answer'],
      explanation: json['explanation'],
      questions:
          subQuestionsList
              ?.map((i) => AiReadingSubQuestion.fromJson(i as Map<String, dynamic>))
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
      question: json['question'],
      options: List<String>.from(json['options']),
      answer: json['answer'],
      explanation: json['explanation'],
    );
  }
}
