import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../providers/word_list_provider.dart';

class AddEditWordScreen extends StatefulWidget {
  final Word? word;
  const AddEditWordScreen({super.key, this.word});
  @override
  State<AddEditWordScreen> createState() => _AddEditWordScreenState();
}

class _AddEditWordScreenState extends State<AddEditWordScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _wordController;
  late TextEditingController _meaningController;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.word?.word ?? '');
    _meaningController = TextEditingController(text: widget.word?.meaning ?? '');
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    super.dispose();
  }

  void _saveWord() {
    if (_formKey.currentState!.validate()) {
      final notifier = context.read<WordListNotifier>();
      final newWord = Word(
        id: widget.word?.id,
        word: _wordController.text,
        meaning: _meaningController.text,
      );
      if (widget.word == null) {
        notifier.addWord(newWord);
      } else {
        notifier.updateWord(newWord);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
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
                validator: (value) => (value == null || value.isEmpty) ? '단어를 입력하세요' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _meaningController,
                decoration: const InputDecoration(labelText: '뜻'),
                validator: (value) => (value == null || value.isEmpty) ? '뜻을 입력하세요' : null,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveWord,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('저장', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
