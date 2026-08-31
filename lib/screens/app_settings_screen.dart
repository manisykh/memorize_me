import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../providers/entitlement_provider.dart';
import '../providers/theme_provider.dart';
import '../services/study_sound_service.dart';
import '../themes/app_theme.dart';
import '../widgets/ai_settings_card.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/study_guide.dart';
import 'onboarding_screen.dart';
import 'select_spreadsheet_screen.dart';
import 'tts_settings_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  static const _recentSpreadsheetsKey = 'recent_google_spreadsheets';

  bool _isAiSettingsExpanded = false;
  bool _isAccountActionRunning = false;
  int _connectedSheetCount = 0;

  @override
  void initState() {
    super.initState();
    _loadConnectedSheetCount();
  }

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
              _buildGoogleAccountSection(context),

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
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      secondary: const Icon(CupertinoIcons.music_note_2),
                      title: const Text('학습 효과음'),
                      subtitle: const Text('정답·오답과 카드 스와이프를 소리로 구분'),
                      value: context.watch<StudySoundService>().enabled,
                      onChanged:
                          (value) => context.read<StudySoundService>().setEnabled(value),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
                      leading: const Icon(CupertinoIcons.speaker_2_fill),
                      title: const Text('TTS 목소리 설정'),
                      trailing: const Icon(CupertinoIcons.right_chevron),
                      onTap:
                          () => Navigator.of(
                            context,
                          ).push(MaterialPageRoute(builder: (_) => const TtsSettingsScreen())),
                    ),
                  ],
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

  Future<void> _loadConnectedSheetCount() async {
    final preferences = await SharedPreferences.getInstance();
    final count = preferences.getStringList(_recentSpreadsheetsKey)?.length ?? 0;
    if (!mounted) return;
    setState(() => _connectedSheetCount = count);
  }

  Future<void> _clearConnectedSheetHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_recentSpreadsheetsKey);
    if (!mounted) return;
    setState(() => _connectedSheetCount = 0);
  }

  Future<void> _connectGoogleAccount() async {
    if (_isAccountActionRunning) return;
    setState(() => _isAccountActionRunning = true);
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.signIn();
      if (!mounted) return;
      if (authProvider.isGoogleDriveConnected) {
        await context.read<EntitlementProvider>().refresh();
        if (!mounted) return;
        _showMessage('Google 계정이 연결되었습니다.');
      } else {
        _showMessage('Google 계정 연결이 취소되었습니다.');
      }
    } catch (error) {
      if (mounted) _showMessage(_readableError(error));
    } finally {
      if (mounted) setState(() => _isAccountActionRunning = false);
    }
  }

  Future<void> _openConnectedSheets() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen()),
    );
    await _loadConnectedSheetCount();
  }

  Future<void> _disconnectGoogleDrive() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Google Drive 연결을 해제할까요?'),
            content: const Text(
              'Google 시트 접근 권한과 최근 연결 목록만 해제합니다. '
              '이미 가져온 단어장, 학습 기록과 Founding 혜택은 유지됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('연결 해제'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isAccountActionRunning = true);
    try {
      await context.read<AuthProvider>().disconnectGoogleDrive();
      await _clearConnectedSheetHistory();
      if (mounted) {
        _showMessage('Google Drive 연결을 해제했습니다. 로컬 학습 데이터는 유지됩니다.');
      }
    } catch (error) {
      if (mounted) _showMessage(_readableError(error));
    } finally {
      if (mounted) setState(() => _isAccountActionRunning = false);
    }
  }

  Future<void> _deleteCloudAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('계정과 클라우드 혜택을 삭제할까요?'),
            content: const Text(
              'Google 계정에 연결된 앱 계정과 Founding 혜택, 최근 Google 시트 연결 기록을 영구 삭제합니다. '
              '가져온 로컬 단어장과 학습 기록은 유지됩니다. Founding 등록 기간이 끝난 뒤에는 혜택을 복구할 수 없습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isAccountActionRunning = true);
    try {
      final authProvider = context.read<AuthProvider>();
      await authProvider.reauthenticateForCloudDeletion();
      await context.read<EntitlementProvider>().deleteCloudIdentity();
      await authProvider.disconnectGoogleDrive();
      await _clearConnectedSheetHistory();
      if (mounted) {
        _showMessage('계정과 클라우드 혜택을 삭제했습니다. 로컬 학습 데이터는 유지됩니다.');
      }
    } catch (error) {
      if (mounted) _showMessage(_readableError(error));
    } finally {
      if (mounted) setState(() => _isAccountActionRunning = false);
    }
  }

  Widget _buildGoogleAccountSection(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final authProvider = context.watch<AuthProvider>();
    final entitlement = context.watch<EntitlementProvider>();
    final googleUser = authProvider.currentUser;
    final isConnected = authProvider.isGoogleDriveConnected;
    final hasCloudIdentity = authProvider.hasGoogleCloudIdentity;
    final isFounding = entitlement.isFoundingMember && entitlement.isServerConfirmed;
    final isProtected = isFounding && hasCloudIdentity;
    final isBusy =
        _isAccountActionRunning || authProvider.isLoading || entitlement.loading;
    final accountEmail = googleUser?.email ?? authProvider.cloudIdentityEmail;

    final foundingTitle =
        isProtected
            ? 'Founding 혜택 보호됨'
            : isFounding
            ? 'Founding 혜택 활성화됨'
            : entitlement.loading
            ? 'Founding 혜택 확인 중'
            : 'Founding 혜택 등록 준비 중';
    final foundingDescription =
        isProtected
            ? '${accountEmail ?? 'Google 계정'}에 연결되어 다른 기기에서 복원할 수 있습니다.'
            : isFounding
            ? '현재 기기에서 사용할 수 있습니다. Google 계정에 연결하면 다른 기기에서도 복원할 수 있습니다.'
            : '네트워크 연결 후 자동으로 등록 상태를 확인합니다.';

    return GlassmorphicCard(
      borderRadius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (googleUser != null)
                GoogleUserCircleAvatar(identity: googleUser)
              else
                Container(
                  width: 42,
                  height: 42,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset('assets/icons/google_logo.png'),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? googleUser?.displayName ?? 'Google 계정 연결됨'
                          : hasCloudIdentity
                          ? 'Google Drive 연결 해제됨'
                          : 'Google 계정 연결',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      accountEmail ??
                          (isConnected
                              ? 'Google 시트와 Founding 혜택에 사용됩니다.'
                              : '로그인 없이도 앱의 기본 기능을 사용할 수 있습니다.'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '연결됨',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isConnected
                ? 'Google Drive에서 선택한 시트만 가져옵니다. 연결을 해제해도 이미 만든 단어장은 기기에 남습니다.'
                : hasCloudIdentity
                ? 'Founding 혜택은 계정에 보관되어 있습니다. Google 시트를 가져올 때 Drive를 다시 연결하세요.'
                : 'Google 시트 가져오기와 Founding 혜택의 다른 기기 복원에만 계정을 사용합니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isProtected
                      ? CupertinoIcons.shield_lefthalf_fill
                      : isFounding
                      ? CupertinoIcons.rosette
                      : CupertinoIcons.clock,
                  size: 22,
                  color: colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        foundingTitle,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        foundingDescription,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!entitlement.loading && !isFounding)
                  IconButton(
                    tooltip: '다시 확인',
                    onPressed: isBusy ? null : entitlement.refresh,
                    icon: const Icon(CupertinoIcons.refresh, size: 20),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (isConnected) ...[
            OutlinedButton.icon(
              onPressed: isBusy ? null : _openConnectedSheets,
              icon: const Icon(CupertinoIcons.doc_on_doc),
              label: Text(
                _connectedSheetCount > 0
                    ? '연결된 시트 관리 ($_connectedSheetCount)'
                    : 'Google 시트 선택',
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: isBusy ? null : _disconnectGoogleDrive,
              icon: const Icon(CupertinoIcons.link),
              label: const Text('Google Drive 연결 해제'),
            ),
          ] else
            FilledButton.icon(
              onPressed: isBusy ? null : _connectGoogleAccount,
              icon:
                  isBusy
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Image.asset(
                        'assets/icons/google_logo.png',
                        width: 19,
                        height: 19,
                      ),
              label: Text(
                hasCloudIdentity ? 'Google Drive 다시 연결' : 'Google 계정 연결',
              ),
            ),
          const SizedBox(height: 6),
          Divider(color: colors.outlineVariant),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: colors.error),
            onPressed: isBusy ? null : _deleteCloudAccount,
            icon: const Icon(CupertinoIcons.delete, size: 19),
            label: const Text('계정 및 클라우드 혜택 삭제'),
          ),
          Text(
            '앱 계정과 Founding 혜택을 영구 삭제합니다. 로컬 학습 데이터는 유지됩니다.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _readableError(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('StateError: ', '')
        .replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
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
