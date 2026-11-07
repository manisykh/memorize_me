import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider_catalog.dart';
import '../providers/ai_settings_provider.dart';
import '../screens/ai_provider_setup_screen.dart';
import '../services/ai_service.dart';
import '../services/api_key_service.dart';
import '../themes/memorize_identity.dart';

class AiSettingsCard extends StatefulWidget {
  final bool embedded;

  const AiSettingsCard({super.key, this.embedded = false});

  @override
  State<AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends State<AiSettingsCard> {
  final Map<AiProvider, bool> _registered = {};
  final Set<AiProvider> _testing = {};
  bool _testingAll = false;
  String? _feedbackMessage;
  bool _feedbackSuccess = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshProviders());
  }

  Future<void> _refreshProviders() async {
    final keys = context.read<ApiKeyService>();
    final next = <AiProvider, bool>{};
    for (final provider in AiProvider.values) {
      final key = await keys.getApiKey(provider);
      next[provider] = key?.trim().isNotEmpty == true;
    }
    if (!mounted) return;
    setState(() {
      _registered
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _openSetup(bool freeFirst) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiProviderSetupScreen(freeFirst: freeFirst),
      ),
    );
    if (mounted) await _refreshProviders();
  }

  List<AiProvider> _orderedRegistered(AiSettingsProvider settings) {
    final providers =
        _registered.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toSet();
    final ordered = <AiProvider>[];
    void add(AiProvider provider) {
      if (providers.contains(provider) && !ordered.contains(provider)) {
        ordered.add(provider);
      }
    }

    add(settings.selectedProvider);
    for (final provider in settings.fallbackOrder) {
      add(provider);
    }
    for (final provider in AiProvider.values) {
      add(provider);
    }
    return ordered;
  }

  AiProviderCatalogEntry _catalogFor(AiProvider provider) =>
      AiProviderCatalog.defaults.firstWhere(
        (entry) => entry.provider == provider,
        orElse:
            () => AiProviderCatalogEntry(
              provider: provider,
              accessType: AiAccessType.paid,
              summary: '',
              guideSteps: const [],
              consoleUrl: '',
            ),
      );

  Future<bool> _test(
    AiProvider provider, {
    String? model,
    bool notify = true,
  }) async {
    if (_testing.contains(provider)) return false;
    setState(() => _testing.add(provider));
    final settings = context.read<AiSettingsProvider>();
    try {
      await context.read<AiService>().testConnection(
        provider: provider,
        modelName: model ?? settings.selectedModelFor(provider),
        endpoint: settings.endpointFor(provider),
      );
      if (notify && mounted) {
        setState(() {
          _feedbackSuccess = true;
          _feedbackMessage = '${provider.shortLabel} 연결이 정상입니다.';
        });
      }
      return true;
    } catch (_) {
      if (notify && mounted) {
        setState(() {
          _feedbackSuccess = false;
          _feedbackMessage = '${provider.shortLabel} 연결을 확인해 주세요.';
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _testing.remove(provider));
    }
  }

  Future<void> _testAll(List<AiProvider> providers) async {
    if (_testingAll || providers.isEmpty) return;
    setState(() => _testingAll = true);
    var success = 0;
    for (final provider in providers) {
      if (await _test(provider, notify: false)) success++;
    }
    if (!mounted) return;
    setState(() {
      _testingAll = false;
      _feedbackSuccess = success == providers.length;
      _feedbackMessage = '${providers.length}개 중 $success개 AI 연결이 정상입니다.';
    });
  }

  Future<void> _openModelPicker(AiProvider provider) async {
    final settings = context.read<AiSettingsProvider>();
    final identity = MemorizeIdentity.of(Theme.of(context));
    final candidates =
        <String>{
          settings.selectedModelFor(provider),
          ..._catalogFor(provider).models,
        }.toList();
    final availability = <String, bool?>{
      for (final model in candidates) model: null,
    };
    var scanStarted = false;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder: (sheetContext, refresh) {
              Future<void> scan() async {
                for (final model in candidates) {
                  if (!sheetContext.mounted) return;
                  final ok = await _test(provider, model: model, notify: false);
                  if (!sheetContext.mounted) return;
                  refresh(() => availability[model] = ok);
                }
              }

              if (!scanStarted) {
                scanStarted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) => scan());
              }
              return SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.78,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${provider.shortLabel} 모델 변경',
                              style: Theme.of(sheetContext).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '등록된 API 키로 후보 모델을 확인하고 있습니다.',
                              style: TextStyle(color: identity.mutedInk),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                          children:
                              candidates.map((model) {
                                final available = availability[model];
                                return ListTile(
                                  title: Text(
                                    model,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    available == null
                                        ? '사용 가능 여부 확인 중'
                                        : available
                                        ? '사용 가능'
                                        : '현재 키로 사용할 수 없음',
                                  ),
                                  leading:
                                      available == null
                                          ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : Icon(
                                            available
                                                ? CupertinoIcons
                                                    .check_mark_circled_solid
                                                : CupertinoIcons
                                                    .xmark_circle_fill,
                                            color:
                                                available
                                                    ? identity.success
                                                    : identity.review,
                                          ),
                                  enabled: available == true,
                                  selected:
                                      settings.selectedModelFor(provider) ==
                                      model,
                                  onTap:
                                      available == true
                                          ? () {
                                            settings.setModel(provider, model);
                                            Navigator.pop(sheetContext);
                                          }
                                          : null,
                                );
                              }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final settings = context.watch<AiSettingsProvider>();
    final providers = _orderedRegistered(settings);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!widget.embedded) ...[
          Text(
            'AI 설정',
            style: theme.textTheme.titleLarge?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '등록한 AI와 사용 순서를 관리합니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: identity.mutedInk,
            ),
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: _AddProviderButton(
                label: '무료 AI 추가',
                icon: CupertinoIcons.gift_fill,
                background: identity.softSuccess,
                foreground: identity.success,
                onTap: () => _openSetup(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AddProviderButton(
                label: '보유 키 추가',
                icon: Icons.key_rounded,
                background: identity.softContext,
                foreground: identity.primaryAction,
                onTap: () => _openSetup(false),
              ),
            ),
          ],
        ),
        if (_feedbackMessage != null) ...[
          const SizedBox(height: 12),
          _ConnectionFeedback(
            message: _feedbackMessage!,
            success: _feedbackSuccess,
            onClose: () => setState(() => _feedbackMessage = null),
          ),
        ],
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          child: SwitchListTile.adaptive(
            title: const Text(
              '자동 대체',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('주 모델 실패 시 아래 순서대로 요청합니다.'),
            value: settings.autoFallbackEnabled,
            onChanged: settings.setAutoFallbackEnabled,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '등록된 AI',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: identity.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Text(
              '끌어서 우선순위 변경',
              style: theme.textTheme.labelSmall?.copyWith(
                color: identity.mutedInk,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (providers.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: identity.surface,
              borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
              border: Border.all(color: identity.border),
            ),
            child: Text(
              '아직 등록된 AI가 없습니다. 위 버튼으로 연결해 주세요.',
              style: TextStyle(color: identity.mutedInk),
              textAlign: TextAlign.center,
            ),
          )
        else
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: providers.length,
            onReorderItem: (oldIndex, newIndex) {
              final reordered = [...providers];
              final moved = reordered.removeAt(oldIndex);
              reordered.insert(newIndex, moved);
              settings.setProviderPriority(reordered);
            },
            itemBuilder: (context, index) {
              final provider = providers[index];
              return Padding(
                key: ValueKey(provider),
                padding: const EdgeInsets.only(bottom: 10),
                child: _RegisteredProviderCard(
                  provider: provider,
                  model: settings.selectedModelFor(provider),
                  isMain: index == 0,
                  activeInRouting:
                      index == 0 || settings.autoFallbackEnabled,
                  freeFirst:
                      settings.wasAddedFromFreeSetup(provider) ??
                      _catalogFor(provider).isFreeFirst,
                  testing: _testing.contains(provider),
                  index: index,
                  onModelTap: () => _openModelPicker(provider),
                  onTest: () => _test(provider),
                ),
              );
            },
          ),
        if (providers.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _testingAll ? null : () => _testAll(providers),
              icon:
                  _testingAll
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(CupertinoIcons.check_mark_circled),
              label: Text(_testingAll ? '전체 연결 확인 중...' : '등록된 AI 전체 연결 테스트'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          'API 키는 기기의 보안 저장소에만 보관됩니다. 모델 확인과 AI 생성은 각 제공업체의 API 사용량을 소모할 수 있습니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: identity.mutedInk,
            height: 1.4,
          ),
        ),
      ],
    );

    return widget.embedded
        ? Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: content,
        )
        : content;
  }
}

class _ConnectionFeedback extends StatelessWidget {
  const _ConnectionFeedback({
    required this.message,
    required this.success,
    required this.onClose,
  });

  final String message;
  final bool success;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final identity = MemorizeIdentity.of(Theme.of(context));
    final color = success ? identity.success : identity.review;
    final background = success ? identity.softSuccess : identity.softReview;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 10, 7, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(
            success
                ? CupertinoIcons.check_mark_circled_solid
                : CupertinoIcons.exclamationmark_circle_fill,
            color: color,
            size: 21,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: '닫기',
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
            icon: Icon(CupertinoIcons.xmark, color: color, size: 17),
          ),
        ],
      ),
    );
  }
}

class _AddProviderButton extends StatelessWidget {
  const _AddProviderButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: background,
        foregroundColor: foreground,
        elevation: 0,
        shape: const StadiumBorder(),
      ),
    );
  }
}

class _RegisteredProviderCard extends StatelessWidget {
  const _RegisteredProviderCard({
    required this.provider,
    required this.model,
    required this.isMain,
    required this.activeInRouting,
    required this.freeFirst,
    required this.testing,
    required this.index,
    required this.onModelTap,
    required this.onTest,
  });

  final AiProvider provider;
  final String model;
  final bool isMain;
  final bool activeInRouting;
  final bool freeFirst;
  final bool testing;
  final int index;
  final VoidCallback onModelTap;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final activeBackground =
        freeFirst ? identity.softSuccess : identity.softContext;
    final background =
        activeInRouting
            ? activeBackground
            : Color.alphaBlend(
              identity.mutedInk.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.12 : 0.07,
              ),
              identity.surface,
            );
    final accent =
        activeInRouting
            ? (freeFirst ? identity.success : identity.primaryAction)
            : identity.mutedInk;
    final titleColor = activeInRouting ? identity.ink : identity.mutedInk;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Icon(
                CupertinoIcons.line_horizontal_3,
                color: identity.mutedInk,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        provider.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: identity.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        isMain ? 'Main' : '${index + 1}순위',
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: onModelTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: identity.surface.withValues(alpha: 0.76),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            model,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          CupertinoIcons.chevron_down,
                          size: 14,
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: testing ? null : onTest,
            child:
                testing
                    ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('연결 테스트'),
          ),
        ],
      ),
    );
  }
}
