import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_key_service.dart';

class AiSettingsProvider extends ChangeNotifier {
  SharedPreferences? _prefs;

  AiProvider _selectedProvider = AiProvider.gemini;
  final Map<AiProvider, String> _selectedModels = {};
  String _customOpenAiEndpoint = '';
  bool _autoFallbackEnabled = false;
  List<AiProvider> _fallbackOrder = List<AiProvider>.from(AiProvider.values);

  AiSettingsProvider() {
    loadSettings();
  }

  AiProvider get selectedProvider => _selectedProvider;
  String get selectedModel => selectedModelFor(_selectedProvider);
  String? get selectedEndpoint =>
      _selectedProvider == AiProvider.customOpenAI ? _customOpenAiEndpoint.trim() : null;
  String get customOpenAiEndpoint => _customOpenAiEndpoint;
  bool get autoFallbackEnabled => _autoFallbackEnabled;
  List<AiProvider> get fallbackOrder => List.unmodifiable(_fallbackOrder);

  String selectedModelFor(AiProvider provider) {
    return _selectedModels[provider] ?? provider.defaultModel;
  }

  String? endpointFor(AiProvider provider) {
    return provider == AiProvider.customOpenAI ? _customOpenAiEndpoint.trim() : null;
  }

  Future<void> _initPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  Future<void> loadSettings() async {
    await _initPrefs();
    _selectedProvider = _loadSelectedProvider();

    for (final provider in AiProvider.values) {
      final storedModel = _prefs!.getString('ai_model_${provider.name}');
      _selectedModels[provider] = storedModel ?? _legacyModelFor(provider) ?? provider.defaultModel;
    }

    _customOpenAiEndpoint = _prefs!.getString('custom_openai_endpoint') ?? '';
    _autoFallbackEnabled = _prefs!.getBool('ai_auto_fallback_enabled') ?? false;
    _fallbackOrder = _loadFallbackOrder();
    notifyListeners();
  }

  List<AiProvider> _loadFallbackOrder() {
    final stored = _prefs!.getStringList('ai_fallback_order') ?? const <String>[];
    final ordered = <AiProvider>[];
    for (final name in stored) {
      for (final provider in AiProvider.values) {
        if (provider.name == name && !ordered.contains(provider)) {
          ordered.add(provider);
        }
      }
    }
    for (final provider in AiProvider.values) {
      if (!ordered.contains(provider)) ordered.add(provider);
    }
    return ordered;
  }

  AiProvider _loadSelectedProvider() {
    final storedName = _prefs!.getString('ai_provider_name');
    if (storedName != null) {
      for (final provider in AiProvider.values) {
        if (provider.name == storedName) return provider;
      }
    }

    final legacyIndex = _prefs!.getInt('ai_provider');
    if (legacyIndex != null && legacyIndex >= 0 && legacyIndex < AiProvider.values.length) {
      return AiProvider.values[legacyIndex];
    }
    return AiProvider.gemini;
  }

  String? _legacyModelFor(AiProvider provider) {
    switch (provider) {
      case AiProvider.gemini:
        return _prefs!.getString('gemini_model');
      case AiProvider.openAI:
        return _prefs!.getString('gpt_model');
      case AiProvider.anthropic:
      case AiProvider.groq:
      case AiProvider.openRouter:
      case AiProvider.mistral:
      case AiProvider.deepSeek:
      case AiProvider.xAI:
      case AiProvider.perplexity:
      case AiProvider.together:
      case AiProvider.fireworks:
      case AiProvider.customOpenAI:
        return null;
    }
  }

  Future<void> saveSettings() async {
    await _initPrefs();
    await _prefs!.setString('ai_provider_name', _selectedProvider.name);
    await _prefs!.setInt('ai_provider', _selectedProvider.index);
    await _prefs!.setString('custom_openai_endpoint', _customOpenAiEndpoint);
    await _prefs!.setBool('ai_auto_fallback_enabled', _autoFallbackEnabled);
    await _prefs!.setStringList(
      'ai_fallback_order',
      _fallbackOrder.map((provider) => provider.name).toList(),
    );
    for (final entry in _selectedModels.entries) {
      await _prefs!.setString('ai_model_${entry.key.name}', entry.value);
    }
    notifyListeners();
  }

  void setProvider(AiProvider provider) {
    if (_selectedProvider == provider) return;
    _selectedProvider = provider;
    saveSettings();
  }

  void setModel(AiProvider provider, String model) {
    final trimmed = model.trim();
    if (trimmed.isEmpty || _selectedModels[provider] == trimmed) return;
    _selectedModels[provider] = trimmed;
    saveSettings();
  }

  void setCustomOpenAiEndpoint(String endpoint) {
    final trimmed = endpoint.trim();
    if (_customOpenAiEndpoint == trimmed) return;
    _customOpenAiEndpoint = trimmed;
    saveSettings();
  }

  void setAutoFallbackEnabled(bool enabled) {
    if (_autoFallbackEnabled == enabled) return;
    _autoFallbackEnabled = enabled;
    saveSettings();
  }

  void moveFallbackProvider(AiProvider provider, int delta) {
    final index = _fallbackOrder.indexOf(provider);
    if (index < 0) return;
    final targetIndex = (index + delta).clamp(0, _fallbackOrder.length - 1);
    if (targetIndex == index) return;
    _fallbackOrder
      ..removeAt(index)
      ..insert(targetIndex, provider);
    saveSettings();
  }

  List<AiRequestOption> requestOptions({required bool fallbackEnabled}) {
    if (!fallbackEnabled) {
      return [
        AiRequestOption(
          provider: _selectedProvider,
          modelName: selectedModelFor(_selectedProvider),
          endpoint: endpointFor(_selectedProvider),
        ),
      ];
    }

    final ordered = <AiProvider>[
      _selectedProvider,
      ..._fallbackOrder.where((provider) => provider != _selectedProvider),
    ];
    return ordered
        .map(
          (provider) => AiRequestOption(
            provider: provider,
            modelName: selectedModelFor(provider),
            endpoint: endpointFor(provider),
          ),
        )
        .toList();
  }
}

class AiRequestOption {
  final AiProvider provider;
  final String modelName;
  final String? endpoint;

  const AiRequestOption({
    required this.provider,
    required this.modelName,
    this.endpoint,
  });
}
