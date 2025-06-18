// screens/flashcard_screen.dart (수정 후)

import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/word_model.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
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
  String _sessionTitle = '플래시카드'; // 세션 제목 (일반/오답노트)

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

  // 일반 단어장으로 세션 시작
  void _startSession() {
    final allWords = context.read<WordListNotifier>().words;
    if (allWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('단어를 먼저 추가해주세요.')));
      }
      return;
    }
    final settings = context.read<SettingsNotifier>().settings;
    final words = List<Word>.from(allWords)..shuffle();
    final wordCount = settings.wordCount.clamp(1, allWords.length);
    _initializeSession(
      words: words.take(wordCount).toList(),
      settings: settings,
      title: context.read<WordbookManager>().activeWordbook?.name ?? '플래시카드',
    );
  }

  // 오답노트로 세션 시작
  Future<void> _startIncorrectWordSession(String name) async {
    final manager = context.read<WordbookManager>();
    final incorrectWords = await manager.getIncorrectWords(name);

    if (incorrectWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('이 오답노트에는 단어가 없습니다.')));
      }
      return;
    }

    final settings = context.read<SettingsNotifier>().settings;
    _initializeSession(words: incorrectWords..shuffle(), settings: settings, title: '$name (오답노트)');
  }

  // 세션 초기화 공통 로직
  void _initializeSession({
    required List<Word> words,
    required AppSettings settings,
    required String title,
  }) {
    setState(() {
      _sessionTitle = title;
      _sessionItems =
          words.map((word) {
            TestType type = settings.testType;
            if (type == TestType.random) {
              type = [TestType.wordToMeaning, TestType.meaningToWord][Random().nextInt(2)];
            }
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

  // 오답노트 목록을 보여주는 모달 메뉴
  void _showIncorrectWordbookList() {
    final manager = context.read<WordbookManager>();
    final names = manager.incorrectWordbookNames;

    if (names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('생성된 오답노트가 없습니다.')));
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
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
                    trailing: IconButton(
                      icon: const Icon(CupertinoIcons.trash),
                      onPressed: () async {
                        await manager.deleteIncorrectWordbook(name);
                        if (mounted) Navigator.pop(ctx);
                      },
                    ),
                    onTap: () {
                      Navigator.pop(ctx);
                      _startIncorrectWordSession(name);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 학습 세션이 활성화되지 않았을 때 (초기 화면)
    if (!_sessionActive) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GlassmorphicCard(
                onTap: _startSession,
                child: const SizedBox(
                  width: 220,
                  height: 50,
                  child: Center(child: Text('플래시카드 학습 시작')),
                ),
              ),
              const SizedBox(height: 20),
              // 오답노트 버튼 추가
              GlassmorphicCard(
                onTap: _showIncorrectWordbookList,
                child: const SizedBox(
                  width: 220,
                  height: 50,
                  child: Center(child: Text('오답노트로 학습하기')),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 학습 세션이 활성화되었을 때 (카드 학습 화면)
    if (_sessionItems.isEmpty) {
      return const Center(child: Text("학습할 단어가 없습니다."));
    }

    final quizItem = _sessionItems[_currentIndex];
    final bool isShowingWord =
        (quizItem.questionType == TestType.wordToMeaning && !_isFlipped) ||
        (quizItem.questionType != TestType.wordToMeaning && _isFlipped);

    final String frontText = getQuestionText(quizItem.word, quizItem.questionType);
    final String backText = getAnswerText(quizItem.word, quizItem.questionType);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_sessionTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _sessionActive = false),
        ),
      ),
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
                              icon: const Icon(CupertinoIcons.speaker_2_fill),
                              iconSize: 30,
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
                GlassmorphicCard(onTap: _prevCard, child: const Icon(Icons.arrow_back)),
                GlassmorphicCard(
                  onTap: () => setState(() => _sessionActive = false),
                  child: const Icon(Icons.stop),
                ),
                GlassmorphicCard(onTap: _nextCard, child: const Icon(Icons.arrow_forward)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
