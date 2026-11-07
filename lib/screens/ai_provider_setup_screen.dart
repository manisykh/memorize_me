import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/ai_provider_catalog.dart';
import '../providers/ai_settings_provider.dart';
import '../services/ai_service.dart';
import '../services/api_key_service.dart';
import '../services/app_config_service.dart';
import '../themes/memorize_identity.dart';

class AiProviderSetupScreen extends StatefulWidget {
  const AiProviderSetupScreen({super.key, this.freeFirst = true});

  final bool freeFirst;

  @override
  State<AiProviderSetupScreen> createState() => _AiProviderSetupScreenState();
}

class _AiProviderSetupScreenState extends State<AiProviderSetupScreen> {
  late bool _showFreeProviders;
  AiProviderCatalogEntry? _selected;
  int _step = 0;
  bool _obscureKey = true;
  bool _isTesting = false;
  bool _connectionSucceeded = false;
  String? _connectionMessage;
  final _apiKeyController = TextEditingController();
  final _endpointController = TextEditingController();
  final _modelController = TextEditingController();

  String? get _customEndpointError {
    if (_selected?.provider != AiProvider.customOpenAI) return null;
    final value = _endpointController.text.trim();
    if (value.isEmpty) return 'HTTPS endpoint를 입력하세요.';
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      return '보안을 위해 https:// 주소만 사용할 수 있습니다.';
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _showFreeProviders = widget.freeFirst;
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _endpointController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final config = context.watch<AppConfigService>();
    final catalog =
        AiProviderCatalog.resolve(
          config.aiProviderCatalogJson,
        ).where((entry) => entry.visible).toList();

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(
        backgroundColor: identity.canvas,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _showFreeProviders ? '무료 API로 시작' : '보유한 API 키 연결',
          style: TextStyle(color: identity.ink, fontWeight: FontWeight.w900),
        ),
        leading: CloseButton(onPressed: () => Navigator.maybePop(context)),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _StepHeader(
              step: _step,
              identity: identity,
              onStepTap: (step) {
                if (step <= _step) {
                  setState(() {
                    _step = step;
                    _connectionSucceeded = false;
                    _connectionMessage = null;
                  });
                }
              },
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 120),
                child: switch (_step) {
                  0 => _buildProviderStep(context, catalog, config),
                  1 => _buildKeyStep(context),
                  _ => _buildTestStep(context),
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: identity.canvas,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
          child: _buildBottomAction(context),
        ),
      ),
    );
  }

  Widget _buildProviderStep(
    BuildContext context,
    List<AiProviderCatalogEntry> catalog,
    AppConfigService config,
  ) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final entries =
        catalog
            .where(
              (entry) =>
                  _showFreeProviders
                      ? entry.appearsInFreeSetup
                      : entry.appearsInOwnedSetup,
            )
            .toList()
          ..sort((a, b) {
            if (a.recommended == b.recommended) return 0;
            return a.recommended ? -1 : 1;
          });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _showFreeProviders ? '어떤 AI를 연결할까요?' : '이미 사용 중인 AI가 있나요?',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _showFreeProviders
              ? '무료 정책과 가입 편의성을 기준으로 정리했어요. 무료 한도와 모델은 제공업체 정책에 따라 바뀔 수 있습니다.'
              : '구독 서비스와 API 요금은 별개일 수 있어요. API 키와 결제 한도를 먼저 확인해 주세요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: identity.mutedInk,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        _FreshnessNotice(
          verifiedAt: config.aiProviderCatalogVerifiedAt,
          identity: identity,
        ),
        const SizedBox(height: 16),
        ...entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ProviderChoiceCard(
              entry: entry,
              selected: _selected?.provider == entry.provider,
              identity: identity,
              freeSetup: _showFreeProviders,
              onTap: () => _selectProvider(entry),
              onCopyUrl: () => _copyConsoleUrl(entry),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Center(
          child: TextButton.icon(
            onPressed:
                () => setState(() {
                  _showFreeProviders = !_showFreeProviders;
                  _selected = null;
                }),
            icon: Icon(
              _showFreeProviders ? Icons.key_rounded : CupertinoIcons.gift,
              size: 18,
            ),
            label: Text(
              _showFreeProviders ? '보유한 API 키를 직접 연결할게요' : '무료로 시작할 수 있는 AI 보기',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyStep(BuildContext context) {
    final entry = _selected!;
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final provider = entry.provider;
    final models = entry.models;
    final selectedModel =
        _modelController.text.isEmpty ? models.first : _modelController.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SelectedProviderSummary(
          entry: entry,
          identity: identity,
          freeSetup: _showFreeProviders,
        ),
        const SizedBox(height: 18),
        Text(
          'API 키 발급 방법',
          style: theme.textTheme.titleLarge?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          child: Column(
            children: [
              for (var index = 0; index < entry.guideSteps.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == entry.guideSteps.length - 1 ? 0 : 10,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: identity.softInfo,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: identity.primaryAction,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          entry.guideSteps[index],
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: identity.ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (entry.consoleUrl.isNotEmpty) ...[
                const Divider(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: () => _copyConsoleUrl(entry),
                    icon: const Icon(CupertinoIcons.doc_on_doc, size: 17),
                    label: const Text('API 키 발급 주소 복사'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          '연결 정보',
          style: theme.textTheme.titleLarge?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          key: ValueKey(provider),
          initialValue: models.contains(selectedModel) ? selectedModel : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: '사용 모델'),
          items:
              models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model,
                      child: Text(model, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
          onChanged: (value) {
            if (value != null) _modelController.text = value;
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _apiKeyController,
          obscureText: _obscureKey,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: '${provider.shortLabel} API 키',
            hintText: '발급받은 키 붙여넣기',
            suffixIcon: IconButton(
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
              icon: Icon(
                _obscureKey ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
              ),
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (provider == AiProvider.customOpenAI) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _endpointController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Chat Completions endpoint',
              hintText: 'https://example.com/v1/chat/completions',
            ).copyWith(errorText: _customEndpointError),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            decoration: const InputDecoration(
              labelText: '모델 ID',
              hintText: 'provider/model-name',
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
        const SizedBox(height: 14),
        _SecurityNotice(identity: identity),
      ],
    );
  }

  Widget _buildTestStep(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final entry = _selected!;
    final color =
        _connectionSucceeded
            ? identity.success
            : _connectionMessage == null
            ? identity.primaryAction
            : identity.review;

    return Column(
      children: [
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.11),
            shape: BoxShape.circle,
          ),
          child:
              _isTesting
                  ? Padding(
                    padding: const EdgeInsets.all(27),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: color,
                    ),
                  )
                  : Icon(
                    _connectionSucceeded
                        ? CupertinoIcons.check_mark_circled_solid
                        : _connectionMessage == null
                        ? CupertinoIcons.link_circle_fill
                        : CupertinoIcons.exclamationmark_circle_fill,
                    size: 48,
                    color: color,
                  ),
        ),
        const SizedBox(height: 18),
        Text(
          _isTesting
              ? '연결을 확인하고 있어요'
              : _connectionSucceeded
              ? '${entry.provider.shortLabel} 연결 완료'
              : _connectionMessage == null
              ? '마지막으로 연결을 확인해요'
              : '연결 정보를 다시 확인해 주세요',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _connectionMessage ?? '짧은 테스트 요청을 보내 API 키와 모델이 정상적으로 작동하는지 확인합니다.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: identity.mutedInk,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        _SelectedProviderSummary(
          entry: entry,
          identity: identity,
          freeSetup: _showFreeProviders,
        ),
        const SizedBox(height: 12),
        _SecurityNotice(identity: identity),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    final identity = MemorizeIdentity.of(Theme.of(context));
    final enabled = switch (_step) {
      0 => _selected != null,
      1 =>
        _apiKeyController.text.trim().isNotEmpty &&
            (_selected?.provider != AiProvider.customOpenAI ||
                (_endpointController.text.trim().isNotEmpty &&
                    _customEndpointError == null &&
                    _modelController.text.trim().isNotEmpty)),
      _ => !_isTesting,
    };
    final label = switch (_step) {
      0 =>
        _selected == null
            ? 'AI 제공업체를 선택하세요'
            : '${_selected!.provider.shortLabel}로 계속',
      1 => '안전하게 저장하고 계속',
      _ => _connectionSucceeded ? 'AI 학습 시작' : '연결 확인',
    };

    final primaryButton = FilledButton(
      onPressed: enabled ? _handlePrimaryAction : null,
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: identity.primaryAction,
        foregroundColor: Colors.white,
        shape: const StadiumBorder(),
      ),
      child: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );

    if (_step == 0) return primaryButton;

    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _isTesting ? null : _goToPreviousStep,
          icon: const Icon(CupertinoIcons.chevron_left, size: 18),
          label: const Text('이전'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(104, 54),
            foregroundColor: identity.ink,
            side: BorderSide(color: identity.border),
            shape: const StadiumBorder(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: primaryButton),
      ],
    );
  }

  void _goToPreviousStep() {
    if (_step <= 0) return;
    setState(() {
      _step--;
      _connectionSucceeded = false;
      _connectionMessage = null;
    });
  }

  void _selectProvider(AiProviderCatalogEntry entry) {
    setState(() {
      _selected = entry;
      _apiKeyController.clear();
      _endpointController.clear();
      _modelController.text = entry.models.first;
      _connectionMessage = null;
      _connectionSucceeded = false;
    });
  }

  Future<void> _copyConsoleUrl(AiProviderCatalogEntry entry) async {
    if (entry.consoleUrl.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: entry.consoleUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('API 키 발급 주소를 복사했습니다. 브라우저 주소창에 붙여넣으세요.')),
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (_step == 0) {
      setState(() => _step = 1);
      return;
    }
    if (_step == 1) {
      final provider = _selected!.provider;
      final settings = context.read<AiSettingsProvider>();
      await context.read<ApiKeyService>().saveApiKey(
        provider,
        _apiKeyController.text.trim(),
      );
      settings.setProvider(provider);
      settings.setModel(
        provider,
        _modelController.text.trim().isEmpty
            ? _selected!.models.first
            : _modelController.text.trim(),
      );
      settings.setSetupSource(provider, freeSetup: _showFreeProviders);
      if (provider == AiProvider.customOpenAI) {
        settings.setCustomOpenAiEndpoint(_endpointController.text.trim());
      }
      if (!mounted) return;
      setState(() => _step = 2);
      return;
    }
    if (_connectionSucceeded) {
      Navigator.of(context).pop(true);
      return;
    }
    await _testConnection();
  }

  Future<void> _testConnection() async {
    if (_isTesting) return;
    final provider = _selected!.provider;
    final settings = context.read<AiSettingsProvider>();
    setState(() {
      _isTesting = true;
      _connectionMessage = null;
    });
    try {
      await context.read<AiService>().testConnection(
        provider: provider,
        modelName: settings.selectedModelFor(provider),
        endpoint: settings.endpointFor(provider),
      );
      if (!mounted) return;
      setState(() {
        _connectionSucceeded = true;
        _connectionMessage = 'API 키와 모델 연결이 정상입니다. 이제 예문과 퀴즈를 만들 수 있어요.';
      });
    } on CustomApiException catch (error) {
      if (!mounted) return;
      setState(() => _connectionMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _connectionMessage = '연결에 실패했습니다. API 키, 모델과 제공업체의 사용 한도를 확인해 주세요.',
      );
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.identity,
    required this.onStepTap,
  });

  final int step;
  final MemorizeIdentity identity;
  final ValueChanged<int> onStepTap;

  @override
  Widget build(BuildContext context) {
    const labels = ['제공업체 선택', 'API 키 연결', '연결 확인'];
    return Container(
      color: identity.surface,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      child: Row(
        children: List.generate(labels.length, (index) {
          final active = index <= step;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: index <= step ? () => onStepTap(index) : null,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 15,
                          backgroundColor:
                              active
                                  ? identity.primaryAction
                                  : identity.softInfo,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              color: active ? Colors.white : identity.mutedInk,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[index],
                          maxLines: 1,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(
                            color:
                                active
                                    ? identity.primaryAction
                                    : identity.mutedInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (index < labels.length - 1)
                  Container(
                    width: 18,
                    height: 1,
                    color:
                        active && index < step
                            ? identity.primaryAction
                            : identity.border,
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _ProviderChoiceCard extends StatelessWidget {
  const _ProviderChoiceCard({
    required this.entry,
    required this.selected,
    required this.identity,
    required this.freeSetup,
    required this.onTap,
    required this.onCopyUrl,
  });

  final AiProviderCatalogEntry entry;
  final bool selected;
  final MemorizeIdentity identity;
  final bool freeSetup;
  final VoidCallback onTap;
  final VoidCallback onCopyUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = selected ? identity.primaryAction : identity.mutedInk;
    return Material(
      color: selected ? identity.softContext : identity.surface,
      borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(
              color:
                  selected
                      ? identity.primaryAction.withValues(alpha: 0.48)
                      : identity.border,
            ),
          ),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle,
                    color: accent,
                    size: 23,
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
                                entry.provider.label,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: identity.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (entry.recommended)
                              _Badge(
                                label: '초보 추천',
                                color: identity.primaryAction,
                              ),
                            const SizedBox(width: 5),
                            _Badge(
                              label: entry.setupAccessLabel(
                                freeSetup: freeSetup,
                              ),
                              color: identity.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          entry.setupSummary(freeSetup: freeSetup),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: identity.mutedInk,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (entry.requiresPaymentMethod) ...[
                          const SizedBox(height: 6),
                          Text(
                            '결제수단 등록이 필요할 수 있어요.',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: identity.review,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (selected && entry.consoleUrl.isNotEmpty) ...[
                const Divider(height: 22),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onCopyUrl,
                    icon: const Icon(CupertinoIcons.doc_on_doc, size: 16),
                    label: const Text('발급 주소 복사'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedProviderSummary extends StatelessWidget {
  const _SelectedProviderSummary({
    required this.entry,
    required this.identity,
    required this.freeSetup,
  });

  final AiProviderCatalogEntry entry;
  final MemorizeIdentity identity;
  final bool freeSetup;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: identity.softContext,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(
          color: identity.primaryAction.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: identity.surface,
            foregroundColor: identity.primaryAction,
            child: const Icon(CupertinoIcons.sparkles),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.provider.label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${entry.setupAccessLabel(freeSetup: freeSetup)} · ${entry.models.first}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FreshnessNotice extends StatelessWidget {
  const _FreshnessNotice({required this.verifiedAt, required this.identity});

  final String verifiedAt;
  final MemorizeIdentity identity;

  @override
  Widget build(BuildContext context) {
    final checkedAt = DateTime.tryParse(verifiedAt);
    final isStale =
        checkedAt == null || DateTime.now().difference(checkedAt).inDays > 45;
    final color = isStale ? identity.scheduled : identity.success;
    return Row(
      children: [
        Icon(
          isStale
              ? CupertinoIcons.exclamationmark_shield
              : CupertinoIcons.checkmark_shield,
          size: 17,
          color: color,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            isStale
                ? '마지막 정책 확인 $verifiedAt · 연결 전 제공업체 안내를 다시 확인해 주세요.'
                : '공식 정책 확인 $verifiedAt · 앱 실행 시 최신 목록을 확인합니다.',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice({required this.identity});

  final MemorizeIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: identity.softSuccess,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            CupertinoIcons.lock_shield_fill,
            size: 20,
            color: identity.success,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              'API 키는 이 기기의 보안 저장소에만 저장됩니다. 생성 요청 시 선택한 단어와 학습 설정은 해당 AI 제공업체로 직접 전송됩니다.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: identity.mutedInk,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
