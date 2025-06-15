// screens/manage_words_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../providers/word_list_provider.dart';
import '../services/csv_service.dart';
import '../themes/app_theme.dart';
import 'add_edit_word_screen.dart';

class ManageWordsScreen extends StatelessWidget {
  const ManageWordsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // notifier를 위젯 트리 상단에서 한 번만 읽어옵니다.
    final wordListNotifier = context.read<WordListNotifier>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('단어 관리'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_down_doc),
            onPressed: () async {
              // ▼▼▼ 수정된 부분 ▼▼▼
              // importFromCsv 호출 로직을 notifier 내부로 옮겼으므로 그대로 사용합니다.
              await wordListNotifier.importFromCsv(context, context.read<CsvService>());
              // ▲▲▲ 수정된 부분 ▲▲▲
            },
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_up_doc),
            onPressed: () async {
              // ▼▼▼ 수정된 부분 ▼▼▼
              // 현재 활성화된 단어장이 있는지 확인합니다.
              final activeWordbook = wordListNotifier.activeWordbook;
              if (activeWordbook == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('내보내기할 단어장을 먼저 선택해주세요.')));
                }
                return;
              }
              // CsvService의 exportCsv 메서드에 현재 단어장의 dbFileName을 전달합니다.
              await context.read<CsvService>().exportCsv(activeWordbook.dbFileName);
              // ▲▲▲ 수정된 부분 ▲▲▲
            },
          ),
        ],
      ),
      body: Consumer<WordListNotifier>(
        builder: (context, notifier, child) {
          // 활성화된 단어장이 없는 경우의 UI
          if (notifier.activeWordbook == null) {
            return const Center(child: Text('먼저 사용할 단어장을 선택해주세요.'));
          }
          // 단어는 있지만 단어 목록이 비어있는 경우
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
                      backgroundColor: AppTheme.accentRed,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: '삭제',
                    ),
                  ],
                ),
                child: ListTile(
                  title: Text(word.word, style: theme.textTheme.bodyLarge),
                  subtitle: Text(
                    word.meaning,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.brightness == Brightness.light
                              ? AppTheme.subTextLight
                              : AppTheme.subTextDark,
                    ),
                  ),
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
      floatingActionButton: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        child: FloatingActionButton(
          onPressed:
              () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AddEditWordScreen())),
          backgroundColor: theme.primaryColor,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }
}
