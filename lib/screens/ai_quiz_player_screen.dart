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

  // ▼▼▼ [추가] PDF 제목과 옵션을 관리할 변수 ▼▼▼
  late final TextEditingController _pdfTitleController;
  PdfExportType _selectedPdfType = PdfExportType.withAnswers;

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    // PDF 제목 컨트롤러 초기화 (오늘 날짜를 포함한 기본값)
    _pdfTitleController = TextEditingController(
      text: 'AI 생성 퀴즈 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _pdfTitleController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  // --- [수정] 오답노트 저장 로직 ---
  void _handleSubmit() async {
    int currentScore = 0;
    final List<Word> incorrectWords = [];
    final wordbookName = context.read<WordbookManager>().activeWordbook?.name ?? 'AI Quiz';

    for (int i = 0; i < widget.quizResponse.questions.length; i++) {
      final question = widget.quizResponse.questions[i];
      if (_userAnswers[i] == question.answer) {
        currentScore++;
      } else {
        incorrectWords.add(
          Word(
            word: question.question,
            meaning: '[정답: ${question.answer}] [내 오답: ${_userAnswers[i] ?? '미입력'}]',
          ),
        );
      }
    }

    if (incorrectWords.isNotEmpty) {
      await context.read<WordbookManager>().addIncorrectWordsToNote(wordbookName, incorrectWords);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('틀린 문제 ${incorrectWords.length}개가 오답노트에 추가되었습니다.')));
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

  // ▼▼▼ [추가] PDF 내보내기 옵션 다이얼로그를 띄우는 함수 ▼▼▼
  Future<void> _showPdfExportDialog() async {
    // 다이얼로그가 닫히기 전까지 _selectedPdfType의 현재 상태를 임시 저장
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
                    // 사용자가 최종 선택한 옵션을 실제 상태에 반영
                    setState(() {
                      _selectedPdfType = tempSelectedType;
                    });
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

  // ▼▼▼ [수정] PDF 내보내기 로직 (다이얼로그의 선택값을 사용) ▼▼▼
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
    final theme = Theme.of(context);
    final totalQuestions = widget.quizResponse.questions.length;

    return Scaffold(
      // ▼▼▼ [수정] AppBar에 PDF 내보내기 버튼 추가 ▼▼▼
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
        itemCount: totalQuestions + 1,
        itemBuilder: (context, index) {
          if (index == totalQuestions) {
            return _buildSubmitAndResultSection(theme, totalQuestions);
          }
          final question = widget.quizResponse.questions[index];
          return _buildQuestionBlock(question, index, theme);
        },
      ),
    );
  }

  // --- UI 빌더 헬퍼 함수들 ---

  // 각 질문 단위를 만드는 함수
  Widget _buildQuestionBlock(AiQuestion question, int index, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
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
          // 독해 지문 또는 듣기 스크립트
          if (question.passage != null) _buildPassage(question.passage!, theme),
          if (question.script != null) _buildScript(question.script!, theme),

          // 질문
          Text(
            '${index + 1}. ${question.question}',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),

          // 선택지 목록
          ...question.options.map((option) {
            return _buildOptionTile(
              optionText: option,
              questionIndex: index,
              correctAnswer: question.answer,
            );
          }),
        ],
      ),
    );
  }

  // 독해 지문 위젯
  Widget _buildPassage(String passage, ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(passage, style: theme.textTheme.bodyMedium),
    );
  }

  // 듣기 스크립트 위젯
  Widget _buildScript(String script, ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: () => _ttsService.speak(script),
            color: theme.primaryColor,
          ),
          Expanded(
            child: Text(
              script,
              style: theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // 각 선택지를 만드는 함수 (HTML 템플릿의 스타일링 로직 반영)
  Widget _buildOptionTile({
    required String optionText,
    required int questionIndex,
    required String correctAnswer,
  }) {
    final theme = Theme.of(context);
    final userAnswer = _userAnswers[questionIndex];

    Color? backgroundColor;
    Color borderColor = theme.dividerColor;
    bool isSelected = (userAnswer == optionText);

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

    return GestureDetector(
      onTap:
          _isSubmitted
              ? null
              : () {
                setState(() {
                  _userAnswers[questionIndex] = optionText;
                });
              },
      child: Container(
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
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? theme.primaryColor : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(optionText, style: theme.textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }

  // 결과 확인 버튼 및 결과 요약 섹션
  Widget _buildSubmitAndResultSection(ThemeData theme, int totalQuestions) {
    return Column(
      children: [
        const SizedBox(height: 16),
        if (!_isSubmitted)
          SizedBox(
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
        if (_isSubmitted)
          Container(
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
                  _score == totalQuestions ? "🎉 완벽해요!" : "👏 수고하셨습니다!",
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // [PDF 저장 기능] PDF 저장/공유 버튼 추가
                    OutlinedButton.icon(
                      icon:
                          _isExporting
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                              : const Icon(Icons.share),
                      label: const Text('결과 공유'),
                      onPressed: _isExporting ? null : _handlePdfExport,
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('돌아가기'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
