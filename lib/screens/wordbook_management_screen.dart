import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/study_plan_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'flashcard_screen.dart';
import 'manage_words_screen.dart';
import 'merge_wordbooks_screen.dart';
import 'select_sheet_screen.dart';
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
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.58),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.shadow.withValues(
                        alpha: theme.brightness == Brightness.dark ? 0.30 : 0.06,
                      ),
                      blurRadius: 18,
                      spreadRadius: -8,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(CupertinoIcons.search),
                    hintText: '모든 단어장에서 단어 검색...',
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                    isDense: false,
                    contentPadding: EdgeInsets.zero,
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
          _buildSectionTitle(theme, '필수 영어단어 6000'),
          const SizedBox(height: 12),
          _buildBuiltinWordbookSection(theme, manager),
          const SizedBox(height: 26),
          _buildSectionTitle(theme, '단어장 가져오기'),
          const SizedBox(height: 12),
          _buildImportPanel(theme, manager),
          if (manager.wordbooks.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildAdvancedManagementPanel(theme),
          ],
          const SizedBox(height: 26),
          _buildSectionTitle(theme, '단어장 목록'),
          const SizedBox(height: 6),
          Text(
            '카드를 선택하면 편집 대상 단어장이 됩니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (manager.wordbooks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: _buildEmptyWordbookGuide(theme, manager),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: manager.wordbooks.length,
              itemBuilder: (context, index) {
                final wordbook = manager.wordbooks[index];
                final isSelectedForEditing = _selectedForEditing?.id == wordbook.id;
                final isActive = _isActiveWordbook(manager.activeWordbook, wordbook);
                final studyPlan = manager.planFor(wordbook);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: FutureBuilder<_WordbookStatsSnapshot>(
                    future: _statsFutureFor(manager, wordbook),
                    builder: (context, snapshot) {
                      final stats = snapshot.data;
                      return GlassmorphicCard(
                        borderRadius: 14,
                        isActive: isActive || isSelectedForEditing,
                        onTap: () {
                          if (isActive) {
                            setState(() => _selectedForEditing = wordbook);
                            return;
                          }
                          _activateWordbook(manager, wordbook);
                        },
                        padding: const EdgeInsets.fromLTRB(16, 15, 8, 14),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _getSourceIcon(wordbook.source, theme),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    wordbook.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontSize: 16,
                                      fontWeight:
                                          isActive ? FontWeight.w900 : FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (studyPlan != null) ...[
                                  _buildBadge(context, '플랜', theme.colorScheme.tertiary),
                                  const SizedBox(width: 6),
                                ],
                                if (isActive) ...[
                                  _buildBadge(context, '활성', theme.colorScheme.primary),
                                  const SizedBox(width: 2),
                                ],
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
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatChip(
                                    context,
                                    '새 단어',
                                    stats?.newCount.toString() ?? '...',
                                    color: theme.colorScheme.tertiary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatChip(
                                    context,
                                    '학습 중',
                                    stats?.learningCount.toString() ?? '...',
                                    color: theme.colorScheme.secondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (studyPlan != null) ...[
                              _buildPlanSummary(context, studyPlan, stats),
                              const SizedBox(height: 12),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed:
                                        isActive
                                            ? null
                                            : () => _activateWordbook(manager, wordbook),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    icon: Icon(
                                      isActive
                                          ? CupertinoIcons.checkmark_circle_fill
                                          : Icons.radio_button_checked,
                                      size: 17,
                                    ),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(isActive ? '사용 중' : '이 단어장 사용'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _openManageWords(wordbook),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    icon: const Icon(CupertinoIcons.pencil, size: 17),
                                    label: const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text('단어 편집'),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _showStudyPlanBuilder(wordbook),
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    icon: const Icon(CupertinoIcons.calendar_badge_plus, size: 17),
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(studyPlan == null ? '플랜 만들기' : '플랜 수정'),
                                    ),
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

  Future<void> _openGoogleSheetImport() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen()),
    );
    if (!mounted || result == null) return;

    if (result == selectSheetImportResultStartStudy) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => const FlashcardScreen(
                initialMode: FlashcardLaunchMode.newWords,
              ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('가져온 단어장을 선택하고 학습을 시작할 수 있습니다.')),
    );
  }

  bool _isActiveWordbook(Wordbook? activeWordbook, Wordbook wordbook) {
    if (activeWordbook == null) return false;
    if (activeWordbook.id != null && wordbook.id != null) {
      return activeWordbook.id == wordbook.id;
    }
    return activeWordbook.dbFileName == wordbook.dbFileName;
  }

  Future<void> _activateWordbook(WordbookManager manager, Wordbook wordbook) async {
    setState(() => _selectedForEditing = wordbook);
    await manager.setActiveWordbook(wordbook);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('현재 학습 기준을 ${wordbook.name}(으)로 변경했습니다.')),
    );
  }

  void _openManageWords(Wordbook wordbook) {
    setState(() => _selectedForEditing = wordbook);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ManageWordsScreen(wordbook: wordbook)),
    );
  }

  Widget _buildBadge(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Future<void> _showStudyPlanBuilder(Wordbook wordbook) async {
    final parentContext = context;
    final manager = parentContext.read<WordbookManager>();
    final messenger = ScaffoldMessenger.of(parentContext);
    final words = await manager.getAllWordsFrom(wordbook);
    if (!parentContext.mounted) return;

    if (words.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('플랜을 만들 단어가 없습니다.')));
      return;
    }

    final existingPlan = manager.planFor(wordbook);
    await showModalBottomSheet<void>(
      context: parentContext,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder:
          (_) => _WordbookPlanBuilderSheet(
            manager: manager,
            messenger: messenger,
            wordbook: wordbook,
            words: words,
            existingPlan: existingPlan,
            initialDailyTarget: existingPlan?.dailyNewTarget ?? _defaultDailyTarget(words.length),
          ),
    );
  }

  int _defaultDailyTarget(int totalWords) {
    if (totalWords >= 500) return 30;
    if (totalWords >= 200) return 20;
    return 15;
  }

  Widget _buildImportPanel(ThemeData theme, WordbookManager manager) {
    return Column(
      children: [
        GlassmorphicCard(
          borderRadius: 14,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          onTap: _openGoogleSheetImport,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Image.asset(
                    'assets/icons/google_sheet_icon.png',
                    height: 26,
                    width: 26,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google 시트에서 가져오기',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Drive에서 직접 선택한 스프레드시트만 단어장으로 가져옵니다.',
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
              const SizedBox(width: 10),
              const Icon(CupertinoIcons.chevron_right, size: 18),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => manager.createNewWordbookFromCsv(context),
            icon: const Icon(CupertinoIcons.folder_open),
            label: const Text('CSV · XLSX 파일에서 가져오기'),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedManagementPanel(ThemeData theme) {
    return GlassmorphicCard(
      borderRadius: 14,
      padding: EdgeInsets.zero,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          leading: const Icon(CupertinoIcons.slider_horizontal_3),
          title: Text(
            '고급 관리',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          subtitle: Text(
            '단어 편집, 단어장 병합',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            ListTile(
              leading: const Icon(CupertinoIcons.pencil_ellipsis_rectangle),
              title: const Text('선택한 단어장 편집'),
              subtitle: Text(
                _selectedForEditing == null
                    ? '먼저 아래 목록에서 단어장을 선택하세요.'
                    : '${_selectedForEditing!.name}의 단어를 수정합니다.',
              ),
              onTap: _openSelectedWordbookEditor,
            ),
            ListTile(
              leading: const Icon(Icons.merge_type),
              title: const Text('단어장 병합'),
              subtitle: const Text('여러 단어장을 하나로 합칩니다.'),
              onTap: _openMergeWordbooks,
            ),
          ],
        ),
      ),
    );
  }

  void _openSelectedWordbookEditor() {
    if (_selectedForEditing != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManageWordsScreen(wordbook: _selectedForEditing!),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('편집할 단어장을 목록에서 선택해 주세요.')),
    );
  }

  void _openMergeWordbooks() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MergeWordbooksScreen()),
    );
  }

  Widget _buildEmptyWordbookGuide(ThemeData theme, WordbookManager manager) {
    return GlassmorphicCard(
      borderRadius: 14,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        children: [
          Icon(
            CupertinoIcons.book_circle_fill,
            size: 44,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            '첫 단어장을 만들어보세요',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'Google 시트에서 단어를 가져오면 바로 복습 루틴과 플래시카드를 시작할 수 있습니다.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openGoogleSheetImport,
              icon: Image.asset(
                'assets/icons/google_sheet_icon.png',
                height: 20,
                width: 20,
              ),
              label: const Text('Google 시트로 단어장 만들기'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => manager.createNewWordbookFromCsv(context),
              icon: const Icon(CupertinoIcons.folder_open),
              label: const Text('CSV · XLSX 파일에서 가져오기'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuiltinWordbookSection(ThemeData theme, WordbookManager manager) {
    final templates = manager.builtinWordbookTemplates;
    return Column(
      children:
          templates
              .map(
                (template) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildBuiltinWordbookCard(theme, manager, template),
                ),
              )
              .toList(),
    );
  }

  Widget _buildBuiltinWordbookCard(
    ThemeData theme,
    WordbookManager manager,
    BuiltinWordbookTemplate template,
  ) {
    final isAdded = manager.isBuiltinWordbookAdded(template);
    final isActive = manager.activeWordbook?.dbFileName == template.dbFileName;
    final accentColor = theme.colorScheme.primary;

    return GlassmorphicCard(
      borderRadius: 14,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        try {
          final wordbook = await manager.addBuiltinWordbook(template);
          if (!mounted) return;
          setState(() => _selectedForEditing = wordbook);
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                isAdded
                    ? '${template.name}을(를) 활성 단어장으로 선택했습니다.'
                    : '${template.name}이(가) 추가되었습니다.',
              ),
            ),
          );
        } catch (e) {
          if (!mounted) return;
          messenger.showSnackBar(SnackBar(content: Text('기본 단어장을 추가하지 못했습니다: $e')));
        }
      },
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(CupertinoIcons.book_fill, color: accentColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        template.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        template.levelLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _buildBuiltinMetaPill(
                      theme,
                      '${template.count}개 수록',
                      theme.colorScheme.primary,
                    ),
                    _buildBuiltinMetaPill(
                      theme,
                      '단계별 학습',
                      theme.colorScheme.tertiary,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  template.description,
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
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? accentColor.withValues(alpha: 0.14)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isActive
                  ? '현재'
                  : isAdded
                  ? '추가됨'
                  : '추가',
              style: theme.textTheme.labelSmall?.copyWith(
                color: isActive ? accentColor : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuiltinMetaPill(ThemeData theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Future<_WordbookStatsSnapshot> _statsFutureFor(WordbookManager manager, Wordbook wordbook) {
    final key = wordbook.id ?? wordbook.dbFileName;
    return _statsFutures.putIfAbsent(key, () async {
      final words = await manager.getAllWordsFrom(wordbook);
      final studyPlan = manager.planFor(wordbook);
      final scopedWords = manager.wordsAvailableForPlan(words, plan: studyPlan);
      final plan = _srsService.buildDailyPlan(scopedWords);
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

  Widget _buildPlanSummary(
    BuildContext context,
    StudyPlan plan,
    _WordbookStatsSnapshot? stats,
  ) {
    final theme = Theme.of(context);
    final totalDays = plan.estimatedTotalDays();
    final currentDay = totalDays == 0 ? 0 : plan.currentChunk().clamp(1, totalDays).toInt();
    final openedWords = plan.unlockedNewLimit().clamp(0, plan.totalWords).toInt();
    final progress = plan.totalWords == 0 ? 0.0 : openedWords / plan.totalWords;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.tertiary.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 16,
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  totalDays == 0 ? '플랜 진행 중' : '$currentDay/$totalDays일차 · 하루 ${plan.dailyNewTarget}개',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.tertiary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.tertiary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.72),
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.tertiary),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '열린 단어 $openedWords/${plan.totalWords}개 · 복습 ${stats?.dueCount ?? 0}개 · 학습 중 ${stats?.learningCount ?? 0}개',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
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
      case WordbookSource.builtin:
        return Icon(
          CupertinoIcons.book_fill,
          size: 24,
          color: theme.colorScheme.primary,
        );
    }
  }
}

class _WordbookPlanBuilderSheet extends StatefulWidget {
  final WordbookManager manager;
  final ScaffoldMessengerState messenger;
  final Wordbook wordbook;
  final List<Word> words;
  final StudyPlan? existingPlan;
  final int initialDailyTarget;

  const _WordbookPlanBuilderSheet({
    required this.manager,
    required this.messenger,
    required this.wordbook,
    required this.words,
    required this.existingPlan,
    required this.initialDailyTarget,
  });

  @override
  State<_WordbookPlanBuilderSheet> createState() => _WordbookPlanBuilderSheetState();
}

class _WordbookPlanBuilderSheetState extends State<_WordbookPlanBuilderSheet> {
  late final TextEditingController _dailyController;
  late final TextEditingController _targetDaysController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initialDailyTarget = widget.initialDailyTarget.clamp(1, widget.words.length).toInt();
    _dailyController = TextEditingController(text: '$initialDailyTarget');
    _targetDaysController = TextEditingController(
      text: '${(widget.words.length / initialDailyTarget).ceil()}',
    );
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

  int get _dailyTarget => _parseValue(_dailyController, 15).clamp(1, widget.words.length).toInt();

  int get _estimatedDays => (widget.words.length / _dailyTarget).ceil();

  DateTime get _targetDate => DateTime.now().add(Duration(days: _estimatedDays - 1));

  void _applyTargetDays() {
    final targetDays =
        _parseValue(_targetDaysController, _estimatedDays).clamp(1, widget.words.length).toInt();
    final dailyTarget = (widget.words.length / targetDays).ceil().clamp(1, widget.words.length);
    _setControllerText(_dailyController, '$dailyTarget');
    setState(() {});
  }

  void _applyDailyTarget() {
    final dailyTarget = _dailyTarget;
    _setControllerText(_targetDaysController, '${(widget.words.length / dailyTarget).ceil()}');
    setState(() {});
  }

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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.existingPlan == null ? '학습 플랜 만들기' : '학습 플랜 수정',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: '닫기',
                        onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(CupertinoIcons.xmark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.wordbook.name}의 새 단어를 며칠 동안 나눠 열지 정합니다. 복습 단어는 숨기지 않고, 새 단어만 일정에 맞춰 열립니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _targetDaysController,
                    enabled: !_isSaving,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '전체 단어를 며칠 동안 나눌까요?',
                      prefixIcon: Icon(CupertinoIcons.flag),
                      suffixText: '일',
                    ),
                    onChanged: (_) => _applyTargetDays(),
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
                    onChanged: (_) => _applyDailyTarget(),
                  ),
                  const SizedBox(height: 16),
                  _PlanSummaryStrip(
                    days: _estimatedDays,
                    dailyTarget: _dailyTarget,
                    totalWords: widget.words.length,
                    targetDate: targetDate,
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

class _PlanSummaryStrip extends StatelessWidget {
  final int days;
  final int dailyTarget;
  final int totalWords;
  final DateTime targetDate;

  const _PlanSummaryStrip({
    required this.days,
    required this.dailyTarget,
    required this.totalWords,
    required this.targetDate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.42)),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: [
          _PlanSummaryMetric(label: '총 단어', value: '$totalWords개'),
          _PlanSummaryMetric(label: '예상 기간', value: '$days일'),
          _PlanSummaryMetric(label: '하루 목표', value: '$dailyTarget개'),
          _PlanSummaryMetric(label: '예상 완료', value: '${targetDate.month}/${targetDate.day}'),
        ],
      ),
    );
  }
}

class _PlanSummaryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _PlanSummaryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 118,
      child: Column(
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
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
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
