import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../themes/memorize_identity.dart';

class LegalInformationScreen extends StatelessWidget {
  const LegalInformationScreen({super.key});

  static const privacyPolicyUrl = String.fromEnvironment('PRIVACY_POLICY_URL');
  static const accountDeletionUrl = String.fromEnvironment(
    'ACCOUNT_DELETION_URL',
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: const Text('개인정보 및 계정 삭제')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MemorizeIdentity.pagePadding,
            18,
            MemorizeIdentity.pagePadding,
            32,
          ),
          children: [
            Text(
              '내 데이터를 어떻게 다루는지\n확인하세요.',
              style: theme.textTheme.headlineMedium?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '최종 업데이트: 2026년 10월 18일',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: identity.mutedInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            _LegalCard(
              icon: CupertinoIcons.shield_lefthalf_fill,
              title: '개인정보 처리 요약',
              children: const [
                _LegalParagraph(
                  title: '기기에 저장되는 데이터',
                  body:
                      '단어장, 학습 기록, 설정과 AI API 키는 기본적으로 현재 기기에 저장됩니다. API 키는 Android의 보안 저장소를 사용합니다.',
                ),
                _LegalParagraph(
                  title: '계정과 Google 시트',
                  body:
                      'Google 로그인을 선택하면 계정 식별 정보와 사용자가 선택한 시트에 접근하기 위한 Drive 권한을 사용합니다. 초기 사용자 혜택 연결을 위한 최소 정보가 Firebase에 보관될 수 있습니다.',
                ),
                _LegalParagraph(
                  title: 'AI 제공업체로 전송되는 데이터',
                  body:
                      'AI 기능을 직접 실행한 경우에만 프롬프트, 단어, 예문과 설정값이 선택한 AI 제공업체로 전송됩니다. 이 처리에는 해당 제공업체의 정책이 적용됩니다.',
                ),
                _LegalParagraph(
                  title: '앱 품질 정보',
                  body:
                      '앱 품질 개선과 장애 분석을 위해 Firebase Analytics, Crashlytics, Remote Config을 사용할 수 있습니다.',
                ),
              ],
            ),
            const SizedBox(height: 14),
            _LegalCard(
              icon: CupertinoIcons.person_crop_circle_badge_minus,
              title: '계정 및 데이터 삭제',
              children: [
                const _LegalParagraph(
                  title: '앱에서 즉시 요청',
                  body:
                      '설정 > 계정과 Google 시트 > 계정 및 초기 사용자 혜택 삭제에서 클라우드 계정 정보를 삭제할 수 있습니다. 로컬 단어장과 학습 기록은 별도로 유지되며 앱 데이터 삭제 또는 앱 삭제로 제거할 수 있습니다.',
                ),
                const _LegalParagraph(
                  title: '앱에 접근할 수 없을 때',
                  body: '아래 계정 삭제 안내 페이지에서 외부 요청 방법과 삭제 범위를 확인하세요.',
                ),
                if (privacyPolicyUrl.isNotEmpty) ...[
                  _UrlBlock(
                    label: '개인정보 처리방침',
                    url: privacyPolicyUrl,
                    identity: identity,
                  ),
                  const SizedBox(height: 10),
                ],
                if (accountDeletionUrl.isNotEmpty)
                  _UrlBlock(
                    label: '계정 삭제 안내',
                    url: accountDeletionUrl,
                    identity: identity,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F09255A),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: identity.primaryAction),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _LegalParagraph extends StatelessWidget {
  const _LegalParagraph({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: identity.mutedInk,
              height: 1.55,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrlBlock extends StatelessWidget {
  const _UrlBlock({
    required this.label,
    required this.url,
    required this.identity,
  });

  final String label;
  final String url;
  final MemorizeIdentity identity;

  @override
  Widget build(BuildContext context) => Material(
    color: identity.softInfo,
    borderRadius: BorderRadius.circular(12),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: () => _openUrl(context),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: identity.primaryAction,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              CupertinoIcons.arrow_up_right_square,
              color: identity.primaryAction,
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _openUrl(BuildContext context) async {
    final uri = Uri.tryParse(url);
    final launched =
        uri != null &&
        uri.scheme == 'https' &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label 페이지를 열 수 없습니다.')));
  }
}
