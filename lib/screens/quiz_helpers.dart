import '../models/word_model.dart';
import '../providers/settings_provider.dart'; // import 추가

class QuizItem {
  final Word word;
  final SelfTestType questionType;
  QuizItem({required this.word, required this.questionType});
}

String getQuestionText(Word word, SelfTestType type) {
  if (type == SelfTestType.wordToMeaning) {
    return word.word;
  }
  if (type == SelfTestType.meaningToWord) {
    return word.meaning;
  }
  return '';
}

String getAnswerText(Word word, SelfTestType type) {
  return type == SelfTestType.wordToMeaning ? word.meaning : word.word;
}
