import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../widgets/glassmorphic_card.dart';
import 'manage_words_screen.dart';
import 'merge_wordbooks_screen.dart';
import 'select_spreadsheet_screen.dart';

class WordbookManagementScreen extends StatefulWidget {
  const WordbookManagementScreen({super.key});

  @override
  State<WordbookManagementScreen> createState() => _WordbookManagementScreenState();
}

class _WordbookManagementScreenState extends State<WordbookManagementScreen> {
  Wordbook? _selectedForEditing;

  @override
  void initState() {
    super.initState();
    _selectedForEditing = context.read<WordbookManager>().activeWordbook;
  }

  Widget _buildToolCard({
    required BuildContext context,
    required Widget icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return GlassmorphicCard(
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Column(
        children: [icon, const SizedBox(height: 8), Text(label, style: theme.textTheme.bodySmall)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final manager = context.watch<WordbookManager>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('내 단어장'), automaticallyImplyLeading: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('단어장 도구', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),

              // ▼▼▼ [수정] 2x2 배열로 레이아웃 변경 ▼▼▼
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          context: context,
                          icon: Image.asset(
                            'assets/icons/google_sheet_icon.png',
                            height: 24,
                            width: 24,
                          ),
                          label: 'Google 시트',
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const SelectSpreadsheetScreen()),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToolCard(
                          context: context,
                          icon: const Icon(CupertinoIcons.folder_open),
                          label: '로컬 파일',
                          onTap: () => manager.createNewWordbookFromCsv(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildToolCard(
                          context: context,
                          icon: const Icon(CupertinoIcons.pencil_ellipsis_rectangle),
                          label: '단어 편집',
                          onTap: () {
                            if (_selectedForEditing != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ManageWordsScreen(wordbook: _selectedForEditing!),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('편집할 단어장을 목록에서 선택해주세요.')),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildToolCard(
                          context: context,
                          icon: const Icon(Icons.merge_type),
                          label: '단어장 병합',
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const MergeWordbooksScreen()),
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('단어장 목록 (탭하여 편집 대상으로 선택)', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              if (manager.wordbooks.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Center(child: Text("추가된 단어장이 없습니다.")),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: manager.wordbooks.length,
                  itemBuilder: (context, index) {
                    final wordbook = manager.wordbooks[index];
                    final isSelectedForEditing = _selectedForEditing?.id == wordbook.id;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: GlassmorphicCard(
                        isActive: isSelectedForEditing,
                        onTap: () {
                          setState(() {
                            _selectedForEditing = wordbook;
                          });
                        },
                        padding: const EdgeInsets.only(left: 16, right: 8),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _getSourceIcon(wordbook.source, theme),
                          title: Text(
                            wordbook.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight:
                                  isSelectedForEditing ? FontWeight.bold : FontWeight.normal,
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
          ),
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
}
