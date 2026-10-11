import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/study_plan_model.dart';
import '../services/database_service.dart';
import '../services/analytics_service.dart';
import '../services/local_word_file_service.dart';
import '../services/srs_service.dart';
import '../services/study_schedule_service.dart';
import '../services/study_history_service.dart';
import '../services/quiz_review_service.dart';
import '../services/word_data_parser.dart';
import 'word_list_provider.dart';

class WordbookManager extends ChangeNotifier {
  static const String _studyActivityDatesKey = 'study_activity_dates';
  static const String _lastActiveWordbookIdKey = 'last_active_wordbook_id';
  static const String _lastActiveWordbookDbFileNameKey =
      'last_active_wordbook_db_file_name';
  static const String _lastActiveWordbookNameKey = 'last_active_wordbook_name';
  static const int _builtinContentRevision = 2;
  static const List<BuiltinWordbookTemplate> _builtinTemplates = [
    BuiltinWordbookTemplate(
      name: '필수 영어단어 1단계',
      dbFileName: 'builtin_essential_english_stage_1_v1.db',
      sourceAsset: 'assets/builtin_essential_english_stage_1.csv',
      offset: 0,
      count: 1000,
      targetCount: 1000,
      levelLabel: '1단계',
      description: '빈도 순위 1~1,000위 필수 단어',
    ),
    BuiltinWordbookTemplate(
      name: '필수 영어단어 2단계',
      dbFileName: 'builtin_essential_english_stage_2_v1.db',
      sourceAsset: 'assets/builtin_essential_english_stage_2.csv',
      offset: 0,
      count: 1000,
      targetCount: 1000,
      levelLabel: '2단계',
      description: '빈도 순위 1,001~2,000위 필수 단어',
    ),
    BuiltinWordbookTemplate(
      name: '필수 영어단어 3단계',
      dbFileName: 'builtin_essential_english_stage_3_v1.db',
      sourceAsset: 'assets/builtin_essential_english_stage_3.csv',
      offset: 0,
      count: 1000,
      targetCount: 1000,
      levelLabel: '3단계',
      description: '빈도 순위 2,001~3,000위 필수 단어',
    ),
    BuiltinWordbookTemplate(
      name: '필수 영어단어 4단계',
      dbFileName: 'builtin_essential_english_stage_4_v1.db',
      sourceAsset: 'assets/builtin_essential_english_stage_4.csv',
      offset: 0,
      count: 1000,
      targetCount: 1000,
      levelLabel: '4단계',
      description: '빈도 순위 3,001~4,000위 필수 단어',
    ),
    BuiltinWordbookTemplate(
      name: '필수 영어단어 5단계',
      dbFileName: 'builtin_essential_english_stage_5_v1.db',
      sourceAsset: 'assets/builtin_essential_english_stage_5.csv',
      offset: 0,
      count: 1000,
      targetCount: 1000,
      levelLabel: '5단계',
      description: '빈도 순위 4,001~5,000위 필수 단어',
    ),
    BuiltinWordbookTemplate(
      name: '필수 영어단어 6단계',
      dbFileName: 'builtin_essential_english_stage_6_v1.db',
      sourceAsset: 'assets/builtin_essential_english_stage_6.csv',
      offset: 0,
      count: 1000,
      targetCount: 1000,
      levelLabel: '6단계',
      description: '빈도 순위 5,001~6,000위 필수 단어',
    ),
  ];

  final DatabaseService _dbService;
  final WordListNotifier _wordListNotifier;
  final SrsService _srsService = SrsService();

  List<Wordbook> _wordbooks = [];
  List<Wordbook> get wordbooks => _wordbooks;
  List<BuiltinWordbookTemplate> get builtinWordbookTemplates =>
      List.unmodifiable(_builtinTemplates);
  List<StudyPlan> _studyPlans = [];
  List<StudyPlan> get studyPlans => List.unmodifiable(_studyPlans);

  Wordbook? _activeWordbook;
  Wordbook? get activeWordbook => _activeWordbook;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isActiveWordbookLoading = false;
  bool get isActiveWordbookLoading => _isActiveWordbookLoading;
  Object? _activeWordbookLoadError;
  Object? get activeWordbookLoadError => _activeWordbookLoadError;
  Future<void>? _metadataInitializationFuture;
  Future<void>? _activeWordbookInitializationFuture;
  int _statsRevision = 0;
  int get statsRevision => _statsRevision;
  Future<void> _srsWrites = Future<void>.value();
  final Map<String, Map<String, Word>> _unsavedSrs = {};
  Object? srsSaveError;
  Future<void> get pendingSrsWrites => _srsWrites;
  final Set<String> _studyActivityDates = {};
  Set<String> get studyActivityDates => Set.unmodifiable(_studyActivityDates);
  int get studyDayStreak => _calculateStudyDayStreak();

  WordbookManager(this._dbService, this._wordListNotifier) {
    StudyHistoryService.instance.addListener(_onHistoryChanged);
  }

  void _onHistoryChanged() {
    _statsRevision++;
    notifyListeners();
  }

  @override
  void dispose() {
    StudyHistoryService.instance.removeListener(_onHistoryChanged);
    super.dispose();
  }

  Future<void> loadInitialData() async {
    await loadInitialMetadata();
    await loadActiveWordbookWords();
  }

  Future<void> loadInitialMetadata() {
    return _metadataInitializationFuture ??= _loadInitialMetadata().catchError((
      error,
    ) {
      _metadataInitializationFuture = null;
      throw error;
    });
  }

  Future<void> _loadInitialMetadata() async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      _studyActivityDates
        ..clear()
        ..addAll(prefs.getStringList(_studyActivityDatesKey) ?? const []);
      final lastActiveId = prefs.getInt(_lastActiveWordbookIdKey);
      final lastActiveDbFileName = prefs.getString(
        _lastActiveWordbookDbFileNameKey,
      );

      await _loadWordbooks(shouldNotify: false);
      await _synchronizeInstalledBuiltinContent(prefs);
      await _loadStudyPlans(shouldNotify: false);
      await StudyHistoryService.instance.ensureLoaded();

      _activeWordbook =
          _findRestoredWordbook(lastActiveId, lastActiveDbFileName) ??
          (_wordbooks.isNotEmpty ? _wordbooks.first : null);
      _statsRevision++;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadActiveWordbookWords() {
    return _activeWordbookInitializationFuture ??= _loadActiveWordbookWords()
        .catchError((error) {
          _activeWordbookInitializationFuture = null;
          throw error;
        });
  }

  Future<void> retryActiveWordbookWords() {
    _activeWordbookInitializationFuture = null;
    return loadActiveWordbookWords();
  }

  Future<void> _loadActiveWordbookWords() async {
    await loadInitialMetadata();
    _activeWordbookLoadError = null;
    _isActiveWordbookLoading = true;
    notifyListeners();
    try {
      final wordbook = _activeWordbook;
      if (wordbook == null) {
        _wordListNotifier.clearWords();
      } else {
        await _wordListNotifier.loadWords(wordbook.dbFileName);
      }
    } catch (error) {
      _activeWordbookLoadError = error;
      rethrow;
    } finally {
      _isActiveWordbookLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadWordbooks({bool shouldNotify = true}) async {
    _wordbooks = await _dbService.getWordbooks();
    _statsRevision++;
    // loadInitialData에서 setActiveWordbook을 관리하므로 여기서는 호출하지 않습니다.
    if (shouldNotify) notifyListeners();
  }

  bool isBuiltinWordbookAdded(BuiltinWordbookTemplate template) {
    return getWordbookByDbFileName(template.dbFileName) != null;
  }

  Future<Wordbook> addBuiltinWordbook(BuiltinWordbookTemplate template) async {
    final existing = getWordbookByDbFileName(template.dbFileName);
    if (existing != null) {
      await setActiveWordbook(existing);
      return existing;
    }

    _setLoading(true);
    try {
      final words = await _loadBuiltinWords(template);
      if (words.isEmpty) {
        throw StateError('${template.name}에서 가져올 단어를 찾을 수 없습니다.');
      }
      final wordbook = Wordbook(
        name: template.name,
        dbFileName: template.dbFileName,
        source: WordbookSource.builtin,
      );
      final savedWordbook = await _dbService.addWordbook(wordbook);
      await _dbService.addWordsInBatch(savedWordbook.dbFileName, words);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _builtinContentRevisionKey(template),
        _builtinContentRevision,
      );
      await _loadWordbooks(shouldNotify: false);
      final loadedWordbook =
          getWordbookByDbFileName(savedWordbook.dbFileName) ?? savedWordbook;
      await setActiveWordbook(loadedWordbook);
      return loadedWordbook;
    } finally {
      _setLoading(false);
    }
  }

  Future<Wordbook> createManualWordbook(String name) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty || trimmedName.length > 80) {
      throw ArgumentError('단어장 이름은 1~80자로 입력해주세요.');
    }
    if (_wordbooks.any(
      (book) => book.name.toLowerCase() == trimmedName.toLowerCase(),
    )) {
      throw StateError('같은 이름의 단어장이 이미 있습니다.');
    }

    _setLoading(true);
    try {
      final wordbook = Wordbook(
        name: trimmedName,
        dbFileName:
            'wordbook_manual_${DateTime.now().microsecondsSinceEpoch}.db',
        source: WordbookSource.manual,
      );
      await _dbService.ensureWordbookDatabase(wordbook.dbFileName);
      final saved = await _dbService.addWordbook(wordbook);
      await _loadWordbooks(shouldNotify: false);
      await setActiveWordbook(saved);
      notifyListeners();
      return saved;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Word>> _loadBuiltinWords(BuiltinWordbookTemplate seed) async {
    final csvString = await rootBundle.loadString(seed.sourceAsset);
    return WordDataParser.parseCsv(
      csvString,
      offset: seed.offset,
      count: seed.count,
    );
  }

  String _builtinContentRevisionKey(BuiltinWordbookTemplate template) {
    return 'builtin_content_revision_${template.dbFileName}';
  }

  Future<void> _synchronizeInstalledBuiltinContent(
    SharedPreferences prefs,
  ) async {
    for (final template in _builtinTemplates) {
      final installed = getWordbookByDbFileName(template.dbFileName);
      if (installed == null ||
          (prefs.getInt(_builtinContentRevisionKey(template)) ?? 0) >=
              _builtinContentRevision) {
        continue;
      }

      final currentWords = await _dbService.getAllWords(template.dbFileName);
      final seedWords = await _loadBuiltinWords(template);
      if (currentWords.length != seedWords.length ||
          seedWords.length != template.targetCount) {
        continue;
      }

      currentWords.sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      final changedWords = <Word>[];
      for (var index = 0; index < seedWords.length; index++) {
        final current = currentWords[index];
        final seed = seedWords[index];
        if (current.word == seed.word && current.meaning == seed.meaning) {
          continue;
        }
        changedWords.add(
          current.copyWith(word: seed.word, meaning: seed.meaning),
        );
      }

      if (changedWords.isNotEmpty) {
        await _dbService.updateWordSrsBatch(template.dbFileName, changedWords);
      }
      await prefs.setInt(
        _builtinContentRevisionKey(template),
        _builtinContentRevision,
      );
    }
  }

  Future<void> _loadStudyPlans({bool shouldNotify = true}) async {
    final wordbookDbNames =
        _wordbooks.map((wordbook) => wordbook.dbFileName).toSet();
    _studyPlans =
        (await _dbService.getStudyPlans())
            .where((plan) => wordbookDbNames.contains(plan.dbFileName))
            .toList();
    _statsRevision++;
    if (shouldNotify) notifyListeners();
  }

  Wordbook? getWordbookById(int id) {
    try {
      return _wordbooks.firstWhere((wb) => wb.id == id);
    } catch (e) {
      return null;
    }
  }

  Wordbook? getWordbookByDbFileName(String dbFileName) {
    try {
      return _wordbooks.firstWhere((wb) => wb.dbFileName == dbFileName);
    } catch (e) {
      return null;
    }
  }

  Wordbook? _findRestoredWordbook(int? id, String? dbFileName) {
    if (id != null) {
      final byId = getWordbookById(id);
      if (byId != null) return byId;
    }

    if (dbFileName != null && dbFileName.isNotEmpty) {
      return getWordbookByDbFileName(dbFileName);
    }

    return null;
  }

  Future<void> setActiveWordbook(Wordbook? wordbook) async {
    final wasSame =
        wordbook != null &&
        _activeWordbook != null &&
        (_activeWordbook!.id == wordbook.id ||
            _activeWordbook!.dbFileName == wordbook.dbFileName) &&
        _activeWordbook!.name == wordbook.name &&
        _activeWordbook!.spreadsheetId == wordbook.spreadsheetId &&
        _activeWordbook!.sheetName == wordbook.sheetName &&
        _activeWordbook!.source == wordbook.source;

    _activeWordbook = wordbook;
    if (wordbook != null) {
      final isManual = wordbook.source == WordbookSource.manual;
      if (isManual) {
        await _dbService.ensureWordbookDatabase(wordbook.dbFileName);
      }
      await _wordListNotifier.loadWords(wordbook.dbFileName, force: isManual);
    } else {
      _wordListNotifier.clearWords();
    }

    // 활성화된 단어장 ID를 기기에 저장합니다.
    final prefs = await SharedPreferences.getInstance();
    if (wordbook != null) {
      if (wordbook.id != null) {
        await prefs.setInt(_lastActiveWordbookIdKey, wordbook.id!);
      } else {
        await prefs.remove(_lastActiveWordbookIdKey);
      }
      await prefs.setString(
        _lastActiveWordbookDbFileNameKey,
        wordbook.dbFileName,
      );
      await prefs.setString(_lastActiveWordbookNameKey, wordbook.name);
    } else {
      await prefs.remove(_lastActiveWordbookIdKey);
      await prefs.remove(_lastActiveWordbookDbFileNameKey);
      await prefs.remove(_lastActiveWordbookNameKey);
    }

    if (!wasSame) {
      _statsRevision++;
      notifyListeners();
    }
  }

  List<Word> getWordsForReview() {
    if (_activeWordbook == null) return [];
    return _srsService.dueWords(
      wordsAvailableForPlan(_wordListNotifier.words, plan: activeStudyPlan),
    );
  }

  List<Word> getPendingMcqReviewWords() {
    return quizReviewEntries()
        .where((e) => e.pendingModes.contains(StudyHistoryMode.multipleChoice))
        .map((e) => e.word)
        .toList();
  }

  List<Word> getPendingSpellingReviewWords() {
    return quizReviewEntries()
        .where((e) => e.pendingModes.contains(StudyHistoryMode.spelling))
        .map((e) => e.word)
        .toList();
  }

  List<QuizReviewEntry> quizReviewEntries({bool cumulative = false}) {
    if (_activeWordbook == null) return [];
    return const QuizReviewService().entries(
      dbFileName: _activeWordbook!.dbFileName,
      words: _wordListNotifier.words,
      sessions: StudyHistoryService.instance.sessions,
      cumulative: cumulative,
    );
  }

  StudyPlan? planFor(Wordbook? wordbook) {
    if (wordbook == null) return null;
    for (final plan in _studyPlans) {
      if (plan.dbFileName == wordbook.dbFileName) return plan;
    }
    return null;
  }

  StudyPlan? planForSession(Wordbook wordbook, List<Word> words) {
    final plan = planFor(wordbook);
    if (plan == null || plan.status != StudyPlanStatus.active || words.isEmpty) {
      return null;
    }
    if (plan.mode == StudyPlanMode.free) {
      final keys = StudyScheduleService().bundleKeys(
        _wordListNotifier.words,
        plan,
      );
      if (words.any(
        (word) => !keys.contains(StudyScheduleService.wordKey(word)),
      )) {
        return null;
      }
    }
    return plan;
  }

  StudyPlan? get activeStudyPlan => planFor(_activeWordbook);

  List<Word> wordsAvailableForPlan(
    List<Word> words, {
    required StudyPlan? plan,
  }) {
    final activePlan = plan;
    return StudyScheduleService().availableWords(
      words,
      activePlan,
      introducedToday:
          activePlan == null
              ? 0
              : StudyHistoryService.instance
                  .introducedKeys(activePlan.dbFileName, DateTime.now())
                  .length,
    );
  }

  int lockedNewWordCount(List<Word> words, {required StudyPlan? plan}) {
    final available =
        wordsAvailableForPlan(
          words,
          plan: plan,
        ).map(StudyScheduleService.wordKey).toSet();
    return words
        .where(
          (w) =>
              _srsService.isNewWord(w) &&
              !available.contains(StudyScheduleService.wordKey(w)),
        )
        .length;
  }

  int plannedNewWordSessionCount(List<Word> words, {required StudyPlan? plan}) {
    final activePlan = plan;
    final available = wordsAvailableForPlan(words, plan: activePlan);
    final newCount = available.where(_srsService.isNewWord).length;
    if (activePlan == null ||
        activePlan.status != StudyPlanStatus.active ||
        activePlan.mode == StudyPlanMode.free) {
      return newCount;
    }
    return min(activePlan.dailyNewTarget, newCount);
  }

  int recommendedNewWordSessionCount(
    List<Word> words, {
    required StudyPlan? plan,
  }) => plannedNewWordSessionCount(words, plan: plan);

  Future<StudyPlan?> createStudyPlanForWordbook(
    Wordbook wordbook, {
    required int chunkSize,
    required int dailyNewTarget,
    StudyPlanMode mode = StudyPlanMode.free,
    int? bundleCount,
    bool resetSchedule = false,
  }) async {
    final words = await getAllWordsFrom(wordbook);
    if (words.isEmpty) return null;
    final now = DateTime.now();
    final existing = planFor(wordbook);
    final keys =
        _orderedPlanWords(words).map(StudyScheduleService.wordKey).toList();
    final oldOrder = existing?.wordOrder ?? const <String>[];
    final oldKeys = oldOrder.toSet();
    final order = [...oldOrder, ...keys.where((key) => !oldKeys.contains(key))];
    final restart = existing == null || existing.mode != mode || resetSchedule;
    final revision = max(
      (existing?.revision ?? 0) + 1,
      await _dbService.nextStudyPlanRevision(wordbook.dbFileName),
    );
    final groups =
        (bundleCount ?? existing?.chunkCount ?? 10)
            .clamp(1, order.length)
            .toInt();
    final plan = StudyPlan(
      id: existing?.id,
      wordbookId: wordbook.id,
      dbFileName: wordbook.dbFileName,
      wordbookName: wordbook.name,
      totalWords: order.length,
      chunkSize: max(1, chunkSize),
      dailyNewTarget: max(1, dailyNewTarget),
      startDate: restart ? studyDateKey(now) : existing.startDate,
      createdAt: existing?.createdAt ?? now.toIso8601String(),
      mode: mode,
      bundleCount: groups,
      selectedBundle: (existing?.selectedBundle ?? 1).clamp(1, groups).toInt(),
      revision: revision,
      wordOrder: order,
      scheduleWordKeys:
          restart
              ? _orderedPlanWords(words)
                  .where(_srsService.isNewWord)
                  .map(StudyScheduleService.wordKey)
                  .toList()
              : existing.scheduleWordKeys,
    );
    final saved = await _dbService.saveStudyPlan(plan);
    _studyPlans.removeWhere((p) => p.dbFileName == wordbook.dbFileName);
    _studyPlans.insert(0, saved);
    _statsRevision++;
    notifyListeners();
    return saved;
  }

  Future<void> selectPlanBundle(StudyPlan plan, int bundle) async {
    final current =
        _studyPlans.where((p) => p.dbFileName == plan.dbFileName).firstOrNull;
    if (current == null || current.mode != StudyPlanMode.free) return;
    final saved = await _dbService.saveStudyPlan(
      current.copyWith(
        selectedBundle: bundle.clamp(1, current.chunkCount).toInt(),
      ),
    );
    _studyPlans[_studyPlans.indexOf(current)] = saved;
    _statsRevision++;
    notifyListeners();
  }

  Future<void> deleteStudyPlan(StudyPlan plan) async {
    if (plan.id == null) return;
    await _dbService.deleteStudyPlan(plan.id!);
    _studyPlans.removeWhere((item) => item.id == plan.id);
    _statsRevision++;
    notifyListeners();
  }

  Future<void> updateWordsSrsData(String dbFileName, List<Word> words) async {
    await _dbService.updateWordSrsBatch(dbFileName, words);
    await _recordStudyActivityIfNeeded(words);
    _statsRevision++;
    if (_activeWordbook?.dbFileName == dbFileName) {
      await _wordListNotifier.refreshWords();
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  Future<void> queueWordsSrsData(String dbFileName, List<Word> words) {
    final snapshot = List<Word>.from(words);
    final pending = _unsavedSrs.putIfAbsent(dbFileName, () => {});
    for (final word in snapshot) {
      pending[StudyScheduleService.wordKey(word)] = word;
    }
    _srsWrites = _srsWrites.then((_) async {
      try {
        await updateWordsSrsData(dbFileName, snapshot);
        for (final word in snapshot) {
          final key = StudyScheduleService.wordKey(word);
          if (identical(pending[key], word)) pending.remove(key);
        }
        if (_unsavedSrs.values.every((words) => words.isEmpty)) {
          srsSaveError = null;
        }
      } catch (error) {
        srsSaveError = error;
      }
      notifyListeners();
    });
    return _srsWrites;
  }

  Future<void> retrySrsSaving() async {
    await _srsWrites;
    for (final entry in _unsavedSrs.entries.toList()) {
      if (entry.value.isNotEmpty) {
        await queueWordsSrsData(entry.key, entry.value.values.toList());
      }
    }
  }

  List<Word> latestStudyWords(String dbFileName, List<Word> words) {
    final latest = <String, Word>{
      if (_wordListNotifier.activeDbFileName == dbFileName)
        for (final word in _wordListNotifier.words)
          StudyScheduleService.wordKey(word): word,
      ...?_unsavedSrs[dbFileName],
    };
    return words
        .map((word) => latest[StudyScheduleService.wordKey(word)] ?? word)
        .toList();
  }

  Future<List<Word>> getAllWordsFrom(Wordbook wordbook) async {
    return await _dbService.getAllWords(wordbook.dbFileName);
  }

  Future<void> _recordStudyActivityIfNeeded(List<Word> words) async {
    if (words.isEmpty) return;
    final todayKey = _dateKey(DateTime.now());
    if (_studyActivityDates.contains(todayKey)) return;

    _studyActivityDates.add(todayKey);
    final sortedDates = _studyActivityDates.toList()..sort();
    final trimmedDates =
        sortedDates.length > 370
            ? sortedDates.sublist(sortedDates.length - 370)
            : sortedDates;
    _studyActivityDates
      ..clear()
      ..addAll(trimmedDates);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_studyActivityDatesKey, trimmedDates);
  }

  int _calculateStudyDayStreak() {
    if (_studyActivityDates.isEmpty) return 0;

    var cursor = DateTime.now();
    if (!_studyActivityDates.contains(_dateKey(cursor))) {
      final yesterday = cursor.subtract(const Duration(days: 1));
      if (!_studyActivityDates.contains(_dateKey(yesterday))) return 0;
      cursor = yesterday;
    }

    var streak = 0;
    while (_studyActivityDates.contains(_dateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  String _dateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  List<Word> _orderedPlanWords(List<Word> words) {
    return List<Word>.from(words)
      ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
  }

  Future<void> updateWordsInWordbook(
    Wordbook wordbook,
    List<Word> words,
  ) async {
    await _dbService.updateWordSrsBatch(wordbook.dbFileName, words);
    _statsRevision++;
    if (_activeWordbook?.id == wordbook.id) {
      await _wordListNotifier.refreshWords();
    }
    notifyListeners();
  }

  Future<void> addWordToWordbook(Wordbook wordbook, Word word) async {
    await _dbService.addWord(wordbook.dbFileName, word);
    _statsRevision++;
    if (_activeWordbook?.id == wordbook.id) {
      await _wordListNotifier.refreshWords();
    }
    notifyListeners();
  }

  Future<void> deleteWordFrom(Wordbook wordbook, int wordId) async {
    await _dbService.deleteWord(wordbook.dbFileName, wordId);
    _statsRevision++;
    if (_activeWordbook?.id == wordbook.id) {
      await _wordListNotifier.refreshWords();
    }
    notifyListeners();
  }

  Future<Map<Wordbook, List<Word>>> searchAllWordbooks(String query) async {
    if (query.trim().isEmpty) return {};
    _setLoading(true);
    final Map<Wordbook, List<Word>> searchResults = {};
    for (final wordbook in _wordbooks) {
      final foundWords = await _dbService.searchWordsInWordbook(
        wordbook.dbFileName,
        query,
      );
      if (foundWords.isNotEmpty) {
        searchResults[wordbook] = foundWords;
      }
    }
    _setLoading(false);
    return searchResults;
  }

  Future<void> createNewWordbookFromCsv(BuildContext context) async {
    _setLoading(true);
    try {
      final imported = await const LocalWordFileService().pickAndPreview(
        context,
      );
      if (imported == null) return;
      final words = imported.words;

      if (words.isEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('파일에서 유효한 단어와 뜻을 찾을 수 없습니다.')),
        );
        return;
      }
      if (!context.mounted) {
        _setLoading(false);
        return;
      }
      final theme = Theme.of(context);
      var draftName = imported.fileName;
      void popDialogAfterUnfocus<T>(BuildContext dialogContext, [T? result]) {
        FocusScope.of(dialogContext).unfocus();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!dialogContext.mounted) return;
          Navigator.of(dialogContext).pop<T>(result);
        });
      }

      final String? newName = await showDialog<String>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('단어장 이름 지정'),
              content: TextFormField(
                initialValue: draftName,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '단어장 이름',
                  hintText: '단어장 이름을 입력하세요',
                ),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                onChanged: (value) => draftName = value,
                onFieldSubmitted: (value) {
                  popDialogAfterUnfocus<String>(dialogContext, value.trim());
                },
              ),
              actions: [
                TextButton(
                  child: const Text('취소'),
                  onPressed: () => popDialogAfterUnfocus<String>(dialogContext),
                ),
                FilledButton(
                  child: const Text('생성'),
                  onPressed:
                      () => popDialogAfterUnfocus<String>(
                        dialogContext,
                        draftName.trim(),
                      ),
                ),
              ],
            ),
      );
      if (newName == null || newName.isEmpty) {
        _setLoading(false);
        return;
      }
      final dbFileName = 'wordbook_${DateTime.now().millisecondsSinceEpoch}.db';
      final newWordbook = Wordbook(
        name: newName,
        dbFileName: dbFileName,
        source: WordbookSource.localCsv,
      );
      final savedWordbook = await _dbService.addWordbook(newWordbook);
      await _dbService.addWordsInBatch(savedWordbook.dbFileName, words);
      await _loadWordbooks();
      await setActiveWordbook(savedWordbook);
      if (context.mounted) {
        context.read<AnalyticsService>().logWordbookImported(
          source: imported.fileType,
          wordbookCount: 1,
        );
      }
    } catch (e) {
      debugPrint("Error creating wordbook from local file: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('파일 처리 중 오류 발생: $e')));
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteWordbook(Wordbook wordbook) async {
    _setLoading(true);
    await _srsWrites;
    _unsavedSrs.remove(wordbook.dbFileName);
    if (_activeWordbook?.id == wordbook.id) {
      await setActiveWordbook(null);
    }
    await StudyHistoryService.instance.forgetWordbook(wordbook.dbFileName);
    await _dbService.deleteWordbook(wordbook.id!, wordbook.dbFileName);
    _studyPlans.removeWhere((plan) => plan.dbFileName == wordbook.dbFileName);
    await _loadWordbooks();
    _setLoading(false);
  }

  Future<MergeWordbooksResult> mergeWordbooks(
    Set<int> wordbookIds,
    String newName,
  ) async {
    _setLoading(true);
    try {
      final List<Word> mergedWords = [];
      final Set<String> uniqueWordTexts = {};
      final List<Wordbook> booksToMerge =
          _wordbooks.where((wb) => wordbookIds.contains(wb.id)).toList();

      if (booksToMerge.length < 2) {
        throw StateError('병합할 단어장이 2개 이상 필요합니다.');
      }

      var totalWordCount = 0;
      for (final book in booksToMerge) {
        final wordsFromDb = await _dbService.getAllWords(book.dbFileName);
        totalWordCount += wordsFromDb.length;
        for (var word in wordsFromDb) {
          if (uniqueWordTexts.add(word.word.trim().toLowerCase())) {
            mergedWords.add(word);
          }
        }
      }
      final dbFileName = 'wordbook_${DateTime.now().millisecondsSinceEpoch}.db';
      final newWordbook = Wordbook(
        name: newName,
        dbFileName: dbFileName,
        source: WordbookSource.localCsv,
      );
      final savedWordbook = await _dbService.addWordbook(newWordbook);
      await _dbService.addWordsInBatch(savedWordbook.dbFileName, mergedWords);
      await _loadWordbooks();
      await setActiveWordbook(savedWordbook);
      return MergeWordbooksResult(
        createdWordbook: savedWordbook,
        sourceWordbooks: List.unmodifiable(booksToMerge),
        mergedWordCount: mergedWords.length,
        duplicateSkippedCount: totalWordCount - mergedWords.length,
      );
    } catch (e) {
      debugPrint("Error merging wordbooks: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Wordbook>> createMultipleWordbooksFromSheets(
    Map<sheets.Sheet, List<Word>> preparedSheets,
    String spreadsheetId,
  ) async {
    _setLoading(true);
    final importedWordbooks = <Wordbook>[];
    try {
      for (final entry in preparedSheets.entries) {
        final sheet = entry.key;
        final sheetName = sheet.properties?.title;
        if (sheetName == null || sheetName.isEmpty) continue;

        final words = entry.value;
        if (words.isEmpty) continue;

        final dbFileName =
            'wordbook_${DateTime.now().millisecondsSinceEpoch}_${sheet.properties?.sheetId}.db';
        final newWordbook = Wordbook(
          name: sheetName,
          spreadsheetId: spreadsheetId,
          sheetName: sheetName,
          dbFileName: dbFileName,
          source: WordbookSource.googleSheet,
        );
        final savedWordbook = await _dbService.addWordbook(newWordbook);
        await _dbService.addWordsInBatch(savedWordbook.dbFileName, words);
        importedWordbooks.add(savedWordbook);
      }
      await _loadWordbooks();
      if (importedWordbooks.isNotEmpty) {
        await setActiveWordbook(importedWordbooks.first);
      }
      return importedWordbooks;
    } catch (e) {
      debugPrint("Error creating multiple wordbooks from sheets: $e");
      return importedWordbooks;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      Future.microtask(() => notifyListeners());
    }
  }
}

class MergeWordbooksResult {
  final Wordbook createdWordbook;
  final List<Wordbook> sourceWordbooks;
  final int mergedWordCount;
  final int duplicateSkippedCount;

  const MergeWordbooksResult({
    required this.createdWordbook,
    required this.sourceWordbooks,
    required this.mergedWordCount,
    required this.duplicateSkippedCount,
  });
}

class BuiltinWordbookTemplate {
  final String name;
  final String dbFileName;
  final String sourceAsset;
  final int offset;
  final int count;
  final int targetCount;
  final String levelLabel;
  final String description;

  const BuiltinWordbookTemplate({
    required this.name,
    required this.dbFileName,
    required this.sourceAsset,
    required this.offset,
    required this.count,
    required this.targetCount,
    required this.levelLabel,
    required this.description,
  });
}
