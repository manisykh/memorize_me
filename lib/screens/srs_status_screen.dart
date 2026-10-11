import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/mode_state_service.dart';
import '../services/srs_service.dart';
import '../themes/memorize_identity.dart';

class SrsStatusScreen extends StatefulWidget {
  final bool initialPlanScope;

  const SrsStatusScreen({super.key, this.initialPlanScope = false});

  @override
  State<SrsStatusScreen> createState() => _SrsStatusScreenState();
}

class _SrsStatusScreenState extends State<SrsStatusScreen> {
  static const List<SrsStage> _displayOrder = <SrsStage>[
    SrsStage.newWord,
    SrsStage.learning,
    SrsStage.scheduled,
    SrsStage.due,
    SrsStage.mature,
  ];

  final SrsService _srsService = SrsService();
  final ScrollController _scrollController = ScrollController();
  final Map<SrsStage, GlobalKey> _sectionKeys = <SrsStage, GlobalKey>{
    for (final stage in SrsStage.values) stage: GlobalKey(),
  };

  Wordbook? _selectedWordbook;
  StudyPlan? _studyPlan;
  List<Word> _scopedWords = <Word>[];
  bool _showPlanScope = false;
  bool _isLoading = true;

  int _newCount = 0;
  int _learningCount = 0;
  int _scheduledCount = 0;
  int _reviewCount = 0;
  int _matureCount = 0;

  @override
  void initState() {
    super.initState();
    _showPlanScope = widget.initialPlanScope;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeData());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();
    final lastUsedId = await modeStateService.getLastUsedWordbookId(
      LearningMode.srsStatus,
    );

    Wordbook? initialWordbook = wordbookManager.activeWordbook;
    initialWordbook ??= wordbookManager.getWordbookById(lastUsedId ?? -1);

    if (initialWordbook == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    await _loadWordbook(initialWordbook);
  }

  Future<void> _loadWordbook(Wordbook wordbook) async {
    setState(() => _isLoading = true);

    final wordbookManager = context.read<WordbookManager>();
    final wordListNotifier = context.read<WordListNotifier>();
    final modeStateService = context.read<ModeStateService>();

    await wordbookManager.setActiveWordbook(wordbook);
    if (!mounted) return;

    final words = wordListNotifier.words;
    final studyPlan = wordbookManager.planFor(wordbook);
    final showPlanScope = widget.initialPlanScope && studyPlan != null;
    final scopedWords =
        showPlanScope
            ? wordbookManager.wordsAvailableForPlan(words, plan: studyPlan)
            : words;

    setState(() {
      _selectedWordbook = wordbook;
      _studyPlan = studyPlan;
      _showPlanScope = showPlanScope;
      _scopedWords = scopedWords;
      _calculateStatistics();
      _isLoading = false;
    });

    final wordbookId = wordbook.id;
    if (wordbookId != null) {
      await modeStateService.setLastUsedWordbookId(
        LearningMode.srsStatus,
        wordbookId,
      );
    }
  }

  void _calculateStatistics() {
    var newCount = 0;
    var learningCount = 0;
    var scheduledCount = 0;
    var reviewCount = 0;
    var matureCount = 0;
    final today = _srsService.today();

    for (final word in _scopedWords) {
      switch (_srsService.stageFor(word, baseDate: today)) {
        case SrsStage.newWord:
          newCount++;
          break;
        case SrsStage.learning:
          learningCount++;
          break;
        case SrsStage.scheduled:
          scheduledCount++;
          break;
        case SrsStage.due:
          reviewCount++;
          break;
        case SrsStage.mature:
          matureCount++;
          break;
      }
    }

    _newCount = newCount;
    _learningCount = learningCount;
    _scheduledCount = scheduledCount;
    _reviewCount = reviewCount;
    _matureCount = matureCount;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final visibleStages =
        _displayOrder.where((stage) => _countForStage(stage) > 0).toList();

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          '단어별 SRS 상태',
          style: theme.textTheme.titleLarge?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: identity.primaryAction),
              )
              : _selectedWordbook == null
              ? _EmptyStatusView(identity: identity)
              : SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    MemorizeIdentity.pagePadding,
                    8,
                    MemorizeIdentity.pagePadding,
                    32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildScopeContext(theme, identity),
                      const SizedBox(height: 18),
                      _buildStageGuide(theme, identity),
                      const SizedBox(height: 26),
                      Text(
                        '단어별 상태',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: identity.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '다음 복습일 순서로 확인하세요.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: identity.mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (visibleStages.isEmpty)
                        _buildEmptyWordList(theme, identity)
                      else
                        for (
                          var index = 0;
                          index < visibleStages.length;
                          index++
                        ) ...[
                          _buildStageSection(
                            theme,
                            identity,
                            visibleStages[index],
                          ),
                          if (index != visibleStages.length - 1)
                            const SizedBox(height: 12),
                        ],
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            CupertinoIcons.info_circle,
                            size: 18,
                            color: identity.mutedInk,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '학습 결과에 따라 기억 단계와 다음 복습일은 달라질 수 있어요.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: identity.mutedInk,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Widget _buildScopeContext(ThemeData theme, MemorizeIdentity identity) {
    final wordbook = _selectedWordbook!;
    final plan = _studyPlan;
    final scopeLabel =
        _showPlanScope && plan != null ? plan.scopeLabel : '전체 단어장';

    return Semantics(
      label: '현재 기준 ${wordbook.name}, $scopeLabel, ${_scopedWords.length}개 단어',
      child: Row(
        children: [
          Icon(CupertinoIcons.book, color: identity.success, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${wordbook.name} · $scopeLabel · ${_scopedWords.length}개',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageGuide(ThemeData theme, MemorizeIdentity identity) {
    return Container(
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '기억 단계와 기준',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '전체 ${_scopedWords.length}개',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < _displayOrder.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: identity.border,
                indent: 60,
                endIndent: 16,
              ),
            _buildGuideRow(theme, identity, _displayOrder[index]),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideRow(
    ThemeData theme,
    MemorizeIdentity identity,
    SrsStage stage,
  ) {
    final color = _colorForStage(identity, stage);
    final count = _countForStage(stage);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _softColorForStage(identity, stage),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(_iconForStage(stage), color: color, size: 18),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _labelForStage(stage),
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '$count',
                    maxLines: 1,
                    softWrap: false,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 40, color: identity.border),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _descriptionForStage(stage),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: identity.mutedInk,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 2),
          IconButton(
            tooltip:
                count == 0
                    ? '${_labelForStage(stage)} 단어 없음'
                    : '${_labelForStage(stage)} 목록으로 이동',
            onPressed: count == 0 ? null : () => _scrollToStage(stage),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            visualDensity: VisualDensity.compact,
            icon: Icon(
              CupertinoIcons.arrow_down,
              size: 16,
              color: count == 0 ? identity.border : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStageSection(
    ThemeData theme,
    MemorizeIdentity identity,
    SrsStage stage,
  ) {
    final words = _wordsForStage(stage);
    final color = _colorForStage(identity, stage);

    return Column(
      key: _sectionKeys[stage],
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 50,
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _softColorForStage(identity, stage),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(_sectionHeaderIcon(stage), color: color, size: 25),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sectionTitleForStage(stage, words),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_labelForStage(stage)} ${words.length}개',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: identity.mutedInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          child: Column(
            children: [
              for (var index = 0; index < words.length; index++) ...[
                _buildWordRow(theme, identity, stage, words[index]),
                if (index != words.length - 1)
                  Divider(
                    height: 1,
                    color: identity.border,
                    indent: 14,
                    endIndent: 14,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWordList(ThemeData theme, MemorizeIdentity identity) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Text(
        '표시할 단어가 없습니다.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: identity.mutedInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildWordRow(
    ThemeData theme,
    MemorizeIdentity identity,
    SrsStage stage,
    Word word,
  ) {
    final color = _colorForStage(identity, stage);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  word.word,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  word.meaning,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 5,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _softColorForStage(identity, stage),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_iconForStage(stage), color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _labelForStage(stage),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      for (final line in _detailLinesForWord(word, stage))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            line,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: identity.mutedInk,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _detailLinesForWord(Word word, SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return const <String>['첫 학습 후 일정 시작'];
      case SrsStage.learning:
        return const <String>['최근 학습 완료'];
      case SrsStage.scheduled:
        return <String>[_reviewDateLabel(word, stage)];
      case SrsStage.due:
        return <String>[_reasonForWord(word, stage)];
      case SrsStage.mature:
        return <String>[_reviewDateLabel(word, stage), '연속 정답으로 간격 증가'];
    }
  }

  Future<void> _scrollToStage(SrsStage stage) async {
    final targetContext = _sectionKeys[stage]?.currentContext;
    if (targetContext == null) return;
    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0.04,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  IconData _sectionHeaderIcon(SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return CupertinoIcons.book;
      case SrsStage.learning:
      case SrsStage.scheduled:
      case SrsStage.due:
      case SrsStage.mature:
        return CupertinoIcons.calendar;
    }
  }

  String _sectionTitleForStage(SrsStage stage, List<Word> words) {
    switch (stage) {
      case SrsStage.newWord:
        return '첫 학습 전';
      case SrsStage.learning:
        return '기억 정착 중';
      case SrsStage.scheduled:
        return _earliestReviewDateLabel(words) ?? '다음 복습 예정';
      case SrsStage.due:
        final today = _srsService.today();
        return '오늘 · ${today.month}월 ${today.day}일 (${_weekdayLabel(today.weekday)})';
      case SrsStage.mature:
        return '그 이후';
    }
  }

  String? _earliestReviewDateLabel(List<Word> words) {
    final dates =
        words.map(_srsService.reviewDateFor).whereType<DateTime>().toList()
          ..sort();
    if (dates.isEmpty) return null;
    final date = dates.first;
    return '${date.month}월 ${date.day}일 (${_weekdayLabel(date.weekday)})';
  }

  List<Word> _wordsForStage(SrsStage stage) {
    final today = _srsService.today();
    final words =
        _scopedWords
            .where(
              (word) => _srsService.stageFor(word, baseDate: today) == stage,
            )
            .toList();

    if (stage == SrsStage.due) {
      words.sort(
        (a, b) => _srsService
            .reviewPriority(b, baseDate: today)
            .compareTo(_srsService.reviewPriority(a, baseDate: today)),
      );
      return words;
    }

    if (stage == SrsStage.newWord) {
      words.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      return words;
    }

    words.sort((a, b) {
      final aDate = _srsService.reviewDateFor(a);
      final bDate = _srsService.reviewDateFor(b);
      if (aDate == null && bDate == null) return a.word.compareTo(b.word);
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      final dateCompare = aDate.compareTo(bDate);
      return dateCompare == 0 ? a.word.compareTo(b.word) : dateCompare;
    });
    return words;
  }

  int _countForStage(SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return _newCount;
      case SrsStage.learning:
        return _learningCount;
      case SrsStage.scheduled:
        return _scheduledCount;
      case SrsStage.due:
        return _reviewCount;
      case SrsStage.mature:
        return _matureCount;
    }
  }

  String _labelForStage(SrsStage stage) {
    return _srsService.labelForStage(stage);
  }

  String _descriptionForStage(SrsStage stage) {
    return _srsService.descriptionForStage(stage);
  }

  IconData _iconForStage(SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return CupertinoIcons.doc_text;
      case SrsStage.learning:
        return CupertinoIcons.clock;
      case SrsStage.scheduled:
        return CupertinoIcons.calendar;
      case SrsStage.due:
        return CupertinoIcons.arrow_2_circlepath;
      case SrsStage.mature:
        return CupertinoIcons.check_mark_circled_solid;
    }
  }

  Color _colorForStage(MemorizeIdentity identity, SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return identity.primaryAction;
      case SrsStage.learning:
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFFF2A84B)
            : const Color(0xFFE17A00);
      case SrsStage.scheduled:
        return identity.scheduled;
      case SrsStage.due:
        return identity.review;
      case SrsStage.mature:
        return identity.success;
    }
  }

  Color _softColorForStage(MemorizeIdentity identity, SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return identity.softInfo;
      case SrsStage.learning:
        return Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF493520)
            : const Color(0xFFFFF4E6);
      case SrsStage.scheduled:
        return identity.softScheduled;
      case SrsStage.due:
        return identity.softReview;
      case SrsStage.mature:
        return identity.softSuccess;
    }
  }

  String _reviewDateLabel(Word word, SrsStage stage) {
    if (stage == SrsStage.newWord) return '첫 학습 전';

    final date = _srsService.reviewDateFor(word);
    if (date == null) return '일정 계산 중';

    final today = _srsService.today();
    if (_isSameDay(date, today)) return '오늘';
    return '${date.month}월 ${date.day}일 (${_weekdayLabel(date.weekday)})';
  }

  String _reasonForWord(Word word, SrsStage stage) {
    final today = _srsService.today();
    final reviewDate = _srsService.reviewDateFor(word);

    switch (stage) {
      case SrsStage.newWord:
        return '첫 학습 후 일정 시작';
      case SrsStage.learning:
        return '짧은 간격으로 기억을 확인하는 중';
      case SrsStage.scheduled:
        return _reviewDateLabel(word, stage);
      case SrsStage.due:
        if (reviewDate != null && reviewDate.isBefore(today)) {
          final overdueDays = today.difference(reviewDate).inDays;
          return '예정일이 $overdueDays일 지났어요';
        }
        return '복습 예정일 도달';
      case SrsStage.mature:
        return '복습 간격이 길어진 상태';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayLabel(int weekday) =>
      const <String>['월', '화', '수', '목', '금', '토', '일'][weekday - 1];
}

class _EmptyStatusView extends StatelessWidget {
  final MemorizeIdentity identity;

  const _EmptyStatusView({required this.identity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(CupertinoIcons.book, size: 44, color: identity.mutedInk),
            const SizedBox(height: 12),
            Text(
              '확인할 단어장이 없습니다.',
              style: theme.textTheme.titleMedium?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '통계 탭에서 단어장을 선택한 뒤 다시 열어주세요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: identity.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
