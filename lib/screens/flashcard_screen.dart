// lib/screens/flashcard_screen.dart

import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/flashcard_settings_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
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

  late WordbookManager _wordbookManager;
  final SrsService _srsService = SrsService();
  final List<Word> _updatedWordsInSession = [];

  @override
  void initState() {
    super.initState();
    _ttsService = context.read<TtsService>();
    _wordbookManager = context.read<WordbookManager>();

    // 앱의 현재 활성 단어장으로 로컬 상태를 초기화
    final initialWordbook = _wordbookManager.activeWordbook;
    if (initialWordbook != null) {
      _onWordbookSelected(initialWordbook);
    }
  }

  @override
  void dispose() {
    _saveUpdatedSrsData(); // 화면 종료 시 최종 저장
    _swiperController.dispose();
    super.dispose();
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    // 1. 전역 활성 단어장 설정 (다른 화면과의 동기화를 위해)
    await _wordbookManager.setActiveWordbook(wordbook);

    // 2. 현재 화면의 상태 업데이트
    if (mounted) {
      final words = await _wordbookManager.getAllWordsFrom(wordbook);
      setState(() {
        _selectedWordbook = wordbook;
        _sessionWords = words;
      });
    }
  }

  Future<void> _saveUpdatedSrsData() async {
    if (_updatedWordsInSession.isEmpty || _selectedWordbook == null) return;

    await _wordbookManager.updateWordsSrsData(
      _selectedWordbook!.dbFileName,
      _updatedWordsInSession,
    );
    _updatedWordsInSession.clear();
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    if (previousIndex >= _sessionWords.length) return false;

    final word = _sessionWords[previousIndex];
    final difficulty =
        direction == CardSwiperDirection.right ? SrsDifficulty.good : SrsDifficulty.again;

    final updatedWord = _srsService.updateWordSrs(
      word: word,
      source: SrsUpdateSource.flashcard,
      difficulty: difficulty,
    );

    _updatedWordsInSession.removeWhere((w) => w.id == updatedWord.id);
    _updatedWordsInSession.add(updatedWord);

    setState(() => _currentCardIndex = currentIndex ?? 0);
    return true;
  }

  void _startSession({required bool srsOnly}) {
    if (_selectedWordbook == null) {
      _showSnackbar('학습할 단어장을 선택해주세요.');
      return;
    }

    List<Word> wordsForSession;
    if (srsOnly) {
      wordsForSession = _wordbookManager.getWordsForReview();
      if (wordsForSession.isEmpty) {
        _showSnackbar('오늘 복습할 단어가 없습니다!');
        return;
      }
    } else {
      wordsForSession = _sessionWords;
      if (wordsForSession.isEmpty) {
        _showSnackbar('단어장에 학습할 단어가 없습니다.');
        return;
      }
    }

    setState(() {
      _sessionWords = List.from(wordsForSession)..shuffle();
      _sessionActive = true;
      _updatedWordsInSession.clear();
    });
  }

  void _onSessionEnd() {
    _saveUpdatedSrsData().then((_) {
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
                    setState(() => _sessionActive = false);
                  },
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('다시 학습'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    setState(() {
                      _sessionWords.shuffle();
                      _swiperController.moveTo(0);
                      _updatedWordsInSession.clear();
                    });
                  },
                ),
              ],
            ),
      );
    });
  }

  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_sessionActive) {
          await _saveUpdatedSrsData();
        }
        return true;
      },
      child: _sessionActive ? _buildFlashcardSession() : _buildSetupScreen(),
    );
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
              onWordbookSelected: _onWordbookSelected,
              wordCount: _selectedWordbook != null ? _sessionWords.length : 0,
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
              onPressed: () => _startSession(srsOnly: false),
              child: const Text('전체 단어 학습'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondary,
              ),
              onPressed: () => _startSession(srsOnly: true),
              child: const Text('SRS 학습 (오늘의 복습)'),
            ),
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
                        onEnd: _onSessionEnd,
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
