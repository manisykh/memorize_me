import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../providers/word_list_provider.dart';
import '../services/csv_service.dart';
import '../themes/app_theme.dart';
import 'add_edit_word_screen.dart';

class ManageWordsScreen extends StatelessWidget {
  const ManageWordsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('단어 관리'),
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_down_doc),
            onPressed:
                () async => await context.read<WordListNotifier>().importFromCsv(
                  context,
                  context.read<CsvService>(),
                ),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.arrow_up_doc),
            onPressed: () async => await context.read<CsvService>().exportCsv(),
          ),
        ],
      ),
      body: Consumer<WordListNotifier>(
        builder: (context, notifier, child) {
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
                      onPressed: (context) => context.read<WordListNotifier>().deleteWord(word.id!),
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
