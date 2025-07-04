import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/test_sheet_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'quiz_helpers.dart';

enum QuizMode { none, legacy, spelling, incorrectSpelling, exportSheet }

enum SpellingAnswerState { none, correct, incorrect, showAnswer }

class SpellingQuizResult {
  final Word word;
  final bool isCorrectOnFirstTry;
  final bool isCorrectOnRetry;
  final bool isSkipped;

  SpellingQuizResult({
    required this.word,
    this.isCorrectOnFirstTry = false,
    this.isCorrectOnRetry = false,
    this.isSkipped = false,
  });
}

class QuizScreen extends StatefulWidget {
  final QuizMode initialMode;
  const QuizScreen({super.key, this.initialMode = QuizMode.none});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late QuizMode _currentMode;
  List<Word> _incorrectWordsForSession = [];
  String _incorrectWordbookName = '';

  bool _isExporting = false;
  late final TextEditingController _pdfTitleController;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _pdfTitleController = TextEditingController(
      text: '단어 시험지 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
  }

  @override
  void dispose() {
    _pdfTitleController.dispose();
    super.dispose();
  }

  void _changeMode(QuizMode newMode) {
    final allWords = context.read<WordListNotifier>().words;
    if (newMode != QuizMode.none && allWords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('활성화된 단어장에 단어가 없습니다.')));
      return;
    }
    setState(() => _currentMode = newMode);
  }

  void _showIncorrectWordbookListForQuiz() {
    final manager = context.read<WordbookManager>();
    final names = manager.incorrectWordbookNames;
    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('생성된 오답노트가 없습니다.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassmorphicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('오답노트 선택', style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  ...names.map((name) {
                    return ListTile(
                      title: Text(name, style: Theme.of(ctx).textTheme.bodyLarge),
                      onTap: () async {
                        final words = await manager.getIncorrectWords(name);
                        if (mounted) Navigator.pop(ctx);
                        if (words.isEmpty) {
                          if (mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(const SnackBar(content: Text('이 오답노트에는 단어가 없습니다.')));
                          }
                          return;
                        }
                        setState(() {
                          _incorrectWordsForSession = words;
                          _incorrectWordbookName = name;
                          _currentMode = QuizMode.incorrectSpelling;
                        });
                      },
                    );
                  }),
                ],
              ),
            ),
          ),
    );
  }

  Future<void> _showWordTestPdfExportDialog({required bool share}) async {
    _pdfTitleController.text = '단어 시험지 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('시험지 제목 설정'),
          content: TextField(
            controller: _pdfTitleController,
            decoration: const InputDecoration(labelText: 'PDF 파일 제목'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _handleExport(type: 'pdf', share: share, title: _pdfTitleController.text);
              },
              child: const Text('내보내기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleExport({required String type, required bool share, String? title}) async {
    if (!mounted) return;
    setState(() => _isExporting = true);
    final allWords = context.read<WordListNotifier>().words;
    final settings = context.read<SettingsNotifier>().settings;
    final service = context.read<TestSheetService>();
    try {
      if (type == 'pdf') {
        final pdfTitle = title ?? '단어 시험지';
        await service.exportPdf(
          allWords: allWords,
          settings: settings,
          title: pdfTitle,
          share: share,
        );
      } else {
        await service.exportExcel(allWords, settings, share: share);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('작업 중 오류 발생: $e')));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showExportOptions() {
    final allWords = context.read<WordListNotifier>().words;
    if (allWords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('활성화된 단어장에 단어가 없습니다.')));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassmorphicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0, top: 16.0, bottom: 8.0),
                    child: Text('시험지 파일 형식 선택', style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  _buildExportRow('PDF', exportType: 'pdf', ctx: ctx),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildExportRow('Excel', exportType: 'excel', ctx: ctx),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildExportRow(String format, {required String exportType, required BuildContext ctx}) {
    final theme = Theme.of(ctx);
    return ListTile(
      title: Text(format, style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.save_alt),
            onPressed: () {
              Navigator.pop(ctx);
              if (exportType == 'pdf') {
                _showWordTestPdfExportDialog(share: false);
              } else {
                _handleExport(type: exportType, share: false);
              }
            },
            tooltip: '저장',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Navigator.pop(ctx);
              if (exportType == 'pdf') {
                _showWordTestPdfExportDialog(share: true);
              } else {
                _handleExport(type: exportType, share: true);
              }
            },
            tooltip: '공유',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeWordbookName = context.watch<WordbookManager>().activeWordbook?.name;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentMode == QuizMode.exportSheet ? '시험지 생성' : '셀프 테스트'),
        bottom:
            activeWordbookName != null && _currentMode != QuizMode.none
                ? PreferredSize(
                  preferredSize: const Size.fromHeight(20.0),
                  child: Text(activeWordbookName, style: theme.textTheme.bodySmall),
                )
                : null,
        leading:
            _currentMode != QuizMode.none
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _changeMode(QuizMode.none),
                )
                : null,
        automaticallyImplyLeading: _currentMode == QuizMode.none,
      ),
      body: SafeArea(
        child: switch (_currentMode) {
          QuizMode.none => _buildModeSelectionUI(theme),
          QuizMode.exportSheet => _buildExportSheetView(),
          QuizMode.legacy => _LegacyQuizView(onFinish: () => _changeMode(QuizMode.none)),
          // ▼▼▼ [수정] _SpellingQuizView를 클래스 생성자로 호출합니다. ▼▼▼
          QuizMode.spelling => _SpellingQuizView(onFinish: () => _changeMode(QuizMode.none)),
          QuizMode.incorrectSpelling => _SpellingQuizView(
            onFinish: () => _changeMode(QuizMode.none),
            words: _incorrectWordsForSession,
            wordbookName: _incorrectWordbookName,
          ),
        },
      ),
    );
  }

  Widget _buildModeSelectionUI(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        const SizedBox(height: 40),
        Center(
          child: GlassmorphicCard(
            onTap: () => _changeMode(QuizMode.legacy),
            child: SizedBox(
              width: 220,
              height: 50,
              child: Center(child: Text('기존 퀴즈 (단어/뜻)', style: theme.textTheme.bodyLarge)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GlassmorphicCard(
            onTap: () => _changeMode(QuizMode.spelling),
            child: SizedBox(
              width: 220,
              height: 50,
              child: Center(child: Text('스펠링 퀴즈', style: theme.textTheme.bodyLarge)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GlassmorphicCard(
            onTap: _showIncorrectWordbookListForQuiz,
            child: SizedBox(
              width: 220,
              height: 50,
              child: Center(child: Text('오답 스펠링 퀴즈', style: theme.textTheme.bodyLarge)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GlassmorphicCard(
            onTap: !kIsWeb ? () => _changeMode(QuizMode.exportSheet) : null,
            child: SizedBox(
              width: 220,
              height: 50,
              child: Center(
                child: Text(
                  '시험지 생성/내보내기',
                  style:
                      !kIsWeb
                          ? theme.textTheme.bodyLarge
                          : theme.textTheme.bodyLarge?.copyWith(
                            color: Colors.grey,
                            decoration: TextDecoration.lineThrough,
                          ),
                ),
              ),
            ),
          ),
        ),
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(child: Text('웹에서는 지원되지 않는 기능입니다.', style: theme.textTheme.bodySmall)),
          ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildExportSheetView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassmorphicCard(child: _buildLearningSettingsSection(context)),
          const SizedBox(height: 24),
          _isExporting
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                onPressed: _showExportOptions,
                icon: const Icon(Icons.download),
                label: const Text('파일로 내보내기'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildLearningSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final allWords = context.watch<WordListNotifier>().words;
    final settings = settingsNotifier.settings;
    final double minValue = allWords.isEmpty ? 1.0 : 1.0;
    final double maxValue = allWords.isEmpty ? 1.0 : allWords.length.toDouble();
    const testTypeMap = {
      TestType.random: '랜덤',
      TestType.wordToMeaning: '단어 → 뜻',
      TestType.meaningToWord: '뜻 → 단어',
      TestType.meaningToWordWithHint: '뜻 → 단어 (힌트)',
    };
    const exportOptionMap = {
      ExportOption.both: '시험지와 답안지 모두',
      ExportOption.testOnly: '시험지만',
      ExportOption.answersOnly: '답안지만',
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('단어 수', style: theme.textTheme.bodyLarge),
              Row(
                children: [
                  Text(
                    '${settings.wordCount.clamp(minValue.toInt(), maxValue.toInt())}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 150,
                    child: Slider(
                      value: settings.wordCount.toDouble().clamp(minValue, maxValue),
                      min: minValue,
                      max: maxValue,
                      divisions:
                          allWords.isEmpty
                              ? 1
                              : (maxValue > minValue ? (maxValue - minValue).toInt() : 1),
                      onChanged: (value) => settingsNotifier.setWordCount(value.toInt()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: Text('시험 유형', style: theme.textTheme.bodyLarge),
          trailing: Text(testTypeMap[settings.testType]!, style: theme.textTheme.bodyMedium),
          onTap: () => _showTestTypePicker(context),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: Text('내보내기 옵션', style: theme.textTheme.bodyLarge),
          trailing: Text(
            exportOptionMap[settings.exportOption]!,
            style: theme.textTheme.bodyMedium,
          ),
          onTap: () => _showExportOptionPicker(context),
        ),
      ],
    );
  }

  void _showTestTypePicker(BuildContext context) {
    final settingsNotifier = context.read<SettingsNotifier>();
    const testTypeMap = {
      TestType.random: '랜덤',
      TestType.wordToMeaning: '단어 → 뜻',
      TestType.meaningToWord: '뜻 → 단어',
      TestType.meaningToWordWithHint: '뜻 → 단어 (첫 글자 힌트)',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassmorphicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    testTypeMap.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.value, style: Theme.of(ctx).textTheme.bodyLarge),
                        onTap: () {
                          settingsNotifier.setTestType(entry.key);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
              ),
            ),
          ),
    );
  }

  void _showExportOptionPicker(BuildContext context) {
    final settingsNotifier = context.read<SettingsNotifier>();
    const exportOptionMap = {
      ExportOption.both: '시험지와 답안지 모두',
      ExportOption.testOnly: '시험지만',
      ExportOption.answersOnly: '답안지만',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassmorphicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    exportOptionMap.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.value, style: Theme.of(ctx).textTheme.bodyLarge),
                        onTap: () {
                          settingsNotifier.setExportOption(entry.key);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
              ),
            ),
          ),
    );
  }
}

// ▼▼▼ [수정] 아래에 생략되었던 모든 클래스들의 구현을 복원합니다. ▼▼▼

class _LegacyQuizView extends StatefulWidget {
  final VoidCallback onFinish;
  const _LegacyQuizView({required this.onFinish});
  @override
  State<_LegacyQuizView> createState() => _LegacyQuizViewState();
}

class _LegacyQuizViewState extends State<_LegacyQuizView> {
  List<QuizItem> _sessionItems = [];
  int _currentIndex = 0;
  bool _answerShown = false;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  void _startSession() {
    final allWords = context.read<WordListNotifier>().words;
    final settings = context.read<SettingsNotifier>().settings;
    if (allWords.isEmpty) {
      widget.onFinish();
      return;
    }

    final wordCount = settings.wordCount.clamp(1, allWords.length);
    final sourceCopy = List<Word>.from(allWords);
    final random = Random();
    final sessionWords = <Word>[];

    for (int i = 0; i < wordCount; i++) {
      if (sourceCopy.isEmpty) break;
      final randomIndex = random.nextInt(sourceCopy.length);
      sessionWords.add(sourceCopy.removeAt(randomIndex));
    }

    setState(() {
      _sessionItems =
          sessionWords.map((word) {
            TestType type = settings.testType;
            if (type == TestType.random) {
              type = [TestType.wordToMeaning, TestType.meaningToWord][Random().nextInt(2)];
            }
            return QuizItem(word: word, questionType: type);
          }).toList();
    });
  }

  void _handleAction() {
    if (_answerShown) {
      _nextQuestion();
    } else {
      setState(() => _answerShown = true);
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _sessionItems.length - 1) {
      setState(() {
        _currentIndex++;
        _answerShown = false;
      });
    } else {
      _showQuizEndDialog();
    }
  }

  void _showQuizEndDialog() {
    showCupertinoDialog(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: const Text('퀴즈 종료!'),
            content: const Text('모든 문제를 다 풀었습니다.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('확인'),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  widget.onFinish();
                },
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_sessionItems.isEmpty) return const Center(child: CircularProgressIndicator());

    final quizItem = _sessionItems[_currentIndex];
    final String questionText = getQuestionText(quizItem.word, quizItem.questionType);
    final String answerText = getAnswerText(quizItem.word, quizItem.questionType);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '퀴즈 (${_currentIndex + 1}/${_sessionItems.length})',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: GlassmorphicCard(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          questionText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                        Divider(color: theme.textTheme.bodyLarge!.color!.withOpacity(0.2)),
                        AnimatedOpacity(
                          opacity: _answerShown ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _answerShown ? answerText : "",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _handleAction,
              child: Text(_answerShown ? '다음 문제' : '정답 확인'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SpellingQuizView extends StatefulWidget {
  final VoidCallback onFinish;
  final List<Word>? words;
  final String? wordbookName;
  const _SpellingQuizView({required this.onFinish, this.words, this.wordbookName});
  @override
  State<_SpellingQuizView> createState() => _SpellingQuizPageState();
}

class _SpellingQuizPageState extends State<_SpellingQuizView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  late AnimationController _blinkController;
  final List<ScrollController> _scrollControllers = [];

  List<SpellingQuizResult> _results = [];
  List<Word> _sessionWords = [];
  int _currentIndex = 0;
  SpellingAnswerState _answerState = SpellingAnswerState.none;
  bool _isRetryAttempt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _textController.addListener(() {
      setState(() {});
      _autoScrollToCurrentPosition();
    });
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _initializeSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusNode.unfocus();
    _textController.dispose();
    _focusNode.dispose();
    _blinkController.dispose();
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _ensureKeyboardVisible();
      });
    }
  }

  void _ensureKeyboardVisible() {
    if (mounted && _answerState == SpellingAnswerState.none) {
      _focusNode.requestFocus();
    }
  }

  void _autoScrollToCurrentPosition() {
    if (_scrollControllers.isEmpty) return;
    final currentWord = _sessionWords[_currentIndex].word;
    final userInput = _textController.text;
    if (userInput.length >= currentWord.length) return;
    final screenWidth = MediaQuery.of(context).size.width - 80;
    final boxWidth = 34.0;
    final maxBoxesPerLine = (screenWidth / boxWidth).floor();
    List<String> wordParts = currentWord.split(' ');
    int currentInputIndex = 0;
    int targetLineIndex = 0;
    List<String> currentLineWords = [];
    int currentLineLength = 0;
    for (int partIndex = 0; partIndex < wordParts.length; partIndex++) {
      String part = wordParts[partIndex];
      int newLineLength = currentLineLength + part.length + (currentLineWords.isNotEmpty ? 1 : 0);
      if (newLineLength <= maxBoxesPerLine || currentLineWords.isEmpty) {
        currentLineWords.add(part);
        currentLineLength = newLineLength;
      } else {
        if (currentLineWords.isNotEmpty) {
          int lineEndIndex = currentInputIndex + currentLineWords.join(' ').length;
          if (userInput.length <= lineEndIndex) break;
          currentInputIndex = lineEndIndex + 1;
          targetLineIndex++;
        }
        currentLineWords = [part];
        currentLineLength = part.length;
      }
      if (partIndex == wordParts.length - 1) {
        if (currentLineWords.isNotEmpty) {
          int lineEndIndex = currentInputIndex + currentLineWords.join(' ').length;
          if (userInput.length <= lineEndIndex) break;
        }
      }
    }
    if (targetLineIndex < _scrollControllers.length) {
      final scrollController = _scrollControllers[targetLineIndex];
      if (scrollController.hasClients) {
        final targetOffset = (userInput.length - currentInputIndex) * boxWidth;
        final maxScroll = scrollController.position.maxScrollExtent;
        final scrollOffset = (targetOffset - screenWidth / 2).clamp(0.0, maxScroll);
        scrollController.animateTo(
          scrollOffset,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _initializeSession() {
    List<Word> sourceWords;
    if (widget.words != null) {
      sourceWords = List<Word>.from(widget.words!)..shuffle();
      _sessionWords = sourceWords;
    } else {
      final allWords = context.read<WordListNotifier>().words;
      final settings = context.read<SettingsNotifier>().settings;
      if (allWords.isEmpty) {
        widget.onFinish();
        return;
      }
      sourceWords = List<Word>.from(allWords)..shuffle();
      final wordCount = settings.wordCount.clamp(1, allWords.length);
      _sessionWords = sourceWords.take(wordCount).toList();
    }
    _results = _sessionWords.map((word) => SpellingQuizResult(word: word)).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureKeyboardVisible();
    });
  }

  void _checkAnswer() {
    if (_answerState != SpellingAnswerState.none) return;

    final userInput = _textController.text.trim().toLowerCase();
    final correctAnswer = _sessionWords[_currentIndex].word.toLowerCase();
    setState(() {
      if (userInput == correctAnswer) {
        _answerState = SpellingAnswerState.correct;
        if (_isRetryAttempt) {
          _results[_currentIndex] = SpellingQuizResult(
            word: _sessionWords[_currentIndex],
            isCorrectOnRetry: true,
          );
        } else {
          _results[_currentIndex] = SpellingQuizResult(
            word: _sessionWords[_currentIndex],
            isCorrectOnFirstTry: true,
          );
        }
      } else {
        _answerState = SpellingAnswerState.incorrect;
      }
    });
  }

  void _showCorrectAnswer() {
    final correctAnswer = _sessionWords[_currentIndex].word;
    setState(() {
      _answerState = SpellingAnswerState.showAnswer;
      _results[_currentIndex] = SpellingQuizResult(
        word: _sessionWords[_currentIndex],
        isSkipped: true,
      );
      _textController.text = correctAnswer;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < _sessionWords.length - 1) {
      setState(() {
        _currentIndex++;
        _answerState = SpellingAnswerState.none;
        _isRetryAttempt = false;
        _textController.clear();
      });
      _ensureKeyboardVisible();
    } else {
      _showResults();
    }
  }

  void _skipQuestion() {
    setState(() {
      _results[_currentIndex] = SpellingQuizResult(
        word: _sessionWords[_currentIndex],
        isSkipped: true,
      );
    });
    _nextQuestion();
  }

  void _retryQuestion() {
    setState(() {
      _answerState = SpellingAnswerState.none;
      _isRetryAttempt = true;
      _textController.clear();
    });
    _ensureKeyboardVisible();
  }

  void _showResults() {
    final originalWordbookName =
        widget.wordbookName ?? context.read<WordbookManager>().activeWordbook?.name;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _SpellingQuizResultScreen(
              results: _results,
              originalWordbookName: originalWordbookName,
              onRestart: () {
                Navigator.of(context).pop();
                setState(() {
                  _currentIndex = 0;
                  _answerState = SpellingAnswerState.none;
                  _isRetryAttempt = false;
                  _textController.clear();
                });
                _initializeSession();
              },
              onFinish: () {
                Navigator.of(context).pop();
                widget.onFinish();
              },
            ),
      ),
    );
  }

  Widget _buildAnswerBoxes() {
    final theme = Theme.of(context);
    final currentWord = _sessionWords[_currentIndex].word;
    final userInput = _textController.text;
    final screenWidth = MediaQuery.of(context).size.width - 80;
    final boxWidth = 34.0;
    final maxBoxesPerLine = (screenWidth / boxWidth).floor();
    List<String> wordParts = currentWord.split(' ');
    List<Widget> rows = [];
    int currentInputIndex = 0;
    List<String> currentLineWords = [];
    int currentLineLength = 0;
    for (int partIndex = 0; partIndex < wordParts.length; partIndex++) {
      String part = wordParts[partIndex];
      int newLineLength = currentLineLength + part.length + (currentLineWords.isNotEmpty ? 1 : 0);
      if (newLineLength <= maxBoxesPerLine || currentLineWords.isEmpty) {
        currentLineWords.add(part);
        currentLineLength = newLineLength;
      } else {
        if (currentLineWords.isNotEmpty) {
          rows.add(
            _buildLineBoxes(currentLineWords, currentInputIndex, userInput, theme, rows.length),
          );
          currentInputIndex += currentLineWords.join(' ').length;
          if (partIndex > 0) currentInputIndex++;
        }
        currentLineWords = [part];
        currentLineLength = part.length;
      }
      if (partIndex == wordParts.length - 1) {
        rows.add(
          _buildLineBoxes(currentLineWords, currentInputIndex, userInput, theme, rows.length),
        );
      }
    }
    return Column(
      children:
          rows
              .map((row) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: row))
              .toList(),
    );
  }

  Widget _buildLineBoxes(
    List<String> words,
    int startInputIndex,
    String userInput,
    ThemeData theme,
    int lineIndex,
  ) {
    while (_scrollControllers.length <= lineIndex) {
      _scrollControllers.add(ScrollController());
    }
    List<Widget> boxes = [];
    int currentInputIndex = startInputIndex;
    for (int wordIndex = 0; wordIndex < words.length; wordIndex++) {
      String word = words[wordIndex];
      for (int i = 0; i < word.length; i++) {
        String char = '';
        Color textColor = theme.textTheme.bodyLarge!.color!;
        bool shouldBlink = false;
        if (currentInputIndex < userInput.length) {
          char = userInput[currentInputIndex];
          if (_answerState == SpellingAnswerState.correct) {
            textColor = Colors.blue;
          } else if (_answerState == SpellingAnswerState.incorrect) {
            textColor = Colors.red;
          } else if (_answerState == SpellingAnswerState.showAnswer) {
            textColor = Colors.red;
          }
        } else if (currentInputIndex == userInput.length &&
            _answerState == SpellingAnswerState.none) {
          shouldBlink = true;
        }
        boxes.add(
          Container(
            width: 30,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color:
                      shouldBlink
                          ? Colors.transparent
                          : theme.textTheme.bodyLarge!.color!.withOpacity(0.4),
                  width: 2,
                ),
              ),
            ),
            child: Stack(
              children: [
                if (shouldBlink)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: FadeTransition(
                      opacity: _blinkController,
                      child: Container(height: 2, color: theme.primaryColor),
                    ),
                  ),
                Center(
                  child: Text(
                    char,
                    style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        currentInputIndex++;
      }
      if (wordIndex < words.length - 1) {
        boxes.add(
          Container(
            width: 20,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: const Center(child: Text(' ', style: TextStyle(fontSize: 18))),
          ),
        );
        currentInputIndex++;
      }
    }
    return Scrollbar(
      controller: _scrollControllers[lineIndex],
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _scrollControllers[lineIndex],
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: boxes),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (_answerState == SpellingAnswerState.none) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _textController.text.isNotEmpty ? _checkAnswer : null,
          child: const Text('정답 확인'),
        ),
      );
    } else if (_answerState == SpellingAnswerState.correct) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _nextQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: Text(_currentIndex < _sessionWords.length - 1 ? '다음 문제' : '결과 보기'),
        ),
      );
    } else if (_answerState == SpellingAnswerState.incorrect) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _retryQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('재도전'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _showCorrectAnswer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('정답 보기'),
              ),
            ),
          ),
        ],
      );
    } else {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _nextQuestion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
          ),
          child: Text(_currentIndex < _sessionWords.length - 1 ? '다음 문제' : '결과 보기'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_sessionWords.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final currentWord = _sessionWords[_currentIndex];
    final title = widget.wordbookName != null ? '${widget.wordbookName} (오답)' : '스펠링 퀴즈';
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(title),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: widget.onFinish),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              '퀴즈 (${_currentIndex + 1}/${_sessionWords.length})',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Text(
              currentWord.meaning,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                autofocus: false,
                enableSuggestions: false,
                autocorrect: false,
                onSubmitted: (_) {
                  _checkAnswer();
                },
              ),
            ),
            GestureDetector(onTap: _ensureKeyboardVisible, child: _buildAnswerBoxes()),
            const SizedBox(height: 40),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }
}

class _SpellingQuizResultScreen extends StatelessWidget {
  final List<SpellingQuizResult> results;
  final String? originalWordbookName;
  final VoidCallback onRestart;
  final VoidCallback onFinish;

  const _SpellingQuizResultScreen({
    super.key,
    required this.results,
    this.originalWordbookName,
    required this.onRestart,
    required this.onFinish,
  });

  Future<void> _saveIncorrectWords(BuildContext context) async {
    final incorrectWords =
        results
            .where((r) => !r.isCorrectOnFirstTry && !r.isCorrectOnRetry && !r.isSkipped)
            .map((r) => r.word)
            .toList();
    if (incorrectWords.isEmpty || originalWordbookName == null) return;

    await context.read<WordbookManager>().addIncorrectWordsToNote(
      originalWordbookName!,
      incorrectWords,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalQuestions = results.length;
    final firstTryCorrect = results.where((r) => r.isCorrectOnFirstTry).length;
    final retryCorrect = results.where((r) => r.isCorrectOnRetry).length;
    final skipped = results.where((r) => r.isSkipped).length;
    final incorrect = totalQuestions - firstTryCorrect - retryCorrect - skipped;
    final accuracyRate =
        totalQuestions > 0 ? ((firstTryCorrect + retryCorrect) / totalQuestions * 100).round() : 0;

    // initState 대신 build 메서드에서 호출
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (originalWordbookName != null) {
        _saveIncorrectWords(context);
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('퀴즈 결과'), backgroundColor: Colors.transparent, elevation: 0),
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassmorphicCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '통계',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    _buildStatRow('전체 문제', '$totalQuestions개', theme),
                    _buildStatRow('한번에 맞춘 문제', '$firstTryCorrect개', theme),
                    _buildStatRow('재도전하여 맞춘 문제', '$retryCorrect개', theme),
                    _buildStatRow('틀린 문제', '$incorrect개', theme),
                    _buildStatRow('스킵', '$skipped개', theme),
                    Divider(color: theme.textTheme.bodyLarge?.color?.withOpacity(0.2)),
                    _buildStatRow('정답율', '$accuracyRate%', theme, isHighlight: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            GlassmorphicCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '결과',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    ...results.map((result) => _buildResultItem(result, theme)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRestart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('다시 시작'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('완료'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, ThemeData theme, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isHighlight ? theme.primaryColor : theme.textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(SpellingQuizResult result, ThemeData theme) {
    Color statusColor;
    String statusText;
    IconData statusIcon;
    if (result.isCorrectOnFirstTry) {
      statusColor = Colors.green;
      statusText = '한번에 정답';
      statusIcon = Icons.check_circle;
    } else if (result.isCorrectOnRetry) {
      statusColor = Colors.orange;
      statusText = '재도전 성공';
      statusIcon = Icons.refresh;
    } else {
      statusColor = Colors.red;
      statusText = '틀림/스킵';
      statusIcon = Icons.cancel;
    }
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.word.word,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(result.word.meaning, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
          Text(
            statusText,
            style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
