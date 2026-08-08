import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';

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
                (value) => _popDialogAfterUnfocus<String>(dialogContext, value.trim()),
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
      messenger.showSnackBar(SnackBar(content: Text('단어장 병합 중 오류가 발생했습니다: $error')));
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
        messenger.showSnackBar(SnackBar(content: Text('기존 단어장 삭제 중 오류가 발생했습니다: $error')));
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
              onPressed: () => _popDialogAfterUnfocus<bool>(dialogContext, false),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onError,
              ),
              child: const Text('삭제'),
              onPressed: () => _popDialogAfterUnfocus<bool>(dialogContext, true),
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
    final List<Wordbook> wordbooks = context.watch<WordbookManager>().wordbooks;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('단어장 병합')),
      body:
          wordbooks.isEmpty
              ? const Center(child: Text('병합할 단어장이 없습니다.'))
              : ListView.builder(
                itemCount: wordbooks.length,
                itemBuilder: (context, index) {
                  final wordbook = wordbooks[index];
                  final id = wordbook.id;
                  return CheckboxListTile(
                    title: Text(wordbook.name),
                    subtitle: Text(_sourceLabel(wordbook.source)),
                    value: id != null && _selectedWordbookIds.contains(id),
                    onChanged:
                        id == null || _isMerging
                            ? null
                            : (isSelected) {
                              setState(() {
                                if (isSelected == true) {
                                  _selectedWordbookIds.add(id);
                                } else {
                                  _selectedWordbookIds.remove(id);
                                }
                              });
                            },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isMerging ? null : _onMerge,
        label:
            _isMerging
                ? const Text('병합 중...')
                : Text('선택한 단어장 합치기 (${_selectedWordbookIds.length}개)'),
        icon:
            _isMerging
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : const Icon(Icons.merge_type),
      ),
    );
  }

  String _sourceLabel(WordbookSource source) {
    switch (source) {
      case WordbookSource.googleSheet:
        return 'Google 시트';
      case WordbookSource.localCsv:
        return '로컬 파일';
      case WordbookSource.builtin:
        return '기본 제공';
    }
  }
}
