import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_key_service.dart';

class AiSettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  AiProvider _selectedProvider = AiProvider.gemini;
  // ▼▼▼ [수정] 기본 모델 이름을 최신 버전으로 변경 ▼▼▼
  String _selectedGeminiModel = 'gemini-2.5-pro';
  String _selectedGptModel = 'gpt-4o';

  AiSettingsProvider() {
    loadSettings();
  }

  AiProvider get selectedProvider => _selectedProvider;
  String get selectedModel =>
      _selectedProvider == AiProvider.gemini ? _selectedGeminiModel : _selectedGptModel;
  String get selectedGeminiModel => _selectedGeminiModel;
  String get selectedGptModel => _selectedGptModel;

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> loadSettings() async {
    await _initPrefs();
    _selectedProvider = AiProvider.values[_prefs!.getInt('ai_provider') ?? AiProvider.gemini.index];
    // ▼▼▼ [수정] 저장된 값이 없을 경우의 기본값도 최신 버전으로 변경 ▼▼▼
    _selectedGeminiModel = _prefs!.getString('gemini_model') ?? 'gemini-2.5-pro';
    _selectedGptModel = _prefs!.getString('gpt_model') ?? 'gpt-4o';
    notifyListeners();
  }

  Future<void> saveSettings() async {
    await _initPrefs();
    _prefs!.setInt('ai_provider', _selectedProvider.index);
    _prefs!.setString('gemini_model', _selectedGeminiModel);
    _prefs!.setString('gpt_model', _selectedGptModel);
    notifyListeners();
  }

  void setProvider(AiProvider provider) {
    if (_selectedProvider == provider) return;
    _selectedProvider = provider;
    saveSettings();
  }

  void setGeminiModel(String model) {
    if (_selectedGeminiModel == model) return;
    _selectedGeminiModel = model;
    saveSettings();
  }

  void setGptModel(String model) {
    if (_selectedGptModel == model) return;
    _selectedGptModel = model;
    saveSettings();
  }
}
