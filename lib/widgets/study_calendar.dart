import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/study_history_service.dart';
import '../services/study_schedule_service.dart';
import '../themes/memorize_identity.dart';
import 'study_mode_icon.dart';

class StudyCalendar extends StatefulWidget {
  final StudyHistoryService? history;
  final DateTime? initialDate;
  final bool initialPlanScope;

  const StudyCalendar({
    super.key,
    this.history,
    this.initialDate,
    this.initialPlanScope = false,
  });

  @override
  State<StudyCalendar> createState() => _StudyCalendarState();
}

class _CalendarBook {
  final Wordbook book;
  final List<Word> words;
  final StudyPlan? plan;

  const _CalendarBook(this.book, this.words, this.plan);
}

class _CalendarData {
  final List<_CalendarBook> books;
  final List<StudySessionRecord> sessions;
  final List<Map<String, dynamic>> versions;
  final Map<String, Set<StudyHistoryMode>> modesByDay =
      <String, Set<StudyHistoryMode>>{};
  final Set<String> dueDates = <String>{};

  _CalendarData(this.books, this.sessions, this.versions) {
    for (final session in sessions) {
      modesByDay
          .putIfAbsent(
            studyDateKey(session.completedAt!),
            () => <StudyHistoryMode>{},
          )
          .add(session.mode);
    }

    final today = studyDay(DateTime.now());
    final schedule = StudyScheduleService();
    for (final book in books) {
      for (final word in book.words) {
        final due = schedule.effectiveReviewDate(word, today);
        if (due != null) dueDates.add(studyDateKey(due));
      }
    }
  }

  StudyPlan? planOn(_CalendarBook book, DateTime day) =>
      StudyScheduleService().planOnDate(
        dbFileName: book.book.dbFileName,
        date: day,
        versions: versions,
        fallback: book.plan,
      );

  List<StudySessionRecord> sessionsOn(DateTime date) =>
      sessions
          .where(
            (session) =>
                studyDateKey(session.completedAt!) == studyDateKey(date),
          )
          .toList()
        ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
}

class _UpcomingSchedule {
  final DateTime date;
  final int reviewCount;
  final int planCount;

  const _UpcomingSchedule({
    required this.date,
    required this.reviewCount,
    required this.planCount,
  });
}

class _ModeSummary {
  final StudyHistoryMode mode;
  final int sessions;
  final int success;
  final int failure;

  const _ModeSummary({
    required this.mode,
    required this.sessions,
    required this.success,
    required this.failure,
  });
}

class _StudyCalendarState extends State<StudyCalendar>
    with WidgetsBindingObserver {
  late DateTime _selected;
  late DateTime _month;
  bool _allBooks = false;
  late bool _planScope;
  Future<_CalendarData>? _future;
  String? _loadKey;

  late final StudyHistoryService _history =
      widget.history ?? StudyHistoryService.instance;
  final StudyScheduleService _schedule = StudyScheduleService();

  @override
  void initState() {
    super.initState();
    _selected = studyDay(widget.initialDate ?? DateTime.now());
    _month = DateTime(_selected.year, _selected.month);
    _planScope = widget.initialPlanScope;
    _history.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _history.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _refresh() {
    if (mounted) setState(() => _future = null);
  }

  Future<_CalendarData> _load(WordbookManager manager) async {
    await _history.ensureLoaded();
    final books =
        _allBooks
            ? List<Wordbook>.from(manager.wordbooks)
            : <Wordbook>[
              if (manager.activeWordbook != null) manager.activeWordbook!,
            ];
    final data = <_CalendarBook>[];

    for (final book in books) {
      final plan = manager.planFor(book);
      final allWords = await manager.getAllWordsFrom(book);
      final words =
          !_allBooks && _planScope
              ? manager.wordsAvailableForPlan(allWords, plan: plan)
              : allWords;
      data.add(_CalendarBook(book, words, plan));
    }

    final names = books.map((book) => book.dbFileName).toSet();
    return _CalendarData(
      data,
      _history.completedSessions
          .where((session) => names.contains(session.dbFileName))
          .toList(),
      await _history.planVersions(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WordbookManager>();
    final key =
        '${manager.statsRevision}-${manager.activeWordbook?.dbFileName}-'
        '$_allBooks-$_planScope-${studyDateKey(DateTime.now())}';
    if (_loadKey != key) {
      _loadKey = key;
      _future = null;
    }
    _future ??= _load(manager);

    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '학습 달력',
          style: theme.textTheme.headlineMedium?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '학습 기록과 예정된 일정을 한눈에 확인하세요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: identity.mutedInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 18),
        _buildContextAndScope(manager, theme, identity),
        const SizedBox(height: 14),
        FutureBuilder<_CalendarData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _CalendarLoadError(identity: identity, onRetry: _refresh);
            }
            if (snapshot.connectionState == ConnectionState.waiting ||
                !snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(36),
                child: Center(
                  child: CircularProgressIndicator(
                    color: identity.primaryAction,
                  ),
                ),
              );
            }
            return _buildContent(snapshot.data!, theme, identity);
          },
        ),
      ],
    );
  }

  Widget _buildContextAndScope(
    WordbookManager manager,
    ThemeData theme,
    MemorizeIdentity identity,
  ) {
    final active = manager.activeWordbook;
    final plan = active == null ? null : manager.planFor(active);
    final contextLabel =
        _allBooks
            ? '전체 단어장 · ${manager.wordbooks.length}개'
            : active == null
            ? '학습 단어장을 선택하세요'
            : plan == null
            ? '${active.name} · 전체 단어장'
            : '${active.name} · ${plan.progressLabel}';

    return Row(
      children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: identity.surface,
              borderRadius: BorderRadius.circular(
                MemorizeIdentity.contextRadius,
              ),
              border: Border.all(color: identity.border),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.book, color: identity.success, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    contextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        _CalendarScopeToggle(
          allBooks: _allBooks,
          identity: identity,
          onChanged: (allBooks) {
            setState(() {
              _allBooks = allBooks;
              if (_allBooks) _planScope = false;
              _future = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildContent(
    _CalendarData data,
    ThemeData theme,
    MemorizeIdentity identity,
  ) {
    final today = studyDay(DateTime.now());
    final upcoming = _upcomingSchedules(data, today);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMonthCard(data, today, theme, identity),
        const SizedBox(height: 12),
        _buildLegend(identity),
        const SizedBox(height: 24),
        Text(
          '다가오는 일정',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        _buildUpcomingSchedule(data, upcoming, today, theme, identity),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildMonthCard(
    _CalendarData data,
    DateTime today,
    ThemeData theme,
    MemorizeIdentity identity,
  ) {
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday % 7;
    final cells = ((days + offset + 6) ~/ 7) * 7;
    final textScale = MediaQuery.textScalerOf(context).scale(12) / 12;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: '이전 달',
                onPressed: () => _moveMonth(-1),
                icon: Icon(
                  CupertinoIcons.chevron_left,
                  color: identity.ink,
                  size: 21,
                ),
              ),
              Expanded(
                child: Text(
                  '${_month.year}년 ${_month.month}월',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selected = today;
                    _month = DateTime(today.year, today.month);
                  });
                },
                child: const Text('오늘'),
              ),
              IconButton(
                tooltip: '다음 달',
                onPressed: () => _moveMonth(1),
                icon: Icon(
                  CupertinoIcons.chevron_right,
                  color: identity.ink,
                  size: 21,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final weekday in const <String>[
                '일',
                '월',
                '화',
                '수',
                '목',
                '금',
                '토',
              ])
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 48 * textScale.clamp(1.0, 1.45).toDouble(),
              crossAxisSpacing: 2,
              mainAxisSpacing: 3,
            ),
            itemCount: cells,
            itemBuilder: (context, index) {
              final number = index - offset + 1;
              if (number < 1 || number > days) {
                return const SizedBox.shrink();
              }

              final date = DateTime(_month.year, _month.month, number);
              final completed =
                  data.modesByDay[studyDateKey(date)]?.isNotEmpty == true;
              final due =
                  !date.isBefore(today) &&
                  data.dueDates.contains(studyDateKey(date));
              final planned = data.books.any(
                (book) => _planCountOn(data, book, date, today) > 0,
              );
              final selected = _isSameDay(date, _selected);
              final isToday = _isSameDay(date, today);

              return Semantics(
                button: true,
                selected: selected,
                label:
                    '${studyDateKey(date)}'
                    '${completed ? ' 학습 완료' : ''}'
                    '${due ? ' SRS 복습 예정' : ''}'
                    '${planned ? ' 학습 계획' : ''}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _openDayDetails(data, date, today),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color:
                              selected
                                  ? identity.primaryAction
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                          border:
                              !selected && isToday
                                  ? Border.all(
                                    color: identity.primaryAction,
                                    width: 1.5,
                                  )
                                  : null,
                        ),
                        child: Text(
                          '$number',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                selected
                                    ? Colors.white
                                    : date.weekday == DateTime.sunday
                                    ? identity.review
                                    : identity.ink,
                            fontWeight:
                                selected || isToday
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
                        height: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (completed)
                              _CalendarMarker.completed(identity.success),
                            if (completed && (due || planned))
                              const SizedBox(width: 3),
                            if (due)
                              _CalendarMarker.review(identity.primaryAction),
                            if (due && planned) const SizedBox(width: 3),
                            if (planned)
                              _CalendarMarker.plan(const Color(0xFFFF920F)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(MemorizeIdentity identity) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 14,
      runSpacing: 8,
      children: [
        _CalendarLegendItem(
          marker: _CalendarMarker.completed(identity.success),
          label: '학습 완료',
          identity: identity,
        ),
        _CalendarLegendItem(
          marker: _CalendarMarker.review(identity.primaryAction),
          label: '복습 예정',
          identity: identity,
        ),
        _CalendarLegendItem(
          marker: _CalendarMarker.plan(const Color(0xFFFF920F)),
          label: '학습 계획',
          identity: identity,
        ),
      ],
    );
  }

  Widget _buildUpcomingSchedule(
    _CalendarData data,
    List<_UpcomingSchedule> upcoming,
    DateTime today,
    ThemeData theme,
    MemorizeIdentity identity,
  ) {
    if (upcoming.isEmpty) {
      return _CalendarEmptyGroup(
        label: '앞으로 예정된 복습이나 학습 계획이 없습니다.',
        identity: identity,
      );
    }

    return _CalendarGroupedSurface(
      identity: identity,
      children: [
        for (var index = 0; index < upcoming.length; index++) ...[
          _buildUpcomingRow(data, upcoming[index], today, theme, identity),
          if (index != upcoming.length - 1)
            Divider(height: 1, color: identity.border, indent: 14),
        ],
      ],
    );
  }

  Widget _buildUpcomingRow(
    _CalendarData data,
    _UpcomingSchedule item,
    DateTime today,
    ThemeData theme,
    MemorizeIdentity identity,
  ) {
    final isToday = _isSameDay(item.date, today);
    final color =
        item.reviewCount > 0 ? identity.primaryAction : const Color(0xFFFF920F);
    final icon =
        item.reviewCount > 0 && item.planCount > 0
            ? CupertinoIcons.book
            : item.reviewCount > 0
            ? CupertinoIcons.arrow_2_circlepath
            : CupertinoIcons.calendar;
    final parts = <String>[
      if (item.reviewCount > 0) '복습 ${item.reviewCount}개',
      if (item.planCount > 0) '새 단어 ${item.planCount}개',
    ];

    return Material(
      color:
          isToday
              ? identity.softContext.withValues(alpha: 0.62)
              : Colors.transparent,
      child: InkWell(
        onTap: () => _openDayDetails(data, item.date, today),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isToday ? '오늘' : '${item.date.month}월 ${item.date.day}일',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isToday ? identity.primaryAction : identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _weekdayLongLabel(item.date.weekday),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 38, color: identity.border),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      item.reviewCount > 0
                          ? identity.softInfo
                          : const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  parts.join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 6),
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

  List<_UpcomingSchedule> _upcomingSchedules(
    _CalendarData data,
    DateTime today,
  ) {
    final result = <_UpcomingSchedule>[];
    for (var offset = 0; offset < 35 && result.length < 3; offset++) {
      final date = today.add(Duration(days: offset));
      var reviewCount = 0;
      var planCount = 0;
      for (final book in data.books) {
        reviewCount += _reviewWordsOn(book, date, today).length;
        planCount += _planCountOn(data, book, date, today);
      }
      if (reviewCount == 0 && planCount == 0) continue;
      result.add(
        _UpcomingSchedule(
          date: date,
          reviewCount: reviewCount,
          planCount: planCount,
        ),
      );
    }
    return result;
  }

  List<Word> _reviewWordsOn(_CalendarBook book, DateTime date, DateTime today) {
    if (date.isBefore(today)) return const <Word>[];
    return <Word>[
      if (_isSameDay(date, today)) ..._schedule.overdue(book.words, today),
      ..._schedule.dueOn(book.words, date),
    ];
  }

  int _planCountOn(
    _CalendarData data,
    _CalendarBook book,
    DateTime date,
    DateTime today,
  ) {
    final plan = data.planOn(book, date);
    if (plan == null || plan.status != StudyPlanStatus.active) return 0;

    switch (plan.mode) {
      case StudyPlanMode.scheduled:
        return _schedule.scheduledKeysOn(book.words, plan, date).length;
      case StudyPlanMode.free:
        if (!_isSameDay(date, today)) return 0;
        return _schedule.bundleKeys(book.words, plan).length;
      case StudyPlanMode.reviewFirst:
        if (!_isSameDay(date, today)) return 0;
        final reviewCount = _reviewWordsOn(book, date, today).length;
        return _schedule.adaptiveTarget(plan.dailyNewTarget, reviewCount);
    }
  }

  void _openDayDetails(_CalendarData data, DateTime date, DateTime today) {
    setState(() => _selected = studyDay(date));
    final identity = MemorizeIdentity.of(Theme.of(context));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.34),
      builder:
          (sheetContext) => FractionallySizedBox(
            heightFactor: 0.78,
            child: _buildDayDetailsSheet(
              sheetContext,
              data,
              studyDay(date),
              today,
              identity,
            ),
          ),
    );
  }

  Widget _buildDayDetailsSheet(
    BuildContext sheetContext,
    _CalendarData data,
    DateTime date,
    DateTime today,
    MemorizeIdentity identity,
  ) {
    final theme = Theme.of(sheetContext);
    final sessions = data.sessionsOn(date);
    final modeSummaries = _modeSummaries(sessions);

    return Material(
      color: identity.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: identity.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        children: [
                          Text(
                            '${date.month}월 ${date.day}일 ${_weekdayLongLabel(date.weekday)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: identity.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (_isSameDay(date, today))
                            Text(
                              '오늘',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: identity.primaryAction,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _sheetContextLabel(data),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: identity.mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '닫기',
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: Icon(CupertinoIcons.xmark, color: identity.mutedInk),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _sheetSectionTitle('완료한 학습', theme, identity),
            const SizedBox(height: 10),
            _buildCompletedStudyGroup(modeSummaries, theme, identity),
            const SizedBox(height: 22),
            _sheetSectionTitle('예정된 일정', theme, identity),
            const SizedBox(height: 10),
            _buildPlannedScheduleGroup(data, date, today, theme, identity),
            if (_history.lastError != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _history.retrySaving,
                icon: const Icon(CupertinoIcons.refresh),
                label: const Text('학습 기록 저장 다시 시도'),
              ),
            ],
            if (context.read<WordbookManager>().srsSaveError != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: context.read<WordbookManager>().retrySrsSaving,
                icon: const Icon(CupertinoIcons.refresh),
                label: const Text('복습 일정 저장 다시 시도'),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  CupertinoIcons.info_circle,
                  size: 17,
                  color: identity.mutedInk,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'SRS 일정은 학습 결과에 따라 달라질 수 있어요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: identity.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetSectionTitle(
    String title,
    ThemeData theme,
    MemorizeIdentity identity,
  ) => Text(
    title,
    style: theme.textTheme.titleLarge?.copyWith(
      color: identity.ink,
      fontWeight: FontWeight.w900,
    ),
  );

  Widget _buildCompletedStudyGroup(
    List<_ModeSummary> summaries,
    ThemeData theme,
    MemorizeIdentity identity,
  ) {
    if (summaries.isEmpty) {
      return _CalendarEmptyGroup(
        label: '이 날짜에 완료한 학습이 없습니다.',
        identity: identity,
      );
    }

    return _CalendarGroupedSurface(
      identity: identity,
      children: [
        for (var index = 0; index < summaries.length; index++) ...[
          _buildModeSummaryRow(summaries[index], theme, identity),
          if (index != summaries.length - 1)
            Divider(height: 1, color: identity.border, indent: 66),
        ],
      ],
    );
  }

  Widget _buildModeSummaryRow(
    _ModeSummary summary,
    ThemeData theme,
    MemorizeIdentity identity,
  ) {
    final visual = _modeVisual(summary.mode, identity);
    final successLabel =
        summary.mode == StudyHistoryMode.flashcard ? '알아요' : '정답';
    final failureLabel =
        summary.mode == StudyHistoryMode.flashcard ? '몰라요' : '오답';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: visual.$2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              studyModeIcon(summary.mode),
              color: visual.$1,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${_modeShortLabel(summary.mode)} · ${summary.sessions}회',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _ResultMetric(
            label: successLabel,
            value: summary.success,
            color: identity.primaryAction,
            identity: identity,
          ),
          Container(
            width: 1,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 10),
            color: identity.border,
          ),
          _ResultMetric(
            label: failureLabel,
            value: summary.failure,
            color: identity.review,
            identity: identity,
          ),
        ],
      ),
    );
  }

  Widget _buildPlannedScheduleGroup(
    _CalendarData data,
    DateTime date,
    DateTime today,
    ThemeData theme,
    MemorizeIdentity identity,
  ) {
    final rows = <Widget>[];
    for (final book in data.books) {
      final reviewCount = _reviewWordsOn(book, date, today).length;
      final plan = data.planOn(book, date);
      final planCount = _planCountOn(data, book, date, today);

      if (reviewCount > 0) {
        rows.add(
          _ScheduleDetailRow(
            icon: CupertinoIcons.arrow_2_circlepath,
            color: identity.primaryAction,
            background: identity.softInfo,
            title: 'SRS 복습 $reviewCount개',
            subtitle:
                '${book.book.name} · ${_isSameDay(date, today) ? '오늘 복습 예정' : '복습 예정'}',
            identity: identity,
          ),
        );
      }

      if (planCount > 0 && plan != null) {
        rows.add(
          _ScheduleDetailRow(
            icon: CupertinoIcons.calendar,
            color: const Color(0xFFFF920F),
            background: const Color(0xFFFFF4E5),
            title: '새 단어 계획 $planCount개',
            subtitle: _planDetailSubtitle(book, plan, date),
            identity: identity,
          ),
        );
      }
    }

    if (rows.isEmpty) {
      return _CalendarEmptyGroup(
        label: '이 날짜에 예정된 복습이나 학습 계획이 없습니다.',
        identity: identity,
      );
    }

    return _CalendarGroupedSurface(
      identity: identity,
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index != rows.length - 1)
            Divider(height: 1, color: identity.border, indent: 66),
        ],
      ],
    );
  }

  List<_ModeSummary> _modeSummaries(List<StudySessionRecord> sessions) {
    final result = <_ModeSummary>[];
    for (final mode in StudyHistoryMode.values) {
      final matches =
          sessions.where((session) => session.mode == mode).toList();
      if (matches.isEmpty) continue;
      final success = matches.fold<int>(
        0,
        (sum, session) => sum + session.successCount,
      );
      final total = matches.fold<int>(
        0,
        (sum, session) => sum + session.answers.length,
      );
      result.add(
        _ModeSummary(
          mode: mode,
          sessions: matches.length,
          success: success,
          failure: total - success,
        ),
      );
    }
    return result;
  }

  (Color, Color) _modeVisual(StudyHistoryMode mode, MemorizeIdentity identity) {
    switch (mode) {
      case StudyHistoryMode.flashcard:
        return (identity.success, identity.softSuccess);
      case StudyHistoryMode.multipleChoice:
        return (const Color(0xFFE77B12), const Color(0xFFFFF4E8));
      case StudyHistoryMode.spelling:
        return (identity.review, identity.softReview);
    }
  }

  String _modeShortLabel(StudyHistoryMode mode) {
    switch (mode) {
      case StudyHistoryMode.flashcard:
        return '플래시카드';
      case StudyHistoryMode.multipleChoice:
        return '객관식';
      case StudyHistoryMode.spelling:
        return '스펠링';
    }
  }

  String _sheetContextLabel(_CalendarData data) {
    if (_allBooks) return '전체 단어장 · ${data.books.length}개';
    if (data.books.isEmpty) return '선택된 단어장 없음';
    final book = data.books.first;
    return book.plan == null
        ? '${book.book.name} · 전체 단어장'
        : '${book.book.name} · ${book.plan!.progressLabel}';
  }

  String _planDetailSubtitle(
    _CalendarBook book,
    StudyPlan plan,
    DateTime date,
  ) {
    switch (plan.mode) {
      case StudyPlanMode.free:
        return '${plan.currentChunk()}번 묶음 · ${book.book.name}';
      case StudyPlanMode.scheduled:
        return '${plan.currentChunk(now: date)}일차 · ${book.book.name}';
      case StudyPlanMode.reviewFirst:
        return '복습량 반영 · ${book.book.name}';
    }
  }

  void _moveMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      _selected = _month;
    });
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _weekdayLongLabel(int weekday) =>
      const <String>['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'][weekday -
          1];
}

class _CalendarScopeToggle extends StatelessWidget {
  final bool allBooks;
  final MemorizeIdentity identity;
  final ValueChanged<bool> onChanged;

  const _CalendarScopeToggle({
    required this.allBooks,
    required this.identity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 54,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
        border: Border.all(color: identity.border),
      ),
      child: Row(
        children: [
          _ScopeSegment(
            label: '현재',
            selected: !allBooks,
            identity: identity,
            onTap: () => onChanged(false),
          ),
          _ScopeSegment(
            label: '전체',
            selected: allBooks,
            identity: identity,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ScopeSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final MemorizeIdentity identity;
  final VoidCallback onTap;

  const _ScopeSegment({
    required this.label,
    required this.selected,
    required this.identity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? identity.softInfo : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? identity.primaryAction : identity.mutedInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarMarker extends StatelessWidget {
  final Color color;
  final _CalendarMarkerType type;

  const _CalendarMarker._(this.color, this.type);

  factory _CalendarMarker.completed(Color color) =>
      _CalendarMarker._(color, _CalendarMarkerType.completed);
  factory _CalendarMarker.review(Color color) =>
      _CalendarMarker._(color, _CalendarMarkerType.review);
  factory _CalendarMarker.plan(Color color) =>
      _CalendarMarker._(color, _CalendarMarkerType.plan);

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case _CalendarMarkerType.completed:
        return Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        );
      case _CalendarMarkerType.review:
        return Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
          ),
        );
      case _CalendarMarkerType.plan:
        return Container(
          width: 13,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        );
    }
  }
}

enum _CalendarMarkerType { completed, review, plan }

class _CalendarLegendItem extends StatelessWidget {
  final Widget marker;
  final String label;
  final MemorizeIdentity identity;

  const _CalendarLegendItem({
    required this.marker,
    required this.label,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 16, height: 12, child: Center(child: marker)),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: identity.mutedInk,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CalendarGroupedSurface extends StatelessWidget {
  final MemorizeIdentity identity;
  final List<Widget> children;

  const _CalendarGroupedSurface({
    required this.identity,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(children: children),
    );
  }
}

class _CalendarEmptyGroup extends StatelessWidget {
  final String label;
  final MemorizeIdentity identity;

  const _CalendarEmptyGroup({required this.label, required this.identity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: identity.mutedInk,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ScheduleDetailRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String subtitle;
  final MemorizeIdentity identity;

  const _ScheduleDetailRow({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.subtitle,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final MemorizeIdentity identity;

  const _ResultMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 42,
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarLoadError extends StatelessWidget {
  final MemorizeIdentity identity;
  final VoidCallback onRetry;

  const _CalendarLoadError({required this.identity, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          Text(
            '학습 일정을 불러오지 못했습니다.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(CupertinoIcons.refresh),
            label: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
