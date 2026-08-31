import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/learning_route_origin.dart';
import '../models/study_plan_model.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/api_key_service.dart';
import '../services/analytics_service.dart';
import '../services/srs_service.dart';
import '../themes/app_theme.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/study_guide.dart';
import 'ai_grammar_quiz_setup_screen.dart';
import 'ai_quiz_setup_screen.dart';
import 'app_settings_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'srs_status_screen.dart';
import 'wordbook_management_screen.dart';

enum _ShellTab { home, review, stats, ai, settings }

const bool _showStatsMetricCards = false;
const bool _showDeckSecondaryMetrics = false;

Future<void> _openMistakeReview(BuildContext context) async {
  final manager = context.read<WordbookManager>();
  final mcqCount = manager.getPendingMcqReviewWords().length;
  final spellingCount = manager.getPendingSpellingReviewWords().length;
  if (mcqCount == 0 && spellingCount == 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('지금 다시 확인할 오답이 없습니다.')),
    );
    return;
  }

  final startsWithMcq = mcqCount > 0;
  final title = startsWithMcq ? '객관식 오답부터 확인합니다' : '주관식 오답을 확인합니다';
  final message =
      startsWithMcq
          ? spellingCount > 0
              ? '객관식에서 틀린 $mcqCount개를 먼저 다시 풉니다. 모두 맞히면 주관식 오답 $spellingCount개로 이어갈 수 있습니다.'
              : '객관식에서 틀린 $mcqCount개를 같은 방식으로 다시 풉니다. 모두 맞힌 뒤 주관식으로 이어갈지 선택할 수 있습니다.'
          : '주관식에서 틀리거나 정답을 확인한 $spellingCount개를 다시 입력합니다.';
  final confirmed = await showDialog<bool>(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('나중에'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('시작'),
            ),
          ],
        ),
  );
  if (confirmed != true || !context.mounted) return;

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder:
          (_) => QuizScreen(
            initialMode:
                startsWithMcq ? QuizMode.reviewMultipleChoice : QuizMode.reviewSpelling,
            origin: LearningRouteOrigin.review,
            mistakeReview: true,
          ),
    ),
  );
}

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
    final isVision = theme.primaryColor == const Color(0xFFC76E40);

    if (isDark) {
      return const _ShellPalette(
        background: Color(0xFF231C16),
        topBar: Color(0xFF2D241C),
        iconSurface: Color(0xFF4F3F30),
        navBackground: Color(0xFF3A2E24),
        navIndicator: Color(0xFF604A35),
        border: Color(0xFF604A35),
        brand: Color(0xFFF0A866),
        accent: Color(0xFFF0A866),
        review: Color(0xFF7BBF8E),
        info: Color(0xFFFAB97A),
        success: Color(0xFF7BBF8E),
        warning: Color(0xFFE5B36A),
      );
    }

    if (isVision) {
      final background = theme.scaffoldBackgroundColor;
      final topBar = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.50),
        background,
      );
      final navBackground = Color.alphaBlend(
        Colors.white.withValues(alpha: 0.42),
        background,
      );
      final iconSurface = Color.alphaBlend(
        const Color(0xFFE5D6BD).withValues(alpha: 0.62),
        background,
      );
      return _ShellPalette(
        background: background,
        topBar: topBar,
        iconSurface: iconSurface,
        navBackground: navBackground,
        navIndicator: iconSurface,
        border: Color.alphaBlend(
          const Color(0xFFE5D6BD).withValues(alpha: 0.72),
          background,
        ),
        brand: const Color(0xFF8B4A32),
        accent: const Color(0xFFC76E40),
        review: const Color(0xFF5C8A6E),
        info: const Color(0xFFE08A52),
        success: const Color(0xFF5C8A6E),
        warning: const Color(0xFFD69A3F),
      );
    }

    return const _ShellPalette(
      background: Color(0xFFFAFAFA),
      topBar: Color(0xFFFFFFFF),
      iconSurface: Color(0xFFEAF3EF),
      navBackground: Color(0xFFFFFFFF),
      navIndicator: Color(0xFFE4F0E8),
      border: Color(0xFFDDE5E0),
      brand: Color(0xFF2F5D50),
      accent: Color(0xFFC86F3D),
      review: Color(0xFF5E7F64),
      info: Color(0xFFB77942),
      success: Color(0xFF3F7A5A),
      warning: Color(0xFFC49638),
    );
  }
}

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> {
  static const _guideSeenKey = 'memorize_me.study_guide_seen_v1';
  static const _lastShellTabKey = 'memorize_me.last_shell_tab';

  final SrsService _srsService = SrsService();
  final Map<Object, Future<_DeckStats>> _deckStatsFutures = {};
  _ShellTab _currentTab = _ShellTab.home;
  int? _cachedStatsRevision;
  bool _guideCheckStarted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreLastTab();
      _maybeShowFirstRunGuide();
    });
  }

  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final tabName = prefs.getString(_lastShellTabKey);
    if (tabName == null) return;

    for (final tab in _ShellTab.values) {
      if (tab.name == tabName) {
        if (!mounted) return;
        setState(() => _currentTab = tab);
        return;
      }
    }
  }

  void _selectTab(int index) {
    final nextTab = _ShellTab.values[index];
    setState(() => _currentTab = nextTab);
    context.read<AnalyticsService>().logTabViewed(nextTab.name);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_lastShellTabKey, nextTab.name),
    );
  }

  Future<void> _maybeShowFirstRunGuide() async {
    if (_guideCheckStarted) return;
    _guideCheckStarted = true;

    final prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool(_guideSeenKey) == true) return;

    await prefs.setBool(_guideSeenKey, true);
    if (!mounted) return;
    await showStudyGuideSheet(context, StudyGuideCatalog.quickStart);
  }

  Object _wordbookKey(Wordbook wordbook) => wordbook.id ?? wordbook.dbFileName;

  Future<_DeckStats> _statsForWordbook(WordbookManager manager, Wordbook wordbook) {
    return _deckStatsFutures.putIfAbsent(_wordbookKey(wordbook), () async {
      final words = await manager.getAllWordsFrom(wordbook);
      final studyPlan = manager.planFor(wordbook);
      final scopedWords = manager.wordsAvailableForPlan(words, plan: studyPlan);
      final isPlanScoped = studyPlan?.status == StudyPlanStatus.active;
      final plan = _srsService.buildDailyPlan(scopedWords);
      final reviewNotice = _reviewNoticeForWords(scopedWords, plan.dueWords.length);
      return _DeckStats(
        totalCount: isPlanScoped ? scopedWords.length : words.length,
        fullCount: words.length,
        lockedCount:
            isPlanScoped ? manager.lockedNewWordCount(words, plan: studyPlan) : 0,
        isPlanScoped: isPlanScoped,
        reviewCount: plan.dueWords.length,
        newCount: plan.newWords.length,
        learningCount: plan.learningWords.length,
        matureCount: plan.matureWords.length,
        nextReviewLabel: reviewNotice?.label,
        hasDueReviewNotice: reviewNotice?.isDue ?? false,
        hasOverdueReviewNotice: reviewNotice?.isOverdue ?? false,
      );
    });
  }

  _DeckReviewNotice? _reviewNoticeForWords(List<Word> words, int dueCount) {
    final today = _srsService.today();
    DateTime? nearest;
    var overdueCount = 0;

    for (final word in words) {
      final reviewDate = _srsService.reviewDateFor(word);
      if (reviewDate == null) continue;
      if (reviewDate.isBefore(today)) {
        overdueCount++;
        continue;
      }
      if (!reviewDate.isAfter(today)) continue;
      if (nearest == null || reviewDate.isBefore(nearest!)) {
        nearest = reviewDate;
      }
    }

    if (overdueCount > 0) {
      return _DeckReviewNotice(
        label: '복습일 지난 단어 $overdueCount개',
        isDue: true,
        isOverdue: true,
      );
    }
    if (dueCount > 0) {
      return _DeckReviewNotice(label: '복습할 단어 $dueCount개', isDue: true);
    }
    if (nearest == null) return null;
    return _DeckReviewNotice(label: '다음 복습 ${nearest.month}/${nearest.day}');
  }

  void _cycleTheme() {
    final notifier = context.read<ThemeNotifier>();
    const themes = [
      AppThemeType.lightGreen,
      AppThemeType.visionProtection,
      AppThemeType.dark,
    ];
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
    final palette = _ShellPalette.of(theme);
    final isDark = theme.brightness == Brightness.dark;
    final currentTheme = context.select<ThemeNotifier, AppThemeType>(
      (notifier) => notifier.currentTheme,
    );
    final manager = context.watch<WordbookManager>();
    if (_cachedStatsRevision != manager.statsRevision) {
      _deckStatsFutures.clear();
      _cachedStatsRevision = manager.statsRevision;
    }
    final user = context.watch<AuthProvider>().currentUser;
    final words = context.watch<WordListNotifier>().words;
    final activeWordbook = manager.activeWordbook;
    final activeStudyPlan = manager.planFor(activeWordbook);
    final plannedWordbookDbNames =
        manager.studyPlans
            .where((plan) => plan.status == StudyPlanStatus.active)
            .map((plan) => plan.dbFileName)
            .toSet();
    final routineWords = manager.wordsAvailableForPlan(words, plan: activeStudyPlan);
    final dailyPlan = _srsService.buildDailyPlan(routineWords);
    final fullDailyPlan = _srsService.buildDailyPlan(words);
    final routineWordCount = routineWords.length;
    final lockedNewWordCount = manager.lockedNewWordCount(words, plan: activeStudyPlan);
    final plannedNewWordSessionCount =
        manager.plannedNewWordSessionCount(words, plan: activeStudyPlan);
    final newWordSessionCount =
        manager.recommendedNewWordSessionCount(words, plan: activeStudyPlan);
    final learningScopeSubtitle = _learningScopeSubtitle(activeWordbook, activeStudyPlan);

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: palette.topBar,
                border: Border(
                  bottom: BorderSide(
                    color: palette.border.withValues(alpha: isDark ? 0.52 : 0.78),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isDark ? Colors.black : palette.border).withValues(
                          alpha: isDark ? 0.24 : 0.34,
                        ),
                    blurRadius: 18,
                    spreadRadius: -12,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 10),
                child: Row(
                  children: [
                    _ThemeIconButton(
                      currentTheme: currentTheme,
                      palette: palette,
                      onTap: _cycleTheme,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WordbookManagementScreen(),
                              ),
                            ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Memorize Me',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  color: palette.brand,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: palette.iconSurface.withValues(alpha: isDark ? 0.72 : 0.92),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: palette.border.withValues(alpha: isDark ? 0.72 : 0.82),
                                  ),
                                ),
                                child: Text(
                                  learningScopeSubtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: palette.brand,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ProfileAvatarButton(
                      user: user,
                      onTap: () => _showProfileSheet(context, theme, manager, dailyPlan, user),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: palette.background,
                child: _buildCurrentTab(
                  manager: manager,
                  dailyPlan: dailyPlan,
                  fullDailyPlan: fullDailyPlan,
                  user: user,
                  activeWordbook: activeWordbook,
                  activeStudyPlan: activeStudyPlan,
                  plannedWordbookDbNames: plannedWordbookDbNames,
                  lockedNewWordCount: lockedNewWordCount,
                  plannedNewWordSessionCount: plannedNewWordSessionCount,
                  newWordSessionCount: newWordSessionCount,
                  routineWordCount: routineWordCount,
                  totalWordCount: words.length,
                  learningScopeSubtitle: learningScopeSubtitle,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.navBackground,
          border: Border(
            top: BorderSide(
              color: palette.border.withValues(alpha: isDark ? 0.58 : 0.82),
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: (isDark ? Colors.black : palette.border).withValues(
                alpha: isDark ? 0.30 : 0.36,
              ),
              blurRadius: 20,
              spreadRadius: -10,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          indicatorColor: palette.navIndicator,
          selectedIndex: _ShellTab.values.indexOf(_currentTab),
          height: 76,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(icon: Icon(CupertinoIcons.house), label: '홈'),
            NavigationDestination(icon: Icon(CupertinoIcons.play_circle), label: '복습'),
            NavigationDestination(icon: Icon(CupertinoIcons.chart_bar), label: '통계'),
            NavigationDestination(icon: Icon(CupertinoIcons.sparkles), label: 'AI 학습'),
            NavigationDestination(icon: Icon(CupertinoIcons.settings), label: '설정'),
          ],
        ),
      ),
    );
  }

  String _learningScopeSubtitle(Wordbook? activeWordbook, StudyPlan? studyPlan) {
    if (activeWordbook == null) return '현재 학습 기준 선택 필요';
    if (studyPlan == null || studyPlan.status != StudyPlanStatus.active) {
      return '현재 학습 기준 · ${activeWordbook.name} 전체';
    }
    final totalDays = studyPlan.estimatedTotalDays();
    final currentDay = totalDays == 0 ? 0 : studyPlan.currentChunk().clamp(1, totalDays).toInt();
    return '현재 학습 기준 · ${activeWordbook.name} 플랜 $currentDay/$totalDays일차';
  }

  Widget _buildCurrentTab({
    required WordbookManager manager,
    required DailyLearningPlan dailyPlan,
    required DailyLearningPlan fullDailyPlan,
    required GoogleSignInAccount? user,
    required Wordbook? activeWordbook,
    required StudyPlan? activeStudyPlan,
    required Set<String> plannedWordbookDbNames,
    required int lockedNewWordCount,
    required int plannedNewWordSessionCount,
    required int newWordSessionCount,
    required int routineWordCount,
    required int totalWordCount,
    required String learningScopeSubtitle,
  }) {
    switch (_currentTab) {
      case _ShellTab.home:
        return _BloomHomeDashboardTab(
          dailyPlan: dailyPlan,
          studyDayStreak: manager.studyDayStreak,
          studyPlan: activeStudyPlan,
          lockedNewWordCount: lockedNewWordCount,
          plannedNewWordSessionCount: plannedNewWordSessionCount,
          newWordSessionCount: newWordSessionCount,
          user: user,
          activeWordbook: activeWordbook,
          plannedWordbookDbNames: plannedWordbookDbNames,
          wordbooks: manager.wordbooks,
          statsForWordbook: (wordbook) => _statsForWordbook(manager, wordbook),
        );
      case _ShellTab.review:
        return _BloomReviewTab(
          dailyPlan: dailyPlan,
          plannedNewWordSessionCount: plannedNewWordSessionCount,
          newWordSessionCount: newWordSessionCount,
          learningScopeSubtitle: learningScopeSubtitle,
        );
      case _ShellTab.stats:
        return _BloomStatsTab(
          fullDailyPlan: fullDailyPlan,
          planDailyPlan: dailyPlan,
          totalWordCount: totalWordCount,
          planWordCount: routineWordCount,
          activeStudyPlan: activeStudyPlan,
          lockedNewWordCount: lockedNewWordCount,
          plannedNewWordSessionCount: plannedNewWordSessionCount,
          newWordSessionCount: newWordSessionCount,
          learningScopeSubtitle: learningScopeSubtitle,
        );
      case _ShellTab.ai:
        return _BloomAiLearningTab(
          learningScopeSubtitle: learningScopeSubtitle,
          onOpenSettings: () => _selectTab(_ShellTab.values.indexOf(_ShellTab.settings)),
        );
      case _ShellTab.settings:
        return const AppSettingsScreen();
    }
  }

  void _showDecksSheet({
    required BuildContext context,
    required WordbookManager manager,
    required Wordbook? activeWordbook,
    required StudyPlan? activeStudyPlan,
    required Set<String> plannedWordbookDbNames,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => FractionallySizedBox(
            heightFactor: 0.88,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: Material(
                    color: _ShellPalette.of(Theme.of(sheetContext)).background,
                    child: _BloomDecksTab(
                      activeWordbook: activeWordbook,
                      activeStudyPlan: activeStudyPlan,
                      plannedWordbookDbNames: plannedWordbookDbNames,
                      wordbooks: manager.wordbooks,
                      statsForWordbook: (wordbook) => _statsForWordbook(manager, wordbook),
                      onClose: () => Navigator.of(sheetContext).pop(),
                    ),
                  ),
                ),
              ),
            ),
          ),
    );
  }
}

class _ThemeIconButton extends StatelessWidget {
  final AppThemeType currentTheme;
  final _ShellPalette palette;
  final VoidCallback onTap;

  const _ThemeIconButton({
    required this.currentTheme,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: _themeTooltip,
      child: Semantics(
        button: true,
        label: _themeTooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: isDark ? 0.36 : 0.72),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: palette.border.withValues(alpha: isDark ? 0.82 : 0.94),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? Colors.black : palette.brand).withValues(
                      alpha: isDark ? 0.16 : 0.07,
                    ),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(_themeIcon, color: palette.accent, size: 23),
                  Positioned(
                    right: 9,
                    bottom: 9,
                    child: Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.brand,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData get _themeIcon {
    switch (currentTheme) {
      case AppThemeType.lightGreen:
        return CupertinoIcons.sun_max;
      case AppThemeType.dark:
        return CupertinoIcons.moon;
      case AppThemeType.visionProtection:
        return CupertinoIcons.eye;
    }
  }

  String get _themeTooltip {
    switch (currentTheme) {
      case AppThemeType.lightGreen:
        return '라이트 모드';
      case AppThemeType.dark:
        return '다크 모드';
      case AppThemeType.visionProtection:
        return '시력 보호 모드';
    }
  }
}

class _ProfileAvatarButton extends StatelessWidget {
  final GoogleSignInAccount? user;
  final VoidCallback onTap;

  const _ProfileAvatarButton({
    required this.user,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '프로필',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: _UserAvatar(user: user, radius: 22),
      ),
    );
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
      child: Text(
        '🙂',
        style: TextStyle(fontSize: radius + 2),
      ),
    );
  }
}

class _HomeDashboardTab extends StatelessWidget {
  final DailyLearningPlan dailyPlan;
  final GoogleSignInAccount? user;
  final Wordbook? activeWordbook;
  final List<Wordbook> wordbooks;
  final Future<_DeckStats> Function(Wordbook wordbook) statsForWordbook;

  const _HomeDashboardTab({
    required this.dailyPlan,
    required this.user,
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
                    builder:
                        (_) => const FlashcardScreen(
                          initialMode: FlashcardLaunchMode.review,
                          origin: LearningRouteOrigin.home,
                        ),
                  ),
                );
                return;
              }
              if (dailyPlan.hasNewWords) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const FlashcardScreen(
                          initialMode: FlashcardLaunchMode.newWords,
                          origin: LearningRouteOrigin.home,
                        ),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FlashcardScreen(origin: LearningRouteOrigin.home),
                ),
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
            plannedWordbookDbNames: const <String>{},
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

class _BloomHomeDashboardTab extends StatefulWidget {
  final DailyLearningPlan dailyPlan;
  final int studyDayStreak;
  final StudyPlan? studyPlan;
  final int lockedNewWordCount;
  final int plannedNewWordSessionCount;
  final int newWordSessionCount;
  final GoogleSignInAccount? user;
  final Wordbook? activeWordbook;
  final Set<String> plannedWordbookDbNames;
  final List<Wordbook> wordbooks;
  final Future<_DeckStats> Function(Wordbook wordbook) statsForWordbook;

  const _BloomHomeDashboardTab({
    required this.dailyPlan,
    required this.studyDayStreak,
    required this.studyPlan,
    required this.lockedNewWordCount,
    required this.plannedNewWordSessionCount,
    required this.newWordSessionCount,
    required this.user,
    required this.activeWordbook,
    required this.plannedWordbookDbNames,
    required this.wordbooks,
    required this.statsForWordbook,
  });

  @override
  State<_BloomHomeDashboardTab> createState() => _BloomHomeDashboardTabState();
}

class _BloomHomeDashboardTabState extends State<_BloomHomeDashboardTab> {
  final SrsService _srsService = SrsService();
  int _todayWordShuffleSeed = 0;

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));
    final dailyPlan = widget.dailyPlan;
    final activeWordbook = widget.activeWordbook;
    final wordbooks = widget.wordbooks;
    final statsForWordbook = widget.statsForWordbook;
    final reviewCount = dailyPlan.dueWords.length;
    final newCount = widget.newWordSessionCount;
    final availableNewCount = dailyPlan.newWords.length;
    final learningCount = dailyPlan.learningWords.length;
    final matureCount = dailyPlan.matureWords.length;
    final totalFocus = reviewCount + newCount + learningCount;
    final totalWords = totalFocus + matureCount;
    final reviewedTodayCount = _reviewedTodayCount(dailyPlan);
    final remainingTodayFocus = reviewCount + widget.newWordSessionCount;
    final todayPlanTotal = reviewedTodayCount + remainingTodayFocus;
    final todayCompletedCount = min(reviewedTodayCount, todayPlanTotal);
    final todayProgress =
        todayPlanTotal == 0
            ? (totalWords == 0 ? 0.0 : 1.0)
            : (todayCompletedCount / todayPlanTotal).clamp(0.0, 1.0).toDouble();
    final todayActionCount =
        reviewCount > 0
            ? reviewCount
            : dailyPlan.hasNewWords
            ? newCount
            : 0;
    final estimatedMinutes = _estimatedMinutes(todayActionCount);
    final dashboardWordbooks = _prioritizeActiveWordbook(wordbooks, activeWordbook);
    final hasActiveWordbook = activeWordbook != null;
    final actionTitle =
        !hasActiveWordbook
            ? '단어장 만들기'
            : dailyPlan.hasReview
            ? '복습 $reviewCount개 시작'
            : availableNewCount > 0 && newCount > 0
            ? '새 단어 $newCount개 시작'
            : learningCount > 0
            ? '카드 $learningCount개 점검'
            : '전체 카드 보기';
    final actionSubtitle =
        !hasActiveWordbook
            ? 'Google 시트 또는 CSV에서 가져오기'
            : dailyPlan.hasReview
            ? '예상 $estimatedMinutes분'
            : availableNewCount > 0 && newCount > 0
            ? _newWordActionSubtitle(newCount, widget.plannedNewWordSessionCount)
            : learningCount > 0
            ? '학습 중인 단어 확인'
            : '전체 카드 확인';
    final prescriptionTitle =
        !hasActiveWordbook
            ? '단어장을 추가하세요'
            : dailyPlan.hasReview
            ? '오늘 복습 $reviewCount개'
            : availableNewCount > 0 && newCount > 0
            ? '새 단어 $newCount개 시작'
            : learningCount > 0
            ? '학습 중 $learningCount개 확인'
            : '오늘 학습 완료';
    final prescriptionDescription =
        !hasActiveWordbook
            ? '단어장을 불러오면 복습과 새 단어 수를 계산합니다.'
            : dailyPlan.hasReview
            ? '복습일이 된 단어부터 처리합니다.'
            : availableNewCount > 0 && newCount > 0
            ? '오늘 시작할 새 단어만 표시합니다.'
            : learningCount > 0
            ? '복습일 전 단어를 카드로 확인합니다.'
            : '필수 루틴이 비었습니다.';

    return SingleChildScrollView(
      key: const PageStorageKey<String>('bloom-home-dashboard-v2'),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeLearningHero(
            userName: _firstName(widget.user?.displayName),
            remainingCount: remainingTodayFocus,
            hasActiveWordbook: hasActiveWordbook,
          ),
          const SizedBox(height: 14),
          _TodayLearningPanel(
            prescriptionTitle: prescriptionTitle,
            prescriptionDescription: prescriptionDescription,
            hasActiveWordbook: hasActiveWordbook,
            reviewCount: reviewCount,
            newCount: newCount,
            learningCount: learningCount,
            completedCount: todayCompletedCount,
            remainingCount: remainingTodayFocus,
            totalCount: todayPlanTotal,
            progress: todayProgress,
            actionTitle: actionTitle,
            actionSubtitle: actionSubtitle,
            onActionTap: () => _startRecommendedLearning(context),
            palette: palette,
            onGuideTap: () => showStudyGuideSheet(context, StudyGuideCatalog.todayRoutine),
          ),
          if (widget.studyPlan != null) ...[
            const SizedBox(height: 12),
            _StudyPlanStatusCard(
              plan: widget.studyPlan!,
              lockedNewWordCount: widget.lockedNewWordCount,
              availableNewWordCount: availableNewCount,
              plannedNewWordCount: widget.plannedNewWordSessionCount,
              adjustedNewWordCount: newCount,
              palette: palette,
              onGuideTap: () => showStudyGuideSheet(context, StudyGuideCatalog.studyPlan),
            ),
          ],
          const SizedBox(height: 18),
          _SectionHeader(
            title: '단어장 현황',
            actionLabel: '전체 보기',
            onActionTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _WordbookStatusPager(
            wordbooks: dashboardWordbooks,
            activeWordbook: activeWordbook,
            plannedWordbookDbNames: widget.plannedWordbookDbNames,
            statsForWordbook: statsForWordbook,
          ),
        ],
      ),
    );
  }

  void _startRecommendedLearning(BuildContext context) {
    if (widget.activeWordbook == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
      );
      return;
    }
    if (widget.dailyPlan.hasReview) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => const FlashcardScreen(
                initialMode: FlashcardLaunchMode.review,
                origin: LearningRouteOrigin.home,
              ),
        ),
      );
      return;
    }
    if (widget.dailyPlan.hasNewWords && widget.newWordSessionCount > 0) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => const FlashcardScreen(
                initialMode: FlashcardLaunchMode.newWords,
                origin: LearningRouteOrigin.home,
              ),
        ),
      );
      return;
    }
    if (widget.dailyPlan.learningWords.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const FlashcardScreen(origin: LearningRouteOrigin.home),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const FlashcardScreen(origin: LearningRouteOrigin.home),
      ),
    );
  }

  Widget _buildTodayWordCard(_ShellPalette palette) {
    final candidates = <_TodayWordCandidate>[
      for (final word in widget.dailyPlan.dueWords)
        _TodayWordCandidate(stageLabel: '오늘의 복습 단어', word: word),
      for (final word in widget.dailyPlan.learningWords)
        _TodayWordCandidate(stageLabel: '학습 중인 단어', word: word),
      for (final word in widget.dailyPlan.newWords)
        _TodayWordCandidate(stageLabel: '새로 만날 단어', word: word),
      for (final word in widget.dailyPlan.matureWords)
        _TodayWordCandidate(stageLabel: '안정 기억 단어', word: word),
    ];

    if (candidates.isNotEmpty) {
      final deckKey = widget.activeWordbook?.id ?? widget.activeWordbook?.dbFileName ?? '';
      final random = Random(Object.hash(deckKey, _todayWordShuffleSeed, DateTime.now().day));
      final candidate = candidates[random.nextInt(candidates.length)];
      final word = candidate.word;
      return _TodayWordSpotlight(
        stageLabel: candidate.stageLabel,
        word: word.word,
        meaning: word.meaning,
        example: word.exampleSentence,
        palette: palette,
        onShuffle: candidates.length > 1 ? _shuffleTodayWord : null,
      );
    }

    return _TodayWordSpotlight(
      stageLabel: '오늘의 단어',
      word: '준비 완료',
      meaning: '지금 급한 복습 단어가 없습니다.',
      example:
          widget.activeWordbook == null
              ? '단어장을 불러오면 추천 단어가 표시됩니다.'
              : '전체 카드를 가볍게 확인해보세요.',
      palette: palette,
      onShuffle: null,
    );
  }

  void _shuffleTodayWord() {
    setState(() => _todayWordShuffleSeed++);
  }

  int _estimatedMinutes(int focusCount) {
    if (focusCount <= 0) return 3;
    return ((focusCount * 18) / 60).ceil().clamp(1, 45).toInt();
  }

  String _newWordActionSubtitle(int adjustedCount, int plannedCount) {
    if (plannedCount > adjustedCount) {
      return '복습량에 맞춰 새 단어 $plannedCount개 중 $adjustedCount개만 시작';
    }
    return '새 단어 $adjustedCount개부터 시작';
  }

  String _firstName(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '학습자';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  int _reviewedTodayCount(DailyLearningPlan plan) {
    return [
      ...plan.dueWords,
      ...plan.newWords,
      ...plan.learningWords,
      ...plan.matureWords,
    ].where((word) => _srsService.wasReviewedToday(word)).length;
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

class _TodayWordCandidate {
  final String stageLabel;
  final Word word;

  const _TodayWordCandidate({
    required this.stageLabel,
    required this.word,
  });
}

class _HomeLearningHero extends StatelessWidget {
  final String userName;
  final int remainingCount;
  final bool hasActiveWordbook;

  const _HomeLearningHero({
    required this.userName,
    required this.remainingCount,
    required this.hasActiveWordbook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focusMessage =
        !hasActiveWordbook
            ? '학습할 단어장을 추가하세요.'
            : remainingCount == 0
            ? '오늘 처리할 필수 학습이 없습니다.'
            : '남은 학습 $remainingCount개';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '오늘 학습',
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          focusMessage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 14,
            height: 1.35,
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TodayLearningPanel extends StatelessWidget {
  final String prescriptionTitle;
  final String prescriptionDescription;
  final bool hasActiveWordbook;
  final int reviewCount;
  final int newCount;
  final int learningCount;
  final int completedCount;
  final int remainingCount;
  final int totalCount;
  final double progress;
  final String actionTitle;
  final String actionSubtitle;
  final VoidCallback onActionTap;
  final _ShellPalette palette;
  final VoidCallback? onGuideTap;

  const _TodayLearningPanel({
    required this.prescriptionTitle,
    required this.prescriptionDescription,
    required this.hasActiveWordbook,
    required this.reviewCount,
    required this.newCount,
    required this.learningCount,
    required this.completedCount,
    required this.remainingCount,
    required this.totalCount,
    required this.progress,
    required this.actionTitle,
    required this.actionSubtitle,
    required this.onActionTap,
    required this.palette,
    this.onGuideTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressPercent = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFCF6),
            palette.iconSurface.withValues(alpha: 0.72),
            const Color(0xFFFFF7EE),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: palette.brand.withValues(alpha: theme.brightness == Brightness.dark ? 0.20 : 0.10),
            blurRadius: 24,
            spreadRadius: -14,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.brand,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: palette.brand.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: -8,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  CupertinoIcons.checkmark_square,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            prescriptionTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 19,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                              height: 1.22,
                            ),
                          ),
                        ),
                        if (onGuideTap != null) ...[
                          const SizedBox(width: 6),
                          _InlineGuideButton(onTap: onGuideTap!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      prescriptionDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.36,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              constraints: const BoxConstraints(minHeight: 62),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    palette.brand,
                    Color.lerp(palette.brand, palette.accent, 0.22)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: palette.brand.withValues(alpha: 0.22),
                    blurRadius: 18,
                    spreadRadius: -10,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(CupertinoIcons.play_fill, color: palette.brand, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          actionTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          actionSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    CupertinoIcons.chevron_right,
                    color: Colors.white.withValues(alpha: 0.88),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (hasActiveWordbook) ...[
            Row(
              children: [
                Expanded(
                  child: _LearningMetricBubble(
                    label: '복습',
                    value: '$reviewCount',
                    helper: '오늘 다시 볼 단어',
                    icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
                    accentColor: palette.accent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LearningMetricBubble(
                    label: '새 단어',
                    value: '$newCount',
                    helper: '오늘 새로 시작',
                    icon: CupertinoIcons.plus_circle_fill,
                    accentColor: palette.brand,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _LearningMetricBubble(
                    label: '학습 중',
                    value: '$learningCount',
                    helper: '복습일 대기',
                    icon: CupertinoIcons.book_fill,
                    accentColor: palette.review,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Text(
                  '오늘 목표 완료율',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                Text(
                  remainingCount == 0 ? '완료' : '남음 $remainingCount',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    color: palette.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$progressPercent%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: palette.iconSurface.withValues(alpha: 0.86),
                valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              totalCount == 0
                  ? '오늘 꼭 처리해야 할 복습과 새 단어가 없습니다.'
                  : '오늘 완료 $completedCount개 · 지금 남은 학습 $remainingCount개',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ] else
            Text(
              '단어장을 준비하면 오늘 복습, 새 단어, 학습 중 상태가 여기에 표시됩니다.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}

class _LearningMetricBubble extends StatelessWidget {
  final String label;
  final String value;
  final String helper;
  final IconData icon;
  final Color accentColor;

  const _LearningMetricBubble({
    required this.label,
    required this.value,
    required this.helper,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 86),
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: accentColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            helper,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 10,
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineGuideButton extends StatelessWidget {
  final VoidCallback onTap;

  const _InlineGuideButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: '설명 보기',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(
            CupertinoIcons.question_circle,
            size: 17,
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _StudyPlanStatusCard extends StatelessWidget {
  final StudyPlan plan;
  final int lockedNewWordCount;
  final int availableNewWordCount;
  final int plannedNewWordCount;
  final int adjustedNewWordCount;
  final _ShellPalette palette;
  final VoidCallback? onGuideTap;

  const _StudyPlanStatusCard({
    required this.plan,
    required this.lockedNewWordCount,
    required this.availableNewWordCount,
    required this.plannedNewWordCount,
    required this.adjustedNewWordCount,
    required this.palette,
    this.onGuideTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = plan.unlockedNewLimit();
    final scheduleProgress =
        plan.totalWords == 0 ? 0.0 : (unlocked / plan.totalWords).clamp(0.0, 1.0).toDouble();
    final totalDays = plan.estimatedTotalDays();
    final currentDay = totalDays == 0 ? 0 : plan.currentChunk().clamp(1, totalDays).toInt();
    final isAdjusted = adjustedNewWordCount < plannedNewWordCount;
    final todayNewLabel =
        isAdjusted
            ? '오늘 새 단어 $adjustedNewWordCount/$plannedNewWordCount개'
            : '오늘 새 단어 $adjustedNewWordCount개';

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.iconSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(CupertinoIcons.calendar, color: palette.brand, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '학습 플랜 적용 중',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currentDay/$totalDays일차 · $todayNewLabel · 목표 ${_formatMonthDay(plan.targetEndDate())}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onGuideTap != null) ...[
                const SizedBox(width: 6),
                _InlineGuideButton(onTap: onGuideTap!),
              ],
              const SizedBox(width: 6),
              _StatusBadge(text: '잠긴 단어 $lockedNewWordCount', color: palette.info),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: scheduleProgress,
              minHeight: 8,
              backgroundColor: palette.iconSurface,
              valueColor: AlwaysStoppedAnimation<Color>(palette.brand),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isAdjusted
                ? '복습 부담이 커서 새 단어를 줄였어요 · 열린 새 단어 $availableNewWordCount개'
                : '열림 $unlocked/${plan.totalWords} · 잠김 $lockedNewWordCount',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '새 단어는 플랜 범위 안에서 열리고, 복습량에 따라 오늘 시작 수가 조절됩니다.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonthDay(DateTime date) => '${date.month}/${date.day}';
}

class _ContinueLearningCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final _ShellPalette palette;
  final VoidCallback onTap;

  const _ContinueLearningCard({
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        constraints: const BoxConstraints(minHeight: 86),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: LinearGradient(
            colors: [
              palette.brand.withValues(alpha: 0.94),
              palette.accent.withValues(alpha: 0.96),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: palette.accent.withValues(alpha: 0.20),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.play_fill, color: palette.brand, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 18,
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.82),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(CupertinoIcons.chevron_right, color: Colors.white.withValues(alpha: 0.86)),
          ],
        ),
      ),
    );
  }
}

class _HomeInsightCard extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  final IconData icon;
  final Color accentColor;

  const _HomeInsightCard({
    required this.label,
    required this.value,
    required this.description,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: 28,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 132),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor, size: 18),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: accentColor,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int streak;
  final _ShellPalette palette;

  const _StreakCard({
    required this.streak,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleStreak = streak == 0 ? 0 : streak.clamp(1, 7).toInt();

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      borderRadius: 28,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 168),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.flame_fill, color: palette.accent, size: 18),
                const SizedBox(width: 7),
                Text(
                  '연속 학습',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: palette.accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$streak',
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 30,
                    height: 0.95,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    '일',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              streak == 0 ? '학습을 시작해요' : '연속 학습 중',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(7, (index) {
                final isActive = index < visibleStreak;
                return Expanded(
                  child: Container(
                    height: 24,
                    margin: EdgeInsets.only(right: index == 6 ? 0 : 5),
                    decoration: BoxDecoration(
                      color: isActive
                          ? palette.accent
                          : theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['월', '화', '수', '목', '금', '토', '일']
                  .map(
                    (day) => Text(
                      day,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyGoalCard extends StatelessWidget {
  final int completed;
  final int remaining;
  final int target;
  final _ShellPalette palette;

  const _WeeklyGoalCard({
    required this.completed,
    required this.remaining,
    required this.target,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeTarget = target < 0 ? 0 : target;
    final safeCompleted = completed.clamp(0, safeTarget == 0 ? 0 : safeTarget).toInt();
    final safeRemaining = remaining < 0 ? 0 : remaining;
    final progress = safeTarget == 0 ? 0.0 : safeCompleted / safeTarget;
    final progressPercent = (progress * 100).round();

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      borderRadius: 28,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 168),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(CupertinoIcons.scope, color: palette.accent, size: 17),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '오늘 목표',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontSize: 12,
                      color: palette.accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 7,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      ),
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            safeTarget == 0 ? '-' : '$progressPercent%',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              safeTarget == 0
                  ? '대기 없음'
                  : safeRemaining == 0
                  ? '목표 달성'
                  : '$safeRemaining개 남음',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              safeTarget == 0 ? '오늘 꼭 처리할 단어가 없어요' : '완료 $safeCompleted / $safeTarget',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeAchievementRow extends StatelessWidget {
  final int streak;
  final double progress;
  final _ShellPalette palette;

  const _HomeAchievementRow({
    required this.streak,
    required this.progress,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextTargetProgress = progress.clamp(0.0, 1.0).toDouble();
    final nextDays = streak == 0 ? 7 : (14 - streak.clamp(0, 14)).clamp(0, 14).toInt();

    return Row(
      children: [
        Expanded(
          child: GlassmorphicCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            borderRadius: 28,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 104),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: palette.accent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(CupertinoIcons.rosette, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '최근 뱃지',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: palette.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          streak >= 7 ? '7일 연속' : '학습 시작',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          streak >= 7 ? '방금 달성' : '첫 기록 대기',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
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
        const SizedBox(width: 14),
        Expanded(
          child: GlassmorphicCard(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            borderRadius: 28,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 104),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.scope, color: palette.accent, size: 17),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '다음 목표',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: palette.accent,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Icon(CupertinoIcons.chevron_right, size: 15, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '14일 연속 학습',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: nextTargetProgress,
                      minHeight: 7,
                      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    nextDays == 0 ? '목표 달성' : '$nextDays일 남음',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TodayWordSpotlight extends StatelessWidget {
  final String stageLabel;
  final String word;
  final String meaning;
  final String? example;
  final _ShellPalette palette;
  final VoidCallback? onShuffle;

  const _TodayWordSpotlight({
    required this.stageLabel,
    required this.word,
    required this.meaning,
    required this.example,
    required this.palette,
    required this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveExample =
        example == null || example!.trim().isEmpty ? '예문이 등록되면 이곳에 함께 표시됩니다.' : example!.trim();

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 18, 20),
      borderRadius: 30,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(CupertinoIcons.sparkles, size: 17, color: palette.accent),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        stageLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontSize: 13,
                          color: palette.accent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  word,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  meaning,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '"$effectiveExample"',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          _TodayWordShuffleButton(
            palette: palette,
            onTap: onShuffle,
          ),
        ],
      ),
    );
  }
}

class _TodayWordShuffleButton extends StatelessWidget {
  final _ShellPalette palette;
  final VoidCallback? onTap;

  const _TodayWordShuffleButton({
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;

    return Tooltip(
      message: enabled ? '다른 단어 보기' : '추천 단어',
      child: Semantics(
        button: enabled,
        label: enabled ? '다른 추천 단어 보기' : '추천 단어',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withValues(alpha: enabled ? 0.82 : 0.58),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color:
                      enabled
                          ? palette.review.withValues(alpha: 0.38)
                          : palette.border.withValues(alpha: 0.72),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.review.withValues(alpha: enabled ? 0.18 : 0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: palette.review.withValues(alpha: enabled ? 0.16 : 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        CupertinoIcons.leaf_arrow_circlepath,
                        color: palette.review.withValues(alpha: enabled ? 0.95 : 0.62),
                        size: 34,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onActionTap;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(foregroundColor: palette.brand),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(actionLabel),
              const SizedBox(width: 4),
              const Icon(CupertinoIcons.arrow_right, size: 14),
            ],
          ),
        ),
      ],
    );
  }
}

class _WordbookStatusPager extends StatefulWidget {
  final List<Wordbook> wordbooks;
  final Wordbook? activeWordbook;
  final Set<String> plannedWordbookDbNames;
  final Future<_DeckStats> Function(Wordbook wordbook) statsForWordbook;

  const _WordbookStatusPager({
    required this.wordbooks,
    required this.activeWordbook,
    required this.plannedWordbookDbNames,
    required this.statsForWordbook,
  });

  @override
  State<_WordbookStatusPager> createState() => _WordbookStatusPagerState();
}

class _WordbookStatusPagerState extends State<_WordbookStatusPager> {
  static const double _statusCardHeight = 272.0;

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
          hasStudyPlan: widget.plannedWordbookDbNames.contains(wordbook.dbFileName),
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
                  hasStudyPlan: widget.plannedWordbookDbNames.contains(wordbook.dbFileName),
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
  final bool hasStudyPlan;
  final Future<_DeckStats> statsFuture;
  final int index;
  final int totalCount;

  const _WordbookStatusSlide({
    required this.wordbook,
    required this.activeWordbook,
    required this.hasStudyPlan,
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
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      borderRadius: 20,
      onTap: () async {
        await manager.setActiveWordbook(wordbook);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('대시보드 기준 단어장을 ${wordbook.name}(으)로 바꿨습니다.')),
        );
      },
      child: FutureBuilder<_DeckStats>(
        future: statsFuture,
        builder: (context, snapshot) {
          final stats = snapshot.data;
          final totalWords = stats?.totalCount ?? 0;
          final masteryRatio = stats?.masteryRatio ?? 0.0;
          final focusCount = stats?.focusCount ?? 0;
          final totalLabel =
              stats == null
                  ? '현황 불러오는 중'
                  : stats.isPlanScoped
                  ? '플랜 ${stats.totalCount}/${stats.fullCount}개 · 잠김 ${stats.lockedCount}개'
                  : '전체 $totalWords개 · 집중 $focusCount개';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.iconSurface,
                      borderRadius: BorderRadius.circular(14),
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
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (hasStudyPlan) ...[
                              _PlanBadge(palette: palette),
                              const SizedBox(width: 6),
                            ],
                            _StatusBadge(
                              text: _isActive ? '현재' : '${index + 1}/$totalCount',
                              color: _isActive ? palette.brand : palette.info,
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          stats?.isPlanScoped == true ? '$totalLabel · 집중 $focusCount개' : totalLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    stats?.isPlanScoped == true ? '플랜 안정 기억률' : '안정 기억률',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    stats == null ? '-' : '${(masteryRatio * 100).round()}%',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: palette.success,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                stats?.isPlanScoped == true ? '안정 기억 단계 / 현재 플랜 기준' : '안정 기억 단계 / 전체 단어 기준',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child:
                    stats == null
                        ? const LinearProgressIndicator(minHeight: 8)
                        : LinearProgressIndicator(
                          value: masteryRatio.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: palette.iconSurface,
                          valueColor: AlwaysStoppedAnimation<Color>(palette.success),
                        ),
              ),
              if (stats?.nextReviewLabel != null) ...[
                const SizedBox(height: 7),
                _ReviewAlertChip(
                  label: stats!.nextReviewLabel!,
                  isDue: stats.hasDueReviewNotice,
                  isOverdue: stats.hasOverdueReviewNotice,
                  palette: palette,
                ),
              ],
              const SizedBox(height: 6),
              _MemoryDistributionBar(stats: stats),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _StatusMetricPill(
                      label: '새 단어',
                      value: stats?.newCount,
                      color: palette.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _StatusMetricPill(
                      label: '학습 중',
                      value: stats?.learningCount,
                      color: palette.warning,
                    ),
                  ),
                ],
              ),
              if (_showDeckSecondaryMetrics) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  Expanded(
                    child: _StatusMetricPill(
                      label: '복습 필요',
                      value: stats?.reviewCount,
                      color: palette.review,
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
            ],
          );
        },
      ),
    );
  }
}

class _ReviewAlertChip extends StatelessWidget {
  final String label;
  final bool isDue;
  final bool isOverdue;
  final _ShellPalette palette;

  const _ReviewAlertChip({
    required this.label,
    required this.isDue,
    required this.isOverdue,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        isOverdue
            ? theme.colorScheme.error
            : isDue
            ? palette.review
            : palette.success;
    final icon =
        isOverdue
            ? CupertinoIcons.exclamationmark_triangle_fill
            : isDue
            ? CupertinoIcons.bell_fill
            : CupertinoIcons.calendar;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isOverdue ? 0.18 : 0.11),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: isOverdue ? 0.46 : 0.16),
          width: isOverdue ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
      _BarSegment(count: data.newCount, color: palette.info),
      _BarSegment(count: data.learningCount, color: palette.warning),
      _BarSegment(count: data.reviewCount, color: palette.review),
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
      height: 38,
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
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
          value == null ? '-' : '$value',
          style: theme.textTheme.titleSmall?.copyWith(
            fontSize: 14,
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

class _PlanBadge extends StatelessWidget {
  final _ShellPalette palette;

  const _PlanBadge({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: palette.success.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.success.withValues(alpha: 0.34)),
        boxShadow: [
          BoxShadow(
            color: palette.success.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.rectangle_badge_checkmark, size: 12, color: palette.success),
          const SizedBox(width: 4),
          Text(
            '플랜',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.success,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
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
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      child: Column(
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
                ),
                child: Icon(CupertinoIcons.tray, color: palette.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '첫 단어장이 필요합니다',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Google 시트나 CSV·XLSX 파일에서 단어를 가져오면 오늘 루틴을 바로 시작할 수 있습니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
                );
              },
              icon: const Icon(CupertinoIcons.plus_circle_fill),
              label: const Text('단어장 만들기'),
            ),
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

class _BloomDecksTab extends _DecksTab {
  final StudyPlan? activeStudyPlan;
  final Set<String> plannedWordbookDbNames;
  final VoidCallback? onClose;

  const _BloomDecksTab({
    required Wordbook? activeWordbook,
    required this.activeStudyPlan,
    required this.plannedWordbookDbNames,
    this.onClose,
    required List<Wordbook> wordbooks,
    required Future<_DeckStats> Function(Wordbook wordbook) statsForWordbook,
  }) : super(
         activeWordbook: activeWordbook,
         wordbooks: wordbooks,
         statsForWordbook: statsForWordbook,
       );

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DeckLibrarySheetHeader(
            activeWordbookName: activeWordbook?.name,
            palette: palette,
            onClose: onClose,
          ),
          const SizedBox(height: 18),
          _DecksSummaryPanel(
            activeWordbookName: activeWordbook?.name,
            activeStudyPlan: activeStudyPlan,
            deckCount: wordbooks.length,
            palette: palette,
            onManageTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
              );
            },
            onPlanTap: () => _showStudyPlanBuilder(context),
          ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: '불러온 단어장',
            actionLabel: '관리',
            onActionTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          if (wordbooks.isEmpty)
            const _EmptyWordbookStatusCard()
          else
            ...wordbooks.map(
              (wordbook) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _BloomDeckPreviewCard(
                  wordbook: wordbook,
                  isActive: _isActiveWordbook(wordbook),
                  hasStudyPlan: plannedWordbookDbNames.contains(wordbook.dbFileName),
                  statsFuture: statsForWordbook(wordbook),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isActiveWordbook(Wordbook wordbook) {
    if (activeWordbook == null) return false;
    if (wordbook.id != null && activeWordbook!.id != null) {
      return wordbook.id == activeWordbook!.id;
    }
    return wordbook.dbFileName == activeWordbook!.dbFileName;
  }

  Future<void> _showStudyPlanBuilder(BuildContext context) async {
    final parentContext = context;
    final manager = context.read<WordbookManager>();
    final messenger = ScaffoldMessenger.of(parentContext);
    final wordbook = activeWordbook;
    if (wordbook == null) {
      messenger.showSnackBar(const SnackBar(content: Text('먼저 학습 기준 단어장을 선택해주세요.')));
      return;
    }

    final words = await manager.getAllWordsFrom(wordbook);
    if (!parentContext.mounted) return;
    if (words.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('플랜을 만들 단어가 없습니다.')));
      return;
    }

    final existingPlan = manager.planFor(wordbook);
    final presets = _StudyPlanPreset.presetsFor(words.length);
    final initialDailyTarget = existingPlan?.dailyNewTarget ?? _defaultDailyTarget(words.length);

    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _StudyPlanBuilderSheet(
            manager: manager,
            messenger: messenger,
            wordbook: wordbook,
            words: words,
            existingPlan: existingPlan,
            presets: presets,
            initialDailyTarget: initialDailyTarget,
            formatPlanDate: _formatPlanDate,
          ),
    );
  }

  int _defaultDailyTarget(int totalWords) {
    if (totalWords >= 500) return 30;
    if (totalWords >= 200) return 20;
    return 15;
  }

  String _formatPlanDate(DateTime date) => '${date.month}/${date.day}';
}

class _StudyPlanBuilderSheet extends StatefulWidget {
  final WordbookManager manager;
  final ScaffoldMessengerState messenger;
  final Wordbook wordbook;
  final List<Word> words;
  final StudyPlan? existingPlan;
  final List<_StudyPlanPreset> presets;
  final int initialDailyTarget;
  final String Function(DateTime date) formatPlanDate;

  const _StudyPlanBuilderSheet({
    required this.manager,
    required this.messenger,
    required this.wordbook,
    required this.words,
    required this.existingPlan,
    required this.presets,
    required this.initialDailyTarget,
    required this.formatPlanDate,
  });

  @override
  State<_StudyPlanBuilderSheet> createState() => _StudyPlanBuilderSheetState();
}

class _StudyPlanBuilderSheetState extends State<_StudyPlanBuilderSheet> {
  late final TextEditingController _dailyController;
  late final TextEditingController _targetDaysController;
  late String _selectedPresetId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialDailyTarget = widget.initialDailyTarget.clamp(1, widget.words.length).toInt();
    _dailyController = TextEditingController(text: '$initialDailyTarget');
    _targetDaysController = TextEditingController(
      text: '${(widget.words.length / initialDailyTarget).ceil()}',
    );
    _selectedPresetId = widget.existingPlan == null ? 'balanced' : 'custom';
  }

  @override
  void dispose() {
    _dailyController.dispose();
    _targetDaysController.dispose();
    super.dispose();
  }

  int _parseValue(TextEditingController controller, int fallback) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) return fallback;
    return value;
  }

  void _setControllerText(TextEditingController controller, String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  int get _dailyTarget => _parseValue(_dailyController, 20).clamp(1, widget.words.length).toInt();
  int get _estimatedDays => (widget.words.length / _dailyTarget).ceil();
  int get _estimatedChunks => _estimatedDays;
  DateTime get _targetDate => DateTime.now().add(Duration(days: max(_estimatedDays - 1, 0)));

  Future<void> _deletePlan() async {
    final existingPlan = widget.existingPlan;
    if (_isSaving || existingPlan == null) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _isSaving = true);
    await widget.manager.deleteStudyPlan(existingPlan);
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.messenger.showSnackBar(
      const SnackBar(content: Text('학습 플랜을 해제했습니다.')),
    );
  }

  Future<void> _savePlan() async {
    if (_isSaving) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final dailyTarget = _dailyTarget;
    final estimatedDays = _estimatedDays;
    setState(() => _isSaving = true);
    await widget.manager.createStudyPlanForWordbook(
      widget.wordbook,
      chunkSize: dailyTarget,
      dailyNewTarget: dailyTarget,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    widget.messenger.showSnackBar(
      SnackBar(content: Text('하루 $dailyTarget개, $estimatedDays일 플랜을 저장했습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;
    final dailyTarget = _dailyTarget;
    final estimatedDays = _estimatedDays;
    final estimatedChunks = _estimatedChunks;
    final targetDate = _targetDate;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: GlassmorphicCard(
              borderRadius: 30,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.existingPlan == null ? '학습 플랜 만들기' : '학습 플랜 수정',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.wordbook.name} · 새 단어를 며칠 동안 나눠서 SRS에 넣을지 정합니다. 복습 단어는 잠기지 않고, 새 단어만 일정에 맞춰 열립니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '추천 속도',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth =
                          constraints.maxWidth < 520
                              ? (constraints.maxWidth - 10) / 2
                              : (constraints.maxWidth - 20) / 3;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children:
                            widget.presets.map((preset) {
                              return SizedBox(
                                width: itemWidth,
                                child: _PlanPresetChip(
                                  preset: preset,
                                  selected: _selectedPresetId == preset.id,
                                  onTap:
                                      _isSaving
                                          ? null
                                          : () {
                                            _setControllerText(
                                              _dailyController,
                                              '${preset.dailyTarget}',
                                            );
                                            _setControllerText(
                                              _targetDaysController,
                                              '${(widget.words.length / preset.dailyTarget).ceil()}',
                                            );
                                            setState(() => _selectedPresetId = preset.id);
                                          },
                                ),
                              );
                            }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _targetDaysController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '새 단어를 며칠 동안 나눌까요?',
                      prefixIcon: Icon(CupertinoIcons.flag),
                      suffixText: '일',
                    ),
                    onChanged: (_) {
                      final targetDays =
                          _parseValue(_targetDaysController, estimatedDays)
                              .clamp(1, widget.words.length)
                              .toInt();
                      final nextDailyTarget =
                          (widget.words.length / targetDays).ceil().clamp(1, widget.words.length).toInt();
                      _setControllerText(_dailyController, '$nextDailyTarget');
                      setState(() => _selectedPresetId = 'custom');
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _dailyController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '하루에 새로 시작할 단어',
                      prefixIcon: Icon(CupertinoIcons.calendar_badge_plus),
                      suffixText: '개',
                    ),
                    onChanged: (_) {
                      final nextDailyTarget =
                          _parseValue(_dailyController, 20).clamp(1, widget.words.length).toInt();
                      _setControllerText(
                        _targetDaysController,
                        '${(widget.words.length / nextDailyTarget).ceil()}',
                      );
                      setState(() => _selectedPresetId = 'custom');
                    },
                  ),
                  const SizedBox(height: 16),
                  _PlanPreviewStrip(
                    days: estimatedDays,
                    chunks: estimatedChunks,
                    dailyTarget: dailyTarget,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '예상 완료일 ${widget.formatPlanDate(targetDate)} · $estimatedDays일 계획은 $estimatedChunks개 일일 묶음으로 진행됩니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (widget.existingPlan != null) ...[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : _deletePlan,
                            icon: const Icon(CupertinoIcons.trash, size: 17),
                            label: const Text('해제'),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _savePlan,
                          icon:
                              _isSaving
                                  ? const SizedBox(
                                    width: 17,
                                    height: 17,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                  : const Icon(CupertinoIcons.check_mark, size: 17),
                          label: Text(_isSaving ? '저장 중' : '저장'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudyPlanPreset {
  final String id;
  final String title;
  final String description;
  final int dailyTarget;

  const _StudyPlanPreset({
    required this.id,
    required this.title,
    required this.description,
    required this.dailyTarget,
  });

  static List<_StudyPlanPreset> presetsFor(int totalWords) {
    final gentleDaily = _dailyFor(totalWords, small: 8, medium: 12, large: 18);
    final balancedDaily = _dailyFor(totalWords, small: 15, medium: 20, large: 30);
    final focusDaily = _dailyFor(totalWords, small: 20, medium: 30, large: 45);

    return [
      _StudyPlanPreset(
        id: 'gentle',
        title: '천천히',
        description: '부담을 줄이고 꾸준히',
        dailyTarget: gentleDaily,
      ),
      _StudyPlanPreset(
        id: 'balanced',
        title: '균형',
        description: '가장 무난한 추천',
        dailyTarget: balancedDaily,
      ),
      _StudyPlanPreset(
        id: 'focus',
        title: '집중',
        description: '짧게 몰아서 끝내기',
        dailyTarget: focusDaily,
      ),
    ];
  }

  static int _dailyFor(int totalWords, {required int small, required int medium, required int large}) {
    if (totalWords >= 500) return min(large, totalWords);
    if (totalWords >= 200) return min(medium, totalWords);
    return min(small, totalWords);
  }
}

class _PlanPresetChip extends StatelessWidget {
  final _StudyPlanPreset preset;
  final bool selected;
  final VoidCallback? onTap;

  const _PlanPresetChip({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    final color = selected ? palette.brand : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color:
              selected
                  ? palette.brand.withValues(alpha: 0.12)
                  : palette.iconSurface.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? palette.brand : palette.border.withValues(alpha: 0.52),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                  size: 16,
                  color: color,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    preset.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              preset.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '하루 ${preset.dailyTarget}개',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BloomReviewTab extends _ReviewTab {
  final int plannedNewWordSessionCount;
  final int newWordSessionCount;
  final String learningScopeSubtitle;

  const _BloomReviewTab({
    required DailyLearningPlan dailyPlan,
    required this.plannedNewWordSessionCount,
    required this.newWordSessionCount,
    required this.learningScopeSubtitle,
  }) : super(dailyPlan: dailyPlan);

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));
    final wordbookManager = context.watch<WordbookManager>();
    final reviewCount = dailyPlan.dueWords.length;
    final newCount = dailyPlan.newWords.length;
    final todayNewCount = min(newWordSessionCount, newCount);
    final hasTodayNewWords = todayNewCount > 0;
    final learningCount = dailyPlan.learningWords.length;
    final pendingMcqCount = wordbookManager.getPendingMcqReviewWords().length;
    final pendingSpellingCount = wordbookManager.getPendingSpellingReviewWords().length;
    final pendingMistakeCount = pendingMcqCount + pendingSpellingCount;
    const showReviewSummaryCards = false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabIntroHeader(
            title: '복습',
            subtitle: '$learningScopeSubtitle 기준으로 오늘 필요한 복습과 테스트를 시작합니다.',
          ),
          const SizedBox(height: 16),
          _ContinueLearningCard(
            title:
                dailyPlan.hasReview
                    ? '오늘 복습부터'
                    : hasTodayNewWords
                    ? '새 단어 시작'
                    : '가볍게 점검',
            subtitle:
                dailyPlan.hasReview
                    ? '복습 $reviewCount개 · 약 ${((reviewCount * 18) / 60).ceil().clamp(1, 45)}분 소요'
                    : hasTodayNewWords
                    ? '복습 큐가 비어 있어 새 단어 $todayNewCount개를 시작합니다.'
                    : '급한 복습과 새 단어가 없으니 전체 카드를 확인해보세요.',
            palette: palette,
            onTap: () {
              if (dailyPlan.hasReview) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const FlashcardScreen(
                          initialMode: FlashcardLaunchMode.review,
                          origin: LearningRouteOrigin.review,
                        ),
                  ),
                );
                return;
              }
              if (hasTodayNewWords) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const FlashcardScreen(
                          initialMode: FlashcardLaunchMode.newWords,
                          origin: LearningRouteOrigin.review,
                        ),
                  ),
                );
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FlashcardScreen(origin: LearningRouteOrigin.review),
                ),
              );
            },
          ),
          if (showReviewSummaryCards) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HomeInsightCard(
                  label: '복습 대기',
                  value: '$reviewCount개',
                  description: reviewCount == 0 ? '오늘은 안정적이에요' : '먼저 고정할 단어',
                  icon: CupertinoIcons.flame_fill,
                  accentColor: palette.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _HomeInsightCard(
                  label: '새 단어',
                  value: '$todayNewCount개',
                  description:
                      plannedNewWordSessionCount > todayNewCount
                          ? '오늘 시작 $todayNewCount/$plannedNewWordSessionCount\n학습 중 $learningCount개는 복습일 대기'
                          : '오늘 시작할 단어\n학습 중 $learningCount개는 복습일 대기',
                  icon: CupertinoIcons.layers_alt_fill,
                  accentColor: palette.review,
                ),
              ),
            ],
          ),
          ],
          const SizedBox(height: 14),
          _SectionHeader(
            title: '학습 방식',
            actionLabel: 'SRS',
            onActionTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SrsStatusScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _BloomFeatureCard(
            title: '플래시카드',
            subtitle: '의미를 확인하며 기억 단계를 천천히 올립니다.',
            icon: CupertinoIcons.layers_alt_fill,
            accentColor: palette.brand,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const FlashcardScreen(origin: LearningRouteOrigin.review),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _BloomFeatureCard(
            title: '셀프 테스트',
            subtitle: '객관식과 스펠링으로 점검합니다.',
            icon: CupertinoIcons.pencil_outline,
            accentColor: palette.info,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QuizScreen(origin: LearningRouteOrigin.review)),
              );
            },
          ),
          const SizedBox(height: 12),
          _BloomFeatureCard(
            title: '오답 다시 확인',
            subtitle:
                pendingMistakeCount == 0
                    ? '객관식과 주관식에서 틀린 단어가 여기에 모입니다.'
                    : pendingMcqCount > 0 && pendingSpellingCount > 0
                    ? '객관식 $pendingMcqCount개 · 주관식 $pendingSpellingCount개'
                    : pendingMcqCount > 0
                    ? '객관식에서 틀린 $pendingMcqCount개를 다시 확인합니다.'
                    : '주관식에서 틀린 $pendingSpellingCount개를 다시 확인합니다.',
            icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
            accentColor: palette.warning,
            onTap: () => _startWeakReview(context),
          ),
        ],
      ),
    );
  }

  void _startWeakReview(BuildContext context) => _openMistakeReview(context);
}

class _BloomStatsTab extends StatefulWidget {
  final DailyLearningPlan fullDailyPlan;
  final DailyLearningPlan planDailyPlan;
  final int totalWordCount;
  final int planWordCount;
  final StudyPlan? activeStudyPlan;
  final int lockedNewWordCount;
  final int plannedNewWordSessionCount;
  final int newWordSessionCount;
  final String learningScopeSubtitle;

  const _BloomStatsTab({
    required this.fullDailyPlan,
    required this.planDailyPlan,
    required this.totalWordCount,
    required this.planWordCount,
    required this.activeStudyPlan,
    required this.lockedNewWordCount,
    required this.plannedNewWordSessionCount,
    required this.newWordSessionCount,
    required this.learningScopeSubtitle,
  });

  @override
  State<_BloomStatsTab> createState() => _BloomStatsTabState();
}

class _BloomStatsTabState extends State<_BloomStatsTab> {
  bool _showPlanScope = true;

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));
    final hasPlan = widget.activeStudyPlan != null;
    final usePlanScope = hasPlan && _showPlanScope;
    final dailyPlan = usePlanScope ? widget.planDailyPlan : widget.fullDailyPlan;
    final totalWordCount = usePlanScope ? widget.planWordCount : widget.totalWordCount;
    final matureCount = dailyPlan.matureWords.length;
    final mastery =
        totalWordCount == 0 ? 0.0 : (matureCount / totalWordCount).clamp(0.0, 1.0).toDouble();
    final scopeLabel = usePlanScope ? '현재 플랜' : '전체 단어장';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabIntroHeader(
            title: '통계',
            subtitle: '$scopeLabel · ${widget.learningScopeSubtitle}',
          ),
          const SizedBox(height: 16),
          if (hasPlan) ...[
            _StatsScopeSwitch(
              usePlanScope: usePlanScope,
              onChanged: (value) => setState(() => _showPlanScope = value),
              palette: palette,
            ),
            const SizedBox(height: 12),
          ],
          if (usePlanScope) ...[
            _PlanStatsSummaryCard(
              plan: widget.activeStudyPlan!,
              openedWordCount: widget.planWordCount,
              lockedNewWordCount: widget.lockedNewWordCount,
              plannedNewWordSessionCount: widget.plannedNewWordSessionCount,
              newWordSessionCount: widget.newWordSessionCount,
              palette: palette,
            ),
            const SizedBox(height: 12),
          ],
          _MasteryOverviewCard(
            progress: mastery,
            totalWordCount: totalWordCount,
            matureCount: matureCount,
            palette: palette,
          ),
          if (_showStatsMetricCards) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HomeInsightCard(
                  label: '오늘 복습',
                  value: '${dailyPlan.dueWords.length}개',
                  description: '지금 볼 단어',
                  icon: CupertinoIcons.flame_fill,
                  accentColor: palette.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _HomeInsightCard(
                  label: '새 단어',
                  value: '${dailyPlan.newWords.length}개',
                  description: '첫 학습 대기',
                  icon: CupertinoIcons.sparkles,
                  accentColor: palette.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HomeInsightCard(
                  label: '학습 중',
                  value: '${dailyPlan.learningWords.length}개',
                  description: '다음 복습 예정',
                  icon: CupertinoIcons.book_fill,
                  accentColor: palette.warning,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _HomeInsightCard(
                  label: '안정 기억',
                  value: '$matureCount개',
                  description: '긴 간격 복습',
                  icon: CupertinoIcons.check_mark_circled_solid,
                  accentColor: palette.review,
                ),
              ),
            ],
          ),
          ],
          const SizedBox(height: 14),
          _BloomFeatureCard(
            title: usePlanScope ? '플랜 기준 SRS 현황' : 'SRS 학습 현황',
            subtitle:
                usePlanScope
                    ? '열린 플랜 단어만 확인합니다.'
                    : '복습 일정과 단계 분포를 봅니다.',
            icon: CupertinoIcons.chart_bar_alt_fill,
            accentColor: palette.info,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SrsStatusScreen(initialPlanScope: usePlanScope),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatsScopeSwitch extends StatelessWidget {
  final bool usePlanScope;
  final ValueChanged<bool> onChanged;
  final _ShellPalette palette;

  const _StatsScopeSwitch({
    required this.usePlanScope,
    required this.onChanged,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: palette.iconSurface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border.withValues(alpha: 0.64)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatsScopeButton(
              label: '전체 단어장',
              selected: !usePlanScope,
              color: palette.brand,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _StatsScopeButton(
              label: '현재 학습 기준',
              selected: usePlanScope,
              color: palette.accent,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsScopeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _StatsScopeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PlanStatsSummaryCard extends StatelessWidget {
  final StudyPlan plan;
  final int openedWordCount;
  final int lockedNewWordCount;
  final int plannedNewWordSessionCount;
  final int newWordSessionCount;
  final _ShellPalette palette;

  const _PlanStatsSummaryCard({
    required this.plan,
    required this.openedWordCount,
    required this.lockedNewWordCount,
    required this.plannedNewWordSessionCount,
    required this.newWordSessionCount,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        plan.totalWords == 0 ? 0.0 : (openedWordCount / plan.totalWords).clamp(0.0, 1.0).toDouble();
    final adjusted = newWordSessionCount < plannedNewWordSessionCount;

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      borderRadius: 26,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(CupertinoIcons.calendar, color: palette.accent, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '플랜 통계 범위',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _StatusBadge(text: '플랜 적용', color: palette.accent),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: palette.iconSurface,
              valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '열림 $openedWordCount/${plan.totalWords} · 잠김 $lockedNewWordCount',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            adjusted
                ? '오늘 새 단어는 복습 부담 때문에 $plannedNewWordSessionCount개 중 $newWordSessionCount개만 표시합니다.'
                : '오늘 새 단어 목표는 $newWordSessionCount개입니다.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _BloomAiLearningTab extends _AiLearningTab {
  final String learningScopeSubtitle;
  final VoidCallback onOpenSettings;

  const _BloomAiLearningTab({
    required this.learningScopeSubtitle,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabIntroHeader(
            title: 'AI 학습',
            subtitle: '예문과 문제 생성을 관리합니다.',
          ),
          const SizedBox(height: 16),
          _AiReadinessCard(palette: palette, onOpenSettings: onOpenSettings),
          const SizedBox(height: 12),
          _AiBetaSummaryCard(palette: palette),
          const SizedBox(height: 18),
          _BloomFeatureCard(
            title: '예문 생성',
            subtitle: '예문과 번역을 채웁니다.',
            icon: CupertinoIcons.doc_text,
            accentColor: palette.info,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => const AiQuizSetupScreen(
                        initialFocus: AiQuizSetupFocus.sentences,
                      ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _BloomFeatureCard(
            title: '퀴즈 생성',
            subtitle: '단어장 맞춤 문제를 만듭니다.',
            icon: CupertinoIcons.question_circle,
            accentColor: palette.review,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiQuizSetupScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _BloomFeatureCard(
            title: '문법 문제 생성',
            subtitle: '문법 범위별 문제를 만듭니다.',
            icon: CupertinoIcons.text_cursor,
            accentColor: palette.accent,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiGrammarQuizSetupScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AiBetaSummaryCard extends StatelessWidget {
  final _ShellPalette palette;

  const _AiBetaSummaryCard({required this.palette});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiSettings = context.watch<AiSettingsProvider>();
    final fallbackText =
        aiSettings.autoFallbackEnabled
            ? '자동 대체 사용 시 여러 AI 제공자에 순차 요청될 수 있습니다.'
            : '현재 선택한 AI 제공자에만 요청됩니다.';

    return GlassmorphicCard(
      borderRadius: 14,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: palette.warning.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.exclamationmark_shield,
              color: palette.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 생성은 베타 기능입니다',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '단어장과 생성 옵션이 외부 AI 제공자에게 전송됩니다. 생성된 문제와 해설은 사용 전 확인하세요. $fallbackText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
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

class _AiReadinessCard extends StatelessWidget {
  final _ShellPalette palette;
  final VoidCallback onOpenSettings;

  const _AiReadinessCard({
    required this.palette,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aiSettings = context.watch<AiSettingsProvider>();
    final apiKeyService = context.read<ApiKeyService>();

    return FutureBuilder<Map<AiProvider, bool>>(
      future: _loadRegisteredProviders(apiKeyService),
      builder: (context, snapshot) {
        final isCheckingApiKey = snapshot.connectionState == ConnectionState.waiting;
        final registeredProviders = snapshot.data ?? const <AiProvider, bool>{};
        final priorityOptions = _registeredPriorityOptions(aiSettings, registeredProviders);
        final hasApiKey = !isCheckingApiKey && priorityOptions.isNotEmpty;
        final fallbackCount = aiSettings.fallbackOrder.length;
        final statusColor =
            isCheckingApiKey
                ? palette.info
                : hasApiKey
                ? palette.success
                : palette.warning;
        const showModelDetails = false;

        return GlassmorphicCard(
          borderRadius: 14,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isCheckingApiKey
                          ? CupertinoIcons.clock_fill
                          : hasApiKey
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.exclamationmark_circle_fill,
                      color: statusColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCheckingApiKey
                              ? 'AI 설정 확인 중'
                              : hasApiKey
                              ? '생성 준비 완료'
                              : 'API 등록이 필요합니다',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasApiKey
                              ? '등록된 모델 순서대로 실행합니다.'
                              : '설정에서 API 키를 등록하세요.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (showModelDetails) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildReadinessPill(
                    theme: theme,
                    icon: Icons.memory_rounded,
                    label: '${aiSettings.selectedProvider.shortLabel} · ${aiSettings.selectedModel}',
                    color: palette.info,
                  ),
                  _buildReadinessPill(
                    theme: theme,
                    icon:
                        isCheckingApiKey
                            ? CupertinoIcons.clock
                            : hasApiKey
                            ? CupertinoIcons.lock_shield_fill
                            : CupertinoIcons.lock_slash,
                    label:
                        isCheckingApiKey
                            ? 'API 키 확인 중'
                            : hasApiKey
                            ? 'API 키 등록됨'
                            : 'API 키 필요',
                    color: statusColor,
                  ),
                  _buildReadinessPill(
                    theme: theme,
                    icon: CupertinoIcons.arrow_2_circlepath,
                    label:
                        aiSettings.autoFallbackEnabled
                            ? '자동 대체 ${fallbackCount}개'
                            : '자동 대체 꺼짐',
                    color:
                        aiSettings.autoFallbackEnabled
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.outline,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _buildApiGuide(theme, hasApiKey: hasApiKey),
              const SizedBox(height: 14),
              _buildRegisteredPriorityList(
                theme,
                options: priorityOptions,
                isChecking: isCheckingApiKey,
              ),
              ],
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('설정 탭에서 AI 설정 관리'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<AiProvider, bool>> _loadRegisteredProviders(ApiKeyService apiKeyService) async {
    final result = <AiProvider, bool>{};
    for (final provider in AiProvider.values) {
      final apiKey = await apiKeyService.getApiKey(provider);
      result[provider] = apiKey != null && apiKey.isNotEmpty;
    }
    return result;
  }

  List<AiRequestOption> _registeredPriorityOptions(
    AiSettingsProvider aiSettings,
    Map<AiProvider, bool> registeredProviders,
  ) {
    return aiSettings
        .requestOptions(fallbackEnabled: aiSettings.autoFallbackEnabled)
        .where((option) => registeredProviders[option.provider] ?? false)
        .toList();
  }

  Widget _buildApiGuide(ThemeData theme, {required bool hasApiKey}) {
    final color = hasApiKey ? palette.success : palette.warning;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasApiKey ? CupertinoIcons.checkmark_shield_fill : CupertinoIcons.lightbulb_fill,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              hasApiKey
                  ? '자동 대체를 켜면 오류 때 다음 모델로 이어집니다.'
                  : 'AI 회사 선택 → 모델 선택 → API 키 등록 순서로 준비하세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisteredPriorityList(
    ThemeData theme, {
    required List<AiRequestOption> options,
    required bool isChecking,
  }) {
    if (isChecking) {
      return Text(
        '등록된 AI 모델을 확인하는 중입니다.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    if (options.isEmpty) {
      return Text(
        '등록된 모델이 없습니다.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: palette.warning,
          fontWeight: FontWeight.w800,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '실행 순서',
          style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          final isPrimary = index == 0;
          final color = isPrimary ? palette.success : theme.colorScheme.tertiary;
          return Padding(
            padding: EdgeInsets.only(bottom: index == options.length - 1 ? 0 : 7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isPrimary ? 0.11 : 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: isPrimary ? 0.30 : 0.20)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${option.provider.shortLabel} · ${option.modelName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReadinessPill({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
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
        ],
      ),
    );
  }

}

class _TabIntroHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TabIntroHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.displaySmall?.copyWith(
            fontSize: 29,
            height: 1.08,
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.42,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _DeckLibrarySheetHeader extends StatelessWidget {
  final String? activeWordbookName;
  final _ShellPalette palette;
  final VoidCallback? onClose;

  const _DeckLibrarySheetHeader({
    required this.activeWordbookName,
    required this.palette,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: palette.iconSurface,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: palette.border.withValues(alpha: 0.72)),
          ),
          child: Icon(CupertinoIcons.book_fill, color: palette.brand, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '단어장',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                activeWordbookName == null
                    ? '오늘 학습 기준을 선택하세요'
                    : '현재 학습 기준 · $activeWordbookName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          tooltip: '닫기',
          onPressed: onClose,
          icon: const Icon(CupertinoIcons.xmark, size: 18),
        ),
      ],
    );
  }
}

class _DecksSummaryPanel extends StatelessWidget {
  final String? activeWordbookName;
  final StudyPlan? activeStudyPlan;
  final int deckCount;
  final _ShellPalette palette;
  final VoidCallback onManageTap;
  final VoidCallback onPlanTap;

  const _DecksSummaryPanel({
    required this.activeWordbookName,
    required this.activeStudyPlan,
    required this.deckCount,
    required this.palette,
    required this.onManageTap,
    required this.onPlanTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      borderRadius: 32,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  activeWordbookName ?? '단어장을 불러와주세요',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatusBadge(text: '$deckCount개', color: palette.brand),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            activeWordbookName == null
                ? '학습을 시작하려면 먼저 사용할 단어장을 선택해야 합니다.'
                : activeStudyPlan == null
                ? '홈과 복습 루틴은 이 단어장을 기준으로 계산됩니다.'
                : '학습 플랜으로 새 단어 노출을 나눠서 진행 중입니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onManageTap,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(CupertinoIcons.slider_horizontal_3, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('관리'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onPlanTap,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  icon: const Icon(CupertinoIcons.calendar_badge_plus, size: 18),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(activeStudyPlan == null ? '플랜 만들기' : '플랜 수정'),
                  ),
                ),
              ),
            ],
          ),
          if (activeStudyPlan != null) ...[
            const SizedBox(height: 14),
            _PlanPreviewStrip(
              days: activeStudyPlan!.estimatedTotalDays(),
              chunks: activeStudyPlan!.chunkCount,
              dailyTarget: activeStudyPlan!.dailyNewTarget,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanPreviewStrip extends StatelessWidget {
  final int days;
  final int chunks;
  final int dailyTarget;

  const _PlanPreviewStrip({
    required this.days,
    required this.chunks,
    required this.dailyTarget,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _ShellPalette.of(Theme.of(context));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.iconSurface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border.withValues(alpha: 0.58)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth =
              constraints.maxWidth < 380
                  ? (constraints.maxWidth - 12) / 2
                  : (constraints.maxWidth - 24) / 3;
          return Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              SizedBox(
                width: itemWidth,
                child: _PlanPreviewMetric(
                  label: '예상 기간',
                  value: '$days일',
                  color: palette.brand,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _PlanPreviewMetric(
                  label: '일일 묶음',
                  value: '$chunks일',
                  color: palette.info,
                ),
              ),
              SizedBox(
                width: itemWidth,
                child: _PlanPreviewMetric(
                  label: '하루 목표',
                  value: '$dailyTarget개',
                  color: palette.review,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PlanPreviewMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PlanPreviewMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _BloomDeckPreviewCard extends StatelessWidget {
  final Wordbook wordbook;
  final bool isActive;
  final bool hasStudyPlan;
  final Future<_DeckStats> statsFuture;

  const _BloomDeckPreviewCard({
    required this.wordbook,
    required this.isActive,
    required this.hasStudyPlan,
    required this.statsFuture,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    final manager = context.read<WordbookManager>();

    return GlassmorphicCard(
      borderRadius: 30,
      isActive: isActive,
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
          final total = stats?.totalCount ?? 0;
          final focus = stats?.focusCount ?? 0;
          final mastery = stats?.masteryRatio ?? 0.0;
          final masteryPercent = (mastery * 100).round();
          final countLabel =
              stats == null
                  ? '현황을 불러오는 중'
                  : stats.isPlanScoped
                  ? '플랜 ${stats.totalCount}/${stats.fullCount}개 · 집중 $focus개'
                  : '전체 $total개 · 집중 $focus개';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: palette.iconSurface,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(CupertinoIcons.book_fill, color: palette.brand, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          wordbook.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          countLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasStudyPlan) ...[
                    _PlanBadge(palette: palette),
                    const SizedBox(width: 8),
                  ],
                  if (isActive) ...[
                    _StatusBadge(text: '현재', color: palette.brand),
                    const SizedBox(width: 8),
                  ],
                  Icon(CupertinoIcons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      stats?.isPlanScoped == true ? '플랜 안정 기억률' : '안정 기억률',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    stats == null ? '-' : '$masteryPercent%',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: palette.brand,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: mastery.clamp(0.0, 1.0),
                  minHeight: 9,
                  backgroundColor: palette.iconSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.accent),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InlineStat(label: '복습', value: '${stats?.reviewCount ?? 0}'),
                  _InlineStat(label: '새 단어', value: '${stats?.newCount ?? 0}'),
                  _InlineStat(label: '학습 중', value: '${stats?.learningCount ?? 0}'),
                  _InlineStat(label: '안정 기억', value: '${stats?.matureCount ?? 0}'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BloomFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;

  const _BloomFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GlassmorphicCard(
      borderRadius: 18,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.42,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(CupertinoIcons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
        ],
      ),
    );
  }
}

class _MasteryOverviewCard extends StatelessWidget {
  final double progress;
  final int totalWordCount;
  final int matureCount;
  final _ShellPalette palette;

  const _MasteryOverviewCard({
    required this.progress,
    required this.totalWordCount,
    required this.matureCount,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percent = (progress * 100).round();

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      borderRadius: 18,
      child: Column(
        children: [
          Text(
            '전체 암기율',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            '안정 기억 단계 / 전체 단어',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: 82,
            height: 82,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 6,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    palette.iconSurface.withValues(alpha: 0.86),
                  ),
                ),
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(palette.review),
                ),
                Center(
                  child: Text(
                    '$percent%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: palette.brand,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CompactMetricTile(
                  label: '전체 단어',
                  value: '$totalWordCount',
                  accentColor: palette.brand,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CompactMetricTile(
                  label: '안정 기억',
                  value: '$matureCount',
                  accentColor: palette.review,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AiLearningHeroCard extends StatelessWidget {
  final _ShellPalette palette;

  const _AiLearningHeroCard({required this.palette});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(34),
        gradient: LinearGradient(
          colors: [
            palette.review.withValues(alpha: 0.18),
            palette.accent.withValues(alpha: 0.12),
            palette.iconSurface.withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(color: palette.border.withValues(alpha: 0.58)),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.sparkles, color: palette.brand, size: 30),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '단어장을 AI 자료로 확장',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  'API 한도에 도달하면 설정된 대체 모델로 이어서 시도합니다.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.42,
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

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }
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
                        builder:
                            (_) => const QuizScreen(
                              initialMode: QuizMode.reviewSpelling,
                              origin: LearningRouteOrigin.review,
                            ),
                      ),
                    )
                    : null,
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Flashcards',
            subtitle: '전체 카드 또는 새 단어 카드 학습으로 이어집니다.',
            icon: CupertinoIcons.layers_alt_fill,
            accentColor: palette.brand,
            onTap:
                () => Navigator.of(
                  context,
                ).push(
                  MaterialPageRoute(
                    builder: (_) => const FlashcardScreen(origin: LearningRouteOrigin.review),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'Self Test',
            subtitle: '객관식과 스펠링을 시작합니다.',
            icon: CupertinoIcons.pencil_outline,
            accentColor: palette.info,
            onTap:
                () => Navigator.of(
                  context,
                ).push(
                  MaterialPageRoute(
                    builder: (_) => const QuizScreen(origin: LearningRouteOrigin.review),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: '오답 다시 확인',
            subtitle: '틀린 문제를 같은 유형으로 먼저 다시 확인합니다.',
            icon: CupertinoIcons.arrow_2_circlepath_circle_fill,
            accentColor: palette.warning,
            onTap: () => _openMistakeReview(context),
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
            '예문, 퀴즈, 문법 연습을 시작합니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _AiReadinessCard(
            palette: palette,
            onOpenSettings: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AppSettingsScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _AiBetaSummaryCard(palette: palette),
          const SizedBox(height: 16),
          _ActionCard(
            title: 'AI 예문 생성',
            subtitle: '예문과 번역을 채웁니다.',
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
            title: 'AI 퀴즈 생성',
            subtitle: '단어장 맞춤 문제를 만듭니다.',
            icon: CupertinoIcons.sparkles,
            accentColor: palette.success,
            onTap:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AiQuizSetupScreen())),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'AI 문법 체크',
            subtitle: '문법 범위별 문제를 만듭니다.',
            icon: CupertinoIcons.text_cursor,
            accentColor: palette.accent,
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiGrammarQuizSetupScreen()),
                ),
          ),
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
            subtitle: '복습 일정과 단계 분포를 봅니다.',
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

class _DeckReviewNotice {
  final String label;
  final bool isDue;
  final bool isOverdue;

  const _DeckReviewNotice({
    required this.label,
    this.isDue = false,
    this.isOverdue = false,
  });
}

class _DeckStats {
  final int totalCount;
  final int fullCount;
  final int lockedCount;
  final bool isPlanScoped;
  final int reviewCount;
  final int newCount;
  final int learningCount;
  final int matureCount;
  final String? nextReviewLabel;
  final bool hasDueReviewNotice;
  final bool hasOverdueReviewNotice;

  const _DeckStats({
    required this.totalCount,
    this.fullCount = 0,
    this.lockedCount = 0,
    this.isPlanScoped = false,
    required this.reviewCount,
    required this.newCount,
    required this.learningCount,
    required this.matureCount,
    this.nextReviewLabel,
    this.hasDueReviewNotice = false,
    this.hasOverdueReviewNotice = false,
  });

  int get focusCount => reviewCount + newCount + learningCount;
  double get masteryRatio => totalCount == 0 ? 0.0 : matureCount / totalCount;
}
