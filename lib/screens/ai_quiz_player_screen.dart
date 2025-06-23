import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../models/word_model.dart';
import '../providers/wordbook_manager.dart';
import '../services/test_sheet_service.dart';
import '../services/tts_service.dart';

class AiQuizPlayerScreen extends StatefulWidget {
  final AiQuizResponse quizResponse;
  const AiQuizPlayerScreen({super.key, required this.quizResponse});

  @override
  State<AiQuizPlayerScreen> createState() => _AiQuizPlayerScreenState();
}

class _AiQuizPlayerScreenState extends State<AiQuizPlayerScreen> {
  final Map<int, String> _userAnswers = {};
  bool _isSubmitted = false;
  int _score = 0;
  final ScrollController _scrollController = ScrollController();
  late final TtsService _ttsService;
  bool _isExporting = false;
  late final TextEditingController _pdfTitleController;
  PdfExportType _selectedPdfType = PdfExportType.withAnswers;

  final List<dynamic> _flatQuestionList = [];
  int _totalQuestionCount = 0;

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _pdfTitleController = TextEditingController(
      text: 'AI 생성 퀴즈 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
    _flattenQuestions();
    debugPrint(
      '[AiQuizPlayerScreen] initState: 퀴즈 화면 시작. 원본 문제 수: ${widget.quizResponse.questions.length}',
    );
    debugPrint('[AiQuizPlayerScreen] initState: 채점용 1차원 리스트 생성 완료. 총 문제 수: $_totalQuestionCount');
  }

  void _flattenQuestions() {
    for (var question in widget.quizResponse.questions) {
      if (question.type == 'reading_section' && question.questions != null) {
        _flatQuestionList.addAll(question.questions!);
      } else {
        _flatQuestionList.add(question);
      }
    }
    _totalQuestionCount = _flatQuestionList.length;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pdfTitleController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  void _handleSubmit() async {
    int currentScore = 0;
    final List<Word> incorrectWords = [];
    final wordbookName = context.read<WordbookManager>().activeWordbook?.name ?? 'AI Quiz 오답노트';

    for (int i = 0; i < _flatQuestionList.length; i++) {
      final questionItem = _flatQuestionList[i];
      final correctAnswer = questionItem.answer;
      final userAnswer = _userAnswers[i];

      if (userAnswer == correctAnswer) {
        currentScore++;
      } else {
        incorrectWords.add(
          Word(
            word: questionItem.question,
            meaning: '[정답: $correctAnswer] [내 오답: ${userAnswer ?? '미입력'}]',
          ),
        );
      }
    }

    // if (incorrectWords.isNotEmpty) {
    //   await context.read<WordbookManager>().addIncorrectWordsToNote(wordbookName, incorrectWords);
    //   if (mounted) {
    //     ScaffoldMessenger.of(
    //       context,
    //     ).showSnackBar(SnackBar(content: Text('틀린 문제 ${incorrectWords.length}개가 오답노트에 추가되었습니다.')));
    //   }
    // }

    setState(() {
      _score = currentScore;
      _isSubmitted = true;
    });

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _showPdfExportDialog() async {
    PdfExportType tempSelectedType = _selectedPdfType;
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('PDF로 내보내기'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _pdfTitleController,
                    decoration: const InputDecoration(labelText: 'PDF 파일 제목'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  RadioListTile<PdfExportType>(
                    title: const Text('문제와 정답'),
                    value: PdfExportType.withAnswers,
                    groupValue: tempSelectedType,
                    onChanged: (value) => setDialogState(() => tempSelectedType = value!),
                  ),
                  RadioListTile<PdfExportType>(
                    title: const Text('문제만'),
                    value: PdfExportType.questionsOnly,
                    groupValue: tempSelectedType,
                    onChanged: (value) => setDialogState(() => tempSelectedType = value!),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                FilledButton(
                  onPressed: () {
                    setState(() => _selectedPdfType = tempSelectedType);
                    Navigator.pop(context);
                    _handlePdfExport();
                  },
                  child: const Text('내보내기'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handlePdfExport() async {
    setState(() => _isExporting = true);
    try {
      await context.read<TestSheetService>().exportAiQuizAsPdf(
        questions: widget.quizResponse.questions,
        title: _pdfTitleController.text,
        exportType: _selectedPdfType,
        share: true,
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF 생성 중 오류 발생: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[AiQuizPlayerScreen] build: build 메서드 실행.');
    final theme = Theme.of(context);
    final groupedQuestions = _groupQuestions();

    List<Widget> allWidgets = [];
    int globalQuestionIndex = 0;

    debugPrint('[AiQuizPlayerScreen] build: 그룹화된 카테고리 수: ${groupedQuestions.length}');

    groupedQuestions.forEach((category, questions) {
      debugPrint('[AiQuizPlayerScreen] build: 카테고리 [$category] 처리 시작. 항목 수: ${questions.length}');
      allWidgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
          child: Text(_getCategoryTitle(category), style: theme.textTheme.headlineSmall),
        ),
      );
      for (var question in questions) {
        if (question.type == 'reading_section') {
          allWidgets.add(_buildReadingSectionBlock(question, globalQuestionIndex, theme));
          globalQuestionIndex += question.questions?.length ?? 0;
        } else {
          allWidgets.add(_buildQuestionBlock(question, globalQuestionIndex, theme));
          globalQuestionIndex++;
        }
      }
    });

    allWidgets.add(_buildSubmitAndResultSection(theme, _totalQuestionCount));
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 생성 퀴즈'),
        actions: [
          IconButton(
            icon:
                _isExporting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                    : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _isExporting ? null : _showPdfExportDialog,
            tooltip: 'PDF로 내보내기',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: allWidgets,
      ),
    );
  }

  Map<String, List<AiQuestion>> _groupQuestions() {
    const categoryOrder = ['vocabulary', 'grammar', 'reading_section', 'listening'];
    final tempMap = <String, List<AiQuestion>>{};
    for (var question in widget.quizResponse.questions) {
      final type = question.type;
      if (tempMap[type] == null) tempMap[type] = [];
      tempMap[type]!.add(question);
    }
    return {
      for (var key in categoryOrder)
        if (tempMap.containsKey(key)) key: tempMap[key]!,
    };
  }

  Widget _buildCategoryBlock(String category, List<AiQuestion> items, ThemeData theme) {
    int questionNumberOffset = 0;
    for (String catKey in _groupQuestions().keys) {
      if (catKey == category) break;
      final prevItems = _groupQuestions()[catKey]!;
      for (var item in prevItems) {
        questionNumberOffset += (item.type == 'reading_section' ? item.questions?.length ?? 0 : 1);
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24.0, bottom: 8.0, left: 8.0),
          child: Text(_getCategoryTitle(category), style: theme.textTheme.headlineSmall),
        ),
        ...items.map((item) {
          if (item.type == 'reading_section') {
            final block = _buildReadingSectionBlock(item, questionNumberOffset, theme);
            questionNumberOffset += item.questions?.length ?? 0;
            return block;
          } else {
            final block = _buildQuestionBlock(item, questionNumberOffset, theme);
            questionNumberOffset++;
            return block;
          }
        }),
      ],
    );
  }

  Widget _buildReadingSectionBlock(
    AiQuestion readingSection,
    int questionStartIndex,
    ThemeData theme,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (readingSection.passage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildPassage(readingSection.passage!, theme),
            ),
          ...readingSection.questions!.asMap().entries.map((entry) {
            int localIndex = entry.key;
            AiReadingSubQuestion subQuestion = entry.value;
            int currentQuestionIndex = questionStartIndex + localIndex;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                localIndex == readingSection.questions!.length - 1 ? 16 : 0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (localIndex > 0) const Divider(height: 32, thickness: 0.5),
                  Text(
                    '${currentQuestionIndex + 1}. ${subQuestion.question}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  ...subQuestion.options.map((option) {
                    return _buildOptionTile(
                      optionText: option,
                      questionIndex: currentQuestionIndex,
                      correctAnswer: subQuestion.answer,
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuestionBlock(AiQuestion question, int questionIndex, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (question.script != null) _buildScript(question.script!, theme),
          Text(
            '${questionIndex + 1}. ${question.question!}',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...question.options!.map((option) {
            return _buildOptionTile(
              optionText: option,
              questionIndex: questionIndex,
              correctAnswer: question.answer!,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPassage(String passage, ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(passage, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
    );
  }

  Widget _buildScript(String script, ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => _ttsService.speakDialogue(script),
            color: theme.primaryColor,
          ),
          if (!_isSubmitted)
            Expanded(
              child: Text(
                script.replaceAll(RegExp(r'[^\[\]A-Z]'), ' '),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          // 제출 후에만 전체 스크립트 표시
          if (_isSubmitted)
            Expanded(
              child: Text(
                script.replaceAll(RegExp(r'\[.*?\]'), ' '),
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required String optionText,
    required int questionIndex,
    required String correctAnswer,
    String? explanation, // 해설을 받을 수 있도록 파라미터 추가
  }) {
    final theme = Theme.of(context);
    final userAnswer = _userAnswers[questionIndex];

    Color? backgroundColor;
    Color borderColor = theme.dividerColor.withOpacity(0.5);
    bool isSelected = (userAnswer == optionText);

    // 1. 상태에 따른 스타일 변경 로직
    if (_isSubmitted) {
      if (optionText == correctAnswer) {
        // 정답 선택지
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green;
      } else if (isSelected) {
        // 사용자가 선택한 오답
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red;
      }
    } else if (isSelected) {
      // 결과 확인 전, 사용자가 선택한 선택지
      backgroundColor = theme.primaryColor.withOpacity(0.1);
      borderColor = theme.primaryColor;
    }

    // 2. UI 위젯 반환
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap:
              _isSubmitted
                  ? null // 제출 후에는 탭 비활성화
                  : () => setState(() => _userAnswers[questionIndex] = optionText), // 사용자 답변 저장
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(
                color: borderColor,
                width: isSelected || (optionText == correctAnswer && _isSubmitted) ? 1.5 : 1.0,
              ),
            ),
            child: Text(optionText, style: theme.textTheme.bodyLarge),
          ),
        ),
        // 3. 해설 표시 로직
        // 제출 후, 정답인 선택지 아래에 해설(explanation)이 있으면 표시
        if (_isSubmitted &&
            optionText == correctAnswer &&
            explanation != null &&
            explanation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 12.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('💡', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    explanation,
                    style: TextStyle(color: Colors.blueGrey.shade700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSubmitAndResultSection(ThemeData theme, int totalQuestions) {
    return Padding(
      padding: const EdgeInsets.only(top: 32.0),
      child:
          _isSubmitted
              ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.primaryColor),
                ),
                child: Column(
                  children: [
                    Text('퀴즈 결과', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text(
                      '$_score / $totalQuestions',
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _score == totalQuestions
                          ? "🎉 완벽해요! 모든 문제를 맞혔습니다!"
                          : _score >= totalQuestions * 0.7
                          ? "👍 아주 잘했어요!"
                          : "👏 다음번엔 더 잘할 수 있을 거예요!",
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('돌아가기'),
                    ),
                  ],
                ),
              )
              : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: theme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('결과 확인하기', style: TextStyle(fontSize: 18)),
                ),
              ),
    );
  }

  String _getCategoryTitle(String categoryKey) {
    switch (categoryKey) {
      case 'vocabulary':
        return 'Vocabulary (어휘)';
      case 'grammar':
        return 'Grammar (문법)';
      case 'reading_section':
        return 'Reading Comprehension (독해)';
      case 'listening':
        return 'Listening Comprehension (리스닝)';
      default:
        return 'Questions';
    }
  }
}
