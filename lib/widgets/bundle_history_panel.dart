import 'package:flutter/material.dart';

import '../models/study_plan_model.dart';
import '../services/study_history_service.dart';
import 'study_mode_icon.dart';

class BundleHistoryPanel extends StatefulWidget {
  final StudyPlan? plan;
  final WordbookStudyHistory overallHistory;
  final bool loading;

  const BundleHistoryPanel({
    super.key,
    required this.plan,
    required this.overallHistory,
    this.loading = false,
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
        plan != null &&
        plan.mode == StudyPlanMode.free &&
        plan.chunkCount > 1;
    final bundlePlan = canShowBundles ? plan : null;
    final bundle = bundlePlan != null
        ? (_selectedBundle ?? bundlePlan.currentChunk())
            .clamp(1, bundlePlan.chunkCount)
            .toInt()
        : 1;
    final history = _showBundle && bundlePlan != null
        ? StudyHistoryService.instance.bundleHistory(bundlePlan, bundle)
        : widget.overallHistory;
    final theme = Theme.of(context);

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
            child: !_showBundle
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
                        for (var index = 1;
                            index <= bundlePlan.chunkCount;
                            index++)
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
    final result = history.hasSessions
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
