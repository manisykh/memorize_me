import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../widgets/glassmorphic_card.dart';
import 'manage_words_screen.dart';
import 'merge_wordbooks_screen.dart';
import 'select_spreadsheet_screen.dart';

class WordbookManagementScreen extends StatelessWidget {
  const WordbookManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ▼▼▼ [수정] 배경 투명화 ▼▼▼
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('내 단어장'), automaticallyImplyLeading: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: _buildWordbookList(context),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WordbookManager manager, Wordbook wordbook) {
    showCupertinoDialog(
      context: context,
      builder:
          (_) => CupertinoAlertDialog(
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

  Widget _getSourceIcon(WordbookSource source, ThemeData theme) {
    switch (source) {
      case WordbookSource.googleSheet:
        return Image.asset('assets/icons/google_sheet_icon.png', width: 24, height: 24);
      case WordbookSource.localCsv:
        return Icon(
          CupertinoIcons.doc_text_fill,
          size: 24,
          color: theme.textTheme.bodyLarge?.color?.withOpacity(0.9),
        );
    }
  }

  Widget _buildWordbookList(BuildContext context) {
    final manager = context.watch<WordbookManager>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('단어장 도구', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: GlassmorphicCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen())),
                    child: Column(
                      children: [
                        Image.asset(
                          'assets/icons/google_sheet_icon.png',
                          height: 24,
                          width: 24,
                        ), // 아이콘 복원
                        const SizedBox(height: 8),
                        Text('Google 시트', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassmorphicCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    onTap: () => manager.createNewWordbookFromCsv(context),
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.folder_open),
                        const SizedBox(height: 8),
                        Text('로컬 파일', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // 두 줄 사이의 간격
            Row(
              children: [
                Expanded(
                  child: GlassmorphicCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const MergeWordbooksScreen())),
                    child: Column(
                      children: [
                        const Icon(Icons.merge_type),
                        const SizedBox(height: 8),
                        Text('단어장 병합', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassmorphicCard(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    onTap:
                        () => Navigator.of(
                          context,
                        ).push(MaterialPageRoute(builder: (_) => const ManageWordsScreen())),
                    child: Column(
                      children: [
                        const Icon(CupertinoIcons.pencil_ellipsis_rectangle),
                        const SizedBox(height: 8),
                        Text('단어 편집', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('단어장 목록', style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        if (manager.wordbooks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: Text("추가된 단어장이 없습니다.", style: theme.textTheme.bodyMedium)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: manager.wordbooks.length,
            itemBuilder: (context, index) {
              final wordbook = manager.wordbooks[index];
              final isActive = manager.activeWordbook?.id == wordbook.id;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: GlassmorphicCard(
                  isActive: isActive,
                  onTap: () => manager.setActiveWordbook(wordbook),
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: _getSourceIcon(wordbook.source, theme),
                    title: Text(
                      wordbook.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        CupertinoIcons.trash,
                        color: theme.iconTheme.color?.withOpacity(0.7),
                      ),
                      onPressed: () => _confirmDelete(context, manager, wordbook),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
