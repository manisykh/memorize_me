// lib/models/ai_quiz_model.dart (내용 확인)

import 'dart:convert';

class AiQuizResponse {
  final List<AiQuestion> questions;
  AiQuizResponse({required this.questions});

  factory AiQuizResponse.fromJson(Map<String, dynamic> json) {
    var list = json['questions'] as List;
    List<AiQuestion> questionsList = list.map((i) => AiQuestion.fromJson(i)).toList();
    return AiQuizResponse(questions: questionsList);
  }
}

class AiQuestion {
  final String type;
  final String? passage;
  final String? script;
  final String question;
  final List<String> options;
  final String answer;

  AiQuestion({
    required this.type,
    this.passage,
    this.script,
    required this.question,
    required this.options,
    required this.answer,
  });

  factory AiQuestion.fromJson(Map<String, dynamic> json) {
    return AiQuestion(
      type: json['type'],
      passage: json['passage'],
      script: json['script'],
      question: json['question'],
      options: List<String>.from(json['options']),
      answer: json['answer'],
    );
  }

  static AiQuizResponse parse(String jsonString) {
    final cleanedJson = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();
    return AiQuizResponse.fromJson(jsonDecode(cleanedJson));
  }
}
