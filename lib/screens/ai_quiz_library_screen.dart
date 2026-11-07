import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/saved_ai_quiz.dart';
import '../services/ai_quiz_library_service.dart';
import '../themes/memorize_identity.dart';
import 'ai_quiz_player_screen.dart';

class AiQuizLibraryScreen extends StatefulWidget {
  const AiQuizLibraryScreen({super.key});

  @override
  State<AiQuizLibraryScreen> createState() => _AiQuizLibraryScreenState();
}

class _AiQuizLibraryScreenState extends State<AiQuizLibraryScreen> {
  bool _selecting = false;
  AiQuizCategory? _categoryFilter;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => context.read<AiQuizLibraryService>().load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final library = context.watch<AiQuizLibraryService>();
    final items = library.items;
    final visibleItems =
        _categoryFilter == null
            ? items
            : items.where((item) => item.category == _categoryFilter).toList();
    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(
        title: Text(_selecting ? '${_selectedIds.length}개 선택' : '저장된 AI 퀴즈'),
        actions: [
          if (items.length >= 2)
            TextButton(
              onPressed:
                  () => setState(() {
                    _selecting = !_selecting;
                    if (!_selecting) _selectedIds.clear();
                  }),
              child: Text(_selecting ? '취소' : '합치기'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child:
            !library.loaded
                ? const Center(child: CircularProgressIndicator())
                : items.isEmpty
                ? _EmptyLibrary(identity: identity)
                : Column(
                  children: [
                    _CategoryFilters(
                      items: items,
                      selected: _categoryFilter,
                      identity: identity,
                      onSelected:
                          (category) => setState(() {
                            _categoryFilter = category;
                            _selectedIds.clear();
                          }),
                    ),
                    Expanded(
                      child:
                          visibleItems.isEmpty
                              ? _EmptyCategory(identity: identity)
                              : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  30,
                                ),
                                itemCount: visibleItems.length,
                                separatorBuilder:
                                    (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final item = visibleItems[index];
                                  final selected = _selectedIds.contains(
                                    item.id,
                                  );
                                  return _SavedQuizCard(
                                    item: item,
                                    selected: selected,
                                    selecting: _selecting,
                                    identity: identity,
                                    onTap: () {
                                      if (_selecting) {
                                        setState(() {
                                          selected
                                              ? _selectedIds.remove(item.id)
                                              : _selectedIds.add(item.id);
                                        });
                                      } else {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => AiQuizPlayerScreen(
                                                  quizResponse: item.quiz,
                                                  savedTitle: item.title,
                                                  savedCategory: item.category,
                                                ),
                                          ),
                                        );
                                      }
                                    },
                                    onDelete: () => _delete(item),
                                  );
                                },
                              ),
                    ),
                  ],
                ),
      ),
      bottomNavigationBar:
          !_selecting
              ? null
              : SafeArea(
                minimum: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: FilledButton.icon(
                  onPressed: _selectedIds.length < 2 ? null : _merge,
                  icon: const Icon(Icons.merge_rounded),
                  label: Text('선택한 ${_selectedIds.length}개 퀴즈 합치기'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: const StadiumBorder(),
                  ),
                ),
              ),
    );
  }

  Future<void> _delete(SavedAiQuiz item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('저장된 퀴즈를 삭제할까요?'),
            content: Text(item.title),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('삭제'),
              ),
            ],
          ),
    );
    if (confirmed == true && mounted) {
      await context.read<AiQuizLibraryService>().delete(item.id);
    }
  }

  Future<void> _merge() async {
    final library = context.read<AiQuizLibraryService>();
    final selected =
        library.items.where((item) => _selectedIds.contains(item.id)).toList();
    var draftTitle =
        '합친 AI 퀴즈 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    final title = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('합친 퀴즈 이름'),
            content: TextFormField(
              initialValue: draftTitle,
              autofocus: true,
              decoration: const InputDecoration(labelText: '퀴즈 이름'),
              textInputAction: TextInputAction.done,
              onChanged: (value) => draftTitle = value,
              onFieldSubmitted: (value) {
                final normalized = value.trim();
                if (normalized.isEmpty) return;
                FocusScope.of(dialogContext).unfocus();
                Navigator.pop(dialogContext, normalized);
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  final normalized = draftTitle.trim();
                  if (normalized.isEmpty) return;
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.pop(dialogContext, normalized);
                },
                child: const Text('합치기'),
              ),
            ],
          ),
    );
    if (title == null || !mounted) return;
    final merged = await library.merge(quizzes: selected, title: title);
    if (!mounted) return;
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => AiQuizPlayerScreen(
              quizResponse: merged.quiz,
              savedTitle: merged.title,
              savedCategory: merged.category,
            ),
      ),
    );
  }
}

class _SavedQuizCard extends StatelessWidget {
  const _SavedQuizCard({
    required this.item,
    required this.selected,
    required this.selecting,
    required this.identity,
    required this.onTap,
    required this.onDelete,
  });

  final SavedAiQuiz item;
  final bool selected;
  final bool selecting;
  final MemorizeIdentity identity;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? identity.softContext : identity.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        side: BorderSide(
          color: selected ? identity.primaryAction : identity.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
          child: Row(
            children: [
              Icon(
                selecting
                    ? selected
                        ? CupertinoIcons.check_mark_circled_solid
                        : CupertinoIcons.circle
                    : CupertinoIcons.doc_text_fill,
                color: selected ? identity.primaryAction : identity.success,
                size: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: identity.softContext,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.category.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: identity.primaryAction,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            '${item.quiz.answerableQuestionCount}문제 · ${DateFormat('yyyy.MM.dd HH:mm').format(item.createdAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: identity.mutedInk,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (item.sourceTitles.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        '${item.sourceTitles.length}개 퀴즈를 합친 항목',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: identity.primaryAction,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (!selecting)
                IconButton(
                  tooltip: '삭제',
                  onPressed: onDelete,
                  icon: Icon(CupertinoIcons.delete, color: identity.mutedInk),
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

class _CategoryFilters extends StatelessWidget {
  const _CategoryFilters({
    required this.items,
    required this.selected,
    required this.identity,
    required this.onSelected,
  });

  final List<SavedAiQuiz> items;
  final AiQuizCategory? selected;
  final MemorizeIdentity identity;
  final ValueChanged<AiQuizCategory?> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(AiQuizCategory? category) =>
        category == null
            ? items.length
            : items.where((item) => item.category == category).length;

    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
        children: [
          _CategoryChip(
            label: '전체',
            count: count(null),
            selected: selected == null,
            identity: identity,
            onTap: () => onSelected(null),
          ),
          for (final category in AiQuizCategory.values) ...[
            const SizedBox(width: 8),
            _CategoryChip(
              label: category.label,
              count: count(category),
              selected: selected == category,
              identity: identity,
              onTap: () => onSelected(category),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.identity,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final MemorizeIdentity identity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? identity.primaryAction : identity.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? identity.primaryAction : identity.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            '$label $count',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyCategory extends StatelessWidget {
  const _EmptyCategory({required this.identity});

  final MemorizeIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '이 카테고리에 저장된 퀴즈가 없습니다.',
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: identity.mutedInk),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary({required this.identity});

  final MemorizeIdentity identity;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.manage_search_rounded,
              size: 52,
              color: identity.mutedInk,
            ),
            const SizedBox(height: 14),
            Text(
              '저장된 AI 퀴즈가 없습니다.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '생성한 퀴즈 화면에서 저장하면 이곳에서 다시 보거나 합칠 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(color: identity.mutedInk),
            ),
          ],
        ),
      ),
    );
  }
}
