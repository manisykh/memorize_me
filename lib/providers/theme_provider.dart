// providers/theme_provider.dart (수정 후)

import 'package:flutter/material.dart';

/// 앱에서 사용할 테마의 종류를 정의합니다.
enum AppThemeType {
  basic, // 기본 테마
  eyeCare, // 시력 보호 테마
}

class ThemeNotifier extends ChangeNotifier {
  AppThemeType _currentTheme = AppThemeType.basic;
  AppThemeType get currentTheme => _currentTheme;

  // 시력 보호 테마의 배경색 단계를 저장 (1, 2, 3)
  int _eyeCareLevel = 1;
  int get eyeCareLevel => _eyeCareLevel;

  void setTheme(AppThemeType themeType) {
    if (_currentTheme != themeType) {
      _currentTheme = themeType;
      notifyListeners();
    }
  }

  void setEyeCareLevel(int level) {
    if (_eyeCareLevel != level && level >= 1 && level <= 3) {
      _eyeCareLevel = level;
      notifyListeners();
    }
  }
}
