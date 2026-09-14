import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../providers/word_list_provider.dart';
import '../services/study_schedule_service.dart';
import '../services/srs_service.dart';
import 'glassmorphic_card.dart';
import 'study_guide.dart';

Future<void> showStudyPlanEditor(BuildContext context, Wordbook wordbook) async {
  final manager = context.read<WordbookManager>();
  try {
    final words = await manager.getAllWordsFrom(wordbook);
    if (!context.mounted) return;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('플랜을 만들 단어가 없습니다.')));
      return;
    }
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (_) => _PlanEditor(wordbook: wordbook, words: words, manager: manager),
    );
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('플랜을 불러오지 못했습니다. 다시 시도해주세요.')));
    }
  }
}

class StudyPlanPanel extends StatelessWidget {
  final StudyPlan plan;
  final Future<void> Function()? onChanged;
  const StudyPlanPanel({super.key, required this.plan, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WordbookManager>();
    final book = manager.getWordbookByDbFileName(plan.dbFileName);
    final current = manager.planFor(book) ?? plan;
    final words = context.watch<WordListNotifier>().words;
    final theme = Theme.of(context);
    final srs = SrsService();
    final schedule = StudyScheduleService();
    final available = manager.wordsAvailableForPlan(words, plan: current);
    final learned = words.where((w) => !srs.isNewWord(w)).length;
    final target = manager.recommendedNewWordSessionCount(words, plan: current);
    final unlockedKeys = (current.scheduleWordKeys ?? schedule.orderedKeys(words, current))
        .take(current.unlockedNewLimit()).toSet();
    final missing = words.where((w) => srs.isNewWord(w) && unlockedKeys.contains(StudyScheduleService.wordKey(w))).length;
    final actualKeys = words.map(StudyScheduleService.wordKey).toSet();
    Future<void> select(int bundle) async {
      try {
        await manager.selectPlanBundle(current, bundle);
        await onChanged?.call();
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('묶음을 변경하지 못했습니다. 다시 시도해주세요.')));
        }
      }
    }
    return GlassmorphicCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(current.mode == StudyPlanMode.free ? Icons.view_module_outlined : Icons.event_outlined,
              color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(current.scopeLabel,
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
          IconButton(tooltip: '플랜 안내', icon: const Icon(Icons.help_outline),
            onPressed: () => showStudyGuideSheet(context, StudyGuideCatalog.studyPlan)),
          IconButton(tooltip: '플랜 수정', icon: const Icon(Icons.tune),
            onPressed: book == null ? null : () async {
              await showStudyPlanEditor(context, book);
              await onChanged?.call();
            }),
        ]),
        if (current.mode == StudyPlanMode.free) ...[
          DropdownButtonFormField<int>(
            key: ValueKey('${current.revision}-${current.selectedBundle}'),
            initialValue: current.currentChunk(), isExpanded: true,
            decoration: const InputDecoration(labelText: '학습 묶음'),
            items: List.generate(current.chunkCount, (index) {
              final keys = schedule.bundleKeys(words, current, bundle: index + 1);
              final count = keys.where(actualKeys.contains).length;
              return DropdownMenuItem(value: index + 1, child: Text('${index + 1}번 묶음 · $count개'));
            }),
            onChanged: (value) { if (value != null) select(value); },
          ),
          const SizedBox(height: 10),
          Text('선택한 묶음 ${available.length}개 · 다른 묶음으로 이동해도 SRS 기록은 유지됩니다.',
            style: theme.textTheme.bodySmall),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: current.currentChunk() <= 1 ? null : () => select(current.currentChunk() - 1),
              icon: const Icon(Icons.chevron_left), label: const Text('이전 묶음'))),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(
              onPressed: current.currentChunk() >= current.chunkCount ? null : () => select(current.currentChunk() + 1),
              icon: const Icon(Icons.chevron_right), label: const Text('다음 묶음'))),
          ]),
        ] else ...[
          Text('1회 이상 학습 $learned/${words.length}개 · 이번 새 단어 최대 $target개',
            style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: words.isEmpty ? 0 : learned / words.length),
          const SizedBox(height: 8),
          Text(current.mode == StudyPlanMode.scheduled
              ? '1회 학습 목표 ${studyDateKey(current.targetEndDate())} · 일정상 열린 새 단어 중 미학습 $missing개'
              : '복습 대기 ${srs.dueWords(words).length}개를 기준으로 새 단어를 조절합니다. 미학습 일일 할당량은 이월하지 않습니다.',
            style: theme.textTheme.bodySmall),
        ],
      ]),
    );
  }
}

class _PlanEditor extends StatefulWidget {
  final Wordbook wordbook;
  final List<Word> words;
  final WordbookManager manager;
  const _PlanEditor({required this.wordbook, required this.words, required this.manager});
  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late final StudyPlan? _existing = widget.manager.planFor(widget.wordbook);
  late StudyPlanMode _mode = _existing?.mode ?? StudyPlanMode.free;
  late final _bundle = TextEditingController(text: '${_existing?.chunkCount ?? min(10, widget.words.length)}');
  late final _daily = TextEditingController(text: '${_existing?.dailyNewTarget ?? min(20, widget.words.length)}');
  bool _resetSchedule = false;
  bool _saving = false;
  String? _error;

  int get _newCount => widget.words.where(SrsService().isNewWord).length;
  bool get _keepSchedule => _existing?.mode == StudyPlanMode.scheduled &&
      _mode == StudyPlanMode.scheduled && !_resetSchedule;

  @override
  void dispose() { _bundle.dispose(); _daily.dispose(); super.dispose(); }

  Future<void> _save() async {
    final bundles = int.tryParse(_bundle.text);
    final daily = int.tryParse(_daily.text);
    if ((_mode == StudyPlanMode.free && (bundles == null || bundles < 1 || bundles > widget.words.length)) ||
        (_mode != StudyPlanMode.free && !_keepSchedule && (daily == null || daily < 1 || daily > widget.words.length))) {
      setState(() => _error = '1부터 ${widget.words.length} 사이의 숫자를 입력해주세요.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.manager.createStudyPlanForWordbook(widget.wordbook,
        chunkSize: _mode == StudyPlanMode.free ? (widget.words.length / bundles!).ceil() : daily!,
        dailyNewTarget: _keepSchedule ? _existing!.dailyNewTarget : (daily ?? 20),
        mode: _mode, bundleCount: (bundles ?? 10).clamp(1, widget.words.length).toInt(),
        resetSchedule: _resetSchedule,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() { _saving = false; _error = '플랜을 저장하지 못했습니다. 다시 시도해주세요.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = max(1, int.tryParse(_daily.text) ?? 20);
    final days = (_newCount / daily).ceil();
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day + max(0, days - 1));
    return PopScope(canPop: !_saving, child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('학습 플랜', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4), Text('${widget.wordbook.name} · ${widget.words.length}개'),
          const SizedBox(height: 12),
          RadioGroup<StudyPlanMode>(
            groupValue: _mode,
            onChanged: (value) {
              if (!_saving && value != null) {
                setState(() { _mode = value; _error = null; });
              }
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final mode in StudyPlanMode.values)
                  RadioListTile<StudyPlanMode>(
                    contentPadding: EdgeInsets.zero,
                    title: Text(mode.label), subtitle: Text(mode.description),
                    value: mode, enabled: !_saving,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_mode == StudyPlanMode.free) ...[
            TextField(controller: _bundle, enabled: !_saving, keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '나눌 학습 묶음 수', suffixText: '묶음'),
              onChanged: (_) => setState(() {})),
            const SizedBox(height: 8),
            Text('묶음당 약 ${(widget.words.length / max(1, int.tryParse(_bundle.text) ?? 10)).ceil()}개 · 다음 묶음은 직접 선택합니다.'),
            if (_existing != null) const Text('묶음 수를 바꾸면 구성이 다시 나뉩니다. 기존 학습 결과와 SRS는 유지됩니다.'),
          ] else ...[
            if (_existing?.mode == StudyPlanMode.scheduled && _mode == StudyPlanMode.scheduled)
              SwitchListTile(contentPadding: EdgeInsets.zero,
                title: const Text('일정 다시 조정'),
                subtitle: const Text('켜면 남은 새 단어를 오늘부터 다시 배정합니다. 끄면 기존 일정과 목표를 유지합니다.'),
                value: _resetSchedule, onChanged: _saving ? null : (v) => setState(() => _resetSchedule = v)),
            TextField(controller: _daily, enabled: !_saving && !_keepSchedule,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '하루 새 단어 목표', suffixText: '개'),
              onChanged: (_) => setState(() {})),
            if (_mode == StudyPlanMode.scheduled) ...[
              const SizedBox(height: 8),
              Text(_keepSchedule ? '기존 1회 학습 목표일 ${studyDateKey(_existing!.targetEndDate())}'
                  : '남은 새 단어 $_newCount개 · $days일 · 1회 학습 목표 ${studyDateKey(end)}'),
              TextButton.icon(onPressed: _saving || _keepSchedule || _newCount == 0 ? null : () async {
                final lastDate = DateTime(today.year + 10, today.month, today.day);
                final selected = await showDatePicker(context: context,
                  initialDate: end.isAfter(lastDate) ? lastDate : end,
                  firstDate: studyDay(today), lastDate: lastDate);
                if (selected == null || !mounted) return;
                final count = DateTime.utc(selected.year, selected.month, selected.day)
                    .difference(DateTime.utc(today.year, today.month, today.day)).inDays + 1;
                setState(() => _daily.text = '${(_newCount / count).ceil()}');
              }, icon: const Icon(Icons.event), label: const Text('목표 날짜로 분량 계산')),
              const Text('목표일은 새 단어의 1회 학습 기준입니다. 암기 상태와 SRS 복습은 별도로 관리합니다.'),
              if (_existing?.mode == StudyPlanMode.scheduled) const Text('새로 추가한 단어도 일정에 넣으려면 일정 다시 조정을 켜주세요.'),
            ] else ...[
              const SizedBox(height: 8),
              const Text('먼 미래의 새 단어 수와 완료일은 확정하지 않습니다. 오늘의 복습량을 반영해 조절합니다.'),
            ],
          ],
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12),
            child: Text(_error!, style: TextStyle(color: theme.colorScheme.error))),
          const SizedBox(height: 18),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? '저장 중' : '플랜 적용')),
          if (_existing != null) TextButton(onPressed: _saving ? null : () async {
            final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
              title: const Text('플랜을 해제할까요?'), content: const Text('학습 이력과 SRS는 유지되고 단어장 전체를 학습할 수 있습니다.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('해제'))]));
            if (confirmed != true || !mounted) return;
            setState(() => _saving = true);
            try {
              await widget.manager.deleteStudyPlan(_existing);
              if (context.mounted) Navigator.pop(context);
            } catch (_) {
              if (mounted) setState(() { _saving = false; _error = '해제하지 못했습니다. 다시 시도해주세요.'; });
            }
          }, child: const Text('플랜 해제')),
        ],
      )),
    ));
  }
}
