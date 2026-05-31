import 'dart:io';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/study_plan_model.dart';
import '../services/database_service.dart';
import '../services/sheets_service.dart';
import '../services/srs_service.dart';
import 'word_list_provider.dart';

class WordbookManager extends ChangeNotifier {
  static const String _studyActivityDatesKey = 'study_activity_dates';
  static const String _lastActiveWordbookIdKey = 'last_active_wordbook_id';
  static const String _lastActiveWordbookDbFileNameKey = 'last_active_wordbook_db_file_name';
  static const String _lastActiveWordbookNameKey = 'last_active_wordbook_name';

  final DatabaseService _dbService;
  final SheetsService _sheetsService;
  final WordListNotifier _wordListNotifier;
  final SrsService _srsService = SrsService();

  List<Wordbook> _wordbooks = [];
  List<Wordbook> get wordbooks => _wordbooks;
  List<StudyPlan> _studyPlans = [];
  List<StudyPlan> get studyPlans => List.unmodifiable(_studyPlans);

  Wordbook? _activeWordbook;
  Wordbook? get activeWordbook => _activeWordbook;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  int _statsRevision = 0;
  int get statsRevision => _statsRevision;
  final Set<String> _studyActivityDates = {};
  int get studyDayStreak => _calculateStudyDayStreak();

  WordbookManager(this._dbService, this._sheetsService, this._wordListNotifier);

  Future<void> loadInitialData() async {
    _setLoading(true);

    // 1. 기기에서 마지막 활성 단어장 ID를 불러옵니다.
    final prefs = await SharedPreferences.getInstance();
    _studyActivityDates
      ..clear()
      ..addAll(prefs.getStringList(_studyActivityDatesKey) ?? const []);
    final lastActiveId = prefs.getInt(_lastActiveWordbookIdKey);
    final lastActiveDbFileName = prefs.getString(_lastActiveWordbookDbFileNameKey);

    // 2. 전체 단어장 목록을 DB에서 로드합니다.
    await _loadWordbooks(shouldNotify: false);
    await _loadStudyPlans(shouldNotify: false);

    // 3. 저장된 ID가 있다면, 해당 단어장을 찾아 활성화합니다.
    final restoredWordbook = _findRestoredWordbook(lastActiveId, lastActiveDbFileName);
    if (restoredWordbook != null) {
      await setActiveWordbook(restoredWordbook);
    } else if (_wordbooks.isNotEmpty && _activeWordbook == null) {
      // 저장된 ID가 없고, 현재 활성 단어장도 없다면 첫 번째 단어장을 활성화합니다.
      await setActiveWordbook(_wordbooks.first);
    }

    _setLoading(false);
  }

  Future<void> _loadWordbooks({bool shouldNotify = true}) async {
    _wordbooks = await _dbService.getWordbooks();
    _statsRevision++;
    // loadInitialData에서 setActiveWordbook을 관리하므로 여기서는 호출하지 않습니다.
    if (shouldNotify) notifyListeners();
  }

  Future<void> _loadStudyPlans({bool shouldNotify = true}) async {
    final wordbookDbNames = _wordbooks.map((wordbook) => wordbook.dbFileName).toSet();
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
      await _wordListNotifier.loadWords(wordbook.dbFileName);
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
      await prefs.setString(_lastActiveWordbookDbFileNameKey, wordbook.dbFileName);
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
    return _srsService.dueWords(wordsAvailableForPlan(_wordListNotifier.words));
  }

  StudyPlan? planFor(Wordbook? wordbook) {
    if (wordbook == null) return null;
    for (final plan in _studyPlans) {
      if (plan.dbFileName == wordbook.dbFileName) return plan;
    }
    return null;
  }

  StudyPlan? get activeStudyPlan => planFor(_activeWordbook);

  List<Word> wordsAvailableForPlan(List<Word> words, {StudyPlan? plan}) {
    final activePlan = plan ?? activeStudyPlan;
    if (activePlan == null || activePlan.status != StudyPlanStatus.active) return words;

    final orderedWords = _orderedPlanWords(words);
    final unlockedLimit = activePlan.unlockedNewLimit();
    if (unlockedLimit >= activePlan.totalWords || unlockedLimit >= orderedWords.length) {
      return words;
    }
    final unlockedWordKeys = orderedWords.take(unlockedLimit).map(_wordKey).toSet();

    return words.where((word) => unlockedWordKeys.contains(_wordKey(word))).toList();
  }

  int lockedNewWordCount(List<Word> words, {StudyPlan? plan}) {
    final activePlan = plan ?? activeStudyPlan;
    if (activePlan == null || activePlan.status != StudyPlanStatus.active) return 0;
    final orderedWords = _orderedPlanWords(words);
    final unlockedLimit = activePlan.unlockedNewLimit();
    if (unlockedLimit >= activePlan.totalWords || unlockedLimit >= orderedWords.length) return 0;
    return (orderedWords.length - unlockedLimit).clamp(0, orderedWords.length).toInt();
  }

  int plannedNewWordSessionCount(List<Word> words, {StudyPlan? plan}) {
    final availablePlanWords = wordsAvailableForPlan(words, plan: plan);
    final newWordCount = availablePlanWords.where(_srsService.isNewWord).length;
    final activePlan = plan ?? activeStudyPlan;
    if (activePlan == null) return newWordCount;
    return min(activePlan.dailyNewTarget, newWordCount);
  }

  int recommendedNewWordSessionCount(List<Word> words, {StudyPlan? plan}) {
    final activePlan = plan ?? activeStudyPlan;
    final plannedCount = plannedNewWordSessionCount(words, plan: activePlan);
    if (activePlan == null || plannedCount == 0) return plannedCount;

    final availablePlanWords = wordsAvailableForPlan(words, plan: activePlan);
    final reviewCount = _srsService.dueWords(availablePlanWords).length;
    final adjustedCount = _adjustNewWordCountForReviewLoad(
      plannedCount: plannedCount,
      dailyTarget: activePlan.dailyNewTarget,
      reviewCount: reviewCount,
    );
    return min(plannedCount, adjustedCount);
  }

  int _adjustNewWordCountForReviewLoad({
    required int plannedCount,
    required int dailyTarget,
    required int reviewCount,
  }) {
    if (plannedCount <= 0 || reviewCount <= 0) return plannedCount;

    final heavyReviewLine = max(30, dailyTarget * 3);
    if (reviewCount >= heavyReviewLine) return 0;
    if (reviewCount >= dailyTarget * 2) return max(1, (plannedCount * 0.25).ceil());
    if (reviewCount >= dailyTarget) return max(1, (plannedCount * 0.5).ceil());
    if (reviewCount >= (dailyTarget * 0.6).ceil()) return max(1, (plannedCount * 0.75).ceil());
    return plannedCount;
  }

  Future<StudyPlan?> createStudyPlanForWordbook(
    Wordbook wordbook, {
    required int chunkSize,
    required int dailyNewTarget,
  }) async {
    final words = await getAllWordsFrom(wordbook);
    if (words.isEmpty) return null;
    final now = DateTime.now();
    final today = _dateKey(now);
    final existingPlan = planFor(wordbook);
    final plan = StudyPlan(
      id: existingPlan?.id,
      wordbookId: wordbook.id,
      dbFileName: wordbook.dbFileName,
      wordbookName: wordbook.name,
      totalWords: words.length,
      chunkSize: chunkSize,
      dailyNewTarget: dailyNewTarget,
      startDate: existingPlan?.startDate ?? today,
      createdAt: existingPlan?.createdAt ?? now.toIso8601String(),
    );
    final savedPlan = await _dbService.saveStudyPlan(plan);
    _studyPlans.removeWhere((item) => item.dbFileName == wordbook.dbFileName);
    _studyPlans.insert(0, savedPlan);
    _statsRevision++;
    notifyListeners();
    return savedPlan;
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
        sortedDates.length > 370 ? sortedDates.sublist(sortedDates.length - 370) : sortedDates;
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

  String _wordKey(Word word) {
    return '${word.id ?? ''}|${word.word}|${word.meaning}';
  }

  List<Word> _orderedPlanWords(List<Word> words) {
    return List<Word>.from(words)..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
  }

  Future<void> updateWordsInWordbook(Wordbook wordbook, List<Word> words) async {
    await _dbService.updateWordSrsBatch(wordbook.dbFileName, words);
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
      final foundWords = await _dbService.searchWordsInWordbook(wordbook.dbFileName, query);
      if (foundWords.isNotEmpty) {
        searchResults[wordbook] = foundWords;
      }
    }
    _setLoading(false);
    return searchResults;
  }

  Future<void> createNewWordbookFromCsv(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null) return;
    _setLoading(true);
    try {
      final file = result.files.single;
      final path = file.path!;
      final csvString = await File(path).readAsString();
      final List<List<dynamic>> csvTable = const CsvToListConverter().convert(csvString);
      final List<Word> words =
          csvTable
              .skip(1)
              .map((row) {
                if (row.length >= 2) {
                  return Word(word: row[0].toString().trim(), meaning: row[1].toString().trim());
                }
                return null;
              })
              .where((word) => word != null && word.word.isNotEmpty && word.meaning.isNotEmpty)
              .cast<Word>()
              .toList();

      if (words.isEmpty && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CSV 파일에서 유효한 단어를 찾을 수 없습니다.')));
        _setLoading(false);
        return;
      }
      if (!context.mounted) {
        _setLoading(false);
        return;
      }
      final theme = Theme.of(context);
      final nameController = TextEditingController(text: p.basenameWithoutExtension(path));
      final String? newName = await showDialog<String>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('단어장 이름 지정'),
              content: TextField(
                controller: nameController,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '단어장 이름',
                  hintText: '단어장 이름을 입력하세요',
                ),
                style: TextStyle(color: theme.textTheme.bodyLarge?.color),
                onSubmitted: (value) {
                  Navigator.of(dialogContext).pop(value.trim());
                },
              ),
              actions: [
                TextButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                FilledButton(
                  child: const Text('생성'),
                  onPressed: () => Navigator.of(dialogContext).pop(nameController.text.trim()),
                ),
              ],
            ),
      );
      nameController.dispose();
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
    } catch (e) {
      debugPrint("Error creating wordbook from CSV: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('파일 처리 중 오류 발생: $e')));
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteWordbook(Wordbook wordbook) async {
    _setLoading(true);
    if (_activeWordbook?.id == wordbook.id) {
      await setActiveWordbook(null);
    }
    await _dbService.deleteWordbook(wordbook.id!, wordbook.dbFileName);
    _studyPlans.removeWhere((plan) => plan.dbFileName == wordbook.dbFileName);
    await _loadWordbooks();
    _setLoading(false);
  }

  Future<void> mergeWordbooks(Set<int> wordbookIds, String newName, BuildContext context) async {
    _setLoading(true);
    try {
      final List<Word> mergedWords = [];
      final Set<String> uniqueWordTexts = {};
      final List<Wordbook> booksToMerge =
          _wordbooks.where((wb) => wordbookIds.contains(wb.id)).toList();
      for (final book in booksToMerge) {
        final wordsFromDb = await _dbService.getAllWords(book.dbFileName);
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
      if (context.mounted) {
        final deleteOriginals = await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('병합 완료'),
              content: Text("새로운 단어장 '$newName'이(가) 생성되었습니다.\n병합에 사용된 기존 단어장들을 삭제하시겠습니까?"),
              actions: [
                TextButton(
                  child: const Text('유지'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(dialogContext).colorScheme.error,
                    foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                  ),
                  child: const Text('삭제'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                ),
              ],
            );
          },
        );
        if (deleteOriginals == true) {
          for (final bookToDelete in booksToMerge) {
            await deleteWordbook(bookToDelete);
          }
        }
        await _loadWordbooks();
        await setActiveWordbook(savedWordbook);
        if (!context.mounted) return;
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("Error merging wordbooks: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createMultipleWordbooksFromSheets(
    List<sheets.Sheet> selectedSheets,
    String spreadsheetId,
  ) async {
    _setLoading(true);
    try {
      for (final sheet in selectedSheets) {
        final sheetName = sheet.properties?.title;
        if (sheetName == null || sheetName.isEmpty) continue;
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
        final words = await _sheetsService.getWordsFromSheet(spreadsheetId, sheetName);
        if (words != null) {
          await _dbService.addWordsInBatch(savedWordbook.dbFileName, words);
        }
      }
      await _loadWordbooks();
    } catch (e) {
      debugPrint("Error creating multiple wordbooks from sheets: $e");
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
