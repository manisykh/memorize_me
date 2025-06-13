import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../themes/app_theme.dart';
import '../widgets/enhanced_glass_card.dart';
import '../widgets/enhanced_neumorphic_container.dart';
import 'quiz_helpers.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});
  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List<QuizItem> _sessionItems = [];
  int _currentIndex = 0;
  bool _answerShown = false;
  bool _sessionActive = false;

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
            type = TestType.values[random.nextInt(3)];
          }
          return QuizItem(word: word, questionType: type);
        }).toList();

    setState(() {
      _currentIndex = 0;
      _answerShown = false;
      _sessionActive = true;
    });
  }

  void _handleAction() {
    if (_answerShown) {
      _nextQuestion();
    } else {
      setState(() {
        _answerShown = true;
      });
    }
  }

  void _nextQuestion() {
    setState(() {
      _answerShown = false;
    });
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        if (_currentIndex < _sessionItems.length - 1) {
          setState(() {
            _currentIndex++;
          });
        } else {
          showCupertinoDialog(
            context: context,
            builder:
                (context) => CupertinoAlertDialog(
                  title: const Text('퀴즈 종료!'),
                  content: const Text('모든 문제를 다 풀었습니다.'),
                  actions: [
                    CupertinoDialogAction(
                      isDefaultAction: true,
                      child: const Text('확인'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
          );
          setState(() {
            _sessionActive = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_sessionActive || _sessionItems.isEmpty) {
      return Center(
        child: EnhancedNeumorphicContainer(
          onTap: _startSession,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
          child: Text('퀴즈 시작', style: theme.textTheme.titleMedium),
        ),
      );
    }

    final quizItem = _sessionItems[_currentIndex];
    final String questionText = getQuestionText(quizItem.word, quizItem.questionType);
    final String answerText = getAnswerText(quizItem.word, quizItem.questionType);

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    questionText,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 28),
                  ),
                ),
                const Divider(indent: 40, endIndent: 40),
                AnimatedOpacity(
                  opacity: _answerShown ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      answerText,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 24,
                        color: theme.primaryColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          EnhancedNeumorphicContainer(
            onTap: _handleAction,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(_answerShown ? '다음 문제' : '정답 확인', style: theme.textTheme.titleMedium),
            ),
          ),
        ],
      ),
    );
  }
}
