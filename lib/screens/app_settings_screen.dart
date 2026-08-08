import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/entitlement_provider.dart';
import '../providers/theme_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/ai_settings_card.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/study_guide.dart';
import 'onboarding_screen.dart';
import 'tts_settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _isAiSettingsExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: canPop ? AppBar(automaticallyImplyLeading: true) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '앱 설정',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: 29,
                  height: 1.08,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 18),
              _buildSectionTitle(theme, '계정'),
              const SizedBox(height: 12),
              _buildAuthSection(context),
              const SizedBox(height: 12),
              _buildFoundingStatus(context),

              const SizedBox(height: 24),
              _buildSectionTitle(theme, '디자인'),
              const SizedBox(height: 12),
              _buildThemeSettingsSection(context),

              const SizedBox(height: 24),
              _buildSectionTitle(theme, '가이드'),
              const SizedBox(height: 12),
              GlassmorphicCard(
                borderRadius: 14,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  leading: const Icon(CupertinoIcons.question_circle_fill),
                  title: const Text('사용 가이드'),
                  subtitle: const Text('오늘 학습, 학습 플랜, SRS 기준을 다시 보기'),
                  trailing: const Icon(CupertinoIcons.right_chevron),
                  onTap:
                      () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => const StudyGuideScreen())),
                ),
              ),
              const SizedBox(height: 12),
              GlassmorphicCard(
                borderRadius: 14,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                  leading: const Icon(CupertinoIcons.book_fill),
                  title: const Text('온보딩 다시 보기'),
                  subtitle: const Text('앱의 주요 기능 소개를 다시 봅니다.'),
                  trailing: const Icon(CupertinoIcons.right_chevron),
                  onTap:
                      () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => OnboardingScreen(
                                onFinished: () => Navigator.of(context).pop(),
                              ),
                        ),
                      ),
                ),
              ),

              const SizedBox(height: 24),
              _buildSectionTitle(theme, '소리'),
              const SizedBox(height: 12),
              GlassmorphicCard(
                borderRadius: 14,
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
              _buildAiSettingsExpansion(theme),
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
      borderRadius: 14,
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
      borderRadius: 14,
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

  Widget _buildFoundingStatus(BuildContext context) {
    final theme = Theme.of(context);
    final entitlement = context.watch<EntitlementProvider>();
    final registered = entitlement.isFoundingMember && entitlement.isServerConfirmed;

    return GlassmorphicCard(
      borderRadius: 14,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          registered ? CupertinoIcons.rosette : CupertinoIcons.clock,
          color: registered ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(
          registered ? 'Founding 혜택 등록 완료' : 'Founding 혜택 등록 준비 중',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          registered
              ? '향후 추가되는 유료 기능도 무료로 이용할 수 있습니다.'
              : '네트워크 연결 후 자동으로 등록합니다. Google 로그인 시 기기 변경 후에도 혜택을 복원할 수 있습니다.',
        ),
        trailing:
            entitlement.loading
                ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : registered
                ? Icon(CupertinoIcons.check_mark_circled_solid, color: theme.colorScheme.primary)
                : IconButton(
                  tooltip: '다시 확인',
                  onPressed: entitlement.refresh,
                  icon: const Icon(CupertinoIcons.refresh),
                ),
      ),
    );
  }

  Widget _buildAiSettingsExpansion(ThemeData theme) {
    return Column(
      children: [
        GlassmorphicCard(
          borderRadius: 14,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            leading: const Icon(CupertinoIcons.sparkles),
            title: Text(
              'AI 모델과 API',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('사용할 AI와 API 키, 자동 대체 후보를 관리합니다.'),
            trailing: AnimatedRotation(
              turns: _isAiSettingsExpanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 180),
              child: const Icon(CupertinoIcons.chevron_down),
            ),
            onTap:
                () => setState(() {
                  _isAiSettingsExpanded = !_isAiSettingsExpanded;
                }),
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child:
              _isAiSettingsExpanded
                  ? const Padding(
                    key: ValueKey('ai-settings-expanded'),
                    padding: EdgeInsets.only(top: 12),
                    child: AiSettingsCard(),
                  )
                  : const SizedBox.shrink(key: ValueKey('ai-settings-collapsed')),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

}
