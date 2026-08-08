import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../services/test_sheet_service.dart';
import '../services/analytics_service.dart';
import '../services/tts_service.dart';
import '../widgets/glassmorphic_card.dart';

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
  late final TextEditingController _exportTitleController;

  final List<dynamic> _flatQuestionList = [];
  int _totalQuestionCount = 0;
  final List<int> _questionNumberOffsets = [];

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
    _exportTitleController = TextEditingController(
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
    _exportTitleController.dispose();
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
    final testSheetService = context.read<TestSheetService>();
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
                    controller: _exportTitleController,
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
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _handlePdfExport(testSheetService);
                    });
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
        title: _exportTitleController.text,
        exportType: _selectedPdfType,
        share: true,
      );
      if (mounted) {
        context.read<AnalyticsService>().logExportCompleted(
          format: 'pdf',
          source: 'ai_quiz',
        );
      }
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

  Future<void> _handleHtmlExport(TestSheetService service) async {
    setState(() => _isExporting = true);
    try {
      await service.exportAiQuizAsInteractiveHtml(
        questions: widget.quizResponse.questions,
        title: _exportTitleController.text,
        share: true,
      );
      if (mounted) {
        context.read<AnalyticsService>().logExportCompleted(
          format: 'html',
          source: 'ai_quiz',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('HTML 생성 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _showHtmlExportDialog() async {
    final testSheetService = context.read<TestSheetService>();
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('HTML로 내보내기'),
            content: TextField(
              controller: _exportTitleController,
              decoration: const InputDecoration(
                labelText: 'HTML 파일 이름',
                helperText: '확장자는 자동으로 추가됩니다.',
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                FocusScope.of(dialogContext).unfocus();
                Navigator.pop(dialogContext);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _handleHtmlExport(testSheetService);
                });
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.pop(dialogContext);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _handleHtmlExport(testSheetService);
                  });
                },
                child: const Text('내보내기'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('AI 퀴즈'),
        actions: [
          IconButton(
            icon:
                _isExporting
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _isExporting ? null : _showPdfExportDialog,
            tooltip: 'PDF로 내보내기',
          ),
          IconButton(
            icon: const Icon(Icons.language_rounded),
            onPressed: _isExporting ? null : _showHtmlExportDialog,
            tooltip: '인터랙티브 HTML로 내보내기',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          itemCount: widget.quizResponse.questions.length + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return _buildQuizOverview(theme);
            }
            if (index == widget.quizResponse.questions.length + 1) {
              return _buildSubmitAndResultSection(theme, _totalQuestionCount);
            }
            final question = widget.quizResponse.questions[index - 1];
            final questionStartIndex = _questionNumberOffsets[index - 1];
            if (question.type == 'reading_section') {
              return _buildReadingSectionBlock(question, questionStartIndex, theme);
            }
            return _buildQuestionBlock(question, questionStartIndex, theme);
          },
        ),
      ),
    );
  }

  Widget _buildQuizOverview(ThemeData theme) {
    final answeredCount = _userAnswers.length.clamp(0, _totalQuestionCount);
    final progress =
        _totalQuestionCount == 0
            ? 0.0
            : (_isSubmitted ? 1.0 : answeredCount / _totalQuestionCount).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassmorphicCard(
        borderRadius: 28,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildIconBadge(
                  icon: CupertinoIcons.sparkles,
                  color: theme.colorScheme.primary,
                  size: 44,
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isSubmitted ? 'AI 퀴즈 결과' : 'AI 맞춤 퀴즈',
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _isSubmitted ? '정답과 해설을 확인해보세요.' : '단어장을 바탕으로 생성된 문제입니다.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _buildLinearProgress(theme, progress),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoPill(
                  theme: theme,
                  icon: CupertinoIcons.square_list_fill,
                  label: '전체 $_totalQuestionCount문제',
                  color: theme.colorScheme.primary,
                ),
                _buildInfoPill(
                  theme: theme,
                  icon: CupertinoIcons.check_mark_circled_solid,
                  label: _isSubmitted ? '정답 $_score개' : '선택 $answeredCount개',
                  color: _successColor(theme),
                ),
                _buildInfoPill(
                  theme: theme,
                  icon: CupertinoIcons.doc_text_fill,
                  label: _isSubmitted ? '${_scorePercent(_score, _totalQuestionCount)}%' : '해설 포함 가능',
                  color: theme.colorScheme.tertiary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadingSectionBlock(
    AiQuestion readingSection,
    int questionStartIndex,
    ThemeData theme,
  ) {
    final subQuestions = readingSection.questions ?? const <AiReadingSubQuestion>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassmorphicCard(
        borderRadius: 26,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(
              theme: theme,
              icon: CupertinoIcons.book_fill,
              title: '읽기 지문',
              subtitle: '${subQuestions.length}개 문제',
              color: theme.colorScheme.primary,
            ),
            if (readingSection.passage != null) ...[
              const SizedBox(height: 14),
              _buildPassage(readingSection.passage!),
            ],
            ...subQuestions.asMap().entries.map((entry) {
              final localIndex = entry.key;
              final subQuestion = entry.value;
              final globalQuestionIndex = questionStartIndex + localIndex;
              return Padding(
                padding: EdgeInsets.only(top: localIndex == 0 ? 18 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (localIndex > 0) ...[
                      const SizedBox(height: 2),
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.72),
                      ),
                      const SizedBox(height: 20),
                    ],
                    _buildQuestionPrompt(
                      theme: theme,
                      number: globalQuestionIndex + 1,
                      question: subQuestion.question,
                    ),
                    const SizedBox(height: 12),
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
      ),
    );
  }

  Widget _buildQuestionBlock(AiQuestion question, int questionIndex, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GlassmorphicCard(
        borderRadius: 26,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (question.script != null) ...[
              _buildSectionHeader(
                theme: theme,
                icon: CupertinoIcons.speaker_2_fill,
                title: '듣기 문제',
                subtitle: '재생 후 답을 고르세요',
                color: theme.colorScheme.tertiary,
              ),
              const SizedBox(height: 12),
              _buildScript(question.script!),
              const SizedBox(height: 12),
            ],
            _buildQuestionPrompt(
              theme: theme,
              number: questionIndex + 1,
              question: question.question ?? '질문 없음',
            ),
            const SizedBox(height: 12),
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
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        passage,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.88),
          height: 1.55,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildScript(String script) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded),
            onPressed: () => _ttsService.speakDialogue(script),
            color: theme.colorScheme.primary,
            tooltip: '듣기 지문 재생',
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _isSubmitted ? script.replaceAll(RegExp(r'\[.*?\]'), ' ') : '듣기 버튼을 누른 뒤 답을 선택하세요.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color:
                    _isSubmitted
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1.45,
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
    final isSelected = userAnswer == optionText;
    final isCorrectAnswer = optionText == correctAnswer;
    final isWrongSelection = _isSubmitted && isSelected && !isCorrectAnswer;
    final success = _successColor(theme);
    final error = theme.colorScheme.error;

    Color backgroundColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28);
    Color borderColor = theme.colorScheme.outlineVariant;
    Color foregroundColor = theme.colorScheme.onSurface;
    IconData optionIcon = CupertinoIcons.circle;
    Color iconColor = theme.colorScheme.onSurfaceVariant;

    if (_isSubmitted && isCorrectAnswer) {
      backgroundColor = success.withValues(alpha: 0.13);
      borderColor = success.withValues(alpha: 0.48);
      foregroundColor = success;
      optionIcon = CupertinoIcons.check_mark_circled_solid;
      iconColor = success;
    } else if (isWrongSelection) {
      backgroundColor = error.withValues(alpha: 0.10);
      borderColor = error.withValues(alpha: 0.42);
      foregroundColor = error;
      optionIcon = CupertinoIcons.xmark_circle_fill;
      iconColor = error;
    } else if (isSelected) {
      backgroundColor = theme.colorScheme.primary.withValues(alpha: 0.12);
      borderColor = theme.colorScheme.primary.withValues(alpha: 0.52);
      foregroundColor = theme.colorScheme.primary;
      optionIcon = CupertinoIcons.largecircle_fill_circle;
      iconColor = theme.colorScheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap:
                  _isSubmitted
                      ? null
                      : () => setState(() => _userAnswers[questionIndex] = optionText),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: borderColor,
                    width: isSelected || (_isSubmitted && isCorrectAnswer) ? 1.4 : 1.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(optionIcon, color: iconColor, size: 19),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Text(
                        optionText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: foregroundColor,
                          height: 1.42,
                          fontWeight: isSelected || isCorrectAnswer ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isSubmitted &&
              isCorrectAnswer &&
              explanation != null &&
              explanation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.20)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      CupertinoIcons.lightbulb_fill,
                      size: 17,
                      color: theme.colorScheme.tertiary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        explanation,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitAndResultSection(ThemeData theme, int totalQuestions) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child:
          _isSubmitted
              ? _buildResultCard(theme, totalQuestions)
              : GlassmorphicCard(
                borderRadius: 28,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '답을 모두 고른 뒤 결과를 확인하세요.',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '선택하지 않은 문제는 오답으로 처리됩니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _handleSubmit,
                        icon: const Icon(CupertinoIcons.checkmark_alt_circle),
                        label: const Text('결과 확인하기'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildResultCard(ThemeData theme, int totalQuestions) {
    final ratio = totalQuestions == 0 ? 0.0 : (_score / totalQuestions).clamp(0.0, 1.0);
    final percent = _scorePercent(_score, totalQuestions);
    final toneColor =
        ratio >= 0.8
            ? _successColor(theme)
            : ratio >= 0.5
            ? theme.colorScheme.primary
            : theme.colorScheme.error;

    return GlassmorphicCard(
      borderRadius: 30,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 9,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: toneColor,
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        '$percent%',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: toneColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '퀴즈 결과',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _resultMessage(score: _score, total: totalQuestions),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _buildResultMetric(
                  theme: theme,
                  label: '정답',
                  value: '$_score',
                  color: _successColor(theme),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildResultMetric(
                  theme: theme,
                  label: '오답',
                  value: '${(totalQuestions - _score).clamp(0, totalQuestions)}',
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildResultMetric(
                  theme: theme,
                  label: '전체',
                  value: '$totalQuestions',
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(CupertinoIcons.arrow_left_circle),
              label: const Text('AI 학습으로 돌아가기'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Row(
      children: [
        _buildIconBadge(icon: icon, color: color, size: 38),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionPrompt({
    required ThemeData theme,
    required int number,
    required String question,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$number',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            question,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLinearProgress(ThemeData theme, double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _isSubmitted ? '채점 완료' : '풀이 진행률',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoPill({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBadge({
    required IconData icon,
    required Color color,
    required double size,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.36),
      ),
      child: Icon(icon, color: color, size: size * 0.50),
    );
  }

  Widget _buildResultMetric({
    required ThemeData theme,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Color _successColor(ThemeData theme) {
    return theme.brightness == Brightness.dark
        ? const Color(0xFF8FCB91)
        : const Color(0xFF5C8A6E);
  }

  int _scorePercent(int score, int total) {
    if (total <= 0) return 0;
    return ((score / total) * 100).round();
  }

  String _resultMessage({required int score, required int total}) {
    if (total <= 0) return '생성된 문제가 없습니다.';
    final ratio = score / total;
    if (ratio >= 0.9) return '거의 완벽합니다. 헷갈린 해설만 가볍게 확인하세요.';
    if (ratio >= 0.7) return '좋습니다. 틀린 선택지의 이유를 확인하면 기억이 더 단단해집니다.';
    if (ratio >= 0.45) return '아직 익숙해지는 중입니다. 해설을 읽고 플래시카드로 다시 점검해보세요.';
    return '괜찮습니다. 이번 퀴즈는 약한 부분을 찾는 용도입니다.';
  }
}
