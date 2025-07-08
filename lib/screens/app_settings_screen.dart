import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../providers/ai_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/api_key_service.dart';
import '../themes/app_theme.dart';
import '../widgets/glassmorphic_card.dart';
import 'tts_settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _isGeminiKeyRegistered = false;
  bool _isOpenAiKeyRegistered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiStatus();
    });
  }

  Future<void> _checkApiStatus() async {
    if (!mounted) return;
    final apiKeyService = context.read<ApiKeyService>();
    final geminiKey = await apiKeyService.getApiKey(AiProvider.gemini);
    final openAiKey = await apiKeyService.getApiKey(AiProvider.openAI);
    if (mounted) {
      setState(() {
        _isGeminiKeyRegistered = (geminiKey != null && geminiKey.isNotEmpty);
        _isOpenAiKeyRegistered = (openAiKey != null && openAiKey.isNotEmpty);
      });
    }
  }

  Future<void> _showApiKeyDialog(AiProvider provider) async {
    final apiKeyController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('${provider.name} API 키 등록'),
            content: TextField(controller: apiKeyController, obscureText: true),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('취소')),
              TextButton(
                onPressed: () async {
                  if (apiKeyController.text.isNotEmpty) {
                    await context.read<ApiKeyService>().saveApiKey(provider, apiKeyController.text);
                    if (mounted) Navigator.pop(dialogContext);
                    await _checkApiStatus();
                  }
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('앱 설정'), automaticallyImplyLeading: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('계정', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              _buildAuthSection(context),

              const SizedBox(height: 24),
              Text('디자인', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              _buildThemeSettingsSection(context),

              const SizedBox(height: 24),
              Text('소리', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              GlassmorphicCard(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  leading: const Icon(CupertinoIcons.speaker_2_fill),
                  title: const Text('TTS 목소리 설정'),
                  trailing: const Icon(CupertinoIcons.right_chevron),
                  onTap:
                      () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => const TtsSettingsScreen())),
                ),
              ),

              const SizedBox(height: 24),
              Text('AI 설정', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              _buildAiSettingsSection(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthSection(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final user = authProvider.currentUser;

    if (authProvider.isLoading) return const Center(child: CircularProgressIndicator());

    return GlassmorphicCard(
      child: user != null ? _buildLoggedInUser(context, user) : _buildLoginButton(context),
    );
  }

  Widget _buildLoggedInUser(BuildContext context, GoogleSignInAccount user) {
    final theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: GoogleUserCircleAvatar(identity: user),
      title: Text(
        user.displayName ?? 'No Name',
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(user.email, style: theme.textTheme.bodyMedium),
      trailing: IconButton(
        icon: const Icon(Icons.logout),
        onPressed: () => context.read<AuthProvider>().signOut(),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => context.read<AuthProvider>().signIn(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/google_logo.png', height: 24, width: 24),
            const SizedBox(width: 12),
            Text('Google 계정으로 로그인', style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSettingsSection(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    return GlassmorphicCard(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          RadioListTile<AppThemeType>(
            title: const Text('기본 (밝음)'),
            value: AppThemeType.lightGreen,
            groupValue: themeNotifier.currentTheme,
            onChanged: (value) {
              if (value != null) themeNotifier.setTheme(value);
            },
          ),
          RadioListTile<AppThemeType>(
            title: const Text('어두운 테마'),
            value: AppThemeType.dark,
            groupValue: themeNotifier.currentTheme,
            onChanged: (value) {
              if (value != null) themeNotifier.setTheme(value);
            },
          ),
          RadioListTile<AppThemeType>(
            title: const Text('시력 보호'),
            value: AppThemeType.visionProtection,
            groupValue: themeNotifier.currentTheme,
            onChanged: (value) {
              if (value != null) themeNotifier.setTheme(value);
            },
          ),
          if (themeNotifier.currentTheme == AppThemeType.visionProtection)
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0, 16.0, 8.0),
              child: Row(
                children: [
                  Text("배경 농도", style: Theme.of(context).textTheme.bodyMedium),
                  Expanded(
                    child: Slider(
                      value: themeNotifier.eyeCareLevel.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: "Level ${themeNotifier.eyeCareLevel}",
                      onChanged: (value) {
                        themeNotifier.setEyeCareLevel(value.toInt());
                      },
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiSettingsSection(BuildContext context) {
    final aiSettings = context.watch<AiSettingsProvider>();

    // ▼▼▼ [수정] 제공해주신 표와 스크린샷에 맞게 모델 목록을 업데이트합니다. ▼▼▼
    final List<String> geminiModels = [
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
    ];
    final List<String> openAiModels = ['gpt-4o', 'gpt-4-turbo', 'gpt-3.5-turbo'];

    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildApiStatusRow(provider: AiProvider.gemini, isRegistered: _isGeminiKeyRegistered),
            const Divider(height: 24),
            _buildApiStatusRow(provider: AiProvider.openAI, isRegistered: _isOpenAiKeyRegistered),
            const Divider(height: 24),
            SegmentedButton<AiProvider>(
              segments: const [
                ButtonSegment(value: AiProvider.gemini, label: Text('Gemini')),
                ButtonSegment(value: AiProvider.openAI, label: Text('GPT')),
              ],
              selected: {aiSettings.selectedProvider},
              onSelectionChanged: (newSelection) {
                aiSettings.setProvider(newSelection.first);
              },
            ),
            const SizedBox(height: 8),
            if (aiSettings.selectedProvider == AiProvider.gemini)
              _buildModelDropdown(
                models: geminiModels,
                selectedValue: aiSettings.selectedGeminiModel,
                onChanged: (newValue) {
                  if (newValue != null) aiSettings.setGeminiModel(newValue);
                },
              )
            else
              _buildModelDropdown(
                models: openAiModels,
                selectedValue: aiSettings.selectedGptModel,
                onChanged: (newValue) {
                  if (newValue != null) aiSettings.setGptModel(newValue);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiStatusRow({required AiProvider provider, required bool isRegistered}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(provider.name, style: theme.textTheme.titleMedium),
        Row(
          children: [
            Text(
              isRegistered ? '등록 완료' : '등록 필요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isRegistered ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 30,
              child: OutlinedButton(
                onPressed: () => _showApiKeyDialog(provider),
                child: Text(isRegistered ? '관리' : '등록'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelDropdown({
    required List<String> models,
    required String selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    // 선택된 값이 목록에 없으면 첫 번째 값으로 대체 (안전장치)
    final valueInList = models.contains(selectedValue) ? selectedValue : models.first;

    return DropdownButton<String>(
      value: valueInList,
      isExpanded: true,
      underline: Container(height: 1, color: Theme.of(context).primaryColor.withOpacity(0.5)),
      onChanged: onChanged,
      items:
          models
              .map<DropdownMenuItem<String>>(
                (String value) => DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(),
    );
  }
}
