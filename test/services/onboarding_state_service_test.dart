import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/services/onboarding_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const service = OnboardingStateService();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('첫 실행에는 온보딩을 표시한다', () async {
    expect(await service.shouldShow(), isTrue);
  });

  test('완료 상태를 저장하면 다음 실행부터 표시하지 않는다', () async {
    await service.markSeen();
    expect(await service.shouldShow(), isFalse);
  });
}
