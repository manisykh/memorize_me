import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/ai_settings_provider.dart';
import '../services/ai_service.dart';
import '../services/api_key_service.dart';
import 'glassmorphic_card.dart';

class AiSettingsCard extends StatefulWidget {
  const AiSettingsCard({super.key});

  @override
  State<AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends State<AiSettingsCard> {
  final Map<AiProvider, bool> _registeredProviders = {};
  final ScrollController _fallbackScrollController = ScrollController();
  bool _isTestingConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkApiStatus());
  }

  @override
  void dispose() {
    _fallbackScrollController.dispose();
    super.dispose();
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
    final apiKeyService = context.read<ApiKeyService>();
    var draftApiKey = '';
    final apiKey = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('${provider.label} API 키 등록'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '키는 기기 안의 보안 저장소에만 저장됩니다. 앱 서버로 전송하지 않고 AI 요청에만 사용합니다.',
                  style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  obscureText: true,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: '${provider.shortLabel} API 키',
                    hintText: '${provider.shortLabel} API 키 입력',
                    helperText: '저장 후 AI 퀴즈와 예문 생성에 사용할 수 있습니다.',
                  ),
                  onChanged: (value) => draftApiKey = value,
                  onSubmitted:
                      (value) => _popDialogAfterUnfocus(
                        dialogContext,
                        value.trim(),
                      ),
                ),
              ],
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
                      draftApiKey.trim(),
                    ),
                child: const Text('저장'),
              ),
            ],
          ),
    );
    if (apiKey == null || apiKey.isEmpty || !mounted) return;
    await apiKeyService.saveApiKey(provider, apiKey);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _registeredProviders[provider] = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${provider.shortLabel} API 키를 저장했습니다.')),
      );
      _checkApiStatus();
    });
  }

  Future<void> _showCustomModelDialog(AiSettingsProvider aiSettings) async {
    final provider = aiSettings.selectedProvider;
    var draftModel = aiSettings.selectedModel;
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('${provider.shortLabel} 모델 ID 직접 입력'),
            content: TextFormField(
              initialValue: draftModel,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '모델 ID',
                hintText: '예: provider/model-name 또는 model-name',
              ),
              onChanged: (value) => draftModel = value,
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
                      draftModel.trim(),
                    ),
                child: const Text('적용'),
              ),
            ],
          ),
    );
    if (result == null || result.isEmpty) return;
    aiSettings.setModel(provider, result);
  }

  Future<void> _testSelectedConnection(AiSettingsProvider aiSettings) async {
    if (_isTestingConnection) return;
    setState(() => _isTestingConnection = true);
    try {
      await context.read<AiService>().testConnection(
            provider: aiSettings.selectedProvider,
            modelName: aiSettings.selectedModel,
            endpoint: aiSettings.selectedEndpoint,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${aiSettings.selectedProvider.shortLabel} ${aiSettings.selectedModel} 연결 테스트에 성공했습니다.',
          ),
        ),
      );
      _checkApiStatus();
    } on CustomApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI 연결 테스트에 실패했습니다: $e')),
      );
    } finally {
      if (mounted) setState(() => _isTestingConnection = false);
    }
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
            '사용할 AI와 대체 후보를 관리합니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildAiDataNotice(theme, aiSettings),
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
                hintText: 'https://integrate.api.nvidia.com/v1/chat/completions',
                helperText: 'OpenAI 호환 API 서버를 직접 연결합니다.',
              ),
              onChanged: aiSettings.setCustomOpenAiEndpoint,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed:
                    () => aiSettings.setCustomOpenAiEndpoint(
                      'https://integrate.api.nvidia.com/v1/chat/completions',
                    ),
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('NVIDIA NIM endpoint 사용'),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildCurrentStatus(theme, aiSettings),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isTestingConnection ? null : () => _testSelectedConnection(aiSettings),
              icon:
                  _isTestingConnection
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.network_check_rounded),
              label: Text(_isTestingConnection ? '연결 테스트 중...' : '현재 AI 설정 연결 테스트'),
            ),
          ),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('자동 대체 사용'),
            subtitle: const Text('오류가 나면 체크한 후보로 이어서 시도합니다.'),
            value: aiSettings.autoFallbackEnabled,
            onChanged: aiSettings.setAutoFallbackEnabled,
          ),
          if (aiSettings.autoFallbackEnabled) ...[
            const SizedBox(height: 8),
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
          if (aiSettings.autoFallbackEnabled) ...[
            const Divider(height: 28),
            _buildFallbackCandidateGrid(aiSettings),
          ],
        ],
      ),
    );
  }

  Widget _buildAiDataNotice(ThemeData theme, AiSettingsProvider aiSettings) {
    final fallbackText =
        aiSettings.autoFallbackEnabled
            ? '자동 대체가 켜져 있어 실패 시 체크한 대체 제공자에도 요청할 수 있습니다.'
            : '자동 대체가 꺼져 있어 현재 선택한 제공자에만 요청합니다.';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.privacy_tip_outlined, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'API 키는 이 기기의 보안 저장소에 저장됩니다. AI 생성 시 선택한 단어, 뜻, 예문, 문법 범위가 외부 AI 제공자에게 전송됩니다. $fallbackText',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.35,
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
                  child: Row(
                    children: [
                      Expanded(child: Text(model, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      _buildCostHintBadge(
                        Theme.of(context),
                        provider.costHintForModel(
                          model,
                          endpoint: aiSettings.customOpenAiEndpoint,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          onChanged: (value) {
            if (value != null) aiSettings.setModel(provider, value);
          },
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: _buildCostHintBadge(
            Theme.of(context),
            provider.costHintForModel(
              selectedModel,
              endpoint: aiSettings.customOpenAiEndpoint,
            ),
          ),
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

  Widget _buildCostHintBadge(ThemeData theme, String label) {
    final lower = label.toLowerCase();
    final Color color =
        label.contains('무료')
            ? Colors.green
            : label.contains('유료')
                ? theme.colorScheme.error
                : theme.colorScheme.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        lower.contains('free') ? label : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
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

  Widget _buildFallbackCandidateGrid(AiSettingsProvider aiSettings) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '대체 후보',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            final innerWidth = constraints.maxWidth - 22;
            final cardWidth = isWide ? (innerWidth - 10) / 2 : innerWidth;
            return Container(
              constraints: const BoxConstraints(maxHeight: 360),
              padding: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.24)),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Scrollbar(
                controller: _fallbackScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _fallbackScrollController,
                  padding: const EdgeInsets.all(10),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children:
                        AiProvider.values.map((provider) {
                          return SizedBox(
                            width: cardWidth,
                            child: _buildFallbackCandidateBox(aiSettings, provider),
                          );
                        }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFallbackCandidateBox(AiSettingsProvider aiSettings, AiProvider provider) {
    final theme = Theme.of(context);
    final isActive = provider == aiSettings.selectedProvider;
    final isFallback = aiSettings.isFallbackProviderEnabled(provider);
    final selected = isActive || isFallback;
    final isRegistered = _registeredProviders[provider] ?? false;
    final isLastFallback = _isLastFallback(aiSettings, provider);
    final accentColor =
        isActive
            ? theme.colorScheme.primary
            : isLastFallback
                ? theme.colorScheme.tertiary
                : selected
                    ? theme.colorScheme.secondary
                    : theme.colorScheme.outline;
    final cardColor =
        selected
            ? Color.alphaBlend(
              accentColor.withValues(alpha: 0.12),
              theme.colorScheme.surface,
            )
            : Color.alphaBlend(
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.48),
              theme.colorScheme.surface,
            );
    final borderColor =
        selected
            ? accentColor.withValues(alpha: 0.58)
            : theme.colorScheme.outline.withValues(alpha: 0.34);

    final statusLabel =
        isActive
            ? '현재 사용'
            : isFallback
                ? '대체 후보'
                : '미사용';
    final keyLabel = isRegistered ? 'API 키 등록됨' : 'API 키 필요';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap:
          isActive
              ? null
              : () => aiSettings.setFallbackProviderEnabled(provider, !isFallback),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(10, 12, 13, 12),
        decoration: BoxDecoration(
          color: cardColor,
        borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: selected ? 1.4 : 1),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: selected ? 0.12 : 0.08),
              blurRadius: selected ? 10 : 7,
              spreadRadius: -5,
              offset: Offset(0, selected ? 4 : 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: selected ? 0.82 : 0.34),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: selected ? 0.14 : 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isActive
                    ? Icons.radio_button_checked_rounded
                    : isFallback
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                size: 20,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          provider.shortLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildCandidateToggle(
                        theme: theme,
                        selected: selected,
                        isActive: isActive,
                        color: accentColor,
                        onTap:
                            isActive
                                ? null
                                : () => aiSettings.setFallbackProviderEnabled(
                                      provider,
                                      !isFallback,
                                    ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aiSettings.selectedModelFor(provider),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _buildMiniBadge(theme, statusLabel, accentColor),
                      _buildMiniBadge(
                        theme,
                        keyLabel,
                        isRegistered ? Colors.green : Colors.orange,
                      ),
                      if (isLastFallback)
                        _buildMiniBadge(theme, '최근 대체', theme.colorScheme.tertiary),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateToggle({
    required ThemeData theme,
    required bool selected,
    required bool isActive,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return Tooltip(
      message: isActive ? '현재 사용 모델' : selected ? '대체 후보에서 제외' : '대체 후보로 추가',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: selected ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: selected ? 0.28 : 0.14)),
          ),
          child: Icon(
            selected ? Icons.check_rounded : Icons.add_rounded,
            size: 18,
            color: isActive ? color.withValues(alpha: 0.70) : color,
          ),
        ),
      ),
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
