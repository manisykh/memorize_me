// lib/screens/add_edit_word_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/sentence_completion_matcher.dart';
import '../themes/memorize_identity.dart';

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
  late TextEditingController _exampleTranslationController;
  late TextEditingController _sentenceBlankAnswerController;
  late List<TextEditingController> _additionalMeaningControllers;
  final _wordFocusNode = FocusNode();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _wordController = TextEditingController(text: widget.word?.word ?? '');
    _meaningController = TextEditingController(
      text: widget.word?.meaning ?? '',
    );
    _exampleController = TextEditingController(
      text: widget.word?.exampleSentence ?? '',
    );
    _exampleTranslationController = TextEditingController(
      text: widget.word?.exampleSentenceTranslation ?? '',
    );
    _sentenceBlankAnswerController = TextEditingController(
      text: widget.word?.sentenceBlankAnswer ?? '',
    );
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
    _exampleTranslationController.dispose();
    _sentenceBlankAnswerController.dispose();
    _wordFocusNode.dispose();
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
                        onPressed:
                            () => Navigator.of(
                              dialogContext,
                            ).pop(candidate.index),
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
      final nextPrimary =
          _additionalMeaningControllers[selectedIndex].text.trim();
      _meaningController.text = nextPrimary;
      _additionalMeaningControllers[selectedIndex].text = primary;
    });
  }

  Future<void> _saveWord({bool addAnother = false}) async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      // ▼▼▼ [수정] WordListNotifier 대신 WordbookManager 사용 ▼▼▼
      final manager = context.read<WordbookManager>();

      final primaryMeaning = _meaningController.text.trim();
      final seenMeanings = <String>{primaryMeaning.toLowerCase()};
      final additionalMeanings =
          _additionalMeaningControllers
              .map((controller) => controller.text.trim())
              .where(
                (meaning) =>
                    meaning.isNotEmpty &&
                    seenMeanings.add(meaning.toLowerCase()),
              )
              .toList();
      final newWord = Word(
        id: widget.word?.id,
        word: _wordController.text.trim(),
        meaning: primaryMeaning,
        additionalMeanings: additionalMeanings,
        exampleSentence: _exampleController.text.trim(),
        exampleSentenceTranslation: _exampleTranslationController.text.trim(),
        sentenceBlankAnswer: _sentenceBlankAnswerController.text.trim(),
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
        await manager.addWordToWordbook(widget.wordbook, newWord);
      } else {
        await manager.updateWordsInWordbook(widget.wordbook, [newWord]);
      }

      if (!mounted) return;
      if (addAnother) {
        _wordController.clear();
        _meaningController.clear();
        _exampleController.clear();
        _exampleTranslationController.clear();
        _sentenceBlankAnswerController.clear();
        final oldControllers = _additionalMeaningControllers;
        setState(() => _additionalMeaningControllers = []);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          for (final controller in oldControllers) {
            controller.dispose();
          }
        });
        _wordFocusNode.requestFocus();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장했습니다. 다음 단어를 입력하세요.')));
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('단어를 저장하지 못했습니다: $error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Scaffold(
      backgroundColor: identity.canvas,
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
                    _FormSection(
                      title: '기본 정보',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _wordController,
                            focusNode: _wordFocusNode,
                            autofocus: widget.word == null,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: '단어',
                              suffixIcon:
                                  _wordController.text.isEmpty
                                      ? null
                                      : IconButton(
                                        tooltip: '단어 지우기',
                                        onPressed: () {
                                          _wordController.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(
                                          CupertinoIcons.xmark_circle_fill,
                                        ),
                                      ),
                            ),
                            onChanged: (_) => setState(() {}),
                            validator:
                                (value) =>
                                    value == null || value.trim().isEmpty
                                        ? '단어를 입력해주세요.'
                                        : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _meaningController,
                            decoration: const InputDecoration(
                              labelText: '대표 뜻',
                              helperText: '퀴즈와 시험 출제의 기준이 됩니다.',
                            ),
                            validator:
                                (value) =>
                                    value == null || value.trim().isEmpty
                                        ? '대표 뜻을 입력해주세요.'
                                        : null,
                          ),
                          if (_additionalMeaningControllers.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _changePrimaryMeaning,
                              icon: const Icon(CupertinoIcons.pencil, size: 18),
                              label: const Text('대표 뜻 변경'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: '추가 뜻',
                      trailing: TextButton.icon(
                        onPressed: _addAdditionalMeaning,
                        icon: const Icon(CupertinoIcons.plus_circle, size: 20),
                        label: const Text('추가'),
                      ),
                      child:
                          _additionalMeaningControllers.isEmpty
                              ? Text(
                                '플래시카드, 힌트와 정답 해설에 표시할 뜻을 추가할 수 있어요.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: identity.mutedInk,
                                  height: 1.45,
                                ),
                              )
                              : Column(
                                children:
                                    _additionalMeaningControllers
                                        .asMap()
                                        .entries
                                        .map(
                                          (entry) => Padding(
                                            padding: EdgeInsets.only(
                                              bottom:
                                                  entry.key ==
                                                          _additionalMeaningControllers
                                                                  .length -
                                                              1
                                                      ? 0
                                                      : 10,
                                            ),
                                            child: TextFormField(
                                              controller: entry.value,
                                              decoration: InputDecoration(
                                                labelText:
                                                    '추가 뜻 ${entry.key + 1}',
                                                suffixIcon: IconButton(
                                                  tooltip: '추가 뜻 삭제',
                                                  onPressed:
                                                      () =>
                                                          _removeAdditionalMeaning(
                                                            entry.key,
                                                          ),
                                                  icon: const Icon(
                                                    CupertinoIcons
                                                        .xmark_circle_fill,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                    ),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: '예문',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _exampleController,
                            decoration: const InputDecoration(
                              labelText: '예문 (선택 사항)',
                            ),
                            maxLines: 2,
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _exampleTranslationController,
                            decoration: const InputDecoration(
                              labelText: '예문 해석 (선택 사항)',
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                          Theme(
                            data: theme.copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(bottom: 8),
                              leading: Icon(
                                CupertinoIcons.doc_text,
                                color: identity.mutedInk,
                              ),
                              title: const Text('문장 완성 빈칸 표현 (선택)'),
                              children: [
                                TextFormField(
                                  key: const Key('sentence_blank_answer'),
                                  controller: _sentenceBlankAnswerController,
                                  decoration: const InputDecoration(
                                    labelText: '예문에 나온 표현',
                                    helperText: '자동 인식이 안 될 때만 입력하세요.',
                                  ),
                                  onChanged: (_) => setState(() {}),
                                  validator: (value) {
                                    final answer = value?.trim() ?? '';
                                    if (answer.isEmpty) return null;
                                    if (SentenceCompletionMatcher.findLiteral(
                                          answer,
                                          _exampleController.text,
                                        ) ==
                                        null) {
                                      return '예문에 있는 표현을 입력해주세요.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          Builder(
                            builder: (context) {
                              final sentence = _exampleController.text;
                              final override =
                                  _sentenceBlankAnswerController.text.trim();
                              final match =
                                  override.isNotEmpty
                                      ? SentenceCompletionMatcher.findLiteral(
                                        override,
                                        sentence,
                                      )
                                      : SentenceCompletionMatcher.find(
                                        _wordController.text,
                                        sentence,
                                      );
                              if (match == null) {
                                return const SizedBox.shrink();
                              }
                              final preview = sentence.replaceRange(
                                match.start,
                                match.end,
                                '_________',
                              );
                              return Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: identity.softContext,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '출제 미리보기',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                            color: identity.primaryAction,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      preview,
                                      style: theme.textTheme.bodyMedium
                                          ?.copyWith(color: identity.ink),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: identity.surface,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.word == null) ...[
                      OutlinedButton(
                        onPressed:
                            _saving ? null : () => _saveWord(addAnother: true),
                        child: const Text('저장하고 계속 추가'),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      onPressed: _saving ? null : () => _saveWord(),
                      child: Text(widget.word == null ? '저장 후 목록' : '저장'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _FormSection({required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
