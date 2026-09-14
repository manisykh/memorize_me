import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/learning_route_origin.dart';
import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/quiz_review_service.dart';
import '../services/study_history_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/study_mode_icon.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

class MistakeReviewScreen extends StatefulWidget {
  final bool cumulative;

  const MistakeReviewScreen({super.key, this.cumulative = false});

  @override
  State<MistakeReviewScreen> createState() => _MistakeReviewScreenState();
}

class _MistakeReviewScreenState extends State<MistakeReviewScreen> {
  late Future<void> _loading;

  @override
  void initState() {
    super.initState();
    _loading = StudyHistoryService.instance.ensureLoaded();
  }

  Future<void> _start(List<Word> words, {StudyHistoryMode? mode}) async {
    if (words.isEmpty) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => mode == null
            ? FlashcardScreen(
                initialMode: FlashcardLaunchMode.review,
                origin: LearningRouteOrigin.review,
                reviewWordsOverride: words,
              )
            : QuizScreen(
                initialMode: mode == StudyHistoryMode.multipleChoice
                    ? QuizMode.reviewMultipleChoice
                    : QuizMode.reviewSpelling,
                origin: LearningRouteOrigin.review,
                mistakeReview: true,
                wordsOverride: words,
              ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WordbookManager>();
    final theme = Theme.of(context);
    final title = widget.cumulative ? '누적 오답 노트' : '남은 오답 복습';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<void>(
        future: _loading,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: OutlinedButton.icon(
                onPressed: () => setState(
                  () => _loading = StudyHistoryService.instance.ensureLoaded(),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('기록 다시 불러오기'),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = manager.quizReviewEntries(
            cumulative: widget.cumulative,
          );
          final modesFor = (QuizReviewEntry entry) => widget.cumulative
              ? entry.historyModes
              : entry.pendingModes;
          final mcq = entries
              .where(
                (entry) => modesFor(
                  entry,
                ).contains(StudyHistoryMode.multipleChoice),
              )
              .map((entry) => entry.word)
              .toList();
          final spelling = entries
              .where(
                (entry) => modesFor(
                  entry,
                ).contains(StudyHistoryMode.spelling),
              )
              .map((entry) => entry.word)
              .toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              _MistakeIntro(
                cumulative: widget.cumulative,
                wordbookName:
                    manager.activeWordbook?.name ?? '단어장을 선택하세요',
                count: entries.length,
              ),
              if (entries.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 56),
                  child: Column(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 44,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.cumulative
                            ? '저장된 오답 이력이 없습니다.'
                            : '지금 다시 풀어야 할 오답이 없습니다.',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                const SizedBox(height: 16),
                _ReviewActionPanel(
                  totalCount: entries.length,
                  mcqCount: mcq.length,
                  spellingCount: spelling.length,
                  onCards: () => _start(
                    entries.map((entry) => entry.word).toList(),
                  ),
                  onMcq: mcq.isEmpty
                      ? null
                      : () => _start(
                          mcq,
                          mode: StudyHistoryMode.multipleChoice,
                        ),
                  onSpelling: spelling.isEmpty
                      ? null
                      : () => _start(
                          spelling,
                          mode: StudyHistoryMode.spelling,
                        ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '단어 목록',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _CountBadge(count: entries.length),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '단어를 누르면 문제 유형과 시도 이력을 확인할 수 있습니다.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                for (final indexed in entries.indexed) ...[
                  _MistakeEntryCard(
                    index: indexed.$1 + 1,
                    entry: indexed.$2,
                    cumulative: widget.cumulative,
                  ),
                  if (indexed.$1 < entries.length - 1)
                    const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MistakeIntro extends StatelessWidget {
  final bool cumulative;
  final String wordbookName;
  final int count;

  const _MistakeIntro({
    required this.cumulative,
    required this.wordbookName,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = cumulative
        ? theme.colorScheme.tertiary
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            foregroundColor: color,
            child: Icon(
              cumulative ? Icons.history_rounded : Icons.task_alt_rounded,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wordbookName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  cumulative
                      ? '틀림·스킵·재도전 이력을 계속 보관합니다. 나중에 맞힌 단어도 다시 선택해 학습할 수 있습니다.'
                      : '아직 한 번에 정답 처리되지 않은 $count개입니다. 같은 문제 유형을 한 번에 맞히면 목록에서 빠집니다.',
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewActionPanel extends StatelessWidget {
  final int totalCount;
  final int mcqCount;
  final int spellingCount;
  final VoidCallback onCards;
  final VoidCallback? onMcq;
  final VoidCallback? onSpelling;

  const _ReviewActionPanel({
    required this.totalCount,
    required this.mcqCount,
    required this.spellingCount,
    required this.onCards,
    required this.onMcq,
    required this.onSpelling,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '복습 방식 선택',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '바로 문제를 풀거나, 카드로 뜻을 먼저 확인하세요.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onCards,
            icon: Icon(studyModeIcon(StudyHistoryMode.flashcard)),
            label: Text('카드로 먼저 보기 · $totalCount개'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMcq,
                  icon: Icon(
                    studyModeIcon(StudyHistoryMode.multipleChoice),
                  ),
                  label: Text('객관식 $mcqCount'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onSpelling,
                  icon: Icon(studyModeIcon(StudyHistoryMode.spelling)),
                  label: Text('스펠링 $spellingCount'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;

  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count개',
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MistakeEntryCard extends StatefulWidget {
  final int index;
  final QuizReviewEntry entry;
  final bool cumulative;

  const _MistakeEntryCard({
    required this.index,
    required this.entry,
    required this.cumulative,
  });

  @override
  State<_MistakeEntryCard> createState() => _MistakeEntryCardState();
}

class _MistakeEntryCardState extends State<_MistakeEntryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entry = widget.entry;
    final modes = widget.cumulative
        ? entry.historyModes
        : entry.pendingModes;
    final state = entry.pendingModes.isEmpty ? '확인 완료' : '복습 대기';
    final modeNames = modes
        .map(
          (mode) => mode == StudyHistoryMode.multipleChoice
              ? '객관식'
              : '스펠링',
        )
        .join(' · ');

    return Material(
      color: theme.colorScheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Text(
                      '${widget.index}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.word.word,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.word.meaning,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$modeNames · $state',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: entry.pendingModes.isEmpty
                                ? theme.colorScheme.primary
                                : theme.colorScheme.error,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Text(
                        _expanded ? '접기' : '이력 보기',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox.shrink()
                : _MistakeEventList(events: entry.events),
          ),
        ],
      ),
    );
  }
}

class _MistakeEventList extends StatelessWidget {
  final List<QuizMistakeEvent> events;

  const _MistakeEventList({required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Text(
          '이전 버전에서 저장된 오답입니다. 당시 시도별 상세 기록은 없습니다.',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shrinkWrap: true,
        primary: false,
        itemCount: events.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: theme.colorScheme.outlineVariant,
        ),
        itemBuilder: (_, index) {
          final event = events[index];
          final at = event.answer.at;
          final time =
              '${studyDateKey(at)} '
              '${at.hour.toString().padLeft(2, '0')}:'
              '${at.minute.toString().padLeft(2, '0')}';
          final attempts = event.answer.attemptLog;
          final detail = attempts.isEmpty
              ? time
              : '$time · ${attempts.asMap().entries.map((attempt) => '${attempt.key + 1}차 ${attempt.value.success ? '정답' : '오답'}').join(' · ')}';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  studyModeIcon(event.mode),
                  size: 19,
                  color: studyModeColor(event.mode, theme.brightness),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event.mode.label} · ${event.label}',
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(detail, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
