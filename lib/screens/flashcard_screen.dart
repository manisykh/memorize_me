// lib/screens/flashcard_screen.dart

import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/flashcard_settings_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../services/tts_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_button.dart';
import 'quiz_screen.dart';

enum FlashcardLaunchMode { setup, review, newWords }

enum FlashcardSessionType { allWords, review, newWords }

class _SessionEndContent {
  final String title;
  final String message;
  final String primaryLabel;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;

  const _SessionEndContent({
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
  });
}

class FlashcardScreen extends StatefulWidget {
  final FlashcardLaunchMode initialMode;

  const FlashcardScreen({super.key, this.initialMode = FlashcardLaunchMode.setup});

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
  bool _pendingInitialLaunch = true;

  int get _recommendedNewWordSessionCount =>
      _srsService.buildDailyPlan(_allWords).suggestedNewWordBatchSize;

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
      setState(() {
        _selectedWordbook = wordbook;
        _allWords = words;
        _sessionWords = words;
      });
      _runInitialLaunchIfNeeded();
    }
  }

  Future<void> _saveUpdatedSrsData() async {
    if (_updatedWordsInSession.isEmpty || _selectedWordbook == null) return;

    await _wordbookManager.updateWordsSrsData(
      _selectedWordbook!.dbFileName,
      _updatedWordsInSession,
    );
    _updatedWordsInSession.clear();
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (previousIndex >= _sessionWords.length) return false;

    final word = _sessionWords[previousIndex];
    final difficulty =
        direction == CardSwiperDirection.right ? SrsDifficulty.good : SrsDifficulty.again;

    final updatedWord = _srsService.updateWordSrs(
      word: word,
      source: SrsUpdateSource.flashcard,
      difficulty: difficulty,
    );

    _updatedWordsInSession.removeWhere((w) => w.id == updatedWord.id);
    _updatedWordsInSession.add(updatedWord);

    setState(() => _currentCardIndex = currentIndex ?? 0);
    return true;
  }

  void _runInitialLaunchIfNeeded() {
    if (!_pendingInitialLaunch || _selectedWordbook == null || _sessionWords.isEmpty) return;
    _pendingInitialLaunch = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.initialMode == FlashcardLaunchMode.review) {
        _startSession(srsOnly: true);
      } else if (widget.initialMode == FlashcardLaunchMode.newWords) {
        _startNewWordSession();
      }
    });
  }

  void _startSession({required bool srsOnly}) {
    if (_selectedWordbook == null) {
      _showSnackbar('학습할 단어장을 선택해주세요.');
      return;
    }

    List<Word> wordsForSession;
    if (srsOnly) {
      wordsForSession = _wordbookManager.getWordsForReview();
      if (wordsForSession.isEmpty) {
        _showSnackbar('오늘 복습할 단어가 없습니다!');
        return;
      }
    } else {
      wordsForSession = _allWords;
      if (wordsForSession.isEmpty) {
        _showSnackbar('단어장에 학습할 단어가 없습니다.');
        return;
      }
    }

    setState(() {
      _sessionWords = List.from(wordsForSession)..shuffle();
      _sessionType = srsOnly ? FlashcardSessionType.review : FlashcardSessionType.allWords;
      _currentCardIndex = 0;
      _sessionActive = true;
      _updatedWordsInSession.clear();
    });
  }

  void _startNewWordSession() {
    if (_selectedWordbook == null) {
      _showSnackbar('학습할 단어장을 선택해주세요.');
      return;
    }

    final newWords =
        (List<Word>.from(_allWords.where(_srsService.isNewWord))..shuffle())
            .take(_recommendedNewWordSessionCount)
            .toList();
    if (newWords.isEmpty) {
      _showSnackbar('새로 학습할 단어가 없습니다.');
      return;
    }

    setState(() {
      _sessionWords = List.from(newWords)..shuffle();
      _sessionType = FlashcardSessionType.newWords;
      _currentCardIndex = 0;
      _sessionActive = true;
      _updatedWordsInSession.clear();
    });
  }

  void _onSessionEnd() {
    _saveUpdatedSrsData().then((_) {
      if (!mounted) return;
      final content = _sessionEndContent();
      showDialog<void>(
        context: context,
        builder:
            (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: _buildSessionEndDialog(dialogContext, content),
            ),
      );
    });
  }

  _SessionEndContent _sessionEndContent() {
    switch (_sessionType) {
      case FlashcardSessionType.review:
        final hasNewWords = _allWords.any(_srsService.isNewWord);
        final batchSize = _recommendedNewWordSessionCount;
        return _SessionEndContent(
          title: '오늘 복습 완료',
          message:
              hasNewWords
                  ? '복습 큐를 비웠어요. 새 단어 $batchSize개를 SRS에 넣어볼까요?'
                  : '좋아요. 오늘 기억해야 할 단어를 다시 붙잡았습니다.',
          primaryLabel: hasNewWords ? '새 단어 $batchSize개' : '다시 복습',
          secondaryLabel: '완료',
          onPrimary: hasNewWords ? _startNewWordSession : _restartCurrentSession,
          onSecondary: _finishSession,
        );
      case FlashcardSessionType.newWords:
        return _SessionEndContent(
          title: '새 단어 학습 완료',
          message: '새 단어가 SRS 일정에 들어갔어요. 짧은 테스트로 떠올릴 수 있는지 확인해볼까요?',
          primaryLabel: '퀴즈 시작',
          secondaryLabel: '완료',
          onPrimary: _goToQuiz,
          onSecondary: _finishSession,
        );
      case FlashcardSessionType.allWords:
        return _SessionEndContent(
          title: '카드 학습 완료',
          message: '전체 카드 학습을 마쳤어요. 기억이 흔들리는 단어는 테스트로 한 번 더 확인해보세요.',
          primaryLabel: '퀴즈 시작',
          secondaryLabel: '다시 학습',
          onPrimary: _goToQuiz,
          onSecondary: _restartCurrentSession,
        );
    }
  }

  void _finishSession() {
    if (!mounted) return;
    setState(() => _sessionActive = false);
  }

  void _restartCurrentSession() {
    if (!mounted) return;
    setState(() {
      _sessionWords.shuffle();
      _currentCardIndex = 0;
      _swiperController.moveTo(0);
      _updatedWordsInSession.clear();
    });
  }

  void _goToQuiz() {
    if (!mounted) return;
    setState(() => _sessionActive = false);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QuizScreen(initialMode: QuizMode.spelling)),
    );
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
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
    final settings = context.watch<FlashcardSettingsProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('플래시카드 학습 준비')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WordbookSelectionButton(
              selectedWordbook: _selectedWordbook,
              onWordbookSelected: _onWordbookSelected,
              wordCount: _selectedWordbook != null ? _allWords.length : 0,
            ),
            const SizedBox(height: 18),
            GlassmorphicCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          CupertinoIcons.sparkles,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '오늘의 카드 루틴',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '단어를 빠르게 넘기며 기억 강도를 조정하고, 바로 다음 퀴즈 흐름으로 이어집니다.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHeaderMetric(
                          theme,
                          '전체',
                          '${_allWords.length}개',
                          theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHeaderMetric(
                          theme,
                          '새 단어',
                          '${_allWords.where(_srsService.isNewWord).length}개',
                          const Color(0xFF0EA5E9),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildHeaderMetric(
                          theme,
                          '오늘 복습',
                          '${_wordbookManager.getWordsForReview().length}개',
                          Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('학습 설정', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            GlassmorphicCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  RadioListTile<FlashcardFrontType>(
                    title: const Text('단어 먼저 보기'),
                    subtitle: const Text('발음과 형태를 먼저 익힌 뒤 뜻을 확인합니다.'),
                    value: FlashcardFrontType.word,
                    groupValue: settings.frontType,
                    onChanged: (value) => settings.setFrontType(value!),
                  ),
                  RadioListTile<FlashcardFrontType>(
                    title: const Text('뜻 먼저 보기'),
                    subtitle: const Text('뜻을 보고 단어를 떠올리는 회상 중심 방식입니다.'),
                    value: FlashcardFrontType.meaning,
                    groupValue: settings.frontType,
                    onChanged: (value) => settings.setFrontType(value!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _buildLaunchCard(
              theme: theme,
              accentColor: theme.colorScheme.primary,
              title: '전체 카드 루틴',
              description: '단어장을 넓게 훑으며 전체 기억 강도를 다시 확인합니다.',
              cta: '전체 단어 학습',
              onTap: () => _startSession(srsOnly: false),
            ),
            const SizedBox(height: 12),
            _buildLaunchCard(
              theme: theme,
              accentColor: const Color(0xFF0EA5E9),
              title: '새 단어 $_recommendedNewWordSessionCount개',
              description: '아직 SRS 일정에 들어가지 않은 단어를 첫 학습 카드로 올립니다. 완료 후 다음 복습 일정이 생깁니다.',
              cta: '새 단어 $_recommendedNewWordSessionCount개 학습',
              onTap: _startNewWordSession,
            ),
            const SizedBox(height: 12),
            _buildLaunchCard(
              theme: theme,
              accentColor: Colors.deepOrange,
              title: '오늘 복습 카드',
              description: '복습 날짜가 온 단어를 먼저 정리해 오늘 루틴의 중심을 잡습니다.',
              cta: 'SRS 학습 시작',
              onTap: () => _startSession(srsOnly: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashcardSession() {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_selectedWordbook?.name ?? '플래시카드'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _sessionActive = false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _buildSessionHeader(theme),
            ),
            Expanded(
              child:
                  _sessionWords.isEmpty
                      ? const Center(child: Text("학습할 단어가 없습니다."))
                      : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                        child: Column(
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Positioned.fill(child: _buildDeckPreview(theme)),
                                  CardSwiper(
                                    controller: _swiperController,
                                    cardsCount: _sessionWords.length,
                                    onSwipe: _onSwipe,
                                    onEnd: _onSessionEnd,
                                    padding: const EdgeInsets.all(8.0),
                                    backCardOffset: const Offset(0, 16),
                                    numberOfCardsDisplayed: min(3, _sessionWords.length),
                                    allowedSwipeDirection: AllowedSwipeDirection.symmetric(horizontal: true),
                                    cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                                      final word = _sessionWords[index];
                                      final settings = context.read<FlashcardSettingsProvider>();
                                      final bool showWordFirst =
                                          settings.frontType == FlashcardFrontType.word;

                                      Color overlayColor = Colors.transparent;
                                      if (percentThresholdX != 0) {
                                        final opacity = min(percentThresholdX.abs() / 100, 0.22);
                                        overlayColor =
                                            percentThresholdX > 0
                                                ? const Color(0xFF0EA5E9).withValues(alpha: opacity)
                                                : Colors.deepOrange.withValues(alpha: opacity);
                                      }

                                      final frontWidget = _buildCardSurface(
                                        context: context,
                                        word: word,
                                        isWordSide: showWordFirst,
                                        overlayColor: overlayColor,
                                      );

                                      final backWidget = _buildCardSurface(
                                        context: context,
                                        word: word,
                                        isWordSide: !showWordFirst,
                                        overlayColor: overlayColor,
                                      );

                                      return FlipCard(
                                        key: ValueKey(word.id),
                                        front: frontWidget,
                                        back: backWidget,
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildSessionControls(theme),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionHeader(ThemeData theme) {
    final totalCount = _sessionWords.length;
    final completedCount = totalCount == 0 ? 0 : _currentCardIndex.clamp(0, totalCount);
    final remainingCount = max(totalCount - completedCount, 0);
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    final accentColor = switch (_sessionType) {
      FlashcardSessionType.review => Colors.deepOrange,
      FlashcardSessionType.newWords => const Color(0xFF0EA5E9),
      FlashcardSessionType.allWords => theme.colorScheme.primary,
    };
    final title = switch (_sessionType) {
      FlashcardSessionType.review => '오늘 복습 카드',
      FlashcardSessionType.newWords => '새 단어 ${_sessionWords.length}개',
      FlashcardSessionType.allWords => '전체 카드 루틴',
    };
    final subtitle = switch (_sessionType) {
      FlashcardSessionType.review => '오늘 다시 봐야 할 단어를 먼저 굳히는 단계입니다.',
      FlashcardSessionType.newWords => '새 단어를 SRS 흐름에 올려두는 짧은 진입 단계입니다.',
      FlashcardSessionType.allWords => '전체 단어를 넓게 훑으며 기억 강도를 다시 확인합니다.',
    };

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(CupertinoIcons.layers_alt_fill, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: accentColor,
              backgroundColor: accentColor.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildHeaderMetric(theme, '진행', '$completedCount / $totalCount', accentColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildHeaderMetric(theme, '남음', '$remainingCount개', accentColor)),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeaderMetric(
                  theme,
                  '단계',
                  _sessionType == FlashcardSessionType.newWords ? '진입' : '복습',
                  accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderMetric(ThemeData theme, String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckPreview(ThemeData theme) {
    if (_sessionWords.length <= 1) {
      return const SizedBox.shrink();
    }

    final previews = <Widget>[];
    for (var depth = 2; depth >= 1; depth--) {
      final previewIndex = _currentCardIndex + depth;
      if (previewIndex >= _sessionWords.length) {
        continue;
      }
      final previewWord = _sessionWords[previewIndex];
      final accentColor = depth == 1 ? const Color(0xFF0EA5E9) : theme.colorScheme.primary;
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
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors:
                        theme.brightness == Brightness.dark
                            ? [
                              theme.colorScheme.surface.withValues(alpha: 0.94),
                              theme.colorScheme.surface.withValues(alpha: 0.88),
                            ]
                            : [
                              Colors.white.withValues(alpha: 0.95),
                              const Color(0xFFF4FAF7).withValues(alpha: 0.92),
                            ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: accentColor.withValues(alpha: 0.14)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${previewIndex + 1} / ${_sessionWords.length}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        previewWord.word,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        previewWord.meaning,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.74),
                        ),
                      ),
                    ],
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

  Widget _buildSessionControls(ThemeData theme) {
    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderRadius: 24,
      child: Row(
        children: [
          Expanded(
            child: _buildControlButton(
              theme: theme,
              icon: CupertinoIcons.xmark,
              label: '몰라요',
              accentColor: Colors.deepOrange,
              onTap: () => _swiperController.swipe(CardSwiperDirection.left),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildControlButton(
              theme: theme,
              icon: CupertinoIcons.arrow_counterclockwise,
              label: '되돌리기',
              accentColor: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              onTap: () => _swiperController.undo(),
              filled: false,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _buildControlButton(
              theme: theme,
              icon: CupertinoIcons.check_mark,
              label: '알아요',
              accentColor: const Color(0xFF0EA5E9),
              onTap: () => _swiperController.swipe(CardSwiperDirection.right),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color accentColor,
    required VoidCallback onTap,
    bool filled = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: filled ? accentColor.withValues(alpha: 0.10) : theme.colorScheme.surface.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: filled ? accentColor.withValues(alpha: 0.18) : theme.colorScheme.outline.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: accentColor, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: filled ? accentColor : theme.textTheme.bodyMedium?.color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLaunchCard({
    required ThemeData theme,
    required Color accentColor,
    required String title,
    required String description,
    required String cta,
    required VoidCallback onTap,
  }) {
    return GlassmorphicCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(CupertinoIcons.play_fill, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(description, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            cta,
            style: theme.textTheme.labelLarge?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionEndDialog(BuildContext dialogContext, _SessionEndContent content) {
    final theme = Theme.of(dialogContext);
    final accentColor = switch (_sessionType) {
      FlashcardSessionType.review => Colors.deepOrange,
      FlashcardSessionType.newWords => const Color(0xFF0EA5E9),
      FlashcardSessionType.allWords => theme.colorScheme.primary,
    };

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      borderRadius: 28,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(CupertinoIcons.sparkles, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  content.title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(content.message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildRouteStep(
                  theme,
                  accentColor,
                  '1',
                  _sessionType == FlashcardSessionType.newWords ? '카드 진입 완료' : '카드 루틴 완료',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildRouteStep(
                  theme,
                  accentColor,
                  '2',
                  content.primaryLabel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    content.onSecondary();
                  },
                  child: Text(content.secondaryLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    content.onPrimary();
                  },
                  child: Text(content.primaryLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStep(
    ThemeData theme,
    Color accentColor,
    String step,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              step,
              style: theme.textTheme.labelMedium?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSurface({
    required BuildContext context,
    required Word word,
    required bool isWordSide,
    required Color overlayColor,
  }) {
    final theme = Theme.of(context);
    final accentColor = isWordSide ? theme.colorScheme.primary : const Color(0xFF0EA5E9);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.08),
            blurRadius: 26,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors:
                      theme.brightness == Brightness.dark
                          ? [
                            theme.colorScheme.surface,
                            theme.colorScheme.surface.withValues(alpha: 0.92),
                          ]
                          : [
                            Colors.white,
                            const Color(0xFFF6FBF8),
                          ],
                ),
                border: Border.all(color: accentColor.withValues(alpha: 0.14)),
                borderRadius: BorderRadius.circular(28),
              ),
              child: _buildCardSide(word: word, isWordSide: isWordSide),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: accentColor.withValues(alpha: 0.16)),
              ),
              child: Text(
                isWordSide ? '단어' : '뜻',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.35)),
              ),
              child: Text(
                '탭해서 뒤집기',
                style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          if (overlayColor != Colors.transparent)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    color: overlayColor,
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ▼▼▼ [수정] 전체 위젯 수정
  Widget _buildCardSide({required Word word, required bool isWordSide}) {
    String mainText = isWordSide ? word.word : word.meaning;
    String? exampleText = isWordSide ? word.exampleSentence : null;
    String? translationText = !isWordSide ? word.exampleSentenceTranslation : null;
    final theme = Theme.of(context);

    const footerHeight = 50.0;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mainText,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.22,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isWordSide ? '먼저 발음과 형태를 익히고, 뒤집어서 뜻을 확인하세요.' : '뜻을 보고 단어를 떠올린 뒤 다시 뒤집어 확인하세요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.72),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (exampleText != null && exampleText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 22.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '"$exampleText"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  if (translationText != null && translationText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14.0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          '"$translationText"',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.secondary,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: footerHeight,
            child:
                isWordSide
                    ? OutlinedButton.icon(
                      onPressed: () => _ttsService.speak(word.word),
                      icon: const Icon(CupertinoIcons.speaker_2_fill, size: 18),
                      label: const Text('발음 듣기'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
