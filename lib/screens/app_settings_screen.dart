import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/auth_provider.dart';
import '../providers/entitlement_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/study_sound_service.dart';
import '../themes/app_theme.dart';
import '../themes/memorize_identity.dart';
import '../widgets/ai_settings_card.dart';
import '../widgets/google_account_avatar.dart';
import '../widgets/study_guide.dart';
import 'onboarding_screen.dart';
import 'select_spreadsheet_screen.dart';
import 'tts_settings_screen.dart';
import 'wordbook_management_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  static const _recentSpreadsheetsKey = 'recent_google_spreadsheets';

  bool _isAccountSettingsExpanded = false;
  bool _isDesignSettingsExpanded = false;
  bool _isGuideSettingsExpanded = false;
  bool _isSoundSettingsExpanded = false;
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
    final identity = MemorizeIdentity.of(theme);
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final authProvider = context.watch<AuthProvider>();
    final themeNotifier = context.watch<ThemeNotifier>();
    final manager = context.watch<WordbookManager>();
    final activeWordbook = manager.activeWordbook;
    final googleUser = authProvider.currentUser;
    final accountStatus =
        authProvider.isGoogleDriveConnected
            ? '연결됨'
            : authProvider.hasGoogleCloudIdentity
            ? '계정 보관됨'
            : '연결 필요';

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: canPop ? AppBar(automaticallyImplyLeading: true) : null,
      body: SafeArea(
        child: SingleChildScrollView(
          key: const PageStorageKey<String>('memorize-settings-identity-v1'),
          padding: const EdgeInsets.fromLTRB(
            MemorizeIdentity.pagePadding,
            18,
            MemorizeIdentity.pagePadding,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '앱 설정',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: identity.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '앱 사용 환경을 설정하고 관리합니다.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: identity.mutedInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _SettingsGroup(
                identity: identity,
                children: [
                  _SettingsIdentityRow(
                    identity: identity,
                    leading:
                        googleUser != null
                            ? GoogleAccountAvatar(
                              account: googleUser,
                              radius: 24,
                            )
                            : _SettingsIconBadge(
                              icon: CupertinoIcons.person_crop_circle,
                              color: identity.primaryAction,
                              background: identity.softInfo,
                            ),
                    title: '계정과 Google 시트',
                    subtitle:
                        authProvider.isGoogleDriveConnected
                            ? 'Google 시트가 연결되어 있어요.'
                            : 'Google 연결과 클라우드 정보를 관리합니다.',
                    trailing: _SettingsStatusChip(
                      label: accountStatus,
                      color:
                          authProvider.isGoogleDriveConnected
                              ? identity.success
                              : identity.mutedInk,
                      background:
                          authProvider.isGoogleDriveConnected
                              ? identity.softSuccess
                              : identity.softContext,
                    ),
                    expanded: _isAccountSettingsExpanded,
                    onTap:
                        () => setState(
                          () =>
                              _isAccountSettingsExpanded =
                                  !_isAccountSettingsExpanded,
                        ),
                    expandedChild: _buildGoogleAccountSection(context),
                  ),
                  _SettingsIdentityRow(
                    identity: identity,
                    leading: _SettingsIconBadge(
                      icon: CupertinoIcons.paintbrush_fill,
                      color: identity.primaryAction,
                      background: identity.softInfo,
                    ),
                    title: '디자인',
                    subtitle: '밝음 · 어두움 · 시력 보호',
                    trailing: _ThemePreviewStrip(
                      selectedTheme: themeNotifier.currentTheme,
                    ),
                    expanded: _isDesignSettingsExpanded,
                    onTap:
                        () => setState(
                          () =>
                              _isDesignSettingsExpanded =
                                  !_isDesignSettingsExpanded,
                        ),
                    expandedChild: _buildThemeSettingsSection(context),
                  ),
                  _SettingsIdentityRow(
                    identity: identity,
                    leading: _SettingsIconBadge(
                      icon: CupertinoIcons.book,
                      color: identity.success,
                      background: identity.softSuccess,
                    ),
                    title: '가이드',
                    subtitle: '앱 사용법과 주요 기능을 확인합니다.',
                    expanded: _isGuideSettingsExpanded,
                    onTap:
                        () => setState(
                          () =>
                              _isGuideSettingsExpanded =
                                  !_isGuideSettingsExpanded,
                        ),
                    expandedChild: _buildGuideSettingsSection(),
                  ),
                  _SettingsIdentityRow(
                    identity: identity,
                    leading: _SettingsIconBadge(
                      icon: CupertinoIcons.speaker_2_fill,
                      color: identity.review,
                      background: identity.softReview,
                    ),
                    title: '소리와 음성',
                    subtitle: '효과음, 발음과 듣기 음성을 관리합니다.',
                    expanded: _isSoundSettingsExpanded,
                    onTap:
                        () => setState(
                          () =>
                              _isSoundSettingsExpanded =
                                  !_isSoundSettingsExpanded,
                        ),
                    expandedChild: _buildSoundSettingsSection(),
                  ),
                  _SettingsIdentityRow(
                    identity: identity,
                    leading: _SettingsIconBadge(
                      icon: CupertinoIcons.sparkles,
                      color: const Color(0xFF7846E8),
                      background:
                          theme.brightness == Brightness.dark
                              ? identity.softInfo
                              : const Color(0xFFF1ECFF),
                    ),
                    title: 'AI 모델과 API',
                    subtitle: 'AI 제공업체, API 키와 자동 대체를 설정합니다.',
                    expanded: _isAiSettingsExpanded,
                    onTap:
                        () => setState(
                          () => _isAiSettingsExpanded = !_isAiSettingsExpanded,
                        ),
                    expandedChild: const AiSettingsCard(embedded: true),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                '학습 관리',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: identity.mutedInk,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _SettingsGroup(
                identity: identity,
                children: [
                  _SettingsIdentityRow(
                    identity: identity,
                    leading: _SettingsIconBadge(
                      icon: CupertinoIcons.book,
                      color: identity.success,
                      background: identity.softSuccess,
                    ),
                    title: '현재 학습 단어장',
                    subtitle: activeWordbook?.name ?? '선택된 단어장이 없습니다.',
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WordbookManagementScreen(),
                          ),
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadConnectedSheetCount() async {
    final preferences = await SharedPreferences.getInstance();
    final count =
        preferences.getStringList(_recentSpreadsheetsKey)?.length ?? 0;
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
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen()));
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
              '이미 가져온 단어장, 학습 기록과 초기 사용자 혜택은 유지됩니다.',
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
            title: const Text('계정과 초기 사용자 혜택을 삭제할까요?'),
            content: const Text(
              '현재 계정에 연결된 앱 계정, 초기 사용자 혜택 등록과 최근 Google 시트 연결 기록을 삭제합니다. '
              '가져온 로컬 단어장과 학습 기록은 유지됩니다. 혜택 등록 기간에는 앱을 다시 시작하면 새 기기 계정에 재등록될 수 있지만, 등록 종료 후에는 복구하지 못할 수 있습니다.',
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
      final entitlement = context.read<EntitlementProvider>();
      await authProvider.reauthenticateForCloudDeletion();
      await entitlement.deleteCloudIdentity();
      await authProvider.disconnectGoogleDrive();
      await _clearConnectedSheetHistory();
      if (mounted) {
        _showMessage('현재 계정의 클라우드 정보와 혜택 등록을 삭제했습니다. 로컬 학습 데이터는 유지됩니다.');
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
    final isFounding =
        entitlement.isFoundingMember && entitlement.isServerConfirmed;
    final isProtected = isFounding && hasCloudIdentity;
    final isBusy =
        _isAccountActionRunning ||
        authProvider.isLoading ||
        entitlement.loading;
    final accountEmail = googleUser?.email ?? authProvider.cloudIdentityEmail;

    final foundingTitle =
        isProtected
            ? '초기 사용자 혜택 보호됨'
            : isFounding
            ? '초기 사용자 혜택 활성화됨'
            : entitlement.loading
            ? '초기 사용자 혜택 확인 중'
            : '초기 사용자 혜택 등록 준비 중';
    final foundingDescription =
        isProtected
            ? '${accountEmail ?? 'Google 계정'}에 연결되어 다른 기기에서 복원할 수 있습니다.'
            : isFounding
            ? '현재 기기에서 사용할 수 있습니다. Google 계정에 연결하면 다른 기기에서도 복원할 수 있습니다.'
            : '네트워크 연결 후 자동으로 등록 상태를 확인합니다.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (googleUser != null)
                GoogleAccountAvatar(account: googleUser, radius: 21)
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
                              ? 'Google 시트와 초기 사용자 혜택에 사용됩니다.'
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
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
                ? '초기 사용자 혜택은 계정에 보관되어 있습니다. Google 시트를 가져올 때 Drive를 다시 연결하세요.'
                : 'Google 시트 가져오기와 초기 사용자 혜택의 다른 기기 복원에만 계정을 사용합니다.',
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
            label: const Text('계정 및 초기 사용자 혜택 삭제'),
          ),
          Text(
            '현재 계정의 클라우드 정보와 혜택 등록을 삭제합니다. 로컬 학습 데이터는 유지됩니다.',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          RadioGroup<AppThemeType>(
            groupValue: themeNotifier.currentTheme,
            onChanged: (value) {
              if (value != null) themeNotifier.setTheme(value);
            },
            child: const Column(
              children: [
                RadioListTile<AppThemeType>(
                  title: Text('기본 (밝음)'),
                  value: AppThemeType.lightGreen,
                ),
                RadioListTile<AppThemeType>(
                  title: Text('어두운 테마'),
                  value: AppThemeType.dark,
                ),
                RadioListTile<AppThemeType>(
                  title: Text('시력 보호'),
                  value: AppThemeType.visionProtection,
                ),
              ],
            ),
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

  Widget _buildGuideSettingsSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
            leading: const Icon(CupertinoIcons.question_circle_fill),
            title: const Text('사용 가이드'),
            subtitle: const Text('처음 시작, 초기 사용자 혜택, 학습과 AI 안내'),
            trailing: const Icon(CupertinoIcons.right_chevron),
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StudyGuideScreen()),
                ),
          ),
          const Divider(height: 1),
          ListTile(
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
        ],
      ),
    );
  }

  Widget _buildSoundSettingsSection() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: TtsVoiceSettingsPanel(),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final MemorizeIdentity identity;
  final List<Widget> children;

  const _SettingsGroup({required this.identity, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(height: 1, color: identity.border, indent: 74),
          ],
        ],
      ),
    );
  }
}

class _SettingsIdentityRow extends StatelessWidget {
  final MemorizeIdentity identity;
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final bool expanded;
  final VoidCallback onTap;
  final Widget? expandedChild;

  const _SettingsIdentityRow({
    required this.identity,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
    this.expanded = false,
    this.expandedChild,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(child: leading),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: identity.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: identity.mutedInk,
                            height: 1.38,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    Flexible(child: trailing!),
                  ],
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: expanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      color: identity.mutedInk,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ClipRect(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child:
                expanded && expandedChild != null
                    ? Column(
                      children: [
                        Divider(height: 1, color: identity.border),
                        expandedChild!,
                      ],
                    )
                    : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}

class _SettingsIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;

  const _SettingsIconBadge({
    required this.icon,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _SettingsStatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _SettingsStatusChip({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ThemePreviewStrip extends StatelessWidget {
  final AppThemeType selectedTheme;

  const _ThemePreviewStrip({required this.selectedTheme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ThemePreview(
          icon: CupertinoIcons.sun_max_fill,
          foreground: const Color(0xFFFF9800),
          background: Colors.white,
          selected: selectedTheme == AppThemeType.lightGreen,
        ),
        const SizedBox(width: 5),
        _ThemePreview(
          icon: CupertinoIcons.moon_fill,
          foreground: Colors.white,
          background: const Color(0xFF17243A),
          selected: selectedTheme == AppThemeType.dark,
        ),
        const SizedBox(width: 5),
        _ThemePreview(
          icon: CupertinoIcons.leaf_arrow_circlepath,
          foreground: const Color(0xFF31835E),
          background: const Color(0xFFE5F2DD),
          selected: selectedTheme == AppThemeType.visionProtection,
        ),
      ],
    );
  }
}

class _ThemePreview extends StatelessWidget {
  final IconData icon;
  final Color foreground;
  final Color background;
  final bool selected;

  const _ThemePreview({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 31,
      height: 31,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: selected ? const Color(0xFF1E73F7) : const Color(0xFFD9E2F0),
          width: selected ? 2 : 1,
        ),
      ),
      child: Icon(icon, color: foreground, size: 16),
    );
  }
}
