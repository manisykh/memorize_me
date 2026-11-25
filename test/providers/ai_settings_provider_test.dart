import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/providers/ai_settings_provider.dart';
import 'package:memorize_app/services/api_key_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'ai_provider_name': AiProvider.gemini.name,
      'ai_model_gemini': 'custom-gemini-model',
      'ai_model_groq': 'custom-groq-model',
      'ai_fallback_order': [AiProvider.groq.name, AiProvider.cohere.name],
      'ai_fallback_providers': [AiProvider.groq.name, AiProvider.cohere.name],
      'ai_provider_setup_sources': [
        '${AiProvider.gemini.name}:free',
        '${AiProvider.groq.name}:owned',
        '${AiProvider.cohere.name}:free',
      ],
    });
  });

  test(
    'removing a registered provider clears its saved configuration',
    () async {
      final settings = AiSettingsProvider();
      await settings.loadSettings();

      await settings.removeProviderConfiguration(
        AiProvider.groq,
        remainingProviders: const [AiProvider.gemini, AiProvider.cohere],
      );

      expect(settings.selectedProvider, AiProvider.gemini);
      expect(settings.fallbackOrder, [AiProvider.cohere]);
      expect(settings.wasAddedFromFreeSetup(AiProvider.groq), isNull);
      expect(
        settings.selectedModelFor(AiProvider.groq),
        AiProvider.groq.defaultModel,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ai_model_groq'), isNull);
      expect(
        prefs.getStringList('ai_provider_setup_sources'),
        isNot(contains('${AiProvider.groq.name}:owned')),
      );
    },
  );

  test(
    'removing the main provider promotes the next registered provider',
    () async {
      final settings = AiSettingsProvider();
      await settings.loadSettings();

      await settings.removeProviderConfiguration(
        AiProvider.gemini,
        remainingProviders: const [AiProvider.groq, AiProvider.cohere],
      );

      expect(settings.selectedProvider, AiProvider.groq);
      expect(settings.fallbackOrder, [AiProvider.cohere]);
      expect(settings.fallbackProviders, {AiProvider.cohere});
    },
  );
}
