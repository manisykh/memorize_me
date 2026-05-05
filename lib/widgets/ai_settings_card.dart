import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_settings_provider.dart';
import '../services/api_key_service.dart';
import 'glassmorphic_card.dart';

class AiSettingsCard extends StatefulWidget {
  const AiSettingsCard({super.key});

  @override
  State<AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends State<AiSettingsCard> {
  final Map<AiProvider, bool> _registeredProviders = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkApiStatus());
  }

  Future<void> _checkApiStatus() async {
    if (!mounted) return;
    final apiKeyService = context.read<ApiKeyService>();
    final nextState = <AiProvider, bool>{};
    for (final provider in AiProvider.values) {
      final apiKey = await apiKeyService.getApiKey(provider);
      nextState[provider] = apiKey != null && apiKey.isNotEmpty;
    }
    if (!mounted) return;
    setState(() {
      _registeredProviders
        ..clear()
        ..addAll(nextState);
    });
  }

  Future<void> _showApiKeyDialog(AiProvider provider) async {
    final controller = TextEditingController();
    final apiKeyService = context.read<ApiKeyService>();
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('${provider.label} API 키 등록'),
            content: TextField(
              controller: controller,
              obscureText: true,
              decoration: InputDecoration(hintText: '${provider.shortLabel} API 키 입력'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () async {
                  if (controller.text.isEmpty) return;
                  await apiKeyService.saveApiKey(provider, controller.text);
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _checkApiStatus();
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
    controller.dispose();
  }

  Future<void> _showCustomModelDialog(AiSettingsProvider aiSettings) async {
    final provider = aiSettings.selectedProvider;
    final controller = TextEditingController(text: aiSettings.selectedModel);
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('${provider.shortLabel} 모델 ID 입력'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '모델 ID',
                hintText: '예: provider/model-name 또는 model-name',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
                child: const Text('적용'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    aiSettings.setModel(provider, result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiSettings = context.watch<AiSettingsProvider>();

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 제공자', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '여러 회사의 API 키를 동시에 등록해두고, 사용할 제공자와 모델을 선택합니다. 목록에 없는 모델은 직접 ID로 추가할 수 있습니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          _buildProviderDropdown(aiSettings),
          const SizedBox(height: 12),
          _buildModelSelector(aiSettings),
          if (aiSettings.selectedProvider == AiProvider.customOpenAI) ...[
            const SizedBox(height: 12),
            TextFormField(
              initialValue: aiSettings.customOpenAiEndpoint,
              decoration: const InputDecoration(
                labelText: 'Chat Completions Endpoint',
                hintText: 'https://example.com/v1/chat/completions',
                helperText: 'OpenAI 호환 API 서버를 직접 연결합니다.',
              ),
              onChanged: aiSettings.setCustomOpenAiEndpoint,
            ),
          ],
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('자동 대체 사용'),
            subtitle: const Text('켜면 학습 내용이 등록된 다른 AI 회사로도 전송될 수 있습니다. 한도 초과, 서버 과부하, 네트워크 오류에서만 이어서 시도합니다.'),
            value: aiSettings.autoFallbackEnabled,
            onChanged: aiSettings.setAutoFallbackEnabled,
          ),
          if (aiSettings.autoFallbackEnabled) ...[
            const SizedBox(height: 8),
            Text(
              '대체 우선순위',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            ...aiSettings.fallbackOrder.map(
              (provider) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildFallbackOrderRow(aiSettings, provider),
              ),
            ),
          ],
          const Divider(height: 28),
          Text('API 키 등록', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...AiProvider.values.map(
            (provider) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildApiStatusRow(
                provider: provider,
                isRegistered: _registeredProviders[provider] ?? false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderDropdown(AiSettingsProvider aiSettings) {
    return DropdownButtonFormField<AiProvider>(
      value: aiSettings.selectedProvider,
      isExpanded: true,
      decoration: const InputDecoration(labelText: '사용할 AI 회사'),
      items:
          AiProvider.values.map((provider) {
            return DropdownMenuItem(
              value: provider,
              child: Text(provider.label, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
      onChanged: (provider) {
        if (provider != null) aiSettings.setProvider(provider);
      },
    );
  }

  Widget _buildModelSelector(AiSettingsProvider aiSettings) {
    final provider = aiSettings.selectedProvider;
    final selectedModel = aiSettings.selectedModel;
    final models = [
      if (!provider.modelPresets.contains(selectedModel)) selectedModel,
      ...provider.modelPresets,
    ];

    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedModel,
            isExpanded: true,
            decoration: const InputDecoration(labelText: '사용 모델'),
            items:
                models.map((model) {
                  return DropdownMenuItem(
                    value: model,
                    child: Text(model, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
            onChanged: (value) {
              if (value != null) aiSettings.setModel(provider, value);
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: '모델 ID 직접 입력',
          onPressed: () => _showCustomModelDialog(aiSettings),
          icon: const Icon(Icons.edit),
        ),
      ],
    );
  }

  Widget _buildApiStatusRow({required AiProvider provider, required bool isRegistered}) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              provider.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isRegistered ? '등록 완료' : '등록 필요',
            style: theme.textTheme.bodySmall?.copyWith(
              color: isRegistered ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 32,
            child: OutlinedButton(
              onPressed: () => _showApiKeyDialog(provider),
              child: Text(isRegistered ? '관리' : '등록'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackOrderRow(AiSettingsProvider aiSettings, AiProvider provider) {
    final theme = Theme.of(context);
    final order = aiSettings.fallbackOrder;
    final index = order.indexOf(provider);
    final isRegistered = _registeredProviders[provider] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Expanded(
            child: Text(
              provider.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isRegistered ? null : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (!isRegistered)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '키 없음',
                style: theme.textTheme.labelSmall?.copyWith(color: Colors.orange),
              ),
            ),
          IconButton(
            tooltip: '위로',
            onPressed: index <= 0 ? null : () => aiSettings.moveFallbackProvider(provider, -1),
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            tooltip: '아래로',
            onPressed:
                index >= order.length - 1
                    ? null
                    : () => aiSettings.moveFallbackProvider(provider, 1),
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
        ],
      ),
    );
  }
}
