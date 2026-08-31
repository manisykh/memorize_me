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
  late List<TextEditingController> _additionalMeaningControllers;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.word?.word ?? '');
    _meaningController = TextEditingController(text: widget.word?.meaning ?? '');
    _exampleController = TextEditingController(text: widget.word?.exampleSentence ?? '');
    _additionalMeaningControllers =
        (widget.word?.additionalMeanings ?? const [])
            .map((meaning) => TextEditingController(text: meaning))
            .toList();
  }

  @override
  void dispose() {
    _wordController.dispose();
    _meaningController.dispose();
    _exampleController.dispose();
    for (final controller in _additionalMeaningControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addAdditionalMeaning() {
    setState(() => _additionalMeaningControllers.add(TextEditingController()));
  }

  void _removeAdditionalMeaning(int index) {
    final controller = _additionalMeaningControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  Future<void> _changePrimaryMeaning() async {
    final primary = _meaningController.text.trim();
    final candidates = <({int index, String value})>[];
    for (var index = 0; index < _additionalMeaningControllers.length; index++) {
      final value = _additionalMeaningControllers[index].text.trim();
      if (value.isNotEmpty) candidates.add((index: index, value: value));
    }
    if (candidates.isEmpty) return;

    final selectedIndex = await showDialog<int>(
      context: context,
      builder:
          (dialogContext) => SimpleDialog(
            title: const Text('새 대표 뜻 선택'),
            children:
                candidates
                    .map(
                      (candidate) => SimpleDialogOption(
                        onPressed: () => Navigator.of(dialogContext).pop(candidate.index),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(candidate.value),
                        ),
                      ),
                    )
                    .toList(),
          ),
    );
    if (selectedIndex == null || !mounted) return;

    setState(() {
      final nextPrimary = _additionalMeaningControllers[selectedIndex].text.trim();
      _meaningController.text = nextPrimary;
      _additionalMeaningControllers[selectedIndex].text = primary;
    });
  }

  Future<void> _saveWord() async {
    if (_formKey.currentState!.validate()) {
      // ▼▼▼ [수정] WordListNotifier 대신 WordbookManager 사용 ▼▼▼
      final manager = context.read<WordbookManager>();

      final primaryMeaning = _meaningController.text.trim();
      final seenMeanings = <String>{primaryMeaning.toLowerCase()};
      final additionalMeanings =
          _additionalMeaningControllers
              .map((controller) => controller.text.trim())
              .where((meaning) => meaning.isNotEmpty && seenMeanings.add(meaning.toLowerCase()))
              .toList();
      final newWord = Word(
        id: widget.word?.id,
        word: _wordController.text.trim(),
        meaning: primaryMeaning,
        additionalMeanings: additionalMeanings,
        exampleSentence: _exampleController.text.trim(),
        exampleSentenceTranslation: widget.word?.exampleSentenceTranslation,
        // 기존 단어의 SRS 정보는 유지
        srsLevel: widget.word?.srsLevel ?? 0,
        nextReviewDate: widget.word?.nextReviewDate,
        lastReviewedAt: widget.word?.lastReviewedAt,
        correctStreak: widget.word?.correctStreak ?? 0,
        incorrectCount: widget.word?.incorrectCount ?? 0,
        pendingMcqReview: widget.word?.pendingMcqReview ?? 0,
        pendingSpellingReview: widget.word?.pendingSpellingReview ?? 0,
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
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    TextFormField(
                      controller: _wordController,
                      decoration: const InputDecoration(labelText: '단어'),
                      validator:
                          (value) => value == null || value.trim().isEmpty ? '단어를 입력해주세요.' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _meaningController,
                      decoration: const InputDecoration(
                        labelText: '대표 뜻',
                        helperText: '퀴즈와 시험 출제의 기준이 됩니다.',
                      ),
                      validator:
                          (value) => value == null || value.trim().isEmpty ? '대표 뜻을 입력해주세요.' : null,
                    ),
                    if (_additionalMeaningControllers.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _changePrimaryMeaning,
                          icon: const Icon(Icons.swap_vert, size: 18),
                          label: const Text('대표 뜻 변경'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '추가 뜻',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _addAdditionalMeaning,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('추가'),
                        ),
                      ],
                    ),
                    if (_additionalMeaningControllers.isEmpty)
                      Text(
                        '추가 뜻은 플래시카드, 힌트와 정답 해설에 표시됩니다.',
                        style: Theme.of(context).textTheme.bodySmall,
                      )
                    else
                      ..._additionalMeaningControllers.asMap().entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: TextFormField(
                            controller: entry.value,
                            decoration: InputDecoration(
                              labelText: '추가 뜻 ${entry.key + 1}',
                              suffixIcon: IconButton(
                                tooltip: '추가 뜻 삭제',
                                onPressed: () => _removeAdditionalMeaning(entry.key),
                                icon: const Icon(Icons.close),
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _exampleController,
                      decoration: const InputDecoration(labelText: '예문 (선택 사항)'),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(onPressed: _saveWord, child: const Text('저장')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
