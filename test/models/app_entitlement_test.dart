import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/app_entitlement.dart';

void main() {
  test('출시 무료 모드에서는 모든 기능을 사용할 수 있다', () {
    expect(
      canUseAppFeature(
        feature: AppFeature.advancedAiOptions,
        isLaunchFree: true,
        entitlement: const EntitlementSnapshot(),
      ),
      isTrue,
    );
  });

  test('유료 전환 후 Free 사용자는 영구 무료 기능만 사용할 수 있다', () {
    const free = EntitlementSnapshot(plan: AppPlan.free);
    expect(
      canUseAppFeature(
        feature: AppFeature.srsReview,
        isLaunchFree: false,
        entitlement: free,
      ),
      isTrue,
    );
    expect(
      canUseAppFeature(
        feature: AppFeature.customPrompts,
        isLaunchFree: false,
        entitlement: free,
      ),
      isFalse,
    );
  });

  test('Founding과 Pro 사용자는 전체 기능을 사용할 수 있다', () {
    for (final plan in [AppPlan.founding, AppPlan.pro]) {
      expect(
        canUseAppFeature(
          feature: AppFeature.cloudSync,
          isLaunchFree: false,
          entitlement: EntitlementSnapshot(plan: plan),
        ),
        isTrue,
      );
    }
  });

  test('알 수 없는 서버 플랜은 Free로 안전하게 처리한다', () {
    expect(EntitlementSnapshot.parsePlan('unknown'), AppPlan.free);
  });
}
