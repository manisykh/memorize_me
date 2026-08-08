import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/entitlement_provider.dart';
import '../services/app_config_service.dart';

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
    final seenVersion = prefs.getInt('memorize_me.launch_notice_seen_version') ?? 0;
    if (seenVersion >= version || !mounted) return;

    final entitlement = context.read<EntitlementProvider>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text(config.launchNoticeTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.launchNoticeMessage),
                const SizedBox(height: 16),
                const _NoticePoint(text: 'Google Sheets/CSV와 기본 학습 기능은 계속 무료'),
                const _NoticePoint(text: '초기 사용자는 향후 유료 기능도 무료 이용'),
                const _NoticePoint(text: '광고 없이 모든 기능 제공'),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    entitlement.isServerConfirmed
                        ? 'Founding 혜택이 등록되었습니다.'
                        : 'Founding 혜택 등록을 준비 중입니다. 네트워크 연결 후 자동으로 다시 시도합니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );

    await prefs.setInt('memorize_me.launch_notice_seen_version', version);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _NoticePoint extends StatelessWidget {
  const _NoticePoint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
