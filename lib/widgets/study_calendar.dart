import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/learning_route_origin.dart';
import '../providers/wordbook_manager.dart';
import '../services/study_history_service.dart';
import '../services/study_schedule_service.dart';
import '../services/srs_service.dart';
import '../screens/flashcard_screen.dart';
import 'study_mode_icon.dart';

class StudyCalendar extends StatefulWidget {
  final StudyHistoryService? history;
  const StudyCalendar({super.key, this.history});
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
  final Map<String, Set<StudyHistoryMode>> modesByDay = {};
  final Set<String> dueDates = {};
  _CalendarData(this.books, this.sessions, this.versions) {
    for (final session in sessions) {
      modesByDay.putIfAbsent(studyDateKey(session.completedAt!), () => {}).add(session.mode);
    }
    final today = studyDay(DateTime.now());
    for (final book in books) {
      for (final word in book.words) {
        final due = SrsService().reviewDateFor(word);
        if (due != null) dueDates.add(studyDateKey(due.isBefore(today) ? today : due));
      }
    }
  }
  StudyPlan? planOn(_CalendarBook book, DateTime day) => StudyScheduleService().planOnDate(
    dbFileName: book.book.dbFileName, date: day, versions: versions, fallback: book.plan);
  List<StudySessionRecord> sessionsOn(DateTime date) => sessions.where((s) =>
      studyDateKey(s.completedAt!) == studyDateKey(date)).toList()
    ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
}

class _StudyCalendarState extends State<StudyCalendar> with WidgetsBindingObserver {
  DateTime _selected = studyDay(DateTime.now());
  late DateTime _month = DateTime(_selected.year, _selected.month);
  bool _allBooks = false;
  bool _starting = false;
  Future<_CalendarData>? _future;
  String? _loadKey;
  late final _history = widget.history ?? StudyHistoryService.instance;
  final _schedule = StudyScheduleService();
  final _detailsController = ScrollController();

  @override
  void initState() {
    super.initState();
    _history.addListener(_refresh);
    WidgetsBinding.instance.addObserver(this);
  }
  @override
  void dispose() {
    _history.removeListener(_refresh);
    WidgetsBinding.instance.removeObserver(this);
    _detailsController.dispose();
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }
  void _refresh() { if (mounted) setState(() => _future = null); }

  Future<_CalendarData> _load(WordbookManager manager) async {
    await _history.ensureLoaded();
    final books = _allBooks ? List<Wordbook>.from(manager.wordbooks) :
        [if (manager.activeWordbook != null) manager.activeWordbook!];
    final data = <_CalendarBook>[];
    for (final book in books) {
      data.add(_CalendarBook(book, await manager.getAllWordsFrom(book), manager.planFor(book)));
    }
    final names = books.map((b) => b.dbFileName).toSet();
    return _CalendarData(data, _history.completedSessions.where((s) => names.contains(s.dbFileName)).toList(),
      await _history.planVersions());
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WordbookManager>();
    final key = '${manager.statsRevision}-${manager.activeWordbook?.dbFileName}-$_allBooks-${studyDateKey(DateTime.now())}';
    if (_loadKey != key) { _loadKey = key; _future = null; }
    _future ??= _load(manager);
    final theme = Theme.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('학습 달력', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('완료한 학습과 다음 복습을 한눈에', style: theme.textTheme.bodySmall),
      const SizedBox(height: 12),
      SegmentedButton<bool>(segments: const [
        ButtonSegment(value: false, label: Text('현재 단어장')),
        ButtonSegment(value: true, label: Text('전체 단어장')),
      ], selected: {_allBooks}, onSelectionChanged: (value) => setState(() {
        _allBooks = value.first;
        _future = null;
      })),
      const SizedBox(height: 8),
      FutureBuilder<_CalendarData>(future: _future, builder: (context, snapshot) {
        if (snapshot.hasError) return Column(children: [
          const Text('학습 일정을 불러오지 못했습니다.'),
          OutlinedButton.icon(onPressed: _refresh, icon: const Icon(Icons.refresh), label: const Text('다시 시도')),
        ]);
        if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        return _content(snapshot.data!);
      }),
    ]);
  }

  Widget _content(_CalendarData data) {
    final theme = Theme.of(context);
    final today = studyDay(DateTime.now());
    final selectedSessions = data.sessionsOn(_selected);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday % 7;
    final cells = ((days + offset + 6) ~/ 7) * 7;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final groups = data.books.where((book) => selectedSessions.any((s) => s.dbFileName == book.book.dbFileName) ||
        _reviewWords(book, today).isNotEmpty || _planSummary(data, book, today) != null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(tooltip: '이전 달', onPressed: () => _moveMonth(-1), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Text('${_month.year}년 ${_month.month}월', textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
        IconButton(tooltip: '다음 달', onPressed: () => _moveMonth(1), icon: const Icon(Icons.chevron_right)),
        TextButton(onPressed: () => setState(() {
          _selected = today; _month = DateTime(today.year, today.month);
        }), child: const Text('오늘')),
      ]),
      Row(children: [for (final day in ['일', '월', '화', '수', '목', '금', '토'])
        Expanded(child: Center(child: Text(day, style: theme.textTheme.labelSmall)))]),
      const SizedBox(height: 4),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7,
          mainAxisExtent: 46 * scale.clamp(1.0, 1.8).toDouble(), crossAxisSpacing: 3, mainAxisSpacing: 3),
        itemCount: cells, itemBuilder: (context, index) {
          final number = index - offset + 1;
          if (number < 1 || number > days) return const SizedBox.shrink();
          final date = DateTime(_month.year, _month.month, number);
          final modes = data.modesByDay[studyDateKey(date)] ?? const <StudyHistoryMode>{};
          final due = !date.isBefore(today) && data.dueDates.contains(studyDateKey(date));
          final target = data.books.any((b) {
            final plan = data.planOn(b, date);
            return plan != null && _schedule.scheduledKeysOn(b.words, plan, date).isNotEmpty;
          });
          final selected = date == _selected;
          return Semantics(button: true, selected: selected,
            label: '${studyDateKey(date)}${modes.map((m) => ' ${m.label} 완료').join()}${due ? ' 복습 예정' : ''}${target ? ' 플랜 목표' : ''}',
            child: Material(color: selected ? theme.colorScheme.primaryContainer :
                modes.isNotEmpty ? theme.colorScheme.primary.withValues(alpha: .06) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(borderRadius: BorderRadius.circular(8),
                onTap: () => setState(() => _selected = date),
                child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: date == today ? theme.colorScheme.primary : Colors.transparent)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$number', style: TextStyle(fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
                      color: !selected && date.weekday == DateTime.sunday ? theme.colorScheme.error : null)),
                    const SizedBox(height: 3),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final mode in StudyHistoryMode.values)
                        if (modes.contains(mode)) Padding(padding: const EdgeInsets.symmetric(horizontal: 1),
                          child: Icon(Icons.circle, size: 5, color: studyModeColor(mode, theme.brightness))),
                      if (due) const Padding(padding: EdgeInsets.symmetric(horizontal: 1),
                        child: Icon(Icons.circle_outlined, size: 7, color: Color(0xFFD38912))),
                      if (target) Icon(Icons.remove, size: 8, color: theme.colorScheme.onSurfaceVariant),
                    ]),
                  ])),
              ),
            ));
        }),
      const SizedBox(height: 8),
      Wrap(spacing: 12, runSpacing: 6, children: [
        for (final mode in StudyHistoryMode.values)
          _legend(Icons.circle, mode == StudyHistoryMode.flashcard ? '카드' :
              mode == StudyHistoryMode.multipleChoice ? '객관식' : '스펠링', studyModeColor(mode, theme.brightness)),
        _legend(Icons.circle_outlined, 'SRS', const Color(0xFFD38912)),
        _legend(Icons.remove, '플랜', theme.colorScheme.onSurfaceVariant),
      ]),
      const Divider(height: 24),
      Text('${_selected.month}월 ${_selected.day}일${_selected == today ? ' · 오늘' : ''}',
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(selectedSessions.isEmpty ? '완료한 학습 없음' : '완료한 학습 ${selectedSessions.length}회 · '
          '${{for (final s in selectedSessions) for (final a in s.answers) '${s.dbFileName}:${a.wordKey}'}.length}단어',
        style: theme.textTheme.bodySmall),
      if (_history.lastError != null) OutlinedButton.icon(onPressed: _history.retrySaving,
        icon: const Icon(Icons.refresh), label: const Text('학습 기록 저장 다시 시도')),
      if (context.watch<WordbookManager>().srsSaveError != null) OutlinedButton.icon(
        onPressed: context.read<WordbookManager>().retrySrsSaving,
        icon: const Icon(Icons.refresh), label: const Text('복습 일정 저장 다시 시도')),
      const SizedBox(height: 10),
      if (groups.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 18),
        child: Text('이 날짜의 학습·복습 일정이 없습니다.'))
      else if (_allBooks) ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 420),
        child: Scrollbar(controller: _detailsController, thumbVisibility: true,
          child: ListView.builder(controller: _detailsController, shrinkWrap: true, primary: false,
            itemCount: groups.length, itemBuilder: (_, index) => _bookGroup(data, groups[index], today, selectedSessions))),
      ) else _bookGroup(data, groups.first, today, selectedSessions),
      const SizedBox(height: 12),
      Text('완료일 기준 기록 · SRS 일정은 학습 결과에 따라 바뀝니다.',
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
    ]);
  }

  Widget _legend(IconData icon, String label, Color color) => Row(mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 10, color: color), const SizedBox(width: 4), Text(label, style: Theme.of(context).textTheme.labelSmall)]);
  void _moveMonth(int offset) => setState(() {
    _month = DateTime(_month.year, _month.month + offset); _selected = _month;
  });

  List<Word> _reviewWords(_CalendarBook book, DateTime today) => _selected.isBefore(today) ? [] : [
    if (_selected == today) ..._schedule.overdue(book.words, today),
    ..._schedule.dueOn(book.words, _selected),
  ];

  Widget _bookGroup(_CalendarData data, _CalendarBook book, DateTime today, List<StudySessionRecord> sessions) {
    final matches = sessions.where((s) => s.dbFileName == book.book.dbFileName).toList();
    final review = _reviewWords(book, today);
    final plan = _planSummary(data, book, today);
    final children = <Widget>[
      for (final session in matches) _sessionTile(session),
      if (review.isNotEmpty) ListTile(contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.event_repeat, color: Color(0xFFD38912)),
        title: Text('SRS 복습 ${review.length}개'),
        subtitle: Text(_selected == today ? '지난 묶음에서 남은 복습 포함' : '현재 예정된 복습')),
      if (review.isNotEmpty && _selected == today) OutlinedButton.icon(
        onPressed: _starting ? null : () => _startReview(book, review),
        icon: const Icon(Icons.play_arrow), label: const Text('카드로 복습 시작')),
      if (plan != null) ListTile(contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.flag_outlined), title: Text(plan)),
    ];
    if (!_allBooks) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(book.book.name, style: const TextStyle(fontWeight: FontWeight.w700)), ...children,
    ]);
    return ExpansionTile(
      key: PageStorageKey('${studyDateKey(_selected)}-${book.book.dbFileName}'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 16, 12),
      title: Text(book.book.name, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([if (matches.isNotEmpty) '학습 ${matches.length}회',
        if (review.isNotEmpty) 'SRS ${review.length}개', if (plan != null) '플랜 있음'].join(' · ')),
      children: children,
    );
  }

  Widget _sessionTile(StudySessionRecord session) {
    final at = session.completedAt!;
    final theme = Theme.of(context);
    final color = studyModeColor(session.mode, theme.brightness);
    final time = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final success = session.successCount;
    final total = session.answers.length;
    final isCard = session.mode == StudyHistoryMode.flashcard;
    return ListTile(contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: .10),
        child: Icon(studyModeIcon(session.mode), color: color, size: 20)),
      title: Text('${session.mode.label}${session.bundle == null ? '' : ' · ${session.bundle}번 묶음'}'),
      subtitle: Text('$time · ${isCard ? '알아요' : '정답'} $success · ${isCard ? '몰라요' : '틀림/스킵'} ${total - success}'),
    );
  }

  Future<void> _startReview(_CalendarBook book, List<Word> words) async {
    setState(() => _starting = true);
    try {
      await context.read<WordbookManager>().setActiveWordbook(book.book);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FlashcardScreen(
        initialMode: FlashcardLaunchMode.review, origin: LearningRouteOrigin.review,
        reviewWordsOverride: words)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('복습을 시작하지 못했습니다. 다시 시도해주세요.')));
    } finally {
      if (mounted) setState(() { _starting = false; _future = null; });
    }
  }

  String? _planSummary(_CalendarData data, _CalendarBook book, DateTime today) {
    final plan = data.planOn(book, _selected);
    if (plan == null || plan.status != StudyPlanStatus.active) return null;
    if (plan.mode == StudyPlanMode.scheduled) {
      final keys = _schedule.scheduledKeysOn(book.words, plan, _selected);
      if (keys.isEmpty) return null;
      final recorded = <String>{for (final s in data.sessions.where((s) =>
          s.dbFileName == book.book.dbFileName && !studyDay(s.completedAt!).isAfter(_selected)))
        for (final a in s.answers) a.wordKey};
      return '새 단어 목표 ${keys.length}개 · 학습 ${keys.intersection(recorded).length}개';
    }
    if (_selected != today) return null;
    final current = book.plan ?? plan;
    return current.mode == StudyPlanMode.free ? '${current.currentChunk()}번 묶음 · 자유롭게 학습' :
        '복습 우선 · 새 단어 하루 최대 ${current.dailyNewTarget}개';
  }
}
