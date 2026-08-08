// lib/services/api_key_service.dart (새 파일)

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 어떤 AI 제공자인지 구분하기 위한 Enum
enum AiProvider {
  gemini,
  openAI,
  anthropic,
  groq,
  openRouter,
  mistral,
  deepSeek,
  xAI,
  perplexity,
  together,
  fireworks,
  customOpenAI,
  zAi,
}

extension AiProviderInfo on AiProvider {
  String get label {
    switch (this) {
      case AiProvider.gemini:
        return 'Google Gemini';
      case AiProvider.openAI:
        return 'OpenAI';
      case AiProvider.anthropic:
        return 'Anthropic Claude';
      case AiProvider.groq:
        return 'Groq';
      case AiProvider.openRouter:
        return 'OpenRouter';
      case AiProvider.mistral:
        return 'Mistral AI';
      case AiProvider.deepSeek:
        return 'DeepSeek';
      case AiProvider.xAI:
        return 'xAI Grok';
      case AiProvider.perplexity:
        return 'Perplexity';
      case AiProvider.together:
        return 'Together AI';
      case AiProvider.fireworks:
        return 'Fireworks AI';
      case AiProvider.customOpenAI:
        return 'Custom OpenAI Compatible';
      case AiProvider.zAi:
        return 'Z.AI';
    }
  }

  String get shortLabel {
    switch (this) {
      case AiProvider.gemini:
        return 'Gemini';
      case AiProvider.openAI:
        return 'OpenAI';
      case AiProvider.anthropic:
        return 'Claude';
      case AiProvider.groq:
        return 'Groq';
      case AiProvider.openRouter:
        return 'OpenRouter';
      case AiProvider.mistral:
        return 'Mistral';
      case AiProvider.deepSeek:
        return 'DeepSeek';
      case AiProvider.xAI:
        return 'xAI';
      case AiProvider.perplexity:
        return 'Perplexity';
      case AiProvider.together:
        return 'Together';
      case AiProvider.fireworks:
        return 'Fireworks';
      case AiProvider.customOpenAI:
        return 'Custom';
      case AiProvider.zAi:
        return 'Z.AI';
    }
  }

  String get defaultModel => modelPresets.first;

  List<String> get modelPresets {
    switch (this) {
      case AiProvider.gemini:
        return const [
          'gemini-3.5-flash',
          'gemini-3.1-flash-lite',
          'gemini-3.1-pro-preview',
          'gemini-2.5-pro',
          'gemini-2.5-flash',
          'gemini-2.5-flash-lite',
          'gemini-2.0-flash',
          'gemini-1.5-pro',
          'gemini-1.5-flash',
        ];
      case AiProvider.openAI:
        return const [
          'gpt-4.1',
          'gpt-4.1-mini',
          'gpt-4.1-nano',
          'gpt-4o',
          'gpt-4o-mini',
          'gpt-4-turbo',
          'gpt-3.5-turbo',
        ];
      case AiProvider.anthropic:
        return const [
          'claude-3-5-sonnet-latest',
          'claude-3-5-haiku-latest',
          'claude-3-opus-latest',
        ];
      case AiProvider.groq:
        return const [
          'llama-3.3-70b-versatile',
          'llama-3.1-8b-instant',
          'mixtral-8x7b-32768',
          'gemma2-9b-it',
        ];
      case AiProvider.openRouter:
        return const [
          'deepseek/deepseek-chat-v3-0324:free',
          'meta-llama/llama-3.3-70b-instruct:free',
          'openai/gpt-4o',
          'anthropic/claude-3.5-sonnet',
          'google/gemini-2.0-flash-001',
          'meta-llama/llama-3.1-70b-instruct',
        ];
      case AiProvider.mistral:
        return const [
          'mistral-large-latest',
          'mistral-small-latest',
          'codestral-latest',
          'open-mixtral-8x22b',
        ];
      case AiProvider.deepSeek:
        return const [
          'deepseek-chat',
          'deepseek-reasoner',
        ];
      case AiProvider.xAI:
        return const [
          'grok-2-latest',
          'grok-2-vision-latest',
        ];
      case AiProvider.perplexity:
        return const [
          'sonar',
          'sonar-pro',
          'sonar-reasoning',
          'sonar-deep-research',
        ];
      case AiProvider.together:
        return const [
          'meta-llama/Llama-3.3-70B-Instruct-Turbo',
          'meta-llama/Meta-Llama-3.1-8B-Instruct-Turbo',
          'Qwen/Qwen2.5-72B-Instruct-Turbo',
          'mistralai/Mixtral-8x7B-Instruct-v0.1',
        ];
      case AiProvider.fireworks:
        return const [
          'accounts/fireworks/models/llama-v3p1-70b-instruct',
          'accounts/fireworks/models/deepseek-r1',
        ];
      case AiProvider.customOpenAI:
        return const [
          'meta/llama-3.3-70b-instruct',
          'nvidia/llama-3.3-nemotron-super-49b-v1.5',
          'nvidia/llama-3.1-nemotron-70b-instruct',
          'meta/llama-3.1-405b-instruct',
          'meta/llama-3.1-70b-instruct',
          'custom-model',
        ];
      case AiProvider.zAi:
        return const [
          'glm-4.7-flash',
          'glm-5.1',
          'glm-5',
          'glm-5-turbo',
          'glm-4.7',
          'glm-4.7-flashx',
          'glm-4.6',
          'glm-4.5',
          'glm-4.5-air',
          'glm-4.5-flash',
        ];
    }
  }

  String costHintForModel(String model, {String? endpoint}) {
    final normalizedModel = model.toLowerCase();
    final normalizedEndpoint = endpoint?.toLowerCase() ?? '';

    switch (this) {
      case AiProvider.gemini:
        if (normalizedModel.contains('pro-preview')) return '유료 모델';
        return '무료 티어 가능';
      case AiProvider.groq:
        return '무료 플랜 가능';
      case AiProvider.openRouter:
        return normalizedModel.endsWith(':free') ? '무료 모델' : '요금 확인';
      case AiProvider.customOpenAI:
        if (normalizedEndpoint.contains('integrate.api.nvidia.com')) {
          return 'NVIDIA 무료 크레딧 확인';
        }
        return '요금 확인';
      case AiProvider.zAi:
        if (normalizedModel == 'glm-4.7-flash' ||
            normalizedModel == 'glm-4.5-flash') {
          return '무료 모델';
        }
        if (normalizedModel == 'glm-5.1') {
          return '한시적 무료 · 정책 확인';
        }
        return '요금 확인';
      case AiProvider.openAI:
      case AiProvider.anthropic:
      case AiProvider.mistral:
      case AiProvider.deepSeek:
      case AiProvider.xAI:
      case AiProvider.perplexity:
      case AiProvider.together:
      case AiProvider.fireworks:
        return '요금 확인';
    }
  }

  String? get chatCompletionsEndpoint {
    switch (this) {
      case AiProvider.openAI:
        return 'https://api.openai.com/v1/chat/completions';
      case AiProvider.groq:
        return 'https://api.groq.com/openai/v1/chat/completions';
      case AiProvider.openRouter:
        return 'https://openrouter.ai/api/v1/chat/completions';
      case AiProvider.mistral:
        return 'https://api.mistral.ai/v1/chat/completions';
      case AiProvider.deepSeek:
        return 'https://api.deepseek.com/chat/completions';
      case AiProvider.xAI:
        return 'https://api.x.ai/v1/chat/completions';
      case AiProvider.perplexity:
        return 'https://api.perplexity.ai/chat/completions';
      case AiProvider.together:
        return 'https://api.together.xyz/v1/chat/completions';
      case AiProvider.fireworks:
        return 'https://api.fireworks.ai/inference/v1/chat/completions';
      case AiProvider.zAi:
        return 'https://api.z.ai/api/paas/v4/chat/completions';
      case AiProvider.customOpenAI:
      case AiProvider.gemini:
      case AiProvider.anthropic:
        return null;
    }
  }
}

class ApiKeyService {
  final _storage = const FlutterSecureStorage();

  // 프로바이더별 키 이름 정의
  String _keyName(AiProvider provider) {
    return 'api_key_${provider.name}';
  }

  // API 키 저장
  Future<void> saveApiKey(AiProvider provider, String apiKey) async {
    await _storage.write(key: _keyName(provider), value: apiKey);
  }

  // API 키 불러오기
  Future<String?> getApiKey(AiProvider provider) async {
    return await _storage.read(key: _keyName(provider));
  }

  // API 키 삭제 (선택적 기능)
  Future<void> deleteApiKey(AiProvider provider) async {
    await _storage.delete(key: _keyName(provider));
  }
}
