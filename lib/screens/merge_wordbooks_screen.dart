import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../themes/memorize_identity.dart';

class MergeWordbooksScreen extends StatefulWidget {
  const MergeWordbooksScreen({super.key});

  @override
  State<MergeWordbooksScreen> createState() => _MergeWordbooksScreenState();
}

class _MergeWordbooksScreenState extends State<MergeWordbooksScreen> {
  final Set<int> _selectedWordbookIds = {};
  bool _isMerging = false;

  Future<void> _onMerge() async {
    final manager = context.read<WordbookManager>();
    final messenger = ScaffoldMessenger.of(context);

    if (_selectedWordbookIds.length < 2) {
      messenger.showSnackBar(
        const SnackBar(content: Text('병합하려면 2개 이상의 단어장을 선택해주세요.')),
      );
      return;
    }

    final selectedIds = Set<int>.from(_selectedWordbookIds);
    var draftName = '';
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('새 단어장 이름'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: '단어장 이름',
              hintText: '병합된 단어장의 이름을 입력하세요',
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onChanged: (value) => draftName = value,
            onSubmitted:
                (value) =>
                    _popDialogAfterUnfocus<String>(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => _popDialogAfterUnfocus<String>(dialogContext),
            ),
            FilledButton(
              child: const Text('병합'),
              onPressed:
                  () => _popDialogAfterUnfocus<String>(
                    dialogContext,
                    draftName.trim(),
                  ),
            ),
          ],
        );
      },
    );

    await Future<void>.delayed(Duration.zero);
    if (!mounted || newName == null || newName.isEmpty) return;

    setState(() => _isMerging = true);
    MergeWordbooksResult result;
    try {
      result = await manager.mergeWordbooks(selectedIds, newName);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isMerging = false);
      messenger.showSnackBar(
        SnackBar(content: Text('단어장 병합 중 오류가 발생했습니다: $error')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isMerging = false);

    final deleteOriginals = await _confirmDeleteOriginals(result);
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    if (deleteOriginals == true) {
      setState(() => _isMerging = true);
      try {
        for (final wordbook in result.sourceWordbooks) {
          await manager.deleteWordbook(wordbook);
        }
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              "'${result.createdWordbook.name}' 병합 완료. 기존 단어장 ${result.sourceWordbooks.length}개를 삭제했습니다.",
            ),
          ),
        );
        setState(() => _selectedWordbookIds.clear());
      } catch (error) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text('기존 단어장 삭제 중 오류가 발생했습니다: $error')),
        );
      } finally {
        if (mounted) setState(() => _isMerging = false);
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            "'${result.createdWordbook.name}' 병합 완료. ${result.mergedWordCount}개 단어를 담았습니다.",
          ),
        ),
      );
      setState(() => _selectedWordbookIds.clear());
    }
  }

  Future<bool?> _confirmDeleteOriginals(MergeWordbooksResult result) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final duplicateText =
            result.duplicateSkippedCount > 0
                ? '\n중복 단어 ${result.duplicateSkippedCount}개는 제외했습니다.'
                : '';
        return AlertDialog(
          title: const Text('병합 완료'),
          content: Text(
            "'${result.createdWordbook.name}' 단어장이 생성되었습니다.\n"
            '${result.sourceWordbooks.length}개 단어장에서 ${result.mergedWordCount}개 단어를 가져왔습니다.'
            '$duplicateText\n\n'
            '병합에 사용한 기존 단어장들을 삭제할까요?',
          ),
          actions: [
            TextButton(
              child: const Text('유지'),
              onPressed:
                  () => _popDialogAfterUnfocus<bool>(dialogContext, false),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('삭제'),
              onPressed:
                  () => _popDialogAfterUnfocus<bool>(dialogContext, true),
            ),
          ],
        );
      },
    );
  }

  void _popDialogAfterUnfocus<T>(BuildContext dialogContext, [T? result]) {
    FocusScope.of(dialogContext).unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!dialogContext.mounted) return;
      Navigator.of(dialogContext).pop<T>(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<WordbookManager>();
    final List<Wordbook> wordbooks = manager.wordbooks;
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: const Text('단어장 병합')),
      body: SafeArea(
        top: false,
        child:
            wordbooks.isEmpty
                ? const Center(child: Text('병합할 단어장이 없습니다.'))
                : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: identity.softContext,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.merge_type,
                            color: identity.primaryAction,
                            size: 34,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '합칠 단어장을 두 개 이상 선택하세요.',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: identity.ink,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '기존 단어장은 그대로 유지됩니다.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: identity.mutedInk,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                        color: identity.surface,
                        borderRadius: BorderRadius.circular(
                          MemorizeIdentity.cardRadius,
                        ),
                        border: Border.all(color: identity.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${_selectedWordbookIds.length}개',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: identity.primaryAction,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' 선택됨',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          color: identity.ink,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          for (final indexed in wordbooks.indexed) ...[
                            if (indexed.$1 > 0)
                              Divider(height: 1, color: identity.border),
                            Builder(
                              builder: (context) {
                                final wordbook = indexed.$2;
                                final id = wordbook.id;
                                final selected =
                                    id != null &&
                                    _selectedWordbookIds.contains(id);
                                return FutureBuilder<int>(
                                  future: manager
                                      .getAllWordsFrom(wordbook)
                                      .then((words) => words.length),
                                  builder: (context, snapshot) {
                                    final count = snapshot.data;
                                    return Material(
                                      color:
                                          selected
                                              ? identity.softContext
                                              : identity.surface,
                                      child: InkWell(
                                        onTap:
                                            id == null || _isMerging
                                                ? null
                                                : () => setState(() {
                                                  if (selected) {
                                                    _selectedWordbookIds.remove(
                                                      id,
                                                    );
                                                  } else {
                                                    _selectedWordbookIds.add(
                                                      id,
                                                    );
                                                  }
                                                }),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                            14,
                                            14,
                                            12,
                                            14,
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                CupertinoIcons.book,
                                                color:
                                                    selected
                                                        ? identity.success
                                                        : identity.mutedInk,
                                                size: 28,
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      wordbook.name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: theme
                                                          .textTheme
                                                          .titleMedium
                                                          ?.copyWith(
                                                            color: identity.ink,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${_sourceLabel(wordbook.source)}${count == null ? '' : ' · 전체 $count개'}',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall
                                                          ?.copyWith(
                                                            color:
                                                                identity
                                                                    .mutedInk,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                selected
                                                    ? CupertinoIcons
                                                        .check_mark_circled_solid
                                                    : CupertinoIcons.circle,
                                                color:
                                                    selected
                                                        ? identity.primaryAction
                                                        : identity.border,
                                                size: 28,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: identity.surface,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          child: FilledButton.icon(
            onPressed: _isMerging ? null : _onMerge,
            icon:
                _isMerging
                    ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.merge_type),
            label: Text(
              _isMerging
                  ? '병합 중...'
                  : '선택한 단어장 합치기 (${_selectedWordbookIds.length}개)',
            ),
          ),
        ),
      ),
    );
  }

  String _sourceLabel(WordbookSource source) {
    switch (source) {
      case WordbookSource.googleSheet:
        return 'Google 시트';
      case WordbookSource.localCsv:
        return '로컬 파일';
      case WordbookSource.manual:
        return '직접 만든 단어장';
      case WordbookSource.builtin:
        return '기본 제공';
    }
  }
}
