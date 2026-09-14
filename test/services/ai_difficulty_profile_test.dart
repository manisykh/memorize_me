import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/services/ai_difficulty_profile.dart';

void main() {
  test('7단계 난이도는 고유한 레이블과 점진적인 기준을 가진다', () {
    expect(AiDifficultyProfiles.values, hasLength(7));
    expect(AiDifficultyProfiles.labels.toSet(), hasLength(7));
    expect(AiDifficultyProfiles.forLevel(1).audience, contains('초등 저학년'));
    expect(AiDifficultyProfiles.forLevel(5).audience, contains('고등학교'));
    expect(AiDifficultyProfiles.forLevel(7).audience, contains('논문'));
    expect(AiDifficultyProfiles.forLevel(7).lexile, '1300L+');
    expect(AiDifficultyProfiles.forLevel(1).passageMinWords, 50);
    expect(AiDifficultyProfiles.forLevel(5).passageMinWords, 250);
    expect(AiDifficultyProfiles.forLevel(7).passageMaxWords, 750);
  });

  test('알 수 없는 레이블은 중급 기준으로 안전하게 대체한다', () {
    expect(AiDifficultyProfiles.fromLabel('unknown').level, 3);
  });
}
