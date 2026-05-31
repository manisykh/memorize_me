import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/study_plan_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/mode_state_service.dart';
import '../services/srs_service.dart';
import '../themes/app_theme.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_button.dart';
import 'quiz_screen.dart';

class SrsStatusScreen extends StatefulWidget {
  final bool initialPlanScope;

  const SrsStatusScreen({super.key, this.initialPlanScope = false});

  @override
  State<SrsStatusScreen> createState() => _SrsStatusScreenState();
}

class _SrsStatusScreenState extends State<SrsStatusScreen> {
  Wordbook? _selectedWordbook;
  List<Word> _words = [];
  List<Word> _scopedWords = [];
  StudyPlan? _studyPlan;
  bool _showPlanScope = false;
  bool _isLoading = true;
  final SrsService _srsService = SrsService();

  int _newCount = 0;
  int _learningCount = 0;
  int _reviewCount = 0;
  int _matureCount = 0;
  int _dueToday = 0;
  int _dueTomorrow = 0;
  int _dueThisWeek = 0;
  int _lockedNewWordCount = 0;
  Map<String, double> _forecastData = {};

  @override
  void initState() {
    super.initState();
    _showPlanScope = widget.initialPlanScope;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();

    final lastUsedId = await modeStateService.getLastUsedWordbookId(LearningMode.srsStatus);
    Wordbook? initialWordbook = wordbookManager.activeWordbook;
    initialWordbook ??= wordbookManager.getWordbookById(lastUsedId ?? -1);

    if (initialWordbook != null) {
      await _onWordbookSelected(initialWordbook);
      return;
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    setState(() => _isLoading = true);

    final wordbookManager = context.read<WordbookManager>();
    final wordListNotifier = context.read<WordListNotifier>();
    final modeStateService = context.read<ModeStateService>();
    await wordbookManager.setActiveWordbook(wordbook);

    if (mounted) {
      final words = wordListNotifier.words;
      final studyPlan = wordbookManager.planFor(wordbook);
      final showPlanScope = studyPlan != null;
      final scopedWords =
          showPlanScope ? wordbookManager.wordsAvailableForPlan(words, plan: studyPlan) : words;
      final lockedNewWordCount =
          studyPlan == null ? 0 : wordbookManager.lockedNewWordCount(words, plan: studyPlan);
      setState(() {
        _selectedWordbook = wordbook;
        _words = words;
        _studyPlan = studyPlan;
        _showPlanScope = showPlanScope;
        _scopedWords = scopedWords;
        _lockedNewWordCount = lockedNewWordCount;
        _calculateStatistics();
        _isLoading = false;
      });
    }

    await modeStateService.setLastUsedWordbookId(LearningMode.srsStatus, wordbook.id!);
  }

  void _calculateStatistics() {
    var newCount = 0;
    var learningCount = 0;
    var reviewCount = 0;
    var matureCount = 0;
    var dueToday = 0;
    var dueTomorrow = 0;
    var dueThisWeek = 0;
    final forecastData = <String, double>{};

    final today = _srsService.today();
    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: DateTime.daysPerWeek - today.weekday));

    for (var i = 0; i < 7; i++) {
      final date = today.add(Duration(days: i));
      forecastData[DateFormat('MM/dd').format(date)] = 0;
    }

    for (final word in _scopedWords) {
      final stage = _srsService.stageFor(word, baseDate: today);
      switch (stage) {
        case SrsStage.newWord:
          newCount++;
          break;
        case SrsStage.due:
          reviewCount++;
          break;
        case SrsStage.learning:
          learningCount++;
          break;
        case SrsStage.mature:
          matureCount++;
          break;
      }

      final reviewDate = _srsService.reviewDateFor(word);
      final isDue = _srsService.isDueForReview(word, baseDate: today);

      if (isDue) {
        dueToday++;
      }
      if (reviewDate != null && reviewDate.isAtSameMomentAs(tomorrow)) {
        dueTomorrow++;
      }
      if (reviewDate != null && reviewDate.isAfter(today) && !reviewDate.isAfter(endOfWeek)) {
        dueThisWeek++;
      }

      if (reviewDate != null) {
        final difference = reviewDate.difference(today).inDays;
        if (difference >= 0 && difference < 7) {
          final dateKey = DateFormat('MM/dd').format(reviewDate);
          forecastData[dateKey] = (forecastData[dateKey] ?? 0) + 1;
        }
      }
    }

    _newCount = newCount;
    _learningCount = learningCount;
    _reviewCount = reviewCount;
    _matureCount = matureCount;
    _dueToday = dueToday;
    _dueTomorrow = dueTomorrow;
    _dueThisWeek = dueThisWeek;
    _forecastData = forecastData;
  }

  void _setScope(bool usePlanScope) {
    final studyPlan = _studyPlan;
    final wordbookManager = context.read<WordbookManager>();
    final scopedWords =
        usePlanScope && studyPlan != null
            ? wordbookManager.wordsAvailableForPlan(_words, plan: studyPlan)
            : _words;

    setState(() {
      _showPlanScope = usePlanScope && studyPlan != null;
      _scopedWords = scopedWords;
      _calculateStatistics();
    });
  }

  IconData _iconForStage(SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return CupertinoIcons.plus_circle_fill;
      case SrsStage.due:
        return CupertinoIcons.flame_fill;
      case SrsStage.learning:
        return CupertinoIcons.bolt_circle_fill;
      case SrsStage.mature:
        return CupertinoIcons.check_mark_circled_solid;
    }
  }

  Color _colorForStage(SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return AppTheme.primaryGreen;
      case SrsStage.due:
        return AppTheme.accentCoral;
      case SrsStage.learning:
        return Colors.amber.shade800;
      case SrsStage.mature:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedWords = List<Word>.from(_scopedWords)
      ..sort((a, b) => _srsService.reviewPriority(b).compareTo(_srsService.reviewPriority(a)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('SRS 학습 현황')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WordbookSelectionButton(
              selectedWordbook: _selectedWordbook,
              onWordbookSelected: _onWordbookSelected,
              wordCount: _words.length,
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
            else if (_selectedWordbook == null)
              const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('현황을 보려면 단어장을 선택해 주세요.')))
            else ...[
              if (_studyPlan != null) ...[
                _buildScopeControl(theme),
                const SizedBox(height: 16),
              ],
              _buildSectionTitle('학습 현황 요약', theme),
              if (_showPlanScope && _studyPlan != null) ...[
                _buildPlanScopeCard(theme),
                const SizedBox(height: 16),
              ],
              _buildReviewMotivationCard(theme),
              const SizedBox(height: 16),
              _buildSummarySection(theme),
              const SizedBox(height: 16),
              _buildSrsExplanationSection(theme),
              const SizedBox(height: 24),
              _buildSectionTitle('예정된 복습', theme),
              _buildScheduleSection(theme),
              const SizedBox(height: 16),
              _buildForecastChart(theme),
              const SizedBox(height: 24),
              _buildSectionTitle('단어별 상세 정보', theme),
              _buildDetailTable(theme, sortedWords),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: theme.textTheme.titleLarge),
    );
  }

  Widget _buildScopeControl(ThemeData theme) {
    return GlassmorphicCard(
      padding: const EdgeInsets.all(6),
      borderRadius: 24,
      child: Row(
        children: [
          Expanded(
            child: _buildScopeButton(
              theme: theme,
              label: '전체 단어장',
              selected: !_showPlanScope,
              color: theme.colorScheme.primary,
              onTap: () => _setScope(false),
            ),
          ),
          Expanded(
            child: _buildScopeButton(
              theme: theme,
              label: '현재 학습 기준',
              selected: _showPlanScope,
              color: AppTheme.accentCoral,
              onTap: () => _setScope(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeButton({
    required ThemeData theme,
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: selected ? color : theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _buildPlanScopeCard(ThemeData theme) {
    final plan = _studyPlan;
    if (plan == null) return const SizedBox.shrink();
    final opened = _scopedWords.length;
    final progress =
        plan.totalWords == 0 ? 0.0 : (opened / plan.totalWords).clamp(0.0, 1.0).toDouble();
    final totalDays = plan.estimatedTotalDays();
    final currentDay = totalDays == 0 ? 0 : plan.currentChunk().clamp(1, totalDays).toInt();

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.accentCoral.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(CupertinoIcons.calendar, color: AppTheme.accentCoral, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '현재 학습 기준 · 플랜 $currentDay/$totalDays일차',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _buildSmallBadge(theme, '플랜 적용', AppTheme.accentCoral),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCoral),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '열린 단어 $opened/${plan.totalWords}개 · 잠긴 단어 $_lockedNewWordCount개',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildReviewMotivationCard(ThemeData theme) {
    final hasDue = _dueToday > 0;
    final accentColor = hasDue ? AppTheme.accentCoral : AppTheme.primaryGreen;
    final title = hasDue ? '지금 복습하면 기억이 다시 또렷해집니다' : '오늘 급한 복습은 비어 있습니다';
    final message =
        hasDue
            ? '오늘 복습 대상은 다음 복습일이 오늘이거나 이미 지난 단어입니다. 오래 밀린 단어부터 다시 보면 회복 속도가 빠릅니다.'
            : _newCount > 0
            ? '복습 큐가 비어 있으니 새 단어를 넣기에 좋은 타이밍입니다.'
            : '현재 단어장의 기억 상태가 비교적 안정적입니다.';

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  hasDue ? CupertinoIcons.flame_fill : CupertinoIcons.check_mark_circled_solid,
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(message, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _buildTinyStat(theme, '오늘 복습', '$_dueToday', AppTheme.accentCoral)),
              const SizedBox(width: 8),
              Expanded(child: _buildTinyStat(theme, '내일', '$_dueTomorrow', AppTheme.primaryGreen)),
              const SizedBox(width: 8),
              Expanded(child: _buildTinyStat(theme, '이번 주', '$_dueThisWeek', theme.colorScheme.primary)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  hasDue && _selectedWordbook != null
                      ? () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QuizScreen(initialMode: QuizMode.reviewSpelling)),
                      )
                      : null,
              icon: const Icon(CupertinoIcons.play_fill, size: 18),
              label: Text(hasDue ? '오늘 복습 시작' : '복습 완료'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTinyStat(ThemeData theme, String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            style: theme.textTheme.titleMedium?.copyWith(color: accentColor, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(ThemeData theme) {
    final total = _newCount + _reviewCount + _learningCount + _matureCount;
    if (total == 0) {
      return const GlassmorphicCard(child: Padding(padding: EdgeInsets.all(16), child: Text('단어가 없습니다.')));
    }

    return GlassmorphicCard(
      child: Row(
        children: [
          SizedBox(
            height: 148,
            width: 148,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 42,
                sections: [
                  PieChartSectionData(
                    value: _newCount.toDouble(),
                    color: _colorForStage(SrsStage.newWord),
                    radius: 25,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: _reviewCount.toDouble(),
                    color: _colorForStage(SrsStage.due),
                    radius: 25,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: _learningCount.toDouble(),
                    color: _colorForStage(SrsStage.learning),
                    radius: 25,
                    showTitle: false,
                  ),
                  PieChartSectionData(
                    value: _matureCount.toDouble(),
                    color: _colorForStage(SrsStage.mature),
                    radius: 25,
                    showTitle: false,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendRow(theme, SrsStage.newWord, _srsService.labelForStage(SrsStage.newWord), _newCount),
                _buildLegendRow(theme, SrsStage.due, _srsService.labelForStage(SrsStage.due), _reviewCount),
                _buildLegendRow(theme, SrsStage.learning, _srsService.labelForStage(SrsStage.learning), _learningCount),
                _buildLegendRow(theme, SrsStage.mature, _srsService.labelForStage(SrsStage.mature), _matureCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(ThemeData theme, SrsStage stage, String text, [int? count]) {
    final color = _colorForStage(stage);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_iconForStage(stage), color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          if (count != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                count.toString(),
                style: theme.textTheme.labelLarge?.copyWith(color: color, fontWeight: FontWeight.w800),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSrsExplanationSection(ThemeData theme) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SRS 기준 가이드', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
            '복습 대상은 다음 복습일이 오늘이거나 이미 지난 단어입니다. 새 단어는 아직 복습 대상이 아니고, 한 번 학습한 뒤부터 SRS 일정에 들어갑니다.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '단계 변화는 하루에 여러 번 학습해도 즉시 반영됩니다. 다만 오늘 복습 큐는 과부하를 줄이기 위해 다음 복습일 기준으로 보여줍니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          _buildExplanationTile(theme, SrsStage.newWord),
          _buildExplanationTile(theme, SrsStage.due),
          _buildExplanationTile(theme, SrsStage.learning),
          _buildExplanationTile(theme, SrsStage.mature),
        ],
      ),
    );
  }

  Widget _buildExplanationTile(ThemeData theme, SrsStage stage) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _buildLegendRow(theme, stage, _srsService.descriptionForStage(stage)),
    );
  }

  Widget _buildScheduleSection(ThemeData theme) {
    return GlassmorphicCard(
      child: Column(
        children: [
          _buildScheduleTile(theme, '오늘 복습', _dueToday),
          _buildScheduleTile(theme, '내일 복습', _dueTomorrow),
          _buildScheduleTile(theme, '이번 주 복습', _dueThisWeek, showDivider: false),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(ThemeData theme, String title, int count, {bool showDivider = true}) {
    return Column(
      children: [
        ListTile(
          title: Text(title),
          trailing: Text(
            '$count개',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildForecastChart(ThemeData theme) {
    if (_forecastData.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 220,
      child: GlassmorphicCard(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: 52.0 * _forecastData.length,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                barGroups:
                    _forecastData.entries.map((entry) {
                      final index = _forecastData.keys.toList().indexOf(entry.key);
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value,
                            color: AppTheme.primaryGreen,
                            width: 20,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ],
                      );
                    }).toList(),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget:
                          (value, meta) =>
                              value % 5 == 0
                                  ? Text(value.toInt().toString(), style: theme.textTheme.labelSmall)
                                  : const Text(''),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _forecastData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_forecastData.keys.elementAt(index), style: theme.textTheme.labelSmall),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine:
                      (value) => FlLine(color: theme.dividerColor.withValues(alpha: 0.25), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTable(ThemeData theme, List<Word> words) {
    return GlassmorphicCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('단어')),
            DataColumn(label: Text('기억 상태')),
            DataColumn(label: Text('기준')),
            DataColumn(label: Text('다음 복습일')),
          ],
          rows:
              words.map((word) {
                final stage = _srsService.stageFor(word);
                final stageColor = _colorForStage(stage);
                return DataRow(
                  color: WidgetStateProperty.all(stageColor.withValues(alpha: 0.08)),
                  cells: [
                    DataCell(Text(word.word)),
                    DataCell(_buildSrsStageChip(theme, word)),
                    DataCell(Text(_srsService.reasonForWord(word))),
                    DataCell(Text(_srsService.reviewDateFor(word) != null ? DateFormat('yyyy-MM-dd').format(_srsService.reviewDateFor(word)!) : '미정')),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildSrsStageChip(ThemeData theme, Word word) {
    final stage = _srsService.stageFor(word);
    final color = _colorForStage(stage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForStage(stage), color: color, size: 16),
          const SizedBox(width: 5),
          Text(
            '${_srsService.labelForStage(stage)} · ${_srsService.reasonForWord(word)}',
            style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
