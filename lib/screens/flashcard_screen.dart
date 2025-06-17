import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../services/tts_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'quiz_helpers.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  List<QuizItem> _sessionItems = [];
  int _currentIndex = 0;
  bool _isFlipped = false;
  bool _sessionActive = false;
  late final TtsService _ttsService;

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  void _startSession() {
    final allWords = context.read<WordListNotifier>().words;
    final settings = context.read<SettingsNotifier>().settings;
    if (allWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('단어를 먼저 추가해주세요.')));
      }
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
      _currentIndex = 0;
      _isFlipped = false;
      _sessionActive = true;
    });
  }

  void _flipCard() => setState(() => _isFlipped = !_isFlipped);

  void _nextCard() {
    if (_sessionItems.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex + 1) % _sessionItems.length;
        _isFlipped = false;
      });
    }
  }

  void _prevCard() {
    if (_sessionItems.isNotEmpty) {
      setState(() {
        _currentIndex = (_currentIndex - 1 + _sessionItems.length) % _sessionItems.length;
        _isFlipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_sessionActive || _sessionItems.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: GlassmorphicCard(
            onTap: _startSession,
            child: SizedBox(
              width: 200,
              height: 50,
              child: Center(child: Text('플래시카드 시작', style: theme.textTheme.bodyLarge)),
            ),
          ),
        ),
      );
    }

    final quizItem = _sessionItems[_currentIndex];
    final bool isShowingWord =
        (quizItem.questionType == TestType.wordToMeaning && !_isFlipped) ||
        (quizItem.questionType != TestType.wordToMeaning && _isFlipped);

    // 이 변수들은 이제 화면에 표시될 텍스트를 결정하는 데만 사용됩니다.
    final String frontText = getQuestionText(quizItem.word, quizItem.questionType);
    final String backText = getAnswerText(quizItem.word, quizItem.questionType);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${_currentIndex + 1} / ${_sessionItems.length}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GestureDetector(
                onTap: _flipCard,
                child: GlassmorphicCard(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: Center(
                      key: ValueKey(_isFlipped),
                      child: Column(
                        // ▼▼▼ 1. 텍스트 위치 고정 (mainAxisSize: MainAxisSize.min 제거) ▼▼▼
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              _isFlipped ? backText : frontText,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall,
                            ),
                          ),
                          if (isShowingWord) ...[
                            const SizedBox(height: 15),
                            IconButton(
                              icon: const Icon(CupertinoIcons.speaker_2_fill, color: Colors.white),
                              iconSize: 30,
                              // ▼▼▼ 2. 항상 영어 단어를 발음하도록 수정 ▼▼▼
                              onPressed: () => _ttsService.speak(quizItem.word.word),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GlassmorphicCard(
                  onTap: _prevCard,
                  child: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                GlassmorphicCard(
                  onTap: _startSession,
                  child: const Icon(Icons.refresh, color: Colors.white),
                ),
                GlassmorphicCard(
                  onTap: _nextCard,
                  child: const Icon(Icons.arrow_forward, color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
