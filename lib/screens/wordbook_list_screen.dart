// screens/wordbook_list_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../themes/app_theme.dart';
import 'home_screen.dart';
import 'select_spreadsheet_screen.dart'; // TODO: 다음 단계에서 생성할 파일

class WordbookListScreen extends StatelessWidget {
  const WordbookListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('내 단어장 목록')),
      body: Consumer<WordbookManager>(
        builder: (context, manager, child) {
          if (manager.isLoading && manager.wordbooks.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (manager.wordbooks.isEmpty) {
            return const Center(
              child: Text('단어장이 없습니다.\n아래 + 버튼을 눌러 새 단어장을 추가해보세요!', textAlign: TextAlign.center),
            );
          }

          return ListView.builder(
            itemCount: manager.wordbooks.length,
            itemBuilder: (context, index) {
              final wordbook = manager.wordbooks[index];
              final isActive = manager.activeWordbook?.id == wordbook.id;

              return Slidable(
                key: ValueKey(wordbook.id),
                endActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  children: [
                    SlidableAction(
                      onPressed: (context) => _confirmDelete(context, manager, wordbook),
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: '삭제',
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(wordbook.name, style: theme.textTheme.titleMedium),
                  subtitle: Text('ID: ${wordbook.spreadsheetId}', overflow: TextOverflow.ellipsis),
                  leading: Icon(
                    isActive ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.book_solid,
                    color: isActive ? theme.primaryColor : theme.iconTheme.color,
                  ),
                  onTap: () async {
                    await manager.setActiveWordbook(wordbook);
                    if (context.mounted) {
                      Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => const HomeScreen()));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: 다음 단계에서 SelectSpreadsheetScreen으로 이동하는 로직 구현
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen()));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('단어장 추가 기능 구현 예정')));
        },
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WordbookManager manager, Wordbook wordbook) {
    showCupertinoDialog(
      context: context,
      builder:
          (context) => CupertinoAlertDialog(
            title: const Text('단어장 삭제'),
            content: Text("'${wordbook.name}' 단어장을 정말 삭제하시겠습니까?\n이 작업은 되돌릴 수 없습니다."),
            actions: [
              CupertinoDialogAction(
                child: const Text('취소'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('삭제'),
                onPressed: () {
                  manager.deleteWordbook(wordbook);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
    );
  }
}
