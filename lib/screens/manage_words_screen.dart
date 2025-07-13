// lib/screens/manage_words_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/database_service.dart';
import 'add_edit_word_screen.dart';

class ManageWordsScreen extends StatefulWidget {
  final Wordbook wordbook;
  const ManageWordsScreen({super.key, required this.wordbook});

  @override
  State<ManageWordsScreen> createState() => _ManageWordsScreenState();
}

class _ManageWordsScreenState extends State<ManageWordsScreen> {
  late Future<List<Word>> _wordsFuture;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  void _loadWords() {
    if (!mounted) return;
    setState(() {
      _wordsFuture = context.read<DatabaseService>().getAllWords(widget.wordbook.dbFileName);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text("'${widget.wordbook.name}' 단어 편집")),
      body: FutureBuilder<List<Word>>(
        future: _wordsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('단어장에 단어가 없습니다.'));
          }

          final words = snapshot.data!;
          return ListView.builder(
            itemCount: words.length,
            itemBuilder: (context, index) {
              final word = words[index];
              return ListTile(
                title: Text(word.word),
                subtitle: Text(word.meaning),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(CupertinoIcons.pencil),
                      onPressed: () async {
                        // AddEditWordScreen에서 변경사항이 있었는지 여부를 bool로 받음
                        final bool? resultHasChanged = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder:
                                (_) => AddEditWordScreen(wordbook: widget.wordbook, word: word),
                          ),
                        );
                        // 변경사항이 있었을 경우에만 목록을 새로고침
                        if (resultHasChanged == true) {
                          _loadWords();
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(CupertinoIcons.trash, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(context, word),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final bool? resultHasChanged = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => AddEditWordScreen(wordbook: widget.wordbook)),
          );
          if (resultHasChanged == true) {
            _loadWords();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Word word) {
    final wordbookManager = context.read<WordbookManager>();
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
                onPressed: () async {
                  await wordbookManager.deleteWordFrom(widget.wordbook, word.id!);
                  Navigator.pop(dialogContext);
                  _loadWords(); // 삭제 후 목록 새로고침
                },
              ),
            ],
          ),
    );
  }
}
