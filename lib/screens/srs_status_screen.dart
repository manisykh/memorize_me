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

class SrsStatusScreen extends StatefulWidget {
  const SrsStatusScreen({super.key});

  @override
  State<SrsStatusScreen> createState() => _SrsStatusScreenState();
}

class _SrsStatusScreenState extends State<SrsStatusScreen> {
  Wordbook? _selectedWordbook;
  List<Word> _words = [];
  bool _isLoading = false;

  // 통계 데이터
  int _newCount = 0;
  int _learningCount = 0;
  int _matureCount = 0;

  // 예정된 복습 데이터
  int _dueToday = 0;
  int _dueTomorrow = 0;
  int _dueThisWeek = 0;
  // ▼▼▼ [추가] 막대 차트용 데이터 ▼▼▼
  Map<String, double> _forecastData = {};

  // 정렬을 위한 상태
  final int _sortColumnIndex = 0;
  final bool _sortAscending = true;

  @override
  void initState() {
    super.initState();
    _loadLastUsedWordbook();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialWordbook = context.read<WordbookManager>().activeWordbook;
      if (initialWordbook != null) {
        _onWordbookSelected(initialWordbook);
      }
    });
  }

  Future<void> _loadLastUsedWordbook() async {
    final modeStateService = context.read<ModeStateService>();
    final wordbookManager = context.read<WordbookManager>();

    final lastUsedId = await modeStateService.getLastUsedWordbookId(LearningMode.srsStatus);
    Wordbook? lastUsedWordbook;
    if (lastUsedId != null) {
      lastUsedWordbook = wordbookManager.getWordbookById(lastUsedId);
    }
    lastUsedWordbook ??= wordbookManager.wordbooks.firstOrNull;

    if (lastUsedWordbook != null) {
      await _onWordbookSelected(lastUsedWordbook);
    }
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    setState(() => _isLoading = true);
    final words = await context.read<WordbookManager>().getAllWordsFrom(wordbook);
    if (mounted) {
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
    int newCount = 0, learningCount = 0, matureCount = 0;
    int dueToday = 0, dueTomorrow = 0, dueThisWeek = 0;
    Map<String, double> forecastData = {};

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final endOfWeek = today.add(Duration(days: DateTime.daysPerWeek - today.weekday));

    // 막대 차트를 위해 향후 7일간의 날짜 초기화
    for (int i = 0; i < 7; i++) {
      final date = today.add(Duration(days: i));
      final dateString = DateFormat('MM/dd').format(date);
      forecastData[dateString] = 0;
    }

    for (final word in _words) {
      // 1. 학습 현황 요약 계산
      if (word.srsLevel == 0)
        newCount++;
      else if (word.srsLevel >= 1 && word.srsLevel <= 4)
        learningCount++;
      else
        matureCount++;

      // 2. 예정된 복습 계산
      DateTime? reviewDate;
      if (word.nextReviewDate != null && word.nextReviewDate!.isNotEmpty) {
        try {
          reviewDate = DateTime.parse(word.nextReviewDate!);
        } catch (e) {
          /* 파싱 오류 무시 */
        }
      }

      // 새 단어는 오늘 복습으로 간주
      reviewDate ??= today;

      if (!reviewDate.isAfter(today))
        dueToday++;
      else if (reviewDate == tomorrow)
        dueTomorrow++;

      if (reviewDate.isAfter(today) && !reviewDate.isAfter(endOfWeek)) dueThisWeek++;

      // 막대 차트 데이터 계산 (오늘 ~ 6일 후)
      final difference = reviewDate.difference(today).inDays;
      if (difference >= 0 && difference < 7) {
        final dateString = DateFormat('MM/dd').format(reviewDate);
        forecastData[dateString] = (forecastData[dateString] ?? 0) + 1;
      }
    }

    setState(() {
      _newCount = newCount;
      _learningCount = learningCount;
      _matureCount = matureCount;
      _dueToday = dueToday;
      _dueTomorrow = dueTomorrow;
      _dueThisWeek = dueThisWeek;
      _forecastData = forecastData;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    // ... 기존 코드와 동일
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
            if (_selectedWordbook != null)
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('학습 현황 요약', theme),
                      _buildSummarySection(),
                      const SizedBox(height: 16),
                      _buildSrsExplanationSection(), // ▼▼▼ [추가] SRS 설명 섹션
                      const SizedBox(height: 24),
                      _buildSectionTitle('예정된 복습', theme),
                      _buildScheduleSection(),
                      const SizedBox(height: 16),
                      _buildForecastChart(), // ▼▼▼ [추가] 일자별 학습량 차트
                      const SizedBox(height: 24),
                      _buildSectionTitle('단어별 상세 정보', theme),
                      _buildDetailTable(),
                    ],
                  )
            else
              const Center(child: Text('현황을 보려면 단어장을 선택해주세요.')),
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
    final total = _newCount + _learningCount + _matureCount;
    if (total == 0)
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('단어가 없습니다.')));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // ▼▼▼ [수정] SizedBox 크기를 키워 그래프를 크게 표시합니다. ▼▼▼
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
                      showTitle: false, // ▼▼▼ [수정] 그래프에 글씨가 나타나지 않도록 설정합니다.
                    ),
                    PieChartSectionData(
                      value: _learningCount.toDouble(),
                      color: Colors.blueAccent,
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
                  _buildLegend(Colors.grey, '새 단어', _newCount),
                  _buildLegend(Colors.blueAccent, '학습 중 (Lv 1-4)', _learningCount),
                  _buildLegend(Colors.green, '완료 (Lv 5+)', _matureCount),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String text, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(width: 16, height: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSrsExplanationSection() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('SRS 학습이란?', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'SRS(Spaced Repetition System, 간격 반복 학습)는 "에빙하우스의 망각 곡선" 이론에 기반한 효율적인 암기 기법입니다. 뇌가 정보를 잊어버릴 때쯤 다시 상기시켜 장기 기억으로 전환시키는 원리입니다.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text('레벨의 의미', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '• 새 단어: 아직 한 번도 학습하지 않은 단어입니다.\n'
              '• 학습 중 (Lv 1-4): 단기 기억에 저장된 단계로, 잊지 않도록 짧은 주기로 복습합니다.\n'
              '• 완료 (Lv 5+): 장기 기억으로 전환된 단계로, 복습 주기가 점차 길어집니다.',
              style: theme.textTheme.bodyMedium,
            ),
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
            width: 50.0 * _forecastData.length, // 차트 넓이 조절
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
                        if (value % 5 == 0) {
                          // 5 단위로 Y축 표시
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        }
                        return const Text('');
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

  Widget _buildDetailTable() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          // ▼▼▼ [수정] 컬럼 간 간격을 좁힙니다. ▼▼▼
          columnSpacing: 24,
          sortColumnIndex: _sortColumnIndex,
          sortAscending: _sortAscending,
          columns: [
            // ▼▼▼ [수정] '단어' 컬럼에서 정렬 기능을 제거합니다. ▼▼▼
            const DataColumn(label: Text('단어')),
            DataColumn(label: const Text('SRS 레벨'), numeric: true, onSort: _onSort),
            DataColumn(label: const Text('다음 복습일'), onSort: _onSort),
          ],
          rows:
              _words
                  .map(
                    (word) => DataRow(
                      cells: [
                        DataCell(Text(word.word)),
                        DataCell(Text(word.srsLevel.toString())),
                        // ▼▼▼ [수정] N/A 대신 '학습전'으로 표시합니다. ▼▼▼
                        DataCell(Text(word.nextReviewDate ?? '학습전')),
                      ],
                    ),
                  )
                  .toList(),
        ),
      ),
    );
  }
}
