// lib/screens/manage_words_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/database_service.dart';
import '../services/srs_service.dart';
import '../themes/app_theme.dart';
import 'add_edit_word_screen.dart';

class ManageWordsScreen extends StatefulWidget {
  final Wordbook wordbook;

  const ManageWordsScreen({super.key, required this.wordbook});

  @override
  State<ManageWordsScreen> createState() => _ManageWordsScreenState();
}

class _ManageWordsScreenState extends State<ManageWordsScreen> {
  late Future<List<Word>> _wordsFuture;
  final SrsService _srsService = SrsService();
  final TextEditingController _searchController = TextEditingController();
  SrsStage? _selectedStage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadWords();
    _searchController.addListener(() {
      if (!mounted) return;
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadWords() {
    if (!mounted) return;
    setState(() {
      _wordsFuture = context.read<DatabaseService>().getAllWords(widget.wordbook.dbFileName);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text("'${widget.wordbook.name}' 단어 편집")),
      body: FutureBuilder<List<Word>>(
        future: _wordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(child: Text('단어를 불러오지 못했습니다.'));
          }

          final allWords = snapshot.data ?? const <Word>[];
          final visibleWords = _applyFilters(allWords);

          if (allWords.isEmpty) {
            return const Center(child: Text('이 단어장에는 아직 단어가 없습니다.'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: '단어 또는 뜻 검색',
                    prefixIcon: const Icon(CupertinoIcons.search),
                    suffixIcon:
                        _searchQuery.isEmpty
                            ? null
                            : IconButton(
                              tooltip: '검색 지우기',
                              onPressed: _searchController.clear,
                              icon: const Icon(CupertinoIcons.clear_circled_solid),
                            ),
                    filled: true,
                    fillColor: scheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'SRS 기준으로 보기',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 42,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: const Text('전체'),
                        selected: _selectedStage == null,
                        onSelected: (_) => setState(() => _selectedStage = null),
                      ),
                    ),
                    ...SrsStage.values.map((stage) {
                      final count =
                          allWords.where((word) => _srsService.stageFor(word) == stage).length;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text('${_srsService.labelForStage(stage)} $count'),
                          selected: _selectedStage == stage,
                          onSelected: (_) => setState(() => _selectedStage = stage),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    visibleWords.isEmpty
                        ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? '조건에 맞는 단어가 없습니다.'
                                : '검색 결과가 없습니다.',
                          ),
                        )
                        : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
                          itemCount: visibleWords.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final word = visibleWords[index];
                            final stage = _srsService.stageFor(word);
                            final stageColor = _stageColor(stage);

                            return Dismissible(
                              key: ValueKey('word-${word.id}-${word.word}'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  CupertinoIcons.delete_solid,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (_) => _confirmDelete(context, word),
                              onDismissed: (_) async {
                                await context.read<WordbookManager>().deleteWordFrom(
                                  widget.wordbook,
                                  word.id!,
                                );
                                _loadWords();
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("'${word.word}' 단어를 삭제했습니다.")),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: scheme.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: scheme.outline.withValues(alpha: 0.28)),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                                  title: Text(
                                    word.word,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(word.meaning),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: stageColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                _srsService.labelForStage(stage),
                                                style: TextStyle(
                                                  color: stageColor,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _srsService.reasonForWord(word),
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: scheme.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  trailing: IconButton(
                                    tooltip: '단어 수정',
                                    icon: const Icon(CupertinoIcons.pencil),
                                    onPressed: () async {
                                      final resultHasChanged = await Navigator.of(context).push<bool>(
                                        MaterialPageRoute(
                                          builder:
                                              (_) => AddEditWordScreen(
                                                wordbook: widget.wordbook,
                                                word: word,
                                              ),
                                        ),
                                      );
                                      if (resultHasChanged == true) {
                                        _loadWords();
                                      }
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final resultHasChanged = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => AddEditWordScreen(wordbook: widget.wordbook)),
          );
          if (resultHasChanged == true) {
            _loadWords();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, Word word) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('단어 삭제'),
            content: Text("'${word.word}' 단어를 정말 삭제하시겠습니까?"),
            actions: [
              TextButton(
                child: const Text('취소'),
                onPressed: () => Navigator.pop(dialogContext, false),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                  foregroundColor: Theme.of(dialogContext).colorScheme.onError,
                ),
                child: const Text('삭제'),
                onPressed: () => Navigator.pop(dialogContext, true),
              ),
            ],
          ),
    );

    return confirmed ?? false;
  }

  List<Word> _applyFilters(List<Word> words) {
    final filtered =
        _selectedStage == null
            ? List<Word>.from(words)
            : words.where((word) => _srsService.stageFor(word) == _selectedStage).toList();

    final query = _searchQuery;
    final searched =
        query.isEmpty
            ? filtered
            : filtered.where((word) {
              final targetWord = word.word.toLowerCase();
              final targetMeaning = word.meaning.toLowerCase();
              final targetExample = (word.exampleSentence ?? '').toLowerCase();
              return targetWord.contains(query) ||
                  targetMeaning.contains(query) ||
                  targetExample.contains(query);
            }).toList();

    searched.sort((a, b) {
      final priorityA = _srsService.reviewPriority(a);
      final priorityB = _srsService.reviewPriority(b);
      if (priorityA != priorityB) {
        return priorityB.compareTo(priorityA);
      }
      return a.word.toLowerCase().compareTo(b.word.toLowerCase());
    });

    return searched;
  }

  Color _stageColor(SrsStage stage) {
    switch (stage) {
      case SrsStage.newWord:
        return Colors.blueGrey;
      case SrsStage.due:
        return AppTheme.accentCoral;
      case SrsStage.learning:
        return Colors.amber.shade800;
      case SrsStage.mature:
        return Colors.green;
    }
  }
}
