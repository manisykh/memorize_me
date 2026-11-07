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
      MaterialApp(home: OnboardingScreen(onFinished: () => completed = true)),
    );

    await tester.tap(find.text('건너뛰기'));
    await tester.pump();

    expect(completed, isTrue);
  });

  testWidgets('다음 버튼으로 마지막 페이지까지 이동하면 시작 버튼이 보인다', (tester) async {
    await setPhoneSize(tester);
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(home: OnboardingScreen(onFinished: () => completed = true)),
    );

    for (var index = 0; index < 4; index++) {
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
    }

    expect(find.text('단어장 추가하고 시작'), findsOneWidget);
    expect(find.text('기본 단어장으로 둘러보기'), findsOneWidget);
    expect(find.text('이제 학습을'), findsOneWidget);
    expect(find.text('시작하세요'), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);

    await tester.tap(find.text('단어장 추가하고 시작'));
    await tester.pump();

    expect(completed, isTrue);
  });
}
