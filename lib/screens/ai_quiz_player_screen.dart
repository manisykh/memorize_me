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
  // UI 상태 및 데이터 관련 변수
  final Map<int, String> _userAnswers = {};
  bool _isSubmitted = false;
  int _score = 0;
  final ScrollController _scrollController = ScrollController();
  late final TtsService _ttsService;
  final bool _isExporting = false;
  late final TextEditingController _pdfTitleController;
  final PdfExportType _selectedPdfType = PdfExportType.withAnswers;

  // 채점 및 문제 번호 계산을 위한 변수
  final List<dynamic> _flatQuestionList = [];
  int _totalQuestionCount = 0;
  final List<int> _questionNumberOffsets = []; // 각 문제 블록의 시작 번호를 저장

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _pdfTitleController = TextEditingController(
      text: 'AI 생성 퀴즈 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );

    // initState에서 위젯이 빌드되기 전에 필요한 모든 데이터를 계산합니다.
    _prepareQuizData();
  }

  /// 퀴즈에 필요한 데이터(전체 문제 리스트, 총 개수, 문제 번호 오프셋)를 미리 준비합니다.
  void _prepareQuizData() {
    int cumulativeIndex = 0;
    for (final question in widget.quizResponse.questions) {
      // 1. 문제 번호 오프셋 계산 (ListView.builder에서 사용)
      _questionNumberOffsets.add(cumulativeIndex);

      // 2. 채점을 위한 1차원 리스트 생성
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
      if (_userAnswers[i] == questionItem.answer) {
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

  // PDF 내보내기 관련 함수들은 변경 없음 (생략)
  Future<void> _showPdfExportDialog() async {
    /* ... 이전과 동일 ... */
  }
  Future<void> _handlePdfExport() async {
    /* ... 이전과 동일 ... */
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 생성 퀴즈'), actions: [/* ... 이전과 동일 ... */]),
      // ▼▼▼ [개선 3] 안정성을 위해 ListView.builder 구조로 변경 ▼▼▼
      body: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        // 원본 문제 리스트 길이 + 마지막 '결과' 섹션 1개
        itemCount: widget.quizResponse.questions.length + 1,
        itemBuilder: (context, index) {
          // 마지막 아이템은 '결과 확인' 버튼 또는 결과 표시 섹션
          if (index == widget.quizResponse.questions.length) {
            return _buildSubmitAndResultSection(theme, _totalQuestionCount);
          }

          // 각 문제 블록을 그림
          final question = widget.quizResponse.questions[index];
          final questionStartIndex = _questionNumberOffsets[index]; // 미리 계산된 시작 번호

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
              child: _buildPassage(readingSection.passage!, theme),
            ),
          ...readingSection.questions!.asMap().entries.map((entry) {
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
                    '${globalQuestionIndex + 1}. ${subQuestion.question}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  ...subQuestion.options.map(
                    (option) => _buildOptionTile(
                      optionText: option,
                      questionIndex: globalQuestionIndex,
                      correctAnswer: subQuestion.answer,
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
            if (question.script != null) _buildScript(question.script!, theme),
            Text(
              '${questionIndex + 1}. ${question.question!}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ...question.options!.map(
              (option) => _buildOptionTile(
                optionText: option,
                questionIndex: questionIndex,
                correctAnswer: question.answer!,
                explanation: question.explanation,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPassage(String passage, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Text(passage, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
    );
  }

  // ▼▼▼ [개선 2] 요청사항에 맞게 수정된 스크립트 위젯 ▼▼▼
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
          if (_isSubmitted)
            // 제출 후: 전체 스크립트 표시
            Expanded(
              child: Text(
                script.replaceAll(RegExp(r'\[.*?\]'), ' '),
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            // 제출 전: 안내 문구 표시
            Expanded(
              child: Text(
                '지문을 들어보세요.',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
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
        // ▼▼▼ [개선 1] 해설 표시 로직 활성화 ▼▼▼
        if (_isSubmitted &&
            optionText == correctAnswer && // 정답인 선택지에만 표시
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
