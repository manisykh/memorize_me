import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../themes/app_theme.dart';
import 'glassmorphic_card.dart';

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
      '먼저 홈이나 단어장 탭에서 오늘 기준이 될 단어장을 선택합니다.',
      '홈의 복습, 새 단어, 학습 중 숫자를 보고 오늘 처리할 학습을 파악합니다.',
      '학습 플랜을 만들면 새 단어가 한꺼번에 열리지 않고 일정에 맞춰 나뉩니다.',
      '오늘 복습 시작 또는 새 단어 시작을 누르면 현재 상태에 맞는 플래시카드 학습으로 이동합니다.',
    ],
    footer: '긴 설명은 설정 > 사용 가이드에서 언제든 다시 볼 수 있습니다.',
  );

  static const todayRoutine = GuideTopic(
    id: 'today-routine',
    icon: CupertinoIcons.chart_bar_alt_fill,
    title: '오늘 학습 읽는 법',
    summary: '홈 대시보드는 현재 단어장 기준으로 오늘 무엇을 해야 하는지 보여줍니다.',
    bullets: [
      '복습은 SRS 기준으로 오늘 다시 봐야 하는 단어입니다.',
      '새 단어는 오늘 처음 학습하도록 열린 단어입니다. 플랜이 있으면 플랜 범위 안에서만 열립니다.',
      '학습 중은 아직 안정 기억 단계가 아니며, 다음 복습일을 기다리거나 짧게 확인할 단어입니다.',
      '오늘 처리 현황은 오늘 완료한 학습과 지금 남은 복습, 새 단어를 함께 보여줍니다.',
    ],
  );

  static const studyPlan = GuideTopic(
    id: 'study-plan',
    icon: CupertinoIcons.calendar_badge_plus,
    title: '학습 플랜 이해하기',
    summary: '단어가 많은 단어장을 일정에 맞게 쪼개서 새 단어 부담을 줄이는 기능입니다.',
    bullets: [
      '며칠 안에 끝낼까요는 전체 새 단어를 어느 기간에 나눠 시작할지 정하는 값입니다.',
      '하루 새 단어 목표는 하루에 새로 시작할 단어 수입니다.',
      '일일 묶음은 공부 기간과 같은 수로 나뉩니다. 30일 계획이면 30개의 일일 묶음으로 진행됩니다.',
      '복습 단어는 플랜 때문에 잠기지 않습니다. 복습은 항상 우선입니다.',
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
      '플랜이 없으면 현재 단어장의 새 단어 후보에서 기본 목표량을 추천합니다.',
      '플랜이 있으면 아직 열리지 않은 새 단어는 대시보드와 루틴에서 제외됩니다.',
      '오늘 복습량이 많으면 새 단어 수를 줄여서 루틴이 과하게 무거워지지 않게 합니다.',
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
      '하루에 여러 번 학습해도 단어 상태가 바뀌면 대시보드와 복습 숫자가 함께 변합니다.',
    ],
  );

  static const aiLearning = GuideTopic(
    id: 'ai-learning',
    icon: CupertinoIcons.rectangle_stack_fill,
    title: 'AI 학습 사용하기',
    summary: 'AI 학습은 단어장을 바탕으로 예문, 문제, 문법 점검 자료를 만드는 보조 기능입니다.',
    bullets: [
      'AI 설정에서 사용할 제공자와 모델, API 키를 먼저 등록합니다.',
      '여러 API 키를 등록하면 한도 초과 시 대체 모델로 이어서 시도할 수 있습니다.',
      'AI 문제 생성은 단어장을 선택한 뒤 문제 유형과 개수를 정해서 시작합니다.',
      'AI 결과는 복습을 대신하는 기능이 아니라 이해와 예문 확장을 돕는 기능입니다.',
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
  ];
}

Future<void> showStudyGuideSheet(BuildContext context, GuideTopic topic) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder:
        (sheetContext) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: GlassmorphicCard(
              borderRadius: 30,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: _GuideTopicContent(
                topic: topic,
                onClose: () => Navigator.of(sheetContext).pop(),
              ),
            ),
          ),
        ),
  );
}

class StudyGuideScreen extends StatelessWidget {
  const StudyGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('사용 가이드')),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          itemBuilder: (context, index) {
            final topic = StudyGuideCatalog.all[index];
            return GlassmorphicCard(
              borderRadius: 28,
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              onTap: () => showStudyGuideSheet(context, topic),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          topic.summary,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    CupertinoIcons.chevron_right,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            );
          },
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemCount: StudyGuideCatalog.all.length,
        ),
      ),
    );
  }
}

class _GuideTopicContent extends StatelessWidget {
  final GuideTopic topic;
  final VoidCallback onClose;

  const _GuideTopicContent({
    required this.topic,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _GuideIcon(icon: topic.icon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    topic.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: onClose,
                  icon: const Icon(CupertinoIcons.xmark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              topic.summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            for (final bullet in topic.bullets) ...[
              _GuideBullet(text: bullet),
              const SizedBox(height: 10),
            ],
            if (topic.footer != null) ...[
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  topic.footer!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GuideIcon extends StatelessWidget {
  final IconData icon;

  const _GuideIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = isDark ? AppTheme.accentCoral : theme.colorScheme.primary;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }
}

class _GuideBullet extends StatelessWidget {
  final String text;

  const _GuideBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.42,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
