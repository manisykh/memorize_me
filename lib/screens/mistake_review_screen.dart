import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/learning_route_origin.dart';
import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/quiz_review_service.dart';
import '../services/study_history_service.dart';
import '../themes/memorize_identity.dart';
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
        builder:
            (_) =>
                mode == null
                    ? FlashcardScreen(
                      initialMode: FlashcardLaunchMode.review,
                      origin: LearningRouteOrigin.review,
                      reviewWordsOverride: words,
                    )
                    : QuizScreen(
                      initialMode:
                          mode == StudyHistoryMode.multipleChoice
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
    final identity = MemorizeIdentity.of(theme);
    final title = widget.cumulative ? '누적 오답 노트' : '남은 오답 복습';

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: FutureBuilder<void>(
          future: _loading,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: OutlinedButton.icon(
                  onPressed:
                      () => setState(
                        () =>
                            _loading =
                                StudyHistoryService.instance.ensureLoaded(),
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
            Set<StudyHistoryMode> modesFor(QuizReviewEntry entry) =>
                widget.cumulative ? entry.historyModes : entry.pendingModes;
            final mcq =
                entries
                    .where(
                      (entry) => modesFor(
                        entry,
                      ).contains(StudyHistoryMode.multipleChoice),
                    )
                    .map((entry) => entry.word)
                    .toList();
            final spelling =
                entries
                    .where(
                      (entry) =>
                          modesFor(entry).contains(StudyHistoryMode.spelling),
                    )
                    .map((entry) => entry.word)
                    .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                _WordbookContextStrip(
                  wordbookName: manager.activeWordbook?.name ?? '단어장을 선택하세요',
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
                          color: identity.primaryAction,
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
                  const SizedBox(height: 24),
                  Text(
                    widget.cumulative ? '틀린 문제부터 다시 확인해요' : '남은 오답부터 다시 풀어봐요',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.cumulative
                        ? '오답을 복습하면 더 오래 기억할 수 있어요.'
                        : '한 번에 맞히면 대기 목록에서 빠져요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: identity.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ReviewActionPanel(
                    totalCount: entries.length,
                    mcqCount: mcq.length,
                    spellingCount: spelling.length,
                    onCards:
                        () =>
                            _start(entries.map((entry) => entry.word).toList()),
                    onMcq:
                        mcq.isEmpty
                            ? null
                            : () => _start(
                              mcq,
                              mode: StudyHistoryMode.multipleChoice,
                            ),
                    onSpelling:
                        spelling.isEmpty
                            ? null
                            : () => _start(
                              spelling,
                              mode: StudyHistoryMode.spelling,
                            ),
                  ),
                  const SizedBox(height: 28),
                  Divider(color: identity.border, height: 1),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '단어 목록',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: identity.ink,
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
                      color: identity.mutedInk,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        for (final indexed in entries.indexed) ...[
                          _MistakeEntryCard(
                            index: indexed.$1 + 1,
                            entry: indexed.$2,
                            cumulative: widget.cumulative,
                          ),
                          if (indexed.$1 < entries.length - 1)
                            Divider(height: 1, color: identity.border),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WordbookContextStrip extends StatelessWidget {
  final String wordbookName;
  final int count;

  const _WordbookContextStrip({
    required this.wordbookName,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: identity.softContext,
        borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
      ),
      child: Row(
        children: [
          Icon(CupertinoIcons.book, color: identity.success, size: 27),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: wordbookName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: '  ·  누적 $count개',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: identity.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Icon(
            CupertinoIcons.chevron_right,
            color: identity.mutedInk,
            size: 18,
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
    final identity = MemorizeIdentity.of(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: onCards,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: identity.primaryAction,
            shape: const StadiumBorder(),
          ),
          icon: const Icon(CupertinoIcons.play_circle_fill, size: 25),
          label: Text(
            '오답 카드로 확인 · $totalCount개',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ModeReviewButton(
                label: '객관식 다시 풀기',
                count: mcqCount,
                mode: StudyHistoryMode.multipleChoice,
                onPressed: onMcq,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ModeReviewButton(
                label: '스펠링 다시 풀기',
                count: spellingCount,
                mode: StudyHistoryMode.spelling,
                onPressed: onSpelling,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ModeReviewButton extends StatelessWidget {
  final String label;
  final int count;
  final StudyHistoryMode mode;
  final VoidCallback? onPressed;

  const _ModeReviewButton({
    required this.label,
    required this.count,
    required this.mode,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final modeColor = studyModeColor(mode, theme.brightness);
    return Material(
      color: identity.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        side: BorderSide(color: identity.border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 10, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: modeColor.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(studyModeIcon(mode), color: modeColor, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count개',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: modeColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: identity.mutedInk,
                size: 17,
              ),
            ],
          ),
        ),
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
    final identity = MemorizeIdentity.of(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: identity.softContext,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count개',
        style: theme.textTheme.labelMedium?.copyWith(
          color: identity.primaryAction,
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
    final identity = MemorizeIdentity.of(theme);
    final entry = widget.entry;
    final modes = widget.cumulative ? entry.historyModes : entry.pendingModes;
    final state = entry.pendingModes.isEmpty ? '확인 완료' : '재확인 필요';
    final modeNames = modes
        .map((mode) => mode == StudyHistoryMode.multipleChoice ? '객관식' : '스펠링')
        .join(' · ');

    return Material(
      color: identity.surface,
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
                    backgroundColor:
                        entry.pendingModes.isEmpty
                            ? identity.softSuccess
                            : identity.softReview,
                    foregroundColor:
                        entry.pendingModes.isEmpty
                            ? identity.success
                            : identity.review,
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
                            color: identity.ink,
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
                            color:
                                entry.pendingModes.isEmpty
                                    ? identity.success
                                    : identity.review,
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
                          color: identity.primaryAction,
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
            child:
                !_expanded
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
    final identity = MemorizeIdentity.of(theme);
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
        color: identity.softContext.withValues(alpha: 0.55),
        border: Border(top: BorderSide(color: identity.border)),
      ),
      constraints: const BoxConstraints(maxHeight: 260),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shrinkWrap: true,
        primary: false,
        itemCount: events.length,
        separatorBuilder: (_, _) => Divider(height: 1, color: identity.border),
        itemBuilder: (_, index) {
          final event = events[index];
          final at = event.answer.at;
          final time =
              '${studyDateKey(at)} '
              '${at.hour.toString().padLeft(2, '0')}:'
              '${at.minute.toString().padLeft(2, '0')}';
          final attempts = event.answer.attemptLog;
          final detail =
              attempts.isEmpty
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
