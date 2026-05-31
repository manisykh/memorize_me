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
    final apiKey = await showDialog<String>(
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
                onPressed: () => _popDialogAfterUnfocus(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed:
                    () => _popDialogAfterUnfocus(
                      dialogContext,
                      controller.text.trim(),
                    ),
                child: const Text('저장'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (apiKey == null || apiKey.isEmpty || !mounted) return;
    await apiKeyService.saveApiKey(provider, apiKey);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _registeredProviders[provider] = true;
      });
      _checkApiStatus();
    });
  }

  Future<void> _showCustomModelDialog(AiSettingsProvider aiSettings) async {
    final provider = aiSettings.selectedProvider;
    final controller = TextEditingController(text: aiSettings.selectedModel);
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('${provider.shortLabel} 모델 ID 직접 입력'),
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
                onPressed: () => _popDialogAfterUnfocus(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed:
                    () => _popDialogAfterUnfocus(
                      dialogContext,
                      controller.text.trim(),
                    ),
                child: const Text('적용'),
              ),
            ],
          ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) return;
    aiSettings.setModel(provider, result);
  }

  void _popDialogAfterUnfocus(BuildContext dialogContext, [String? result]) {
    FocusScope.of(dialogContext).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext, result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiSettings = context.watch<AiSettingsProvider>();

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 설정', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '사용할 AI 회사와 모델을 먼저 고르고, 자동 대체에 쓸 후보만 체크해서 관리합니다.',
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
          const SizedBox(height: 14),
          _buildCurrentStatus(theme, aiSettings),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('자동 대체 사용'),
            subtitle: const Text('한도 초과, 서버 과부하, 네트워크 오류가 날 때 체크한 후보로만 이어서 시도합니다.'),
            value: aiSettings.autoFallbackEnabled,
            onChanged: aiSettings.setAutoFallbackEnabled,
          ),
          if (aiSettings.autoFallbackEnabled) ...[
            const SizedBox(height: 8),
            _buildFallbackCandidateChips(aiSettings),
            const SizedBox(height: 14),
            if (aiSettings.fallbackOrder.isNotEmpty) ...[
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
            ] else
              _buildEmptyFallbackHint(theme),
          ],
          const Divider(height: 28),
          Text('API 키 등록 현황', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...aiSettings.configuredProviders.map(
            (provider) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _buildApiStatusRow(
                provider: provider,
                isRegistered: _registeredProviders[provider] ?? false,
                isActive: provider == aiSettings.selectedProvider,
                isLastFallback: _isLastFallback(aiSettings, provider),
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
      decoration: const InputDecoration(labelText: 'AI 회사'),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
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
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _showCustomModelDialog(aiSettings),
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text('목록에 없는 모델 직접 입력'),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStatus(ThemeData theme, AiSettingsProvider aiSettings) {
    final lastUsed = aiSettings.lastUsedOption;
    final hasFallback = lastUsed != null && lastUsed.provider != aiSettings.selectedProvider;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildStatusPill(
          theme: theme,
          icon: Icons.radio_button_checked_rounded,
          label: '현재 ${aiSettings.selectedProvider.shortLabel}',
          detail: aiSettings.selectedModel,
          color: theme.colorScheme.primary,
        ),
        if (hasFallback)
          _buildStatusPill(
            theme: theme,
            icon: Icons.alt_route_rounded,
            label: '최근 대체 ${lastUsed.provider.shortLabel}',
            detail: lastUsed.modelName,
            color: theme.colorScheme.tertiary,
          ),
      ],
    );
  }

  Widget _buildStatusPill({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String detail,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              '$label · $detail',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackCandidateChips(AiSettingsProvider aiSettings) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '대체 후보',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children:
              AiProvider.values.map((provider) {
                final isActive = provider == aiSettings.selectedProvider;
                final selected = isActive || aiSettings.isFallbackProviderEnabled(provider);
                return FilterChip(
                  selected: selected,
                  showCheckmark: !isActive,
                  avatar:
                      isActive
                          ? Icon(Icons.radio_button_checked_rounded, size: 16, color: theme.colorScheme.primary)
                          : null,
                  label: Text(isActive ? '${provider.shortLabel} 현재' : provider.shortLabel),
                  onSelected:
                      isActive
                          ? null
                          : (value) => aiSettings.setFallbackProviderEnabled(provider, value),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildEmptyFallbackHint(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        '대체 후보를 체크하면 이곳에 우선순위와 API 키 상태가 표시됩니다.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }

  Widget _buildApiStatusRow({
    required AiProvider provider,
    required bool isRegistered,
    required bool isActive,
    required bool isLastFallback,
  }) {
    final theme = Theme.of(context);
    final accentColor =
        isActive
            ? theme.colorScheme.primary
            : isLastFallback
                ? theme.colorScheme.tertiary
                : theme.colorScheme.outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isActive || isLastFallback ? 0.10 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: isActive || isLastFallback ? 0.32 : 0.14)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildMiniBadge(
                      theme,
                      isRegistered ? '등록 완료' : '등록 필요',
                      isRegistered ? Colors.green : Colors.orange,
                    ),
                    if (isActive) _buildMiniBadge(theme, '현재 사용', theme.colorScheme.primary),
                    if (isLastFallback) _buildMiniBadge(theme, '최근 대체', theme.colorScheme.tertiary),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 34,
            child: OutlinedButton(
              onPressed: () => _showApiKeyDialog(provider),
              child: Text(isRegistered ? '관리' : '등록'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBadge(ThemeData theme, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildFallbackOrderRow(AiSettingsProvider aiSettings, AiProvider provider) {
    final theme = Theme.of(context);
    final order = aiSettings.fallbackOrder;
    final index = order.indexOf(provider);
    final isRegistered = _registeredProviders[provider] ?? false;
    final isLastFallback = _isLastFallback(aiSettings, provider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            isLastFallback
                ? theme.colorScheme.tertiary.withValues(alpha: 0.10)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(14),
        border:
            isLastFallback
                ? Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.30))
                : null,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${provider.shortLabel} · ${aiSettings.selectedModelFor(provider)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isRegistered ? null : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isRegistered ? '대체 가능' : 'API 키 등록 필요',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: isRegistered ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
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

  bool _isLastFallback(AiSettingsProvider aiSettings, AiProvider provider) {
    final lastUsed = aiSettings.lastUsedOption;
    return lastUsed != null &&
        lastUsed.provider == provider &&
        lastUsed.provider != aiSettings.selectedProvider;
  }
}
