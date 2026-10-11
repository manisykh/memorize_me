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
import '../providers/wordbook_manager.dart';
import '../services/srs_service.dart';
import '../services/analytics_service.dart';
import '../services/test_sheet_service.dart';
import '../services/study_sound_service.dart';
import '../services/study_history_service.dart';
import '../services/study_schedule_service.dart';
import '../themes/app_theme.dart';
import '../themes/memorize_identity.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_dialog.dart';
import 'flashcard_screen.dart';
import 'add_edit_word_screen.dart';
import 'mistake_review_screen.dart';
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
  final Word selectedAnswer;
  final bool isCorrect;
  McqQuizResult({
    required this.questionWord,
    required this.selectedAnswer,
    required this.isCorrect,
  });
}

class SpellingQuizResult {
  final Word word;
  final bool isCorrectOnFirstTry;
  final bool isCorrectOnRetry;
  final bool isSkipped;
  final String userAnswer;
  SpellingQuizResult({
    required this.word,
    this.isCorrectOnFirstTry = false,
    this.isCorrectOnRetry = false,
    this.isSkipped = false,
    this.userAnswer = '',
  });
}

class QuizScreen extends StatefulWidget {
  final QuizMode initialMode;
  final LearningRouteOrigin origin;
  final bool mistakeReview;
  final List<Word>? wordsOverride;

  const QuizScreen({
    super.key,
    this.initialMode = QuizMode.none,
    this.origin = LearningRouteOrigin.standalone,
    this.mistakeReview = false,
    this.wordsOverride,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Wordbook? _selectedWordbook;
  StudyPlan? _studyPlan;
  List<Word> _words = [];
  List<Word> _allWordbookWords = [];
  bool _exportWholeWordbook = true;
  List<Word> _optionPool = [];
  List<Word> _reviewWords = [];
  List<Word> _pendingMcqWords = [];
  List<Word> _pendingSpellingWords = [];
  List<Word> _reviewMcqSessionWords = [];
  List<Word> _bridgedSpellingWords = [];
  bool _isLoading = false;
  bool _isScreenLoading = true;
  late QuizMode _currentMode;
  String _selectedExportType = 'pdf';

  bool get _isDirectLaunch => widget.initialMode != QuizMode.none;

  List<Word> get _exportWords =>
      _exportWholeWordbook ? _allWordbookWords : _words;

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
    final lastUsedId = await modeStateService.getLastUsedWordbookId(
      LearningMode.quiz,
    );
    if (!mounted) return;
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
    });
    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();
    await wordbookManager.setActiveWordbook(wordbook);
    if (mounted) {
      final plan = wordbookManager.planFor(wordbook);
      final allWords = await wordbookManager.getAllWordsFrom(wordbook);
      if (!mounted) return;
      final routineWords = wordbookManager.wordsAvailableForPlan(
        allWords,
        plan: plan,
      );
      setState(() {
        _selectedWordbook = wordbook;
        _studyPlan = plan;
        _allWordbookWords = allWords;
        _words = List<Word>.from(widget.wordsOverride ?? routineWords);
        _optionPool = List<Word>.from(allWords);
        _pendingMcqWords = wordbookManager.getPendingMcqReviewWords();
        _pendingSpellingWords = wordbookManager.getPendingSpellingReviewWords();
        _reviewMcqSessionWords = List<Word>.from(
          widget.wordsOverride ?? _pendingMcqWords,
        );
        _reviewWords = List<Word>.from(
          widget.wordsOverride ?? _pendingSpellingWords,
        );
        if (_currentMode == QuizMode.reviewMultipleChoice &&
            _reviewMcqSessionWords.isEmpty) {
          _currentMode =
              _pendingSpellingWords.isEmpty
                  ? QuizMode.none
                  : QuizMode.reviewSpelling;
        }
        if (_currentMode == QuizMode.reviewSpelling && _reviewWords.isEmpty) {
          _currentMode = QuizMode.none;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('지금은 복습이 필요한 단어가 없습니다.')),
            );
          });
        }
        _isLoading = false;
      });
    }
    await modeStateService.setLastUsedWordbookId(
      LearningMode.quiz,
      wordbook.id!,
    );
  }

  void _changeMode(QuizMode newMode) {
    if (_selectedWordbook == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('먼저 학습할 단어장을 선택해주세요.')));
      return;
    }
    if ((newMode == QuizMode.spelling || newMode == QuizMode.multipleChoice) &&
        _words.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('선택된 단어장에 단어가 없습니다.')));
      return;
    }
    if (newMode == QuizMode.reviewSpelling && _reviewWords.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('지금은 복습이 필요한 단어가 없습니다.')));
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

  Future<void> _showSentenceCompletionIssues(List<Word> words) async {
    final wordbook = _selectedWordbook;
    if (wordbook == null) return;
    final issues =
        words
            .where(
              (word) =>
                  !TestSheetService.canUseSentenceCompletion(word) ||
                  TestSheetService.hasMultipleSentenceForms(word),
            )
            .toList();
    if (issues.isEmpty) return;
    final selected = await showModalBottomSheet<Word>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder:
          (sheetContext) => SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * 0.72,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '문장 완성 확인 필요 ${issues.length}개',
                        style: Theme.of(sheetContext).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: issues.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final word = issues[index];
                        final sentence = word.exampleSentence?.trim() ?? '';
                        final reason =
                            sentence.isEmpty
                                ? '예문 없음'
                                : (word.sentenceBlankAnswer
                                        ?.trim()
                                        .isNotEmpty ??
                                    false)
                                ? '지정한 빈칸 표현이 예문에 없음'
                                : !TestSheetService.canUseSentenceCompletion(
                                  word,
                                )
                                ? '원형·활용형을 예문에서 찾지 못함'
                                : '여러 형태가 나옴 · 첫 표현으로 자동 출제';
                        return ListTile(
                          title: Text(word.word),
                          subtitle: Text(
                            '$reason${sentence.isEmpty ? '' : '\n$sentence'}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: sentence.isNotEmpty,
                          trailing: const Icon(Icons.edit_outlined),
                          onTap: () => Navigator.of(sheetContext).pop(word),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    if (selected == null || !mounted) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditWordScreen(wordbook: wordbook, word: selected),
      ),
    );
    if (saved == true && mounted) await _onWordbookSelected(wordbook);
  }

  void _continueReviewSpelling() {
    final seen = <String>{};
    final combinedWords =
        <Word>[..._reviewMcqSessionWords, ..._pendingSpellingWords].where((
          word,
        ) {
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
    final exportWords = _exportWords;
    if (exportWords.isEmpty) {
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
          allWords: exportWords,
          settings: settings,
          title: exportTitle,
          share: share,
          savePath: savePath,
          openAfterSave: action == _ExportAction.open,
        );
      } else if (type == 'html') {
        await service.exportInteractiveHtml(
          allWords: exportWords,
          settings: settings,
          title: exportTitle,
          share: share,
          savePath: savePath,
          openAfterSave: action == _ExportAction.open,
        );
      } else {
        await service.exportExcel(
          exportWords,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('파일이 성공적으로 저장되었습니다.\n경로: $savePath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('작업 중 오류 발생: $e')));
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
      if (_currentMode == QuizMode.none && _bridgedSpellingWords.isEmpty) {
        _reviewWords = List<Word>.from(_pendingSpellingWords);
      }
    }
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        leading:
            _currentMode != QuizMode.none
                ? IconButton(
                  icon: const Icon(CupertinoIcons.xmark),
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
            optionPool: _optionPool,
            selectedWordbook: _selectedWordbook!,
            sessionLabel: '뜻 고르기',
            sessionHint: '의미를 빠르게 구분하며 오늘 기억을 점검하는 단계입니다.',
            origin: widget.origin,
            onContinueSpelling: () => _changeMode(QuizMode.spelling),
            onFinish: _finishActiveMode,
          ),
          QuizMode.reviewMultipleChoice => _MultipleChoiceQuizView(
            key: ValueKey('review_mcq_${_selectedWordbook?.id}'),
            words: _reviewMcqSessionWords,
            optionPool: _optionPool,
            selectedWordbook: _selectedWordbook!,
            sessionLabel: '객관식 오답 다시 확인',
            sessionHint: '객관식에서 헷갈린 단어를 같은 방식으로 먼저 확인합니다.',
            mistakeReview: true,
            origin: widget.origin,
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
                  sessionLabel:
                      _bridgedSpellingWords.isEmpty ? '주관식 오답 복습' : '주관식 확인',
                  sessionHint:
                      _bridgedSpellingWords.isEmpty
                          ? '주관식에서 틀리거나 스킵·재도전한 단어를 다시 확인합니다.'
                          : '객관식으로 확인한 단어와 남은 주관식 오답을 직접 입력해봅니다.',
                  origin: widget.origin,
                  onFinish: _finishActiveMode,
                ),
        },
      ),
    );
  }

  void _finishActiveMode() {
    if ((widget.origin == LearningRouteOrigin.home || _isDirectLaunch) &&
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
        return '객관식 퀴즈';
      case QuizMode.reviewMultipleChoice:
        return '객관식 오답';
      case QuizMode.spelling:
        return '스펠링 퀴즈';
      case QuizMode.reviewSpelling:
        return '오답/복습 퀴즈';
    }
  }

  Widget _buildModeSelectionUI(ThemeData theme) {
    final identity = MemorizeIdentity.of(theme);
    final canStartMcq = _words.isNotEmpty && _optionPool.length >= 4;
    final reviewCount =
        context.watch<WordbookManager>().quizReviewEntries().length;
    final reviewEnabled = reviewCount > 0 && _selectedWordbook != null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      children: [
        Text(
          '기억이 실제로 떠오르는지 확인해 보세요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: identity.mutedInk,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        _buildQuizWordbookRow(theme, identity),
        const SizedBox(height: 16),
        _buildQuizScopeSummary(
          theme: theme,
          identity: identity,
          reviewCount: reviewCount,
        ),
        const SizedBox(height: 26),
        _buildQuizSectionTitle(theme, identity, '테스트 방식'),
        const SizedBox(height: 10),
        _buildRecommendedReviewRow(
          theme: theme,
          identity: identity,
          enabled: reviewEnabled,
          onTap:
              reviewEnabled
                  ? () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MistakeReviewScreen(),
                      ),
                    );
                    if (mounted && _selectedWordbook != null) {
                      await _onWordbookSelected(_selectedWordbook!);
                    }
                  }
                  : null,
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _buildQuizModeRow(
                theme: theme,
                identity: identity,
                title: '객관식 퀴즈',
                description: '뜻을 빠르게 구분하며 이해도를 확인합니다.',
                countText: canStartMcq ? '${_words.length}개' : '4개 이상 필요',
                icon: CupertinoIcons.list_bullet,
                accentColor: identity.primaryAction,
                enabled: canStartMcq,
                onTap:
                    canStartMcq
                        ? () => _changeMode(QuizMode.multipleChoice)
                        : null,
              ),
              Divider(height: 1, color: identity.border),
              _buildQuizModeRow(
                theme: theme,
                identity: identity,
                title: '스펠링 퀴즈',
                description: '뜻을 보고 철자를 직접 입력합니다.',
                countText: '${_words.length}개',
                icon: CupertinoIcons.pencil,
                accentColor: identity.success,
                enabled: _words.isNotEmpty,
                onTap:
                    _words.isNotEmpty
                        ? () => _changeMode(QuizMode.spelling)
                        : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        _buildQuizSectionTitle(theme, identity, '기타 도구'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: _buildQuizModeRow(
            theme: theme,
            identity: identity,
            title: '시험지 만들기',
            description:
                kIsWeb
                    ? '웹에서는 시험지 내보내기를 지원하지 않습니다.'
                    : 'PDF · Excel · HTML로 내보냅니다.',
            countText: kIsWeb ? '웹 미지원' : '',
            icon: CupertinoIcons.doc_text,
            accentColor: const Color(0xFF7C4DFF),
            enabled: !kIsWeb,
            onTap: kIsWeb ? null : () => _changeMode(QuizMode.exportSheet),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizSectionTitle(
    ThemeData theme,
    MemorizeIdentity identity,
    String title,
  ) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        color: identity.ink,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildQuizWordbookRow(ThemeData theme, MemorizeIdentity identity) {
    final scopeLabel = _studyPlan == null ? '전체 단어' : '현재 플랜 범위';
    return Material(
      color: identity.softContext,
      borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
        onTap: () async {
          final selected = await showWordbookSelectionDialog(context);
          if (selected != null) await _onWordbookSelected(selected);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
            border: Border.all(
              color: identity.primaryAction.withValues(alpha: 0.16),
            ),
          ),
          child: Row(
            children: [
              Icon(CupertinoIcons.book, color: identity.success, size: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedWordbook?.name ?? '단어장을 선택해주세요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (_selectedWordbook != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        '$scopeLabel ${_words.length}개',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: identity.mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_forward,
                color: identity.mutedInk,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizScopeSummary({
    required ThemeData theme,
    required MemorizeIdentity identity,
    required int reviewCount,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: identity.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '테스트 범위 ',
                children: [
                  TextSpan(
                    text: '${_words.length}개',
                    style: TextStyle(color: identity.primaryAction),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(width: 1, height: 26, color: identity.border),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: '미해결 오답 ',
                children: [
                  TextSpan(
                    text: '$reviewCount개',
                    style: TextStyle(color: identity.review),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedReviewRow({
    required ThemeData theme,
    required MemorizeIdentity identity,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    final mcqCount = _pendingMcqWords.length;
    final spellingCount = _pendingSpellingWords.length;
    return Material(
      color: enabled ? identity.softReview : identity.surface,
      borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        child: Opacity(
          opacity: enabled ? 1 : 0.52,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
              border: Border.all(
                color: identity.review.withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.arrow_2_circlepath,
                  color: identity.review,
                  size: 30,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              '오답 다시 확인',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: identity.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (enabled) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: identity.review.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '먼저 추천',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: identity.review,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        enabled
                            ? '틀린 유형으로 다시 풀어 기억을 정리합니다.'
                            : '현재 다시 확인할 오답이 없습니다.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: identity.mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        enabled
                            ? '객관식 $mcqCount개 · 스펠링 $spellingCount개'
                            : '객관식 0개 · 스펠링 0개',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: identity.mutedInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_forward,
                  color: enabled ? identity.mutedInk : identity.border,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizModeRow({
    required ThemeData theme,
    required MemorizeIdentity identity,
    required String title,
    required String description,
    required String countText,
    required IconData icon,
    required Color accentColor,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  child: Icon(icon, color: accentColor, size: 28),
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
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: identity.ink,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (countText.isNotEmpty)
                            Text(
                              countText,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: accentColor,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: identity.mutedInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_forward,
                  color: identity.mutedInk,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
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

  Widget _buildExportSheetView() {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final settings = settingsNotifier.settings;
    final exportWords = _exportWords;
    final sentenceOnly =
        settings.testTypes.length == 1 &&
        settings.testTypes.contains(SelfTestType.sentenceCompletion);
    final sentenceCount =
        TestSheetService.sentenceCompletionCandidates(
          exportWords,
          repeatSharedSentences: settings.repeatSharedSentences,
        ).length;
    final maxCount =
        sentenceOnly
            ? (sentenceCount == 0 ? 1 : sentenceCount)
            : (exportWords.isEmpty ? 1 : exportWords.length);
    final selectedCount = settings.wordCount.clamp(1, maxCount).toInt();
    final testTypeMap = <SelfTestType, String>{
      SelfTestType.wordToMeaning: '단어 → 뜻',
      SelfTestType.meaningToWord: '뜻 → 단어',
      SelfTestType.sentenceCompletion: '문장 완성',
    };
    final canUseSentence = exportWords.any(
      TestSheetService.canUseSentenceCompletion,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Material(
                color: identity.softContext,
                borderRadius: BorderRadius.circular(
                  MemorizeIdentity.contextRadius,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(
                    MemorizeIdentity.contextRadius,
                  ),
                  onTap: () async {
                    final selected = await showWordbookSelectionDialog(context);
                    if (selected != null) await _onWordbookSelected(selected);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        MemorizeIdentity.contextRadius,
                      ),
                      border: Border.all(
                        color: identity.primaryAction.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.book,
                          color: identity.primaryAction,
                          size: 28,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedWordbook?.name ?? '단어장 선택',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: identity.ink,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '현재 범위 ${exportWords.length}개',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: identity.mutedInk,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          CupertinoIcons.chevron_forward,
                          color: identity.mutedInk,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '출제 $selectedCount문항 · 유형 ${settings.testTypes.length}개 · ${_exportFormatLabel(_selectedExportType)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: identity.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 26),
              _buildExportSectionLabel(theme, identity, '파일 형식'),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'pdf', label: Text('PDF')),
                    ButtonSegment(value: 'excel', label: Text('Excel')),
                    ButtonSegment(value: 'html', label: Text('HTML')),
                  ],
                  selected: {_selectedExportType},
                  onSelectionChanged:
                      (selection) =>
                          setState(() => _selectedExportType = selection.first),
                ),
              ),
              const SizedBox(height: 24),
              _buildExportSectionLabel(theme, identity, '문제 형식'),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<TestQuestionFormat>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: TestQuestionFormat.shortAnswer,
                      label: Text('주관식'),
                    ),
                    ButtonSegment(
                      value: TestQuestionFormat.multipleChoice,
                      label: Text('객관식'),
                    ),
                  ],
                  selected: {settings.questionFormat},
                  onSelectionChanged:
                      (selection) =>
                          settingsNotifier.setQuestionFormat(selection.first),
                ),
              ),
              const SizedBox(height: 24),
              _buildExportSectionLabel(theme, identity, '출제 유형'),
              const SizedBox(height: 9),
              ...testTypeMap.entries.map((entry) {
                final selected = settings.testTypes.contains(entry.key);
                final enabled =
                    entry.key != SelfTestType.sentenceCompletion ||
                    canUseSentence;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Material(
                    color: selected ? identity.softInfo : identity.surface,
                    borderRadius: BorderRadius.circular(
                      MemorizeIdentity.contextRadius,
                    ),
                    child: InkWell(
                      onTap:
                          !enabled
                              ? null
                              : () {
                                final next = Set<SelfTestType>.from(
                                  settings.testTypes,
                                );
                                if (selected) {
                                  if (next.length == 1) return;
                                  next.remove(entry.key);
                                } else {
                                  next.add(entry.key);
                                }
                                settingsNotifier.updateTestTypes(next);
                              },
                      borderRadius: BorderRadius.circular(
                        MemorizeIdentity.contextRadius,
                      ),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 54),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            MemorizeIdentity.contextRadius,
                          ),
                          border: Border.all(
                            color:
                                selected
                                    ? identity.primaryAction
                                    : identity.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? CupertinoIcons.check_mark_circled_solid
                                  : CupertinoIcons.circle,
                              color:
                                  !enabled
                                      ? identity.border
                                      : selected
                                      ? identity.primaryAction
                                      : identity.mutedInk,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.value,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color:
                                      enabled
                                          ? identity.ink
                                          : identity.mutedInk,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!enabled)
                              Text(
                                '예문 필요',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: identity.mutedInk,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 15),
              _buildExportSectionLabel(theme, identity, '문항 수'),
              const SizedBox(height: 9),
              _buildExportWordCountSelector(
                theme: theme,
                identity: identity,
                settingsNotifier: settingsNotifier,
                currentCount: selectedCount,
                maxCount: maxCount,
              ),
              const SizedBox(height: 24),
              _buildExportSectionLabel(theme, identity, '출력 구성'),
              const SizedBox(height: 9),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ExportOption>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ExportOption.both,
                      label: Text('시험지 + 답안지'),
                    ),
                    ButtonSegment(
                      value: ExportOption.testOnly,
                      label: Text('시험지만'),
                    ),
                    ButtonSegment(
                      value: ExportOption.answersOnly,
                      label: Text('답안지만'),
                    ),
                  ],
                  selected: {settings.exportOption},
                  onSelectionChanged:
                      (selection) =>
                          settingsNotifier.setExportOption(selection.first),
                ),
              ),
              const SizedBox(height: 18),
              _buildExportAdvancedSettings(
                theme: theme,
                identity: identity,
                settingsNotifier: settingsNotifier,
                settings: settings,
                sentenceCount: sentenceCount,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: identity.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed:
                    _isLoading || exportWords.isEmpty
                        ? null
                        : _showExportActionSheet,
                child:
                    _isLoading
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('시험지 생성'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportSectionLabel(
    ThemeData theme,
    MemorizeIdentity identity,
    String label,
  ) {
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        color: identity.ink,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  Widget _buildExportWordCountSelector({
    required ThemeData theme,
    required MemorizeIdentity identity,
    required SettingsNotifier settingsNotifier,
    required int currentCount,
    required int maxCount,
  }) {
    void setCount(int value) {
      settingsNotifier.setWordCount(value.clamp(1, maxCount).toInt());
    }

    final presets =
        <int>{
            10.clamp(1, maxCount).toInt(),
            20.clamp(1, maxCount).toInt(),
            maxCount,
          }.toList()
          ..sort();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton.filledTonal(
                onPressed:
                    currentCount > 1 ? () => setCount(currentCount - 1) : null,
                icon: const Icon(CupertinoIcons.minus),
              ),
              Expanded(
                child: InkWell(
                  onTap:
                      () => _showWordCountInputDialog(
                        currentCount: currentCount,
                        maxCount: maxCount,
                        settingsNotifier: settingsNotifier,
                      ),
                  child: Text(
                    '$currentCount',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                onPressed:
                    currentCount < maxCount
                        ? () => setCount(currentCount + 1)
                        : null,
                icon: const Icon(CupertinoIcons.plus),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children:
                presets
                    .map(
                      (count) => ChoiceChip(
                        selected: count == currentCount,
                        label: Text(count == maxCount ? '전체' : '$count'),
                        onSelected: (_) => setCount(count),
                      ),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExportAdvancedSettings({
    required ThemeData theme,
    required MemorizeIdentity identity,
    required SettingsNotifier settingsNotifier,
    required AppSettings settings,
    required int sentenceCount,
  }) {
    final fontLabel =
        settings.fontSize < 11
            ? '글자 크기 작게'
            : settings.fontSize > 14
            ? '글자 크기 크게'
            : '글자 크기 보통';
    return Container(
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.contextRadius),
        border: Border.all(color: identity.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: Icon(
          CupertinoIcons.slider_horizontal_3,
          color: identity.mutedInk,
        ),
        title: Text(
          '세부 설정',
          style: theme.textTheme.titleSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(fontLabel),
        children: [
          if (_studyPlan != null)
            SwitchListTile(
              title: const Text('전체 단어장에서 출제'),
              subtitle: Text(
                '전체 ${_allWordbookWords.length}개 · 현재 학습 ${_words.length}개',
              ),
              value: _exportWholeWordbook,
              onChanged:
                  (value) => setState(() => _exportWholeWordbook = value),
            ),
          if (settings.questionFormat == TestQuestionFormat.shortAnswer)
            SwitchListTile(
              title: const Text('스펠링 힌트'),
              subtitle: const Text('첫 글자와 끝 글자를 표시합니다.'),
              value: settings.includeSpellingHint,
              onChanged: settingsNotifier.setIncludeSpellingHint,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('글자 크기'),
                Expanded(
                  child: Slider(
                    value: settings.fontSize,
                    min: 8,
                    max: 20,
                    divisions: 12,
                    onChanged: settingsNotifier.setFontSize,
                  ),
                ),
                Text('${settings.fontSize.toInt()}'),
              ],
            ),
          ),
          if (settings.testTypes.contains(SelfTestType.sentenceCompletion)) ...[
            SwitchListTile(
              title: const Text('문장 완성에 해석 포함'),
              subtitle: Text('출제 가능한 예문 $sentenceCount개'),
              value: settings.includeTranslation,
              onChanged: settingsNotifier.setIncludeTranslation,
            ),
            SwitchListTile(
              title: const Text('같은 예문도 단어마다 출제'),
              value: settings.repeatSharedSentences,
              onChanged: settingsNotifier.setRepeatSharedSentences,
            ),
          ],
        ],
      ),
    );
  }

  void _showExportActionSheet() {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => SafeArea(
            top: false,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: identity.surface,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: identity.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    '생성 방법을 선택하세요',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final entry
                      in const <_ExportAction, (IconData, String)>{
                        _ExportAction.download: (
                          Icons.download_rounded,
                          '다운로드',
                        ),
                        _ExportAction.share: (Icons.share_rounded, '공유'),
                        _ExportAction.open: (
                          Icons.open_in_new_rounded,
                          '바로 보기',
                        ),
                      }.entries)
                    ListTile(
                      leading: Icon(
                        entry.value.$1,
                        color: identity.primaryAction,
                      ),
                      title: Text(entry.value.$2),
                      trailing: const Icon(
                        CupertinoIcons.chevron_forward,
                        size: 18,
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        unawaited(
                          _handleExport(
                            type: _selectedExportType,
                            action: entry.key,
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
    );
  }

  // ignore: unused_element
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
                child: Icon(
                  _exportFormatIcon(_selectedExportType),
                  color: accentColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '내보내기',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
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
    final presets = <int>{
      5,
      10,
      20,
      maxCount,
    }.where((count) => count >= 1 && count <= maxCount);

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
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.42),
              ),
            ),
            child: Row(
              children: [
                IconButton.filledTonal(
                  onPressed:
                      currentCount > 1
                          ? () => setCount(currentCount - 1)
                          : null,
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
                  onPressed:
                      currentCount < maxCount
                          ? () => setCount(currentCount + 1)
                          : null,
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
              _buildExportScopeBadge(
                theme,
                Icons.picture_as_pdf_outlined,
                'PDF',
              ),
              const SizedBox(width: 6),
              _buildExportScopeBadge(
                theme,
                Icons.table_chart_outlined,
                'Excel',
              ),
              const Spacer(),
              Text(
                '${settings.fontSize.toInt()}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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

  // ignore: unused_element
  Widget _buildLearningSettingsSection(BuildContext context) {
    final theme = Theme.of(context);
    final settingsNotifier = context.watch<SettingsNotifier>();
    final settings = settingsNotifier.settings;
    final exportWords = _exportWords;
    final sentenceOnly =
        settings.testTypes.length == 1 &&
        settings.testTypes.contains(SelfTestType.sentenceCompletion);
    final sentenceWordCount =
        TestSheetService.sentenceCompletionCandidates(
          exportWords,
          repeatSharedSentences: settings.repeatSharedSentences,
        ).length;
    final matchingSentenceCount =
        exportWords.where(TestSheetService.canUseSentenceCompletion).length;
    final duplicateSentenceCount = matchingSentenceCount - sentenceWordCount;
    final missingSentenceCount =
        exportWords
            .where((word) => word.exampleSentence?.trim().isEmpty ?? true)
            .length;
    final unmatchedSentenceWords =
        exportWords
            .where(
              (word) =>
                  (word.exampleSentence?.trim().isNotEmpty ?? false) &&
                  !TestSheetService.canUseSentenceCompletion(word),
            )
            .toList();
    final unmatchedSentenceCount = unmatchedSentenceWords.length;
    final ambiguousSentenceCount =
        exportWords.where(TestSheetService.hasMultipleSentenceForms).length;
    final missingTranslationCount =
        exportWords
            .where(
              (word) =>
                  TestSheetService.canUseSentenceCompletion(word) &&
                  (word.exampleSentenceTranslation?.trim().isEmpty ?? true),
            )
            .length;
    final int maxWordCount =
        sentenceOnly
            ? (sentenceWordCount == 0 ? 1 : sentenceWordCount)
            : (exportWords.isEmpty ? 1 : exportWords.length);
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            '분량과 문제 형식을 조절해 원하는 스타일의 시험지를 만드세요.',
            style: theme.textTheme.bodySmall,
          ),
        ),
        if (_studyPlan != null)
          SwitchListTile(
            title: Text('전체 단어장에서 출제', style: theme.textTheme.bodyLarge),
            subtitle: Text(
              '전체 ${_allWordbookWords.length}개 · 현재 학습 ${_words.length}개',
              style: theme.textTheme.bodySmall,
            ),
            value: _exportWholeWordbook,
            onChanged: (value) => setState(() => _exportWholeWordbook = value),
            contentPadding: const EdgeInsets.only(left: 16, right: 6),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            '파일 형식',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
        if (settings.questionFormat == TestQuestionFormat.multipleChoice &&
            exportWords.length < 2)
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
            onChanged:
                (value) => settingsNotifier.setIncludeSpellingHint(value),
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
        if (sentenceOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
            child: Text(
              sentenceWordCount == 0
                  ? '문장 완성 가능한 단어가 없습니다. 예문에 단어의 원형이나 활용형이 있는지 확인하세요.'
                  : '문장 완성 가능한 단어 $sentenceWordCount개 중 ${settings.wordCount.clamp(1, maxWordCount)}개를 출제합니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color:
                    sentenceWordCount == 0
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (sentenceOnly && sentenceWordCount < exportWords.length)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '제외 ${exportWords.length - sentenceWordCount}개 · 예문 없음 $missingSentenceCount개 · 원형·활용형 없음 $unmatchedSentenceCount개 · 중복 예문 $duplicateSentenceCount개${unmatchedSentenceWords.isEmpty ? '' : ' (일치 없음: ${unmatchedSentenceWords.take(3).map((word) => word.word).join(', ')}${unmatchedSentenceCount > 3 ? ' 외' : ''})'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        if (settings.testTypes.contains(SelfTestType.sentenceCompletion) &&
            (missingSentenceCount +
                    unmatchedSentenceCount +
                    ambiguousSentenceCount) >
                0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: OutlinedButton.icon(
              onPressed: () => _showSentenceCompletionIssues(exportWords),
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: Text(
                '예문 확인 (${missingSentenceCount + unmatchedSentenceCount + ambiguousSentenceCount})',
              ),
            ),
          ),
        if (sentenceOnly &&
            settings.includeTranslation &&
            missingTranslationCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              '해석이 없는 예문 $missingTranslationCount개도 문장 완성으로 출제하고, 해석만 생략합니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
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
          subtitle: Text(
            '해석이 없는 예문은 해석 없이 출제됩니다.',
            style: theme.textTheme.bodySmall,
          ),
          value: settings.includeTranslation,
          onChanged: (value) => settingsNotifier.setIncludeTranslation(value),
          contentPadding: const EdgeInsets.only(left: 16.0, right: 6.0),
        ),
        if (settings.testTypes.contains(SelfTestType.sentenceCompletion))
          SwitchListTile(
            title: Text('같은 예문도 단어마다 출제', style: theme.textTheme.bodyLarge),
            subtitle: Text(
              '끄면 동일한 예문은 한 문제만 출제합니다.',
              style: theme.textTheme.bodySmall,
            ),
            value: settings.repeatSharedSentences,
            onChanged: settingsNotifier.setRepeatSharedSentences,
            contentPadding: const EdgeInsets.only(left: 16, right: 6),
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

  void _showTestTypePicker(
    BuildContext context,
    Map<SelfTestType, String> testTypeMap,
  ) {
    final settingsNotifier = context.read<SettingsNotifier>();
    final tempSelectedTypes = Set<SelfTestType>.from(
      settingsNotifier.settings.testTypes,
    );
    final canDoSentenceCompletion = _exportWords.any(
      TestSheetService.canUseSentenceCompletion,
    );
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
                      child: Text(
                        '시험 유형 선택 (복수 가능)',
                        style: Theme.of(ctx).textTheme.titleLarge,
                      ),
                    ),
                    ...testTypeMap.entries.map((entry) {
                      if (entry.key == SelfTestType.sentenceCompletion) {
                        return CheckboxListTile(
                          title: Text(
                            entry.value,
                            style: Theme.of(ctx).textTheme.bodyLarge,
                          ),
                          subtitle:
                              !canDoSentenceCompletion
                                  ? Text(
                                    '출제 가능한 예문이 없습니다. 예문에 단어의 원형이나 활용형이 있어야 합니다.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(ctx).disabledColor,
                                    ),
                                  )
                                  : null,
                          value: tempSelectedTypes.contains(entry.key),
                          onChanged:
                              !canDoSentenceCompletion &&
                                      !tempSelectedTypes.contains(entry.key)
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
                        title: Text(
                          entry.value,
                          style: Theme.of(ctx).textTheme.bodyLarge,
                        ),
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
                        title: Text(
                          entry.value,
                          style: Theme.of(ctx).textTheme.bodyLarge,
                        ),
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
  final LearningRouteOrigin origin;
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
    this.origin = LearningRouteOrigin.standalone,
    required this.onContinueSpelling,
    required this.onFinish,
  });

  @override
  State<_MultipleChoiceQuizView> createState() =>
      _MultipleChoiceQuizViewState();
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
  bool _hasRecordedHistory = false;
  StudySessionRecorder? _historyRecorder;

  void _startHistory() {
    _sessionWords = _wordbookManager.latestStudyWords(
      widget.selectedWordbook.dbFileName,
      _sessionWords,
    );
    _historyRecorder = StudyHistoryService.instance.start(
      wordbook: widget.selectedWordbook,
      mode: StudyHistoryMode.multipleChoice,
      expectedCount: _sessionWords.length,
      plan: _wordbookManager.planForSession(
        widget.selectedWordbook,
        _sessionWords,
      ),
    );
  }

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
      _hasRecordedHistory = false;
      _sessionWords =
          (List<Word>.from(widget.words)..shuffle()).take(wordCount).toList();
      _prepareQuestion();
    });
    context.read<AnalyticsService>().logStudyStarted(
      mode: 'multiple_choice',
      wordCount: _sessionWords.length,
    );
    _startHistory();
  }

  void _prepareQuestion() {
    if (_sessionWords.isEmpty) return;
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
    final updatedWord = _srsService.updateQuizSrs(
      word: currentWord,
      spelling: false,
      cleanCorrect: isCorrect,
    );
    _historyRecorder?.answer(
      currentWord,
      success: isCorrect,
      userAnswer: _selectedOption!.meaning,
      nextReviewDate: updatedWord.nextReviewDate,
    );
    unawaited(
      _wordbookManager.queueWordsSrsData(widget.selectedWordbook.dbFileName, [
        updatedWord,
      ]),
    );
    setState(() {
      _isAnswered = true;
      _results.add(
        McqQuizResult(
          questionWord: currentWord,
          selectedAnswer: _selectedOption!,
          isCorrect: isCorrect,
        ),
      );
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
        _results
            .where((result) => !result.isCorrect)
            .map((result) => result.questionWord)
            .toList();
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
      _hasRecordedHistory = false;
      _sessionWords = List<Word>.from(uniqueWords)..shuffle();
      _prepareQuestion();
    });
    _startHistory();
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
    if (!_hasRecordedHistory && _results.isNotEmpty) {
      _hasRecordedHistory = true;
      _historyRecorder?.complete();
    }
    context.read<AnalyticsService>().logQuizCompleted(
      mode: 'multiple_choice',
      questionCount: _results.length,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => _McqQuizResultScreen(
              results: _results,
              origin: widget.origin,
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
    if (widget.optionPool.length < 4) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '객관식 보기를 만들려면 단어장에 단어가 4개 이상 필요합니다. 카드나 주관식으로 복습해주세요.',
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: widget.onFinish,
                child: const Text('돌아가기'),
              ),
            ],
          ),
        ),
      );
    }
    final currentWord = _sessionWords[_currentIndex];
    final identity = MemorizeIdentity.of(theme);
    final correctCount = _results.where((result) => result.isCorrect).length;
    final incorrectCount = _results.length - correctCount;
    final correctPulse = _scorePulse == _McqScorePulse.correct;
    final incorrectPulse = _scorePulse == _McqScorePulse.incorrect;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuizSessionHeader(
                  contextLabel: widget.selectedWordbook.name,
                  accentColor: identity.primaryAction,
                  currentIndex: _currentIndex,
                  totalCount: _sessionWords.length,
                  correctCount: correctCount,
                  incorrectCount: incorrectCount,
                  pulseAnimation: _scorePulseController,
                  correctPulsing: correctPulse,
                  incorrectPulsing: incorrectPulse,
                  correctPulseColor: identity.success,
                  correctPulseIcon: CupertinoIcons.checkmark_seal_fill,
                  incorrectPulseIcon:
                      CupertinoIcons.exclamationmark_triangle_fill,
                ),
                const SizedBox(height: 28),
                Text(
                  '다음 단어의 뜻으로 알맞은 것을 선택하세요.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  currentWord.word,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 36,
                    letterSpacing: -0.6,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 26),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _currentOptions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final option = _currentOptions[index];
                    final isCorrect = option.id == currentWord.id;
                    final isSelected = option.id == _selectedOption?.id;
                    final borderColor =
                        !_isAnswered
                            ? isSelected
                                ? identity.primaryAction
                                : identity.border
                            : isCorrect
                            ? identity.success
                            : isSelected
                            ? identity.review
                            : identity.border;
                    final letter = String.fromCharCode(65 + index);
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      constraints: const BoxConstraints(minHeight: 62),
                      decoration: BoxDecoration(
                        color: _getOptionColor(option, currentWord, context),
                        borderRadius: BorderRadius.circular(
                          MemorizeIdentity.cardRadius,
                        ),
                        border: Border.all(color: borderColor),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _onOptionSelected(option),
                          borderRadius: BorderRadius.circular(
                            MemorizeIdentity.cardRadius,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color:
                                        isSelected
                                            ? identity.primaryAction
                                            : identity.softInfo,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    letter,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      color:
                                          isSelected
                                              ? Colors.white
                                              : identity.primaryAction,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Text(
                                    option.meaning,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: identity.ink,
                                      fontWeight: FontWeight.w700,
                                      height: 1.18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          decoration: BoxDecoration(
            color: identity.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: FilledButton(
                onPressed:
                    _selectedOption != null && !_isAnswered
                        ? _nextQuestion
                        : null,
                child: const Text('정답 확인'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
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
                progress <= 0.35 ? progress / 0.35 : (1 - progress) / 0.65;
            final intensity =
                isPulsing ? rawIntensity.clamp(0.0, 1.0).toDouble() : 0.0;
            return Transform.scale(
              scale: 1 + (0.10 * intensity),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
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
          pulseIcon: CupertinoIcons.checkmark_seal_fill,
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
  final String contextLabel;
  final Color accentColor;
  final int currentIndex;
  final int totalCount;
  final int correctCount;
  final int incorrectCount;
  final Animation<double> pulseAnimation;
  final bool correctPulsing;
  final bool incorrectPulsing;
  final Color correctPulseColor;
  final IconData? correctPulseIcon;
  final IconData? incorrectPulseIcon;
  final bool compact;

  const _QuizSessionHeader({
    required this.contextLabel,
    required this.accentColor,
    required this.currentIndex,
    required this.totalCount,
    required this.correctCount,
    required this.incorrectCount,
    required this.pulseAnimation,
    required this.correctPulsing,
    required this.incorrectPulsing,
    required this.correctPulseColor,
    this.correctPulseIcon,
    this.incorrectPulseIcon,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayIndex =
        totalCount == 0 ? 0 : currentIndex.clamp(0, totalCount - 1) + 1;
    final progress = totalCount == 0 ? 0.0 : displayIndex / totalCount;
    final identity = MemorizeIdentity.of(theme);
    final answeredCount = correctCount + incorrectCount;
    final correctRatio =
        answeredCount == 0 ? 0 : ((correctCount / answeredCount) * 100).round();
    final incorrectRatio =
        answeredCount == 0
            ? 0
            : ((incorrectCount / answeredCount) * 100).round();
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 10 : 14,
        16,
        compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  contextLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$displayIndex / $totalCount',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: identity.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 8 : 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: compact ? 6 : 8,
              color: accentColor,
              backgroundColor: accentColor.withValues(alpha: 0.12),
            ),
          ),
          SizedBox(height: compact ? 9 : 12),
          Divider(height: 1, color: identity.border),
          SizedBox(height: compact ? 8 : 11),
          Row(
            children: [
              Expanded(
                child: _buildScore(
                  context: context,
                  label: '맞음',
                  value: correctCount,
                  ratio: correctRatio,
                  color: identity.success,
                  icon: CupertinoIcons.check_mark_circled_solid,
                  pulsing: correctPulsing,
                  pulseColor: correctPulseColor,
                  pulseIcon: correctPulseIcon,
                ),
              ),
              Container(width: 1, height: 30, color: identity.border),
              Expanded(
                child: _buildScore(
                  context: context,
                  label: '틀림',
                  value: incorrectCount,
                  ratio: incorrectRatio,
                  color: identity.review,
                  icon: CupertinoIcons.xmark_circle_fill,
                  pulsing: incorrectPulsing,
                  pulseColor: identity.review,
                  pulseIcon: incorrectPulseIcon,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScore({
    required BuildContext context,
    required String label,
    required int value,
    required int ratio,
    required Color color,
    required IconData icon,
    required bool pulsing,
    required Color pulseColor,
    IconData? pulseIcon,
  }) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: pulseAnimation,
      builder: (context, child) {
        final progress = pulseAnimation.value;
        final raw = progress <= 0.35 ? progress / 0.35 : (1 - progress) / 0.65;
        final intensity = pulsing ? raw.clamp(0.0, 1.0).toDouble() : 0.0;
        final displayColor = pulsing ? pulseColor : color;
        final displayIcon = pulsing && pulseIcon != null ? pulseIcon : icon;
        return Transform.scale(
          scale: 1 + (0.12 * intensity),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                transitionBuilder:
                    (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                child: Icon(
                  displayIcon,
                  key: ValueKey<IconData>(displayIcon),
                  size: 18,
                  color: displayColor,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '$label $value · $ratio%',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: displayColor,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _McqQuizResultScreen extends StatelessWidget {
  final List<McqQuizResult> results;
  final LearningRouteOrigin origin;
  final VoidCallback onRestart;
  final VoidCallback onContinueSpelling;
  final VoidCallback onFinish;
  final bool mistakeReview;

  const _McqQuizResultScreen({
    required this.results,
    required this.origin,
    required this.onRestart,
    required this.onContinueSpelling,
    required this.onFinish,
    this.mistakeReview = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final totalQuestions = results.length;
    final correctAnswers = results.where((r) => r.isCorrect).length;
    final incorrectAnswers = totalQuestions - correctAnswers;
    final accuracyRate =
        totalQuestions > 0
            ? (correctAnswers / totalQuestions * 100).round()
            : 0;
    final hasIncorrect = incorrectAnswers > 0;
    final incorrectResults =
        results.where((result) => !result.isCorrect).toList();
    final correctResults = results.where((result) => result.isCorrect).toList();
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onFinish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('퀴즈 결과'),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: onFinish,
          ),
          actions: [
            IconButton(
              tooltip: '닫기',
              onPressed: onFinish,
              icon: const Icon(CupertinoIcons.xmark),
            ),
            const SizedBox(width: 4),
          ],
        ),
        backgroundColor: identity.canvas,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuizResultHero(
                  percentage: accuracyRate,
                  percentageLabel: '정답률',
                  headline: '$totalQuestions문제 중 $correctAnswers개 정답',
                  metrics: [
                    _QuizResultMetric(
                      label: '맞음',
                      value: correctAnswers,
                      color: identity.primaryAction,
                      icon: CupertinoIcons.check_mark_circled_solid,
                    ),
                    _QuizResultMetric(
                      label: '틀림',
                      value: incorrectAnswers,
                      color: identity.review,
                      icon: CupertinoIcons.xmark_circle_fill,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _QuizResultActions(
                  title: hasIncorrect ? '틀린 문제부터 다시 확인해요' : '다음 학습을 선택하세요',
                  description:
                      hasIncorrect
                          ? '오답 $incorrectAnswers개는 오늘 복습에 반영됐어요.'
                          : '모든 문제를 맞혔어요. 스펠링으로 기억을 한 번 더 확인할 수 있어요.',
                  actions: [
                    if (hasIncorrect)
                      _QuizResultAction(
                        label: '오답 $incorrectAnswers개 다시',
                        icon: CupertinoIcons.arrow_counterclockwise,
                        onPressed: onRestart,
                        emphasized: true,
                      )
                    else
                      _QuizResultAction(
                        label: '객관식 다시',
                        icon: CupertinoIcons.arrow_2_circlepath,
                        onPressed: onRestart,
                      ),
                    _QuizResultAction(
                      label: '플래시카드 학습',
                      icon: CupertinoIcons.rectangle_stack_fill,
                      onPressed: () => _replaceQuizWithFlashcard(context),
                    ),
                    if (!(mistakeReview && hasIncorrect))
                      _QuizResultAction(
                        label: '스펠링 문제',
                        icon: CupertinoIcons.pencil,
                        onPressed: onContinueSpelling,
                      ),
                  ],
                ),
                if (incorrectResults.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _QuizResultSection(
                    title: '틀린 문제',
                    count: incorrectResults.length,
                    color: identity.review,
                    icon: CupertinoIcons.xmark_circle_fill,
                    children:
                        incorrectResults
                            .map((result) => _buildResultItem(result, theme))
                            .toList(),
                  ),
                ],
                if (correctResults.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _QuizResultSection(
                    title: '맞은 문제',
                    count: correctResults.length,
                    color: identity.primaryAction,
                    icon: CupertinoIcons.check_mark_circled_solid,
                    children:
                        correctResults
                            .map((result) => _buildResultItem(result, theme))
                            .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: onFinish,
                    child: const Text('완료'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultItem(McqQuizResult result, ThemeData theme) {
    final identity = MemorizeIdentity.of(theme);
    return _QuizResultWordRow(
      title: result.questionWord.word,
      subtitle:
          result.questionWord.additionalMeanings.isEmpty
              ? null
              : result.questionWord.additionalMeanings.join(' · '),
      statusLabel: result.isCorrect ? '정답' : '오답',
      statusColor: result.isCorrect ? identity.primaryAction : identity.review,
      correctLabel: '정답',
      correctValue: result.questionWord.meaning,
      answerLabel: result.isCorrect ? null : '내 답',
      answerValue: result.isCorrect ? null : result.selectedAnswer.meaning,
    );
  }

  void _replaceQuizWithFlashcard(BuildContext context) {
    final navigator = Navigator.of(context);
    final words = results.map((result) => result.questionWord).toList();
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => FlashcardScreen(
                initialMode: FlashcardLaunchMode.allWords,
                origin: origin,
                reviewWordsOverride: words,
              ),
        ),
      );
    });
  }
}

class _QuizResultMetric {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _QuizResultMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _QuizResultHero extends StatelessWidget {
  final int percentage;
  final String percentageLabel;
  final String headline;
  final List<_QuizResultMetric> metrics;

  const _QuizResultHero({
    required this.percentage,
    required this.percentageLabel,
    required this.headline,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final progress = (percentage / 100).clamp(0.0, 1.0).toDouble();

    final ring = SizedBox.square(
      dimension: 126,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.square(
            dimension: 116,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 9,
              strokeCap: StrokeCap.round,
              color: identity.primaryAction,
              backgroundColor: identity.border.withValues(alpha: 0.72),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$percentage%',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: identity.primaryAction,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                percentageLabel,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: identity.mutedInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: theme.textTheme.titleLarge?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: identity.surface,
            borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
            border: Border.all(color: identity.border),
          ),
          child: Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                if (index > 0)
                  Container(width: 1, height: 54, color: identity.border),
                Expanded(child: _QuizResultMetricView(metric: metrics[index])),
              ],
            ],
          ),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 350) {
          return Column(
            children: [
              ring,
              const SizedBox(height: 18),
              Align(alignment: Alignment.centerLeft, child: summary),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [ring, const SizedBox(width: 18), Expanded(child: summary)],
        );
      },
    );
  }
}

class _QuizResultMetricView extends StatelessWidget {
  final _QuizResultMetric metric;

  const _QuizResultMetricView({required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(metric.icon, size: 16, color: metric.color),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: metric.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${metric.value}',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: metric.color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizResultSection extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final List<Widget> children;

  const _QuizResultSection({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 13),
            child: Row(
              children: [
                Icon(icon, color: color, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$count개',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: identity.mutedInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          for (var index = 0; index < children.length; index++) ...[
            Divider(height: 1, color: identity.border),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _QuizResultWordRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String statusLabel;
  final Color statusColor;
  final String correctLabel;
  final String correctValue;
  final String? answerLabel;
  final String? answerValue;

  const _QuizResultWordRow({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.statusColor,
    required this.correctLabel,
    required this.correctValue,
    required this.answerLabel,
    required this.answerValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: identity.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: identity.mutedInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuizResultValueChip(
                label: correctLabel,
                value: correctValue,
                color: identity.primaryAction,
              ),
              if (answerLabel != null && answerValue != null)
                _QuizResultValueChip(
                  label: answerLabel!,
                  value: answerValue!.isEmpty ? '입력 없음' : answerValue!,
                  color: identity.review,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuizResultValueChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _QuizResultValueChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodyMedium,
          children: [
            TextSpan(
              text: '$label  ',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text: value,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizResultAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  const _QuizResultAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });
}

class _QuizResultActions extends StatelessWidget {
  final String title;
  final String description;
  final List<_QuizResultAction> actions;

  const _QuizResultActions({
    required this.title,
    required this.description,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Container(
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: identity.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: identity.mutedInk,
                  ),
                ),
              ],
            ),
          ),
          for (final action in actions) ...[
            Divider(height: 1, color: identity.border),
            ListTile(
              minTileHeight: 58,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      action.emphasized
                          ? identity.softReview
                          : identity.softInfo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  action.icon,
                  size: 19,
                  color:
                      action.emphasized
                          ? identity.review
                          : identity.primaryAction,
                ),
              ),
              title: Text(
                action.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: identity.ink,
                  fontWeight: FontWeight.w800,
                ),
              ),
              trailing: Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: identity.primaryAction,
              ),
              onTap: action.onPressed,
            ),
          ],
        ],
      ),
    );
  }
}

class QuizHistoryScreen extends StatefulWidget {
  final Wordbook wordbook;
  final StudyHistoryMode initialMode;

  const QuizHistoryScreen({
    super.key,
    required this.wordbook,
    this.initialMode = StudyHistoryMode.multipleChoice,
  });

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> {
  late StudyHistoryMode _mode;

  @override
  void initState() {
    super.initState();
    _mode =
        widget.initialMode == StudyHistoryMode.flashcard
            ? StudyHistoryMode.multipleChoice
            : widget.initialMode;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final service = StudyHistoryService.instance;
    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: const Text('테스트 결과')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: service,
          builder: (context, _) {
            return FutureBuilder<List<StudySessionRecord>>(
              future: service.completedQuizSessions(
                widget.wordbook.dbFileName,
                mode: _mode,
              ),
              builder: (context, snapshot) {
                final sessions = snapshot.data ?? const <StudySessionRecord>[];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: identity.softContext,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.book,
                                  color: identity.success,
                                  size: 21,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.wordbook.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      color: identity.ink,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                Text(
                                  '최근 10회',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: identity.mutedInk,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _QuizHistoryModeSelector(
                            selected: _mode,
                            identity: identity,
                            onChanged: (mode) => setState(() => _mode = mode),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child:
                          snapshot.connectionState == ConnectionState.waiting
                              ? const Center(child: CircularProgressIndicator())
                              : sessions.isEmpty
                              ? _QuizHistoryEmptyState(mode: _mode)
                              : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  2,
                                  20,
                                  28,
                                ),
                                itemCount: sessions.length,
                                separatorBuilder:
                                    (_, _) => const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final session = sessions[index];
                                  return _QuizHistorySessionCard(
                                    session: session,
                                    identity: identity,
                                    onTap:
                                        () => Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder:
                                                (_) => QuizHistoryDetailScreen(
                                                  wordbook: widget.wordbook,
                                                  session: session,
                                                ),
                                          ),
                                        ),
                                  );
                                },
                              ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _QuizHistoryModeSelector extends StatelessWidget {
  final StudyHistoryMode selected;
  final MemorizeIdentity identity;
  final ValueChanged<StudyHistoryMode> onChanged;

  const _QuizHistoryModeSelector({
    required this.selected,
    required this.identity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: identity.softInfo,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _item(context, StudyHistoryMode.multipleChoice, '객관식'),
          _item(context, StudyHistoryMode.spelling, '스펠링'),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, StudyHistoryMode mode, String label) {
    final isSelected = selected == mode;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(mode),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? identity.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow:
                isSelected
                    ? [
                      BoxShadow(
                        color: identity.primaryAction.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                    : null,
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: isSelected ? identity.primaryAction : identity.mutedInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizHistorySessionCard extends StatelessWidget {
  final StudySessionRecord session;
  final MemorizeIdentity identity;
  final VoidCallback onTap;

  const _QuizHistorySessionCard({
    required this.session,
    required this.identity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final completedAt = session.completedAt ?? session.startedAt;
    final correct =
        session.mode == StudyHistoryMode.spelling
            ? session.answers.where(_isFirstTrySpellingCorrect).length
            : session.successCount;
    final weak = session.answers.length - correct;
    final hasDetailedAnswers = session.answers.any(
      (answer) => answer.meaning != null,
    );
    final scope =
        session.planMode == StudyPlanMode.free && session.bundle != null
            ? '${session.bundle}번 묶음'
            : session.planMode == null
            ? '전체 단어장'
            : '학습 계획';

    return Material(
      color: identity.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        side: BorderSide(color: identity.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 13, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  session.mode == StudyHistoryMode.multipleChoice
                      ? CupertinoIcons.list_bullet
                      : CupertinoIcons.pencil,
                  color: const Color(0xFFE77B12),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.mode.label,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: identity.ink,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!hasDetailedAnswers)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: identity.softInfo,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '요약만',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: identity.mutedInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('yyyy.MM.dd HH:mm').format(completedAt)} · $scope',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '정답 $correct',
                            style: TextStyle(color: identity.primaryAction),
                          ),
                          TextSpan(
                            text: ' · ',
                            style: TextStyle(color: identity.mutedInk),
                          ),
                          TextSpan(
                            text: '오답 $weak',
                            style: TextStyle(color: identity.review),
                          ),
                        ],
                      ),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: identity.mutedInk,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuizHistoryEmptyState extends StatelessWidget {
  final StudyHistoryMode mode;

  const _QuizHistoryEmptyState({required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: identity.softInfo,
                shape: BoxShape.circle,
              ),
              child: Icon(
                CupertinoIcons.doc_text_search,
                color: identity.primaryAction,
                size: 27,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '아직 ${mode == StudyHistoryMode.multipleChoice ? '객관식' : '스펠링'} 결과가 없어요',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: identity.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '테스트를 완료하면 최근 결과를 다시 확인할 수 있어요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: identity.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizHistoryDetailScreen extends StatelessWidget {
  final Wordbook wordbook;
  final StudySessionRecord session;

  const QuizHistoryDetailScreen({
    super.key,
    required this.wordbook,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final isSpelling = session.mode == StudyHistoryMode.spelling;
    final correctAnswers =
        isSpelling
            ? session.answers.where(_isFirstTrySpellingCorrect).toList()
            : session.answers.where((answer) => answer.success).toList();
    final weakAnswers =
        isSpelling
            ? session.answers
                .where((answer) => !_isFirstTrySpellingCorrect(answer))
                .toList()
            : session.answers.where((answer) => !answer.success).toList();
    final percentage =
        session.answers.isEmpty
            ? 0
            : (correctAnswers.length / session.answers.length * 100).round();
    final hasDetailedAnswers = session.answers.any(
      (answer) => answer.meaning != null,
    );

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(title: const Text('테스트 결과')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuizResultHero(
                percentage: percentage,
                percentageLabel: isSpelling ? '한 번에 정답률' : '정답률',
                headline:
                    '${session.answers.length}문제 중 ${correctAnswers.length}개 ${isSpelling ? '한 번에 ' : ''}정답',
                metrics: [
                  _QuizResultMetric(
                    label: isSpelling ? '한 번에' : '맞음',
                    value: correctAnswers.length,
                    color: identity.primaryAction,
                    icon: CupertinoIcons.check_mark_circled_solid,
                  ),
                  _QuizResultMetric(
                    label: isSpelling ? '다시 확인' : '틀림',
                    value: weakAnswers.length,
                    color: identity.review,
                    icon:
                        isSpelling
                            ? CupertinoIcons.arrow_counterclockwise_circle_fill
                            : CupertinoIcons.xmark_circle_fill,
                  ),
                ],
              ),
              const SizedBox(height: 22),
              _QuizResultActions(
                title:
                    weakAnswers.isNotEmpty
                        ? '틀린 문제부터 다시 확인해요'
                        : '학습을 한 번 더 이어가세요',
                description:
                    weakAnswers.isNotEmpty
                        ? '이 결과의 오답 ${weakAnswers.length}개를 다시 학습할 수 있어요.'
                        : '이 결과의 전체 단어를 다시 확인할 수 있어요.',
                actions: [
                  if (weakAnswers.isNotEmpty)
                    _QuizResultAction(
                      label: '오답 ${weakAnswers.length}개 다시',
                      icon: CupertinoIcons.arrow_counterclockwise,
                      emphasized: true,
                      onPressed:
                          () => _openQuiz(context, weakAnswers, review: true),
                    ),
                  _QuizResultAction(
                    label: '전체 다시 풀기',
                    icon: CupertinoIcons.arrow_2_circlepath,
                    onPressed: () => _openQuiz(context, session.answers),
                  ),
                  if (!isSpelling)
                    _QuizResultAction(
                      label: '플래시카드 학습',
                      icon: CupertinoIcons.rectangle_stack_fill,
                      onPressed:
                          () => _openFlashcards(context, session.answers),
                    ),
                ],
              ),
              if (!hasDetailedAnswers) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: identity.softInfo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '이전 기록은 점수와 문제 목록만 저장되어 있어요. 새 테스트부터 정답과 내 답을 함께 보여드려요.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: identity.mutedInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              if (weakAnswers.isNotEmpty) ...[
                const SizedBox(height: 22),
                _QuizResultSection(
                  title: isSpelling ? '다시 볼 문제' : '틀린 문제',
                  count: weakAnswers.length,
                  color: identity.review,
                  icon:
                      isSpelling
                          ? CupertinoIcons.arrow_counterclockwise_circle_fill
                          : CupertinoIcons.xmark_circle_fill,
                  children:
                      weakAnswers
                          .map(
                            (answer) => _buildHistoryResultItem(answer, theme),
                          )
                          .toList(),
                ),
              ],
              if (correctAnswers.isNotEmpty) ...[
                const SizedBox(height: 22),
                _QuizResultSection(
                  title: '맞은 문제',
                  count: correctAnswers.length,
                  color: identity.primaryAction,
                  icon: CupertinoIcons.check_mark_circled_solid,
                  children:
                      correctAnswers
                          .map(
                            (answer) => _buildHistoryResultItem(answer, theme),
                          )
                          .toList(),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('완료'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryResultItem(StudyAnswerRecord answer, ThemeData theme) {
    final identity = MemorizeIdentity.of(theme);
    final isSpelling = session.mode == StudyHistoryMode.spelling;
    final firstTryCorrect = isSpelling && _isFirstTrySpellingCorrect(answer);
    final isWeak = isSpelling ? !firstTryCorrect : !answer.success;
    final statusLabel =
        isSpelling
            ? firstTryCorrect
                ? '한 번에 정답'
                : answer.success
                ? '재도전 성공'
                : '틀림/스킵'
            : answer.success
            ? '정답'
            : '오답';
    final statusColor =
        !isWeak
            ? identity.primaryAction
            : isSpelling && answer.success
            ? const Color(0xFFE77B12)
            : identity.review;
    return _QuizResultWordRow(
      title: isSpelling ? (answer.meaning ?? answer.word) : answer.word,
      subtitle:
          answer.additionalMeanings.isEmpty
              ? null
              : answer.additionalMeanings.join(' · '),
      statusLabel: statusLabel,
      statusColor: statusColor,
      correctLabel: '정답',
      correctValue: isSpelling ? answer.word : (answer.meaning ?? '상세 답안 없음'),
      answerLabel:
          isWeak && (answer.userAnswer?.isNotEmpty ?? false) ? '내 답' : null,
      answerValue:
          isWeak && (answer.userAnswer?.isNotEmpty ?? false)
              ? answer.userAnswer
              : null,
    );
  }

  Future<List<Word>> _resolveWords(
    BuildContext context,
    Iterable<StudyAnswerRecord> answers,
  ) async {
    final manager = context.read<WordbookManager>();
    await manager.setActiveWordbook(wordbook);
    final allWords = await manager.getAllWordsFrom(wordbook);
    final byKey = <String, Word>{
      for (final word in allWords) StudyScheduleService.wordKey(word): word,
    };
    return answers
        .map((answer) => byKey[answer.wordKey])
        .whereType<Word>()
        .toList(growable: false);
  }

  Future<void> _openQuiz(
    BuildContext context,
    Iterable<StudyAnswerRecord> answers, {
    bool review = false,
  }) async {
    final words = await _resolveWords(context, answers);
    if (!context.mounted) return;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어장이 변경되어 다시 학습할 단어를 찾을 수 없어요.')),
      );
      return;
    }
    final isSpelling = session.mode == StudyHistoryMode.spelling;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => QuizScreen(
              initialMode:
                  isSpelling
                      ? review
                          ? QuizMode.reviewSpelling
                          : QuizMode.spelling
                      : review
                      ? QuizMode.reviewMultipleChoice
                      : QuizMode.multipleChoice,
              origin:
                  review
                      ? LearningRouteOrigin.review
                      : LearningRouteOrigin.standalone,
              mistakeReview: review,
              wordsOverride: words,
            ),
      ),
    );
  }

  Future<void> _openFlashcards(
    BuildContext context,
    Iterable<StudyAnswerRecord> answers,
  ) async {
    final words = await _resolveWords(context, answers);
    if (!context.mounted) return;
    if (words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('단어장이 변경되어 다시 학습할 단어를 찾을 수 없어요.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => FlashcardScreen(
              initialMode: FlashcardLaunchMode.allWords,
              origin: LearningRouteOrigin.standalone,
              reviewWordsOverride: words,
            ),
      ),
    );
  }
}

bool _isFirstTrySpellingCorrect(StudyAnswerRecord answer) {
  return answer.success && !answer.skipped && answer.attempts <= 1;
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
  String? _firstAttemptAnswer;
  bool _hasSavedSessionSrs = false;
  bool _hasRecordedHistory = false;
  StudySessionRecorder? _historyRecorder;

  void _startHistory() {
    _sessionWords = _wordbookManager.latestStudyWords(
      widget.selectedWordbook.dbFileName,
      _sessionWords,
    );
    _historyRecorder = StudyHistoryService.instance.start(
      wordbook: widget.selectedWordbook,
      mode: StudyHistoryMode.spelling,
      expectedCount: _sessionWords.length,
      plan: _wordbookManager.planForSession(
        widget.selectedWordbook,
        _sessionWords,
      ),
    );
  }

  SpellingAnswerState _answerState = SpellingAnswerState.none;
  final List<SpellingQuizResult> _results = [];
  bool _isClosingResults = false;
  _SpellingScorePulse _scorePulse = _SpellingScorePulse.none;
  Timer? _autoAdvanceTimer;
  int _hintStage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wordbookManager = context.read<WordbookManager>();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
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
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 120),
          _ensureKeyboardVisible,
        ),
      );
      unawaited(
        Future<void>.delayed(
          const Duration(milliseconds: 420),
          _ensureKeyboardVisible,
        ),
      );
    }
  }

  void _initializeSession() {
    _hasSavedSessionSrs = false;
    _hasRecordedHistory = false;
    _sessionWords = List.from(widget.words)..shuffle();
    _startHistory();
    if (_sessionWords.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onFinish());
      return;
    }
    context.read<AnalyticsService>().logStudyStarted(
      mode:
          widget.origin == LearningRouteOrigin.review
              ? 'review_spelling'
              : 'spelling',
      wordCount: _sessionWords.length,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureKeyboardVisible(),
    );
  }

  void _ensureKeyboardVisible() {
    if (mounted && _answerState == SpellingAnswerState.none) {
      FocusScope.of(context).requestFocus(_focusNode);
      unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        FocusScope.of(context).requestFocus(_focusNode);
        unawaited(
          SystemChannels.textInput.invokeMethod<void>('TextInput.show'),
        );
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
    final word = _sessionWords[_currentIndex];
    final submittedAnswer = _textController.text.trim();
    final updated = _srsService.updateQuizSrs(
      word: word,
      spelling: true,
      cleanCorrect: isCorrect && !wasRetryAttempt,
    );
    unawaited(
      _wordbookManager.queueWordsSrsData(widget.selectedWordbook.dbFileName, [
        updated,
      ]),
    );
    _historyRecorder?.answer(
      word,
      success: isCorrect,
      retry: wasRetryAttempt,
      userAnswer:
          wasRetryAttempt
              ? (_firstAttemptAnswer ?? submittedAnswer)
              : submittedAnswer,
      nextReviewDate: updated.nextReviewDate,
    );
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
            userAnswer:
                wasRetryAttempt
                    ? (_firstAttemptAnswer ?? submittedAnswer)
                    : submittedAnswer,
          ),
        );
      } else {
        _answerState = SpellingAnswerState.incorrect;
        if (!wasRetryAttempt) {
          _firstAttemptAnswer = submittedAnswer;
        }
      }
    });
    if (isCorrect) {
      unawaited(
        context.read<StudySoundService>().play(StudySoundEffect.correct),
      );
      _playScorePulse(
        wasRetryAttempt
            ? _SpellingScorePulse.correctRetry
            : _SpellingScorePulse.correctFirstTry,
      );
      _scheduleAutomaticAdvance();
    } else {
      unawaited(
        context.read<StudySoundService>().play(StudySoundEffect.incorrect),
      );
      _playScorePulse(_SpellingScorePulse.wrongAttempt);
    }
  }

  String? _firstRevealableSpellingChar() {
    if (_sessionWords.isEmpty) return null;
    final answer = _sessionWords[_currentIndex].word;
    for (final rune in answer.runes) {
      final char = String.fromCharCode(rune);
      if (char == ' ' || char == '-' || char == '_') {
        continue;
      }
      return char;
    }
    return null;
  }

  void _advanceHint() {
    if (_answerState != SpellingAnswerState.none) return;
    if (_hintStage == 0) {
      setState(() => _hintStage = 1);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _ensureKeyboardVisible(),
      );
      return;
    }
    final firstChar = _firstRevealableSpellingChar();
    final normalizedInput = _textController.text.replaceAll(
      RegExp(r'[\s\-_]'),
      '',
    );
    if (_hintStage >= 2) {
      if (firstChar != null && normalizedInput.isEmpty) {
        _textController.value = TextEditingValue(
          text: firstChar,
          selection: TextSelection.collapsed(offset: firstChar.length),
        );
        setState(() {});
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _ensureKeyboardVisible(),
        );
      }
      return;
    }
    if (firstChar != null && normalizedInput.isEmpty) {
      _textController.value = TextEditingValue(
        text: firstChar,
        selection: TextSelection.collapsed(offset: firstChar.length),
      );
    }
    setState(() => _hintStage = 2);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _ensureKeyboardVisible(),
    );
  }

  void _showCorrectAnswer() {
    if (_answerState == SpellingAnswerState.showAnswer ||
        _answerState == SpellingAnswerState.correct) {
      return;
    }
    final word = _sessionWords[_currentIndex];
    final submittedAnswer =
        (_firstAttemptAnswer ?? _textController.text.trim()).trim();
    final updated = _srsService.updateQuizSrs(
      word: word,
      spelling: true,
      cleanCorrect: false,
    );
    unawaited(
      _wordbookManager.queueWordsSrsData(widget.selectedWordbook.dbFileName, [
        updated,
      ]),
    );
    _historyRecorder?.answer(
      word,
      success: false,
      skipped: true,
      userAnswer: submittedAnswer,
      nextReviewDate: updated.nextReviewDate,
    );
    setState(() {
      _answerState = SpellingAnswerState.showAnswer;
      _textController.text = _sessionWords[_currentIndex].word;
      _results.add(
        SpellingQuizResult(
          word: _sessionWords[_currentIndex],
          isSkipped: true,
          userAnswer: submittedAnswer,
        ),
      );
    });
    unawaited(
      context.read<StudySoundService>().play(StudySoundEffect.incorrect),
    );
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
        _firstAttemptAnswer = null;
        _scorePulse = _SpellingScorePulse.none;
        _hintStage = 0;
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
      _hintStage = 0;
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
        _firstAttemptAnswer = null;
        _hasSavedSessionSrs = false;
        _hasRecordedHistory = false;
        _hintStage = 0;
        _results.clear();
        _textController.clear();
      });
      _initializeSession();
      return;
    }

    final seenIds = <int?>{};
    final uniqueWords =
        weakWords.where((word) => seenIds.add(word.id)).toList();

    setState(() {
      _currentIndex = 0;
      _answerState = SpellingAnswerState.none;
      _isRetryAttempt = false;
      _firstAttemptAnswer = null;
      _hasSavedSessionSrs = false;
      _hasRecordedHistory = false;
      _hintStage = 0;
      _results.clear();
      _textController.clear();
      _sessionWords = List<Word>.from(uniqueWords)..shuffle();
    });
    _startHistory();
    _ensureKeyboardVisible();
  }

  Future<void> _saveSessionSrsOnExit() async {
    if (_hasSavedSessionSrs) return;
    await _wordbookManager.pendingSrsWrites;
    _hasSavedSessionSrs = true;
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
    if (!_hasRecordedHistory && _results.isNotEmpty) {
      _hasRecordedHistory = true;
      _historyRecorder?.complete();
    }
    context.read<AnalyticsService>().logQuizCompleted(
      mode:
          widget.origin == LearningRouteOrigin.review
              ? 'review_spelling'
              : 'spelling',
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
                  onRestart:
                      () => _closeResultsThen(() {
                        setState(() {
                          _currentIndex = 0;
                          _answerState = SpellingAnswerState.none;
                          _isRetryAttempt = false;
                          _firstAttemptAnswer = null;
                          _hasSavedSessionSrs = false;
                          _hasRecordedHistory = false;
                          _hintStage = 0;
                          _results.clear();
                          _textController.clear();
                        });
                        _initializeSession();
                      }),
                  onRetryWeakWords:
                      () => _closeResultsThen(_restartWeakWordSession),
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
    final identity = MemorizeIdentity.of(theme);
    final currentWord = _sessionWords[_currentIndex];
    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final correctCount =
        _results
            .where(
              (result) => result.isCorrectOnFirstTry || result.isCorrectOnRetry,
            )
            .length;
    final incorrectCount = _results.where((result) => result.isSkipped).length;
    final correctPulse =
        _scorePulse == _SpellingScorePulse.correctFirstTry ||
        _scorePulse == _SpellingScorePulse.correctRetry;
    final incorrectPulse =
        _scorePulse == _SpellingScorePulse.wrongAttempt ||
        _scorePulse == _SpellingScorePulse.wrongCommitted;
    final correctPulseColor =
        _scorePulse == _SpellingScorePulse.correctRetry
            ? (theme.brightness == Brightness.dark
                ? const Color(0xFFFFB454)
                : const Color(0xFFE77B12))
            : identity.success;
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
                    contextLabel: widget.selectedWordbook.name,
                    accentColor:
                        widget.sessionLabel.contains('복습')
                            ? identity.review
                            : identity.primaryAction,
                    currentIndex: _currentIndex,
                    totalCount: _sessionWords.length,
                    correctCount: correctCount,
                    incorrectCount: incorrectCount,
                    pulseAnimation: _scorePulseController,
                    correctPulsing: correctPulse,
                    incorrectPulsing: incorrectPulse,
                    correctPulseColor: correctPulseColor,
                    correctPulseIcon:
                        _scorePulse == _SpellingScorePulse.correctRetry
                            ? CupertinoIcons.arrow_counterclockwise
                            : CupertinoIcons.checkmark_seal_fill,
                    incorrectPulseIcon:
                        _scorePulse == _SpellingScorePulse.wrongAttempt
                            ? CupertinoIcons.exclamationmark_triangle_fill
                            : CupertinoIcons.xmark_circle_fill,
                    compact: keyboardVisible,
                  ),
                  SizedBox(height: keyboardVisible ? 14 : 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '주어진 뜻에 해당하는 단어를 입력하세요.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: identity.mutedInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: keyboardVisible ? 12 : 20),
                  Text(
                    currentWord.meaning,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: identity.ink,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.left,
                  ),
                  if (_hintStage >= 2 &&
                      currentWord.additionalMeanings.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.07,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '또 다른 뜻 · ${currentWord.additionalMeanings.first}',
                        textAlign: TextAlign.left,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: keyboardVisible ? 18 : 30),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_hintStage > 0)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Center(
                              child: _buildAnswerBoxes(theme, currentWord.word),
                            ),
                          ),
                        ),
                      Opacity(
                        opacity: _hintStage == 0 ? 1 : 0.01,
                        child: TextField(
                          controller: _textController,
                          focusNode: _focusNode,
                          autofocus: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.done,
                          cursorColor:
                              _hintStage == 0
                                  ? identity.primaryAction
                                  : Colors.transparent,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color:
                                _hintStage == 0
                                    ? identity.ink
                                    : Colors.transparent,
                            fontWeight: FontWeight.w800,
                          ),
                          decoration: InputDecoration(
                            hintText: _hintStage == 0 ? '단어를 입력하세요' : null,
                            suffixIcon:
                                _hintStage == 0 &&
                                        _textController.text.isNotEmpty
                                    ? IconButton(
                                      onPressed: () {
                                        _textController.clear();
                                        setState(() {});
                                        _ensureKeyboardVisible();
                                      },
                                      icon: const Icon(
                                        CupertinoIcons.xmark_circle_fill,
                                      ),
                                    )
                                    : null,
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _checkAnswer(),
                        ),
                      ),
                    ],
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

  // ignore: unused_element
  Widget _buildSpellingStatusBar(ThemeData theme) {
    final correct =
        _results
            .where(
              (result) => result.isCorrectOnFirstTry || result.isCorrectOnRetry,
            )
            .length;
    final wrong = _results.where((result) => result.isSkipped).length;
    final correctPulse =
        _scorePulse == _SpellingScorePulse.correctFirstTry ||
        _scorePulse == _SpellingScorePulse.correctRetry;
    final wrongPulse =
        _scorePulse == _SpellingScorePulse.wrongAttempt ||
        _scorePulse == _SpellingScorePulse.wrongCommitted;
    final correctPulseColor =
        _scorePulse == _SpellingScorePulse.correctRetry
            ? (theme.brightness == Brightness.dark
                ? const Color(0xFFFFB454)
                : const Color(0xFFE77B12))
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
                progress <= 0.35 ? progress / 0.35 : (1 - progress) / 0.65;
            final intensity =
                isPulsing ? rawIntensity.clamp(0.0, 1.0).toDouble() : 0.0;
            final displayColor = isPulsing ? pulseColor : color;
            return Transform.scale(
              scale: 1 + (0.10 * intensity),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
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
                  : CupertinoIcons.checkmark_seal_fill,
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
    bool isFixedHintChar(String char) =>
        char == '-' || char == '_' || char == ' ';
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
      if (_answerState == SpellingAnswerState.correct) {
        return AppTheme.primaryGreen;
      }
      if (_answerState == SpellingAnswerState.incorrect) {
        return AppTheme.accentCoral;
      }
      if (_answerState == SpellingAnswerState.showAnswer) {
        return AppTheme.accentCoral;
      }
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
            !isFixedHint &&
            inputIndex == userInput.length &&
            _answerState == SpellingAnswerState.none;
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
                  color:
                      isFixedHint && !isBlankGap
                          ? theme.colorScheme.primary
                          : getTextColor(),
                  fontWeight:
                      isFixedHint && !isBlankGap
                          ? FontWeight.w900
                          : FontWeight.w700,
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
      final hasRevealableChar = _firstRevealableSpellingChar() != null;
      final normalizedInput = _textController.text.replaceAll(
        RegExp(r'[\s\-_]'),
        '',
      );
      final canUseHint =
          hasRevealableChar &&
          (_hintStage < 2 || (_hintStage >= 2 && normalizedInput.isEmpty));
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: canUseHint ? _advanceHint : null,
                icon: const Icon(CupertinoIcons.lightbulb, size: 18),
                label: const Text(
                  '힌트 보기',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 50,
              child: FilledButton.icon(
                onPressed:
                    _textController.text.isNotEmpty ? _checkAnswer : null,
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
                  backgroundColor:
                      theme.brightness == Brightness.dark
                          ? const Color(0xFFFFB454)
                          : const Color(0xFFE77B12),
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
    final identity = MemorizeIdentity.of(theme);
    final totalQuestions = results.length;
    final firstTryCorrect = results.where((r) => r.isCorrectOnFirstTry).length;
    final retryCorrect = results.where((r) => r.isCorrectOnRetry).length;
    final incorrect = totalQuestions - firstTryCorrect - retryCorrect;
    final firstTryAccuracy =
        totalQuestions > 0
            ? (firstTryCorrect / totalQuestions * 100).round()
            : 0;
    final hasWeakWords = incorrect > 0 || retryCorrect > 0;
    final weakCount = incorrect + retryCorrect;
    final weakResults =
        results.where((result) => !result.isCorrectOnFirstTry).toList();
    final correctResults =
        results.where((result) => result.isCorrectOnFirstTry).toList();
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onFinish();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('퀴즈 결과'),
          leading: IconButton(
            icon: const Icon(CupertinoIcons.back),
            onPressed: onFinish,
          ),
          actions: [
            IconButton(
              tooltip: '닫기',
              onPressed: onFinish,
              icon: const Icon(CupertinoIcons.xmark),
            ),
            const SizedBox(width: 4),
          ],
        ),
        backgroundColor: identity.canvas,
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _QuizResultHero(
                  percentage: firstTryAccuracy,
                  percentageLabel: '한 번에 정답률',
                  headline: '$totalQuestions문제 중 $firstTryCorrect개 한 번에 정답',
                  metrics: [
                    _QuizResultMetric(
                      label: '한 번에',
                      value: firstTryCorrect,
                      color: identity.primaryAction,
                      icon: CupertinoIcons.check_mark_circled_solid,
                    ),
                    _QuizResultMetric(
                      label: '다시 확인',
                      value: weakCount,
                      color: identity.review,
                      icon: CupertinoIcons.arrow_counterclockwise_circle_fill,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _QuizResultActions(
                  title: hasWeakWords ? '다시 볼 단어부터 정리해요' : '이번 세트는 안정적입니다',
                  description:
                      hasWeakWords
                          ? '재도전·오답 $weakCount개는 다음 복습 일정에 보수적으로 반영됐어요.'
                          : '모든 단어를 한 번에 입력했어요.',
                  actions: [
                    if (hasWeakWords)
                      _QuizResultAction(
                        label: '다시 볼 문제 $weakCount개 풀기',
                        icon: CupertinoIcons.arrow_counterclockwise,
                        onPressed: onRetryWeakWords,
                        emphasized: true,
                      ),
                    _QuizResultAction(
                      label: hasWeakWords ? '카드로 먼저 복습' : '새 단어 카드',
                      icon: CupertinoIcons.rectangle_stack_fill,
                      onPressed:
                          () => _replaceQuizWithFlashcard(
                            context,
                            hasWeakWords
                                ? FlashcardLaunchMode.review
                                : FlashcardLaunchMode.newWords,
                          ),
                    ),
                    _QuizResultAction(
                      label: '스펠링 다시',
                      icon: CupertinoIcons.arrow_2_circlepath,
                      onPressed: onRestart,
                    ),
                  ],
                ),
                if (weakResults.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _QuizResultSection(
                    title: '다시 볼 문제',
                    count: weakResults.length,
                    color: identity.review,
                    icon: CupertinoIcons.arrow_counterclockwise_circle_fill,
                    children:
                        weakResults
                            .map((result) => _buildResultItem(result, theme))
                            .toList(),
                  ),
                ],
                if (correctResults.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  _QuizResultSection(
                    title: '맞은 문제',
                    count: correctResults.length,
                    color: identity.primaryAction,
                    icon: CupertinoIcons.check_mark_circled_solid,
                    children:
                        correctResults
                            .map((result) => _buildResultItem(result, theme))
                            .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: onFinish,
                    child: const Text('완료'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _replaceQuizWithFlashcard(
    BuildContext context,
    FlashcardLaunchMode mode,
  ) {
    final navigator = Navigator.of(context);
    navigator.pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigator.pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => FlashcardScreen(
                initialMode: mode,
                origin: origin,
                reviewWordsOverride:
                    mode == FlashcardLaunchMode.review
                        ? results
                            .where((r) => !r.isCorrectOnFirstTry)
                            .map((r) => r.word)
                            .toList()
                        : null,
              ),
        ),
      );
    });
  }

  Widget _buildResultItem(SpellingQuizResult result, ThemeData theme) {
    final identity = MemorizeIdentity.of(theme);
    late final Color statusColor;
    late final String statusText;
    if (result.isCorrectOnFirstTry) {
      statusColor = identity.primaryAction;
      statusText = '한 번에 정답';
    } else if (result.isCorrectOnRetry) {
      statusColor =
          theme.brightness == Brightness.dark
              ? const Color(0xFFFFB454)
              : const Color(0xFFE77B12);
      statusText = '재도전 성공';
    } else {
      statusColor = identity.review;
      statusText = '틀림/스킵';
    }
    return _QuizResultWordRow(
      title: result.word.meaning,
      subtitle:
          result.word.additionalMeanings.isEmpty
              ? null
              : result.word.additionalMeanings.join(' · '),
      statusLabel: statusText,
      statusColor: statusColor,
      correctLabel: '정답',
      correctValue: result.word.word,
      answerLabel: result.isCorrectOnFirstTry ? null : '내 답',
      answerValue: result.isCorrectOnFirstTry ? null : result.userAnswer,
    );
  }
}
