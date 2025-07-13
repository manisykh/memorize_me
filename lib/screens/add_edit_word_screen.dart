// lib/screens/add_edit_word_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/database_service.dart';

class AddEditWordScreen extends StatefulWidget {
  final Wordbook wordbook; // ▼▼▼ [수정] 단어장 정보를 받기 위한 파라미터
  final Word? word;

  const AddEditWordScreen({super.key, required this.wordbook, this.word});

  @override
  State<AddEditWordScreen> createState() => _AddEditWordScreenState();
}

class _AddEditWordScreenState extends State<AddEditWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _wordController;
  late TextEditingController _meaningController;
  late TextEditingController _exampleController;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.word?.word ?? '');
    _meaningController = TextEditingController(text: widget.word?.meaning ?? '');
    _exampleController = TextEditingController(text: widget.word?.exampleSentence ?? '');
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    _exampleController.dispose();
    super.dispose();
  }

  Future<void> _saveWord() async {
    if (_formKey.currentState!.validate()) {
      // ▼▼▼ [수정] WordListNotifier 대신 WordbookManager 사용 ▼▼▼
      final manager = context.read<WordbookManager>();

      final newWord = Word(
        id: widget.word?.id,
        word: _wordController.text,
        meaning: _meaningController.text,
        exampleSentence: _exampleController.text,
        // 기존 단어의 SRS 정보는 유지
        srsLevel: widget.word?.srsLevel ?? 0,
        nextReviewDate: widget.word?.nextReviewDate,
        correctStreak: widget.word?.correctStreak ?? 0,
        incorrectCount: widget.word?.incorrectCount ?? 0,
      );

      if (widget.word == null) {
        // DB에 직접 추가 (Manager에 추가 메서드를 만들어도 됨)
        await context.read<DatabaseService>().addWord(widget.wordbook.dbFileName, newWord);
      } else {
        await manager.updateWordsInWordbook(widget.wordbook, [newWord]);
      }

      // 변경사항이 있었음을 이전 화면에 알림
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(widget.word == null ? '새 단어 추가' : '단어 수정')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _wordController,
                decoration: const InputDecoration(labelText: '단어'),
                validator: (value) => value!.isEmpty ? '단어를 입력해주세요.' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _meaningController,
                decoration: const InputDecoration(labelText: '뜻'),
                validator: (value) => value!.isEmpty ? '뜻을 입력해주세요.' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _exampleController,
                decoration: const InputDecoration(labelText: '예문 (선택 사항)'),
                maxLines: 3,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(onPressed: _saveWord, child: const Text('저장')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
