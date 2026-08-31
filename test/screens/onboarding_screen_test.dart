import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/screens/onboarding_screen.dart';

void main() {
  Future<void> setPhoneSize(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('건너뛰기는 온보딩 완료 콜백을 호출한다', (tester) async {
    await setPhoneSize(tester);
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onFinished: () => completed = true),
      ),
    );

    await tester.tap(find.text('건너뛰기'));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('다음 버튼으로 마지막 페이지까지 이동하면 시작하기가 보인다', (tester) async {
    await setPhoneSize(tester);
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinished: () {})),
    );

    for (var index = 0; index < 5; index++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }

    expect(find.text('시작하기'), findsOneWidget);
    expect(find.text('이제 학습을 시작하세요'), findsOneWidget);
  });
}
