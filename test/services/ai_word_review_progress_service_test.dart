import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/ai_word_review_progress_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final service = AiWordReviewProgressService();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('검토 기록은 단어장별로 유지된다', () async {
    final word = Word(id: 7, word: 'apple', meaning: '사과');
    await service.markReviewed('book_a.db', [word]);

    expect(await service.reviewedWordIds('book_a.db', [word]), {7});
    expect(await service.reviewedWordIds('book_b.db', [word]), isEmpty);
  });

  test('뜻이나 예문이 바뀌면 다시 미검토 상태가 된다', () async {
    final word = Word(id: 7, word: 'apple', meaning: '사과');
    await service.markReviewed('book.db', [word]);

    expect(await service.reviewedWordIds('book.db', [
      word.copyWith(meaning: '사과나무'),
    ]), isEmpty);
    expect(await service.reviewedWordIds('book.db', [
      word.copyWith(exampleSentence: 'I ate an apple.'),
    ]), isEmpty);
  });
}
