// screens/quiz_screen.dart (최종 수정)

import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../providers/quiz_session_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../widgets/glassmorphic_card.dart';
import 'quiz_helpers.dart';
import 'quiz_result_screen.dart';

enum QuizMode { none, legacy, spelling }

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
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  QuizMode _currentMode = QuizMode.none;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _changeMode(QuizMode newMode) {
    if (newMode == QuizMode.none) {
      setState(() => _currentMode = newMode);
      return;
    }

    final allWords = context.read<WordListNotifier>().words;
    if (allWords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('퀴즈를 시작하려면 단어를 먼저 추가해주세요.')));
      return;
    }
    setState(() {
      _currentMode = newMode;
    });
  }

  void _switchPage(int page) {
    FocusScope.of(context).unfocus();

    // PageView의 스크롤을 막았으므로, 이 로직은 항상 PageView가 활성화된 상태에서만 호출됩니다.
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: switch (_currentMode) {
        QuizMode.none => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassmorphicCard(
                onTap: () => _changeMode(QuizMode.legacy),
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: Center(child: Text('기존 퀴즈 (단어/뜻)', style: theme.textTheme.bodyLarge)),
                ),
              ),
              const SizedBox(height: 30),
              GlassmorphicCard(
                onTap: () => _changeMode(QuizMode.spelling),
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: Center(child: Text('스펠링 퀴즈', style: theme.textTheme.bodyLarge)),
                ),
              ),
            ],
          ),
        ),
        QuizMode.legacy => _LegacyQuizView(
          onSwitchMode: () => _changeMode(QuizMode.spelling), // 스펠링 퀴즈로 전환
          onFinish: () => _changeMode(QuizMode.none),
        ),
        QuizMode.spelling => PageView(
          // ▼▼▼ 이 한 줄을 추가하여 스와이프 기능을 비활성화합니다. ▼▼▼
          physics: const NeverScrollableScrollPhysics(),
          // ▲▲▲
          controller: _pageController,
          children: [
            _SpellingQuizView(
              onSwitchMode: () => _switchPage(1), // 기존 퀴즈 페이지로 이동
              onFinish: () => _changeMode(QuizMode.none),
            ),
            _LegacyQuizView(
              onSwitchMode: () => _switchPage(0), // 스펠링 퀴즈 페이지로 이동
              onFinish: () => _changeMode(QuizMode.none),
            ),
          ],
        ),
      },
    );
  }
}

class _LegacyQuizView extends StatefulWidget {
  final VoidCallback onSwitchMode;
  final VoidCallback onFinish;
  const _LegacyQuizView({required this.onSwitchMode, required this.onFinish});
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
    final words = List<Word>.from(allWords)..shuffle();
    final wordCount = settings.wordCount.clamp(1, allWords.length);
    setState(() {
      _sessionItems =
          words.take(wordCount).map((word) {
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
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_sessionItems.isEmpty) return const Center(child: CircularProgressIndicator());

    final quizItem = _sessionItems[_currentIndex];
    final String questionText = getQuestionText(quizItem.word, quizItem.questionType);
    final String answerText = getAnswerText(quizItem.word, quizItem.questionType);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
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
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _handleAction,
              child: Text(_answerShown ? '다음 문제' : '정답 확인'),
            ),
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: widget.onSwitchMode,
            icon: const Icon(Icons.change_circle_outlined, size: 16),
            label: const Text("스펠링 퀴즈로 전환"),
          ),
        ],
      ),
    );
  }
}

class _SpellingQuizView extends StatefulWidget {
  final VoidCallback onSwitchMode;
  final VoidCallback onFinish;
  const _SpellingQuizView({required this.onSwitchMode, required this.onFinish});
  @override
  State<_SpellingQuizView> createState() => _SpellingQuizPageState();
}

class _SpellingQuizPageState extends State<_SpellingQuizView> with SingleTickerProviderStateMixin {
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
    _textController.addListener(() {
      setState(() {});
      _autoScrollToCurrentPosition();
    });

    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _initializeSession();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureKeyboardVisible();
    });
  }

  void _ensureKeyboardVisible() {
    if (mounted) {
      _focusNode.requestFocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
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
          if (userInput.length <= lineEndIndex) {
            break;
          }
          currentInputIndex = lineEndIndex + 1;
          targetLineIndex++;
        }
        currentLineWords = [part];
        currentLineLength = part.length;
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
    final allWords = context.read<WordListNotifier>().words;
    final settings = context.read<SettingsNotifier>().settings;

    if (allWords.isEmpty) {
      widget.onFinish();
      return;
    }

    final words = List<Word>.from(allWords)..shuffle();
    final wordCount = settings.wordCount.clamp(1, allWords.length);
    _sessionWords = words.take(wordCount).toList();
    _results = _sessionWords.map((word) => SpellingQuizResult(word: word)).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureKeyboardVisible();
    });
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _textController.dispose();
    _focusNode.dispose();
    _blinkController.dispose();
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _checkAnswer() {
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _SpellingQuizResultScreen(
              results: _results,
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
                child: const Text('정답 확인'),
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

    return GestureDetector(
      onTap: () => _ensureKeyboardVisible(),
      child: SingleChildScrollView(
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
            SizedBox(
              height: 0,
              width: 0,
              child: TextField(
                controller: _textController,
                focusNode: _focusNode,
                autofocus: true,
                enableSuggestions: false,
                autocorrect: false,
                enabled: _answerState == SpellingAnswerState.none,
                onSubmitted: (_) {
                  if (_textController.text.isNotEmpty) {
                    _checkAnswer();
                  }
                },
              ),
            ),
            _buildAnswerBoxes(),
            const SizedBox(height: 40),
            _buildActionButtons(),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: widget.onSwitchMode,
              icon: const Icon(Icons.change_circle_outlined, size: 16),
              label: const Text("기존 퀴즈로 전환"),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpellingQuizResultScreen extends StatelessWidget {
  final List<SpellingQuizResult> results;
  final VoidCallback onRestart;
  final VoidCallback onFinish;

  const _SpellingQuizResultScreen({
    required this.results,
    required this.onRestart,
    required this.onFinish,
  });

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
        color: theme.textTheme.bodyLarge!.color!.withOpacity(0.05),
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
