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
import '../services/study_history_service.dart';
import '../services/study_schedule_service.dart';
import '../services/today_learning_summary_service.dart';
import '../themes/app_theme.dart';
import '../themes/memorize_identity.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/google_account_avatar.dart';
import '../widgets/study_guide.dart';
import '../widgets/study_plan_panel.dart';
import '../widgets/study_calendar.dart';
import '../widgets/bundle_history_panel.dart';
import '../widgets/wordbook_selection_dialog.dart';
import 'mistake_review_screen.dart';
import 'ai_grammar_quiz_setup_screen.dart';
import 'ai_quiz_setup_screen.dart';
import 'app_settings_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'srs_status_screen.dart';
import 'wordbook_management_screen.dart';

enum _ShellTab { home, review, stats, calendar, ai, settings }

Future<void> _openMistakeReview(BuildContext context) async {
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const MistakeReviewScreen(cumulative: true),
    ),
  );
}

Future<void> _selectActiveWordbook(BuildContext context) async {
  final selectedWordbook = await showWordbookSelectionDialog(context);
  if (selectedWordbook == null || !context.mounted) return;
  await context.read<WordbookManager>().setActiveWordbook(selectedWordbook);
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
        background: Color(0xFF0E1729),
        topBar: Color(0xFF17233A),
        iconSurface: Color(0xFF22314D),
        navBackground: Color(0xFF17233A),
        navIndicator: Color(0xFF22314D),
        border: Color(0xFF33445F),
        brand: Color(0xFF4F8FFF),
        accent: Color(0xFF4F8FFF),
        review: Color(0xFFFF756E),
        info: Color(0xFF85B5FF),
        success: Color(0xFF38C98B),
        warning: Color(0xFFFFB454),
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
      background: Color(0xFFF8FAFD),
      topBar: Color(0xFFFFFFFF),
      iconSurface: Color(0xFFEAF4FF),
      navBackground: Color(0xFFFFFFFF),
      navIndicator: Color(0xFFEAF4FF),
      border: Color(0xFFD9E2F0),
      brand: Color(0xFF09255A),
      accent: Color(0xFF1E73F7),
      review: Color(0xFFFF5B55),
      info: Color(0xFF1E73F7),
      success: Color(0xFF00B875),
      warning: Color(0xFFE77B12),
    );
  }
}

class AppShellScreen extends StatefulWidget {
  const AppShellScreen({super.key});

  @override
  State<AppShellScreen> createState() => _AppShellScreenState();
}

class _AppShellScreenState extends State<AppShellScreen> with RestorationMixin {
  static const _guideSeenKey = 'memorize_me.study_guide_seen_v1';
  static const _lastShellTabKey = 'memorize_me.last_shell_tab';

  final SrsService _srsService = SrsService();
  final RestorableInt _restoredTabIndex = RestorableInt(0);
  final Map<Object, Future<_DeckStats>> _deckStatsFutures = {};
  _ShellTab _currentTab = _ShellTab.home;
  bool _tabRestoredFromState = false;
  int? _cachedStatsRevision;
  bool _guideCheckStarted = false;
  DateTime? _calendarTargetDate;
  bool _calendarPlanScope = false;
  int _homeWordbookPagerRevision = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_tabRestoredFromState) _restoreLastTab();
      _maybeShowFirstRunGuide();
    });
  }

  @override
  String? get restorationId => 'app_shell';

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_restoredTabIndex, 'selected_tab');
    if (_restoredTabIndex.value >= 0 &&
        _restoredTabIndex.value < _ShellTab.values.length) {
      _currentTab = _ShellTab.values[_restoredTabIndex.value];
      _tabRestoredFromState = _restoredTabIndex.value != 0;
    }
  }

  @override
  void dispose() {
    _restoredTabIndex.dispose();
    super.dispose();
  }

  Future<void> _restoreLastTab() async {
    final prefs = await SharedPreferences.getInstance();
    final tabName = prefs.getString(_lastShellTabKey);
    if (tabName == null || _tabRestoredFromState) return;

    for (final tab in _ShellTab.values) {
      if (tab.name == tabName) {
        if (!mounted) return;
        setState(() {
          _currentTab = tab;
          _restoredTabIndex.value = tab.index;
        });
        return;
      }
    }
  }

  void _selectTab(int index) {
    final nextTab = _ShellTab.values[index];
    setState(() {
      if (nextTab == _ShellTab.home) {
        _homeWordbookPagerRevision++;
      }
      _currentTab = nextTab;
      _restoredTabIndex.value = index;
    });
    context.read<AnalyticsService>().logTabViewed(nextTab.name);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_lastShellTabKey, nextTab.name),
    );
  }

  void _openCalendarOn(DateTime date, bool usePlanScope) {
    _calendarTargetDate = studyDay(date);
    _calendarPlanScope = usePlanScope;
    _selectTab(_ShellTab.values.indexOf(_ShellTab.calendar));
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

  Future<_DeckStats> _statsForWordbook(
    WordbookManager manager,
    Wordbook wordbook,
  ) {
    return _deckStatsFutures.putIfAbsent(_wordbookKey(wordbook), () async {
      final words = await manager.getAllWordsFrom(wordbook);
      final studyPlan = manager.planFor(wordbook);
      final scopedWords = manager.wordsAvailableForPlan(words, plan: studyPlan);
      final isPlanScoped = studyPlan?.status == StudyPlanStatus.active;
      final plan = _srsService.buildDailyPlan(scopedWords);
      final reviewNotice = _reviewNoticeForWords(
        scopedWords,
        plan.dueWords.length,
      );
      return _DeckStats(
        totalCount: isPlanScoped ? scopedWords.length : words.length,
        fullCount: words.length,
        lockedCount:
            isPlanScoped
                ? manager.lockedNewWordCount(words, plan: studyPlan)
                : 0,
        isPlanScoped: isPlanScoped,
        reviewCount: plan.dueWords.length,
        newCount: plan.newWords.length,
        learningCount: plan.learningWords.length,
        scheduledCount: plan.scheduledWords.length,
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
      if (nearest == null || reviewDate.isBefore(nearest)) {
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
                            MaterialPageRoute(
                              builder: (_) => const AppSettingsScreen(),
                            ),
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
    final identity = MemorizeIdentity.of(theme);
    final isDark = theme.brightness == Brightness.dark;
    // Every primary tab now owns its page title and context. Keeping the
    // legacy shared app bar above only some tabs made the rebuilt screens feel
    // like different products.
    const usesIdentityHeader = true;
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
    final routineWords = manager.wordsAvailableForPlan(
      words,
      plan: activeStudyPlan,
    );
    final dailyPlan = _srsService.buildDailyPlan(routineWords);
    final fullDailyPlan = _srsService.buildDailyPlan(words);
    final routineWordCount = routineWords.length;
    final lockedNewWordCount = manager.lockedNewWordCount(
      words,
      plan: activeStudyPlan,
    );
    final plannedNewWordSessionCount = manager.plannedNewWordSessionCount(
      words,
      plan: activeStudyPlan,
    );
    final newWordSessionCount = manager.recommendedNewWordSessionCount(
      words,
      plan: activeStudyPlan,
    );
    final learningScopeSubtitle = _learningScopeSubtitle(
      activeWordbook,
      activeStudyPlan,
    );

    return Scaffold(
      backgroundColor:
          usesIdentityHeader ? identity.canvas : palette.background,
      body: SafeArea(
        child: Column(
          children: [
            if (!usesIdentityHeader)
              DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.topBar,
                  border: Border(
                    bottom: BorderSide(
                      color: palette.border.withValues(
                        alpha: isDark ? 0.52 : 0.78,
                      ),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? Colors.black : palette.border)
                          .withValues(alpha: isDark ? 0.24 : 0.34),
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
                                  builder:
                                      (_) => const WordbookManagementScreen(),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.iconSurface.withValues(
                                      alpha: isDark ? 0.72 : 0.92,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: palette.border.withValues(
                                        alpha: isDark ? 0.72 : 0.82,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    learningScopeSubtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
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
                        onTap:
                            () => _showProfileSheet(
                              context,
                              theme,
                              manager,
                              dailyPlan,
                              user,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: ColoredBox(
                color:
                    usesIdentityHeader ? identity.canvas : palette.background,
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
                  currentTheme: currentTheme,
                  onThemeTap: _cycleTheme,
                  onProfileTap:
                      () => _showProfileSheet(
                        context,
                        theme,
                        manager,
                        dailyPlan,
                        user,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: identity.surface,
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
        child: NavigationBarTheme(
          data: theme.navigationBarTheme.copyWith(
            backgroundColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            elevation: 0,
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                size: selected ? 24 : 22,
                color: selected ? identity.primaryAction : identity.mutedInk,
              );
            }),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 10,
                height: 1.1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                color: selected ? identity.primaryAction : identity.mutedInk,
                fontFamilyFallback: AppTheme.systemFontFallback,
              );
            }),
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            indicatorColor: Colors.transparent,
            selectedIndex: _ShellTab.values.indexOf(_currentTab),
            height: 72,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: _selectTab,
            destinations: const [
              NavigationDestination(
                icon: Icon(CupertinoIcons.house),
                label: '홈',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.play),
                label: '학습',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.chart_bar),
                label: '통계',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.calendar),
                label: '달력',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.sparkles),
                label: 'AI 학습',
              ),
              NavigationDestination(
                icon: Icon(CupertinoIcons.settings),
                label: '설정',
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _learningScopeSubtitle(
    Wordbook? activeWordbook,
    StudyPlan? studyPlan,
  ) {
    if (activeWordbook == null) return '현재 학습 기준 선택 필요';
    if (studyPlan == null || studyPlan.status != StudyPlanStatus.active) {
      return '현재 학습 기준 · ${activeWordbook.name} 전체';
    }
    return '${activeWordbook.name} · ${studyPlan.scopeLabel}';
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
    required AppThemeType currentTheme,
    required VoidCallback onThemeTap,
    required VoidCallback onProfileTap,
  }) {
    switch (_currentTab) {
      case _ShellTab.home:
        return _BloomHomeDashboardTab(
          dailyPlan: dailyPlan,
          studyPlan: activeStudyPlan,
          plannedNewWordSessionCount: plannedNewWordSessionCount,
          newWordSessionCount: newWordSessionCount,
          user: user,
          activeWordbook: activeWordbook,
          plannedWordbookDbNames: plannedWordbookDbNames,
          wordbooks: manager.wordbooks,
          statsForWordbook: (wordbook) => _statsForWordbook(manager, wordbook),
          wordbookPagerRevision: _homeWordbookPagerRevision,
          currentTheme: currentTheme,
          onThemeTap: onThemeTap,
          onProfileTap: onProfileTap,
        );
      case _ShellTab.review:
        return _BloomReviewTab(
          dailyPlan: dailyPlan,
          activeWordbook: activeWordbook,
        );
      case _ShellTab.stats:
        return _BloomStatsTab(
          fullDailyPlan: fullDailyPlan,
          planDailyPlan: dailyPlan,
          totalWordCount: totalWordCount,
          planWordCount: routineWordCount,
          activeStudyPlan: activeStudyPlan,
          lockedNewWordCount: lockedNewWordCount,
          activeWordbook: activeWordbook,
          onOpenCalendar: _openCalendarOn,
        );
      case _ShellTab.ai:
        return _BloomAiLearningTab(
          learningScopeSubtitle: learningScopeSubtitle,
          onOpenSettings:
              () => _selectTab(_ShellTab.values.indexOf(_ShellTab.settings)),
        );
      case _ShellTab.calendar:
        return SingleChildScrollView(
          key: const PageStorageKey('calendar-tab'),
          padding: EdgeInsets.fromLTRB(16, 16, 16, 22),
          child: StudyCalendar(
            key: ValueKey(
              '${_calendarTargetDate?.toIso8601String()}-$_calendarPlanScope',
            ),
            initialDate: _calendarTargetDate,
            initialPlanScope: _calendarPlanScope,
          ),
        );
      case _ShellTab.settings:
        return const AppSettingsScreen();
    }
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
                color: theme.colorScheme.surface.withValues(
                  alpha: isDark ? 0.36 : 0.72,
                ),
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
              child: Icon(_themeIcon, color: palette.accent, size: 23),
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

  const _ProfileAvatarButton({required this.user, required this.onTap});

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
      return GoogleAccountAvatar(account: user!, radius: radius);
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: palette.iconSurface,
      child: Icon(
        CupertinoIcons.person_crop_circle,
        size: radius * 1.35,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _BloomHomeDashboardTab extends StatefulWidget {
  final DailyLearningPlan dailyPlan;
  final StudyPlan? studyPlan;
  final int plannedNewWordSessionCount;
  final int newWordSessionCount;
  final GoogleSignInAccount? user;
  final Wordbook? activeWordbook;
  final Set<String> plannedWordbookDbNames;
  final List<Wordbook> wordbooks;
  final Future<_DeckStats> Function(Wordbook wordbook) statsForWordbook;
  final int wordbookPagerRevision;
  final AppThemeType currentTheme;
  final VoidCallback onThemeTap;
  final VoidCallback onProfileTap;

  const _BloomHomeDashboardTab({
    required this.dailyPlan,
    required this.studyPlan,
    required this.plannedNewWordSessionCount,
    required this.newWordSessionCount,
    required this.user,
    required this.activeWordbook,
    required this.plannedWordbookDbNames,
    required this.wordbooks,
    required this.statsForWordbook,
    required this.wordbookPagerRevision,
    required this.currentTheme,
    required this.onThemeTap,
    required this.onProfileTap,
  });

  @override
  State<_BloomHomeDashboardTab> createState() => _BloomHomeDashboardTabState();
}

class _BloomHomeDashboardTabState extends State<_BloomHomeDashboardTab> {
  final SrsService _srsService = SrsService();
  final StudyHistoryService _historyService = StudyHistoryService.instance;
  final TodayLearningSummaryService _todaySummaryService =
      TodayLearningSummaryService();

  @override
  void initState() {
    super.initState();
    _historyService.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _historyService.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final dailyPlan = widget.dailyPlan;
    final activeWordbook = widget.activeWordbook;
    final wordbooks = widget.wordbooks;
    final statsForWordbook = widget.statsForWordbook;
    final newCount = widget.newWordSessionCount;
    final routineWords = <Word>[
      ...dailyPlan.dueWords,
      ...dailyPlan.newWords,
      ...dailyPlan.learningWords,
      ...dailyPlan.scheduledWords,
      ...dailyPlan.matureWords,
    ];
    final todaySummary = _todaySummaryService.build(
      words: routineWords,
      dbFileName: activeWordbook?.dbFileName,
      plan: widget.studyPlan,
      plannedNewWordCount: widget.plannedNewWordSessionCount,
      sessions: _historyService.sessions,
    );
    final remainingTodayFocus = todaySummary.remainingCount;
    final dashboardWordbooks = _prioritizeActiveWordbook(
      wordbooks,
      activeWordbook,
    );
    final hasActiveWordbook = activeWordbook != null;
    final today = _srsService.today();
    final tomorrow = today.add(const Duration(days: 1));
    final followingDay = today.add(const Duration(days: 2));
    final tomorrowReviewCount = _scheduledReviewCount(dailyPlan, tomorrow);
    final followingReviewCount = _scheduledReviewCount(dailyPlan, followingDay);
    final activeScopeLabel =
        !hasActiveWordbook
            ? '학습 단어장을 선택하세요'
            : widget.studyPlan?.status == StudyPlanStatus.active
            ? '${activeWordbook.name} · ${widget.studyPlan!.progressLabel}'
            : '${activeWordbook.name} · 전체';
    final todayOutcomeLabel =
        widget.studyPlan?.status == StudyPlanStatus.active
            ? '${widget.studyPlan!.progressLabel} 진행'
            : '오늘 목표 완료';
    return SingleChildScrollView(
      key: const PageStorageKey<String>('memorize-home-identity-v1'),
      padding: const EdgeInsets.fromLTRB(
        MemorizeIdentity.pagePadding,
        14,
        MemorizeIdentity.pagePadding,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeIdentityHeader(
            user: widget.user,
            currentTheme: widget.currentTheme,
            onThemeTap: widget.onThemeTap,
            onProfileTap: widget.onProfileTap,
            identity: identity,
          ),
          const SizedBox(height: 14),
          _HomeWordbookContext(
            label: activeScopeLabel,
            enabled: hasActiveWordbook,
            identity: identity,
            onTap: () => _selectActiveWordbook(context),
          ),
          const SizedBox(height: 22),
          _HomeTodayHeading(
            remainingCount: remainingTodayFocus,
            hasActiveWordbook: hasActiveWordbook,
            onGuideTap:
                () => showStudyGuideSheet(
                  context,
                  StudyGuideCatalog.todayRoutine,
                ),
            identity: identity,
          ),
          const SizedBox(height: 16),
          _HomeTodayFocusPanel(
            summary: todaySummary,
            hasActiveWordbook: hasActiveWordbook,
            identity: identity,
            onActionTap:
                () => _startRecommendedLearning(
                  context,
                  todaySummary.remainingWords,
                ),
            onExplanationTap:
                () => _showTodayGoalExplanation(context, todaySummary),
          ),
          const SizedBox(height: MemorizeIdentity.sectionGap),
          Divider(color: identity.border, height: 1),
          const SizedBox(height: 18),
          _HomeLearningFlow(
            hasActiveWordbook: hasActiveWordbook,
            newCount: newCount,
            todayOutcomeLabel: todayOutcomeLabel,
            tomorrow: tomorrow,
            tomorrowReviewCount: tomorrowReviewCount,
            followingDay: followingDay,
            followingReviewCount: followingReviewCount,
            identity: identity,
          ),
          if (widget.studyPlan != null) ...[
            const SizedBox(height: MemorizeIdentity.sectionGap),
            _StudyPlanStatusCard(plan: widget.studyPlan!),
          ],
          const SizedBox(height: MemorizeIdentity.sectionGap),
          _SectionHeader(
            title: '내 단어장',
            actionLabel: '단어장 관리',
            homeStyle: true,
            onActionTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const WordbookManagementScreen(),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          _WordbookStatusPager(
            key: ValueKey(
              'home-wordbook-pager-${widget.wordbookPagerRevision}',
            ),
            wordbooks: dashboardWordbooks,
            activeWordbook: activeWordbook,
            plannedWordbookDbNames: widget.plannedWordbookDbNames,
            statsForWordbook: statsForWordbook,
          ),
        ],
      ),
    );
  }

  void _startRecommendedLearning(
    BuildContext context,
    List<Word> remainingWords,
  ) {
    if (widget.activeWordbook == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WordbookManagementScreen()),
      );
      return;
    }
    if (remainingWords.isNotEmpty &&
        remainingWords.every((word) => _srsService.isDueForReview(word))) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => FlashcardScreen(
                initialMode: FlashcardLaunchMode.review,
                origin: LearningRouteOrigin.home,
                reviewWordsOverride: remainingWords,
              ),
        ),
      );
      return;
    }
    if (remainingWords.isNotEmpty &&
        remainingWords.every(_srsService.isNewWord) &&
        widget.newWordSessionCount > 0) {
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
    if (remainingWords.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => FlashcardScreen(
                initialMode: FlashcardLaunchMode.allWords,
                origin: LearningRouteOrigin.home,
                reviewWordsOverride: remainingWords,
              ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => const FlashcardScreen(
              initialMode: FlashcardLaunchMode.allWords,
              origin: LearningRouteOrigin.home,
            ),
      ),
    );
  }

  void _showTodayGoalExplanation(
    BuildContext context,
    TodayLearningSummary summary,
  ) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: identity.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder:
          (context) => SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '오늘 범위는 이렇게 계산해요',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary.additionalCount > 0
                        ? '기본 ${summary.baseCount}개 + 추가 ${summary.additionalCount}개 = 오늘 범위 ${summary.totalCount}개'
                        : '기본 ${summary.baseCount}개 = 오늘 범위 ${summary.totalCount}개',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    summary.mistakeCount == 0
                        ? '오늘의 기본 학습 플랜만 반영되어 있어요.'
                        : '오늘 카드·객관식·스펠링에서 다시 확인이 필요했던 ${summary.mistakeCount}개 중 기본 목표와 겹친 ${summary.overlappingMistakeCount}개는 한 번만 계산했어요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: identity.mutedInk,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: identity.softInfo,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '같은 단어를 여러 방식으로 학습해도 중복되지 않으며, 다시 맞혀 SRS의 복습 필요가 해소되면 완료 수만 올라갑니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  int _scheduledReviewCount(DailyLearningPlan plan, DateTime date) {
    final words = <Word>[
      ...plan.dueWords,
      ...plan.newWords,
      ...plan.learningWords,
      ...plan.scheduledWords,
      ...plan.matureWords,
    ];
    return words.where((word) {
      final reviewDate = _srsService.reviewDateFor(word);
      return reviewDate != null &&
          reviewDate.year == date.year &&
          reviewDate.month == date.month &&
          reviewDate.day == date.day;
    }).length;
  }

  List<Wordbook> _prioritizeActiveWordbook(
    List<Wordbook> source,
    Wordbook? active,
  ) {
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

class _HomeIdentityHeader extends StatelessWidget {
  final GoogleSignInAccount? user;
  final AppThemeType currentTheme;
  final VoidCallback onThemeTap;
  final VoidCallback onProfileTap;
  final MemorizeIdentity identity;

  const _HomeIdentityHeader({
    required this.user,
    required this.currentTheme,
    required this.onThemeTap,
    required this.onProfileTap,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            'Memorize Me',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 20,
              height: 1.2,
              fontWeight: FontWeight.w900,
              color: identity.ink,
              fontStyle: FontStyle.normal,
            ),
          ),
        ),
        _HomeThemeButton(
          currentTheme: currentTheme,
          onTap: onThemeTap,
          identity: identity,
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: '프로필',
          child: InkWell(
            onTap: onProfileTap,
            borderRadius: BorderRadius.circular(999),
            child: _UserAvatar(user: user, radius: 20),
          ),
        ),
      ],
    );
  }
}

class _HomeThemeButton extends StatelessWidget {
  final AppThemeType currentTheme;
  final VoidCallback onTap;
  final MemorizeIdentity identity;

  const _HomeThemeButton({
    required this.currentTheme,
    required this.onTap,
    required this.identity,
  });

  IconData get _icon => switch (currentTheme) {
    AppThemeType.lightGreen => CupertinoIcons.sun_max,
    AppThemeType.dark => CupertinoIcons.moon,
    AppThemeType.visionProtection => CupertinoIcons.eye,
  };

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '테마 변경',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(_icon, size: 20, color: identity.primaryAction),
        ),
      ),
    );
  }
}

class _HomeWordbookContext extends StatelessWidget {
  final String label;
  final bool enabled;
  final MemorizeIdentity identity;
  final VoidCallback onTap;

  const _HomeWordbookContext({
    required this.label,
    required this.enabled,
    required this.identity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: identity.softContext,
      borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.book,
                  color: enabled ? identity.success : identity.mutedInk,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: enabled ? identity.ink : identity.mutedInk,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: identity.mutedInk,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeTodayHeading extends StatelessWidget {
  final int remainingCount;
  final bool hasActiveWordbook;
  final VoidCallback onGuideTap;
  final MemorizeIdentity identity;

  const _HomeTodayHeading({
    required this.remainingCount,
    required this.hasActiveWordbook,
    required this.onGuideTap,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        !hasActiveWordbook
            ? '학습할 단어장을 준비하세요'
            : remainingCount == 0
            ? '오늘 학습을 모두 마쳤어요'
            : '남은 학습 $remainingCount개';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '오늘 학습',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontSize: 30,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  color: identity.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: identity.mutedInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onGuideTap,
          tooltip: '오늘 학습 설명',
          color: identity.mutedInk,
          icon: const Icon(CupertinoIcons.question_circle, size: 20),
        ),
      ],
    );
  }
}

class _HomeTodayFocusPanel extends StatelessWidget {
  final TodayLearningSummary summary;
  final bool hasActiveWordbook;
  final MemorizeIdentity identity;
  final VoidCallback onActionTap;
  final VoidCallback onExplanationTap;

  const _HomeTodayFocusPanel({
    required this.summary,
    required this.hasActiveWordbook,
    required this.identity,
    required this.onActionTap,
    required this.onExplanationTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        final ringSize = min(
          184.0,
          max(158.0, constraints.maxWidth * (compact ? 0.68 : 0.51)),
        );
        final ring = _HomeGoalRing(
          summary: summary,
          identity: identity,
          size: ringSize,
        );
        final details = _HomeFocusDetails(
          summary: summary,
          hasActiveWordbook: hasActiveWordbook,
          identity: identity,
          onActionTap: onActionTap,
          onExplanationTap: onExplanationTap,
        );

        if (compact) {
          return Column(children: [ring, const SizedBox(height: 16), details]);
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [ring, const SizedBox(width: 14), Expanded(child: details)],
        );
      },
    );
  }
}

class _HomeGoalRing extends StatefulWidget {
  final TodayLearningSummary summary;
  final MemorizeIdentity identity;
  final double size;

  const _HomeGoalRing({
    required this.summary,
    required this.identity,
    required this.size,
  });

  @override
  State<_HomeGoalRing> createState() => _HomeGoalRingState();
}

class _HomeGoalRingState extends State<_HomeGoalRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final reduceMotion = media.disableAnimations || media.accessibleNavigation;
    return Semantics(
      label:
          '오늘 학습 범위 ${widget.summary.totalCount}개, 기본 ${widget.summary.baseCount}개, 추가 ${widget.summary.additionalCount}개, 완료 ${widget.summary.completedCount}개, 남음 ${widget.summary.remainingCount}개',
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            final glow =
                reduceMotion ? 0.34 : 0.24 + (_glowController.value * 0.22);
            return Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _HomeGoalRingPainter(
                      baseCount: widget.summary.baseCount,
                      additionalCount: widget.summary.additionalCount,
                      progress: widget.summary.progress,
                      baseColor: widget.identity.primaryAction,
                      additionalColor: widget.identity.scheduled,
                      progressColor: widget.identity.success,
                      emptyColor: widget.identity.border.withValues(alpha: 0.7),
                      glowOpacity: glow,
                    ),
                  ),
                ),
                SizedBox(
                  width: widget.size * 0.58,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.summary.additionalCount > 0)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _HomeGoalNumber(
                              label: '기본',
                              value: widget.summary.baseCount,
                              color: widget.identity.primaryAction,
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(7, 0, 7, 7),
                              child: Text(
                                '+',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: widget.identity.mutedInk,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _HomeGoalNumber(
                              label: '추가',
                              value: widget.summary.additionalCount,
                              color: widget.identity.scheduled,
                            ),
                          ],
                        )
                      else
                        _HomeGoalNumber(
                          label: '기본',
                          value: widget.summary.baseCount,
                          color: widget.identity.primaryAction,
                        ),
                      const SizedBox(height: 7),
                      Divider(height: 1, color: widget.identity.border),
                      const SizedBox(height: 8),
                      Text(
                        '오늘 범위 ${widget.summary.totalCount}개',
                        maxLines: 1,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: widget.identity.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.summary.completedCount}개 완료 · ${widget.summary.remainingCount}개 남음',
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: widget.identity.mutedInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HomeGoalNumber extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _HomeGoalNumber({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        Text(
          '$value',
          style: theme.textTheme.headlineMedium?.copyWith(
            height: 1.05,
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _HomeGoalRingPainter extends CustomPainter {
  final int baseCount;
  final int additionalCount;
  final double progress;
  final Color baseColor;
  final Color additionalColor;
  final Color progressColor;
  final Color emptyColor;
  final double glowOpacity;

  const _HomeGoalRingPainter({
    required this.baseCount,
    required this.additionalCount,
    required this.progress,
    required this.baseColor,
    required this.additionalColor,
    required this.progressColor,
    required this.emptyColor,
    required this.glowOpacity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = max(0, baseCount + additionalCount);
    final scopeStroke = max(16.0, size.shortestSide * 0.115);
    final progressStroke = scopeStroke - 5;
    final radius = (size.shortestSide - scopeStroke) / 2;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius,
    );
    const startAngle = -pi / 2;
    const fullSweep = -pi * 2;

    final scopePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = scopeStroke
          ..strokeCap = StrokeCap.butt;

    if (total == 0) {
      scopePaint.color = emptyColor;
      canvas.drawArc(rect, startAngle, fullSweep, false, scopePaint);
      return;
    }

    final baseSweep = fullSweep * (baseCount / total);
    final additionalSweep = fullSweep - baseSweep;
    if (baseCount > 0) {
      scopePaint.color = baseColor;
      canvas.drawArc(rect, startAngle, baseSweep, false, scopePaint);
    }
    if (additionalCount > 0) {
      scopePaint.color = additionalColor;
      canvas.drawArc(
        rect,
        startAngle + baseSweep,
        additionalSweep,
        false,
        scopePaint,
      );
    }

    final safeProgress = progress.clamp(0.0, 1.0).toDouble();
    if (safeProgress <= 0) return;
    final progressSweep = fullSweep * safeProgress;
    final progressPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = progressStroke
          ..strokeCap = StrokeCap.round
          ..color = progressColor;
    canvas.drawArc(rect, startAngle, progressSweep, false, progressPaint);

    final endAngle = startAngle + progressSweep;
    final endpoint = Offset(
      rect.center.dx + radius * cos(endAngle),
      rect.center.dy + radius * sin(endAngle),
    );
    canvas.drawCircle(
      endpoint,
      progressStroke * 0.76,
      Paint()
        ..color = progressColor.withValues(alpha: glowOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      endpoint,
      progressStroke / 2,
      Paint()..color = progressColor,
    );
    canvas.drawCircle(
      endpoint,
      progressStroke * 0.34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      endpoint.translate(-progressStroke * 0.13, -progressStroke * 0.14),
      1.35,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
  }

  @override
  bool shouldRepaint(covariant _HomeGoalRingPainter oldDelegate) {
    return oldDelegate.baseCount != baseCount ||
        oldDelegate.additionalCount != additionalCount ||
        oldDelegate.progress != progress ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.additionalColor != additionalColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.emptyColor != emptyColor ||
        oldDelegate.glowOpacity != glowOpacity;
  }
}

class _HomeFocusDetails extends StatelessWidget {
  final TodayLearningSummary summary;
  final bool hasActiveWordbook;
  final MemorizeIdentity identity;
  final VoidCallback onActionTap;
  final VoidCallback onExplanationTap;

  const _HomeFocusDetails({
    required this.summary,
    required this.hasActiveWordbook,
    required this.identity,
    required this.onActionTap,
    required this.onExplanationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalText =
        !hasActiveWordbook
            ? '학습할 단어장을\n준비해 주세요'
            : summary.remainingCount == 0
            ? '오늘 학습을\n마쳤어요'
            : '오늘 ${summary.remainingCount}개가\n남았어요';
    final reasonText =
        !hasActiveWordbook
            ? '단어장을 선택하면 오늘 범위를 계산해요.'
            : summary.additionalCount > 0
            ? '기본 목표와 중복을 뺀 오답 ${summary.additionalCount}개가 추가됐어요.'
            : summary.remainingCount == 0
            ? '오늘 기본 목표를 모두 완료했어요.'
            : '같은 단어는 여러 번 학습해도 한 번만 계산해요.';
    final actionTitle =
        !hasActiveWordbook
            ? '단어장 만들기'
            : summary.remainingCount == 0
            ? '전체 카드 보기'
            : '${summary.remainingCount}개 학습 시작';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          goalText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            height: 1.18,
            fontWeight: FontWeight.w900,
            color: identity.ink,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          reasonText,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: identity.mutedInk,
            height: 1.42,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 13),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: onActionTap,
            style: FilledButton.styleFrom(
              backgroundColor: identity.primaryAction,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            child: Text(
              actionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ),
        if (hasActiveWordbook) ...[
          const SizedBox(height: 3),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: onExplanationTap,
              style: TextButton.styleFrom(
                foregroundColor: identity.primaryAction,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 38),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(CupertinoIcons.question_circle, size: 17),
              label: Text(
                summary.additionalCount > 0 ? '왜 늘어났나요?' : '범위 계산 기준',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HomeLearningFlow extends StatelessWidget {
  final bool hasActiveWordbook;
  final int newCount;
  final String todayOutcomeLabel;
  final DateTime tomorrow;
  final int tomorrowReviewCount;
  final DateTime followingDay;
  final int followingReviewCount;
  final MemorizeIdentity identity;

  const _HomeLearningFlow({
    required this.hasActiveWordbook,
    required this.newCount,
    required this.todayOutcomeLabel,
    required this.tomorrow,
    required this.tomorrowReviewCount,
    required this.followingDay,
    required this.followingReviewCount,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '학습 흐름',
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: identity.ink,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          child:
              !hasActiveWordbook
                  ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      '단어장을 선택하면 오늘 학습과 다음 복습 흐름을 보여드려요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _HomeDateMarker(
                              label: '오늘',
                              foreground: identity.success,
                              background: identity.softSuccess,
                            ),
                          ),
                          _HomeTimelineConnector(color: identity.border),
                          Expanded(
                            child: _HomeDateMarker(
                              label: '${tomorrow.day}일',
                              foreground: identity.review,
                              background: identity.softReview,
                            ),
                          ),
                          _HomeTimelineConnector(color: identity.border),
                          Expanded(
                            child: _HomeDateMarker(
                              label: '${followingDay.day}일',
                              foreground: identity.primaryAction,
                              background: identity.softInfo,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _HomeTimelineText(
                              label: '학습 후',
                              value: '새 단어 $newCount개',
                              helper: todayOutcomeLabel,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HomeTimelineText(
                              label: '내일',
                              value: '복습 $tomorrowReviewCount개',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HomeTimelineText(
                              label:
                                  '${followingDay.month}월 ${followingDay.day}일',
                              value: '복습 $followingReviewCount개',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Divider(color: identity.border, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.info_circle,
                            size: 16,
                            color: identity.mutedInk,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              '학습 결과에 따라 일정이 달라질 수 있어요.',
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
      ],
    );
  }
}

class _HomeDateMarker extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const _HomeDateMarker({
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 32,
        constraints: const BoxConstraints(minWidth: 62),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _HomeTimelineConnector extends StatelessWidget {
  final Color color;

  const _HomeTimelineConnector({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 32,
      child: Row(
        children: [
          Expanded(child: Divider(color: color, height: 1)),
          Icon(CupertinoIcons.chevron_right, size: 12, color: color),
          Expanded(child: Divider(color: color, height: 1)),
        ],
      ),
    );
  }
}

class _HomeTimelineText extends StatelessWidget {
  final String label;
  final String value;
  final String? helper;

  const _HomeTimelineText({
    required this.label,
    required this.value,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SizedBox(
          height: 20,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 25,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(
          height: 18,
          child:
              helper == null
                  ? const SizedBox.shrink()
                  : Text(
                    helper!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
        ),
      ],
    );
  }
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: palette.border.withValues(alpha: 0.86)),
        boxShadow: [
          BoxShadow(
            color: palette.brand.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.20 : 0.10,
            ),
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
                color: palette.accent,
                borderRadius: BorderRadius.circular(16),
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
                    child: Icon(
                      CupertinoIcons.play_fill,
                      color: palette.brand,
                      size: 20,
                    ),
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
                    helper: '기억 정착 중',
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

  const _StudyPlanStatusCard({required this.plan});

  @override
  Widget build(BuildContext context) =>
      StudyPlanPanel(plan: plan, homeIdentity: true);
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onActionTap;
  final bool homeStyle;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onActionTap,
    this.homeStyle = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    final identity = MemorizeIdentity.of(theme);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: homeStyle ? 22 : 18,
              fontWeight: FontWeight.w900,
              color: homeStyle ? identity.ink : theme.colorScheme.onSurface,
            ),
          ),
        ),
        TextButton(
          onPressed: onActionTap,
          style: TextButton.styleFrom(
            foregroundColor: homeStyle ? identity.ink : palette.brand,
          ),
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
    super.key,
    required this.wordbooks,
    required this.activeWordbook,
    required this.plannedWordbookDbNames,
    required this.statsForWordbook,
  });

  @override
  State<_WordbookStatusPager> createState() => _WordbookStatusPagerState();
}

class _WordbookStatusPagerState extends State<_WordbookStatusPager> {
  static const double _statusCardHeight = 170.0;
  static const int _loopAnchor = 10000;

  late final PageController _pageController;

  int _initialPageFor(int itemCount) =>
      itemCount <= 1 ? 0 : _loopAnchor - (_loopAnchor % itemCount);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _initialPageFor(widget.wordbooks.length),
      viewportFraction: 0.90,
      keepPage: false,
    );
  }

  @override
  void didUpdateWidget(covariant _WordbookStatusPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.wordbooks.isEmpty) return;

    final activeChanged =
        _wordbookIdentity(oldWidget.activeWordbook) !=
        _wordbookIdentity(widget.activeWordbook);
    final listLengthChanged =
        oldWidget.wordbooks.length != widget.wordbooks.length;
    if (activeChanged || listLengthChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        _pageController.jumpToPage(_initialPageFor(widget.wordbooks.length));
      });
    }
  }

  String? _wordbookIdentity(Wordbook? wordbook) {
    if (wordbook == null) return null;
    return wordbook.id?.toString() ?? wordbook.dbFileName;
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
          hasStudyPlan: widget.plannedWordbookDbNames.contains(
            wordbook.dbFileName,
          ),
          statsFuture: widget.statsForWordbook(wordbook),
        ),
      );
    }

    return SizedBox(
      height: _statusCardHeight,
      child: PageView.builder(
        controller: _pageController,
        padEnds: false,
        clipBehavior: Clip.hardEdge,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final wordbook = widget.wordbooks[index % widget.wordbooks.length];
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _WordbookStatusSlide(
              wordbook: wordbook,
              activeWordbook: widget.activeWordbook,
              hasStudyPlan: widget.plannedWordbookDbNames.contains(
                wordbook.dbFileName,
              ),
              statsFuture: widget.statsForWordbook(wordbook),
            ),
          );
        },
      ),
    );
  }
}

class _WordbookStatusSlide extends StatelessWidget {
  final Wordbook wordbook;
  final Wordbook? activeWordbook;
  final bool hasStudyPlan;
  final Future<_DeckStats> statsFuture;

  const _WordbookStatusSlide({
    required this.wordbook,
    required this.activeWordbook,
    required this.hasStudyPlan,
    required this.statsFuture,
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
    final identity = MemorizeIdentity.of(theme);
    final isDark = theme.brightness == Brightness.dark;
    final manager = context.read<WordbookManager>();

    return Material(
      color: _isActive ? identity.softContext : identity.surface,
      borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        onTap: () async {
          await manager.setActiveWordbook(wordbook);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('대시보드 기준 단어장을 ${wordbook.name}(으)로 바꿨습니다.')),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(
              color: _isActive ? identity.primaryAction : identity.border,
              width: _isActive ? 1.25 : 1,
            ),
          ),
          child: FutureBuilder<_DeckStats>(
            future: statsFuture,
            builder: (context, snapshot) {
              final stats = snapshot.data;
              final masteryRatio = stats?.masteryRatio ?? 0.0;
              final focusCount = stats?.focusCount ?? 0;
              final totalLabel =
                  stats == null
                      ? '현황 불러오는 중'
                      : '전체 ${stats.totalCount}개 · 집중 $focusCount개';
              final nextReviewLabel = stats?.nextReviewLabel ?? '다음 복습 일정 없음';
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CupertinoIcons.book,
                        color: identity.success,
                        size: 25,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          wordbook.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: identity.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      if (_isActive) ...[
                        const SizedBox(width: 6),
                        _CompactDeckBadge(
                          text: '선택된 단어장',
                          foreground: identity.primaryAction,
                          background: identity.softInfo,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          totalLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: identity.mutedInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasStudyPlan) ...[
                        const SizedBox(width: 6),
                        _CompactDeckBadge(
                          text: '플랜',
                          foreground: identity.success,
                          background: identity.softSuccess,
                        ),
                      ],
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        '안정 기억률',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: identity.mutedInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        stats == null
                            ? '-'
                            : '${(masteryRatio * 100).round()}%',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: identity.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value:
                          stats == null ? null : masteryRatio.clamp(0.0, 1.0),
                      minHeight: 7,
                      backgroundColor: identity.border.withValues(alpha: 0.62),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        identity.success,
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    nextReviewLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: identity.mutedInk,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CompactDeckBadge extends StatelessWidget {
  final String text;
  final Color foreground;
  final Color background;

  const _CompactDeckBadge({
    required this.text,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w900,
        ),
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
          Icon(icon, size: 15, color: color),
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
    final identity = MemorizeIdentity.of(Theme.of(context));
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

    final segments =
        [
          _BarSegment(count: data.newCount, color: palette.info),
          _BarSegment(count: data.learningCount, color: palette.warning),
          _BarSegment(count: data.scheduledCount, color: identity.scheduled),
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
          Icon(
            CupertinoIcons.rectangle_badge_checkmark,
            size: 12,
            color: palette.success,
          ),
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
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
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
                  MaterialPageRoute(
                    builder: (_) => const WordbookManagementScreen(),
                  ),
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

class _BloomReviewTab extends _ReviewTab {
  final Wordbook? activeWordbook;

  const _BloomReviewTab({
    required super.dailyPlan,
    required this.activeWordbook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final wordbookManager = context.watch<WordbookManager>();
    final activePlan = wordbookManager.planFor(activeWordbook);
    final archivedMistakeCount =
        wordbookManager.quizReviewEntries(cumulative: true).length;
    final reviewCount = dailyPlan.dueWords.length;
    final hasActiveWordbook = activeWordbook != null;
    final scopeLabel =
        !hasActiveWordbook
            ? '복습할 단어장을 선택하세요'
            : activePlan == null
            ? '${activeWordbook!.name} · 전체 단어장'
            : activePlan.mode == StudyPlanMode.free
            ? '${activeWordbook!.name} · 현재 묶음 ${activePlan.currentChunk()}/${activePlan.chunkCount}'
            : '${activeWordbook!.name} · ${activePlan.progressLabel}';

    return SingleChildScrollView(
      key: const PageStorageKey<String>('memorize-review-identity-v1'),
      padding: const EdgeInsets.fromLTRB(
        MemorizeIdentity.pagePadding,
        14,
        MemorizeIdentity.pagePadding,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '학습',
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 30,
              height: 1.12,
              fontWeight: FontWeight.w900,
              color: identity.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '오늘도 꾸준히, 더 오래 기억해요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _HomeWordbookContext(
            label: scopeLabel,
            enabled: hasActiveWordbook,
            identity: identity,
            onTap: () => _selectActiveWordbook(context),
          ),
          const SizedBox(height: 14),
          _ReviewTodayCard(
            reviewCount: reviewCount,
            hasActiveWordbook: hasActiveWordbook,
            identity: identity,
            onStart:
                reviewCount == 0 || !hasActiveWordbook
                    ? null
                    : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => const FlashcardScreen(
                              initialMode: FlashcardLaunchMode.review,
                              origin: LearningRouteOrigin.review,
                            ),
                      ),
                    ),
          ),
          const SizedBox(height: MemorizeIdentity.sectionGap),
          Divider(color: identity.border, height: 1),
          const SizedBox(height: 18),
          _ReviewSectionTitle(
            title: '단어장 공부 현황',
            subtitle: '지금까지의 학습 기록을 확인하세요.',
            identity: identity,
          ),
          const SizedBox(height: 12),
          _WordbookStudyHistoryCard(
            wordbook: activeWordbook,
            identity: identity,
          ),
          const SizedBox(height: MemorizeIdentity.sectionGap),
          Divider(color: identity.border, height: 1),
          const SizedBox(height: 18),
          _ReviewSectionTitle(
            title: '학습 방식',
            subtitle: '다양한 방식으로 단어를 복습해 보세요.',
            identity: identity,
          ),
          const SizedBox(height: 12),
          _ReviewMethodList(
            identity: identity,
            archivedMistakeCount: archivedMistakeCount,
            onFlashcard:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const FlashcardScreen(
                          origin: LearningRouteOrigin.review,
                        ),
                  ),
                ),
            onSelfTest:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const QuizScreen(
                          origin: LearningRouteOrigin.review,
                        ),
                  ),
                ),
            onMistakes: () => _startWeakReview(context),
          ),
        ],
      ),
    );
  }

  void _startWeakReview(BuildContext context) => _openMistakeReview(context);
}

class _WordbookStudyHistoryCard extends StatelessWidget {
  final Wordbook? wordbook;
  final MemorizeIdentity identity;

  const _WordbookStudyHistoryCard({
    required this.wordbook,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final service = StudyHistoryService.instance;
    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (wordbook == null) {
          return _buildCard(context, const WordbookStudyHistory());
        }
        return FutureBuilder<WordbookStudyHistory>(
          future: service.load(wordbook!.dbFileName),
          builder: (context, snapshot) {
            return _buildCard(
              context,
              snapshot.data ?? const WordbookStudyHistory(),
              loading: snapshot.connectionState == ConnectionState.waiting,
            );
          },
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    WordbookStudyHistory history, {
    bool loading = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child:
          wordbook == null
              ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  '단어장을 선택하면 학습 횟수와 최근 결과를 보여드려요.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
              : Stack(
                children: [
                  BundleHistoryPanel(
                    key: ValueKey(wordbook?.dbFileName ?? 'no-wordbook'),
                    plan: context.watch<WordbookManager>().planFor(wordbook),
                    overallHistory: history,
                    loading: loading,
                    compactSummary: true,
                    onOpenModeHistory:
                        (mode) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => QuizHistoryScreen(
                                  wordbook: wordbook!,
                                  initialMode: mode,
                                ),
                          ),
                        ),
                  ),
                  if (loading)
                    const Positioned(
                      top: 4,
                      right: 4,
                      child: SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                ],
              ),
    );
  }
}

class _ReviewSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  final MemorizeIdentity identity;

  const _ReviewSectionTitle({
    required this.title,
    required this.subtitle,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: identity.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: identity.mutedInk,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ReviewTodayCard extends StatelessWidget {
  final int reviewCount;
  final bool hasActiveWordbook;
  final MemorizeIdentity identity;
  final VoidCallback? onStart;

  const _ReviewTodayCard({
    required this.reviewCount,
    required this.hasActiveWordbook,
    required this.identity,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle =
        !hasActiveWordbook
            ? '단어장을 선택하면 오늘의 복습을 확인할 수 있어요.'
            : reviewCount == 0
            ? '오늘 예정된 복습이 없습니다.'
            : '잊기 전에 지금 복습해 보세요.';

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: identity.softReview,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  CupertinoIcons.arrow_2_circlepath,
                  color: identity.review,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '오늘의 복습',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$reviewCount',
                            style: theme.textTheme.displaySmall?.copyWith(
                              color: identity.success,
                              fontSize: 34,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: '개',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: identity.success,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '오늘 복습할 단어',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 58, color: identity.border),
              const SizedBox(width: 14),
              Expanded(
                flex: 6,
                child: FilledButton.icon(
                  onPressed: onStart,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                    backgroundColor: identity.primaryAction,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: identity.border,
                    disabledForegroundColor: identity.mutedInk,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(CupertinoIcons.play_fill, size: 18),
                  label: Text(reviewCount == 0 ? '복습 없음' : '복습 시작'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewMethodList extends StatelessWidget {
  final MemorizeIdentity identity;
  final int archivedMistakeCount;
  final VoidCallback onFlashcard;
  final VoidCallback onSelfTest;
  final VoidCallback onMistakes;

  const _ReviewMethodList({
    required this.identity,
    required this.archivedMistakeCount,
    required this.onFlashcard,
    required this.onSelfTest,
    required this.onMistakes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          _ReviewMethodRow(
            title: '플래시카드',
            subtitle: '단어 뜻을 확인하고 기억을 쌓아요.',
            icon: CupertinoIcons.layers_alt_fill,
            color: identity.success,
            background: identity.softSuccess,
            identity: identity,
            onTap: onFlashcard,
          ),
          Divider(color: identity.border, height: 1, indent: 72),
          _ReviewMethodRow(
            title: '셀프 테스트',
            subtitle: '객관식과 스펠링으로 실력을 점검해요.',
            icon: CupertinoIcons.list_bullet,
            color: const Color(0xFFE77B12),
            background: const Color(0xFFFFF4E8),
            identity: identity,
            onTap: onSelfTest,
          ),
          Divider(color: identity.border, height: 1, indent: 72),
          _ReviewMethodRow(
            title: '누적 오답 노트',
            subtitle:
                archivedMistakeCount == 0
                    ? '틀린 단어가 쌓이면 여기에서 다시 학습해요.'
                    : '다시 확인할 오답 이력 $archivedMistakeCount개가 있어요.',
            icon: CupertinoIcons.pencil_circle,
            color: identity.review,
            background: identity.softReview,
            identity: identity,
            onTap: onMistakes,
          ),
        ],
      ),
    );
  }
}

class _ReviewMethodRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Color background;
  final MemorizeIdentity identity;
  final VoidCallback onTap;

  const _ReviewMethodRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.background,
    required this.identity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 74),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
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
                  mainAxisAlignment: MainAxisAlignment.center,
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
              const SizedBox(width: 8),
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
}

class _BloomStatsTab extends StatefulWidget {
  final DailyLearningPlan fullDailyPlan;
  final DailyLearningPlan planDailyPlan;
  final int totalWordCount;
  final int planWordCount;
  final StudyPlan? activeStudyPlan;
  final int lockedNewWordCount;
  final Wordbook? activeWordbook;
  final void Function(DateTime date, bool usePlanScope) onOpenCalendar;

  const _BloomStatsTab({
    required this.fullDailyPlan,
    required this.planDailyPlan,
    required this.totalWordCount,
    required this.planWordCount,
    required this.activeStudyPlan,
    required this.lockedNewWordCount,
    required this.activeWordbook,
    required this.onOpenCalendar,
  });

  @override
  State<_BloomStatsTab> createState() => _BloomStatsTabState();
}

class _BloomStatsTabState extends State<_BloomStatsTab> {
  bool _showPlanScope = true;
  final StudyScheduleService _scheduleService = StudyScheduleService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final hasPlan = widget.activeStudyPlan != null;
    final usePlanScope = hasPlan && _showPlanScope;
    final dailyPlan =
        usePlanScope ? widget.planDailyPlan : widget.fullDailyPlan;
    final totalWordCount =
        usePlanScope ? widget.planWordCount : widget.totalWordCount;
    final matureCount = dailyPlan.matureWords.length;
    final mastery =
        totalWordCount == 0
            ? 0.0
            : (matureCount / totalWordCount).clamp(0.0, 1.0).toDouble();
    final words = <Word>[
      ...dailyPlan.dueWords,
      ...dailyPlan.newWords,
      ...dailyPlan.learningWords,
      ...dailyPlan.scheduledWords,
      ...dailyPlan.matureWords,
    ];
    final reviewSchedule = _scheduleService.reviewSchedule(words);
    final scopeLabel =
        widget.activeWordbook == null
            ? '학습 단어장을 선택하세요'
            : usePlanScope
            ? '${widget.activeWordbook!.name} · ${widget.activeStudyPlan!.progressLabel}'
            : '${widget.activeWordbook!.name} · 전체 단어장';

    return SingleChildScrollView(
      key: const PageStorageKey<String>('memorize-stats-identity-v1'),
      padding: const EdgeInsets.fromLTRB(
        MemorizeIdentity.pagePadding,
        14,
        MemorizeIdentity.pagePadding,
        22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TabIntroHeader(title: '통계', subtitle: '학습 계획과 기억 성장을 확인하세요.'),
          const SizedBox(height: 16),
          _HomeWordbookContext(
            label: scopeLabel,
            enabled: widget.activeWordbook != null,
            identity: identity,
            onTap: () => _selectActiveWordbook(context),
          ),
          if (hasPlan) ...[
            const SizedBox(height: 12),
            _StatsScopeSwitch(
              usePlanScope: usePlanScope,
              onChanged: (value) => setState(() => _showPlanScope = value),
              identity: identity,
            ),
          ],
          if (usePlanScope) ...[
            const SizedBox(height: 14),
            _PlanStatsSummaryCard(
              plan: widget.activeStudyPlan!,
              openedWordCount: widget.planWordCount,
              lockedNewWordCount: widget.lockedNewWordCount,
              identity: identity,
            ),
          ],
          const SizedBox(height: 14),
          _StatsMemoryCard(
            progress: mastery,
            totalWordCount: totalWordCount,
            newCount: dailyPlan.newWords.length,
            learningCount: dailyPlan.learningWords.length,
            scheduledCount: dailyPlan.scheduledWords.length,
            reviewCount: dailyPlan.dueWords.length,
            matureCount: dailyPlan.matureWords.length,
            identity: identity,
          ),
          const SizedBox(height: 14),
          _StatsReviewScheduleCard(
            schedule: reviewSchedule,
            hasActiveWordbook: widget.activeWordbook != null,
            identity: identity,
            onDateTap: (date) => widget.onOpenCalendar(date, usePlanScope),
            onStartReview:
                dailyPlan.dueWords.isEmpty || widget.activeWordbook == null
                    ? null
                    : () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => const FlashcardScreen(
                              initialMode: FlashcardLaunchMode.review,
                              origin: LearningRouteOrigin.review,
                            ),
                      ),
                    ),
          ),
          const SizedBox(height: 14),
          _StatsDetailRows(
            identity: identity,
            onOpenSrs:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => SrsStatusScreen(initialPlanScope: usePlanScope),
                  ),
                ),
            onOpenGuide:
                () =>
                    showStudyGuideSheet(context, StudyGuideCatalog.srsAndStats),
          ),
        ],
      ),
    );
  }
}

class _StatsScopeSwitch extends StatelessWidget {
  final bool usePlanScope;
  final ValueChanged<bool> onChanged;
  final MemorizeIdentity identity;

  const _StatsScopeSwitch({
    required this.usePlanScope,
    required this.onChanged,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: identity.softInfo,
        borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatsScopeButton(
              label: '전체 단어장',
              selected: !usePlanScope,
              color: identity.primaryAction,
              surface: identity.surface,
              mutedInk: identity.mutedInk,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _StatsScopeButton(
              label: '현재 묶음',
              selected: usePlanScope,
              color: identity.primaryAction,
              surface: identity.surface,
              mutedInk: identity.mutedInk,
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
  final Color surface;
  final Color mutedInk;
  final VoidCallback onTap;

  const _StatsScopeButton({
    required this.label,
    required this.selected,
    required this.color,
    required this.surface,
    required this.mutedInk,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow:
              selected
                  ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                  : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: selected ? color : mutedInk,
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
  final MemorizeIdentity identity;

  const _PlanStatsSummaryCard({
    required this.plan,
    required this.openedWordCount,
    required this.lockedNewWordCount,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = max(1, openedWordCount + lockedNewWordCount);
    final progress = (openedWordCount / total).clamp(0.0, 1.0).toDouble();
    final start = plan.startDateValue;
    final end = plan.targetEndDate();
    final period =
        plan.mode == StudyPlanMode.scheduled
            ? '${start.month}월 ${start.day}일–${end.month}월 ${end.day}일'
            : plan.mode.label;

    return _StatsSurfaceCard(
      identity: identity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatsIconBadge(
                icon: CupertinoIcons.calendar,
                color: identity.primaryAction,
                background: identity.softInfo,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '학습 계획',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 142),
                child: Text(
                  plan.progressLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '열린 단어 ',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: identity.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '$openedWordCount',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: identity.primaryAction,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                ' / $total',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: identity.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  period,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: identity.border.withValues(alpha: 0.62),
              valueColor: AlwaysStoppedAnimation(identity.success),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '잠긴 단어 $lockedNewWordCount개',
            style: theme.textTheme.bodySmall?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsSurfaceCard extends StatelessWidget {
  final MemorizeIdentity identity;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _StatsSurfaceCard({
    required this.identity,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: identity.surface,
      borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
      border: Border.all(color: identity.border),
    ),
    child: child,
  );
}

class _StatsIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  const _StatsIconBadge({
    required this.icon,
    required this.color,
    required this.background,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(11),
    ),
    alignment: Alignment.center,
    child: Icon(icon, size: size * 0.48, color: color),
  );
}

class _StatsMemoryCard extends StatelessWidget {
  final double progress;
  final int totalWordCount;
  final int newCount;
  final int learningCount;
  final int scheduledCount;
  final int reviewCount;
  final int matureCount;
  final MemorizeIdentity identity;

  const _StatsMemoryCard({
    required this.progress,
    required this.totalWordCount,
    required this.newCount,
    required this.learningCount,
    required this.scheduledCount,
    required this.reviewCount,
    required this.matureCount,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const learningColor = Color(0xFFE17A00);
    final percent = (progress * 100).round();

    return _StatsSurfaceCard(
      identity: identity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatsIconBadge(
                icon: CupertinoIcons.chart_bar_alt_fill,
                color: identity.primaryAction,
                background: identity.softInfo,
              ),
              const SizedBox(width: 10),
              Text(
                '기억 현황',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: identity.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 116,
                height: 116,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 10,
                      color: identity.border.withValues(alpha: 0.66),
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      color: identity.success,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '안정 기억률',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: identity.mutedInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$percent%',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: identity.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            '$matureCount / $totalWordCount',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: identity.mutedInk,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    _StatsStageRow(
                      icon: CupertinoIcons.doc_text,
                      label: '진입',
                      count: newCount,
                      color: identity.primaryAction,
                      background: identity.softInfo,
                      identity: identity,
                    ),
                    _StatsStageRow(
                      icon: CupertinoIcons.clock,
                      label: '학습 중',
                      count: learningCount,
                      color: learningColor,
                      background: const Color(0xFFFFF4E6),
                      identity: identity,
                    ),
                    _StatsStageRow(
                      icon: CupertinoIcons.calendar,
                      label: '복습 예정',
                      count: scheduledCount,
                      color: identity.scheduled,
                      background: identity.softScheduled,
                      identity: identity,
                    ),
                    _StatsStageRow(
                      icon: CupertinoIcons.arrow_2_circlepath,
                      label: '복습 필요',
                      count: reviewCount,
                      color: identity.review,
                      background: identity.softReview,
                      identity: identity,
                    ),
                    _StatsStageRow(
                      icon: CupertinoIcons.check_mark_circled,
                      label: '안정 기억',
                      count: matureCount,
                      color: identity.success,
                      background: identity.softSuccess,
                      identity: identity,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsStageRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color background;
  final MemorizeIdentity identity;

  const _StatsStageRow({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.background,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: identity.mutedInk,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.titleMedium?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsReviewScheduleCard extends StatelessWidget {
  final ReviewScheduleSummary schedule;
  final bool hasActiveWordbook;
  final MemorizeIdentity identity;
  final ValueChanged<DateTime> onDateTap;
  final VoidCallback? onStartReview;

  const _StatsReviewScheduleCard({
    required this.schedule,
    required this.hasActiveWordbook,
    required this.identity,
    required this.onDateTap,
    required this.onStartReview,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxCount = max(1, schedule.dailyCounts.fold(0, max));
    final weekTotal = schedule.total;

    return _StatsSurfaceCard(
      identity: identity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatsIconBadge(
                icon: CupertinoIcons.calendar,
                color: identity.primaryAction,
                background: identity.softInfo,
              ),
              const SizedBox(width: 10),
              Text(
                '복습 일정',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: identity.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatsScheduleMetric(
                  label: '오늘',
                  value: schedule.countAt(0),
                  color: identity.review,
                  identity: identity,
                ),
              ),
              _StatsVerticalDivider(identity: identity),
              Expanded(
                child: _StatsScheduleMetric(
                  label: '내일',
                  value: schedule.countAt(1),
                  color: identity.primaryAction,
                  identity: identity,
                ),
              ),
              _StatsVerticalDivider(identity: identity),
              Expanded(
                child: _StatsScheduleMetric(
                  label: '7일 내',
                  value: weekTotal,
                  color: identity.primaryAction,
                  identity: identity,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Semantics(
            label: '날짜별 복습 일정. 막대를 누르면 달력에서 해당 날짜를 엽니다.',
            child: SizedBox(
              height: 112,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < schedule.dailyCounts.length; i++)
                    Expanded(
                      child: _StatsScheduleBar(
                        date: schedule.startDate.add(Duration(days: i)),
                        count: schedule.dailyCounts[i],
                        maxCount: maxCount,
                        isToday: i == 0,
                        identity: identity,
                        onTap: onDateTap,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: onStartReview,
              style: FilledButton.styleFrom(
                backgroundColor: identity.primaryAction,
                disabledBackgroundColor: identity.border,
                foregroundColor: Colors.white,
                disabledForegroundColor: identity.mutedInk,
                shape: const StadiumBorder(),
              ),
              child: Text(
                !hasActiveWordbook
                    ? '단어장을 선택하세요'
                    : schedule.countAt(0) > 0
                    ? '오늘 복습 시작'
                    : '오늘 예정된 복습이 없어요',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsVerticalDivider extends StatelessWidget {
  final MemorizeIdentity identity;

  const _StatsVerticalDivider({required this.identity});

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 42, color: identity.border);
}

class _StatsScheduleMetric extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final MemorizeIdentity identity;

  const _StatsScheduleMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.identity,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: identity.mutedInk,
            fontWeight: FontWeight.w700,
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
}

class _StatsScheduleBar extends StatelessWidget {
  final DateTime date;
  final int count;
  final int maxCount;
  final bool isToday;
  final MemorizeIdentity identity;
  final ValueChanged<DateTime> onTap;

  const _StatsScheduleBar({
    required this.date,
    required this.count,
    required this.maxCount,
    required this.isToday,
    required this.identity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final height = 12 + (46 * count / maxCount);
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final color = isToday ? identity.review : identity.primaryAction;

    return InkWell(
      onTap: () => onTap(date),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              '$count',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: height,
              decoration: BoxDecoration(
                color: color.withValues(alpha: count == 0 ? 0.18 : 0.86),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(6),
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${date.month}/${date.day}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isToday ? color : identity.mutedInk,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
            Text(
              isToday ? '오늘' : weekdays[date.weekday - 1],
              style: theme.textTheme.labelSmall?.copyWith(
                color: isToday ? color : identity.mutedInk,
                fontWeight: FontWeight.w700,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsDetailRows extends StatelessWidget {
  final MemorizeIdentity identity;
  final VoidCallback onOpenSrs;
  final VoidCallback onOpenGuide;

  const _StatsDetailRows({
    required this.identity,
    required this.onOpenSrs,
    required this.onOpenGuide,
  });

  @override
  Widget build(BuildContext context) => _StatsSurfaceCard(
    identity: identity,
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        _StatsDetailRow(
          icon: CupertinoIcons.doc_on_doc,
          title: '단어별 SRS 상태',
          subtitle: '기억 단계와 다음 복습일',
          identity: identity,
          onTap: onOpenSrs,
        ),
        Divider(height: 1, color: identity.border),
        _StatsDetailRow(
          icon: CupertinoIcons.question_circle,
          title: 'SRS 기준 안내',
          subtitle: '단어가 다음 단계로 이동하는 기준',
          identity: identity,
          onTap: onOpenGuide,
        ),
      ],
    ),
  );
}

class _StatsDetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final MemorizeIdentity identity;
  final VoidCallback onTap;

  const _StatsDetailRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.identity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _StatsIconBadge(
                icon: icon,
                color: identity.primaryAction,
                background: identity.softInfo,
                size: 40,
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 17,
                color: identity.mutedInk,
              ),
            ],
          ),
        ),
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
    final theme = Theme.of(context);
    final palette = _ShellPalette.of(theme);
    final identity = MemorizeIdentity.of(theme);
    final manager = context.watch<WordbookManager>();
    final activeWordbook = manager.activeWordbook;
    final contextLabel =
        activeWordbook == null
            ? '학습 단어장을 선택하세요'
            : '학습 단어장 · ${learningScopeSubtitle.replaceFirst('현재 학습 기준 · ', '')}';

    return SingleChildScrollView(
      key: const PageStorageKey<String>('memorize-ai-learning-identity-v1'),
      padding: const EdgeInsets.fromLTRB(
        MemorizeIdentity.pagePadding,
        18,
        MemorizeIdentity.pagePadding,
        28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI 학습',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '예문과 문제 생성을 관리합니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 18),
          _HomeWordbookContext(
            label: contextLabel,
            enabled: activeWordbook != null,
            identity: identity,
            onTap: () => _selectActiveWordbook(context),
          ),
          const SizedBox(height: 14),
          _AiReadinessCard(palette: palette, onOpenSettings: onOpenSettings),
          const SizedBox(height: 14),
          _AiBetaSummaryCard(palette: palette),
          const SizedBox(height: 26),
          Text(
            'AI 학습 기능',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'AI로 나만의 학습 콘텐츠를 만들어 보세요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _BloomFeatureCard(
            title: '예문·뜻 보강',
            subtitle: '예문 생성과 뜻·해석·오타 검토를 도와줘요.',
            icon: CupertinoIcons.doc_text,
            accentColor: identity.primaryAction,
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
            subtitle: '단어장 맞춤 문제를 만들어줘요.',
            icon: CupertinoIcons.list_bullet,
            accentColor: identity.success,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiQuizSetupScreen()),
              );
            },
          ),
          const SizedBox(height: 12),
          _BloomFeatureCard(
            title: '문법 문제 생성',
            subtitle: '문법 범위별 문제를 만들어줘요.',
            icon: CupertinoIcons.book,
            accentColor: const Color(0xFFE77B12),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AiGrammarQuizSetupScreen(),
                ),
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
    final identity = MemorizeIdentity.of(theme);
    final isDark = theme.brightness == Brightness.dark;
    final aiSettings = context.watch<AiSettingsProvider>();
    final fallbackText =
        aiSettings.autoFallbackEnabled
            ? '자동 대체 사용 시 여러 AI 제공자에 순차 요청될 수 있습니다.'
            : '현재 선택한 AI 제공자에만 요청됩니다.';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: isDark ? identity.surface : const Color(0xFFFFFAF1),
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(
          color: isDark ? identity.border : const Color(0xFFFFDDA7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color:
                  isDark
                      ? palette.warning.withValues(alpha: 0.14)
                      : const Color(0xFFFFF0D9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.exclamationmark_shield,
              color: palette.warning,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 생성은 베타 기능입니다.',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '단어장과 설정 정보는 외부 AI 제공업체로 전송되며, 생성된 내용은 검토 후 사용해 주세요. $fallbackText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: identity.mutedInk,
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

class _AiReadinessCard extends StatelessWidget {
  final _ShellPalette palette;
  final VoidCallback onOpenSettings;

  const _AiReadinessCard({required this.palette, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final aiSettings = context.watch<AiSettingsProvider>();
    final apiKeyService = context.read<ApiKeyService>();

    return FutureBuilder<Map<AiProvider, bool>>(
      future: _loadRegisteredProviders(apiKeyService),
      builder: (context, snapshot) {
        final isCheckingApiKey =
            snapshot.connectionState == ConnectionState.waiting;
        final registeredProviders = snapshot.data ?? const <AiProvider, bool>{};
        final priorityOptions = _registeredPriorityOptions(
          aiSettings,
          registeredProviders,
        );
        final hasApiKey = !isCheckingApiKey && priorityOptions.isNotEmpty;
        final statusColor =
            isCheckingApiKey
                ? palette.info
                : hasApiKey
                ? palette.success
                : palette.warning;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 350;
              final status = Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      isCheckingApiKey
                          ? CupertinoIcons.clock_fill
                          : hasApiKey
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.exclamationmark_circle_fill,
                      color: statusColor,
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                            color: identity.ink,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasApiKey
                              ? '지금 바로 AI 학습을 이용할 수 있습니다.'
                              : '설정에서 API 키를 등록하세요.',
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
              );
              final button = FilledButton(
                onPressed: onOpenSettings,
                style: FilledButton.styleFrom(
                  minimumSize: Size(compact ? double.infinity : 122, 48),
                  backgroundColor: identity.primaryAction,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
                child: const Text(
                  'AI 설정 관리',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              );

              if (compact) {
                return Column(
                  children: [status, const SizedBox(height: 12), button],
                );
              }
              return Row(
                children: [
                  Expanded(child: status),
                  Container(
                    width: 1,
                    height: 58,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: identity.border,
                  ),
                  button,
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<Map<AiProvider, bool>> _loadRegisteredProviders(
    ApiKeyService apiKeyService,
  ) async {
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
}

class _TabIntroHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TabIntroHeader({required this.title, required this.subtitle});

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

class _BloomFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool prominent;

  const _BloomFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);

    return Material(
      color: identity.surface,
      borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        onTap: onTap,
        child: Container(
          padding:
              prominent
                  ? const EdgeInsets.fromLTRB(16, 17, 16, 17)
                  : const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          child: Row(
            children: [
              Container(
                width: prominent ? 54 : 50,
                height: prominent ? 54 : 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: prominent ? 26 : 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                        fontSize: prominent ? 17 : 16,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                        height: 1.42,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_right,
                color: identity.mutedInk,
                size: 19,
              ),
            ],
          ),
        ),
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
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
            subtitle:
                dailyPlan.hasReview
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
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const FlashcardScreen(
                          origin: LearningRouteOrigin.review,
                        ),
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
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder:
                        (_) => const QuizScreen(
                          origin: LearningRouteOrigin.review,
                        ),
                  ),
                ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: '누적 오답 노트',
            subtitle: '이전에 틀리거나 스킵·재도전한 단어와 기록을 모아봅니다.',
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
            title: 'AI 예문·뜻 보강',
            subtitle: '예문 생성과 뜻·해석·오타 검토',
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
                () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AiQuizSetupScreen()),
                ),
          ),
          const SizedBox(height: 12),
          _ActionCard(
            title: 'AI 문법 체크',
            subtitle: '문법 범위별 문제를 만듭니다.',
            icon: CupertinoIcons.text_cursor,
            accentColor: palette.accent,
            onTap:
                () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AiGrammarQuizSetupScreen(),
                  ),
                ),
          ),
        ],
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
  final int scheduledCount;
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
    required this.scheduledCount,
    required this.matureCount,
    this.nextReviewLabel,
    this.hasDueReviewNotice = false,
    this.hasOverdueReviewNotice = false,
  });

  int get focusCount => reviewCount + newCount + learningCount;
  double get masteryRatio => totalCount == 0 ? 0.0 : matureCount / totalCount;
}
