import '../models/word_model.dart';
import '../providers/settings_provider.dart'; // ▼▼▼ [수정] import 추가

class QuizItem {
  final Word word;
  final SelfTestType questionType; // ▼▼▼ [수정] SelfTestType으로 변경
  QuizItem({required this.word, required this.questionType});
}

// 질문 텍스트 생성
String getQuestionText(Word word, SelfTestType type) {
  // ▼▼▼ [수정]
  if (type == SelfTestType.wordToMeaning) {
    return word.word;
  }
  if (type == SelfTestType.meaningToWord) {
    return word.meaning;
  }
  return '';
}

// 정답 텍스트 생성
String getAnswerText(Word word, SelfTestType type) {
  // ▼▼▼ [수정]
  return type == SelfTestType.wordToMeaning ? word.meaning : word.word;
}
