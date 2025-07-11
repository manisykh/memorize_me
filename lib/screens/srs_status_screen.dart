// lib/screens/srs_status_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../widgets/wordbook_selection_button.dart';
import '../services/mode_state_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../providers/word_list_provider.dart';

class SrsStatusScreen extends StatefulWidget {
  const SrsStatusScreen({super.key});

  @override
  State<SrsStatusScreen> createState() => _SrsStatusScreenState();
}

class _SrsStatusScreenState extends State<SrsStatusScreen> {
  Wordbook? _selectedWordbook;
  List<Word> _words = [];
  bool _isLoading = true;

  int _newCount = 0;
  int _learningCount = 0;
  int _reviewCount = 0;
  int _matureCount = 0;
  int _dueToday = 0;
  int _dueTomorrow = 0;
  int _dueThisWeek = 0;
  Map<String, double> _forecastData = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();

    final lastUsedId = await modeStateService.getLastUsedWordbookId(LearningMode.srsStatus);
    Wordbook? initialWordbook = wordbookManager.getWordbookById(lastUsedId ?? -1);
    initialWordbook ??= wordbookManager.activeWordbook;

    if (initialWordbook != null) {
      await _onWordbookSelected(initialWordbook);
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    setState(() => _isLoading = true);

    final wordbookManager = context.read<WordbookManager>();
    await wordbookManager.setActiveWordbook(wordbook);

    if (mounted) {
      final words = context.read<WordListNotifier>().words;
      setState(() {
        _selectedWordbook = wordbook;
        _words = words;
        _calculateStatistics();
        _isLoading = false;
      });
    }

    final modeStateService = context.read<ModeStateService>();
    await modeStateService.setLastUsedWordbookId(LearningMode.srsStatus, wordbook.id!);
  }

  void _calculateStatistics() {
    int newCount = 0, learningCount = 0, reviewCount = 0, matureCount = 0;
    int dueToday = 0, dueTomorrow = 0, dueThisWeek = 0;
    Map<String, double> forecastData = {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: DateTime.daysPerWeek - today.weekday));

    for (int i = 0; i < 7; i++) {
      final date = today.add(Duration(days: i));
      final dateString = DateFormat('MM/dd').format(date);
      forecastData[dateString] = 0;
    }

    for (final word in _words) {
      if (word.srsLevel == 0)
        newCount++;
      else if (word.srsLevel == 1)
        reviewCount++;
      else if (word.srsLevel >= 2 && word.srsLevel <= 4)
        learningCount++;
      else
        matureCount++;

      DateTime? reviewDate;
      if (word.nextReviewDate != null && word.nextReviewDate!.isNotEmpty) {
        try {
          reviewDate = DateTime.parse(word.nextReviewDate!);
        } catch (e) {
          /* 무시 */
        }
      }

      final isDue = reviewDate != null && !reviewDate.isAfter(today);

      if (isDue) dueToday++;
      if (reviewDate == tomorrow) dueTomorrow++;
      if (reviewDate != null && reviewDate.isAfter(today) && !reviewDate.isAfter(endOfWeek))
        dueThisWeek++;

      if (reviewDate != null) {
        final difference = reviewDate.difference(today).inDays;
        if (difference >= 0 && difference < 7) {
          final dateString = DateFormat('MM/dd').format(reviewDate);
          forecastData[dateString] = (forecastData[dateString] ?? 0) + 1;
        }
      }
    }

    if (mounted) {
      setState(() {
        _newCount = newCount;
        _learningCount = learningCount;
        _reviewCount = reviewCount;
        _matureCount = matureCount;
        _dueToday = dueToday;
        _dueTomorrow = dueTomorrow;
        _dueThisWeek = dueThisWeek;
        _forecastData = forecastData;
      });
    }
  }

  Color _getColorForSrsLevel(int level) {
    if (level == 0) return Colors.red.withOpacity(0.2);
    if (level == 1) return Colors.orange.withOpacity(0.2);
    if (level >= 2 && level <= 4) return Colors.yellow.withOpacity(0.2);
    if (level >= 5 && level <= 7) return Colors.green.withOpacity(0.2);
    return Colors.blue.withOpacity(0.2);
  }

  // ▼▼▼ [수정] 클래스 내부에 _buildLegendRow 메서드 정의 ▼▼▼
  Widget _buildLegendRow(Color color, String text, [int? count]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
          if (count != null)
            Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sortedWords = List<Word>.from(_words)..sort((a, b) => a.srsLevel.compareTo(b.srsLevel));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('SRS 학습 현황')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WordbookSelectionButton(
              selectedWordbook: _selectedWordbook,
              onWordbookSelected: _onWordbookSelected,
              wordCount: _words.length,
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_selectedWordbook == null)
              const Center(child: Text('현황을 보려면 단어장을 선택해주세요.'))
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('학습 현황 요약', theme),
                  _buildSummarySection(),
                  const SizedBox(height: 16),
                  _buildSrsExplanationSection(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('예정된 복습', theme),
                  _buildScheduleSection(),
                  const SizedBox(height: 16),
                  _buildForecastChart(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('단어별 상세 정보', theme),
                  _buildDetailTable(sortedWords),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(title, style: theme.textTheme.titleLarge),
    );
  }

  Widget _buildSummarySection() {
    final total = _newCount + _reviewCount + _learningCount + _matureCount;
    if (total == 0) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('단어가 없습니다.')));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              height: 140,
              width: 140,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: [
                    PieChartSectionData(
                      value: _newCount.toDouble(),
                      color: Colors.grey,
                      radius: 25,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: _reviewCount.toDouble(),
                      color: Colors.orange.withOpacity(0.7),
                      radius: 25,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: _learningCount.toDouble(),
                      color: Colors.yellow.shade700,
                      radius: 25,
                      showTitle: false,
                    ),
                    PieChartSectionData(
                      value: _matureCount.toDouble(),
                      color: Colors.green,
                      radius: 25,
                      showTitle: false,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ▼▼▼ [수정] _buildLegend 호출을 _buildLegendRow로 통일 ▼▼▼
                  _buildLegendRow(Colors.grey, '새 단어 (Lv 0)', _newCount),
                  _buildLegendRow(Colors.orange.withOpacity(0.7), '복습 필요 (Lv 1)', _reviewCount),
                  _buildLegendRow(Colors.yellow.shade700, '학습 중 (Lv 2-4)', _learningCount),
                  _buildLegendRow(Colors.green, '안정권 (Lv 5+)', _matureCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSrsExplanationSection() {
    return GlassmorphicCard(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SRS 레벨 가이드', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // ▼▼▼ [수정] _buildLegendRow 호출로 통일 ▼▼▼
            _buildLegendRow(Colors.red, 'Level 0: 즉시 복습 필요 (퀴즈 오답)'),
            _buildLegendRow(Colors.orange, 'Level 1: 복습 필요 (1일 주기)'),
            _buildLegendRow(Colors.yellow, 'Level 2-4: 학습 중 (3-7일 주기)'),
            _buildLegendRow(Colors.green, 'Level 5-7: 안정권 (15-60일 주기)'),
            _buildLegendRow(Colors.blue, 'Level 8+: 암기 완료 (120일+ 주기)'),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Card(
      child: Column(
        children: [
          _buildScheduleTile('오늘 복습', _dueToday),
          _buildScheduleTile('내일 복습', _dueTomorrow),
          _buildScheduleTile('이번 주 내 복습', _dueThisWeek, showDivider: false),
        ],
      ),
    );
  }

  Widget _buildScheduleTile(String title, int count, {bool showDivider = true}) {
    return Column(
      children: [
        ListTile(
          title: Text(title),
          trailing: Text(
            '$count 개',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        if (showDivider) const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildForecastChart() {
    if (_forecastData.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 200,
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 50.0 * _forecastData.length,
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
                            color: Colors.blue,
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
                      getTitlesWidget: (value, meta) {
                        return value % 5 == 0
                            ? Text(value.toInt().toString(), style: const TextStyle(fontSize: 10))
                            : const Text('');
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < _forecastData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              _forecastData.keys.elementAt(index),
                              style: const TextStyle(fontSize: 10),
                            ),
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
                      (value) => FlLine(color: Colors.grey.withOpacity(0.2), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailTable(List<Word> words) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('단어')),
            DataColumn(label: Text('SRS 레벨'), numeric: true),
            DataColumn(label: Text('다음 복습일')),
          ],
          rows:
              words.map((word) {
                return DataRow(
                  color: WidgetStateProperty.all(_getColorForSrsLevel(word.srsLevel)),
                  cells: [
                    DataCell(Text(word.word)),
                    DataCell(Text(word.srsLevel.toString())),
                    DataCell(Text(word.nextReviewDate ?? '학습전')),
                  ],
                );
              }).toList(),
        ),
      ),
    );
  }
}
