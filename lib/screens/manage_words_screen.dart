import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart'; // ▼▼▼ [수정] WordbookManager import
import '../services/csv_service.dart';
import 'add_edit_word_screen.dart';

class ManageWordsScreen extends StatelessWidget {
  const ManageWordsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wordListNotifier = context.watch<WordListNotifier>();
    // ▼▼▼ [수정] activeWordbook 정보는 WordbookManager에서 가져옵니다. ▼▼▼
    final wordbookManager = context.watch<WordbookManager>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('단어 목록 관리'),
        actions: [
          // ▼▼▼ [수정] CSV 가져오기 버튼은 WordbookManagementScreen에 있으므로 여기서 제거합니다. ▼▼▼
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_up_doc),
            onPressed: () async {
              final activeWordbook = wordbookManager.activeWordbook;
              if (activeWordbook == null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('내보내기할 단어장을 먼저 선택해주세요.')));
                return;
              }
              await context.read<CsvService>().exportCsv(activeWordbook.dbFileName);
            },
            tooltip: 'CSV로 내보내기',
          ),
        ],
      ),
      body: SafeArea(
        child: Consumer<WordListNotifier>(
          builder: (context, notifier, child) {
            // ▼▼▼ [수정] activeWordbook 정보는 WordbookManager에서 가져옵니다. ▼▼▼
            if (wordbookManager.activeWordbook == null) {
              return const Center(child: Text('먼저 사용할 단어장을 선택해주세요.'));
            }
            if (notifier.words.isEmpty) {
              return const Center(child: Text('저장된 단어가 없습니다.\n우측 하단 버튼으로 추가해보세요.'));
            }
            return ListView.builder(
              itemCount: notifier.words.length,
              itemBuilder: (context, index) {
                final word = notifier.words[index];
                return Slidable(
                  key: ValueKey(word.id),
                  startActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    children: [
                      SlidableAction(
                        onPressed: (context) => notifier.deleteWord(word.id!),
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                        icon: Icons.delete,
                        label: '삭제',
                      ),
                    ],
                  ),
                  child: ListTile(
                    title: Text(word.word, style: theme.textTheme.bodyLarge),
                    subtitle: Text(word.meaning, style: theme.textTheme.bodyMedium),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => AddEditWordScreen(word: word))),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AddEditWordScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
