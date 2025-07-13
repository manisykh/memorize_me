// lib/screens/quiz_screen.dart

import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../services/test_sheet_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_button.dart';
import 'quiz_helpers.dart';
import '../services/mode_state_service.dart';
import 'package:file_picker/file_picker.dart';

enum QuizMode { none, legacy, spelling, reviewSpelling, exportSheet }

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
  final QuizMode initialMode;
  const QuizScreen({super.key, this.initialMode = QuizMode.none});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Wordbook? _selectedWordbook;
  List<Word> _words = [];
  List<Word> _reviewWords = [];
  bool _isLoading = false;
  bool _isScreenLoading = true;

  late QuizMode _currentMode;
  late final TextEditingController _pdfTitleController;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    _pdfTitleController = TextEditingController(
      text: '단어 시험지 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();

    final lastUsedId = await modeStateService.getLastUsedWordbookId(LearningMode.quiz);
    Wordbook? initialWordbook = wordbookManager.getWordbookById(lastUsedId ?? -1);
    initialWordbook ??= wordbookManager.activeWordbook;
    initialWordbook ??= wordbookManager.wordbooks.firstOrNull;

    if (initialWordbook != null) {
      await _onWordbookSelected(initialWordbook);
    }

    if (mounted) {
      setState(() {
        _isScreenLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pdfTitleController.dispose();
    super.dispose();
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    setState(() => _isLoading = true);

    final wordbookManager = context.read<WordbookManager>();
    await wordbookManager.setActiveWordbook(wordbook);

    if (mounted) {
      final wordListNotifier = context.read<WordListNotifier>();
      setState(() {
        _selectedWordbook = wordbook;
        _words = wordListNotifier.words;
        _reviewWords = wordbookManager.getWordsForReview();
        _isLoading = false;
      });
    }

    final modeStateService = context.read<ModeStateService>();
    await modeStateService.setLastUsedWordbookId(LearningMode.quiz, wordbook.id!);
  }

  void _changeMode(QuizMode newMode) {
    if (_selectedWordbook == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 학습할 단어장을 선택해주세요.')));
      return;
    }
    if (newMode != QuizMode.none && newMode != QuizMode.exportSheet && _words.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택된 단어장에 단어가 없습니다.')));
      return;
    }
    setState(() => _currentMode = newMode);
  }

  // 시험지 내보내기 관련 함수들... (이전과 동일)
  Future<void> _showWordTestPdfExportDialog({required bool share}) async {
    _pdfTitleController.text =
        '${_selectedWordbook?.name ?? "단어"} 시험지 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('시험지 제목 설정'),
          content: TextField(
            controller: _pdfTitleController,
            decoration: const InputDecoration(labelText: 'PDF 파일 제목'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _handleExport(type: 'pdf', share: share, title: _pdfTitleController.text);
              },
              child: const Text('내보내기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleExport({required String type, required bool share, String? title}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final settings = context.read<SettingsNotifier>().settings;
      final service = context.read<TestSheetService>();
      String? savePath;

      // 저장하기 옵션일 경우, 사용자에게 폴더 선택을 요청
      if (!share) {
        savePath = await FilePicker.platform.getDirectoryPath();
        if (savePath == null) {
          // 사용자가 폴더 선택을 취소한 경우
          setState(() => _isLoading = false);
          return;
        }
      }

      // 서비스 호출
      if (type == 'pdf') {
        final pdfTitle = title ?? '단어 시험지';
        await service.exportPdf(
          allWords: _words,
          settings: settings,
          title: pdfTitle,
          share: share,
          savePath: savePath, // 선택된 저장 경로 전달
        );
      } else {
        await service.exportExcel(
          _words,
          settings,
          share: share,
          savePath: savePath, // 선택된 저장 경로 전달
        );
      }

      if (!share && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('파일이 성공적으로 저장되었습니다.\n경로: $savePath')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('작업 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showExportOptions() {
    if (_words.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('활성화된 단어장에 단어가 없습니다.')));
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
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text('시험지 파일 형식 선택', style: Theme.of(ctx).textTheme.titleLarge),
                  ),
                  _buildExportRow('PDF', exportType: 'pdf', ctx: ctx),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _buildExportRow('Excel', exportType: 'excel', ctx: ctx),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildExportRow(String format, {required String exportType, required BuildContext ctx}) {
    final theme = Theme.of(ctx);
    return ListTile(
      title: Text(format, style: theme.textTheme.bodyLarge),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.save_alt, color: theme.textTheme.bodyLarge?.color),
            onPressed: () {
              Navigator.pop(ctx);
              if (exportType == 'pdf') {
                _showWordTestPdfExportDialog(share: false);
              } else {
                _handleExport(type: exportType, share: false);
              }
            },
            tooltip: '저장',
          ),
          IconButton(
            icon: Icon(Icons.share, color: theme.textTheme.bodyLarge?.color),
            onPressed: () {
              Navigator.pop(ctx);
              if (exportType == 'pdf') {
                _showWordTestPdfExportDialog(share: true);
              } else {
                _handleExport(type: exportType, share: true);
              }
            },
            tooltip: '공유',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isScreenLoading) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);

    if (_selectedWordbook != null) {
      _reviewWords = context.watch<WordbookManager>().getWordsForReview();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        leading:
            _currentMode != QuizMode.none
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _changeMode(QuizMode.none),
                )
                : null,
        automaticallyImplyLeading: _currentMode == QuizMode.none,
      ),
      body: SafeArea(
        child: switch (_currentMode) {
          QuizMode.none => _buildModeSelectionUI(theme),
          QuizMode.exportSheet => _buildExportSheetView(),
          QuizMode.legacy => _LegacyQuizView(
            words: _words,
            onFinish: () => _changeMode(QuizMode.none),
          ),
          QuizMode.spelling =>
            _selectedWordbook == null
                ? const Center(child: Text("단어장을 먼저 선택해주세요."))
                : _SpellingQuizView(
                  key: ValueKey('spelling_${_selectedWordbook!.id}'),
                  words: _words,
                  selectedWordbook: _selectedWordbook!,
                  onFinish: () => _changeMode(QuizMode.none),
                ),
          QuizMode.reviewSpelling =>
            _selectedWordbook == null
                ? const Center(child: Text("단어장을 먼저 선택해주세요."))
                : _SpellingQuizView(
                  key: ValueKey('review_${_selectedWordbook!.id}'),
                  words: _reviewWords,
                  selectedWordbook: _selectedWordbook!,
                  onFinish: () => _changeMode(QuizMode.none),
                ),
        },
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_currentMode) {
      case QuizMode.none:
        return '셀프 테스트';
      case QuizMode.exportSheet:
        return '시험지 생성';
      case QuizMode.legacy:
        return '기존 퀴즈 - ${_selectedWordbook?.name}';
      case QuizMode.spelling:
        return '스펠링 퀴즈 - ${_selectedWordbook?.name}';
      case QuizMode.reviewSpelling:
        return '오답/복습 퀴즈 - ${_selectedWordbook?.name}';
      default:
        return '셀프 테스트';
    }
  }

  Widget _buildModeSelectionUI(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      children: [
        const SizedBox(height: 16),
        WordbookSelectionButton(
          selectedWordbook: _selectedWordbook,
          onWordbookSelected: _onWordbookSelected,
          wordCount: _words.length,
        ),
        const SizedBox(height: 32),
        _buildModeCard('기존 퀴즈 (단어/뜻)', () => _changeMode(QuizMode.legacy), theme),
        const SizedBox(height: 20),
        _buildModeCard('전체 스펠링 퀴즈', () => _changeMode(QuizMode.spelling), theme),
        const SizedBox(height: 20),

        Opacity(
          opacity: _reviewWords.isNotEmpty && _selectedWordbook != null ? 1.0 : 0.5,
          child: _buildModeCard(
            '오답/복습 퀴즈 (${_reviewWords.length}개)',
            _reviewWords.isNotEmpty && _selectedWordbook != null
                ? () => _changeMode(QuizMode.reviewSpelling)
                : null,
            theme,
          ),
        ),

        const SizedBox(height: 20),
        _buildModeCard(
          '시험지 생성/내보내기',
          kIsWeb ? null : () => _changeMode(QuizMode.exportSheet),
          theme,
          isWebDisabled: kIsWeb,
        ),
        if (kIsWeb)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(child: Text('웹에서는 지원되지 않는 기능입니다.', style: theme.textTheme.bodySmall)),
          ),
      ],
    );
  }

  Widget _buildModeCard(
    String title,
    VoidCallback? onTap,
    ThemeData theme, {
    bool isWebDisabled = false,
  }) {
    return Center(
      child: GlassmorphicCard(
        onTap: onTap,
        child: SizedBox(
          width: 220,
          height: 50,
          child: Center(
            child: Text(
              title,
              style:
                  onTap == null
                      ? theme.textTheme.bodyLarge?.copyWith(color: Colors.grey)
                      : theme.textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportSheetView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          GlassmorphicCard(child: _buildLearningSettingsSection(context)),
          const SizedBox(height: 24),
          _isLoading
              ? const CircularProgressIndicator()
              : ElevatedButton.icon(
                onPressed: _showExportOptions,
                icon: const Icon(Icons.download),
                label: const Text('파일로 내보내기'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  textStyle: Theme.of(context).textTheme.titleMedium,
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildLearningSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final settings = settingsNotifier.settings;
    final double minValue = _words.isEmpty ? 1.0 : 1.0;
    final double maxValue = _words.isEmpty ? 1.0 : _words.length.toDouble();

    // ▼▼▼ [수정] testTypeMap에 "문장 완성" 추가 ▼▼▼
    final testTypeMap = {
      SelfTestType.random: '랜덤',
      SelfTestType.wordToMeaning: '단어 → 뜻',
      SelfTestType.meaningToWord: '뜻 → 단어',
      SelfTestType.sentenceCompletion: '문장 완성',
    };

    final exportOptionMap = {
      ExportOption.both: '시험지와 답안지 모두',
      ExportOption.testOnly: '시험지만',
      ExportOption.answersOnly: '답안지만',
    };

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('단어 수', style: theme.textTheme.bodyLarge),
              Row(
                children: [
                  Text(
                    '${settings.wordCount.clamp(minValue.toInt(), maxValue.toInt())}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 150,
                    child: Slider(
                      value: settings.wordCount.toDouble().clamp(minValue, maxValue),
                      min: minValue,
                      max: maxValue,
                      divisions: _words.isEmpty ? 1 : (maxValue - minValue).toInt().clamp(1, 100),
                      onChanged: (value) => settingsNotifier.setWordCount(value.toInt()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('폰트 크기', style: theme.textTheme.bodyLarge),
              Row(
                children: [
                  Text(
                    '${settings.fontSize.toInt()}',
                    style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    width: 150,
                    child: Slider(
                      value: settings.fontSize,
                      min: 8.0,
                      max: 20.0,
                      divisions: 12,
                      onChanged: (value) => settingsNotifier.setFontSize(value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: Text('시험 유형', style: theme.textTheme.bodyLarge),
          trailing: Text(testTypeMap[settings.testType]!, style: theme.textTheme.bodyMedium),
          onTap: () => _showTestTypePicker(context),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: Text('내보내기 옵션', style: theme.textTheme.bodyLarge),
          trailing: Text(
            exportOptionMap[settings.exportOption]!,
            style: theme.textTheme.bodyMedium,
          ),
          onTap: () => _showExportOptionPicker(context),
        ),
      ],
    );
  }

  void _showTestTypePicker(BuildContext context) {
    final settingsNotifier = context.read<SettingsNotifier>();
    final testTypeMap = {
      SelfTestType.random: '랜덤',
      SelfTestType.wordToMeaning: '단어 → 뜻',
      SelfTestType.meaningToWord: '뜻 → 단어',
      SelfTestType.sentenceCompletion: '문장 완성',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassmorphicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    testTypeMap.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.value, style: Theme.of(ctx).textTheme.bodyLarge),
                        onTap: () {
                          settingsNotifier.setTestType(entry.key);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
              ),
            ),
          ),
    );
  }

  void _showExportOptionPicker(BuildContext context) {
    final settingsNotifier = context.read<SettingsNotifier>();
    final exportOptionMap = {
      ExportOption.both: '시험지와 답안지 모두',
      ExportOption.testOnly: '시험지만',
      ExportOption.answersOnly: '답안지만',
    };
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => Padding(
            padding: const EdgeInsets.all(8.0),
            child: GlassmorphicCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children:
                    exportOptionMap.entries.map((entry) {
                      return ListTile(
                        title: Text(entry.value, style: Theme.of(ctx).textTheme.bodyLarge),
                        onTap: () {
                          settingsNotifier.setExportOption(entry.key);
                          Navigator.pop(ctx);
                        },
                      );
                    }).toList(),
              ),
            ),
          ),
    );
  }
}

class _LegacyQuizView extends StatefulWidget {
  final List<Word> words;
  final VoidCallback onFinish;
  const _LegacyQuizView({required this.words, required this.onFinish});
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
    final allWords = widget.words;
    final settings = context.read<SettingsNotifier>().settings;
    if (allWords.isEmpty) {
      widget.onFinish();
      return;
    }

    final wordCount = settings.wordCount.clamp(1, allWords.length);
    final sourceCopy = List<Word>.from(allWords)..shuffle();
    final sessionWords = sourceCopy.take(wordCount).toList();

    setState(() {
      _sessionItems =
          sessionWords.map((word) {
            SelfTestType type = settings.testType;
            if (type == SelfTestType.random) {
              type = SelfTestType.values[Random().nextInt(2)];
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
      _showQuizEndDialog();
    }
  }

  void _showQuizEndDialog() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_sessionItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final quizItem = _sessionItems[_currentIndex];
    final String questionText = getQuestionText(quizItem.word, quizItem.questionType);
    final String answerText = getAnswerText(quizItem.word, quizItem.questionType);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _handleAction,
              child: Text(_answerShown ? '다음 문제' : '정답 확인'),
            ),
          ),
        ),
      ],
    );
  }
}

// ▼▼▼ [수정] 스펠링 퀴즈 UI가 복원된 전체 클래스 코드 ▼▼▼
class _SpellingQuizView extends StatefulWidget {
  final List<Word> words;
  final Wordbook selectedWordbook;
  final VoidCallback onFinish;

  const _SpellingQuizView({
    super.key,
    required this.words,
    required this.selectedWordbook,
    required this.onFinish,
  });

  @override
  State<_SpellingQuizView> createState() => _SpellingQuizPageState();
}

// lib/screens/quiz_screen.dart 의 _SpellingQuizPageState 클래스 전체

class _SpellingQuizPageState extends State<_SpellingQuizView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  late final AnimationController _blinkController;
  late WordbookManager _wordbookManager;
  final SrsService _srsService = SrsService();

  List<Word> _sessionWords = [];
  int _currentIndex = 0;
  bool _isRetryAttempt = false;
  SpellingAnswerState _answerState = SpellingAnswerState.none;

  final List<SpellingQuizResult> _results = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wordbookManager = context.read<WordbookManager>();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _initializeSession();
  }

  // ▼▼▼ [수정] dispose 메서드 로직 변경 ▼▼▼
  @override
  void dispose() {
    // 1. Ticker를 사용하는 컨트롤러를 포함한 모든 리소스를 먼저 동기적으로 해제합니다.
    _blinkController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    WidgetsBinding.instance.removeObserver(this);

    // 2. 비동기 작업은 호출만 하고 기다리지 않습니다. (위젯은 이미 사라지는 중)
    _saveIncorrectWordsOnExit();

    // 3. 모든 리소스 해제 후 마지막에 super.dispose()를 호출합니다.
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 100), _ensureKeyboardVisible);
    }
  }

  void _initializeSession() {
    _sessionWords = List.from(widget.words)..shuffle();
    if (_sessionWords.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinish());
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureKeyboardVisible());
  }

  void _ensureKeyboardVisible() {
    if (mounted && _answerState == SpellingAnswerState.none) {
      _focusNode.requestFocus();
    }
  }

  void _checkAnswer() {
    if (_answerState != SpellingAnswerState.none) return;

    final userInput = _textController.text.trim().toLowerCase();
    final correctAnswer = _sessionWords[_currentIndex].word.toLowerCase();

    setState(() {
      if (userInput == correctAnswer) {
        _answerState = SpellingAnswerState.correct;
        _results.add(
          SpellingQuizResult(
            word: _sessionWords[_currentIndex],
            isCorrectOnFirstTry: !_isRetryAttempt,
            isCorrectOnRetry: _isRetryAttempt,
          ),
        );
      } else {
        _answerState = SpellingAnswerState.incorrect;
      }
    });
  }

  void _showCorrectAnswer() {
    setState(() {
      _answerState = SpellingAnswerState.showAnswer;
      _textController.text = _sessionWords[_currentIndex].word;
      _results.add(SpellingQuizResult(word: _sessionWords[_currentIndex], isSkipped: true));
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

  void _retryQuestion() {
    setState(() {
      _answerState = SpellingAnswerState.none;
      _isRetryAttempt = true;
      _textController.clear();
    });
    _ensureKeyboardVisible();
  }

  Future<void> _saveIncorrectWordsOnExit() async {
    final incorrectWords =
        _results.where((r) => !r.isCorrectOnFirstTry).map((r) => r.word).toList();

    if (incorrectWords.isNotEmpty) {
      final wordsToUpdate =
          incorrectWords.map((word) {
            return _srsService.updateWordSrs(word: word, source: SrsUpdateSource.spellingQuiz);
          }).toList();

      await _wordbookManager.updateWordsSrsData(widget.selectedWordbook.dbFileName, wordsToUpdate);
    }
  }

  void _showResults() {
    _saveIncorrectWordsOnExit().then((_) {
      if (mounted) {
        // ▼▼▼ [수정] pushReplacement를 push로 변경 ▼▼▼
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => _SpellingQuizResultScreen(
                  results: _results,
                  onRestart: () {
                    // ▼▼▼ [수정] 결과 화면을 먼저 닫고, 그 다음에 퀴즈 상태를 리셋 ▼▼▼
                    Navigator.of(context).pop();
                    setState(() {
                      _currentIndex = 0;
                      _answerState = SpellingAnswerState.none;
                      _isRetryAttempt = false;
                      _results.clear();
                      _textController.clear();
                    });
                    _initializeSession();
                  },
                  onFinish: () {
                    // ▼▼▼ [수정] 결과 화면을 먼저 닫고, 그 다음에 onFinish 콜백을 호출 ▼▼▼
                    Navigator.of(context).pop();
                    widget.onFinish();
                  },
                ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sessionWords.isEmpty) {
      return const Center(child: Text("퀴즈할 단어가 없습니다."));
    }

    final theme = Theme.of(context);
    final currentWord = _sessionWords[_currentIndex];

    return WillPopScope(
      onWillPop: () async {
        // 뒤로가기 버튼을 누를 때도 오답 저장
        await _saveIncorrectWordsOnExit();
        return true;
      },
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
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 0,
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  autofocus: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _checkAnswer(),
                ),
              ),
            ),
            GestureDetector(
              onTap: _ensureKeyboardVisible,
              child: _buildAnswerBoxes(theme, currentWord.word),
            ),
            const SizedBox(height: 40),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerBoxes(ThemeData theme, String correctAnswer) {
    final userInput = _textController.text;
    Color getTextColor() {
      if (_answerState == SpellingAnswerState.correct) return Colors.blue;
      if (_answerState == SpellingAnswerState.incorrect) return Colors.red;
      if (_answerState == SpellingAnswerState.showAnswer) return Colors.red;
      return theme.textTheme.bodyLarge!.color!;
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: List.generate(correctAnswer.length, (index) {
        final char = index < userInput.length ? userInput[index] : '';
        final bool shouldBlink =
            index == userInput.length && _answerState == SpellingAnswerState.none;

        return Container(
          width: 30,
          height: 40,
          // ▼▼▼ [수정] 깜빡이는 위치에서는 기본 밑줄을 그리지 않도록 수정 ▼▼▼
          decoration: BoxDecoration(
            border: Border(
              bottom:
                  shouldBlink
                      ? BorderSide
                          .none // 깜빡일 때는 기본 밑줄 없음
                      : BorderSide(color: theme.dividerColor, width: 2),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(char, style: theme.textTheme.titleLarge?.copyWith(color: getTextColor())),
              // ▼▼▼ [수정] 깜빡이는 밑줄을 Positioned를 이용해 정확한 위치에 그림 ▼▼▼
              if (shouldBlink)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: FadeTransition(
                    opacity: _blinkController,
                    child: Container(
                      height: 2,
                      color: theme.primaryColor, // 깜빡이는 밑줄 색상
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
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
                child: const Text('정답 보기'),
              ),
            ),
          ),
        ],
      );
    } else {
      // showAnswer
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
}

class _SpellingQuizResultScreen extends StatelessWidget {
  final List<SpellingQuizResult> results;
  final VoidCallback onRestart;
  final VoidCallback onFinish;

  const _SpellingQuizResultScreen({
    super.key,
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
        color: Colors.black.withOpacity(0.04),
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
