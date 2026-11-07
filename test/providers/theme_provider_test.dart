import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/providers/theme_provider.dart';
import 'package:memorize_app/themes/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('저장된 테마가 없으면 밝은 테마로 시작한다', () async {
    SharedPreferences.setMockInitialValues({});
    final notifier = ThemeNotifier();

    await Future<void>.delayed(Duration.zero);

    expect(notifier.currentTheme, AppThemeType.lightGreen);
  });

  test('사용자가 저장한 테마는 그대로 복원한다', () async {
    SharedPreferences.setMockInitialValues({
      'selected_theme': AppThemeType.dark.name,
    });
    final notifier = ThemeNotifier();
    final loaded = Completer<void>();
    notifier.addListener(() {
      if (!loaded.isCompleted) loaded.complete();
    });

    await loaded.future;

    expect(notifier.currentTheme, AppThemeType.dark);
  });
}
