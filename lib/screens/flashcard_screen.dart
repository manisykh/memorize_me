import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flip_card/flip_card.dart';

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
  final GlobalKey<FlipCardState> _cardKey = GlobalKey<FlipCardState>();

  final List<QuizItem> _sessionItems = [];
  final int _currentIndex = 0;
  bool _sessionActive = false;
  late final TtsService _ttsService;
  final String _sessionTitle = '플래시카드';

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

  // ▼▼▼ [삭제] 단어장 변경 로직(_changeWordbook)을 삭제했습니다. ▼▼▼

  void _startSession() {
    // ▼▼▼ [수정] 전역 Provider에서 단어 목록을 가져오도록 복원합니다. ▼▼▼
    final wordListNotifier = context.read<WordListNotifier>();
    final allWords = wordListNotifier.words;

    if (allWords.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('활성화된 단어장에 단어가 없습니다.')));
      }
      return;
    }
    final settings = context.read<SettingsNotifier>().settings;
    final wordCount = settings.wordCount.clamp(1, allWords.length);

    // 성능 개선을 위해 수정한 효율적인 무작위 추출 로직은 유지합니다.
    final sourceCopy = List<Word>.from(allWords);
    final random = Random();
    final sessionWords = <Word>[];

    for (int i = 0; i < wordCount; i++) {
      if (sourceCopy.isEmpty) break;
      final randomIndex = random.nextInt(sourceCopy.length);
      sessionWords.add(sourceCopy.removeAt(randomIndex));
    }

    _initializeSession(
      words: sessionWords,
      settings: settings,
      title: wordListNotifier.activeWordbook?.name ?? '플래시카드',
    );
  }

  // --- 나머지 함수들은 기존과 동일 ---
  void _nextCard() {
    /*...*/
  }
  void _prevCard() {
    /*...*/
  }
  Future<void> _startIncorrectWordSession(String name) async {
    /*...*/
  }
  void _initializeSession({
    required List<Word> words,
    required AppSettings settings,
    required String title,
  }) {
    /*...*/
  }
  void _showIncorrectWordbookList() {
    /*...*/
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeWordbookName = context.watch<WordbookManager>().activeWordbook?.name;

    if (!_sessionActive) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('플래시카드'),
          automaticallyImplyLeading: true,
          // ▼▼▼ [삭제] actions에 있던 단어장 변경 버튼을 삭제했습니다. ▼▼▼
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (activeWordbookName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: Text('현재 단어장: $activeWordbookName', style: theme.textTheme.titleMedium),
                  ),
                GlassmorphicCard(
                  onTap: _startSession,
                  child: const SizedBox(
                    width: 220,
                    height: 50,
                    child: Center(child: Text('플래시카드 학습 시작')),
                  ),
                ),
                const SizedBox(height: 20),
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
        ),
      );
    }

    // 세션 진행 중 UI
    if (_sessionItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_sessionTitle)),
        body: const Center(child: Text("학습할 단어가 없습니다.")),
      );
    }

    final quizItem = _sessionItems[_currentIndex];
    final String frontText = getQuestionText(quizItem.word, quizItem.questionType);
    final String backText = getAnswerText(quizItem.word, quizItem.questionType);

    return Scaffold(
      appBar: AppBar(
        title: Text(_sessionTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _sessionActive = false),
        ),
      ),

      body: SafeArea(
        child: Padding(
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
                child: FlipCard(
                  key: _cardKey,
                  flipOnTouch: true,
                  direction: FlipDirection.HORIZONTAL,
                  front: GlassmorphicCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          frontText,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                    ),
                  ),
                  back: GlassmorphicCard(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              backText,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 15),
                            IconButton(
                              icon: const Icon(CupertinoIcons.speaker_2_fill),
                              iconSize: 30,
                              onPressed: () => _ttsService.speak(quizItem.word.word),
                            ),
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
                    padding: const EdgeInsets.all(20),
                    child: const Icon(Icons.arrow_back, size: 30),
                  ),
                  GlassmorphicCard(
                    onTap: () => setState(() => _sessionActive = false),
                    padding: const EdgeInsets.all(20),
                    child: const Icon(Icons.stop, size: 30),
                  ),
                  GlassmorphicCard(
                    onTap: _nextCard,
                    padding: const EdgeInsets.all(20),
                    child: const Icon(Icons.arrow_forward, size: 30),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
