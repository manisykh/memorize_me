import 'dart:convert';

import '../services/api_key_service.dart';

enum AiAccessType {
  freeTier,
  freeModel,
  monthlyCredit,
  trialCredit,
  paid,
  custom,
}

class AiProviderCatalogEntry {
  const AiProviderCatalogEntry({
    required this.provider,
    required this.accessType,
    required this.summary,
    required this.guideSteps,
    required this.consoleUrl,
    this.recommended = false,
    this.visible = true,
    this.requiresPaymentMethod = false,
    this.modelOverrides,
    this.showInFreeSetup,
    this.showInOwnedSetup,
  });

  final AiProvider provider;
  final AiAccessType accessType;
  final String summary;
  final List<String> guideSteps;
  final String consoleUrl;
  final bool recommended;
  final bool visible;
  final bool requiresPaymentMethod;
  final List<String>? modelOverrides;
  final bool? showInFreeSetup;
  final bool? showInOwnedSetup;

  List<String> get models =>
      modelOverrides == null || modelOverrides!.isEmpty
          ? provider.modelPresets
          : modelOverrides!;

  String get accessLabel {
    switch (accessType) {
      case AiAccessType.freeTier:
        return '무료 플랜';
      case AiAccessType.freeModel:
        return '무료 모델';
      case AiAccessType.monthlyCredit:
        return '월간 무료';
      case AiAccessType.trialCredit:
        return '체험 크레딧';
      case AiAccessType.paid:
        return '보유 키';
      case AiAccessType.custom:
        return '고급 연결';
    }
  }

  bool get isFreeFirst =>
      accessType != AiAccessType.paid && accessType != AiAccessType.custom;

  bool get appearsInFreeSetup => showInFreeSetup ?? isFreeFirst;
  bool get appearsInOwnedSetup => showInOwnedSetup ?? !isFreeFirst;

  String setupAccessLabel({required bool freeSetup}) {
    if (provider == AiProvider.customOpenAI) return '직접 연결';
    if (provider == AiProvider.cohere && !freeSetup) return '무료·유료 키';
    return accessLabel;
  }

  String setupSummary({required bool freeSetup}) {
    if (provider == AiProvider.customOpenAI) {
      return freeSetup
          ? '목록에 없는 무료 OpenAI 호환 API의 주소, 모델 ID, 키를 직접 입력해요.'
          : '보유한 OpenAI 호환 API의 주소, 모델 ID, 키를 직접 입력해요.';
    }
    return summary;
  }

  AiProviderCatalogEntry copyWith({
    AiAccessType? accessType,
    String? summary,
    List<String>? guideSteps,
    String? consoleUrl,
    bool? recommended,
    bool? visible,
    bool? requiresPaymentMethod,
    List<String>? modelOverrides,
    bool? showInFreeSetup,
    bool? showInOwnedSetup,
  }) {
    return AiProviderCatalogEntry(
      provider: provider,
      accessType: accessType ?? this.accessType,
      summary: summary ?? this.summary,
      guideSteps: guideSteps ?? this.guideSteps,
      consoleUrl: consoleUrl ?? this.consoleUrl,
      recommended: recommended ?? this.recommended,
      visible: visible ?? this.visible,
      requiresPaymentMethod:
          requiresPaymentMethod ?? this.requiresPaymentMethod,
      modelOverrides: modelOverrides ?? this.modelOverrides,
      showInFreeSetup: showInFreeSetup ?? this.showInFreeSetup,
      showInOwnedSetup: showInOwnedSetup ?? this.showInOwnedSetup,
    );
  }
}

class AiProviderCatalog {
  static const defaults = <AiProviderCatalogEntry>[
    AiProviderCatalogEntry(
      provider: AiProvider.gemini,
      accessType: AiAccessType.freeTier,
      summary: '발급이 쉽고 한국어 학습 콘텐츠 생성에 무난해요.',
      guideSteps: [
        'Google AI Studio에 로그인',
        'API key 만들기 선택',
        '복사한 키를 아래에 붙여넣기',
      ],
      consoleUrl: 'https://aistudio.google.com/app/apikey',
      recommended: true,
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.groq,
      accessType: AiAccessType.freeTier,
      summary: '무료 플랜의 응답이 빠르고 카드 등록 없이 시작하기 쉬워요.',
      guideSteps: ['GroqCloud 계정 만들기', 'API Keys에서 새 키 생성', '키를 복사해 붙여넣기'],
      consoleUrl: 'https://console.groq.com/keys',
      recommended: true,
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.mistral,
      accessType: AiAccessType.freeTier,
      summary: '무료 모드가 기본 제공되어 별도 결제수단 없이 시작할 수 있어요.',
      guideSteps: ['Mistral Studio에 로그인', 'API Keys에서 키 생성', '키를 복사해 붙여넣기'],
      consoleUrl: 'https://console.mistral.ai/api-keys',
      recommended: true,
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.openRouter,
      accessType: AiAccessType.freeModel,
      summary: '하나의 키로 여러 무료 모델을 자동 선택할 수 있어요.',
      guideSteps: ['OpenRouter에 로그인', 'Keys에서 새 키 생성', '무료 라우터 모델로 연결'],
      consoleUrl: 'https://openrouter.ai/settings/keys',
      recommended: true,
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.zAi,
      accessType: AiAccessType.freeModel,
      summary: 'GLM Flash 무료 모델을 선택해 가볍게 사용할 수 있어요.',
      guideSteps: ['Z.AI 개발자 콘솔 로그인', 'API Keys에서 키 생성', 'Flash 모델을 선택해 연결'],
      consoleUrl: 'https://z.ai/manage-apikey/apikey-list',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.nvidiaNim,
      accessType: AiAccessType.freeTier,
      summary: '개발자 프로그램의 호스팅 API를 실험·개발 용도로 사용할 수 있어요.',
      guideSteps: [
        'build.nvidia.com 로그인',
        '사용할 모델 페이지 열기',
        'Get API Key로 키 발급',
      ],
      consoleUrl: 'https://build.nvidia.com/',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.huggingFace,
      accessType: AiAccessType.monthlyCredit,
      summary: '매월 제공되는 소액 무료 크레딧으로 여러 모델을 시험할 수 있어요.',
      guideSteps: ['Hugging Face 로그인', 'Access Tokens에서 토큰 생성', '토큰을 복사해 붙여넣기'],
      consoleUrl: 'https://huggingface.co/settings/tokens',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.cerebras,
      accessType: AiAccessType.trialCredit,
      summary: '빠른 추론을 체험 크레딧으로 시험할 수 있어요.',
      guideSteps: ['Cerebras Cloud 로그인', 'API Keys에서 키 생성', '사용 가능한 모델 ID를 확인'],
      consoleUrl: 'https://cloud.cerebras.ai/',
      requiresPaymentMethod: true,
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.siliconFlow,
      accessType: AiAccessType.freeModel,
      summary: '일부 무료 모델을 제공하며 지역에 따라 가입 절차가 달라질 수 있어요.',
      guideSteps: ['SiliconCloud 계정 만들기', 'API 키 생성', '무료 표시 모델을 선택'],
      consoleUrl: 'https://cloud.siliconflow.com/account/ak',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.cohere,
      accessType: AiAccessType.freeTier,
      summary: '무료 평가 키로 시작하고 필요하면 유료 운영 키로 확장할 수 있어요.',
      guideSteps: [
        'Cohere Dashboard에 로그인',
        'API Keys에서 평가 또는 프로덕션 키 생성',
        '키를 복사해 붙여넣고 연결 확인',
      ],
      consoleUrl: 'https://dashboard.cohere.com/api-keys',
      showInOwnedSetup: true,
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.openAI,
      accessType: AiAccessType.paid,
      summary: 'OpenAI API 키를 이미 보유한 경우 연결합니다.',
      guideSteps: ['OpenAI 플랫폼에서 API 키 생성', '사용량·결제 한도 확인', '키를 붙여넣기'],
      consoleUrl: 'https://platform.openai.com/api-keys',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.anthropic,
      accessType: AiAccessType.paid,
      summary: 'Anthropic Claude API 키를 이미 보유한 경우 연결합니다.',
      guideSteps: ['Anthropic Console 로그인', 'API 키 생성', '키를 붙여넣기'],
      consoleUrl: 'https://console.anthropic.com/settings/keys',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.deepSeek,
      accessType: AiAccessType.paid,
      summary: 'DeepSeek API 잔액이 있는 계정을 연결합니다.',
      guideSteps: ['DeepSeek 플랫폼 로그인', 'API 키 생성', '잔액을 확인하고 키 붙여넣기'],
      consoleUrl: 'https://platform.deepseek.com/api_keys',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.xAI,
      accessType: AiAccessType.paid,
      summary: 'xAI API 키와 사용 가능한 Grok 모델을 연결합니다.',
      guideSteps: ['xAI Console 로그인', 'API 키 생성', '키를 붙여넣기'],
      consoleUrl: 'https://console.x.ai/',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.perplexity,
      accessType: AiAccessType.paid,
      summary: 'Perplexity API 키를 이미 보유한 경우 연결합니다.',
      guideSteps: ['Perplexity 설정 열기', 'API 키 생성', '키를 붙여넣기'],
      consoleUrl: 'https://www.perplexity.ai/settings/api',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.together,
      accessType: AiAccessType.paid,
      summary: 'Together AI 크레딧과 API 키를 연결합니다.',
      guideSteps: ['Together AI 로그인', 'API 키 생성', '키를 붙여넣기'],
      consoleUrl: 'https://api.together.ai/settings/api-keys',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.fireworks,
      accessType: AiAccessType.paid,
      summary: 'Fireworks AI의 선불 크레딧 계정을 연결합니다.',
      guideSteps: ['Fireworks 로그인', 'API 키 생성', '키를 붙여넣기'],
      consoleUrl: 'https://app.fireworks.ai/settings/users/api-keys',
    ),
    AiProviderCatalogEntry(
      provider: AiProvider.customOpenAI,
      accessType: AiAccessType.custom,
      summary: 'OpenAI 호환 서버의 endpoint, 모델 ID, API 키를 직접 입력합니다.',
      guideSteps: [
        '제공업체의 Chat Completions endpoint 확인',
        '정확한 모델 ID 확인',
        'endpoint와 키를 함께 입력',
      ],
      consoleUrl: '',
      showInFreeSetup: true,
      showInOwnedSetup: true,
    ),
  ];

  static List<AiProviderCatalogEntry> resolve(String remoteJson) {
    final entries = [...defaults];
    if (remoteJson.trim().isEmpty) return entries;
    try {
      final decoded = jsonDecode(remoteJson);
      if (decoded is! List) return entries;
      for (final value in decoded.whereType<Map>()) {
        final name = value['provider']?.toString();
        final index = entries.indexWhere(
          (entry) => entry.provider.name == name,
        );
        if (index < 0) continue;
        final current = entries[index];
        entries[index] = current.copyWith(
          summary: value['summary']?.toString(),
          consoleUrl: value['consoleUrl']?.toString(),
          visible: value['visible'] as bool?,
          recommended: value['recommended'] as bool?,
          requiresPaymentMethod: value['requiresPaymentMethod'] as bool?,
          guideSteps:
              (value['guideSteps'] as List?)
                  ?.map((item) => item.toString())
                  .toList(),
          modelOverrides:
              (value['models'] as List?)
                  ?.map((item) => item.toString())
                  .where((item) => item.isNotEmpty)
                  .toList(),
          accessType: _accessType(value['accessType']?.toString()),
          showInFreeSetup: value['showInFreeSetup'] as bool?,
          showInOwnedSetup: value['showInOwnedSetup'] as bool?,
        );
      }
    } catch (_) {
      return entries;
    }
    return entries;
  }

  static AiAccessType? _accessType(String? value) {
    for (final type in AiAccessType.values) {
      if (type.name == value) return type;
    }
    return null;
  }
}
