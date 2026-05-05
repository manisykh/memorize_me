import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../themes/app_theme.dart';
import '../widgets/ai_settings_card.dart';
import '../widgets/glassmorphic_card.dart';
import 'ai_grammar_quiz_setup_screen.dart';
import 'ai_quiz_setup_screen.dart';
import 'app_settings_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'srs_status_screen.dart';
import 'wordbook_management_screen.dart';

enum _ShellTab { home, decks, review, stats, ai, settings }

class _ShellPalette {
  final Color background;
  final Color topBar;
  final Color iconSurface;
  final Color navBackground;
  final Color navIndicator;
  final Color border;
  final Color brand;
  final Color accent;
  final Color review;
  final Color info;
  final Color success;
  final Color warning;

  const _ShellPalette({
    required this.background,
    required this.topBar,
    required this.iconSurface,
    required this.navBackground,
    required this.navIndicator,
    required this.border,
    required this.brand,
    required this.accent,
    required this.review,
    required this.info,
    required this.success,
    required this.warning,
  });

  factory _ShellPalette.of(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final isVision = theme.primaryColor == const Color(0xFF6C6048);

    if (isDark) {
      return const _ShellPalette(
        background: Color(0xFF0F1517),
        topBar: Color(0xFF11191B),
        iconSurface: Color(0xFF1B2729),
        navBackground: Color(0xFF10181A),
        navIndicator: Color(0xFF203335),
        border: Color(0xFF2A3B3D),
        brand: Color(0xFF82D5C7),
        accent: Color(0xFFE07868),
        review: Color(0xFFE07868),
        info: Color(0xFF86A9D3),
        success: Color(0xFF79BF92),
        warning: Color(0xFFD3A65B),
      );
    }

    if (isVision) {
      return const _ShellPalette(
        background: Color(0xFFF8F2E6),
        topBar: Color(0xFFFEFAF1),
        iconSurface: Color(0xFFEFE7D8),
        navBackground: Color(0xFFFEFAF1),
        navIndicator: Color(0xFFEFE4D2),
        border: Color(0xFFE2D6C2),
        brand: Color(0xFF6C6048),
        accent: Color(0xFF98695A),
        review: Color(0xFFB56557),
        info: Color(0xFF667862),
        success: Color(0xFF5F7657),
        warning: Color(0xFF9A763D),
      );
    }

    return const _ShellPalette(
      background: Color(0xFFF6F7F2),
      topBar: Color(0xFFFBFAF5),
      iconSurface: Color(0xFFEEF1EA),
      navBackground: Color(0xFFFBFAF5),
      navIndicator: Color(0xFFE6F0EA),
      border: Color(0xFFDFE4DA),
      brand: Color(0xFF1F6B5F),
      accent: Color(0xFFD46A5D),
      review: Color(0xFFD46A5D),
      info: Color(0xFF526A86),
      success: Color(0xFF557C63),
      warning: Color(0xFF9A7145),
    );
  }
}

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  final SrsService _srsService = SrsService();
  final Map<Object, Future<_DeckStats>> _deckStatsFutures = {};
  _ShellTab _currentTab = _ShellTab.home;
  int? _cachedStatsRevision;

  Object _wordbookKey(Wordbook wordbook) => wordbook.id ?? wordbook.dbFileName;

  Future<_DeckStats> _statsForWordbook(WordbookManager manager, Wordbook wordbook) {
    return _deckStatsFutures.putIfAbsent(_wordbookKey(wordbook), () async {
      final words = await manager.getAllWordsFrom(wordbook);
      final plan = _srsService.buildDailyPlan(words);
      return _DeckStats(
        totalCount: words.length,
        reviewCount: plan.dueWords.length,
        newCount: plan.newWords.length,
        learningCount: plan.learningWords.length,
        matureCount: plan.matureWords.length,
      );
    });
  }

  void _cycleTheme() {
    final notifier = context.read<ThemeNotifier>();
    final themes = AppThemeType.values;
    final currentIndex = themes.indexOf(notifier.currentTheme);
    final nextTheme = themes[(currentIndex + 1) % themes.length];
    notifier.setTheme(nextTheme);
  }

  void _showProfileSheet(
    BuildContext context,
    ThemeData theme,
    WordbookManager manager,
    DailyLearningPlan dailyPlan,
    GoogleSignInAccount? user,
  ) {
    final palette = _ShellPalette.of(theme);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GlassmorphicCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _UserAvatar(user: user, radius: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.displayName ?? '학습 프로필',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user?.email ??
                                    '단어장 ${manager.wordbooks.length}개 · 오늘 복습 ${dailyPlan.dueWords.length}개',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _MiniMetricCard(
                            label: '새 단어',
                            value: '${dailyPlan.newWords.length}',
                            accentColor: palette.info,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniMetricCard(
                            label: '학습 중',
                            value: '${dailyPlan.learningWords.length}',
                            accentColor: palette.warning,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniMetricCard(
                            label: '안정 기억',
                            value: '${dailyPlan.matureWords.length}',
                            accentColor: palette.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
                          );
                        },
                        icon: const Icon(CupertinoIcons.settings, size: 18),
                        label: const Text('설정 열기'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final palette = _ShellPalette.of(theme);
    final manager = context.watch<WordbookManager>();
    if (_cachedStatsRevision != manager.statsRevision) {
      _deckStatsFutures.clear();
      _cachedStatsRevision = manager.statsRevision;
    }
    final user = context.watch<AuthProvider>().currentUser;
    final words = context.watch<WordListNotifier>().words;
    final dailyPlan = _srsService.buildDailyPlan(words);
    final activeWordbook = manager.activeWordbook;

    return Scaffold(
      backgroundColor:
          theme.scaffoldBackgroundColor == Colors.transparent
              ? Colors.transparent
              : palette.background,
      body: SafeArea(
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.topBar,
                border: Border(bottom: BorderSide(color: palette.border.withValues(alpha: 0.64))),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                child: Row(
                  children: [
                    Tooltip(
                      message: '테마 변경',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _cycleTheme,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: palette.iconSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.border.withValues(alpha: 0.72)),
                          ),
                          child: Icon(
                            CupertinoIcons.eye,
                            color: palette.brand,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Memorize Me',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                              color: palette.brand,
                            ),
                          ),
                          Text(
                            _tabSubtitle(activeWordbook?.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _showProfileSheet(context, theme, manager, dailyPlan, user),
                      child: _UserAvatar(user: user, radius: 20),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _ShellTab.values.indexOf(_currentTab),
                children: [
                  _HomeDashboardTab(
                    dailyPlan: dailyPlan,
                    activeWordbook: activeWordbook,
                    wordbooks: manager.wordbooks,
                    statsForWordbook: (wordbook) => _statsForWordbook(manager, wordbook),
                  ),
                  _DecksTab(
                    activeWordbook: activeWordbook,
                    wordbooks: manager.wordbooks,
                    statsForWordbook: (wordbook) => _statsForWordbook(manager, wordbook),
                  ),
                  _ReviewTab(dailyPlan: dailyPlan),
                  _StatsTab(dailyPlan: dailyPlan, totalWordCount: words.length),
                  const _AiLearningTab(),
                  const AppSettingsScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: palette.navBackground,
        indicatorColor: palette.navIndicator,
        selectedIndex: _ShellTab.values.indexOf(_currentTab),
        height: 72,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected:
            (index) => setState(() => _currentTab = _ShellTab.values[index]),
        destinations: const [
          NavigationDestination(icon: Icon(CupertinoIcons.house), label: '홈'),
          NavigationDestination(icon: Icon(CupertinoIcons.square_stack_3d_down_right), label: '단어장'),
          NavigationDestination(icon: Icon(CupertinoIcons.play_circle), label: '복습'),
          NavigationDestination(icon: Icon(CupertinoIcons.chart_bar), label: '통계'),
          NavigationDestination(icon: Icon(CupertinoIcons.sparkles), label: 'AI 학습'),
          NavigationDestination(icon: Icon(CupertinoIcons.settings), label: '설정'),
        ],
      ),
    );
  }

  String _tabSubtitle(String? activeWordbookName) {
    switch (_currentTab) {
      case _ShellTab.home:
        return activeWordbookName == null ? '오늘의 루틴을 시작해보세요' : '현재 단어장 · $activeWordbookName';
      case _ShellTab.decks:
        return '단어장 흐름과 진행률을 관리하세요';
      case _ShellTab.review:
        return '복습, 테스트, 오답 루틴을 한곳에서';
      case _ShellTab.stats:
        return 'SRS 상태와 학습 추이를 확인하세요';
      case _ShellTab.ai:
        return 'AI 퀴즈와 문법 학습을 한곳에서';
      case _ShellTab.settings:
        return '테마와 학습 환경을 조정하세요';
    }
  }
}

class _UserAvatar extends StatelessWidget {
  final GoogleSignInAccount? user;
  final double radius;

  const _UserAvatar({required this.user, required this.radius});

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));

    if (user != null) {
      return SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: ClipOval(
          child: GoogleUserCircleAvatar(identity: user!),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.iconSurface,
      child: Icon(
        CupertinoIcons.person_crop_circle,
        color: palette.brand,
        size: radius + 4,
      ),
    );
  }
}

class _HomeDashboardTab extends StatelessWidget {
  final DailyLearningPlan dailyPlan;
  final Wordbook? activeWordbook;
  final List<Wordbook> wordbooks;
  final Future<_DeckStats> Function(Wordbook wordbook) statsForWordbook;

  const _HomeDashboardTab({
    required this.dailyPlan,
    required this.activeWordbook,
    required this.wordbooks,
    required this.statsForWordbook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    final reviewCount = dailyPlan.dueWords.length;
    final totalFocus = reviewCount + dailyPlan.newWords.length + dailyPlan.learningWords.length;
    final progress = totalFocus == 0 ? 1.0 : reviewCount / totalFocus;
    final nextActionLabel =
        dailyPlan.hasReview
            ? '복습'
            : dailyPlan.hasNewWords
            ? '새 단어'
            : '카드';
    final dashboardWordbooks = _prioritizeActiveWordbook(wordbooks, activeWordbook);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '오늘',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(width: 12),
              if (activeWordbook != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _TagChip(
                      icon: CupertinoIcons.book_fill,
                      text: activeWordbook!.name,
                      tooltip: '현재 단어장 변경',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
                        );
                      },
                    ),
                  ),
                )
              else
                const Spacer(),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '오늘의 복습은 현재 단어장 기준입니다. 단어장명 또는 현황 카드를 눌러 변경할 수 있습니다.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _CompactMetricTile(
                        label: '복습',
                        value: '$reviewCount',
                        accentColor: palette.review,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactMetricTile(
                        label: '새 단어',
                        value: '${dailyPlan.newWords.length}',
                        accentColor: palette.info,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CompactMetricTile(
                        label: '학습 중',
                        value: '${dailyPlan.learningWords.length}',
                        accentColor: palette.warning,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: palette.accent.withValues(alpha: 0.14),
                          valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(progress * 100).round()}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () {
              if (dailyPlan.hasReview) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QuizScreen(initialMode: QuizMode.reviewSpelling),
                  ),
                );
                return;
              }
              if (dailyPlan.hasNewWords) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const FlashcardScreen(initialMode: FlashcardLaunchMode.newWords),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FlashcardScreen()),
              );
            },
            child: GlassmorphicCard(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              borderRadius: 24,
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.play_fill, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      '시작',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  _TagChip(icon: CupertinoIcons.arrow_right, text: nextActionLabel),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text(
                '단어장 현황',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
                  );
                },
                child: const Text('전체'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _WordbookStatusPager(
            wordbooks: dashboardWordbooks,
            activeWordbook: activeWordbook,
            statsForWordbook: statsForWordbook,
          ),
        ],
      ),
    );
  }

  List<Wordbook> _prioritizeActiveWordbook(List<Wordbook> source, Wordbook? active) {
    if (active == null || source.length < 2) return source;
    var activeMatches = false;
    final ordered = <Wordbook>[];
    final rest = <Wordbook>[];

    for (final wordbook in source) {
      final isActive =
          wordbook.id != null && active.id != null
              ? wordbook.id == active.id
              : wordbook.dbFileName == active.dbFileName;
      if (isActive) {
        activeMatches = true;
        ordered.add(wordbook);
      } else {
        rest.add(wordbook);
      }
    }

    if (!activeMatches) return source;
    return [...ordered, ...rest];
  }
}

class _WordbookStatusPager extends StatefulWidget {
  final List<Wordbook> wordbooks;
  final Wordbook? activeWordbook;
  final Future<_DeckStats> Function(Wordbook wordbook) statsForWordbook;

  const _WordbookStatusPager({
    required this.wordbooks,
    required this.activeWordbook,
    required this.statsForWordbook,
  });

  @override
  State<_WordbookStatusPager> createState() => _WordbookStatusPagerState();
}

class _WordbookStatusPagerState extends State<_WordbookStatusPager> {
  static const double _statusCardHeight = 306.0;

  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.92);
  }

  @override
  void didUpdateWidget(covariant _WordbookStatusPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wordbooks.isEmpty) {
      _currentPage = 0;
      return;
    }
    if (_currentPage >= widget.wordbooks.length) {
      _currentPage = widget.wordbooks.length - 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(_currentPage);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.wordbooks.isEmpty) {
      return const _EmptyWordbookStatusCard();
    }

    if (widget.wordbooks.length == 1) {
      final wordbook = widget.wordbooks.first;
      return SizedBox(
        height: _statusCardHeight,
        child: _WordbookStatusSlide(
          wordbook: wordbook,
          activeWordbook: widget.activeWordbook,
          statsFuture: widget.statsForWordbook(wordbook),
          index: 0,
          totalCount: 1,
        ),
      );
    }

    final visibleDotCount = widget.wordbooks.length.clamp(1, 5).toInt();

    return Column(
      children: [
        SizedBox(
          height: _statusCardHeight,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: widget.wordbooks.length,
            itemBuilder: (context, index) {
              final wordbook = widget.wordbooks[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _WordbookStatusSlide(
                  wordbook: wordbook,
                  activeWordbook: widget.activeWordbook,
                  statsFuture: widget.statsForWordbook(wordbook),
                  index: index,
                  totalCount: widget.wordbooks.length,
                ),
              );
            },
          ),
        ),
        if (widget.wordbooks.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(visibleDotCount, (index) {
              final normalizedIndex =
                  widget.wordbooks.length <= visibleDotCount
                      ? index
                      : ((_currentPage / (widget.wordbooks.length - 1)) *
                              (visibleDotCount - 1))
                          .round();
              final isActive = index == normalizedIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: isActive ? 18 : 6,
                height: 6,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color:
                      isActive
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _WordbookStatusSlide extends StatelessWidget {
  final Wordbook wordbook;
  final Wordbook? activeWordbook;
  final Future<_DeckStats> statsFuture;
  final int index;
  final int totalCount;

  const _WordbookStatusSlide({
    required this.wordbook,
    required this.activeWordbook,
    required this.statsFuture,
    required this.index,
    required this.totalCount,
  });

  bool get _isActive {
    if (activeWordbook == null) return false;
    if (wordbook.id != null && activeWordbook!.id != null) {
      return wordbook.id == activeWordbook!.id;
    }
    return wordbook.dbFileName == activeWordbook!.dbFileName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    final manager = context.read<WordbookManager>();

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      borderRadius: 24,
      onTap: () async {
        await manager.setActiveWordbook(wordbook);
        if (!context.mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
        );
      },
      child: FutureBuilder<_DeckStats>(
        future: statsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          final totalWords = stats?.totalCount ?? 0;
          final masteryRatio =
              stats == null || stats.totalCount == 0
                  ? 0.0
                  : stats.matureCount / stats.totalCount;
          final focusCount =
              stats == null ? 0 : stats.reviewCount + stats.newCount + stats.learningCount;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: palette.iconSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border.withValues(alpha: 0.72)),
                    ),
                    child: Icon(
                      CupertinoIcons.book_fill,
                      color: palette.brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                wordbook.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _StatusBadge(
                              text: _isActive ? '현재' : '${index + 1}/$totalCount',
                              color: _isActive ? palette.brand : palette.info,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stats == null ? '현황 불러오는 중' : '전체 $totalWords개 · 집중 $focusCount개',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    '암기율',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    stats == null ? '-' : '${(masteryRatio * 100).round()}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: palette.brand,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child:
                    stats == null
                        ? const LinearProgressIndicator(minHeight: 10)
                        : LinearProgressIndicator(
                          value: masteryRatio.clamp(0.0, 1.0),
                          minHeight: 10,
                          backgroundColor: palette.iconSurface,
                          valueColor: AlwaysStoppedAnimation<Color>(palette.brand),
                        ),
              ),
              const SizedBox(height: 10),
              _MemoryDistributionBar(stats: stats),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatusMetricPill(
                      label: '복습',
                      value: stats?.reviewCount,
                      color: palette.review,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusMetricPill(
                      label: '새 단어',
                      value: stats?.newCount,
                      color: palette.info,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _StatusMetricPill(
                      label: '학습 중',
                      value: stats?.learningCount,
                      color: palette.warning,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusMetricPill(
                      label: '안정 기억',
                      value: stats?.matureCount,
                      color: palette.success,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemoryDistributionBar extends StatelessWidget {
  final _DeckStats? stats;

  const _MemoryDistributionBar({required this.stats});

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));
    final data = stats;

    if (data == null || data.totalCount == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: palette.iconSurface,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    final segments = [
      _BarSegment(count: data.reviewCount, color: palette.review),
      _BarSegment(count: data.newCount, color: palette.info),
      _BarSegment(count: data.learningCount, color: palette.warning),
      _BarSegment(count: data.matureCount, color: palette.success),
    ].where((segment) => segment.count > 0).toList();

    if (segments.isEmpty) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: palette.iconSurface,
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        height: 8,
        child: Row(
          children:
              segments
                  .map(
                    (segment) => Expanded(
                      flex: segment.count,
                      child: ColoredBox(color: segment.color),
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}

class _StatusMetricPill extends StatelessWidget {
  final String label;
  final int? value;
  final Color color;

  const _StatusMetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value == null ? '-' : '$value',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyWordbookStatusCard extends StatelessWidget {
  const _EmptyWordbookStatusCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.iconSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(CupertinoIcons.tray, color: palette.brand),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '불러온 단어장이 없습니다.',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            tooltip: '단어장 관리',
            icon: const Icon(CupertinoIcons.chevron_right),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BarSegment {
  final int count;
  final Color color;

  const _BarSegment({required this.count, required this.color});
}

class _DecksTab extends StatelessWidget {
  final Wordbook? activeWordbook;
  final List<Wordbook> wordbooks;
  final Future<_DeckStats> Function(Wordbook wordbook) statsForWordbook;

  const _DecksTab({
    required this.activeWordbook,
    required this.wordbooks,
    required this.statsForWordbook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Decks',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  activeWordbook == null
                      ? '불러온 단어장을 기준으로 루틴을 이어갈 수 있습니다.'
                      : '현재 단어장 · ${activeWordbook!.name}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
                          );
                        },
                        icon: const Icon(CupertinoIcons.add_circled, size: 18),
                        label: const Text('단어장 관리'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ...wordbooks.map(
            (wordbook) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DeckPreviewCard(
                wordbook: wordbook,
                statsFuture: statsForWordbook(wordbook),
                showChevron: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewTab extends StatelessWidget {
  final DailyLearningPlan dailyPlan;

  const _ReviewTab({required this.dailyPlan});

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        children: [
          _ActionCard(
            title: '오늘 복습',
            subtitle: dailyPlan.hasReview
                ? '${dailyPlan.dueWords.length}개 단어를 먼저 고정합니다.'
                : '오늘 급한 복습은 없습니다.',
            icon: CupertinoIcons.flame_fill,
            accentColor: palette.review,
            onTap:
                dailyPlan.hasReview
                    ? () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const QuizScreen(initialMode: QuizMode.reviewSpelling),
                      ),
                    )
                    : null,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Flashcards',
            subtitle: '전체 카드 또는 새 단어 루틴으로 이어집니다.',
            icon: CupertinoIcons.layers_alt_fill,
            accentColor: palette.brand,
            onTap:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const FlashcardScreen())),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Self Test',
            subtitle: '객관식과 스펠링 테스트를 한곳에서 시작합니다.',
            icon: CupertinoIcons.pencil_outline,
            accentColor: palette.info,
            onTap:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const QuizScreen())),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Incorrect Review',
            subtitle: '오답 복습과 약한 단어 재확인을 빠르게 이어갑니다.',
            icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
            accentColor: palette.warning,
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const QuizScreen(initialMode: QuizMode.reviewSpelling),
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _AiLearningTab extends StatelessWidget {
  const _AiLearningTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI 학습',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '개인화 문제 생성과 문법 연습을 이곳에서 시작합니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _ActionCard(
            title: 'AI 퀴즈 생성',
            subtitle: '개인화된 문제로 단어 기억을 더 입체적으로 확인합니다.',
            icon: CupertinoIcons.sparkles,
            accentColor: palette.success,
            onTap:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AiQuizSetupScreen())),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'AI 예문 생성',
            subtitle: '단어장을 선택해 예문과 번역을 만들고 플래시카드, 시험지, AI 퀴즈에서 활용합니다.',
            icon: CupertinoIcons.doc_text,
            accentColor: palette.info,
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const AiQuizSetupScreen(
                          initialFocus: AiQuizSetupFocus.sentences,
                        ),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'AI 문법 체크',
            subtitle: '문법 범위를 지정해 추가 연습 문제를 생성합니다.',
            icon: CupertinoIcons.text_cursor,
            accentColor: palette.accent,
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiGrammarQuizSetupScreen()),
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'AI 설정',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          const AiSettingsCard(),
        ],
      ),
    );
  }
}

class _StatsTab extends StatelessWidget {
  final DailyLearningPlan dailyPlan;
  final int totalWordCount;

  const _StatsTab({required this.dailyPlan, required this.totalWordCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Memory Pulse',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniMetricCard(
                  label: '전체 단어',
                  value: '$totalWordCount',
                  accentColor: palette.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetricCard(
                  label: '오늘 복습',
                  value: '${dailyPlan.dueWords.length}',
                  accentColor: palette.review,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MiniMetricCard(
                  label: '새 단어',
                  value: '${dailyPlan.newWords.length}',
                  accentColor: palette.brand,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniMetricCard(
                  label: '안정 기억',
                  value: '${dailyPlan.matureWords.length}',
                  accentColor: palette.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _ActionCard(
            title: 'SRS 학습 현황',
            subtitle: '예정 복습, 단계별 분포, 세부 상태를 더 자세히 확인합니다.',
            icon: CupertinoIcons.chart_bar_alt_fill,
            accentColor: palette.info,
            onTap:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SrsStatusScreen())),
          ),
        ],
      ),
    );
  }
}

class _DeckPreviewCard extends StatelessWidget {
  final Wordbook wordbook;
  final Future<_DeckStats> statsFuture;
  final bool showChevron;

  const _DeckPreviewCard({
    required this.wordbook,
    required this.statsFuture,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    final manager = context.read<WordbookManager>();

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () async {
        await manager.setActiveWordbook(wordbook);
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const WordbookManagementScreen()));
      },
      child: GlassmorphicCard(
        child: FutureBuilder<_DeckStats>(
          future: statsFuture,
          builder: (context, snapshot) {
            final stats = snapshot.data;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: palette.iconSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.border.withValues(alpha: 0.7)),
                      ),
                      child: Icon(
                        CupertinoIcons.book_fill,
                        color: palette.brand,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        wordbook.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (showChevron)
                      Icon(
                        CupertinoIcons.chevron_right,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (stats == null)
                  const LinearProgressIndicator(minHeight: 8)
                else ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InlineStat(label: '복습', value: '${stats.reviewCount}'),
                      _InlineStat(label: '새 단어', value: '${stats.newCount}'),
                      _InlineStat(label: '학습 중', value: '${stats.learningCount}'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${stats.totalCount} total · ${stats.matureCount} mastered',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveAccent = onTap == null ? theme.disabledColor : accentColor;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: GlassmorphicCard(
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: effectiveAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: effectiveAccent, size: 23),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              CupertinoIcons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;

  const _CompactMetricTile({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;

  const _MiniMetricCard({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String label;
  final String value;

  const _InlineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.iconSurface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label $value',
        style: theme.textTheme.labelMedium?.copyWith(
          color: palette.brand,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? tooltip;
  final VoidCallback? onTap;

  const _TagChip({
    required this.icon,
    required this.text,
    this.tooltip,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    final chip = Container(
      constraints: const BoxConstraints(maxWidth: 190),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.review.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: palette.review),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: palette.review,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    final tappableChip =
        onTap == null
            ? chip
            : InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(999),
              child: chip,
            );
    return tooltip == null ? tappableChip : Tooltip(message: tooltip!, child: tappableChip);
  }
}

class _DeckStats {
  final int totalCount;
  final int reviewCount;
  final int newCount;
  final int learningCount;
  final int matureCount;

  const _DeckStats({
    required this.totalCount,
    required this.reviewCount,
    required this.newCount,
    required this.learningCount,
    required this.matureCount,
  });
}
