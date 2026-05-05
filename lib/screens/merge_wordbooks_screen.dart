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

  Future<void> _onMerge() async {
    if (_selectedWordbookIds.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('병합하려면 2개 이상의 단어장을 선택해주세요.')));
      return;
    }

    final nameController = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('새 단어장 이름 입력'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: '새 단어장 이름',
              hintText: '병합된 단어장의 이름을 입력하세요',
            ),
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
          ),
          actions: [
            TextButton(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            FilledButton(
              child: const Text('병합'),
              onPressed: () => Navigator.pop(dialogContext, nameController.text.trim()),
            ),
          ],
        );
      },
    );
    nameController.dispose();
    if (!mounted || newName == null || newName.isEmpty) return;
    context.read<WordbookManager>().mergeWordbooks(
      _selectedWordbookIds,
      newName,
      context,
    );
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
                  return CheckboxListTile(
                    title: Text(wordbook.name),
                    subtitle: Text(
                      wordbook.source == WordbookSource.googleSheet ? 'Google 시트' : '로컬 파일',
                    ),
                    value: _selectedWordbookIds.contains(wordbook.id),
                    onChanged: (isSelected) {
                      setState(() {
                        if (isSelected == true) {
                          _selectedWordbookIds.add(wordbook.id!);
                        } else {
                          _selectedWordbookIds.remove(wordbook.id!);
                        }
                      });
                    },
                  );
                },
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onMerge,
        label: Text('선택한 단어장 합치기 (${_selectedWordbookIds.length}개)'),
        icon: const Icon(Icons.merge_type),
      ),
    );
  }
}
