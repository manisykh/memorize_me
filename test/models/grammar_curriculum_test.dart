import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/grammar_curriculum.dart';
import 'package:memorize_app/models/word_model.dart';
import 'package:memorize_app/services/ai_service.dart';
import 'package:memorize_app/services/api_key_service.dart';

void main() {
  test('큰 주제는 모든 세부 챕터를 한 번씩 포함한다', () {
    for (final category in grammarCurriculum) {
      final topics = groupGrammarTopics(category);
      final groupedChapters = topics.values.expand((chapters) => chapters).toList();

      expect(groupedChapters.length, category.chapters.length);
      expect(groupedChapters.toSet().length, category.chapters.length);
      expect(topics.length, lessThan(category.chapters.length));
    }
  });

  test('중학교의 중복된 부정사·동명사 챕터는 하나씩만 남는다', () {
    final middle = grammarCurriculum.first;
    for (final title in [
      '명사적 용법의 to부정사',
      '형용사적 용법, 부사적 용법의 to부정사',
      '동명사의 역할',
    ]) {
      expect(middle.chapters.where((chapter) => chapter.title == title), hasLength(1));
    }
  });

  test('서로 다른 기존 그룹을 하나의 큰 주제로 선택할 수 있다', () {
    final middle = grammarCurriculum.first;
    final topics = groupGrammarTopics(middle);

    expect(
      topics['문장 구조·동사']!.map((chapter) => chapter.description).toSet(),
      containsAll(['be동사', '일반동사', '동사의 종류', '여러 가지 동사']),
    );
  });

  test('문법 레벨별 난도 범위는 공통 7단계 안에서 제한된다', () {
    expect(grammarCurriculum.first.minDifficulty, 1);
    expect(grammarCurriculum.first.maxDifficulty, 4);
    for (final category in grammarCurriculum) {
      expect(category.minDifficulty, greaterThanOrEqualTo(1));
      expect(category.maxDifficulty, lessThanOrEqualTo(7));
      expect(category.minDifficulty, lessThan(category.maxDifficulty));
    }
  });

  test('문법 레벨 밖의 난도는 API 키 조회 전에 거부한다', () async {
    final service = AiService(ApiKeyService());
    final middle = grammarCurriculum.first;

    await expectLater(
      service.generateGrammarQuiz(
        provider: AiProvider.gemini,
        modelName: 'unused',
        category: middle,
        chapters: [middle.chapters.first],
        questionCount: 5,
        difficulty: '전문가',
        includeExplanation: false,
        questionLanguage: 'English',
        selectedWords: [Word(word: 'study', meaning: '공부하다')],
      ),
      throwsA(isA<CustomApiException>()),
    );
  });
}
