import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../themes/app_theme.dart';

class ThemeNotifier extends ChangeNotifier {
  final String _themeKey = "selected_theme";
  final String _levelKey = "eye_care_level";

  SharedPreferences? _prefs;
  late AppThemeType _currentTheme;
  late int _eyeCareLevel;

  ThemeNotifier() {
    _currentTheme = AppThemeType.lightGreen;
    _eyeCareLevel = 1;
    _loadFromPrefs();
  }

  AppThemeType get currentTheme => _currentTheme;
  int get eyeCareLevel => _eyeCareLevel;

  ThemeData getTheme() => AppTheme.appThemes[_currentTheme]!;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> _loadFromPrefs() async {
    await _initPrefs();
    String? themeName = _prefs!.getString(_themeKey);
    _currentTheme = AppThemeType.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => AppThemeType.lightGreen,
    );
    _eyeCareLevel = _prefs!.getInt(_levelKey) ?? 1;
    notifyListeners();
  }

  Future<void> _saveToPrefs() async {
    await _initPrefs();
    _prefs!.setString(_themeKey, _currentTheme.name);
    _prefs!.setInt(_levelKey, _eyeCareLevel);
  }

  void setTheme(AppThemeType themeType) {
    if (_currentTheme == themeType) return;
    _currentTheme = themeType;
    _saveToPrefs();
    notifyListeners();
  }

  void setEyeCareLevel(int level) {
    // ▼▼▼ [수정] 최대 레벨을 3에서 5로 변경 ▼▼▼
    if (_eyeCareLevel == level || level < 1 || level > 5) return;
    _eyeCareLevel = level;
    _saveToPrefs();
    notifyListeners();
  }
}
