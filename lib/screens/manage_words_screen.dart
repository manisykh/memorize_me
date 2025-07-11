// lib/screens/manage_words_screen.dart (수정된 전체 코드)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import 'add_edit_word_screen.dart';

class ManageWordsScreen extends StatelessWidget {
  const ManageWordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider를 통해 현재 활성화된 단어장 정보와 단어 목록을 가져옵니다.
    final activeWordbookName = context.watch<WordbookManager>().activeWordbook?.name;
    final wordListNotifier = context.watch<WordListNotifier>();
    final words = wordListNotifier.words;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(activeWordbookName ?? '단어 편집')),
      body:
          words.isEmpty
              ? const Center(child: Text('단어장에 단어가 없습니다.'))
              : ListView.builder(
                itemCount: words.length,
                itemBuilder: (context, index) {
                  final word = words[index];
                  return ListTile(
                    title: Text(word.word),
                    subtitle: Text(word.meaning),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 수정 버튼
                        IconButton(
                          icon: const Icon(CupertinoIcons.pencil),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                // 단어 수정 화면으로 이동 (기존 단어 정보 전달)
                                builder: (_) => AddEditWordScreen(word: word),
                              ),
                            );
                          },
                        ),
                        // 삭제 버튼
                        IconButton(
                          icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                          onPressed: () {
                            // 삭제 확인 다이얼로그 표시
                            showCupertinoDialog(
                              context: context,
                              builder:
                                  (dialogContext) => CupertinoAlertDialog(
                                    title: const Text('단어 삭제'),
                                    content: Text("'${word.word}' 단어를 정말 삭제하시겠습니까?"),
                                    actions: [
                                      CupertinoDialogAction(
                                        child: const Text('취소'),
                                        onPressed: () => Navigator.pop(dialogContext),
                                      ),
                                      CupertinoDialogAction(
                                        isDestructiveAction: true,
                                        child: const Text('삭제'),
                                        onPressed: () {
                                          wordListNotifier.deleteWord(word.id!);
                                          Navigator.pop(dialogContext);
                                        },
                                      ),
                                    ],
                                  ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
      // 새 단어 추가 버튼
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              // 단어 추가 화면으로 이동 (단어 정보 없음)
              builder: (_) => const AddEditWordScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
