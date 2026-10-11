import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/study_plan_model.dart';
import '../widgets/study_plan_panel.dart';
import '../services/study_schedule_service.dart';
import '../services/study_history_service.dart';
import '../services/wordbook_xlsx_service.dart';
import '../widgets/wordbook_xlsx_export_dialog.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../themes/memorize_identity.dart';
import '../widgets/glassmorphic_card.dart';
import 'flashcard_screen.dart';
import 'manage_words_screen.dart';
import 'merge_wordbooks_screen.dart';
import 'select_sheet_screen.dart';
import 'select_spreadsheet_screen.dart';

class WordbookManagementScreen extends StatefulWidget {
  const WordbookManagementScreen({super.key});

  @override
  State<WordbookManagementScreen> createState() =>
      _WordbookManagementScreenState();
}

class _WordbookManagementScreenState extends State<WordbookManagementScreen> {
  final SrsService _srsService = SrsService();
  final Map<Object, Future<_WordbookStatsSnapshot>> _statsFutures = {};
  final _searchController = TextEditingController();

  Timer? _debounce;
  Map<Wordbook, List<Word>> _searchResults = {};
  bool _isSearching = false;
  bool _creatingManualWordbook = false;
  final Set<String> _sharingWordbooks = {};
  int? _lastStatsRevision;

  @override
  void initState() {
    super.initState();
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
      backgroundColor: MemorizeIdentity.of(theme).canvas,
      appBar: AppBar(
        title: const Text('단어장 관리'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.colorScheme.outline),
                ),
                child: TextField(
                  controller: _searchController,
                  textAlignVertical: TextAlignVertical.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(CupertinoIcons.search),
                    hintText: '단어장 검색',
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
                              icon: const Icon(
                                CupertinoIcons.xmark_circle_fill,
                              ),
                              onPressed: _searchController.clear,
                            )
                            : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child:
                    isSearchingMode
                        ? _buildSearchResults()
                        : _buildDefaultView(theme, manager),
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
    final identity = MemorizeIdentity.of(theme);
    final active = manager.activeWordbook;
    final orderedWordbooks = List<Wordbook>.from(manager.wordbooks)
      ..sort((a, b) {
        final aActive = _isActiveWordbook(active, a);
        final bActive = _isActiveWordbook(active, b);
        if (aActive == bActive) return 0;
        return aActive ? -1 : 1;
      });

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWordbookAddPanel(theme, manager),
          const SizedBox(height: 26),
          _buildSectionTitle(theme, '단어장 목록'),
          const SizedBox(height: 6),
          Text(
            '학습할 단어장을 선택하고 관리할 수 있어요.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w600,
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
              itemCount: orderedWordbooks.length,
              itemBuilder: (context, index) {
                final wordbook = orderedWordbooks[index];
                final isActive = _isActiveWordbook(
                  manager.activeWordbook,
                  wordbook,
                );
                final studyPlan = manager.planFor(wordbook);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: FutureBuilder<_WordbookStatsSnapshot>(
                    future: _statsFutureFor(manager, wordbook),
                    builder: (context, snapshot) {
                      return _buildManagedWordbookCard(
                        theme: theme,
                        manager: manager,
                        wordbook: wordbook,
                        stats: snapshot.data,
                        studyPlan: studyPlan,
                        isActive: isActive,
                      );
                    },
                  ),
                );
              },
            ),
          if (manager.wordbooks.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildMergeEntry(theme),
          ],
          if (manager.builtinWordbookTemplates.isNotEmpty) ...[
            const SizedBox(height: 26),
            _buildSectionTitle(theme, '필수 영어단어 6000'),
            const SizedBox(height: 12),
            _buildBuiltinWordbookSection(theme, manager),
          ],
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

  Future<void> _activateWordbook(
    WordbookManager manager,
    Wordbook wordbook,
  ) async {
    await manager.setActiveWordbook(wordbook);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('현재 학습 기준을 ${wordbook.name}(으)로 변경했습니다.')),
    );
  }

  void _openManageWords(Wordbook wordbook) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ManageWordsScreen(wordbook: wordbook)),
    );
  }

  Future<void> _createManualWordbook() async {
    var draftName = '';
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('나만의 단어장 만들기'),
            content: Form(
              key: formKey,
              child: TextFormField(
                autofocus: true,
                maxLength: 80,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(labelText: '단어장 이름'),
                onChanged: (value) => draftName = value,
                validator:
                    (value) =>
                        value == null || value.trim().isEmpty
                            ? '이름을 입력해주세요.'
                            : null,
                onFieldSubmitted: (_) {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(dialogContext).pop(draftName.trim());
                  }
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.of(dialogContext).pop(draftName.trim());
                  }
                },
                child: const Text('만들기'),
              ),
            ],
          ),
    );
    if (!mounted || name == null) return;
    setState(() => _creatingManualWordbook = true);
    try {
      final book = await context.read<WordbookManager>().createManualWordbook(
        name,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ManageWordsScreen(wordbook: book)),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('단어장을 만들지 못했습니다: $error')));
      }
    } finally {
      if (mounted) setState(() => _creatingManualWordbook = false);
    }
  }

  Future<void> _shareWordbook(Wordbook book) async {
    setState(() => _sharingWordbooks.add(book.dbFileName));
    try {
      final words = await context.read<WordbookManager>().getAllWordsFrom(book);
      if (words.isEmpty) throw StateError('공유할 단어가 없습니다.');
      if (!mounted) return;
      final options = await showWordbookXlsxExportDialog(context, words);
      if (options == null) return;
      await const WordbookXlsxService().share(
        book,
        words.reversed.toList(),
        options: options,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('XLSX를 공유하지 못했습니다: $error')));
      }
    } finally {
      if (mounted) setState(() => _sharingWordbooks.remove(book.dbFileName));
    }
  }

  Widget _buildManagedWordbookCard({
    required ThemeData theme,
    required WordbookManager manager,
    required Wordbook wordbook,
    required _WordbookStatsSnapshot? stats,
    required StudyPlan? studyPlan,
    required bool isActive,
  }) {
    final identity = MemorizeIdentity.of(theme);
    final isSharing = _sharingWordbooks.contains(wordbook.dbFileName);
    final metadata =
        stats == null
            ? '학습 현황 확인 중'
            : '전체 ${stats.totalWords}개 · 오늘 복습 ${stats.dueCount}개 · 새 단어 ${stats.newCount}개';
    final planLabel =
        studyPlan == null
            ? null
            : studyPlan.mode == StudyPlanMode.free
            ? '플랜 ${studyPlan.currentChunk()}/${studyPlan.chunkCount}'
            : studyPlan.progressLabel;

    Future<void> handleAction(String action) async {
      switch (action) {
        case 'edit':
          _openManageWords(wordbook);
          return;
        case 'plan':
          await _showStudyPlanBuilder(wordbook);
          return;
        case 'share':
          await _shareWordbook(wordbook);
          return;
        case 'delete':
          _confirmDelete(context, manager, wordbook);
          return;
      }
    }

    return Material(
      color: isActive ? identity.softContext : identity.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        side: BorderSide(
          color:
              isActive
                  ? identity.primaryAction.withValues(alpha: 0.24)
                  : identity.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isActive ? null : () => _activateWordbook(manager, wordbook),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
          child: Column(
            children: [
              Row(
                children: [
                  _getSourceIcon(wordbook.source, theme),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                wordbook.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: identity.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: 8),
                              _buildBadge(
                                context,
                                '현재 학습',
                                identity.primaryAction,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: identity.mutedInk,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (planLabel != null) ...[
                    const SizedBox(width: 8),
                    _buildBadge(context, planLabel, identity.primaryAction),
                  ],
                  PopupMenuButton<String>(
                    tooltip: '단어장 관리 메뉴',
                    onSelected: handleAction,
                    itemBuilder:
                        (context) => [
                          if (!isActive)
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('단어 편집'),
                            ),
                          if (!isActive)
                            PopupMenuItem(
                              value: 'plan',
                              child: Text(
                                studyPlan == null ? '플랜 만들기' : '플랜 수정',
                              ),
                            ),
                          if (!isActive && (stats?.totalWords ?? 0) > 0)
                            const PopupMenuItem(
                              value: 'share',
                              child: Text('XLSX 공유'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('단어장 삭제'),
                          ),
                        ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: identity.border),
              const SizedBox(height: 10),
              if (isActive)
                Row(
                  children: [
                    Expanded(
                      child: _CompactWordbookAction(
                        icon: CupertinoIcons.pencil,
                        label: '단어 편집',
                        onTap: () => _openManageWords(wordbook),
                      ),
                    ),
                    Expanded(
                      child: _CompactWordbookAction(
                        icon: CupertinoIcons.calendar,
                        label: studyPlan == null ? '플랜 만들기' : '플랜 수정',
                        onTap: () => _showStudyPlanBuilder(wordbook),
                      ),
                    ),
                    Expanded(
                      child: _CompactWordbookAction(
                        icon: CupertinoIcons.share,
                        label: isSharing ? '준비 중' : 'XLSX 공유',
                        onTap:
                            isSharing || (stats?.totalWords ?? 0) == 0
                                ? null
                                : () => _shareWordbook(wordbook),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _activateWordbook(manager, wordbook),
                    child: const Text('이 단어장 사용'),
                  ),
                ),
            ],
          ),
        ),
      ),
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

  Future<void> _showStudyPlanBuilder(Wordbook wordbook) =>
      showStudyPlanEditor(context, wordbook);

  Widget _buildWordbookAddPanel(ThemeData theme, WordbookManager manager) {
    final identity = MemorizeIdentity.of(theme);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '단어장 추가',
            style: theme.textTheme.titleLarge?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '다양한 방법으로 나만의 단어장을 만들어보세요.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: identity.mutedInk,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _creatingManualWordbook ? null : _createManualWordbook,
              icon:
                  _creatingManualWordbook
                      ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(CupertinoIcons.plus_circle),
              label: const Text('나만의 단어장 만들기'),
            ),
          ),
          const SizedBox(height: 10),
          _ManagementActionRow(
            icon: Image.asset(
              'assets/icons/google_sheet_icon.png',
              width: 24,
              height: 24,
            ),
            label: 'Google 시트에서 가져오기',
            onTap: _openGoogleSheetImport,
          ),
          const SizedBox(height: 8),
          _ManagementActionRow(
            icon: Icon(CupertinoIcons.doc, color: identity.ink, size: 24),
            label: 'CSV · XLSX 파일에서 가져오기',
            onTap: () => manager.createNewWordbookFromCsv(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMergeEntry(ThemeData theme) {
    final identity = MemorizeIdentity.of(theme);
    return Material(
      color: identity.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        side: BorderSide(color: identity.border),
      ),
      child: InkWell(
        onTap: _openMergeWordbooks,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Icon(Icons.merge_type, color: identity.mutedInk, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '단어장 병합',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '두 개의 단어장을 하나로 합칠 수 있어요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: identity.mutedInk,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMergeWordbooks() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const MergeWordbooksScreen()));
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '직접 기록하거나 파일에서 단어를 가져와 학습할 수 있습니다.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _createManualWordbook,
              icon: const Icon(CupertinoIcons.pencil),
              label: const Text('나만의 단어장 만들기'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
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

  Widget _buildBuiltinWordbookSection(
    ThemeData theme,
    WordbookManager manager,
  ) {
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
          await manager.addBuiltinWordbook(template);
          if (!mounted) return;
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
          messenger.showSnackBar(
            SnackBar(content: Text('기본 단어장을 추가하지 못했습니다: $e')),
          );
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
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                      : theme.colorScheme.surfaceContainerHighest.withValues(
                        alpha: 0.72,
                      ),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isActive
                  ? '현재'
                  : isAdded
                  ? '추가됨'
                  : '추가',
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    isActive ? accentColor : theme.colorScheme.onSurfaceVariant,
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

  Future<_WordbookStatsSnapshot> _statsFutureFor(
    WordbookManager manager,
    Wordbook wordbook,
  ) {
    final key = wordbook.id ?? wordbook.dbFileName;
    return _statsFutures.putIfAbsent(key, () async {
      final words = await manager.getAllWordsFrom(wordbook);
      final studyPlan = manager.planFor(wordbook);
      final scopedWords = StudyScheduleService().availableWords(
        words,
        studyPlan,
        introducedToday:
            StudyHistoryService.instance
                .introducedKeys(wordbook.dbFileName, DateTime.now())
                .length,
      );
      final plan = _srsService.buildDailyPlan(scopedWords);
      return _WordbookStatsSnapshot(
        totalWords: words.length,
        studiedCount: words.where((w) => !_srsService.isNewWord(w)).length,
        dueCount: plan.dueWords.length,
        newCount: plan.newWords.length,
        learningCount: plan.learningWords.length,
        scheduledCount: plan.scheduledWords.length,
      );
    });
  }

  void _confirmDelete(
    BuildContext context,
    WordbookManager manager,
    Wordbook wordbook,
  ) {
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
        return Image.asset(
          'assets/icons/google_sheet_icon.png',
          width: 24,
          height: 24,
        );
      case WordbookSource.localCsv:
        return Icon(
          CupertinoIcons.doc_text_fill,
          size: 24,
          color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.9),
        );
      case WordbookSource.manual:
        return Icon(
          CupertinoIcons.pencil,
          size: 24,
          color: theme.colorScheme.primary,
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

class _ManagementActionRow extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onTap;

  const _ManagementActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Material(
      color: identity.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: identity.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              SizedBox(width: 28, height: 28, child: Center(child: icon)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: identity.mutedInk,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactWordbookAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _CompactWordbookAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: onTap == null ? identity.border : identity.primaryAction,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color:
                    onTap == null
                        ? identity.mutedInk.withValues(alpha: 0.55)
                        : identity.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WordbookStatsSnapshot {
  final int totalWords;
  final int studiedCount;
  final int dueCount;
  final int newCount;
  final int learningCount;
  final int scheduledCount;

  const _WordbookStatsSnapshot({
    required this.totalWords,
    required this.studiedCount,
    required this.dueCount,
    required this.newCount,
    required this.learningCount,
    required this.scheduledCount,
  });
}
