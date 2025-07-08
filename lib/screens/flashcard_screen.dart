import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flip_card/flip_card.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

import '../models/word_model.dart';
import '../providers/flashcard_settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/tts_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_dialog.dart';

class FlashcardScreen extends StatefulWidget {
  const FlashcardScreen({super.key});
  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  final CardSwiperController _swiperController = CardSwiperController();
  List<Word> _sessionWords = [];
  bool _sessionActive = false;
  late final TtsService _ttsService;
  String _sessionTitle = '플래시카드';

  @override
  void initState() {
    super.initState();
    _ttsService = TtsService();
  }

  @override
  void dispose() {
    _ttsService.stop();
    _swiperController.dispose();
    super.dispose();
  }

  bool _onSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) {
    // 스와이프 시 로직 (예: 오답노트 기록)을 여기에 추가할 수 있습니다.
    return true;
  }

  void _startSession() {
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

    setState(() {
      _sessionWords = List<Word>.from(allWords)..shuffle();
      _sessionTitle = context.read<WordbookManager>().activeWordbook?.name ?? '플래시카드';
      _sessionActive = true;
    });
  }

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

    setState(() {
      _sessionWords = incorrectWords..shuffle();
      _sessionTitle = '$name (오답노트)';
      _sessionActive = true;
    });
  }

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
    if (!_sessionActive) {
      return _buildSetupScreen();
    } else {
      return _buildFlashcardSession();
    }
  }

  // 학습 시작 전 설정 화면 UI
  Widget _buildSetupScreen() {
    final theme = Theme.of(context);
    final activeWordbook = context.watch<WordbookManager>().activeWordbook;
    final words = context.watch<WordListNotifier>().words;
    final settings = context.watch<FlashcardSettingsProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('플래시카드 학습 설정'), automaticallyImplyLeading: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('1. 학습 단어장 선택', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              // 단어장 선택 UI
              GlassmorphicCard(
                onTap: () async {
                  // ▼▼▼ [수정] wordbook_selection_dialog.dart의 함수를 호출합니다. ▼▼▼
                  final selected = await showWordbookSelectionDialog(context);
                  if (selected != null) {
                    context.read<WordbookManager>().setActiveWordbook(selected);
                  }
                },
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  title: Text(
                    activeWordbook?.name ?? '단어장을 선택해주세요',
                    style: theme.textTheme.bodyLarge,
                  ),
                  subtitle: activeWordbook != null ? Text('${words.length}개의 단어 포함') : null,
                  trailing: const Icon(Icons.change_circle_outlined),
                ),
              ),
              const SizedBox(height: 24),

              Text('2. 카드 앞면 설정', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              // 카드 앞면 설정 UI
              GlassmorphicCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    RadioListTile<FlashcardFrontType>(
                      title: const Text('단어/예문 먼저 보기'),
                      subtitle: const Text('카드를 뒤집으면 뜻이 보입니다.'),
                      value: FlashcardFrontType.word,
                      groupValue: settings.frontType,
                      onChanged: (value) {
                        if (value != null) settings.setFrontType(value);
                      },
                    ),
                    RadioListTile<FlashcardFrontType>(
                      title: const Text('뜻 먼저 보기'),
                      subtitle: const Text('카드를 뒤집으면 단어/예문이 보입니다.'),
                      value: FlashcardFrontType.meaning,
                      groupValue: settings.frontType,
                      onChanged: (value) {
                        if (value != null) settings.setFrontType(value);
                      },
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('플래시카드 학습 시작'),
                  onPressed: activeWordbook == null ? null : _startSession,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('오답노트로 학습하기'),
                  onPressed: _showIncorrectWordbookList,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 실제 학습 세션 UI
  Widget _buildFlashcardSession() {
    final theme = Theme.of(context);
    final settings = context.watch<FlashcardSettingsProvider>();

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
                        padding: const EdgeInsets.all(24.0),
                        cardBuilder: (context, index, percentThresholdX, percentThresholdY) {
                          final word = _sessionWords[index];

                          final frontContent =
                              settings.frontType == FlashcardFrontType.word
                                  ? _buildCardSide(
                                    context: context,
                                    content: word.word,
                                    example: word.exampleSentence,
                                    wordToSpeak: word.word,
                                  )
                                  : _buildCardSide(context: context, content: word.meaning);

                          final backContent =
                              settings.frontType == FlashcardFrontType.word
                                  ? _buildCardSide(context: context, content: word.meaning)
                                  : _buildCardSide(
                                    context: context,
                                    content: word.word,
                                    example: word.exampleSentence,
                                    wordToSpeak: word.word,
                                  );

                          return Card(
                            color: Theme.of(context).colorScheme.surface,
                            elevation: 4.0,
                            shape: theme.cardTheme.shape,
                            clipBehavior: Clip.hardEdge,
                            child: FlipCard(
                              key: ValueKey(word.id),
                              direction: FlipDirection.HORIZONTAL,
                              front: frontContent,
                              back: backContent,
                            ),
                          );
                        },
                      ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _swiperController.undo,
                    icon: Icon(Icons.replay, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    iconSize: 32,
                    tooltip: '되돌리기',
                  ),
                  IconButton(
                    onPressed: () => _swiperController.swipe(CardSwiperDirection.left),
                    icon: Icon(CupertinoIcons.xmark_circle, color: Colors.red.shade300),
                    iconSize: 50,
                    tooltip: '몰라요',
                  ),
                  IconButton(
                    onPressed: () => _swiperController.swipe(CardSwiperDirection.right),
                    icon: Icon(CupertinoIcons.check_mark_circled, color: Colors.green.shade400),
                    iconSize: 50,
                    tooltip: '알아요',
                  ),
                  IconButton(
                    onPressed: () => setState(() => _sessionActive = false),
                    icon: Icon(
                      Icons.exit_to_app,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    iconSize: 32,
                    tooltip: '학습 종료',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 카드 한 면을 그리는 헬퍼 위젯
  Widget _buildCardSide({
    required BuildContext context,
    required String content,
    String? example,
    String? wordToSpeak,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      content,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    if (example != null && example.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: Text(
                          '"$example"',
                          style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (wordToSpeak != null)
            IconButton(
              icon: const Icon(CupertinoIcons.speaker_2_fill),
              iconSize: 30,
              onPressed: () => _ttsService.speak(wordToSpeak),
            ),
        ],
      ),
    );
  }
}
