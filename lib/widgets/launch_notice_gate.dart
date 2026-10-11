import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/entitlement_provider.dart';
import '../services/app_config_service.dart';
import '../themes/memorize_identity.dart';

class LaunchNoticeGate extends StatefulWidget {
  const LaunchNoticeGate({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchNoticeGate> createState() => _LaunchNoticeGateState();
}

class _LaunchNoticeGateState extends State<LaunchNoticeGate> {
  bool _checkStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checkStarted) return;
    _checkStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showNoticeIfNeeded());
  }

  Future<void> _showNoticeIfNeeded() async {
    final config = context.read<AppConfigService>();
    if (!config.launchNoticeEnabled || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final version = config.launchNoticeVersion;
    final seenVersion =
        prefs.getInt('memorize_me.launch_notice_seen_version') ?? 0;
    if (seenVersion >= version || !mounted) return;

    final entitlement = context.read<EntitlementProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0x9909255A),
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final identity = MemorizeIdentity.of(theme);
        return Dialog(
          backgroundColor: identity.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: identity.softContext,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    CupertinoIcons.gift,
                    color: identity.primaryAction,
                    size: 31,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '출시 안내',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: identity.primaryAction,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  config.launchNoticeTitle,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  config.launchNoticeMessage,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: identity.mutedInk,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: identity.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: identity.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: const Column(
                    children: [
                      _NoticePoint(
                        text: 'Google Sheets·CSV·XLSX와 기본 학습 기능은 계속 무료',
                      ),
                      _NoticePoint(text: '초기 사용자는 향후 유료 기능도 무료 이용'),
                      _NoticePoint(text: 'Google 계정 연결 시 다른 기기에서도 혜택 복원'),
                      _NoticePoint(text: '광고 없이 모든 기능 제공', showDivider: false),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: identity.softSuccess,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        entitlement.isServerConfirmed
                            ? CupertinoIcons.checkmark_shield_fill
                            : CupertinoIcons.cloud_upload,
                        color: identity.success,
                        size: 22,
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          entitlement.isServerConfirmed
                              ? '초기 사용자 혜택이 등록되었습니다.'
                              : '혜택 등록을 준비 중입니다. 연결 후 자동으로 다시 시도합니다.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: identity.success,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    await prefs.setInt('memorize_me.launch_notice_seen_version', version);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NoticePoint extends StatelessWidget {
  const _NoticePoint({required this.text, this.showDivider = true});

  final String text;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        border:
            showDivider
                ? Border(bottom: BorderSide(color: identity.border))
                : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.check_mark_circled_solid,
            size: 22,
            color: identity.primaryAction,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: identity.ink,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
