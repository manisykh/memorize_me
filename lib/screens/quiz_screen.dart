import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/learning_route_origin.dart';
import '../models/study_plan_model.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../services/analytics_service.dart';
import '../services/test_sheet_service.dart';
import '../services/study_sound_service.dart';
import '../themes/app_theme.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_button.dart';
import 'flashcard_screen.dart';
import '../services/mode_state_service.dart';
import '../services/quiz_answer_logic.dart';

enum QuizMode {
  none,
  multipleChoice,
  reviewMultipleChoice,
  spelling,
  reviewSpelling,
  exportSheet,
}

enum SpellingAnswerState { none, correct, incorrect, showAnswer }

enum _SpellingScorePulse {
  none,
  correctFirstTry,
  correctRetry,
  wrongAttempt,
  wrongCommitted,
}

enum _McqScorePulse { none, correct, incorrect }

enum _ExportAction { download, share, open }

class McqQuizResult {
  final Word questionWord;
  final bool isCorrect;
  McqQuizResult({required this.questionWord, required this.isCorrect});
}

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
  final LearningRouteOrigin origin;
  final bool mistakeReview;

  const QuizScreen({
    super.key,
    this.initialMode = QuizMode.none,
    this.origin = LearningRouteOrigin.standalone,
    this.mistakeReview = false,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Wordbook? _selectedWordbook;
  StudyPlan? _studyPlan;
  List<Word> _words = [];
  List<Word> _reviewWords = [];
  List<Word> _pendingMcqWords = [];
  List<Word> _pendingSpellingWords = [];
  List<Word> _reviewMcqSessionWords = [];
  List<Word> _bridgedSpellingWords = [];
  int _totalWordCount = 0;
  int _lockedNewWordCount = 0;
  bool _isLoading = false;
  bool _isScreenLoading = true;
  late QuizMode _currentMode;
  bool _canDoSentenceCompletion = false;
  String _selectedExportType = 'pdf';

  bool get _isDirectLaunch => widget.initialMode != QuizMode.none;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.initialMode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  Future<void> _initializeData() async {
    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();
    final lastUsedId = await modeStateService.getLastUsedWordbookId(LearningMode.quiz);
    Wordbook? initialWordbook = wordbookManager.activeWordbook;
    initialWordbook ??= wordbookManager.getWordbookById(lastUsedId ?? -1);
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
    super.dispose();
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    setState(() {
      _isLoading = true;
      _studyPlan = null;
      _totalWordCount = 0;
      _lockedNewWordCount = 0;
    });
    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();
    await wordbookManager.setActiveWordbook(wordbook);
    if (mounted) {
      final wordListNotifier = context.read<WordListNotifier>();
      final plan = wordbookManager.planFor(wordbook);
      final allWords = wordListNotifier.words;
      final routineWords = wordbookManager.wordsAvailableForPlan(
        allWords,
        plan: plan,
      );
      final lockedNewWordCount = wordbookManager.lockedNewWordCount(allWords, plan: plan);
      setState(() {
        _selectedWordbook = wordbook;
        _studyPlan = plan;
        _totalWordCount = allWords.length;
        _lockedNewWordCount = lockedNewWordCount;
        _words = routineWords;
        // ▼▼▼ [수정] 예문 존재 여부 확인 로직
        _canDoSentenceCompletion = _words.any(
          (w) => w.exampleSentence != null && w.exampleSentence!.isNotEmpty,
        );
        _pendingMcqWords = wordbookManager.getPendingMcqReviewWords();
        _pendingSpellingWords = wordbookManager.getPendingSpellingReviewWords();
        _reviewMcqSessionWords = List<Word>.from(_pendingMcqWords);
        _reviewWords =
            widget.mistakeReview
                ? _pendingSpellingWords
                : wordbookManager.getWordsForReview();
        if (_currentMode == QuizMode.reviewMultipleChoice && _pendingMcqWords.isEmpty) {
          _currentMode = _pendingSpellingWords.isEmpty ? QuizMode.none : QuizMode.reviewSpelling;
        }
        if (_currentMode == QuizMode.reviewSpelling && _reviewWords.isEmpty) {
          _currentMode = QuizMode.none;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('지금은 복습 대기 단어가 없습니다.')),
            );
          });
        }
        _isLoading = false;
      });
    }
    await modeStateService.setLastUsedWordbookId(LearningMode.quiz, wordbook.id!);
  }

  void _changeMode(QuizMode newMode) {
    if (_selectedWordbook == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 학습할 단어장을 선택해주세요.')));
      return;
    }
    if ((newMode == QuizMode.spelling || newMode == QuizMode.multipleChoice) && _words.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택된 단어장에 단어가 없습니다.')));
      return;
    }
    if (newMode == QuizMode.reviewSpelling && _reviewWords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지금은 복습 대기 단어가 없습니다.')));
      return;
    }
    if (newMode == QuizMode.reviewMultipleChoice && _pendingMcqWords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('다시 확인할 객관식 오답이 없습니다.')));
      return;
    }
    setState(() => _currentMode = newMode);
  }

  void _continueReviewSpelling() {
    final seen = <String>{};
    final combinedWords = <Word>[
      ..._reviewMcqSessionWords,
      ..._pendingSpellingWords,
    ].where((word) {
      final key = word.id?.toString() ?? word.word.trim().toLowerCase();
      return seen.add(key);
    }).toList();
    setState(() {
      _bridgedSpellingWords = combinedWords;
      _reviewWords = _bridgedSpellingWords;
      _currentMode = QuizMode.reviewSpelling;
    });
  }

  String _defaultExportTitle() {
    return '${_selectedWordbook?.name ?? "단어"} 시험지 - ${DateFormat('yyyy-MM-dd').format(DateTime.now())}';
  }

  String _exportActionLabel(_ExportAction action) {
    return switch (action) {
      _ExportAction.download => '저장',
      _ExportAction.share => '공유',
      _ExportAction.open => '바로 보기',
    };
  }

  Future<String?> _requestExportTitle({
    required String type,
    required _ExportAction action,
    String? initialTitle,
  }) async {
    var inputValue = initialTitle ?? _defaultExportTitle();
    final formatLabel = _exportFormatLabel(type);
    final actionLabel = _exportActionLabel(action);
    final result = await showDialog<String>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: Text('$formatLabel 이름 설정'),
            content: TextFormField(
              initialValue: inputValue,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: '파일 이름',
                helperText: '$actionLabel 전에 이름을 지정합니다.',
              ),
              onChanged: (value) => inputValue = value,
              onFieldSubmitted: (value) {
                FocusScope.of(dialogContext).unfocus();
                Navigator.pop(dialogContext, value.trim());
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.pop(dialogContext);
                },
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.pop(dialogContext, inputValue.trim());
                },
                child: Text(actionLabel),
              ),
            ],
          ),
    );
    if (result == null) return null;
    await Future<void>.delayed(Duration.zero);
    return result.isEmpty ? _defaultExportTitle() : result;
  }

  Future<void> _handleExport({
    required String type,
    required _ExportAction action,
    String? title,
  }) async {
    if (!mounted) return;
    if (_words.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('활성화된 단어장에 단어가 없습니다.')));
      return;
    }
    final settings = context.read<SettingsNotifier>().settings;
    final service = context.read<TestSheetService>();
    final shouldRequestTitle = type == 'html' || action != _ExportAction.open;
    final exportTitle =
        title ??
        (!shouldRequestTitle
            ? _defaultExportTitle()
            : await _requestExportTitle(
              type: type,
              action: action,
              initialTitle: _defaultExportTitle(),
            ));
    if (exportTitle == null) return;
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      String? savePath;
      final share = action == _ExportAction.share;
      if (action == _ExportAction.download) {
        savePath = await FilePicker.platform.getDirectoryPath();
        if (savePath == null) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          return;
        }
      } else if (action == _ExportAction.open) {
        savePath = (await getTemporaryDirectory()).path;
      }
      if (type == 'pdf') {
        await service.exportPdf(
          allWords: _words,
          settings: settings,
          title: exportTitle,
          share: share,
          savePath: savePath,
          openAfterSave: action == _ExportAction.open,
        );
      } else if (type == 'html') {
        await service.exportInteractiveHtml(
          allWords: _words,
          settings: settings,
          title: exportTitle,
          share: share,
          savePath: savePath,
          openAfterSave: action == _ExportAction.open,
        );
      } else {
        await service.exportExcel(
          _words,
          settings,
          title: exportTitle,
          share: share,
          savePath: savePath,
          openAfterSave: action == _ExportAction.open,
        );
      }
      if (mounted) {
        context.read<AnalyticsService>().logExportCompleted(
          format: type,
          source: 'quiz_sheet',
        );
      }
      if (action == _ExportAction.download && mounted) {
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

  String _exportFormatLabel(String type) {
    return switch (type) {
      'pdf' => 'PDF',
      'excel' => 'Excel',
      'html' => 'HTML',
      _ => 'PDF',
    };
  }

  IconData _exportFormatIcon(String type) {
    return switch (type) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'excel' => Icons.table_chart_outlined,
      'html' => Icons.language_rounded,
      _ => Icons.description_outlined,
    };
  }

  Color _exportFormatColor(String type, ThemeData theme) {
    return switch (type) {
      'pdf' => const Color(0xFFEF6F61),
      'excel' => const Color(0xFF0F8F6A),
      'html' => const Color(0xFF7C5CFF),
      _ => theme.colorScheme.primary,
    };
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
      final manager = context.watch<WordbookManager>();
      _pendingMcqWords = manager.getPendingMcqReviewWords();
      _pendingSpellingWords = manager.getPendingSpellingReviewWords();
      if (_bridgedSpellingWords.isEmpty) {
        _reviewWords =
            widget.mistakeReview ? _pendingSpellingWords : manager.getWordsForReview();
      }
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        leading:
            _currentMode != QuizMode.none
                ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _finishActiveMode,
                )
                : null,
        automaticallyImplyLeading: _currentMode == QuizMode.none,
      ),
      body: SafeArea(
        child: switch (_currentMode) {
          QuizMode.none => _buildModeSelectionUI(theme),
          QuizMode.exportSheet => _buildExportSheetView(),
          QuizMode.multipleChoice => _MultipleChoiceQuizView(
            key: ValueKey('mcq_${_selectedWordbook?.id}'),
            words: _words,
            optionPool: _words,
            selectedWordbook: _selectedWordbook!,
            sessionLabel: '뜻 고르기',
            sessionHint: '의미를 빠르게 구분하며 오늘 기억을 점검하는 단계입니다.',
            onContinueSpelling: () => _changeMode(QuizMode.spelling),
            onFinish: _finishActiveMode,
          ),
          QuizMode.reviewMultipleChoice => _MultipleChoiceQuizView(
            key: ValueKey('review_mcq_${_selectedWordbook?.id}'),
            words: _reviewMcqSessionWords,
            optionPool: _words,
            selectedWordbook: _selectedWordbook!,
            sessionLabel: '객관식 오답 다시 확인',
            sessionHint: '객관식에서 헷갈린 단어를 같은 방식으로 먼저 확인합니다.',
            mistakeReview: true,
            onContinueSpelling: _continueReviewSpelling,
            onFinish: _finishActiveMode,
          ),
          QuizMode.spelling =>
            _selectedWordbook == null
                ? const Center(child: Text("단어장을 먼저 선택해주세요."))
                : _SpellingQuizView(
                  key: ValueKey('spelling_${_selectedWordbook!.id}'),
                  words: _words,
                  selectedWordbook: _selectedWordbook!,
                  sessionLabel: '전체 스펠링',
                  sessionHint: '단어 철자를 직접 꺼내며 기억을 더 단단하게 고정합니다.',
                  origin: widget.origin,
                  onFinish: _finishActiveMode,
                ),
          QuizMode.reviewSpelling =>
            _selectedWordbook == null
                ? const Center(child: Text("단어장을 먼저 선택해주세요."))
                : _SpellingQuizView(
                  key: ValueKey('review_${_selectedWordbook!.id}'),
                  words: _reviewWords,
                  selectedWordbook: _selectedWordbook!,
                  sessionLabel: '오늘 복습 스펠링',
                  sessionHint: '헷갈리던 단어를 다시 붙잡아 오늘 복습 큐를 줄이는 단계입니다.',
                  origin: widget.origin,
                  onFinish: _finishActiveMode,
                ),
        },
      ),
    );
  }

  void _finishActiveMode() {
    if ((widget.origin == LearningRouteOrigin.home ||
            (widget.origin == LearningRouteOrigin.standalone && _isDirectLaunch)) &&
        Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    _changeMode(QuizMode.none);
  }

  String _getAppBarTitle() {
    switch (_currentMode) {
      case QuizMode.none:
        return '셀프 테스트';
      case QuizMode.exportSheet:
        return '시험지 생성';
      case QuizMode.multipleChoice:
        return '객관식 퀴즈 - ${_currentScopeName()}';
      case QuizMode.reviewMultipleChoice:
        return '객관식 오답 - ${_currentScopeName()}';
      case QuizMode.spelling:
        return '스펠링 퀴즈 - ${_currentScopeName()}';
      case QuizMode.reviewSpelling:
        return '오답/복습 퀴즈 - ${_currentScopeName()}';
    }
  }

  String _currentScopeName() {
    final name = _selectedWordbook?.name ?? '단어장';
    return _studyPlan == null ? name : '$name 플랜';
  }

  Widget _buildModeSelectionUI(ThemeData theme) {
    final canStartMcq = _words.length >= 4;
    final reviewEnabled = _reviewWords.isNotEmpty && _selectedWordbook != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      children: [
        const SizedBox(height: 16),
        WordbookSelectionButton(
          selectedWordbook: _selectedWordbook,
          onWordbookSelected: _onWordbookSelected,
          wordCount: _words.length,
        ),
        if (_studyPlan != null) ...[
          const SizedBox(height: 12),
          _buildLearningScopeNotice(theme),
        ],
        const SizedBox(height: 18),
        GlassmorphicCard(
          borderRadius: 28,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.check_mark_circled_solid,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '오늘의 테스트 루틴',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '기억이 실제로 떠오르는지 확인하고, 복습 우선순위를 더 또렷하게 만드는 단계입니다.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildQuizSummaryMetric(
                      theme,
                      '전체',
                      '${_words.length}개',
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuizSummaryMetric(
                      theme,
                      '오늘 복습',
                      '${_reviewWords.length}개',
                      AppTheme.accentCoral,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuizSummaryMetric(
                      theme,
                      '진입 추천',
                      reviewEnabled ? '복습' : '전체',
                      AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildQuizModeCard(
          theme: theme,
          title: '오늘 복습 스펠링',
          description: '헷갈린 단어부터 다시 꺼내 보며 오늘 복습 큐를 줄입니다.',
          cta: reviewEnabled ? '복습 시작' : '복습 없음',
          icon: CupertinoIcons.flame_fill,
          accentColor: AppTheme.accentCoral,
          countText: '${_reviewWords.length}개',
          enabled: reviewEnabled,
          onTap: reviewEnabled ? () => _changeMode(QuizMode.reviewSpelling) : null,
        ),
        const SizedBox(height: 12),
        _buildQuizModeCard(
          theme: theme,
          title: '객관식 퀴즈',
          description: '뜻을 빠르게 구분하며 이해도를 먼저 확인합니다.',
          cta: canStartMcq ? '객관식 시작' : '4개 이상 필요',
          icon: CupertinoIcons.square_list_fill,
          accentColor: theme.colorScheme.primary,
          countText: '${_words.length}개',
          enabled: canStartMcq,
          onTap: canStartMcq ? () => _changeMode(QuizMode.multipleChoice) : null,
          tooltip: canStartMcq ? null : '단어가 4개 이상 필요합니다.',
        ),
        const SizedBox(height: 12),
        _buildQuizModeCard(
          theme: theme,
          title: '전체 스펠링',
          description: '뜻을 보고 철자를 직접 떠올리며 기억을 더 단단하게 고정합니다.',
          cta: '바로 시작',
          icon: CupertinoIcons.pencil_outline,
          accentColor: AppTheme.primaryGreen,
          countText: '${_words.length}개',
          enabled: _words.isNotEmpty,
          onTap: () => _changeMode(QuizMode.spelling),
        ),
        const SizedBox(height: 12),
        _buildQuizModeCard(
          theme: theme,
          title: '시험지 생성',
          description: '단어 수, 폰트, 문제 유형을 조정해 테스트지를 파일로 내보냅니다.',
          cta: kIsWeb ? '웹 미지원' : '설정 열기',
          icon: CupertinoIcons.doc_richtext,
          accentColor: const Color(0xFF8B5CF6),
          countText: 'PDF / Excel / HTML',
          enabled: !kIsWeb,
          onTap: kIsWeb ? null : () => _changeMode(QuizMode.exportSheet),
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

  Widget _buildLearningScopeNotice(ThemeData theme) {
    final plan = _studyPlan;
    if (plan == null) return const SizedBox.shrink();
    final totalDays = plan.estimatedTotalDays();
    final currentDay = totalDays == 0 ? 0 : plan.currentChunk().clamp(1, totalDays).toInt();

    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      borderRadius: 20,
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(CupertinoIcons.calendar, color: theme.colorScheme.tertiary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '현재 학습 기준 · 플랜 $currentDay/$totalDays일차',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '퀴즈는 열린 단어 ${_words.length}/$_totalWordCount개만 사용합니다. 잠긴 단어 $_lockedNewWordCount개는 아직 출제하지 않습니다.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizSummaryMetric(
    ThemeData theme,
    String label,
    String value,
    Color accentColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizModeCard({
    required ThemeData theme,
    required String title,
    required String description,
    required String cta,
    required IconData icon,
    required Color accentColor,
    required String countText,
    required bool enabled,
    required VoidCallback? onTap,
    String? tooltip,
    bool isWebDisabled = false,
  }) {
    final content = Opacity(
      opacity: enabled ? 1.0 : 0.56,
      child: GlassmorphicCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        countText,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(description, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          cta,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (isWebDisabled) ...[
                        const SizedBox(width: 8),
                        Text(
                          '웹 미지원',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip, child: content);
    }
    return content;
  }

  Widget _buildExportSheetView() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassmorphicCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(CupertinoIcons.doc_richtext, color: Color(0xFF8B5CF6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '시험지 생성 루틴',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '단어 수와 문제 유형을 조정해 바로 풀어볼 수 있는 시험지를 만듭니다.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildQuizSummaryMetric(
                        theme,
                        '단어 수',
                        '${_words.length}개',
                        theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuizSummaryMetric(
                        theme,
                        '유형',
                        '${context.watch<SettingsNotifier>().settings.testTypes.length}개',
                        const Color(0xFF8B5CF6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildQuizSummaryMetric(
                        theme,
                        '출력',
                        _exportFormatLabel(_selectedExportType),
                        _exportFormatColor(_selectedExportType, theme),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassmorphicCard(child: _buildLearningSettingsSection(context)),
          const SizedBox(height: 24),
          _buildExportActionsCard(theme),
        ],
      ),
    );
  }

  Widget _buildExportActionsCard(ThemeData theme) {
    final formatLabel = _exportFormatLabel(_selectedExportType);
    final accentColor = _exportFormatColor(_selectedExportType, theme);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_exportFormatIcon(_selectedExportType), color: accentColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내보내기',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$formatLabel 형식으로 시험지를 생성합니다. 원하는 방식으로 저장하거나 바로 열어보세요.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildExportActionButton(
                  theme: theme,
                  title: '다운로드',
                  icon: Icons.download_rounded,
                  action: _ExportAction.download,
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildExportActionButton(
                  theme: theme,
                  title: '공유',
                  icon: Icons.share_rounded,
                  action: _ExportAction.share,
                  accentColor: accentColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildExportActionButton(
                  theme: theme,
                  title: '바로 보기',
                  icon: Icons.open_in_new_rounded,
                  action: _ExportAction.open,
                  accentColor: accentColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExportActionButton({
    required ThemeData theme,
    required String title,
    required IconData icon,
    required _ExportAction action,
    required Color accentColor,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _handleExport(type: _selectedExportType, action: action),
      child: Container(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: accentColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accentColor, size: 22),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: accentColor,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showWordCountInputDialog({
    required int currentCount,
    required int maxCount,
    required SettingsNotifier settingsNotifier,
  }) async {
    var inputValue = '$currentCount';
    final result = await showDialog<int>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('단어 수 입력'),
            content: TextFormField(
              initialValue: inputValue,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '1-$maxCount',
                suffixText: '개',
              ),
              onChanged: (value) => inputValue = value,
              onFieldSubmitted: (value) {
                FocusScope.of(dialogContext).unfocus();
                Navigator.pop(dialogContext, int.tryParse(value.trim()));
              },
            ),
            actions: [
              TextButton(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();
                  Navigator.pop(dialogContext);
                },
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () {
                  FocusScope.of(dialogContext).unfocus();
                  final parsed = int.tryParse(inputValue.trim());
                  Navigator.pop(dialogContext, parsed);
                },
                child: const Text('적용'),
              ),
            ],
          ),
    );
    if (result == null || !mounted) return;
    final nextCount = result.clamp(1, maxCount).toInt();
    settingsNotifier.setWordCount(nextCount);
  }

  Widget _buildWordCountControl({
    required BuildContext context,
    required ThemeData theme,
    required SettingsNotifier settingsNotifier,
    required AppSettings settings,
    required int maxCount,
  }) {
    final currentCount = settings.wordCount.clamp(1, maxCount).toInt();
    final presets = <int>{5, 10, 20, maxCount}.where((count) => count >= 1 && count <= maxCount);

    void setCount(int value) {
      settingsNotifier.setWordCount(value.clamp(1, maxCount).toInt());
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('단어 수', style: theme.textTheme.bodyLarge),
              const Spacer(),
              Text(
                '$currentCount / $maxCount',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.42)),
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed: currentCount > 1 ? () => setCount(currentCount - 1) : null,
                  icon: const Icon(Icons.remove_rounded),
                  tooltip: '1개 줄이기',
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap:
                        () => _showWordCountInputDialog(
                          currentCount: currentCount,
                          maxCount: maxCount,
                          settingsNotifier: settingsNotifier,
                        ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            '$currentCount',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('탭해서 입력', style: theme.textTheme.labelSmall),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: currentCount < maxCount ? () => setCount(currentCount + 1) : null,
                  icon: const Icon(Icons.add_rounded),
                  tooltip: '1개 늘리기',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                presets.map((count) {
                  final selected = count == currentCount;
                  return ChoiceChip(
                    selected: selected,
                    label: Text(count == maxCount ? '전체 $maxCount' : '$count개'),
                    onSelected: (_) => setCount(count),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExportScopeBadge(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeControl({
    required ThemeData theme,
    required SettingsNotifier settingsNotifier,
    required AppSettings settings,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('폰트 크기', style: theme.textTheme.bodyLarge),
              const SizedBox(width: 8),
              _buildExportScopeBadge(theme, Icons.picture_as_pdf_outlined, 'PDF'),
              const SizedBox(width: 6),
              _buildExportScopeBadge(theme, Icons.table_chart_outlined, 'Excel'),
              const Spacer(),
              Text(
                '${settings.fontSize.toInt()}',
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Slider(
            value: settings.fontSize,
            min: 8.0,
            max: 20.0,
            divisions: 12,
            label: '${settings.fontSize.toInt()}',
            onChanged: (value) => settingsNotifier.setFontSize(value),
          ),
        ],
      ),
    );
  }

  Widget _buildLearningSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final settings = settingsNotifier.settings;
    final int maxWordCount = _words.isEmpty ? 1 : _words.length;
    final testTypeMap = {
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Text(
            '출력 설정',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '분량과 문제 형식을 조절해 원하는 스타일의 시험지를 만드세요.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            '파일 형식',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<String>(
                  value: 'pdf',
                  icon: Icon(Icons.picture_as_pdf_outlined),
                  label: Text('PDF'),
                ),
                ButtonSegment<String>(
                  value: 'excel',
                  icon: Icon(Icons.table_chart_outlined),
                  label: Text('Excel'),
                ),
                ButtonSegment<String>(
                  value: 'html',
                  icon: Icon(Icons.language_rounded),
                  label: Text('HTML'),
                ),
              ],
              selected: {_selectedExportType},
              onSelectionChanged: (selection) {
                setState(() => _selectedExportType = selection.first);
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            '문제 방식',
            style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<TestQuestionFormat>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment<TestQuestionFormat>(
                  value: TestQuestionFormat.shortAnswer,
                  icon: Icon(Icons.edit_note_rounded),
                  label: Text('주관식'),
                ),
                ButtonSegment<TestQuestionFormat>(
                  value: TestQuestionFormat.multipleChoice,
                  icon: Icon(Icons.radio_button_checked_rounded),
                  label: Text('객관식'),
                ),
              ],
              selected: {settings.questionFormat},
              onSelectionChanged: (selection) {
                settingsNotifier.setQuestionFormat(selection.first);
              },
            ),
          ),
        ),
        if (settings.questionFormat == TestQuestionFormat.multipleChoice && _words.length < 2)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              '객관식 선택지는 같은 단어장 안의 다른 단어에서 자동 생성됩니다.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (settings.questionFormat == TestQuestionFormat.shortAnswer)
          SwitchListTile(
            title: Text('스펠링 힌트', style: theme.textTheme.bodyLarge),
            subtitle: Text(
              '뜻 → 단어, 문장 완성 문제에 첫 글자와 끝 글자를 표시합니다.',
              style: theme.textTheme.bodySmall,
            ),
            value: settings.includeSpellingHint,
            onChanged: (value) => settingsNotifier.setIncludeSpellingHint(value),
            contentPadding: const EdgeInsets.only(left: 16.0, right: 6.0),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              '스펠링 힌트는 주관식 시험지에서만 사용할 수 있습니다.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 8),
        _buildWordCountControl(
          context: context,
          theme: theme,
          settingsNotifier: settingsNotifier,
          settings: settings,
          maxCount: maxWordCount,
        ),
        _buildFontSizeControl(
          theme: theme,
          settingsNotifier: settingsNotifier,
          settings: settings,
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: Text('시험 유형', style: theme.textTheme.bodyLarge),
          trailing: SizedBox(
            width: 150,
            child: Text(
              settings.testTypes.map((type) => testTypeMap[type]!).join(', '),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          onTap: () => _showTestTypePicker(context, testTypeMap),
        ),
        const Divider(indent: 16, endIndent: 16),
        SwitchListTile(
          title: Text('문장 완성 문제에 해석 포함', style: theme.textTheme.bodyLarge),
          value: settings.includeTranslation,
          onChanged: (value) => settingsNotifier.setIncludeTranslation(value),
          contentPadding: const EdgeInsets.only(left: 16.0, right: 6.0),
        ),
        const Divider(indent: 16, endIndent: 16),
        ListTile(
          title: Text('답안 포함 옵션', style: theme.textTheme.bodyLarge),
          trailing: Text(
            exportOptionMap[settings.exportOption]!,
            style: theme.textTheme.bodyMedium,
          ),
          onTap: () => _showExportOptionPicker(context),
        ),
      ],
    );
  }

  void _showTestTypePicker(BuildContext context, Map<SelfTestType, String> testTypeMap) {
    final settingsNotifier = context.read<SettingsNotifier>();
    final tempSelectedTypes = Set<SelfTestType>.from(settingsNotifier.settings.testTypes);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: GlassmorphicCard(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text('시험 유형 선택 (복수 가능)', style: Theme.of(ctx).textTheme.titleLarge),
                    ),
                    ...testTypeMap.entries.map((entry) {
                      if (entry.key == SelfTestType.sentenceCompletion) {
                        return CheckboxListTile(
                          title: Text(entry.value, style: Theme.of(ctx).textTheme.bodyLarge),
                          subtitle:
                              !_canDoSentenceCompletion
                                  ? Text(
                                    '단어장에 예문이 없어 비활성화되었습니다.\n(AI 예문 생성 기능으로 예문을 추가하세요)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(ctx).disabledColor,
                                    ),
                                  )
                                  : null,
                          value: tempSelectedTypes.contains(entry.key),
                          onChanged:
                              !_canDoSentenceCompletion
                                  ? null
                                  : (bool? isSelected) {
                                    setModalState(() {
                                      if (isSelected == true) {
                                        tempSelectedTypes.add(entry.key);
                                      } else {
                                        if (tempSelectedTypes.length > 1) {
                                          tempSelectedTypes.remove(entry.key);
                                        }
                                      }
                                    });
                                  },
                        );
                      }
                      return CheckboxListTile(
                        title: Text(entry.value, style: Theme.of(ctx).textTheme.bodyLarge),
                        value: tempSelectedTypes.contains(entry.key),
                        onChanged: (bool? isSelected) {
                          setModalState(() {
                            if (isSelected == true) {
                              tempSelectedTypes.add(entry.key);
                            } else {
                              if (tempSelectedTypes.length > 1) {
                                tempSelectedTypes.remove(entry.key);
                              }
                            }
                          });
                        },
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          child: const Text('적용'),
                          onPressed: () {
                            settingsNotifier.updateTestTypes(tempSelectedTypes);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
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

class _MultipleChoiceQuizView extends StatefulWidget {
  final List<Word> words;
  final List<Word> optionPool;
  final Wordbook selectedWordbook;
  final String sessionLabel;
  final String sessionHint;
  final bool mistakeReview;
  final VoidCallback onContinueSpelling;
  final VoidCallback onFinish;

  const _MultipleChoiceQuizView({
    super.key,
    required this.words,
    required this.optionPool,
    required this.selectedWordbook,
    required this.sessionLabel,
    required this.sessionHint,
    this.mistakeReview = false,
    required this.onContinueSpelling,
    required this.onFinish,
  });

  @override
  State<_MultipleChoiceQuizView> createState() => _MultipleChoiceQuizViewState();
}

class _MultipleChoiceQuizViewState extends State<_MultipleChoiceQuizView>
    with SingleTickerProviderStateMixin {
  late List<Word> _sessionWords;
  int _currentIndex = 0;
  List<Word> _currentOptions = [];
  Word? _selectedOption;
  bool _isAnswered = false;
  final SrsService _srsService = SrsService();
  late final WordbookManager _wordbookManager;
  final List<McqQuizResult> _results = [];
  bool _isClosingResults = false;
  late final AnimationController _scorePulseController;
  _McqScorePulse _scorePulse = _McqScorePulse.none;
  Timer? _autoAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _wordbookManager = context.read<WordbookManager>();
    _scorePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _startSession();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _scorePulseController.dispose();
    super.dispose();
  }

  void _startSession() {
    _autoAdvanceTimer?.cancel();
    final wordCount = widget.words.length;
    setState(() {
      _results.clear();
      _currentIndex = 0;
      _scorePulse = _McqScorePulse.none;
      _sessionWords = (List<Word>.from(widget.words)..shuffle()).take(wordCount).toList();
      _prepareQuestion();
    });
    context.read<AnalyticsService>().logStudyStarted(
      mode: 'multiple_choice',
      wordCount: _sessionWords.length,
    );
  }

  void _prepareQuestion() {
    final currentWord = _sessionWords[_currentIndex];
    final otherWords = List<Word>.from(widget.optionPool)
      ..removeWhere((w) => w.id == currentWord.id);
    otherWords.shuffle();
    _currentOptions = [currentWord, ...otherWords.take(3)]..shuffle();
    _selectedOption = null;
    _isAnswered = false;
    _scorePulse = _McqScorePulse.none;
  }

  void _onOptionSelected(Word option) {
    if (_isAnswered) return;
    setState(() => _selectedOption = option);
  }

  bool? _commitCurrentAnswer() {
    if (_selectedOption == null || _isAnswered) return null;
    final currentWord = _sessionWords[_currentIndex];
    final isCorrect = QuizAnswerLogic.isCorrectChoice(
      selected: _selectedOption!,
      answer: currentWord,
    );
    final updatedWord = _srsService.updateWordSrs(
      word: currentWord,
      source: SrsUpdateSource.multipleChoiceQuiz,
      difficulty: isCorrect ? SrsDifficulty.good : SrsDifficulty.again,
    ).copyWith(pendingMcqReview: isCorrect ? 0 : 1);
    _wordbookManager.updateWordsSrsData(widget.selectedWordbook.dbFileName, [updatedWord]);
    setState(() {
      _isAnswered = true;
      _results.add(McqQuizResult(questionWord: currentWord, isCorrect: isCorrect));
    });
    return isCorrect;
  }

  void _nextQuestion() {
    final isCorrect = _commitCurrentAnswer();
    if (isCorrect == null) return;
    unawaited(
      context.read<StudySoundService>().play(
        isCorrect ? StudySoundEffect.correct : StudySoundEffect.incorrect,
      ),
    );
    _playScorePulse(
      isCorrect ? _McqScorePulse.correct : _McqScorePulse.incorrect,
    );
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 720), () {
      if (mounted) _advanceQuestion();
    });
  }

  void _playScorePulse(_McqScorePulse pulse) {
    if (!mounted) return;
    setState(() => _scorePulse = pulse);
    unawaited(
      _scorePulseController.forward(from: 0).whenComplete(() {
        if (!mounted || _scorePulse != pulse) return;
        setState(() => _scorePulse = _McqScorePulse.none);
      }),
    );
  }

  void _advanceQuestion() {
    _autoAdvanceTimer?.cancel();
    final nextIndex = QuizAnswerLogic.nextIndex(
      currentIndex: _currentIndex,
      totalCount: _sessionWords.length,
    );
    if (nextIndex != null) {
      setState(() {
        _currentIndex = nextIndex;
        _prepareQuestion();
      });
    } else {
      _showResults();
    }
  }

  void _restartIncorrectSession() {
    _autoAdvanceTimer?.cancel();
    final incorrectWords =
        _results.where((result) => !result.isCorrect).map((result) => result.questionWord).toList();
    if (incorrectWords.isEmpty) {
      _startSession();
      return;
    }

    final seenIds = <int?>{};
    final uniqueWords =
        incorrectWords.where((word) => seenIds.add(word.id)).toList();

    setState(() {
      _results.clear();
      _currentIndex = 0;
      _scorePulse = _McqScorePulse.none;
      _sessionWords = List<Word>.from(uniqueWords)..shuffle();
      _prepareQuestion();
    });
  }

  void _closeResultsThen(VoidCallback action) {
    if (_isClosingResults) return;
    _isClosingResults = true;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _isClosingResults = false;
      action();
    });
  }

  void _finishFromResults() {
    if (_isClosingResults) return;
    _isClosingResults = true;
    Navigator.of(context).pop();
    widget.onFinish();
  }

  void _continueSpellingFromResults() {
    if (_isClosingResults) return;
    _isClosingResults = true;
    Navigator.of(context).pop();
    widget.onContinueSpelling();
  }

  void _showResults() {
    _autoAdvanceTimer?.cancel();
    context.read<AnalyticsService>().logQuizCompleted(
      mode: 'multiple_choice',
      questionCount: _results.length,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _McqQuizResultScreen(
              results: _results,
              mistakeReview: widget.mistakeReview,
              onRestart: () => _closeResultsThen(_restartIncorrectSession),
              onContinueSpelling: _continueSpellingFromResults,
              onFinish: _finishFromResults,
            ),
      ),
    );
  }

  Color _getOptionColor(Word option, Word correctAnswer, BuildContext context) {
    const positive = AppTheme.primaryGreen;
    const caution = AppTheme.accentCoral;
    if (!_isAnswered) {
      if (option.id == _selectedOption?.id) {
        return Theme.of(context).colorScheme.primary.withValues(alpha: 0.13);
      }
      return Theme.of(context).cardColor.withValues(alpha: 0.58);
    }
    if (option.id == correctAnswer.id) {
      return positive.withValues(alpha: 0.14);
    }
    if (option.id == _selectedOption?.id) {
      return caution.withValues(alpha: 0.14);
    }
    return Theme.of(context).cardColor.withValues(alpha: 0.46);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_sessionWords.isEmpty) {
      return const Center(child: Text("퀴즈를 생성할 단어가 부족합니다."));
    }
    final currentWord = _sessionWords[_currentIndex];
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          _QuizSessionHeader(
            label: widget.sessionLabel,
            hint: widget.sessionHint,
            accentColor: theme.colorScheme.primary,
            currentIndex: _currentIndex,
            totalCount: _sessionWords.length,
          ),
          const SizedBox(height: 8),
          _buildScoreStatusBar(theme),
          const SizedBox(height: 10),
          Expanded(
            flex: 3,
            child: GlassmorphicCard(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              child: Center(
                child: Text(
                  currentWord.word,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 10,
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _currentOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final option = _currentOptions[index];
                final isCorrect = option.id == currentWord.id;
                final isSelected = option.id == _selectedOption?.id;
                final borderColor =
                    !_isAnswered
                        ? isSelected
                        ? theme.colorScheme.primary.withValues(alpha: 0.42)
                        : theme.colorScheme.outline.withValues(alpha: 0.18)
                        : isCorrect
                        ? AppTheme.primaryGreen.withValues(alpha: 0.34)
                        : isSelected
                        ? AppTheme.accentCoral.withValues(alpha: 0.34)
                        : theme.colorScheme.outline.withValues(alpha: 0.14);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  constraints: const BoxConstraints(minHeight: 64),
                  decoration: BoxDecoration(
                    color: _getOptionColor(option, currentWord, context),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _onOptionSelected(option),
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Center(
                          child: Text(
                            option.meaning,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              height: 1.18,
                            ),
                            textAlign: TextAlign.center,
                            softWrap: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed:
                  _selectedOption != null && !_isAnswered
                      ? _nextQuestion
                      : null,
              icon: const Icon(CupertinoIcons.check_mark, size: 18),
              label: const Text('정답 확인'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreStatusBar(ThemeData theme) {
    final correct = _results.where((result) => result.isCorrect).length;
    final incorrect = _results.length - correct;
    final correctPulse = _scorePulse == _McqScorePulse.correct;
    final incorrectPulse = _scorePulse == _McqScorePulse.incorrect;

    Widget item({
      required IconData icon,
      required String label,
      required int value,
      required Color color,
      required bool isPulsing,
      IconData? pulseIcon,
    }) {
      return Expanded(
        child: AnimatedBuilder(
          animation: _scorePulseController,
          builder: (context, child) {
            final progress = _scorePulseController.value;
            final rawIntensity =
                progress <= 0.35
                    ? progress / 0.35
                    : (1 - progress) / 0.65;
            final intensity =
                isPulsing ? rawIntensity.clamp(0.0, 1.0).toDouble() : 0.0;
            return Transform.scale(
              scale: 1 + (0.035 * intensity),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.09 + (0.22 * intensity)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.14 + (0.62 * intensity)),
                    width: 1 + intensity,
                  ),
                  boxShadow:
                      intensity == 0
                          ? null
                          : [
                            BoxShadow(
                              color: color.withValues(alpha: 0.24 * intensity),
                              blurRadius: 16 * intensity,
                              spreadRadius: 2 * intensity,
                            ),
                          ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPulsing && pulseIcon != null ? pulseIcon : icon,
                      size: 15 + (2 * intensity),
                      color: color,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '$label $value',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Row(
      children: [
        item(
          icon: CupertinoIcons.check_mark_circled_solid,
          label: '맞음',
          value: correct,
          color: AppTheme.primaryGreen,
          isPulsing: correctPulse,
          pulseIcon: CupertinoIcons.check_mark_circled_solid,
        ),
        const SizedBox(width: 8),
        item(
          icon: CupertinoIcons.xmark_circle_fill,
          label: '틀림',
          value: incorrect,
          color: AppTheme.accentCoral,
          isPulsing: incorrectPulse,
          pulseIcon: CupertinoIcons.exclamationmark_triangle_fill,
        ),
      ],
    );
  }
}

class _QuizSessionHeader extends StatelessWidget {
  final String label;
  final String hint;
  final Color accentColor;
  final int currentIndex;
  final int totalCount;
  final int? correctCount;
  final int? incorrectCount;
  final bool compact;

  const _QuizSessionHeader({
    required this.label,
    required this.hint,
    required this.accentColor,
    required this.currentIndex,
    required this.totalCount,
    this.correctCount,
    this.incorrectCount,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedCount = totalCount == 0 ? 0 : currentIndex.clamp(0, totalCount - 1) + 1;
    final remainingCount = totalCount == 0 ? 0 : totalCount - completedCount;
    final progress = totalCount == 0 ? 0.0 : completedCount / totalCount;
    if (compact) {
      return GlassmorphicCard(
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 10),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    CupertinoIcons.check_mark_circled_solid,
                    color: accentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$completedCount / $totalCount · 남음 $remainingCount개 · ${(progress * 100).round()}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                color: accentColor,
                backgroundColor: accentColor.withValues(alpha: 0.12),
              ),
            ),
          ],
        ),
      );
    }
    return GlassmorphicCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(CupertinoIcons.check_mark_circled_solid, color: accentColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(hint, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              color: accentColor,
              backgroundColor: accentColor.withValues(alpha: 0.12),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMetric(context, '문제', '$completedCount / $totalCount')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetric(context, '남음', '$remainingCount개')),
              const SizedBox(width: 8),
              Expanded(child: _buildMetric(context, '진행률', '${(progress * 100).round()}%')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: accentColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _McqQuizResultScreen extends StatelessWidget {
  final List<McqQuizResult> results;
  final VoidCallback onRestart;
  final VoidCallback onContinueSpelling;
  final VoidCallback onFinish;
  final bool mistakeReview;

  const _McqQuizResultScreen({
    required this.results,
    required this.onRestart,
    required this.onContinueSpelling,
    required this.onFinish,
    this.mistakeReview = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalQuestions = results.length;
    final correctAnswers = results.where((r) => r.isCorrect).length;
    final incorrectAnswers = totalQuestions - correctAnswers;
    final accuracyRate = totalQuestions > 0 ? (correctAnswers / totalQuestions * 100).round() : 0;
    final hasIncorrect = incorrectAnswers > 0;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onFinish();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈 결과'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: onFinish,
        ),
      ),
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
                    _buildStatRow('정답', '$correctAnswers개', theme),
                    _buildStatRow('오답', '$incorrectAnswers개', theme),
                    Divider(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.2)),
                    _buildStatRow('정답율', '$accuracyRate%', theme, isHighlight: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildMomentumCard(
              theme: theme,
              hasIncorrect: hasIncorrect,
              correctAnswers: correctAnswers,
              incorrectAnswers: incorrectAnswers,
            ),
            const SizedBox(height: 20),
            _buildNextActionCard(
              theme: theme,
              hasIncorrect: hasIncorrect,
              incorrectCount: incorrectAnswers,
              onRestart: onRestart,
              onContinueSpelling: onContinueSpelling,
              onFinish: onFinish,
              mistakeReview: mistakeReview,
            ),
            const SizedBox(height: 20),
            GlassmorphicCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상세 결과',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    ...results.map((result) => _buildResultItem(result, theme)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMomentumCard({
    required ThemeData theme,
    required bool hasIncorrect,
    required int correctAnswers,
    required int incorrectAnswers,
  }) {
    final accentColor = hasIncorrect ? AppTheme.accentCoral : AppTheme.primaryGreen;
    final icon = hasIncorrect ? CupertinoIcons.flame_fill : CupertinoIcons.check_mark_circled_solid;
    final title = hasIncorrect ? '오늘 복습 큐가 또렷해졌어요' : '오늘 기억이 잘 붙었습니다';
    final message =
        hasIncorrect
            ? '틀린 단어 $incorrectAnswers개는 다시 볼 이유가 분명해졌습니다. 지금 바로 이어서 복습하면 가장 효율이 좋습니다.'
            : '맞힌 단어 $correctAnswers개가 안정적으로 떠올랐습니다. 새 단어를 더 넣거나 다음 루틴으로 넘어가기 좋은 흐름입니다.';

    return GlassmorphicCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextActionCard({
    required ThemeData theme,
    required bool hasIncorrect,
    required int incorrectCount,
    required VoidCallback onRestart,
    required VoidCallback onContinueSpelling,
    required VoidCallback onFinish,
    required bool mistakeReview,
  }) {
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.arrow_right_circle_fill, color: AppTheme.primaryGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '다음 학습을 선택하세요',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            mistakeReview && hasIncorrect
                ? '객관식 오답 $incorrectCount개가 남았습니다. 모두 맞힌 뒤 주관식 문제로 이어갈 수 있습니다.'
                : hasIncorrect
                ? '틀린 $incorrectCount개는 복습에 반영됩니다. 객관식을 다시 섞어 보거나 주관식 문제로 이어갈 수 있습니다.'
                : '객관식 확인을 마쳤습니다. 한 번 더 섞어 보거나 주관식 문제로 기억을 고정하세요.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          if (mistakeReview && hasIncorrect)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: onRestart,
                icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
                label: Text('남은 객관식 오답 $incorrectCount개 다시'),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
                    label: const Text('객관식 다시'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onContinueSpelling,
                    icon: const Icon(CupertinoIcons.pencil, size: 18),
                    label: const Text('주관식 문제'),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: onFinish,
              icon: const Icon(CupertinoIcons.check_mark_circled, size: 18),
              label: const Text('완료'),
            ),
          ),
        ],
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

  Widget _buildResultItem(McqQuizResult result, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: (result.isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            result.isCorrect ? Icons.check_circle_outline : Icons.cancel_outlined,
            color: result.isCorrect ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.questionWord.word,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(result.questionWord.meaning, style: theme.textTheme.bodyMedium),
                if (result.questionWord.additionalMeanings.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '추가 뜻 · ${result.questionWord.additionalMeanings.join(' · ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpellingQuizView extends StatefulWidget {
  final List<Word> words;
  final Wordbook selectedWordbook;
  final String sessionLabel;
  final String sessionHint;
  final LearningRouteOrigin origin;
  final VoidCallback onFinish;

  const _SpellingQuizView({
    super.key,
    required this.words,
    required this.selectedWordbook,
    required this.sessionLabel,
    required this.sessionHint,
    this.origin = LearningRouteOrigin.standalone,
    required this.onFinish,
  });

  @override
  State<_SpellingQuizView> createState() => _SpellingQuizPageState();
}

class _SpellingQuizPageState extends State<_SpellingQuizView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final AnimationController _blinkController;
  late final AnimationController _scorePulseController;
  late WordbookManager _wordbookManager;
  final SrsService _srsService = SrsService();
  List<Word> _sessionWords = [];
  int _currentIndex = 0;
  bool _isRetryAttempt = false;
  bool _hasSavedSessionSrs = false;
  SpellingAnswerState _answerState = SpellingAnswerState.none;
  final List<SpellingQuizResult> _results = [];
  bool _isClosingResults = false;
  _SpellingScorePulse _scorePulse = _SpellingScorePulse.none;
  Timer? _autoAdvanceTimer;
  bool _showAdditionalMeaningHint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wordbookManager = context.read<WordbookManager>();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..repeat(reverse: true);
    _scorePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 560),
    );
    _initializeSession();
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _blinkController.dispose();
    _scorePulseController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_saveSessionSrsOnExit());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      unawaited(Future<void>.delayed(const Duration(milliseconds: 120), _ensureKeyboardVisible));
      unawaited(Future<void>.delayed(const Duration(milliseconds: 420), _ensureKeyboardVisible));
    }
  }

  void _initializeSession() {
    _hasSavedSessionSrs = false;
    _sessionWords = List.from(widget.words)..shuffle();
    if (_sessionWords.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinish());
      return;
    }
    context.read<AnalyticsService>().logStudyStarted(
      mode: widget.origin == LearningRouteOrigin.review ? 'review_spelling' : 'spelling',
      wordCount: _sessionWords.length,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureKeyboardVisible());
  }

  void _ensureKeyboardVisible() {
    if (mounted && _answerState == SpellingAnswerState.none) {
      FocusScope.of(context).requestFocus(_focusNode);
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        FocusScope.of(context).requestFocus(_focusNode);
        unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      });
    }
  }

  void _dismissKeyboard() {
    _focusNode.unfocus();
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  void _playScorePulse(_SpellingScorePulse pulse) {
    if (!mounted) return;
    setState(() => _scorePulse = pulse);
    unawaited(
      _scorePulseController.forward(from: 0).whenComplete(() {
        if (!mounted || _scorePulse != pulse) return;
        setState(() => _scorePulse = _SpellingScorePulse.none);
      }),
    );
  }

  void _scheduleAutomaticAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(const Duration(milliseconds: 720), () {
      if (mounted) _nextQuestion();
    });
  }

  void _checkAnswer() {
    if (_answerState != SpellingAnswerState.none) return;
    final wasRetryAttempt = _isRetryAttempt;
    final attemptResult = QuizAnswerLogic.evaluateSpelling(
      input: _textController.text,
      answer: _sessionWords[_currentIndex].word,
      isRetry: wasRetryAttempt,
    );
    final isCorrect = attemptResult != SpellingAttemptResult.incorrect;
    setState(() {
      if (isCorrect) {
        _answerState = SpellingAnswerState.correct;
        _results.add(
          SpellingQuizResult(
            word: _sessionWords[_currentIndex],
            isCorrectOnFirstTry:
                attemptResult == SpellingAttemptResult.correctFirstTry,
            isCorrectOnRetry:
                attemptResult == SpellingAttemptResult.correctOnRetry,
          ),
        );
      } else {
        _answerState = SpellingAnswerState.incorrect;
      }
    });
    if (isCorrect) {
      unawaited(context.read<StudySoundService>().play(StudySoundEffect.correct));
      _playScorePulse(
        wasRetryAttempt
            ? _SpellingScorePulse.correctRetry
            : _SpellingScorePulse.correctFirstTry,
      );
      _scheduleAutomaticAdvance();
    } else {
      unawaited(context.read<StudySoundService>().play(StudySoundEffect.incorrect));
      _playScorePulse(_SpellingScorePulse.wrongAttempt);
    }
  }

  String? _firstRevealableSpellingChar() {
    if (_sessionWords.isEmpty) return null;
    final answer = _sessionWords[_currentIndex].word;
    for (final rune in answer.runes) {
      final char = String.fromCharCode(rune);
      if (char == ' ' || char == '-' || char == '_') continue;
      return char;
    }
    return null;
  }

  void _applyFirstLetterHint() {
    if (_answerState != SpellingAnswerState.none) return;
    if (_textController.text.replaceAll(RegExp(r'[\s\-_]'), '').isNotEmpty) return;
    final firstChar = _firstRevealableSpellingChar();
    if (firstChar == null) return;
    _textController.value = TextEditingValue(
      text: firstChar,
      selection: TextSelection.collapsed(offset: firstChar.length),
    );
    setState(() => _showAdditionalMeaningHint = true);
    _ensureKeyboardVisible();
  }

  void _showCorrectAnswer() {
    setState(() {
      _answerState = SpellingAnswerState.showAnswer;
      _textController.text = _sessionWords[_currentIndex].word;
      _results.add(SpellingQuizResult(word: _sessionWords[_currentIndex], isSkipped: true));
    });
    unawaited(context.read<StudySoundService>().play(StudySoundEffect.incorrect));
    _playScorePulse(_SpellingScorePulse.wrongCommitted);
    _scheduleAutomaticAdvance();
  }

  void _nextQuestion() {
    _autoAdvanceTimer?.cancel();
    final nextIndex = QuizAnswerLogic.nextIndex(
      currentIndex: _currentIndex,
      totalCount: _sessionWords.length,
    );
    if (nextIndex != null) {
      setState(() {
        _currentIndex = nextIndex;
        _answerState = SpellingAnswerState.none;
        _isRetryAttempt = false;
        _scorePulse = _SpellingScorePulse.none;
        _showAdditionalMeaningHint = false;
        _textController.clear();
      });
      _ensureKeyboardVisible();
    } else {
      _dismissKeyboard();
      _showResults();
    }
  }

  void _retryQuestion() {
    _autoAdvanceTimer?.cancel();
    setState(() {
      _answerState = SpellingAnswerState.none;
      _isRetryAttempt = true;
      _scorePulse = _SpellingScorePulse.none;
      _showAdditionalMeaningHint = false;
      _textController.clear();
    });
    _ensureKeyboardVisible();
  }

  void _restartWeakWordSession() {
    final weakWords =
        _results
            .where((result) => !result.isCorrectOnFirstTry)
            .map((result) => result.word)
            .toList();
    if (weakWords.isEmpty) {
      setState(() {
        _currentIndex = 0;
        _answerState = SpellingAnswerState.none;
        _isRetryAttempt = false;
        _hasSavedSessionSrs = false;
        _results.clear();
        _textController.clear();
      });
      _initializeSession();
      return;
    }

    final seenIds = <int?>{};
    final uniqueWords = weakWords.where((word) => seenIds.add(word.id)).toList();

    setState(() {
      _currentIndex = 0;
      _answerState = SpellingAnswerState.none;
      _isRetryAttempt = false;
      _hasSavedSessionSrs = false;
      _results.clear();
      _textController.clear();
      _sessionWords = List<Word>.from(uniqueWords)..shuffle();
    });
    _ensureKeyboardVisible();
  }

  Future<void> _saveSessionSrsOnExit() async {
    if (_hasSavedSessionSrs || _results.isEmpty) return;

    final wordsToUpdate =
        _results.map((result) {
          if (result.isCorrectOnFirstTry || result.isCorrectOnRetry) {
            return _srsService.updateWordSrs(
              word: result.word,
              source: SrsUpdateSource.flashcard,
              difficulty: SrsDifficulty.good,
            ).copyWith(pendingSpellingReview: 0);
          }
          return _srsService.updateWordSrs(
            word: result.word,
            source: SrsUpdateSource.spellingQuiz,
          ).copyWith(pendingSpellingReview: 1);
        }).toList();

    _hasSavedSessionSrs = true;
    await _wordbookManager.updateWordsSrsData(widget.selectedWordbook.dbFileName, wordsToUpdate);
  }

  void _closeResultsThen(VoidCallback action) {
    if (_isClosingResults) return;
    _isClosingResults = true;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _isClosingResults = false;
      action();
    });
  }

  void _finishFromResults() {
    if (_isClosingResults) return;
    _isClosingResults = true;
    Navigator.of(context).pop();
    widget.onFinish();
  }

  void _showResults() {
    context.read<AnalyticsService>().logQuizCompleted(
      mode: widget.origin == LearningRouteOrigin.review ? 'review_spelling' : 'spelling',
      questionCount: _results.length,
    );
    _saveSessionSrsOnExit().then((_) {
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => _SpellingQuizResultScreen(
                  results: _results,
                  origin: widget.origin,
                  onRestart: () => _closeResultsThen(() {
                    setState(() {
                      _currentIndex = 0;
                      _answerState = SpellingAnswerState.none;
                      _isRetryAttempt = false;
                      _hasSavedSessionSrs = false;
                      _results.clear();
                      _textController.clear();
                    });
                    _initializeSession();
                  }),
                  onRetryWeakWords: () => _closeResultsThen(_restartWeakWordSession),
                  onFinish: _finishFromResults,
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
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    return PopScope<void>(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) return;
        await _saveSessionSrsOnExit();
      },
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                20,
                keyboardVisible ? 8 : 20,
                20,
                16,
              ),
              child: Column(
                children: [
                  _QuizSessionHeader(
                    label: widget.sessionLabel,
                    hint: widget.sessionHint,
                    accentColor:
                        widget.sessionLabel.contains('복습')
                            ? AppTheme.accentCoral
                            : theme.colorScheme.primary,
                    currentIndex: _currentIndex,
                    totalCount: _sessionWords.length,
                    compact: keyboardVisible,
                  ),
                  SizedBox(height: keyboardVisible ? 8 : 10),
                  _buildSpellingStatusBar(theme),
                  SizedBox(height: keyboardVisible ? 14 : 20),
                  Text(
                    currentWord.meaning,
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  if (_showAdditionalMeaningHint &&
                      currentWord.additionalMeanings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '추가 뜻 · ${currentWord.additionalMeanings.join(' · ')}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: keyboardVisible ? 18 : 30),
                  Opacity(
                    opacity: 0,
                    child: SizedBox(
                      width: 1,
                      height: 1,
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.98),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              minimum: EdgeInsets.zero,
              child: _buildActionButtons(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpellingStatusBar(ThemeData theme) {
    final correct = _results.where((result) => result.isCorrectOnFirstTry || result.isCorrectOnRetry).length;
    final wrong = _results.where((result) => result.isSkipped).length;
    final correctPulse =
        _scorePulse == _SpellingScorePulse.correctFirstTry ||
        _scorePulse == _SpellingScorePulse.correctRetry;
    final wrongPulse =
        _scorePulse == _SpellingScorePulse.wrongAttempt ||
        _scorePulse == _SpellingScorePulse.wrongCommitted;
    final correctPulseColor =
        _scorePulse == _SpellingScorePulse.correctRetry
            ? const Color(0xFFC28A2C)
            : AppTheme.primaryGreen;

    Widget item({
      required IconData icon,
      required String label,
      required String value,
      required Color color,
      required bool isPulsing,
      required Color pulseColor,
      IconData? pulseIcon,
    }) {
      return Expanded(
        child: AnimatedBuilder(
          animation: _scorePulseController,
          builder: (context, child) {
            final progress = _scorePulseController.value;
            final rawIntensity =
                progress <= 0.35
                    ? progress / 0.35
                    : (1 - progress) / 0.65;
            final intensity =
                isPulsing ? rawIntensity.clamp(0.0, 1.0).toDouble() : 0.0;
            final displayColor = isPulsing ? pulseColor : color;
            return Transform.scale(
              scale: 1 + (0.035 * intensity),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                decoration: BoxDecoration(
                  color: displayColor.withValues(
                    alpha: 0.09 + (0.22 * intensity),
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: displayColor.withValues(
                      alpha: 0.14 + (0.62 * intensity),
                    ),
                    width: 1 + intensity,
                  ),
                  boxShadow:
                      intensity == 0
                          ? null
                          : [
                            BoxShadow(
                              color: displayColor.withValues(
                                alpha: 0.24 * intensity,
                              ),
                              blurRadius: 16 * intensity,
                              spreadRadius: 2 * intensity,
                            ),
                          ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPulsing && pulseIcon != null ? pulseIcon : icon,
                      size: 15 + (2 * intensity),
                      color: displayColor,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '$label $value',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: displayColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    }

    return Row(
      children: [
        item(
          icon: CupertinoIcons.check_mark_circled_solid,
          label: '맞음',
          value: '$correct',
          color: AppTheme.primaryGreen,
          isPulsing: correctPulse,
          pulseColor: correctPulseColor,
          pulseIcon:
              _scorePulse == _SpellingScorePulse.correctRetry
                  ? CupertinoIcons.arrow_counterclockwise
                  : CupertinoIcons.check_mark_circled_solid,
        ),
        const SizedBox(width: 8),
        item(
          icon: CupertinoIcons.xmark_circle_fill,
          label: '틀림',
          value: '$wrong',
          color: AppTheme.accentCoral,
          isPulsing: wrongPulse,
          pulseColor: AppTheme.accentCoral,
          pulseIcon:
              _scorePulse == _SpellingScorePulse.wrongAttempt
                  ? CupertinoIcons.exclamationmark_triangle_fill
                  : CupertinoIcons.xmark_circle_fill,
        ),
      ],
    );
  }

  Widget _buildAnswerBoxes(ThemeData theme, String correctAnswer) {
    final userInput = _textController.text.replaceAll(RegExp(r'[\s\-_]'), '');
    bool isFixedHintChar(String char) => char == '-' || char == '_' || char == ' ';
    int visibleInputIndexForAnswerIndex(int answerIndex) {
      var visibleIndex = 0;
      for (var i = 0; i < answerIndex; i++) {
        if (!isFixedHintChar(correctAnswer[i])) {
          visibleIndex++;
        }
      }
      return visibleIndex;
    }

    Color getTextColor() {
      if (_answerState == SpellingAnswerState.correct) return AppTheme.primaryGreen;
      if (_answerState == SpellingAnswerState.incorrect) return AppTheme.accentCoral;
      if (_answerState == SpellingAnswerState.showAnswer) return AppTheme.accentCoral;
      return theme.textTheme.bodyLarge!.color!;
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 8,
      children: List.generate(correctAnswer.length, (index) {
        final answerChar = correctAnswer[index];
        final isFixedHint = isFixedHintChar(answerChar);
        final isBlankGap = answerChar == ' ';
        final inputIndex = visibleInputIndexForAnswerIndex(index);
        final char =
            isBlankGap
                ? ''
                : isFixedHint
                ? answerChar
                : inputIndex < userInput.length
                ? userInput[inputIndex]
                : '';
        final bool shouldBlink =
            !isFixedHint && inputIndex == userInput.length && _answerState == SpellingAnswerState.none;
        return Container(
          width: isBlankGap ? 14 : 30,
          height: 40,
          decoration: BoxDecoration(
            border: Border(
              bottom:
                  isFixedHint
                      ? BorderSide.none
                      : BorderSide(color: theme.dividerColor, width: 2),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Text(
                char,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: isFixedHint && !isBlankGap ? theme.colorScheme.primary : getTextColor(),
                  fontWeight: isFixedHint && !isBlankGap ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
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
            ],
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons() {
    final theme = Theme.of(context);
    if (_answerState == SpellingAnswerState.none) {
      final canUseHint =
          _textController.text.replaceAll(RegExp(r'[\s\-_]'), '').isEmpty &&
          _firstRevealableSpellingChar() != null;
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: canUseHint ? _applyFirstLetterHint : null,
                icon: const Icon(CupertinoIcons.lightbulb, size: 18),
                label: const Text('힌트'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _textController.text.isNotEmpty ? _checkAnswer : null,
                icon: const Icon(CupertinoIcons.check_mark, size: 18),
                label: const Text('정답 확인'),
              ),
            ),
          ),
        ],
      );
    } else if (_answerState == SpellingAnswerState.incorrect) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _retryQuestion,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(CupertinoIcons.refresh, size: 18),
                label: const Text('재도전'),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed: _showCorrectAnswer,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentCoral,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(CupertinoIcons.eye_fill, size: 18),
                label: const Text('정답 보기'),
              ),
            ),
          ),
        ],
      );
    } else {
      return const SizedBox(height: 50);
    }
  }
}

class _SpellingQuizResultScreen extends StatelessWidget {
  final List<SpellingQuizResult> results;
  final LearningRouteOrigin origin;
  final VoidCallback onRestart;
  final VoidCallback onRetryWeakWords;
  final VoidCallback onFinish;

  const _SpellingQuizResultScreen({
    required this.results,
    required this.origin,
    required this.onRestart,
    required this.onRetryWeakWords,
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
    final hasWeakWords = incorrect > 0 || skipped > 0;
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onFinish();
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text('퀴즈 결과'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back),
          onPressed: onFinish,
        ),
      ),
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
                    Divider(color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.2)),
                    _buildStatRow('정답율', '$accuracyRate%', theme, isHighlight: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildMomentumCard(
              theme: theme,
              hasWeakWords: hasWeakWords,
              firstTryCorrect: firstTryCorrect,
              weakCount: incorrect + skipped,
            ),
            const SizedBox(height: 20),
            _buildRoutineBridgeCard(
              context: context,
              theme: theme,
              hasWeakWords: hasWeakWords,
              weakCount: incorrect + skipped,
              onRestart: onRestart,
            ),
            const SizedBox(height: 20),
            _buildNextActionCard(
              context: context,
              theme: theme,
              hasWeakWords: hasWeakWords,
              weakCount: incorrect + skipped,
              onRetryWeakWords: onRetryWeakWords,
              onRestart: onRestart,
              onFinish: onFinish,
            ),
            const SizedBox(height: 20),
            GlassmorphicCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '상세 결과',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 15),
                    ...results.map((result) => _buildResultItem(result, theme)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildMomentumCard({
    required ThemeData theme,
    required bool hasWeakWords,
    required int firstTryCorrect,
    required int weakCount,
  }) {
    final accentColor = hasWeakWords ? AppTheme.accentCoral : AppTheme.primaryGreen;
    final icon = hasWeakWords ? CupertinoIcons.flame_fill : CupertinoIcons.check_mark_circled_solid;
    final title = hasWeakWords ? '약한 단어가 선명해졌어요' : '기억이 안정권에 들어왔어요';
    final message =
        hasWeakWords
            ? '헷갈린 단어 $weakCount개가 오늘 복습 큐에 다시 들어갑니다. 지금 이어서 한 번 더 보면 정착 속도가 빨라집니다.'
            : '첫 시도에 맞힌 단어가 $firstTryCorrect개입니다. 오늘 학습 흐름을 잘 따라왔고, 이제 새 단어를 넣기 좋은 상태입니다.';

    return GlassmorphicCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accentColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(message, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextActionCard({
    required BuildContext context,
    required ThemeData theme,
    required bool hasWeakWords,
    required int weakCount,
    required VoidCallback onRetryWeakWords,
    required VoidCallback onRestart,
    required VoidCallback onFinish,
  }) {
    final retryAccentColor = hasWeakWords ? AppTheme.accentCoral : AppTheme.primaryGreen;
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasWeakWords ? CupertinoIcons.flame_fill : CupertinoIcons.check_mark_circled_solid,
                color: retryAccentColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasWeakWords ? '흔들린 단어를 다시 잡아볼까요?' : '이번 세트는 안정적입니다',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasWeakWords
                ? '틀리거나 스킵한 $weakCount개는 오늘 복습 큐에 남습니다.'
                : '오늘 흐름을 마치거나 같은 묶음을 다시 섞어볼 수 있습니다.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: hasWeakWords ? onRetryWeakWords : onRestart,
                  icon: Icon(
                    hasWeakWords ? CupertinoIcons.arrow_counterclockwise : CupertinoIcons.arrow_2_circlepath,
                    size: 18,
                  ),
                  label: Text(hasWeakWords ? '오답 다시' : '다시 스펠링'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onFinish,
                  child: const Text('완료'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineBridgeCard({
    required BuildContext context,
    required ThemeData theme,
    required bool hasWeakWords,
    required int weakCount,
    required VoidCallback onRestart,
  }) {
    final actionAccentColor = hasWeakWords ? AppTheme.accentCoral : AppTheme.primaryGreen;
    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: actionAccentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(CupertinoIcons.arrow_right_circle_fill, color: actionAccentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  hasWeakWords ? '다음 루틴은 카드 복습이 좋습니다' : '새 단어 카드로 이어가도 좋습니다',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasWeakWords
                ? '흔들린 단어 $weakCount개를 카드로 정리하거나, 순서를 바꿔 다시 스펠링으로 확인하세요.'
                : '스펠링 흐름이 안정적입니다. 새 단어 카드를 열거나 같은 묶음을 다시 섞어볼 수 있습니다.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    _replaceQuizWithFlashcard(
                      context,
                      hasWeakWords ? FlashcardLaunchMode.review : FlashcardLaunchMode.newWords,
                    );
                  },
                  icon: const Icon(CupertinoIcons.rectangle_stack_fill, size: 18),
                  label: Text(hasWeakWords ? '카드 복습' : '새 단어 카드'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRestart,
                  icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
                  label: const Text('다시 스펠링'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _replaceQuizWithFlashcard(BuildContext context, FlashcardLaunchMode mode) {
    final navigator = Navigator.of(context);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => FlashcardScreen(
                initialMode: mode,
                origin: origin,
              ),
        ),
      );
    });
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
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
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
                if (result.word.additionalMeanings.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '추가 뜻 · ${result.word.additionalMeanings.join(' · ')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
