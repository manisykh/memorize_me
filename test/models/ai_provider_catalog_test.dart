import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/models/ai_provider_catalog.dart';
import 'package:memorize_app/services/api_key_service.dart';

void main() {
  test('무료 시작 목록과 보유 키 목록을 분리한다', () {
    final catalog = AiProviderCatalog.resolve('');

    final freeProviders = catalog.where((entry) => entry.appearsInFreeSetup);
    final existingKeyProviders = catalog.where(
      (entry) => entry.appearsInOwnedSetup,
    );

    expect(freeProviders.length, greaterThanOrEqualTo(8));
    expect(
      freeProviders.map((entry) => entry.provider),
      containsAll(<AiProvider>[
        AiProvider.gemini,
        AiProvider.groq,
        AiProvider.mistral,
        AiProvider.openRouter,
        AiProvider.zAi,
        AiProvider.nvidiaNim,
        AiProvider.cohere,
        AiProvider.customOpenAI,
      ]),
    );
    expect(
      existingKeyProviders.map((entry) => entry.provider),
      containsAll(<AiProvider>[
        AiProvider.openAI,
        AiProvider.anthropic,
        AiProvider.cohere,
        AiProvider.customOpenAI,
      ]),
    );
  });

  test('Cohere를 무료 평가 키와 보유 키 흐름에서 모두 연결할 수 있다', () {
    final cohere = AiProviderCatalog.resolve('').singleWhere(
      (entry) => entry.provider == AiProvider.cohere,
    );

    expect(cohere.appearsInFreeSetup, isTrue);
    expect(cohere.appearsInOwnedSetup, isTrue);
    expect(cohere.models, contains('command-a-plus-05-2026'));
    expect(
      AiProvider.cohere.chatCompletionsEndpoint,
      'https://api.cohere.ai/compatibility/v1/chat/completions',
    );
  });

  test('Custom OpenAI Compatible은 두 흐름에서 하나의 공통 설정을 사용한다', () {
    final custom = AiProviderCatalog.resolve('').singleWhere(
      (entry) => entry.provider == AiProvider.customOpenAI,
    );

    expect(custom.appearsInFreeSetup, isTrue);
    expect(custom.appearsInOwnedSetup, isTrue);
    expect(custom.setupAccessLabel(freeSetup: true), '직접 연결');
    expect(custom.setupAccessLabel(freeSetup: false), '직접 연결');
    expect(custom.setupSummary(freeSetup: true), contains('무료 OpenAI 호환 API'));
    expect(custom.setupSummary(freeSetup: false), contains('보유한 OpenAI 호환 API'));
  });

  test('원격 카탈로그로 노출 여부와 안내를 안전하게 갱신한다', () {
    final catalog = AiProviderCatalog.resolve('''
      [
        {
          "provider": "groq",
          "visible": false,
          "summary": "정책 점검 중",
          "accessType": "trialCredit",
          "models": ["replacement-model"],
          "showInFreeSetup": false,
          "showInOwnedSetup": true
        }
      ]
    ''');

    final groq = catalog.singleWhere(
      (entry) => entry.provider == AiProvider.groq,
    );
    expect(groq.visible, isFalse);
    expect(groq.summary, '정책 점검 중');
    expect(groq.accessType, AiAccessType.trialCredit);
    expect(groq.models, const ['replacement-model']);
    expect(groq.appearsInFreeSetup, isFalse);
    expect(groq.appearsInOwnedSetup, isTrue);
  });
}
