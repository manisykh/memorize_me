import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../themes/memorize_identity.dart';

class GuideTopic {
  final String id;
  final IconData icon;
  final String title;
  final String summary;
  final List<String> bullets;
  final String? footer;

  const GuideTopic({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.bullets,
    this.footer,
  });
}

class StudyGuideCatalog {
  static const quickStart = GuideTopic(
    id: 'quick-start',
    icon: CupertinoIcons.map,
    title: '처음 사용할 때의 흐름',
    summary: '이 앱은 단어장을 고르고, 오늘 학습을 처리하고, SRS가 다음 복습 시점을 잡는 구조입니다.',
    bullets: [
      '먼저 홈의 단어장 현황 또는 상단의 현재 학습 기준을 눌러 사용할 단어장을 선택합니다.',
      '홈의 복습 필요, 새 단어, 학습 중 숫자를 보고 오늘 처리할 학습을 파악합니다.',
      '학습 플랜에서 자유모드, 일정 달성 모드, 복습 우선 모드 중 원하는 방식을 선택합니다.',
      '오늘 복습 시작 또는 새 단어 시작을 누르면 현재 상태에 맞는 플래시카드 학습으로 이동합니다.',
    ],
    footer: '긴 설명은 설정 > 가이드 펼치기 > 사용 가이드에서 언제든 다시 볼 수 있습니다.',
  );

  static const todayRoutine = GuideTopic(
    id: 'today-routine',
    icon: CupertinoIcons.chart_bar_alt_fill,
    title: '오늘 학습 읽는 법',
    summary: '홈 대시보드는 현재 단어장 기준으로 오늘 무엇을 해야 하는지 보여줍니다.',
    bullets: [
      '복습 필요는 SRS 기준으로 복습일이 오늘이거나 이미 지난 단어입니다.',
      '새 단어는 오늘 처음 학습하도록 열린 단어입니다. 플랜이 있으면 플랜 범위 안에서만 열립니다.',
      '학습 중은 첫 학습 뒤 짧은 간격으로 기억을 정착시키는 단계입니다.',
      '복습 예정은 초기 학습을 마치고 다음 복습일을 기다리는 단계입니다.',
      '복습 화면을 연 동안에는 복습 중으로 표시되며, 이는 저장되는 기억 단계가 아닙니다.',
      '오늘 처리 현황은 오늘 완료한 학습과 지금 남은 복습, 새 단어를 함께 보여줍니다.',
    ],
  );

  static const studyPlan = GuideTopic(
    id: 'study-plan',
    icon: CupertinoIcons.calendar_badge_plus,
    title: '학습 플랜 이해하기',
    summary: '단어장을 자신의 속도에 맞춰 나누고, 필요하면 날짜별 목표를 세웁니다.',
    bullets: [
      '자유모드는 묶음 수를 정하고 학습할 묶음을 직접 선택합니다. 날짜가 지나도 범위가 늘어나지 않습니다.',
      '일정 달성 모드는 날짜별로 새 단어가 열립니다. 놓친 분량도 남으며, 일정 다시 조정으로 남은 새 단어를 오늘부터 재배정할 수 있습니다.',
      '목표일은 새 단어를 한 번 학습하는 기준입니다. 완전히 외웠는지와 다음 SRS 복습일은 별도로 관리합니다.',
      '복습 우선 모드는 복습이 많을수록 새 단어를 줄입니다. 쉬었던 날의 새 단어 할당량은 쌓이지 않습니다.',
      '묶음과 모드를 바꿔도 학습 기록과 SRS는 유지됩니다. 다른 묶음의 SRS 복습은 달력 탭에서 시작할 수 있습니다. 복습 현황판에서 전체 단어장과 묶음별 완료 기록을 바꿔 확인합니다.',
    ],
    footer: '플랜이 있는 단어장은 단어장 현황에 별도 마크가 표시됩니다.',
  );

  static const recommendedLearning = GuideTopic(
    id: 'recommended-learning',
    icon: CupertinoIcons.play_circle_fill,
    title: '시작 버튼이 고르는 기준',
    summary: '홈의 시작 버튼은 현재 상태에 따라 가장 자연스러운 학습을 엽니다.',
    bullets: [
      '복습할 단어가 있으면 오늘 복습을 먼저 엽니다.',
      '복습이 없고 오늘 열린 새 단어가 있으면 새 단어 플래시카드를 엽니다.',
      '새 단어도 없고 학습 중 단어만 있으면 전체 플래시카드 점검으로 이동합니다.',
      '아무 루틴도 없으면 전체 카드를 천천히 볼 수 있게 합니다.',
    ],
  );

  static const newWordRecommendation = GuideTopic(
    id: 'new-word-recommendation',
    icon: CupertinoIcons.sparkles,
    title: '새 단어 추천 기준',
    summary: '새 단어는 무조건 많이 여는 것이 아니라 오늘 복습 부담과 플랜을 함께 봅니다.',
    bullets: [
      '플랜이 없으면 현재 단어장의 새 단어를 모두 선택할 수 있습니다.',
      '플랜이 있으면 아직 열리지 않은 새 단어는 대시보드와 루틴에서 제외됩니다.',
      '복습 우선 모드에서는 오늘 복습량이 많으면 새 단어 수를 줄입니다. 일정 달성 모드는 정한 일정을 유지합니다.',
      '이미 안정 기억 단계에 가까운 단어보다 아직 처음 학습하지 않은 단어가 우선입니다.',
    ],
  );

  static const srsAndStats = GuideTopic(
    id: 'srs-and-stats',
    icon: CupertinoIcons.waveform_path_ecg,
    title: 'SRS와 통계',
    summary: 'SRS는 단어별 기억 상태를 보고 다음 복습 시점을 정하고, 통계는 그 흐름을 요약합니다.',
    bullets: [
      '복습을 완료하면 단어의 기억 단계와 다음 복습 기준이 갱신됩니다.',
      '통계의 안정 기억은 충분히 반복되어 장기 기억에 가까운 단어를 뜻합니다.',
      '플랜이 있는 단어장은 전체 기준과 플랜 기준을 나눠서 볼 수 있습니다.',
      '달력 탭은 완료한 학습만 완료일 기준으로 표시합니다. 중간에 종료하면 달력과 완료 횟수에는 포함하지 않지만, 이미 푼 문제의 오답과 SRS는 유지합니다.',
      '셀프 테스트의 남은 오답 복습은 객관식·스펠링 오답과 스킵·재도전 단어를 모읍니다. 카드의 몰라요는 포함하지 않습니다. 같은 유형에서 한 번에 맞히면 대기 목록에서 빠집니다.',
      '복습 탭의 누적 오답 노트는 계속 보관되는 이력입니다. 이후 맞힌 단어도 남으며 문제 유형별 복습이나 카드 학습을 선택할 수 있습니다.',
      '퀴즈에서 틀리거나 스킵하면 오늘 다시 복습합니다. 같은 문제의 재도전은 추가 감점하지 않으며, 재도전 정답만으로 복습 간격이 늘어나지 않습니다.',
      'SRS 복습 표시는 현재 예정된 다음 복습일입니다. 학습 결과에 따라 바뀌며, 지난 미완료 복습은 오늘에 모아서 표시합니다.',
      '기존 누적 횟수는 유지됩니다. 날짜별 상세 기록은 달력 기능 적용 이후부터 쌓입니다.',
      '하루에 여러 번 학습해도 단어 상태가 바뀌면 대시보드와 복습 숫자가 함께 변합니다.',
    ],
  );

  static const aiLearning = GuideTopic(
    id: 'ai-learning',
    icon: CupertinoIcons.rectangle_stack_fill,
    title: 'AI 학습 사용하기',
    summary: 'AI 학습은 단어장을 바탕으로 예문, 문제, 문법 점검 자료를 만드는 베타 보조 기능입니다.',
    bullets: [
      '설정에서 AI 모델과 API를 펼친 뒤 사용할 제공자와 모델, API 키를 먼저 등록합니다.',
      '여러 API 키를 등록하면 한도 초과 시 대체 모델로 이어서 시도할 수 있습니다.',
      'AI 문제 생성은 단어장을 선택한 뒤 문제 유형과 개수를 정해서 시작합니다.',
      'AI 결과에는 오류가 있을 수 있으므로 정답과 해설을 확인한 뒤 사용합니다.',
    ],
    footer: '선택한 단어, 뜻, 예문과 생성 옵션은 사용자가 선택한 외부 AI 제공자에게 전송됩니다.',
  );

  static const initialUserBenefit = GuideTopic(
    id: 'initial-user-benefit',
    icon: CupertinoIcons.gift_fill,
    title: '초기 사용자 혜택',
    summary: '출시 초기 이용자에게 향후 유료 기능도 계속 사용할 수 있는 혜택을 등록합니다.',
    bullets: [
      '혜택 등록 기간에는 앱을 시작하면 로그인 여부와 관계없이 현재 기기에 자동 등록됩니다.',
      'Google 계정을 연결하면 혜택을 계정에 보호해 재설치하거나 다른 기기에서도 복원할 수 있습니다.',
      'Google Drive 연결만 해제하면 로컬 단어장, 학습 기록과 등록된 혜택은 유지됩니다.',
      '계정 및 초기 사용자 혜택 삭제는 현재 계정의 클라우드 기록을 삭제합니다. 등록 기간에는 재등록될 수 있지만, 종료 후에는 복구하지 못할 수 있습니다.',
    ],
    footer: 'Google 연결은 선택 사항입니다. Google 시트 가져오기와 다른 기기 복원이 필요할 때만 연결해도 됩니다.',
  );

  static const appSettings = GuideTopic(
    id: 'app-settings',
    icon: CupertinoIcons.settings_solid,
    title: '설정 사용하기',
    summary: '설정은 필요한 항목만 펼쳐서 같은 화면에서 바로 조정할 수 있습니다.',
    bullets: [
      '계정과 Google 시트에서는 Google 연결, 연결된 시트와 초기 사용자 혜택을 관리합니다.',
      '디자인에서는 밝음, 어두움, 시력 보호 테마와 시력 보호 농도를 조절합니다.',
      '소리와 음성에서는 학습 효과음과 단어 발음, AI 대화 듣기 화자를 선택합니다.',
      'AI 모델과 API에서는 제공자, 모델, API 키와 자동 대체 순서를 관리합니다.',
    ],
  );

  static const all = <GuideTopic>[
    quickStart,
    todayRoutine,
    studyPlan,
    recommendedLearning,
    newWordRecommendation,
    srsAndStats,
    aiLearning,
    initialUserBenefit,
    appSettings,
  ];
}

Future<void> showStudyGuideSheet(BuildContext context, GuideTopic topic) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x9909255A),
    builder: (sheetContext) {
      final identity = MemorizeIdentity.of(Theme.of(sheetContext));
      return SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.86,
          ),
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: identity.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                  child: _GuideTopicContent(
                    topic: topic,
                    onClose: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class StudyGuideScreen extends StatelessWidget {
  const StudyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: const Text('사용 가이드')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              '필요한 기능을 빠르게 찾아보세요.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: identity.mutedInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: identity.surface,
                borderRadius: BorderRadius.circular(
                  MemorizeIdentity.cardRadius,
                ),
                border: Border.all(color: identity.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final indexed in StudyGuideCatalog.all.indexed) ...[
                    _GuideTopicRow(topic: indexed.$2),
                    if (indexed.$1 < StudyGuideCatalog.all.length - 1)
                      Divider(height: 1, indent: 76, color: identity.border),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideTopicRow extends StatelessWidget {
  final GuideTopic topic;

  const _GuideTopicRow({required this.topic});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Material(
      color: identity.surface,
      child: InkWell(
        onTap: () => showStudyGuideSheet(context, topic),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              _GuideIcon(icon: topic.icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      topic.summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                color: identity.mutedInk,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideTopicContent extends StatelessWidget {
  final GuideTopic topic;
  final VoidCallback onClose;

  const _GuideTopicContent({required this.topic, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _GuideIcon(icon: topic.icon, large: true),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                topic.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: identity.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: '닫기',
              onPressed: onClose,
              icon: Icon(CupertinoIcons.xmark, color: identity.ink),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          topic.summary,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: identity.mutedInk,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        Divider(height: 1, color: identity.border),
        const SizedBox(height: 4),
        for (final indexed in topic.bullets.indexed)
          _GuideBullet(index: indexed.$1 + 1, text: indexed.$2),
        if (topic.footer != null) ...[
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: identity.softContext,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  color: identity.primaryAction,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    topic.footer!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: identity.primaryAction,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _GuideIcon extends StatelessWidget {
  final IconData icon;
  final bool large;

  const _GuideIcon({required this.icon, this.large = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final size = large ? 54.0 : 44.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: identity.softContext,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: identity.primaryAction, size: large ? 27 : 22),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  final int index;
  final String text;

  const _GuideBullet({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: identity.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: identity.softContext,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$index',
              style: theme.textTheme.titleSmall?.copyWith(
                color: identity.primaryAction,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: identity.ink,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
