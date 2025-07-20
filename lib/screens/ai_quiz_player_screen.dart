import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
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
  PdfExportType _selectedPdfType = PdfExportType.withAnswers;
  late final TextEditingController _pdfTitleController;

  final List<dynamic> _flatQuestionList = [];
  int _totalQuestionCount = 0;
  final List<int> _questionNumberOffsets = [];

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _pdfTitleController = TextEditingController(
      text: 'AI 생성 퀴즈 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
    _prepareQuizData();
  }

  void _prepareQuizData() {
    int cumulativeIndex = 0;
    for (final question in widget.quizResponse.questions) {
      _questionNumberOffsets.add(cumulativeIndex);
      if (question.type == 'reading_section' && question.questions != null) {
        _flatQuestionList.addAll(question.questions!);
        cumulativeIndex += question.questions!.length;
      } else {
        _flatQuestionList.add(question);
        cumulativeIndex++;
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

  void _handleSubmit() {
    int currentScore = 0;
    for (int i = 0; i < _flatQuestionList.length; i++) {
      final questionItem = _flatQuestionList[i];
      final correctAnswer = questionItem.answer ?? '';
      final userAnswer = _userAnswers[i] ?? '';

      if (userAnswer.isNotEmpty && userAnswer == correctAnswer) {
        currentScore++;
      }
    }
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
                    _handlePdfExport(context.read<TestSheetService>());
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

  Future<void> _handlePdfExport(TestSheetService service) async {
    setState(() => _isExporting = true);
    try {
      await service.exportAiQuizAsPdf(
        questions: widget.quizResponse.questions,
        title: _pdfTitleController.text,
        exportType: _selectedPdfType,
        share: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF 생성 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        itemCount: widget.quizResponse.questions.length + 1,
        itemBuilder: (context, index) {
          if (index == widget.quizResponse.questions.length) {
            return _buildSubmitAndResultSection(theme, _totalQuestionCount);
          }
          final question = widget.quizResponse.questions[index];
          final questionStartIndex = _questionNumberOffsets[index];
          if (question.type == 'reading_section') {
            return _buildReadingSectionBlock(question, questionStartIndex, theme);
          } else {
            return _buildQuestionBlock(question, questionStartIndex, theme);
          }
        },
      ),
    );
  }

  Widget _buildReadingSectionBlock(
    AiQuestion readingSection,
    int questionStartIndex,
    ThemeData theme,
  ) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (readingSection.passage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _buildPassage(readingSection.passage!),
            ),
          ...?readingSection.questions?.asMap().entries.map((entry) {
            final localIndex = entry.key;
            final subQuestion = entry.value;
            final globalQuestionIndex = questionStartIndex + localIndex;
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
                    '${globalQuestionIndex + 1}. ${subQuestion.question ?? '질문 없음'}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  ...subQuestion.options.map(
                    (option) => _buildOptionTile(
                      optionText: option,
                      questionIndex: globalQuestionIndex,
                      correctAnswer: subQuestion.answer ?? '',
                      explanation: subQuestion.explanation,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildQuestionBlock(AiQuestion question, int questionIndex, ThemeData theme) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (question.script != null) _buildScript(question.script!),
            Text(
              '${questionIndex + 1}. ${question.question ?? '질문 없음'}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...?(question.options?.map(
              (option) => _buildOptionTile(
                optionText: option,
                questionIndex: questionIndex,
                correctAnswer: question.answer ?? '',
                explanation: question.explanation,
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPassage(String passage) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Text(passage, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
    );
  }

  // ▼▼▼ [수정] 이 메서드만 수정하면 됩니다. ▼▼▼
  Widget _buildScript(String script) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => _ttsService.speakDialogue(script),
            color: Theme.of(context).primaryColor,
            tooltip: '듣기 지문 재생',
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              // 정답 제출 후(_isSubmitted == true)에만 스크립트 표시
              _isSubmitted ? script.replaceAll(RegExp(r'\[.*?\]'), ' ') : '버튼을 눌러 듣기 지문을 재생하세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _isSubmitted ? null : Theme.of(context).hintColor,
              ),
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
    String? explanation,
  }) {
    final theme = Theme.of(context);
    final userAnswer = _userAnswers[questionIndex];
    Color? backgroundColor;
    Color borderColor = theme.dividerColor.withOpacity(0.5);
    bool isSelected = (userAnswer == optionText);
    if (_isSubmitted) {
      if (optionText == correctAnswer) {
        backgroundColor = Colors.green.shade50;
        borderColor = Colors.green;
      } else if (isSelected) {
        backgroundColor = Colors.red.shade50;
        borderColor = Colors.red;
      }
    } else if (isSelected) {
      backgroundColor = theme.primaryColor.withOpacity(0.1);
      borderColor = theme.primaryColor;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap:
              _isSubmitted ? null : () => setState(() => _userAnswers[questionIndex] = optionText),
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
        if (_isSubmitted &&
            optionText == correctAnswer &&
            explanation != null &&
            explanation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 12.0, bottom: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡', style: TextStyle(fontSize: 16)),
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
}
