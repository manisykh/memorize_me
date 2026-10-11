// lib/screens/flashcard_screen.dart

import 'dart:math';
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/learning_route_origin.dart';
import '../models/study_plan_model.dart';
import '../providers/flashcard_settings_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../services/analytics_service.dart';
import '../services/tts_service.dart';
import '../services/study_sound_service.dart';
import '../services/study_history_service.dart';
import '../themes/app_theme.dart';
import '../themes/memorize_identity.dart';
import '../widgets/wordbook_selection_dialog.dart';
import 'quiz_screen.dart';

enum FlashcardLaunchMode { setup, review, newWords, allWords }

enum FlashcardSessionType { allWords, review, newWords }

enum _FlashcardSetupScope { review, newWords, current }

enum _SessionEndAction { restart, unknownOnly, quiz, finish }

class _SessionEndContent {
  final String title;
  final String message;

  const _SessionEndContent({required this.title, required this.message});
}

class FlashcardScreen extends StatefulWidget {
  final FlashcardLaunchMode initialMode;
  final LearningRouteOrigin origin;
  final List<Word>? reviewWordsOverride;

  const FlashcardScreen({
    super.key,
    this.initialMode = FlashcardLaunchMode.setup,
    this.origin = LearningRouteOrigin.standalone,
    this.reviewWordsOverride,
  });

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final CardSwiperController _swiperController = CardSwiperController();

  Wordbook? _selectedWordbook;
  List<Word> _allWords = [];
  List<Word> _sessionWords = [];
  FlashcardSessionType _sessionType = FlashcardSessionType.allWords;
  int _currentCardIndex = 0;
  bool _sessionActive = false;
  late final TtsService _ttsService;

  late WordbookManager _wordbookManager;
  final SrsService _srsService = SrsService();
  final List<Word> _updatedWordsInSession = [];
  final Map<int, SrsDifficulty> _sessionDecisions = {};
  int _unknownCount = 0;
  int _knownCount = 0;
  bool _pendingInitialLaunch = true;
  bool _isEndingSession = false;
  bool _isLeavingSession = false;
  StudySessionRecorder? _historyRecorder;
  bool _showEmptyDeckCompletion = false;
  String? _revealedAdditionalMeaningKey;
  _FlashcardSetupScope? _selectedSetupScope;

  int get _recommendedNewWordSessionCount =>
      _wordbookManager.recommendedNewWordSessionCount(
        _allWords,
        plan: _wordbookManager.planFor(_selectedWordbook),
      );

  List<Word> get _availableWordsForCurrentPlan =>
      _wordbookManager.wordsAvailableForPlan(
        _allWords,
        plan: _wordbookManager.planFor(_selectedWordbook),
      );

  @override
  void initState() {
    super.initState();
    _ttsService = context.read<TtsService>();
    _wordbookManager = context.read<WordbookManager>();

    final initialWordbook = _wordbookManager.activeWordbook;
    if (initialWordbook != null) {
      _onWordbookSelected(initialWordbook);
    }
  }

  @override
  void dispose() {
    _saveUpdatedSrsData();
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    await _wordbookManager.setActiveWordbook(wordbook);

    if (mounted) {
      final words = await _wordbookManager.getAllWordsFrom(wordbook);
      if (!mounted) return;
      setState(() {
        _selectedWordbook = wordbook;
        _allWords = words;
        _sessionWords = _availableWordsForCurrentPlan;
        _selectedSetupScope = null;
      });
      _runInitialLaunchIfNeeded();
    }
  }

  Future<void> _saveUpdatedSrsData() async {
    if (_updatedWordsInSession.isEmpty || _selectedWordbook == null) return;
    final snapshot = List<Word>.from(_updatedWordsInSession);
    await _wordbookManager.pendingSrsWrites;
    for (final updatedWord in snapshot) {
      final allIndex = _allWords.indexWhere(
        (word) => word.id == updatedWord.id,
      );
      if (allIndex != -1) {
        _allWords[allIndex] = updatedWord;
      }
      final sessionIndex = _sessionWords.indexWhere(
        (word) => word.id == updatedWord.id,
      );
      if (sessionIndex != -1) {
        _sessionWords[sessionIndex] = updatedWord;
      }
    }
    _updatedWordsInSession.removeWhere(snapshot.contains);
  }

  bool _onSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    if (previousIndex >= _sessionWords.length) return false;

    final word = _sessionWords[previousIndex];
    final difficulty =
        direction == CardSwiperDirection.right
            ? SrsDifficulty.good
            : SrsDifficulty.again;
    unawaited(
      context.read<StudySoundService>().play(
        difficulty == SrsDifficulty.good
            ? StudySoundEffect.knownSwipe
            : StudySoundEffect.unknownSwipe,
      ),
    );

    final updatedWord = _srsService.updateWordSrs(
      word: word,
      source: SrsUpdateSource.flashcard,
      difficulty: difficulty,
    );
    _historyRecorder?.answer(
      word,
      success: difficulty == SrsDifficulty.good,
      nextReviewDate: updatedWord.nextReviewDate,
    );

    _updatedWordsInSession.removeWhere((w) => w.id == updatedWord.id);
    _updatedWordsInSession.add(updatedWord);
    unawaited(
      _wordbookManager.queueWordsSrsData(_selectedWordbook!.dbFileName, [
        updatedWord,
      ]),
    );
    _sessionDecisions[previousIndex] = difficulty;

    setState(() {
      if (difficulty == SrsDifficulty.good) {
        _knownCount++;
      } else {
        _unknownCount++;
      }
      _currentCardIndex = currentIndex ?? _sessionWords.length;
      _revealedAdditionalMeaningKey = null;
    });
    return true;
  }

  bool _onUndo(
    int? previousIndex,
    int currentIndex,
    CardSwiperDirection direction,
  ) {
    if (currentIndex < 0 || currentIndex >= _sessionWords.length) return true;
    final difficulty = _sessionDecisions.remove(currentIndex);
    final word = _sessionWords[currentIndex];
    _historyRecorder?.undo(word);
    unawaited(
      _wordbookManager.queueWordsSrsData(_selectedWordbook!.dbFileName, [word]),
    );

    _updatedWordsInSession.removeWhere(
      (updatedWord) => updatedWord.id == word.id,
    );
    setState(() {
      if (difficulty == SrsDifficulty.good) {
        _knownCount = max(0, _knownCount - 1);
      } else if (difficulty == SrsDifficulty.again) {
        _unknownCount = max(0, _unknownCount - 1);
      }
      _currentCardIndex = currentIndex;
      _revealedAdditionalMeaningKey = null;
    });
    return true;
  }

  void _runInitialLaunchIfNeeded() {
    if (!_pendingInitialLaunch ||
        _selectedWordbook == null ||
        (_sessionWords.isEmpty &&
            (widget.reviewWordsOverride?.isEmpty ?? true))) {
      return;
    }
    _pendingInitialLaunch = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialMode == FlashcardLaunchMode.review) {
        _startSession(srsOnly: true);
      } else if (widget.initialMode == FlashcardLaunchMode.newWords) {
        _startNewWordSession();
      } else if (widget.initialMode == FlashcardLaunchMode.allWords) {
        _startSession(srsOnly: false);
      }
    });
  }

  void _resetSessionProgress() {
    final book = _selectedWordbook;
    if (book != null) {
      _sessionWords = _wordbookManager.latestStudyWords(
        book.dbFileName,
        _sessionWords,
      );
      _historyRecorder = StudyHistoryService.instance.start(
        wordbook: book,
        mode: StudyHistoryMode.flashcard,
        expectedCount: _sessionWords.length,
        plan: _wordbookManager.planForSession(book, _sessionWords),
      );
    }
    _updatedWordsInSession.clear();
    _sessionDecisions.clear();
    _unknownCount = 0;
    _knownCount = 0;
    _isEndingSession = false;
    _showEmptyDeckCompletion = false;
    _revealedAdditionalMeaningKey = null;
  }

  void _startSession({required bool srsOnly}) {
    if (_selectedWordbook == null) {
      _showSnackbar('학습할 단어장을 선택해주세요.');
      return;
    }

    List<Word> wordsForSession;
    if (srsOnly) {
      wordsForSession =
          widget.reviewWordsOverride ?? _wordbookManager.getWordsForReview();
      if (wordsForSession.isEmpty) {
        _showSnackbar('오늘 복습할 단어가 없습니다!');
        return;
      }
    } else {
      wordsForSession =
          widget.reviewWordsOverride ?? _availableWordsForCurrentPlan;
      if (wordsForSession.isEmpty) {
        _showSnackbar('단어장에 학습할 단어가 없습니다.');
        return;
      }
    }

    setState(() {
      _sessionWords = List.from(wordsForSession)..shuffle();
      _sessionType =
          srsOnly ? FlashcardSessionType.review : FlashcardSessionType.allWords;
      _currentCardIndex = 0;
      _sessionActive = true;
      _resetSessionProgress();
    });
    context.read<AnalyticsService>().logStudyStarted(
      mode: srsOnly ? 'flashcard_review' : 'flashcard_all',
      wordCount: wordsForSession.length,
    );
  }

  void _startNewWordSession() {
    if (_selectedWordbook == null) {
      _showSnackbar('학습할 단어장을 선택해주세요.');
      return;
    }

    final availableNewWords = List<Word>.from(
      _availableWordsForCurrentPlan.where(_srsService.isNewWord),
    );
    final batchSize = _recommendedNewWordSessionCount;
    if (availableNewWords.isNotEmpty && batchSize == 0) {
      _showSnackbar('복습량이 많아 오늘 새 단어는 잠시 줄였어요.');
      return;
    }

    final newWords = (availableNewWords..shuffle()).take(batchSize).toList();
    if (newWords.isEmpty) {
      _showSnackbar('새로 학습할 단어가 없습니다.');
      return;
    }

    setState(() {
      _sessionWords = List.from(newWords)..shuffle();
      _sessionType = FlashcardSessionType.newWords;
      _currentCardIndex = 0;
      _sessionActive = true;
      _resetSessionProgress();
    });
    context.read<AnalyticsService>().logStudyStarted(
      mode: 'flashcard_new_words',
      wordCount: newWords.length,
    );
  }

  _FlashcardSetupScope _effectiveSetupScope({
    required int reviewCount,
    required int newWordCount,
    required int currentCount,
  }) {
    final selected = _selectedSetupScope;
    if (selected == _FlashcardSetupScope.review && reviewCount > 0) {
      return selected!;
    }
    if (selected == _FlashcardSetupScope.newWords && newWordCount > 0) {
      return selected!;
    }
    if (selected == _FlashcardSetupScope.current && currentCount > 0) {
      return selected!;
    }
    if (reviewCount > 0) return _FlashcardSetupScope.review;
    if (newWordCount > 0) return _FlashcardSetupScope.newWords;
    return _FlashcardSetupScope.current;
  }

  void _startSetupScope(_FlashcardSetupScope scope) {
    switch (scope) {
      case _FlashcardSetupScope.review:
        _startSession(srsOnly: true);
        break;
      case _FlashcardSetupScope.newWords:
        _startNewWordSession();
        break;
      case _FlashcardSetupScope.current:
        _startSession(srsOnly: false);
        break;
    }
  }

  void _onSessionEnd() {
    if (_isEndingSession) return;
    _isEndingSession = true;
    context.read<AnalyticsService>().logStudyCompleted(
      mode: 'flashcard_${_sessionType.name}',
      wordCount: _sessionWords.length,
    );
    _historyRecorder?.complete();

    setState(() {
      _currentCardIndex = _sessionWords.length;
      _showEmptyDeckCompletion = true;
    });

    // Card writes are already queued per swipe. Showing the completion dialog
    // must not wait for a long database queue, especially on large decks.
    unawaited(_saveUpdatedSrsData());
    unawaited(_showSessionEndDialog());
  }

  Future<void> _showSessionEndDialog() async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted || !_sessionActive) return;

    final action = await showDialog<_SessionEndAction>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 22),
            child: _buildSessionEndDialog(dialogContext, _sessionEndContent()),
          ),
    );
    if (!mounted) return;

    switch (action ?? _SessionEndAction.finish) {
      case _SessionEndAction.restart:
        _restartCurrentSession();
        break;
      case _SessionEndAction.unknownOnly:
        _restartUnknownSession();
        break;
      case _SessionEndAction.quiz:
        _goToQuiz();
        break;
      case _SessionEndAction.finish:
        _finishSession();
        break;
    }
  }

  _SessionEndContent _sessionEndContent() {
    final plan = _wordbookManager.planFor(_selectedWordbook);
    if (plan != null &&
        plan.mode == StudyPlanMode.free &&
        _sessionType != FlashcardSessionType.review) {
      return _SessionEndContent(
        title: '${plan.currentChunk()}번 묶음 학습 완료',
        message:
            '알아요 $_knownCount개 · 몰라요 $_unknownCount개로 묶음 학습을 마쳤어요. 지금 기억을 한 번 더 확인해 보세요.',
      );
    }
    switch (_sessionType) {
      case FlashcardSessionType.review:
        return _SessionEndContent(
          title: '오늘 복습 완료',
          message:
              '알아요 $_knownCount개 · 몰라요 $_unknownCount개로 복습을 마쳤어요. 학습 결과는 다음 복습 일정에 반영됩니다.',
        );
      case FlashcardSessionType.newWords:
        return _SessionEndContent(
          title: '새 단어 학습 완료',
          message:
              '알아요 $_knownCount개 · 몰라요 $_unknownCount개가 SRS 일정에 반영됐어요. 객관식 퀴즈로 바로 확인할 수 있어요.',
        );
      case FlashcardSessionType.allWords:
        return _SessionEndContent(
          title: '카드 학습 완료',
          message:
              '알아요 $_knownCount개 · 몰라요 $_unknownCount개로 카드 학습을 마쳤어요. 원하는 방식으로 기억을 더 단단하게 만들어 보세요.',
        );
    }
  }

  void _finishSession() {
    if (!mounted) return;
    setState(() {
      _sessionActive = false;
      _showEmptyDeckCompletion = false;
      _isEndingSession = false;
    });
    if (widget.origin != LearningRouteOrigin.standalone &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _restartCurrentSession() {
    if (!mounted) return;
    setState(() {
      _sessionWords.shuffle();
      _currentCardIndex = 0;
      _swiperController.moveTo(0);
      _resetSessionProgress();
    });
  }

  void _restartUnknownSession() {
    if (!mounted) return;
    final unknownWords =
        _sessionDecisions.entries
            .where((entry) => entry.value == SrsDifficulty.again)
            .map((entry) => entry.key)
            .where((index) => index >= 0 && index < _sessionWords.length)
            .map((index) => _sessionWords[index])
            .toList();

    setState(() {
      if (unknownWords.isNotEmpty) {
        _sessionWords = List.from(unknownWords)..shuffle();
      } else {
        _sessionWords.shuffle();
      }
      _currentCardIndex = 0;
      _swiperController.moveTo(0);
      _resetSessionProgress();
    });
  }

  void _goToQuiz() {
    if (!mounted) return;
    final quizWords =
        _selectedWordbook == null
            ? List<Word>.from(_sessionWords)
            : _wordbookManager.latestStudyWords(
              _selectedWordbook!.dbFileName,
              _sessionWords,
            );
    setState(() => _sessionActive = false);
    final route = MaterialPageRoute(
      builder:
          (_) => QuizScreen(
            initialMode: QuizMode.multipleChoice,
            origin: widget.origin,
            wordsOverride: quizWords,
          ),
    );
    if (widget.origin == LearningRouteOrigin.standalone) {
      Navigator.of(context).push(route);
    } else {
      Navigator.of(context).pushReplacement(route);
    }
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _leaveSession() async {
    if (_isLeavingSession) return;
    _isLeavingSession = true;
    await _saveUpdatedSrsData();
    if (!mounted) return;
    final popped = await Navigator.of(context).maybePop();
    if (!popped && mounted) setState(() => _isLeavingSession = false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) return;
        if (_sessionActive) {
          await _saveUpdatedSrsData();
        }
      },
      child: _sessionActive ? _buildFlashcardSession() : _buildSetupScreen(),
    );
  }

  Widget _buildSetupScreen() {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final settings = context.watch<FlashcardSettingsProvider>();
    final studyPlan = _wordbookManager.planFor(_selectedWordbook);
    final availableWords = _availableWordsForCurrentPlan;
    final newWordsInScope = availableWords.where(_srsService.isNewWord).length;
    final reviewCount = _wordbookManager.getWordsForReview().length;
    final recommendedNewCount = _recommendedNewWordSessionCount;
    final selectedScope = _effectiveSetupScope(
      reviewCount: reviewCount,
      newWordCount: recommendedNewCount,
      currentCount: availableWords.length,
    );
    final canStart = switch (selectedScope) {
      _FlashcardSetupScope.review => reviewCount > 0,
      _FlashcardSetupScope.newWords => recommendedNewCount > 0,
      _FlashcardSetupScope.current => availableWords.isNotEmpty,
    };
    final startLabel = switch (selectedScope) {
      _FlashcardSetupScope.review => '오늘 복습 $reviewCount개 시작',
      _FlashcardSetupScope.newWords => '새 단어 $recommendedNewCount개 학습',
      _FlashcardSetupScope.current =>
        '${studyPlan == null ? '전체 단어' : '현재 범위'} ${availableWords.length}개 학습',
    };

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: const Text('플래시카드 학습 준비')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '카드 순서와 학습 범위를 선택하세요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: identity.mutedInk,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            _buildSetupSectionTitle(theme, identity, '현재 단어장'),
            const SizedBox(height: 10),
            _buildSetupWordbookRow(
              theme: theme,
              identity: identity,
              plan: studyPlan,
              availableCount: availableWords.length,
            ),
            const SizedBox(height: 24),
            _buildSetupSectionTitle(theme, identity, '카드 표시 순서'),
            const SizedBox(height: 10),
            _buildFrontTypeSelector(
              theme: theme,
              identity: identity,
              selected: settings.frontType,
              onChanged: settings.setFrontType,
            ),
            const SizedBox(height: 24),
            _buildSetupSectionTitle(theme, identity, '학습 범위'),
            const SizedBox(height: 10),
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
                  _buildSetupScopeRow(
                    theme: theme,
                    identity: identity,
                    scope: _FlashcardSetupScope.review,
                    selectedScope: selectedScope,
                    enabled: reviewCount > 0,
                    title: '오늘 복습 $reviewCount개',
                    description: '복습일이 되었거나 지난 단어',
                  ),
                  Divider(height: 1, color: identity.border),
                  _buildSetupScopeRow(
                    theme: theme,
                    identity: identity,
                    scope: _FlashcardSetupScope.newWords,
                    selectedScope: selectedScope,
                    enabled: recommendedNewCount > 0,
                    title: '새 단어 $recommendedNewCount개',
                    description:
                        newWordsInScope > recommendedNewCount
                            ? '열린 새 단어 $newWordsInScope개 중 오늘 학습할 분량'
                            : '오늘 처음 학습할 수 있는 단어',
                  ),
                  Divider(height: 1, color: identity.border),
                  _buildSetupScopeRow(
                    theme: theme,
                    identity: identity,
                    scope: _FlashcardSetupScope.current,
                    selectedScope: selectedScope,
                    enabled: availableWords.isNotEmpty,
                    title:
                        '${studyPlan == null ? '전체 단어' : '현재 플랜 범위'} ${availableWords.length}개',
                    description:
                        studyPlan?.mode == StudyPlanMode.free
                            ? '현재 묶음에서 학습 가능한 모든 단어'
                            : studyPlan == null
                            ? '선택한 단어장의 모든 단어'
                            : '현재 플랜에서 학습 가능한 모든 단어',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
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
                    '학습 결과는 SRS와 다음 복습 일정에 반영됩니다.',
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: SizedBox(
            height: 54,
            child: FilledButton(
              onPressed:
                  canStart ? () => _startSetupScope(selectedScope) : null,
              style: FilledButton.styleFrom(
                backgroundColor: identity.primaryAction,
                foregroundColor: Colors.white,
                disabledBackgroundColor: identity.border,
                shape: const StadiumBorder(),
              ),
              child: Text(
                startLabel,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSetupSectionTitle(
    ThemeData theme,
    MemorizeIdentity identity,
    String title,
  ) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        color: identity.ink,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildSetupWordbookRow({
    required ThemeData theme,
    required MemorizeIdentity identity,
    required StudyPlan? plan,
    required int availableCount,
  }) {
    final String subtitle;
    if (plan == null) {
      subtitle = '전체 ${_allWords.length}개';
    } else if (plan.mode == StudyPlanMode.free) {
      subtitle =
          '전체 ${_allWords.length}개 · 현재 묶음 ${plan.currentChunk()}/${plan.chunkCount}';
    } else {
      subtitle = '전체 ${_allWords.length}개 · 현재 플랜 범위 $availableCount개';
    }
    return Material(
      color: identity.softContext,
      borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
        onTap: () async {
          final selected = await showWordbookSelectionDialog(context);
          if (selected != null) await _onWordbookSelected(selected);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
            border: Border.all(
              color: identity.primaryAction.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.book, color: identity.success, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _selectedWordbook?.name ?? '단어장을 선택해주세요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_selectedWordbook != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: identity.mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                color: identity.mutedInk,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrontTypeSelector({
    required ThemeData theme,
    required MemorizeIdentity identity,
    required FlashcardFrontType selected,
    required ValueChanged<FlashcardFrontType> onChanged,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: identity.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children:
            FlashcardFrontType.values.map((value) {
              final isSelected = selected == value;
              return Expanded(
                child: Material(
                  color:
                      isSelected ? identity.primaryAction : Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(value),
                    child: Center(
                      child: Text(
                        value == FlashcardFrontType.word ? '단어 먼저' : '뜻 먼저',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: isSelected ? Colors.white : identity.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildSetupScopeRow({
    required ThemeData theme,
    required MemorizeIdentity identity,
    required _FlashcardSetupScope scope,
    required _FlashcardSetupScope selectedScope,
    required bool enabled,
    required String title,
    required String description,
  }) {
    final selected = scope == selectedScope;
    return Material(
      color: selected ? identity.softContext : identity.surface,
      child: InkWell(
        onTap:
            enabled ? () => setState(() => _selectedSetupScope = scope) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                Icon(
                  selected
                      ? CupertinoIcons.largecircle_fill_circle
                      : CupertinoIcons.circle,
                  color: selected ? identity.primaryAction : identity.mutedInk,
                  size: 24,
                ),
                const SizedBox(width: 14),
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
                        description,
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
          ),
        ),
      ),
    );
  }

  Widget _buildFlashcardSession() {
    final theme = Theme.of(context);
    final sessionTitle =
        _sessionType == FlashcardSessionType.review ? '플래시카드 복습' : '플래시카드 학습';

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: true,
        title: Text(sessionTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: '학습 나가기',
          onPressed: _leaveSession,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: _buildSessionHeader(theme),
              ),
              if (_sessionWords.isNotEmpty && !_showEmptyDeckCompletion)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _buildWordStagePanel(
                    theme,
                    MemorizeIdentity.of(theme),
                    _sessionWords[_currentCardIndex.clamp(
                      0,
                      _sessionWords.length - 1,
                    )],
                  ),
                ),
              Expanded(
                child:
                    _sessionWords.isEmpty
                        ? const Center(child: Text("학습할 단어가 없습니다."))
                        : Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                          child: Column(
                            children: [
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 260),
                                  child:
                                      _showEmptyDeckCompletion
                                          ? _buildEmptyDeckCompletion(theme)
                                          : Stack(
                                            key: const ValueKey(
                                              'flashcard_deck',
                                            ),
                                            children: [
                                              Positioned.fill(
                                                child: _buildDeckPreview(theme),
                                              ),
                                              CardSwiper(
                                                controller: _swiperController,
                                                cardsCount:
                                                    _sessionWords.length,
                                                onSwipe: _onSwipe,
                                                onUndo: _onUndo,
                                                onEnd: _onSessionEnd,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 4,
                                                    ),
                                                maxAngle: 0,
                                                backCardOffset: const Offset(
                                                  0,
                                                  16,
                                                ),
                                                numberOfCardsDisplayed: min(
                                                  3,
                                                  _sessionWords.length,
                                                ),
                                                allowedSwipeDirection:
                                                    AllowedSwipeDirection.symmetric(
                                                      horizontal: true,
                                                    ),
                                                cardBuilder: (
                                                  context,
                                                  index,
                                                  percentThresholdX,
                                                  percentThresholdY,
                                                ) {
                                                  final word =
                                                      _sessionWords[index];
                                                  final settings =
                                                      context
                                                          .read<
                                                            FlashcardSettingsProvider
                                                          >();
                                                  final bool showWordFirst =
                                                      settings.frontType ==
                                                      FlashcardFrontType.word;
                                                  final identity =
                                                      MemorizeIdentity.of(
                                                        Theme.of(context),
                                                      );

                                                  Color overlayColor =
                                                      Colors.transparent;
                                                  if (percentThresholdX != 0) {
                                                    final opacity = min(
                                                      percentThresholdX.abs() /
                                                          100,
                                                      0.22,
                                                    );
                                                    overlayColor =
                                                        percentThresholdX > 0
                                                            ? identity.success
                                                                .withValues(
                                                                  alpha:
                                                                      opacity,
                                                                )
                                                            : identity.review
                                                                .withValues(
                                                                  alpha:
                                                                      opacity,
                                                                );
                                                  }

                                                  final frontWidget =
                                                      _buildCardSurface(
                                                        context: context,
                                                        word: word,
                                                        isWordSide:
                                                            showWordFirst,
                                                        overlayColor:
                                                            overlayColor,
                                                        showAdditionalMeanings:
                                                            _revealedAdditionalMeaningKey ==
                                                            _additionalMeaningKey(
                                                              word,
                                                            ),
                                                      );

                                                  final backWidget =
                                                      _buildCardSurface(
                                                        context: context,
                                                        word: word,
                                                        isWordSide:
                                                            !showWordFirst,
                                                        overlayColor:
                                                            overlayColor,
                                                        showAdditionalMeanings:
                                                            _revealedAdditionalMeaningKey ==
                                                            _additionalMeaningKey(
                                                              word,
                                                            ),
                                                      );

                                                  final dragRatio =
                                                      (percentThresholdX / 100)
                                                          .clamp(-1.0, 1.0)
                                                          .toDouble();
                                                  return Transform.rotate(
                                                    alignment:
                                                        Alignment.bottomCenter,
                                                    angle:
                                                        dragRatio * (pi / 18),
                                                    child: _ResponsiveFlipCard(
                                                      key: ValueKey(
                                                        '${word.id ?? word.word}-$showWordFirst',
                                                      ),
                                                      front: frontWidget,
                                                      back: backWidget,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                ),
                              ),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSessionHeader(ThemeData theme) {
    final identity = MemorizeIdentity.of(theme);
    final totalCount = _sessionWords.length;
    final displayIndex =
        totalCount == 0 ? 0 : _currentCardIndex.clamp(0, totalCount - 1) + 1;
    final progress = totalCount == 0 ? 0.0 : displayIndex / totalCount;
    final title = _selectedWordbook?.name ?? '현재 단어장';
    final decidedCount = _knownCount + _unknownCount;
    final knownRatio =
        decidedCount == 0 ? 0 : ((_knownCount / decidedCount) * 100).round();
    final unknownRatio =
        decidedCount == 0 ? 0 : ((_unknownCount / decidedCount) * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '$displayIndex / $totalCount',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: identity.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: identity.primaryAction,
              backgroundColor: identity.primaryAction.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 13),
          Divider(height: 1, color: identity.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInlineDecisionSummary(
                  theme: theme,
                  icon: CupertinoIcons.xmark_circle_fill,
                  label: '몰라요',
                  value: '$_unknownCount개 · $unknownRatio%',
                  color: identity.review,
                ),
              ),
              Container(width: 1, height: 30, color: identity.border),
              Expanded(
                child: _buildInlineDecisionSummary(
                  theme: theme,
                  icon: CupertinoIcons.check_mark_circled_solid,
                  label: '알아요',
                  value: '$_knownCount개 · $knownRatio%',
                  color: identity.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyDeckCompletion(ThemeData theme) {
    final accentColor = switch (_sessionType) {
      FlashcardSessionType.review => AppTheme.accentCoral,
      FlashcardSessionType.newWords => AppTheme.primaryGreen,
      FlashcardSessionType.allWords => theme.colorScheme.primary,
    };

    return Center(
      key: const ValueKey('empty_deck_completion'),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: accentColor.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: 0.08),
              blurRadius: 28,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.check_mark_circled_solid,
                color: accentColor,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              '카드를 모두 확인했습니다',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '남은 카드가 없습니다. 결과를 정리하고 다음 행동을 안내할게요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckPreview(ThemeData theme) {
    if (_sessionWords.length <= 1) {
      return const SizedBox.shrink();
    }

    final identity = MemorizeIdentity.of(theme);
    final previews = <Widget>[];
    for (var depth = 2; depth >= 1; depth--) {
      final previewIndex = _currentCardIndex + depth;
      if (previewIndex >= _sessionWords.length) {
        continue;
      }
      previews.add(
        Positioned(
          left: 18.0 + (depth * 10),
          right: 18.0 + (depth * 10),
          top: 14.0 + (depth * 14),
          bottom: depth * 10.0,
          child: IgnorePointer(
            child: Opacity(
              opacity: depth == 1 ? 0.78 : 0.52,
              child: Container(
                decoration: BoxDecoration(
                  color: identity.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: identity.primaryAction.withValues(alpha: 0.12),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Stack(children: previews);
  }

  Widget _buildCardDecisionRow(ThemeData theme) {
    final identity = MemorizeIdentity.of(theme);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildRoundCardAction(
          theme: theme,
          icon: CupertinoIcons.xmark,
          label: '몰라요',
          accentColor: identity.review,
          onTap: () => _swiperController.swipe(CardSwiperDirection.left),
        ),
        _buildRoundCardAction(
          theme: theme,
          icon: CupertinoIcons.arrow_counterclockwise,
          semanticLabel: '방금 카드 되돌리기',
          accentColor: identity.mutedInk,
          size: 50,
          onTap:
              _knownCount + _unknownCount == 0
                  ? null
                  : () => _swiperController.undo(),
        ),
        _buildRoundCardAction(
          theme: theme,
          icon: CupertinoIcons.check_mark,
          label: '알아요',
          accentColor: identity.success,
          onTap: () => _swiperController.swipe(CardSwiperDirection.right),
        ),
      ],
    );
  }

  Widget _buildInlineDecisionSummary({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 19),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            '$label $value',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoundCardAction({
    required ThemeData theme,
    required IconData icon,
    String? label,
    String? semanticLabel,
    required Color accentColor,
    VoidCallback? onTap,
    double size = 58,
  }) {
    final enabledColor =
        onTap == null ? accentColor.withValues(alpha: 0.35) : accentColor;
    return SizedBox(
      width: 88,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: semanticLabel ?? label ?? '',
            child: Material(
              color: enabledColor.withValues(alpha: 0.11),
              shape: CircleBorder(
                side: BorderSide(color: enabledColor.withValues(alpha: 0.34)),
              ),
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(icon, color: enabledColor, size: size * 0.42),
                ),
              ),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 18,
            child:
                label == null
                    ? null
                    : Text(
                      label,
                      maxLines: 1,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: enabledColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionEndDialog(
    BuildContext dialogContext,
    _SessionEndContent content,
  ) {
    final theme = Theme.of(dialogContext);
    final identity = MemorizeIdentity.of(theme);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: identity.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: -10,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: identity.softSuccess,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  CupertinoIcons.check_mark_circled,
                  color: identity.success,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      content.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_sessionWords.length}개 카드 학습 완료',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '학습 마치기',
                visualDensity: VisualDensity.compact,
                onPressed:
                    () =>
                        Navigator.pop(dialogContext, _SessionEndAction.finish),
                icon: Icon(
                  CupertinoIcons.xmark,
                  color: identity.mutedInk,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: identity.canvas,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: identity.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCompletionMetric(
                    theme: theme,
                    label: '알아요',
                    value: _knownCount,
                    color: identity.primaryAction,
                  ),
                ),
                Container(width: 1, height: 38, color: identity.border),
                Expanded(
                  child: _buildCompletionMetric(
                    theme: theme,
                    label: '몰라요',
                    value: _unknownCount,
                    color: identity.review,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            content.message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: identity.mutedInk,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _buildCompletionAction(
            dialogContext: dialogContext,
            icon: CupertinoIcons.arrow_counterclockwise,
            label: '다시 학습',
            action: _SessionEndAction.restart,
            color: identity.primaryAction,
            filled: false,
          ),
          const SizedBox(height: 9),
          _buildCompletionAction(
            dialogContext: dialogContext,
            icon: CupertinoIcons.xmark_circle,
            label: _unknownCount > 0 ? '몰라요만 학습 ($_unknownCount개)' : '몰라요만 학습',
            action: _SessionEndAction.unknownOnly,
            color: identity.review,
            filled: false,
            enabled: _unknownCount > 0,
          ),
          const SizedBox(height: 9),
          _buildCompletionAction(
            dialogContext: dialogContext,
            icon: CupertinoIcons.play_fill,
            label: '퀴즈 시작',
            action: _SessionEndAction.quiz,
            color: identity.primaryAction,
            filled: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCompletionMetric({
    required ThemeData theme,
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$value개',
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionAction({
    required BuildContext dialogContext,
    required IconData icon,
    required String label,
    required _SessionEndAction action,
    required Color color,
    required bool filled,
    bool enabled = true,
  }) {
    final onPressed =
        enabled ? () => Navigator.pop(dialogContext, action) : null;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      height: 48,
      child:
          filled
              ? FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  shape: const StadiumBorder(),
                ),
                child: child,
              )
              : OutlinedButton(
                onPressed: onPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: color,
                  side: BorderSide(
                    color:
                        enabled
                            ? color.withValues(alpha: 0.45)
                            : color.withValues(alpha: 0.14),
                  ),
                  shape: const StadiumBorder(),
                ),
                child: child,
              ),
    );
  }

  Widget _buildCardSurface({
    required BuildContext context,
    required Word word,
    required bool isWordSide,
    required Color overlayColor,
    required bool showAdditionalMeanings,
  }) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final accentColor = identity.primaryAction;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.045,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                color: identity.surface,
                border: Border.all(color: accentColor.withValues(alpha: 0.24)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: _buildCardSide(
                word: word,
                isWordSide: isWordSide,
                showAdditionalMeanings: showAdditionalMeanings,
                onToggleAdditionalMeanings: () {
                  final key = _additionalMeaningKey(word);
                  setState(() {
                    _revealedAdditionalMeaningKey =
                        _revealedAdditionalMeaningKey == key ? null : key;
                  });
                },
              ),
            ),
          ),
          if (overlayColor != Colors.transparent)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: overlayColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ▼▼▼ [수정] 전체 위젯 수정
  Widget _buildCardSide({
    required Word word,
    required bool isWordSide,
    required bool showAdditionalMeanings,
    required VoidCallback onToggleAdditionalMeanings,
  }) {
    final additionalMeaningText = word.additionalMeanings.join(' · ');
    final mainText =
        !isWordSide &&
                showAdditionalMeanings &&
                additionalMeaningText.isNotEmpty
            ? additionalMeaningText
            : isWordSide
            ? word.word
            : word.meaning;
    final exampleText = isWordSide ? word.exampleSentence : null;
    final translationText = isWordSide ? null : word.exampleSentenceTranslation;
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: identity.softInfo,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: identity.primaryAction.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  isWordSide ? '단어' : '뜻',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: identity.primaryAction,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: identity.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: identity.border),
                ),
                child: Text(
                  '탭해서 뒤집기',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: Text(
                      mainText,
                      key: ValueKey(
                        '$isWordSide-$showAdditionalMeanings-$mainText',
                      ),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w800,
                        height: 1.22,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  if (exampleText != null && exampleText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Column(
                        children: [
                          Divider(color: identity.border),
                          const SizedBox(height: 14),
                          Text(
                            exampleText,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: identity.ink,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  if (translationText != null && translationText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 24.0),
                      child: Column(
                        children: [
                          Divider(color: identity.border),
                          const SizedBox(height: 14),
                          Text(
                            translationText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: identity.mutedInk,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child:
                isWordSide
                    ? OutlinedButton.icon(
                      onPressed: () => _ttsService.speak(word.word),
                      icon: const Icon(CupertinoIcons.speaker_2_fill, size: 18),
                      label: const Text('발음 듣기'),
                    )
                    : word.additionalMeanings.isEmpty
                    ? const SizedBox.shrink()
                    : OutlinedButton.icon(
                      onPressed: onToggleAdditionalMeanings,
                      icon: Icon(
                        showAdditionalMeanings
                            ? CupertinoIcons.chevron_up
                            : CupertinoIcons.eye,
                        size: 18,
                      ),
                      label: Text(
                        showAdditionalMeanings
                            ? '대표 뜻 보기'
                            : '${_additionalMeaningButtonLabel(word)} 보기',
                      ),
                    ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _buildCardDecisionRow(theme),
        ),
      ],
    );
  }

  Widget _buildWordStagePanel(
    ThemeData theme,
    MemorizeIdentity identity,
    Word word,
  ) {
    const stages = <SrsStage>[
      SrsStage.newWord,
      SrsStage.learning,
      SrsStage.scheduled,
      SrsStage.due,
      SrsStage.mature,
    ];
    final currentStage = _srsService.stageFor(word);
    final activeIndex = stages.indexOf(currentStage);
    final stageColor = _colorForSrsStage(identity, currentStage);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
      decoration: BoxDecoration(
        color: stageColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: stageColor.withValues(alpha: 0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '이 단어의 기억 단계',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: stageColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _srsService.labelForStage(currentStage),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: stageColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(stages.length, (index) {
              final active = index <= activeIndex;
              return Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 23,
                            height: 23,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color:
                                  active
                                      ? stageColor
                                      : identity.border.withValues(alpha: 0.64),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color:
                                    active ? Colors.white : identity.mutedInk,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _srsService.labelForStage(stages[index]),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: active ? stageColor : identity.mutedInk,
                              fontSize: 10,
                              fontWeight:
                                  active ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (index < stages.length - 1)
                      Container(
                        width: 8,
                        height: 1.5,
                        margin: const EdgeInsets.only(top: 11),
                        color:
                            index < activeIndex
                                ? stageColor.withValues(alpha: 0.72)
                                : identity.border,
                      ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Color _colorForSrsStage(MemorizeIdentity identity, SrsStage stage) {
    return switch (stage) {
      SrsStage.newWord => identity.primaryAction,
      SrsStage.learning => const Color(0xFFE17A00),
      SrsStage.scheduled => identity.scheduled,
      SrsStage.due => identity.review,
      SrsStage.mature => identity.success,
    };
  }

  String _additionalMeaningKey(Word word) =>
      '${word.id ?? word.word}|${word.meaning}';

  String _additionalMeaningButtonLabel(Word word) {
    final joined = word.additionalMeanings.join(' ');
    final hasKorean = RegExp(r'[가-힣]').hasMatch(joined);
    final hasEnglish = RegExp(r'[A-Za-z]').hasMatch(joined);
    if (hasKorean && !hasEnglish) return '한글 뜻';
    if (hasEnglish && !hasKorean) return '영어 뜻';
    return '추가 뜻';
  }
}

class _ResponsiveFlipCard extends StatefulWidget {
  const _ResponsiveFlipCard({
    super.key,
    required this.front,
    required this.back,
  });

  final Widget front;
  final Widget back;

  @override
  State<_ResponsiveFlipCard> createState() => _ResponsiveFlipCardState();
}

class _ResponsiveFlipCardState extends State<_ResponsiveFlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _showingFront = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
  }

  Future<void> _toggle() async {
    if (_controller.isAnimating) return;
    if (_showingFront) {
      await _controller.forward();
    } else {
      await _controller.reverse();
    }
    if (!mounted) return;
    setState(() => _showingFront = !_showingFront);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final value = _controller.value;
          final showFront = value < 0.5;
          final angle = showFront ? value * pi : (value - 1) * pi;
          final transform =
              Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: showFront ? widget.front : widget.back,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
