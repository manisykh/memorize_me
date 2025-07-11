import 'package:flutter/cupertino.dart';
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

  void _onMerge() {
    if (_selectedWordbookIds.length < 2) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('병합하려면 2개 이상의 단어장을 선택해주세요.')));
      return;
    }

    final nameController = TextEditingController();

    showCupertinoDialog(
      context: context,
      builder: (dialogContext) {
        return CupertinoAlertDialog(
          title: const Text('새 단어장 이름 입력'),
          content: Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: CupertinoTextField(
              controller: nameController,
              placeholder: '병합된 단어장의 이름을 입력하세요',
              autofocus: true,
            ),
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('취소'),
              onPressed: () => Navigator.pop(dialogContext),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('병합'),
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.pop(dialogContext);
                  context.read<WordbookManager>().mergeWordbooks(
                    _selectedWordbookIds,
                    newName,
                    context,
                  );
                }
              },
            ),
          ],
        );
      },
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
