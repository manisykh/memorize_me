import '../models/word_model.dart';

enum SpellingAttemptResult { correctFirstTry, correctOnRetry, incorrect }

class QuizAnswerLogic {
  const QuizAnswerLogic._();

  static String normalizeSpelling(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[\s\-_]'), '');
  }

  static SpellingAttemptResult evaluateSpelling({
    required String input,
    required String answer,
    required bool isRetry,
  }) {
    final isCorrect = normalizeSpelling(input) == normalizeSpelling(answer);
    if (!isCorrect) return SpellingAttemptResult.incorrect;
    return isRetry
        ? SpellingAttemptResult.correctOnRetry
        : SpellingAttemptResult.correctFirstTry;
  }

  static bool isCorrectChoice({required Word selected, required Word answer}) {
    if (selected.id != null && answer.id != null) return selected.id == answer.id;
    return selected.word == answer.word && selected.meaning == answer.meaning;
  }

  static int? nextIndex({required int currentIndex, required int totalCount}) {
    if (totalCount <= 0 || currentIndex >= totalCount - 1) return null;
    return currentIndex + 1;
  }
}
