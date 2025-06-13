import 'dart:math';
import '../models/word_model.dart';
import '../providers/settings_provider.dart';

class QuizItem {
  final Word word;
  final TestType questionType;
  QuizItem({required this.word, required this.questionType});
}

// 질문 텍스트 생성
String getQuestionText(Word word, TestType type) {
  if (type == TestType.wordToMeaning) {
    return word.word;
  }
  if (type == TestType.meaningToWord) {
    return word.meaning;
  }
  if (type == TestType.meaningToWordWithHint) {
    final hint = word.word.isNotEmpty ? '${word.word[0]}${'_' * (word.word.length - 1)}' : '';
    return '${word.meaning} ($hint)';
  }
  return '';
}

// 정답 텍스트 생성
String getAnswerText(Word word, TestType type) {
  return type == TestType.wordToMeaning ? word.meaning : word.word;
}
