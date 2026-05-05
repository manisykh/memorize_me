import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'manage_words_screen.dart';
import 'merge_wordbooks_screen.dart';
import 'select_spreadsheet_screen.dart';

class WordbookManagementScreen extends StatefulWidget {
  const WordbookManagementScreen({super.key});

  @override
  State<WordbookManagementScreen> createState() => _WordbookManagementScreenState();
}

class _WordbookManagementScreenState extends State<WordbookManagementScreen> {
  Wordbook? _selectedForEditing;
  final SrsService _srsService = SrsService();
  final Map<Object, Future<_WordbookStatsSnapshot>> _statsFutures = {};
  final _searchController = TextEditingController();

  Timer? _debounce;
  Map<Wordbook, List<Word>> _searchResults = {};
  bool _isSearching = false;
  int? _lastStatsRevision;

  @override
  void initState() {
    super.initState();
    _selectedForEditing = context.read<WordbookManager>().activeWordbook;

    _searchController.addListener(() {
      if (_debounce?.isActive ?? false) {
        _debounce!.cancel();
      }
      _debounce = Timer(const Duration(milliseconds: 500), _performSearch);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = {};
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final manager = context.read<WordbookManager>();
    final results = await manager.searchAllWordbooks(query);

    if (!mounted) {
      return;
    }

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = context.watch<WordbookManager>();
    final isSearchingMode = _searchController.text.trim().isNotEmpty;

    if (_lastStatsRevision != manager.statsRevision) {
      _statsFutures.clear();
      _lastStatsRevision = manager.statsRevision;
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('단어장 관리'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassmorphicCard(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(CupertinoIcons.search),
                    hintText: '모든 단어장에서 단어 검색...',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: true,
                    suffixIcon:
                        isSearchingMode
                            ? IconButton(
                              icon: const Icon(CupertinoIcons.xmark_circle_fill),
                              onPressed: _searchController.clear,
                            )
                            : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isSearchingMode ? _buildSearchResults() : _buildDefaultView(theme, manager),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return const Center(child: Text('검색 결과가 없습니다.'));
    }

    return ListView.builder(
      itemCount: _searchResults.keys.length,
      itemBuilder: (context, index) {
        final wordbook = _searchResults.keys.elementAt(index);
        final words = _searchResults[wordbook]!;

        return ExpansionTile(
          title: Text('${wordbook.name} (${words.length}개)'),
          initiallyExpanded: true,
          children:
              words
                  .map(
                    (word) => ListTile(
                      title: Text(word.word),
                      subtitle: Text(word.meaning),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }

  Widget _buildDefaultView(ThemeData theme, WordbookManager manager) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('단어장 가져오기', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildToolCard(
                      context: context,
                      icon: Image.asset(
                        'assets/icons/google_sheet_icon.png',
                        height: 24,
                        width: 24,
                      ),
                      label: 'Google 시트',
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen()),
                          ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToolCard(
                      context: context,
                      icon: const Icon(CupertinoIcons.folder_open),
                      label: '로컬 파일',
                      onTap: () => manager.createNewWordbookFromCsv(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildToolCard(
                      context: context,
                      icon: const Icon(CupertinoIcons.pencil_ellipsis_rectangle),
                      label: '단어 편집',
                      onTap: () {
                        if (_selectedForEditing != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ManageWordsScreen(wordbook: _selectedForEditing!),
                            ),
                          );
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('편집할 단어장을 목록에서 선택해 주세요.'),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToolCard(
                      context: context,
                      icon: const Icon(Icons.merge_type),
                      label: '단어장 병합',
                      onTap:
                          () => Navigator.of(
                            context,
                          ).push(MaterialPageRoute(builder: (_) => const MergeWordbooksScreen())),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('단어장 목록 (탭하면 편집 대상으로 선택)', style: theme.textTheme.titleLarge),
          const SizedBox(height: 10),
          if (manager.wordbooks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Text('추가된 단어장이 없습니다.')),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: manager.wordbooks.length,
              itemBuilder: (context, index) {
                final wordbook = manager.wordbooks[index];
                final isSelectedForEditing = _selectedForEditing?.id == wordbook.id;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FutureBuilder<_WordbookStatsSnapshot>(
                    future: _statsFutureFor(manager, wordbook),
                    builder: (context, snapshot) {
                      final stats = snapshot.data;
                      return GlassmorphicCard(
                        isActive: isSelectedForEditing,
                        onTap: () => setState(() => _selectedForEditing = wordbook),
                        padding: const EdgeInsets.fromLTRB(16, 14, 8, 12),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _getSourceIcon(wordbook.source, theme),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    wordbook.name,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight:
                                          isSelectedForEditing ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    CupertinoIcons.trash,
                                    color: theme.iconTheme.color?.withValues(alpha: 0.7),
                                  ),
                                  onPressed: () => _confirmDelete(context, manager, wordbook),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatChip(
                                    context,
                                    '전체',
                                    stats?.totalWords.toString() ?? '...',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatChip(
                                    context,
                                    '오늘 복습',
                                    stats?.dueCount.toString() ?? '...',
                                    color: Colors.deepOrange,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatChip(
                                    context,
                                    '새 단어',
                                    stats?.newCount.toString() ?? '...',
                                    color: Colors.blue,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatChip(
                                    context,
                                    '학습 중',
                                    stats?.learningCount.toString() ?? '...',
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildToolCard({
    required BuildContext context,
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        children: [
          icon,
          const SizedBox(height: 8),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }

  Future<_WordbookStatsSnapshot> _statsFutureFor(WordbookManager manager, Wordbook wordbook) {
    final key = wordbook.id ?? wordbook.dbFileName;
    return _statsFutures.putIfAbsent(key, () async {
      final words = await manager.getAllWordsFrom(wordbook);
      final plan = _srsService.buildDailyPlan(words);
      return _WordbookStatsSnapshot(
        totalWords: words.length,
        dueCount: plan.dueWords.length,
        newCount: plan.newWords.length,
        learningCount: plan.learningWords.length,
      );
    });
  }

  Widget _buildStatChip(
    BuildContext context,
    String label,
    String value, {
    Color? color,
  }) {
    final theme = Theme.of(context);
    final accent = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WordbookManager manager, Wordbook wordbook) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('단어장 삭제'),
            content: Text(
              "'${wordbook.name}' 단어장을 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다.",
            ),
            actions: [
              TextButton(
                child: const Text('취소'),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                child: const Text('삭제'),
                onPressed: () {
                  manager.deleteWordbook(wordbook);
                  Navigator.of(dialogContext).pop();
                },
              ),
            ],
          ),
    );
  }

  Widget _getSourceIcon(WordbookSource source, ThemeData theme) {
    switch (source) {
      case WordbookSource.googleSheet:
        return Image.asset('assets/icons/google_sheet_icon.png', width: 24, height: 24);
      case WordbookSource.localCsv:
        return Icon(
          CupertinoIcons.doc_text_fill,
          size: 24,
          color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.9),
        );
    }
  }
}

class _WordbookStatsSnapshot {
  final int totalWords;
  final int dueCount;
  final int newCount;
  final int learningCount;

  const _WordbookStatsSnapshot({
    required this.totalWords,
    required this.dueCount,
    required this.newCount,
    required this.learningCount,
  });
}
