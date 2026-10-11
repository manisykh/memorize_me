import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/study_plan_model.dart';
import '../services/study_history_service.dart';
import '../themes/memorize_identity.dart';
import 'study_mode_icon.dart';

class BundleHistoryPanel extends StatefulWidget {
  final StudyPlan? plan;
  final WordbookStudyHistory overallHistory;
  final bool loading;
  final bool compactSummary;
  final ValueChanged<StudyHistoryMode>? onOpenModeHistory;

  const BundleHistoryPanel({
    super.key,
    required this.plan,
    required this.overallHistory,
    this.loading = false,
    this.compactSummary = false,
    this.onOpenModeHistory,
  });

  @override
  State<BundleHistoryPanel> createState() => _BundleHistoryPanelState();
}

class _BundleHistoryPanelState extends State<BundleHistoryPanel> {
  bool _showBundle = false;
  int? _selectedBundle;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final canShowBundles =
        plan != null && plan.mode == StudyPlanMode.free && plan.chunkCount > 1;
    final bundlePlan = canShowBundles ? plan : null;
    final bundle =
        bundlePlan != null
            ? (_selectedBundle ?? bundlePlan.currentChunk())
                .clamp(1, bundlePlan.chunkCount)
                .toInt()
            : 1;
    final history =
        _showBundle && bundlePlan != null
            ? StudyHistoryService.instance.bundleHistory(bundlePlan, bundle)
            : widget.overallHistory;
    final theme = Theme.of(context);

    if (widget.compactSummary) {
      return _buildCompactSummary(
        context,
        bundlePlan: bundlePlan,
        bundle: bundle,
        history: history,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bundlePlan != null) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.menu_book_outlined),
                label: Text('전체 단어장'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.view_agenda_outlined),
                label: Text('묶음별'),
              ),
            ],
            selected: {_showBundle},
            onSelectionChanged: (selection) {
              setState(() => _showBundle = selection.first);
            },
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child:
                !_showBundle
                    ? const SizedBox(height: 12)
                    : Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 4),
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('${bundlePlan.revision}-$bundle'),
                        initialValue: bundle,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: '확인할 묶음',
                          prefixIcon: Icon(Icons.layers_outlined),
                        ),
                        items: [
                          for (
                            var index = 1;
                            index <= bundlePlan.chunkCount;
                            index++
                          )
                            DropdownMenuItem(
                              value: index,
                              child: Text(
                                '$index번 묶음${index == bundlePlan.currentChunk() ? ' · 현재 학습' : ''}',
                              ),
                            ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedBundle = value);
                        },
                      ),
                    ),
          ),
        ],
        _HistoryRow(
          label: '플래시카드',
          mode: StudyHistoryMode.flashcard,
          history: history.flashcard,
          successLabel: '알아요',
          failureLabel: '몰라요',
        ),
        const SizedBox(height: 9),
        _HistoryRow(
          label: '객관식 퀴즈',
          mode: StudyHistoryMode.multipleChoice,
          history: history.multipleChoice,
          successLabel: '정답',
          failureLabel: '오답',
        ),
        const SizedBox(height: 9),
        _HistoryRow(
          label: '스펠링 퀴즈',
          mode: StudyHistoryMode.spelling,
          history: history.spelling,
          successLabel: '정답',
          failureLabel: '오답',
        ),
        if (!widget.loading && !history.hasAnySessions) ...[
          const SizedBox(height: 10),
          Text(
            _showBundle && bundlePlan != null
                ? '이 묶음에서 완료한 학습이 아직 없습니다.'
                : '학습을 한 번 완료하면 최근 결과가 표시됩니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (_showBundle && bundlePlan != null) ...[
          const SizedBox(height: 8),
          Text(
            '현재 플랜 구성에서 $bundle번 묶음으로 완료한 학습 기준',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCompactSummary(
    BuildContext context, {
    required StudyPlan? bundlePlan,
    required int bundle,
    required WordbookStudyHistory history,
  }) {
    final identity = MemorizeIdentity.of(Theme.of(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (bundlePlan != null) ...[
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: identity.softInfo,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CompactScopeButton(
                    label: '전체 단어장',
                    selected: !_showBundle,
                    identity: identity,
                    onTap: () => setState(() => _showBundle = false),
                  ),
                ),
                Expanded(
                  child: _CompactScopeButton(
                    label: '현재 묶음',
                    selected: _showBundle,
                    identity: identity,
                    onTap: () {
                      setState(() {
                        _showBundle = true;
                        _selectedBundle ??= bundlePlan.currentChunk();
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child:
                !_showBundle
                    ? const SizedBox(height: 12)
                    : Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 2),
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('${bundlePlan.revision}-$bundle-compact'),
                        initialValue: bundle,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: '확인할 묶음',
                          filled: true,
                          fillColor: identity.softContext,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: BorderSide(color: identity.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(11),
                            borderSide: BorderSide(
                              color: identity.primaryAction,
                              width: 1.3,
                            ),
                          ),
                        ),
                        items: [
                          for (
                            var index = 1;
                            index <= bundlePlan.chunkCount;
                            index++
                          )
                            DropdownMenuItem(
                              value: index,
                              child: Text(
                                '$index번 묶음${index == bundlePlan.currentChunk() ? ' · 현재 학습' : ''}',
                              ),
                            ),
                        ],
                        onChanged:
                            (value) => setState(() => _selectedBundle = value),
                      ),
                    ),
          ),
        ],
        if (bundlePlan == null) const SizedBox(height: 2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _CompactHistorySummaryItem(
                label: '플래시카드',
                mode: StudyHistoryMode.flashcard,
                history: history.flashcard,
                successLabel: '알아요',
                failureLabel: '몰라요',
                identity: identity,
                onTap: null,
              ),
            ),
            _CompactHistoryDivider(identity: identity),
            Expanded(
              child: _CompactHistorySummaryItem(
                label: '객관식',
                mode: StudyHistoryMode.multipleChoice,
                history: history.multipleChoice,
                successLabel: '정답',
                failureLabel: '오답',
                identity: identity,
                onTap:
                    history.multipleChoice.hasSessions &&
                            widget.onOpenModeHistory != null
                        ? () => widget.onOpenModeHistory?.call(
                          StudyHistoryMode.multipleChoice,
                        )
                        : null,
              ),
            ),
            _CompactHistoryDivider(identity: identity),
            Expanded(
              child: _CompactHistorySummaryItem(
                label: '스펠링',
                mode: StudyHistoryMode.spelling,
                history: history.spelling,
                successLabel: '정답',
                failureLabel: '오답',
                identity: identity,
                onTap:
                    history.spelling.hasSessions &&
                            widget.onOpenModeHistory != null
                        ? () => widget.onOpenModeHistory?.call(
                          StudyHistoryMode.spelling,
                        )
                        : null,
              ),
            ),
          ],
        ),
        if (!widget.loading && !history.hasAnySessions) ...[
          const SizedBox(height: 10),
          Text(
            _showBundle && bundlePlan != null
                ? '이 묶음에서 완료한 학습이 아직 없습니다.'
                : '학습을 완료하면 최근 결과가 표시됩니다.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactScopeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final MemorizeIdentity identity;
  final VoidCallback onTap;

  const _CompactScopeButton({
    required this.label,
    required this.selected,
    required this.identity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? identity.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: identity.primaryAction.withValues(alpha: 0.09),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? identity.primaryAction : identity.mutedInk,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _CompactHistoryDivider extends StatelessWidget {
  final MemorizeIdentity identity;

  const _CompactHistoryDivider({required this.identity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 94,
      margin: const EdgeInsets.only(top: 12),
      color: identity.border,
    );
  }
}

class _CompactHistorySummaryItem extends StatelessWidget {
  final String label;
  final StudyHistoryMode mode;
  final StudyModeHistory history;
  final String successLabel;
  final String failureLabel;
  final MemorizeIdentity identity;
  final VoidCallback? onTap;

  const _CompactHistorySummaryItem({
    required this.label,
    required this.mode,
    required this.history,
    required this.successLabel,
    required this.failureLabel,
    required this.identity,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (mode) {
      StudyHistoryMode.flashcard => identity.success,
      StudyHistoryMode.multipleChoice => const Color(0xFFE77B12),
      StudyHistoryMode.spelling => const Color(0xFFE77B12),
    };
    final background = switch (mode) {
      StudyHistoryMode.flashcard => identity.softSuccess,
      StudyHistoryMode.multipleChoice => const Color(0xFFFFF4E8),
      StudyHistoryMode.spelling => const Color(0xFFFFF4E8),
    };
    final resultStyle = theme.textTheme.labelSmall?.copyWith(
      color: identity.mutedInk,
      fontWeight: FontWeight.w700,
      height: 1.25,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
          child: Column(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: BoxShape.circle,
                ),
                child: Icon(studyModeIcon(mode), color: color, size: 21),
              ),
              const SizedBox(height: 7),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (onTap != null) ...[
                    const SizedBox(width: 2),
                    Icon(
                      CupertinoIcons.chevron_forward,
                      size: 11,
                      color: identity.mutedInk,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
              Text(
                '${history.sessionCount}회',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              if (history.hasSessions)
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$successLabel ${history.latestSuccess}',
                        style: TextStyle(color: identity.primaryAction),
                      ),
                      TextSpan(
                        text: ' · ',
                        style: TextStyle(color: identity.mutedInk),
                      ),
                      TextSpan(
                        text: '$failureLabel ${history.latestFailure}',
                        style: TextStyle(color: identity.review),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: resultStyle,
                )
              else
                Text(
                  '최근 기록 없음',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: resultStyle,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final String label;
  final StudyHistoryMode mode;
  final StudyModeHistory history;
  final String successLabel;
  final String failureLabel;

  const _HistoryRow({
    required this.label,
    required this.mode,
    required this.history,
    required this.successLabel,
    required this.failureLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = studyModeColor(mode, theme.brightness);
    final result =
        history.hasSessions
            ? '최근 $successLabel ${history.latestSuccess}/${history.latestTotal} · '
                '$failureLabel ${history.latestFailure}/${history.latestTotal}'
            : '아직 완료한 학습 없음';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(studyModeIcon(mode), color: color, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  result,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${history.sessionCount}회',
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
