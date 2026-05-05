// lib/screens/home_screen.dart

import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../themes/app_theme.dart';
import '../widgets/learning_mode_card.dart';
import 'ai_quiz_setup_screen.dart';
import 'app_settings_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'srs_status_screen.dart';
import 'wordbook_management_screen.dart';
import 'ai_grammar_quiz_setup_screen.dart'; // ▼▼▼ [추가] ▼▼▼

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _HomePalette.of(theme);
    final wordbookManager = context.watch<WordbookManager>();
    final words = context.watch<WordListNotifier>().words;
    final srsService = SrsService();
    final dailyPlan = srsService.buildDailyPlan(words);
    final recommendation = srsService.recommendationForPlan(dailyPlan);
    final reviewWords = dailyPlan.dueWords;
    final newWordSessionCount = dailyPlan.suggestedNewWordBatchSize;
    final bool canStartReviewQuiz = reviewWords.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: palette.surface.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.98 : 0.94,
              ),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              expandedHeight: 96,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surface.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.98 : 0.94,
                    ),
                    border: Border(
                      bottom: BorderSide(
                        color: palette.outline.withValues(alpha: 0.42),
                      ),
                    ),
                  ),
                ),
                titlePadding: const EdgeInsets.only(left: 20, bottom: 18),
                title: Text(
                  'Memorize Me',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: palette.heading,
                  ),
                ),
              ),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: palette.iconButtonSurface,
                    shape: BoxShape.circle,
                    border: Border.all(color: palette.outline),
                  ),
                  child: IconButton(
                    icon: Icon(CupertinoIcons.settings, color: palette.heading),
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const AppSettingsScreen())),
                    tooltip: '앱 설정',
                  ),
                ),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: _WordbookStatusCarousel(
                  wordbooks: wordbookManager.wordbooks,
                  activeWordbook: wordbookManager.activeWordbook,
                  manager: wordbookManager,
                  statsRevision: wordbookManager.statsRevision,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: _RoutineFocusCard(
                  recommendation: recommendation,
                  onTap: () {
                    switch (recommendation.focus) {
                      case LearningFocus.review:
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const QuizScreen(initialMode: QuizMode.reviewSpelling),
                          ),
                        );
                        break;
                      case LearningFocus.newWords:
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => const FlashcardScreen(
                                  initialMode: FlashcardLaunchMode.newWords,
                                ),
                          ),
                        );
                        break;
                      case LearningFocus.quiz:
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const QuizScreen()));
                        break;
                      case LearningFocus.rest:
                        Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const FlashcardScreen()));
                        break;
                    }
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '오늘의 루틴',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: palette.heading,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.list(
                children: [
                  _RoutineStepCard(
                    step: '1',
                    title: '오늘 복습',
                    subtitle:
                        dailyPlan.hasReview
                            ? '${dailyPlan.dueWords.length}개 단어를 잊기 전에 다시 봅니다'
                            : '기한이 온 복습 단어가 없습니다',
                    icon: CupertinoIcons.flame_fill,
                    color: AppTheme.accentCoral,
                    actionLabel: dailyPlan.hasReview ? '기억 고정하기' : '완료',
                    enabled: dailyPlan.hasReview,
                    onTap:
                        dailyPlan.hasReview
                            ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) =>
                                        const QuizScreen(initialMode: QuizMode.reviewSpelling),
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(height: 12),
                  _RoutineStepCard(
                    step: '2',
                    title: '새 단어 익히기',
                    subtitle:
                        dailyPlan.hasNewWords
                            ? '새 단어 ${dailyPlan.newWords.length}개 중 ${newWordSessionCount}개부터 시작합니다'
                            : '새로 SRS에 넣을 단어가 없습니다',
                    icon: CupertinoIcons.plus_circle_fill,
                    color: const Color(0xFF0EA5E9),
                    actionLabel: dailyPlan.hasNewWords ? '$newWordSessionCount개 익히기' : '완료',
                    enabled: dailyPlan.hasNewWords,
                    onTap:
                        dailyPlan.hasNewWords
                            ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => const FlashcardScreen(
                                      initialMode: FlashcardLaunchMode.newWords,
                                    ),
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(height: 12),
                  _RoutineStepCard(
                    step: '3',
                    title: '짧은 테스트',
                    subtitle:
                        dailyPlan.canTakeQuiz
                            ? '오늘 기억한 단어를 떠올릴 수 있는지 확인합니다'
                            : '복습이나 학습 중인 단어가 생기면 추천됩니다',
                    icon: CupertinoIcons.pencil_outline,
                    color: const Color(0xFF4F46E5),
                    actionLabel: dailyPlan.canTakeQuiz ? '퀴즈 시작' : '대기',
                    enabled: dailyPlan.canTakeQuiz,
                    onTap:
                        dailyPlan.canTakeQuiz
                            ? () => Navigator.of(
                              context,
                            ).push(MaterialPageRoute(builder: (_) => const QuizScreen()))
                            : null,
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  '학습 바로가기',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: palette.heading,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  LearningModeCard(
                    heroTag: 'flashcards-hero',
                    title: '플래시카드',
                    subtitle: '빠르게 넘기며 복습',
                    icon: CupertinoIcons.layers_alt_fill,
                    accentColor: AppTheme.primaryGreen,
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FlashcardScreen()),
                        ),
                  ),
                  LearningModeCard(
                    heroTag: 'quiz-hero',
                    title: '셀프 테스트',
                    subtitle: '직접 써보며 확인',
                    icon: CupertinoIcons.pencil_outline,
                    accentColor: const Color(0xFF4F46E5),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const QuizScreen())),
                  ),
                  LearningModeCard(
                    heroTag: 'wordbook-hero',
                    title: '내 단어장',
                    subtitle: '단어 추가와 정리',
                    icon: CupertinoIcons.book_fill,
                    accentColor: const Color(0xFF0EA5E9),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
                        ),
                  ),
                  Opacity(
                    opacity: canStartReviewQuiz ? 1.0 : 0.5,
                    child: LearningModeCard(
                      heroTag: 'review_quiz_hero',
                      title: '오답 복습',
                      subtitle: '${reviewWords.length}개 다시 보기',
                      icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
                      accentColor: AppTheme.accentCoral,
                      onTap:
                          canStartReviewQuiz
                              ? () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          const QuizScreen(initialMode: QuizMode.reviewSpelling),
                                ),
                              )
                              : null,
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Text(
                  'AI 학습',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: palette.heading,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverList.list(
                children: [
                  _AiActionTile(
                    title: 'AI 퀴즈',
                    subtitle: '선택한 단어로 실전 문제를 생성합니다',
                    icon: CupertinoIcons.sparkles,
                    color: const Color(0xFF7C3AED),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const AiQuizSetupScreen())),
                  ),
                  const SizedBox(height: 12),
                  _AiActionTile(
                    title: 'AI 문법',
                    subtitle: '문법 범위와 난이도를 골라 문제를 만듭니다',
                    icon: CupertinoIcons.text_cursor,
                    color: const Color(0xFFDB2777),
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AiGrammarQuizSetupScreen()),
                        ),
                  ),
                ],
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
          ],
        ),
      ),
    );
  }
}

class _HomePalette {
  final Color heading;
  final Color muted;
  final Color surface;
  final Color surfaceVariant;
  final Color outline;
  final Color shadow;
  final Color iconButtonSurface;
  final Color statusFront;
  final Color statusBackPrimary;
  final Color statusBackSecondary;
  final Color statusChip;
  final Color statusStat;
  final Color disabledButton;

  const _HomePalette({
    required this.heading,
    required this.muted,
    required this.surface,
    required this.surfaceVariant,
    required this.outline,
    required this.shadow,
    required this.iconButtonSurface,
    required this.statusFront,
    required this.statusBackPrimary,
    required this.statusBackSecondary,
    required this.statusChip,
    required this.statusStat,
    required this.disabledButton,
  });

  factory _HomePalette.of(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isVision = theme.primaryColor == const Color(0xFF6C6048);

    if (isDark) {
      return _HomePalette(
        heading: scheme.onSurface,
        muted: scheme.onSurfaceVariant,
        surface: scheme.surface,
        surfaceVariant: scheme.surfaceContainerHighest,
        outline: scheme.outline,
        shadow: Colors.black,
        iconButtonSurface: scheme.surfaceContainerHighest,
        statusFront: const Color(0xFF17201E),
        statusBackPrimary: const Color(0xFF263733),
        statusBackSecondary: const Color(0xFF2F2C3A),
        statusChip: const Color(0xFF22302D),
        statusStat: const Color(0xFF22302D),
        disabledButton: const Color(0xFF2A3A36),
      );
    }

    if (isVision) {
      return _HomePalette(
        heading: scheme.onSurface,
        muted: scheme.onSurfaceVariant,
        surface: scheme.surface,
        surfaceVariant: scheme.surfaceContainerHighest,
        outline: scheme.outline,
        shadow: const Color(0xFF4A3821),
        iconButtonSurface: const Color(0xFFFFF9EC),
        statusFront: const Color(0xFFFFF9EC),
        statusBackPrimary: const Color(0xFFF1E4CF),
        statusBackSecondary: const Color(0xFFE8D9BF),
        statusChip: const Color(0xFFF1E4CF),
        statusStat: const Color(0xFFF6EBD8),
        disabledButton: const Color(0xFFE9DCC7),
      );
    }

    return _HomePalette(
      heading: scheme.onSurface,
      muted: scheme.onSurfaceVariant,
      surface: scheme.surface,
      surfaceVariant: scheme.surfaceContainerHighest,
      outline: scheme.outline.withValues(alpha: 0.46),
      shadow: scheme.shadow,
      iconButtonSurface: Colors.white.withValues(alpha: 0.82),
      statusFront: const Color(0xFFFFFCF6),
      statusBackPrimary: const Color(0xFFF1E8DA),
      statusBackSecondary: const Color(0xFFE7EEE7),
      statusChip: const Color(0xFFE7EEE7),
      statusStat: const Color(0xFFF4EFE7),
      disabledButton: const Color(0xFFE2E8E5),
    );
  }
}

class _WordbookStatusCarousel extends StatefulWidget {
  final List<Wordbook> wordbooks;
  final Wordbook? activeWordbook;
  final WordbookManager manager;
  final int statsRevision;

  const _WordbookStatusCarousel({
    required this.wordbooks,
    required this.activeWordbook,
    required this.manager,
    required this.statsRevision,
  });

  @override
  State<_WordbookStatusCarousel> createState() => _WordbookStatusCarouselState();
}

class _WordbookStatusCarouselState extends State<_WordbookStatusCarousel> {
  final SrsService _srsService = SrsService();
  final Map<Object, Future<List<Word>>> _wordFutures = {};
  Timer? _activationTimer;
  double _dragOffset = 0;
  bool _isDragging = false;
  bool _isAnimatingAway = false;
  int _visibleIndex = 0;

  @override
  void initState() {
    super.initState();
    _resetController();
  }

  @override
  void didUpdateWidget(covariant _WordbookStatusCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLength = oldWidget.wordbooks.length;
    final newLength = widget.wordbooks.length;
    final oldKeys = oldWidget.wordbooks.map(_wordbookKey).toSet();
    final newKeys = widget.wordbooks.map(_wordbookKey).toSet();
    if (oldLength != newLength ||
        oldKeys.length != newKeys.length ||
        !oldKeys.containsAll(newKeys) ||
        oldWidget.statsRevision != widget.statsRevision) {
      _wordFutures.clear();
    }
    final visibleWordbook =
        widget.wordbooks.isEmpty ? null : widget.wordbooks[_visibleIndex % widget.wordbooks.length];
    final externalActiveChanged =
        oldWidget.activeWordbook?.id != widget.activeWordbook?.id &&
        widget.activeWordbook?.id != visibleWordbook?.id;
    if (oldLength != newLength || externalActiveChanged) {
      _resetController();
    }
  }

  @override
  void dispose() {
    _activationTimer?.cancel();
    super.dispose();
  }

  Object _wordbookKey(Wordbook wordbook) {
    return wordbook.id ?? wordbook.dbFileName;
  }

  Future<List<Word>> _wordsFutureFor(Wordbook wordbook) {
    return _wordFutures.putIfAbsent(
      _wordbookKey(wordbook),
      () => widget.manager.getAllWordsFrom(wordbook),
    );
  }

  void _activateWordbookAfterSettled(Wordbook wordbook) {
    _activationTimer?.cancel();
    _activationTimer = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      widget.manager.setActiveWordbook(wordbook);
    });
  }

  void _resetController() {
    final length = widget.wordbooks.length;
    if (length == 0) {
      _visibleIndex = 0;
      _dragOffset = 0;
      _isDragging = false;
      _isAnimatingAway = false;
      return;
    }

    final activeIndex = widget.activeWordbook == null
        ? 0
        : widget.wordbooks.indexWhere((wordbook) => wordbook.id == widget.activeWordbook!.id);
    _visibleIndex = activeIndex < 0 ? 0 : activeIndex;
    _dragOffset = 0;
    _isDragging = false;
    _isAnimatingAway = false;
  }

  int _wrappedIndex(int index) {
    final length = widget.wordbooks.length;
    return ((index % length) + length) % length;
  }

  void _showWordbookAt(int index) {
    if (widget.wordbooks.isEmpty) return;
    final nextIndex = _wrappedIndex(index);
    setState(() {
      _visibleIndex = nextIndex;
      _dragOffset = 0;
      _isDragging = false;
      _isAnimatingAway = false;
    });
    _activateWordbookAfterSettled(widget.wordbooks[nextIndex]);
  }

  void _animateToWordbook(int index, double exitOffset) {
    if (_isAnimatingAway) return;
    setState(() {
      _isDragging = false;
      _isAnimatingAway = true;
      _dragOffset = exitOffset;
    });
    Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _showWordbookAt(index);
    });
  }

  void _handleDragEnd(DragEndDetails details, double width) {
    if (widget.wordbooks.length < 2) {
      setState(() => _dragOffset = 0);
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    final threshold = width * 0.22;
    if (_dragOffset <= -threshold || velocity < -650) {
      _animateToWordbook(_visibleIndex + 1, -width * 1.04);
    } else if (_dragOffset >= threshold || velocity > 650) {
      _animateToWordbook(_visibleIndex - 1, width * 1.04);
    } else {
      setState(() {
        _isDragging = false;
        _dragOffset = 0;
      });
    }
  }

  Widget _buildStatusPanel(
    BuildContext context,
    Wordbook wordbook,
    int index, {
    bool compact = false,
  }) {
    return FutureBuilder<List<Word>>(
      future: _wordsFutureFor(wordbook),
      builder: (context, snapshot) {
        final words = snapshot.data ?? const <Word>[];
        final plan = _srsService.buildDailyPlan(words);
        final canReview = plan.dueWords.isNotEmpty;
        return _TodayPanel(
          activeWordbookName: wordbook.name,
          wordCount: words.length,
          reviewCount: plan.dueWords.length,
          newWordCount: plan.newWords.length,
          canStartReviewQuiz: canReview,
          positionLabel: '${index + 1} / ${widget.wordbooks.length}',
          compact: compact,
          onReviewTap:
              canReview
                  ? () {
                    widget.manager.setActiveWordbook(wordbook).then((_) {
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => const QuizScreen(
                                initialMode: QuizMode.reviewSpelling,
                              ),
                        ),
                      );
                    });
                  }
                  : null,
          onStatusTap: () {
            widget.manager.setActiveWordbook(wordbook).then((_) {
              if (!context.mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SrsStatusScreen()),
              );
            });
          },
        );
      },
    );
  }

  Widget _buildBackCard(BuildContext context, Wordbook wordbook, int index, int depth) {
    final theme = Theme.of(context);
    final palette = _HomePalette.of(theme);
    final colors = [palette.statusBackPrimary, palette.statusBackSecondary];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: colors[(depth - 1) % colors.length],
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.outline, width: 1.2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: palette.iconButtonSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              depth == 1 ? CupertinoIcons.book_fill : CupertinoIcons.layers_alt_fill,
              color: depth == 1 ? AppTheme.primaryGreen : AppTheme.accentCoral,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  wordbook.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: palette.heading.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${index + 1} / ${widget.wordbooks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeckLayer(BuildContext context, int depth, double width) {
    final direction = _dragOffset > 0 ? -1 : 1;
    final index = depth == 0 ? _visibleIndex : _wrappedIndex(_visibleIndex + (depth * direction));
    final wordbook = widget.wordbooks[index];
    final isFront = depth == 0;
    final isPreviewStatus = depth == 1;
    final leftInset = depth * 10.0;
    final rightInset = depth == 0 ? 24.0 : (14.0 - ((depth - 1) * 2.0)).clamp(6.0, 14.0).toDouble();
    final topInset = 10.0 + ((4 - depth) * 14.0);
    final height = isFront
        ? 320.0
        : (isPreviewStatus ? 286.0 : (272.0 - ((depth - 2) * 18.0)).clamp(220.0, 272.0).toDouble());
    final opacity = isFront ? 1.0 : (1.0 - (depth * 0.07)).clamp(0.58, 0.94).toDouble();
    final scale = isFront ? 1.0 : (isPreviewStatus ? 0.985 : 1.0);
    final rotation = isFront ? (_dragOffset / width).clamp(-0.045, 0.045).toDouble() : 0.0;
    final slideOffset = isFront ? Offset(_dragOffset / width, 0) : Offset.zero;
    final motionDuration =
        _isDragging ? Duration.zero : const Duration(milliseconds: 280);

    Widget card = (isFront || isPreviewStatus)
        ? _buildStatusPanel(context, wordbook, index, compact: isPreviewStatus)
        : _buildBackCard(context, wordbook, index, depth);
    if (!isFront) {
      card = IgnorePointer(child: card);
    }

    return AnimatedPositioned(
      key: ValueKey('wordbook-card-${_wordbookKey(wordbook)}-$depth'),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutQuart,
      top: topInset,
      left: leftInset,
      right: rightInset,
      height: height,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: opacity,
        child: AnimatedSlide(
          duration: motionDuration,
          curve: Curves.easeOutQuart,
          offset: slideOffset,
          child: AnimatedRotation(
            duration: motionDuration,
            curve: Curves.easeOutQuart,
            turns: rotation / (2 * 3.141592653589793),
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: card,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wordbooks.isEmpty) {
      return _TodayPanel(
        activeWordbookName: '단어장을 불러와 주세요',
        wordCount: 0,
        reviewCount: 0,
        newWordCount: 0,
        canStartReviewQuiz: false,
        positionLabel: '0 / 0',
        onReviewTap: null,
        onStatusTap:
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SrsStatusScreen())),
      );
    }

    final visibleCardCount = widget.wordbooks.length < 5 ? widget.wordbooks.length : 5;

    return Column(
      children: [
        SizedBox(
          height: 430,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragUpdate:
                    widget.wordbooks.length > 1
                        ? (details) {
                          if (_isAnimatingAway) return;
                          setState(() {
                            _isDragging = true;
                            _dragOffset = (_dragOffset + details.delta.dx).clamp(
                              -constraints.maxWidth * 0.42,
                              constraints.maxWidth * 0.42,
                            ).toDouble();
                          });
                        }
                        : null,
                onHorizontalDragEnd:
                    widget.wordbooks.length > 1
                        ? (details) => _handleDragEnd(details, constraints.maxWidth)
                        : null,
                onHorizontalDragCancel:
                    () => setState(() {
                      _isDragging = false;
                      _dragOffset = 0;
                    }),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var depth = visibleCardCount - 1; depth >= 0; depth--)
                      _buildDeckLayer(context, depth, constraints.maxWidth),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RoutineFocusCard extends StatelessWidget {
  final LearningFocusRecommendation recommendation;
  final VoidCallback onTap;

  const _RoutineFocusCard({required this.recommendation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _HomePalette.of(theme);
    final icon =
        recommendation.focus == LearningFocus.review
            ? CupertinoIcons.flame_fill
            : recommendation.focus == LearningFocus.newWords
            ? CupertinoIcons.plus_circle_fill
            : recommendation.focus == LearningFocus.quiz
            ? CupertinoIcons.pencil_outline
            : CupertinoIcons.layers_alt_fill;
    final accent =
        recommendation.focus == LearningFocus.review
            ? AppTheme.accentCoral
            : recommendation.focus == LearningFocus.newWords
            ? const Color(0xFF0EA5E9)
            : recommendation.focus == LearningFocus.quiz
            ? const Color(0xFF4F46E5)
            : AppTheme.primaryGreen;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: palette.outline),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: theme.brightness == Brightness.dark ? 0.22 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: accent, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recommendation.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: palette.heading,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendation.description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                recommendation.actionLabel,
                style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  final String activeWordbookName;
  final int wordCount;
  final int reviewCount;
  final int newWordCount;
  final bool canStartReviewQuiz;
  final String positionLabel;
  final bool compact;
  final VoidCallback? onReviewTap;
  final VoidCallback onStatusTap;

  const _TodayPanel({
    required this.activeWordbookName,
    required this.wordCount,
    required this.reviewCount,
    required this.newWordCount,
    required this.canStartReviewQuiz,
    required this.positionLabel,
    this.compact = false,
    required this.onReviewTap,
    required this.onStatusTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _HomePalette.of(theme);
    final title = canStartReviewQuiz
        ? '오늘 기억을 붙잡을 시간이에요'
        : newWordCount > 0
            ? '복습은 완료, 새 단어를 열어볼까요?'
            : '오늘 복습은 깨끗하게 비었어요';
    final actionHeight = compact ? 40.0 : 46.0;

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: palette.statusFront,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: palette.outline, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: theme.brightness == Brightness.dark ? 0.30 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activeWordbookName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.statusChip,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  positionLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: onStatusTap,
                tooltip: '학습 현황',
                icon: const Icon(CupertinoIcons.chart_bar_fill),
                style: IconButton.styleFrom(
                  backgroundColor: palette.surfaceVariant,
                  foregroundColor: AppTheme.accentCoral,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            title,
            maxLines: compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: (compact ? theme.textTheme.titleMedium : theme.textTheme.titleLarge)?.copyWith(
              color: palette.heading,
              fontWeight: FontWeight.w900,
              height: compact ? 1.18 : 1.2,
            ),
          ),
          SizedBox(height: compact ? 10 : 14),
          Row(
            children: [
              _StatPill(label: '전체 단어', value: '$wordCount'),
              const SizedBox(width: 8),
              _StatPill(label: '오늘 복습', value: '$reviewCount'),
              if (!compact) ...[
                const SizedBox(width: 8),
                _StatPill(label: '새 단어', value: '$newWordCount'),
              ],
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          if (compact)
            FilledButton.icon(
              onPressed: onReviewTap,
              icon: const Icon(CupertinoIcons.play_fill, size: 16),
              label: Text(
                canStartReviewQuiz ? '복습 시작' : '복습 완료',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    canStartReviewQuiz ? theme.colorScheme.secondary : palette.disabledButton,
                foregroundColor:
                    canStartReviewQuiz ? theme.colorScheme.onSecondary : palette.muted,
                minimumSize: Size.fromHeight(actionHeight),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onReviewTap,
                    icon: const Icon(CupertinoIcons.play_fill, size: 18),
                    label: Text(
                      canStartReviewQuiz ? '기억 고정하기' : '복습 완료',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor:
                          canStartReviewQuiz
                              ? theme.colorScheme.secondary
                              : palette.disabledButton,
                      foregroundColor:
                          canStartReviewQuiz
                              ? theme.colorScheme.onSecondary
                              : palette.muted,
                      minimumSize: Size(0, actionHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const FlashcardScreen()),
                        ),
                    icon: const Icon(CupertinoIcons.layers_alt_fill, size: 18),
                    label: const Text(
                      '카드 학습',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.heading,
                      side: BorderSide(color: palette.outline),
                      minimumSize: Size(0, actionHeight),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _HomePalette.of(theme);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: palette.statusStat,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: palette.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                color: palette.heading,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineStepCard extends StatelessWidget {
  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String actionLabel;
  final bool enabled;
  final VoidCallback? onTap;

  const _RoutineStepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.actionLabel,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _HomePalette.of(theme);
    final baseColor =
        theme.brightness == Brightness.dark ? Color.lerp(color, Colors.white, 0.26)! : color;
    final effectiveColor = enabled ? baseColor : palette.muted;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: enabled ? palette.surface : palette.surfaceVariant.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.outline),
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(
                alpha:
                  enabled ? (theme.brightness == Brightness.dark ? 0.22 : 0.06) : 0.02,
              ),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Text(
                step,
                style: TextStyle(color: effectiveColor, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: effectiveColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: palette.heading,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                actionLabel,
                style: TextStyle(color: effectiveColor, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AiActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AiActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _HomePalette.of(theme);
    final effectiveColor =
        theme.brightness == Brightness.dark ? Color.lerp(color, Colors.white, 0.26)! : color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: palette.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: effectiveColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, color: effectiveColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: palette.heading,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(CupertinoIcons.chevron_forward, color: palette.muted, size: 18),
          ],
        ),
      ),
    );
  }
}
