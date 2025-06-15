import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../services/tts_service.dart'; // TTS 서비스 import
import '../themes/app_theme.dart';
import '../widgets/enhanced_glass_card.dart';
import '../widgets/enhanced_neumorphic_container.dart';
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
    final sessionWords = words.take(wordCount).toList();

    final random = Random();
    _sessionItems =
        sessionWords.map((word) {
          TestType type = settings.testType;
          if (type == TestType.random) {
            // 플래시카드에서는 '단어 -> 뜻' 또는 '뜻 -> 단어'만 사용
            type = [TestType.wordToMeaning, TestType.meaningToWord][random.nextInt(2)];
          }
          return QuizItem(word: word, questionType: type);
        }).toList();

    setState(() {
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
      return Center(
        child: EnhancedNeumorphicContainer(
          onTap: _startSession,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Text('플래시카드 시작', style: theme.textTheme.titleMedium),
        ),
      );
    }

    final quizItem = _sessionItems[_currentIndex];

    // 현재 카드에 영단어가 표시되는지 여부를 결정하는 로직
    final bool isShowingWord =
        (quizItem.questionType == TestType.wordToMeaning && !_isFlipped) ||
        (quizItem.questionType == TestType.meaningToWord && _isFlipped);

    final String currentWord = quizItem.word.word;
    final String frontText = getQuestionText(quizItem.word, quizItem.questionType);
    final String backText = getAnswerText(quizItem.word, quizItem.questionType);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${_currentIndex + 1} / ${_sessionItems.length}',
            style: TextStyle(
              color:
                  theme.brightness == Brightness.light
                      ? AppTheme.subTextLight
                      : AppTheme.subTextDark,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 20),
          EnhancedGlassCard(
            onTap: _flipCard,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              transitionBuilder: (child, animation) {
                final rotateAnim = Tween(begin: pi, end: 0.0).animate(animation);
                return AnimatedBuilder(
                  animation: rotateAnim,
                  child: child,
                  builder: (context, child) {
                    final isUnder = (ValueKey(_isFlipped) != child?.key);
                    var tilt = ((animation.value - 0.5).abs() - 0.5) * 0.003;
                    tilt *= isUnder ? -1.0 : 1.0;
                    final value = min(rotateAnim.value, pi / 2);
                    return Transform(
                      transform: Matrix4.rotationY(value)..setEntry(3, 0, tilt),
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                key: ValueKey(_isFlipped),
                children: [
                  Text(
                    _isFlipped ? backText : frontText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 28),
                  ),
                  if (isShowingWord) ...[
                    const SizedBox(height: 15),
                    IconButton(
                      icon: const Icon(CupertinoIcons.speaker_2_fill),
                      iconSize: 30,
                      color: theme.colorScheme.secondary,
                      onPressed: () => _ttsService.speak(currentWord),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              EnhancedNeumorphicContainer(
                onTap: _prevCard,
                shape: BoxShape.circle,
                padding: const EdgeInsets.all(16),
                child: const Icon(CupertinoIcons.arrow_left),
              ),
              EnhancedNeumorphicContainer(
                onTap: _startSession,
                shape: BoxShape.circle,
                padding: const EdgeInsets.all(16),
                child: const Icon(CupertinoIcons.arrow_2_circlepath),
              ),
              EnhancedNeumorphicContainer(
                onTap: _nextCard,
                shape: BoxShape.circle,
                padding: const EdgeInsets.all(16),
                child: const Icon(CupertinoIcons.arrow_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
