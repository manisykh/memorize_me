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

// 현재 어떤 퀴즈 모드인지 나타내는 상태
enum QuizMode { none, legacy, spelling }

// 스펠링 퀴즈 답변 상태
enum SpellingAnswerState { none, correct, incorrect, showAnswer }

// 스펠링 퀴즈 결과 클래스
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

// 퀴즈 탭의 메인 화면. 어떤 퀴즈를 보여줄지 상태를 관리합니다.
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
    // 현재 모드가 spelling이고 PageView가 활성화된 상태에서만 실행
    if (_currentMode == QuizMode.spelling && _pageController.hasClients) {
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
          onSwitchMode: () => _switchPage(1),
          onFinish: () => _changeMode(QuizMode.none),
        ),
        QuizMode.spelling => PageView(
          controller: _pageController,
          children: [
            _SpellingQuizView(
              onSwitchMode: () => _switchPage(1),
              onFinish: () => _changeMode(QuizMode.none),
            ),
            _LegacyQuizView(
              onSwitchMode: () => _switchPage(0),
              onFinish: () => _changeMode(QuizMode.none),
            ),
          ],
        ),
      },
    );
  }
}

// --- 기존 퀴즈 UI ---
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
            if (type == TestType.random)
              type = [TestType.wordToMeaning, TestType.meaningToWord][Random().nextInt(2)];
            return QuizItem(word: word, questionType: type);
          }).toList();
    });
  }

  void _handleAction() {
    if (_answerShown)
      _nextQuestion();
    else
      setState(() => _answerShown = true);
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
                  const Divider(color: Colors.white30),
                  AnimatedOpacity(
                    opacity: _answerShown ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _answerShown ? answerText : "",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [const Shadow(blurRadius: 2, color: Colors.black54)],
                      ),
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

// --- 스펠링 퀴즈 UI ---
class _SpellingQuizView extends StatefulWidget {
  final VoidCallback onSwitchMode;
  final VoidCallback onFinish;
  const _SpellingQuizView({super.key, required this.onSwitchMode, required this.onFinish});
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
      _autoScrollToCurrentPosition(); // 추가
    });

    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _initializeSession();

    // 키보드를 항상 올려놓기 위한 추가 설정
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureKeyboardVisible();
    });
  }

  void _ensureKeyboardVisible() {
    if (mounted) {
      _focusNode.requestFocus();
      // 약간의 지연 후 다시 포커스 요청 (키보드가 확실히 올라오도록)
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

    // 현재 입력 위치가 어느 줄에 있는지 찾기
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

    // 해당 줄의 ScrollController로 스크롤
    if (targetLineIndex < _scrollControllers.length) {
      final scrollController = _scrollControllers[targetLineIndex];
      if (scrollController.hasClients) {
        // 현재 입력 위치의 대략적인 x 좌표 계산
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
    final screenWidth = MediaQuery.of(context).size.width - 80; // 좌우 패딩 40씩
    final boxWidth = 34.0; // 박스 너비 (30 + 마진 4)
    final maxBoxesPerLine = (screenWidth / boxWidth).floor();

    List<String> wordParts = currentWord.split(' ');
    List<Widget> rows = [];

    int currentInputIndex = 0;
    List<String> currentLineWords = [];
    int currentLineLength = 0;

    for (int partIndex = 0; partIndex < wordParts.length; partIndex++) {
      String part = wordParts[partIndex];

      // 현재 줄에 이 단어를 추가할 수 있는지 확인
      int newLineLength =
          currentLineLength + part.length + (currentLineWords.isNotEmpty ? 1 : 0); // 공백 포함

      if (newLineLength <= maxBoxesPerLine || currentLineWords.isEmpty) {
        // 현재 줄에 추가 가능
        currentLineWords.add(part);
        currentLineLength = newLineLength;
      } else {
        // 새 줄 시작 - 현재 줄 먼저 처리
        if (currentLineWords.isNotEmpty) {
          rows.add(
            _buildLineBoxes(currentLineWords, currentInputIndex, userInput, theme, rows.length),
          );
          currentInputIndex += currentLineWords.join(' ').length;
          if (partIndex > 0) currentInputIndex++; // 이전 공백
        }

        // 새 줄 시작
        currentLineWords = [part];
        currentLineLength = part.length;
      }

      // 마지막 단어인 경우
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

      // 단어의 각 글자에 대한 박스 생성
      for (int i = 0; i < word.length; i++) {
        String char = '';
        Color textColor = Colors.white;
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
                  color: shouldBlink ? Colors.transparent : Colors.white54,
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

      // 마지막 단어가 아니면 공백 추가
      if (wordIndex < words.length - 1) {
        boxes.add(
          Container(
            width: 20,
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            child: const Center(child: Text(' ', style: TextStyle(fontSize: 18))),
          ),
        );
        currentInputIndex++; // 공백을 위한 인덱스 증가
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
    final theme = Theme.of(context);

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
      // showAnswer 상태
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
            // 숨겨진 실제 입력 필드
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
            // 보여지는 답변 상자들
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

// 스펠링 퀴즈 결과 화면
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
    final incorrect = totalQuestions - firstTryCorrect - retryCorrect;
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
            // 통계 섹션
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
                    _buildStatRow('전체 문제', '$totalQuestions개'),
                    _buildStatRow('한번에 맞춘 문제', '$firstTryCorrect개'),
                    _buildStatRow('재도전하여 맞춘 문제', '$retryCorrect개'),
                    _buildStatRow('틀린 문제 (스킵)', '$skipped개'),
                    _buildStatRow('틀린 문제 (스킵)', '$incorrect개'),
                    const Divider(color: Colors.white30),
                    _buildStatRow('정답율', '$accuracyRate%', isHighlight: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // 결과 섹션
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
            // 액션 버튼들
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

  Widget _buildStatRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? Colors.blue : Colors.white,
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
        color: Colors.white.withOpacity(0.1),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  result.word.meaning,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
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
