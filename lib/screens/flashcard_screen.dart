// lib/screens/flashcard_screen.dart (세션 종료 문제 해결 코드)

import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:intl/intl.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/flashcard_settings_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/tts_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_button.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final CardSwiperController _swiperController = CardSwiperController();

  Wordbook? _selectedWordbook;
  List<Word> _sessionWords = [];
  int _currentCardIndex = 0;
  bool _sessionActive = false;
  late final TtsService _ttsService;
  List<String> _incorrectWordbookNames = [];

  @override
  void initState() {
    super.initState();
    _ttsService = context.read<TtsService>();

    final manager = context.read<WordbookManager>();
    _incorrectWordbookNames = manager.incorrectWordbookNames;
    if (manager.activeWordbook != null) {
      _loadWordsForWordbook(manager.activeWordbook!);
    }
  }

  @override
  void dispose() {
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _loadWordsForWordbook(Wordbook wordbook, {bool srsOnly = false}) async {
    setState(() {
      _selectedWordbook = wordbook;
      _sessionWords = [];
      _currentCardIndex = 0;
    });

    final manager = context.read<WordbookManager>();
    final words =
        srsOnly ? await manager.getWordsForSrsSession() : await manager.getAllWordsFrom(wordbook);

    if (mounted) {
      setState(() {
        _sessionWords = words;
        if (words.isNotEmpty) _sessionWords.shuffle();
      });
    }
  }

  Future<void> _startSrsSession() async {
    if (_selectedWordbook == null) {
      _showSnackbar('먼저 학습할 단어장을 선택해주세요.');
      return;
    }
    await _loadWordsForWordbook(_selectedWordbook!, srsOnly: true);
    if (!mounted) return;
    if (_sessionWords.isEmpty) {
      _showSnackbar('오늘 복습할 단어가 없습니다!');
      return;
    }
    setState(() => _sessionActive = true);
  }

  void _showIncorrectWordbookList() {
    if (_incorrectWordbookNames.isEmpty) {
      _showSnackbar('생성된 오답노트가 없습니다.');
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
                  ..._incorrectWordbookNames.map((name) {
                    return ListTile(
                      title: Text(name),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final words = await context.read<WordbookManager>().getIncorrectWords(name);
                        if (!mounted) return;
                        if (words.isEmpty) {
                          _showSnackbar('이 오답노트에는 단어가 없습니다.');
                          return;
                        }
                        setState(() {
                          _sessionWords = words..shuffle();
                          _selectedWordbook = null;
                          _sessionActive = true;
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

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    setState(() {
      _currentCardIndex = currentIndex ?? 0;
    });
    if (previousIndex >= _sessionWords.length) return false;

    // ▼▼▼ [수정] 오답노트 학습 시에는 SRS 업데이트를 건너뛰고, 일반 단어장 학습 시에만 업데이트합니다. ▼▼▼
    if (_selectedWordbook != null) {
      final word = _sessionWords[previousIndex];
      final knowsIt = direction == CardSwiperDirection.right;
      context.read<WordbookManager>().updateWordSrsStatus(word, knowsIt, _selectedWordbook!);
    }
    return true;
  }

  void _startSession() {
    if (_selectedWordbook == null) {
      _showSnackbar('학습할 단어장을 선택해주세요.');
      return;
    }
    _loadWordsForWordbook(_selectedWordbook!, srsOnly: false).then((_) {
      if (!mounted) return;
      if (_sessionWords.isNotEmpty) {
        setState(() => _sessionActive = true);
      } else {
        _showSnackbar('단어장에 학습할 단어가 없습니다.');
      }
    });
  }

  // ▼▼▼ [추가] 세션 종료 시 호출될 다이얼로그 함수 ▼▼▼
  void _onSessionEnd() {
    showCupertinoDialog(
      context: context,
      builder:
          (dialogContext) => CupertinoAlertDialog(
            title: const Text('학습 완료!'),
            content: const Text('모든 카드를 학습했습니다.'),
            actions: [
              CupertinoDialogAction(
                child: const Text('종료'),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // 학습 설정 화면으로 돌아가기
                  setState(() => _sessionActive = false);
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('다시 학습'),
                onPressed: () {
                  Navigator.pop(dialogContext);
                  // 현재 단어장과 설정으로 세션 다시 시작
                  if (_selectedWordbook != null) {
                    _loadWordsForWordbook(_selectedWordbook!);
                  }
                },
              ),
            ],
          ),
    );
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _sessionActive ? _buildFlashcardSession() : _buildSetupScreen();
  }

  Widget _buildSetupScreen() {
    final theme = Theme.of(context);
    final settings = context.watch<FlashcardSettingsProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('플래시카드 학습 준비')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            WordbookSelectionButton(
              selectedWordbook: _selectedWordbook,
              onWordbookSelected: (wordbook) => _loadWordsForWordbook(wordbook, srsOnly: false),
              wordCount: _sessionWords.length,
            ),
            const SizedBox(height: 24),
            Text('학습 설정', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            GlassmorphicCard(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  RadioListTile<FlashcardFrontType>(
                    title: const Text('단어 먼저 보기'),
                    value: FlashcardFrontType.word,
                    groupValue: settings.frontType,
                    onChanged: (value) => settings.setFrontType(value!),
                  ),
                  RadioListTile<FlashcardFrontType>(
                    title: const Text('뜻 먼저 보기'),
                    value: FlashcardFrontType.meaning,
                    groupValue: settings.frontType,
                    onChanged: (value) => settings.setFrontType(value!),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _startSession,
              child: const Text('전체 단어 학습'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
              ),
              onPressed: _startSrsSession,
              child: const Text('SRS 학습 (오늘의 복습)'),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: _showIncorrectWordbookList, child: const Text('오답노트로 학습하기')),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashcardSession() {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_selectedWordbook?.name ?? '플래시카드'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => setState(() => _sessionActive = false),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child:
                  _sessionWords.isEmpty
                      ? const Center(child: Text("학습할 단어가 없습니다."))
                      : CardSwiper(
                        controller: _swiperController,
                        cardsCount: _sessionWords.length,
                        onSwipe: _onSwipe,
                        onEnd: _onSessionEnd, // ▼▼▼ [수정] 스와이프가 끝나면 _onSessionEnd 함수를 호출합니다. ▼▼▼
                        padding: const EdgeInsets.all(24.0),
                        allowedSwipeDirection: AllowedSwipeDirection.symmetric(horizontal: true),
                        cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                          final word = _sessionWords[index];
                          final settings = context.read<FlashcardSettingsProvider>();

                          Color overlayColor = Colors.transparent;
                          if (percentThresholdX != 0) {
                            final opacity = min(percentThresholdX.abs() / 100, 0.4);
                            overlayColor =
                                percentThresholdX > 0
                                    ? Colors.blue.withOpacity(opacity)
                                    : Colors.red.withOpacity(opacity);
                          }

                          final frontWidget = Card(
                            color: Theme.of(context).cardColor,
                            elevation: 4.0,
                            shape: Theme.of(context).cardTheme.shape,
                            child: _buildCardSide(
                              word: word,
                              isWordSide: settings.frontType == FlashcardFrontType.word,
                            ),
                          );

                          final backWidget = Card(
                            color: Theme.of(context).cardColor,
                            elevation: 4.0,
                            shape: Theme.of(context).cardTheme.shape,
                            child: _buildCardSide(
                              word: word,
                              isWordSide: settings.frontType != FlashcardFrontType.word,
                            ),
                          );

                          return Stack(
                            children: [
                              FlipCard(
                                key: ValueKey(word.id),
                                front: frontWidget,
                                back: backWidget,
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: overlayColor,
                                      borderRadius:
                                          (theme.cardTheme.shape as RoundedRectangleBorder)
                                              .borderRadius,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                    onPressed: () => _swiperController.swipe(CardSwiperDirection.left),
                    icon: Icon(CupertinoIcons.xmark_circle_fill, color: Colors.red.shade700),
                    iconSize: 60,
                    tooltip: '몰라요',
                  ),
                  IconButton(
                    onPressed: () => _swiperController.undo(),
                    icon: Icon(Icons.replay, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    iconSize: 40,
                    tooltip: '되돌리기',
                  ),
                  IconButton(
                    onPressed: () => _swiperController.swipe(CardSwiperDirection.right),
                    icon: Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      color: Colors.blue.shade700,
                    ),
                    iconSize: 60,
                    tooltip: '알아요',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSide({required Word word, required bool isWordSide}) {
    String mainText = isWordSide ? word.word : word.meaning;
    String? exampleText = isWordSide ? word.exampleSentence : null;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    mainText,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (exampleText != null && exampleText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Text(
                        '"$exampleText"',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (isWordSide)
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0),
            child: IconButton(
              icon: const Icon(CupertinoIcons.speaker_2_fill),
              iconSize: 30,
              onPressed: () => _ttsService.speak(word.word),
            ),
          ),
      ],
    );
  }
}
