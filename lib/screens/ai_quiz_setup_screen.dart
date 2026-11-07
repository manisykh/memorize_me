// lib/screens/ai_quiz_setup_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../models/study_plan_model.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/ai_service.dart';
import '../services/ai_word_review_progress_service.dart';
import '../services/ai_difficulty_profile.dart';
import '../services/analytics_service.dart';
import '../services/api_key_service.dart';
import '../services/mode_state_service.dart';
import '../services/srs_service.dart';
import '../themes/memorize_identity.dart';
import '../utils/ai_error_utils.dart';
import '../widgets/ai_setup_widgets.dart';
import '../widgets/ai_settings_card.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_dialog.dart';
import 'ai_quiz_player_screen.dart';

enum AiQuizSetupFocus { quiz, sentences }

enum _AiQuizWordScope { today, due, mistakes, custom }

enum _AiEnrichmentTask { missingExamples, reviewMeanings, refineExamples }

enum _AiEnrichmentScope { needed, today, custom }

class AiQuizSetupScreen extends StatefulWidget {
  final AiQuizSetupFocus initialFocus;

  const AiQuizSetupScreen({
    super.key,
    this.initialFocus = AiQuizSetupFocus.quiz,
  });

  @override
  State<AiQuizSetupScreen> createState() => _AiQuizSetupScreenState();
}

class _AiQuizSetupScreenState extends State<AiQuizSetupScreen> {
  Wordbook? _selectedWordbook;
  StudyPlan? _studyPlan;
  List<Word> _words = [];
  final Set<int> _selectedWordIds = {};
  Set<int> _reviewedWordIds = {};
  final _reviewProgress = const AiWordReviewProgressService();
  int _totalWordCount = 0;
  int _lockedNewWordCount = 0;

  String _selectedQuizType = '종합';
  double _difficulty = 3.0;
  double _questionCount = 10.0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _includeExplanation = false;
  bool _isGeneratingSentences = false;
  bool _isReviewingMeanings = false;
  String _questionLanguage = 'English';
  _AiQuizWordScope _quizScope = _AiQuizWordScope.today;
  _AiEnrichmentTask _enrichmentTask = _AiEnrichmentTask.missingExamples;
  _AiEnrichmentScope _enrichmentScope = _AiEnrichmentScope.needed;
  bool _showAdvancedQuizSettings = false;
  bool _showDataNotice = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialWordbook = context.read<WordbookManager>().activeWordbook;
      if (initialWordbook != null) {
        _onWordbookSelected(initialWordbook);
      }
    });
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    setState(() {
      _isLoading = true;
      _selectedWordbook = wordbook;
      _studyPlan = null;
      _totalWordCount = 0;
      _lockedNewWordCount = 0;
      _words.clear();
      _selectedWordIds.clear();
      _reviewedWordIds = {};
    });

    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();
    await wordbookManager.setActiveWordbook(wordbook);

    final allWords = await wordbookManager.getAllWordsFrom(wordbook);
    final studyPlan = wordbookManager.planFor(wordbook);
    final words = wordbookManager.wordsAvailableForPlan(
      allWords,
      plan: studyPlan,
    );
    final reviewedIds = await _reviewProgress.reviewedWordIds(
      wordbook.dbFileName,
      words,
    );
    final lockedNewWordCount = wordbookManager.lockedNewWordCount(
      allWords,
      plan: studyPlan,
    );
    if (mounted) {
      setState(() {
        _studyPlan = studyPlan;
        _totalWordCount = allWords.length;
        _lockedNewWordCount = lockedNewWordCount;
        _words = words;
        _reviewedWordIds = reviewedIds;
        _syncAutomaticSelection(words);
        _isLoading = false;
      });
    }

    await modeStateService.setLastUsedWordbookId(
      LearningMode.aiQuiz,
      wordbook.id!,
    );
  }

  List<Word> _dueWords([List<Word>? source]) =>
      SrsService().dueWords(source ?? _words);

  List<Word> _mistakeWords([List<Word>? source]) {
    final allowed =
        (source ?? _words).map((word) => word.id).whereType<int>().toSet();
    return context
        .read<WordbookManager>()
        .quizReviewEntries()
        .map((entry) => entry.word)
        .where((word) => word.id != null && allowed.contains(word.id))
        .toList();
  }

  List<Word> _todayWords([List<Word>? source]) {
    final words = source ?? _words;
    final manager = context.read<WordbookManager>();
    final daily = SrsService().buildDailyPlan(words);
    final newTarget = manager.plannedNewWordSessionCount(
      words,
      plan: _studyPlan,
    );
    final ordered = <Word>[
      ...daily.dueWords,
      ..._mistakeWords(words),
      ...daily.learningWords,
      ...daily.newWords.take(newTarget),
    ];
    final seen = <int>{};
    final unique =
        ordered.where((word) => word.id != null && seen.add(word.id!)).toList();
    return unique.isEmpty ? words.take(20).toList() : unique;
  }

  List<Word> _neededEnrichmentWords([List<Word>? source]) {
    final words = source ?? _words;
    switch (_enrichmentTask) {
      case _AiEnrichmentTask.missingExamples:
        return words
            .where((word) => word.exampleSentence?.trim().isEmpty ?? true)
            .toList();
      case _AiEnrichmentTask.reviewMeanings:
      case _AiEnrichmentTask.refineExamples:
        return _reviewPriorityWords(words).toList();
    }
  }

  void _syncAutomaticSelection([List<Word>? source]) {
    final words = source ?? _words;
    Iterable<Word> selected;
    if (widget.initialFocus == AiQuizSetupFocus.sentences) {
      selected = switch (_enrichmentScope) {
        _AiEnrichmentScope.needed => _neededEnrichmentWords(words).take(20),
        _AiEnrichmentScope.today => _todayWords(words).take(20),
        _AiEnrichmentScope.custom => const <Word>[],
      };
    } else {
      selected = switch (_quizScope) {
        _AiQuizWordScope.today => _todayWords(words),
        _AiQuizWordScope.due => _dueWords(words),
        _AiQuizWordScope.mistakes => _mistakeWords(words),
        _AiQuizWordScope.custom => const <Word>[],
      };
    }
    _selectedWordIds
      ..clear()
      ..addAll(
        selected.where((word) => word.id != null).map((word) => word.id!),
      );
  }

  Iterable<Word> _reviewPriorityWords(List<Word> words) sync* {
    final available = words.where(
      (word) => word.id != null && !_reviewedWordIds.contains(word.id),
    );
    yield* available.where(
      (word) =>
          (word.exampleSentence?.trim().isNotEmpty ?? false) &&
          (word.exampleSentenceTranslation?.trim().isEmpty ?? true),
    );
    yield* available.where(
      (word) =>
          !(word.exampleSentence?.trim().isNotEmpty ?? false) ||
          !(word.exampleSentenceTranslation?.trim().isEmpty ?? true),
    );
  }

  void _onSelectAll() => setState(() {
    final available = _words.where((word) => word.id != null);
    if (widget.initialFocus == AiQuizSetupFocus.sentences) {
      _selectedWordIds
        ..clear()
        ..addAll(
          _neededEnrichmentWords(_words).take(20).map((word) => word.id!),
        );
    } else {
      _selectedWordIds.addAll(available.map((word) => word.id!));
    }
  });
  void _onDeselectAll() => setState(() => _selectedWordIds.clear());

  Future<void> _showAiSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder:
          (_) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'AI 설정',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const AiSettingsCard(),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  Future<void> _handleApiError(dynamic e) async {
    if (!mounted) return;
    final message = aiUserFacingErrorMessage(e);
    if (aiErrorShouldOpenSettings(e)) {
      final openSettings = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('AI 설정 필요'),
              content: Text(message),
              actions: [
                TextButton(
                  child: const Text('취소'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                FilledButton(
                  child: const Text('설정 열기'),
                  onPressed: () => Navigator.pop(dialogContext, true),
                ),
              ],
            ),
      );
      if (openSettings == true && mounted) {
        await _showAiSettingsSheet();
      }
      return;
    }
    setState(() => _errorMessage = message);
  }

  void _showPartialGenerationNotice(AiQuizResponse quizResponse) {
    final requested = quizResponse.requestedQuestionCount;
    final generated = quizResponse.answerableQuestionCount;
    final dropped = quizResponse.droppedDuplicateCount;
    if (requested <= 0 || (generated >= requested && dropped == 0)) return;

    final droppedText = dropped > 0 ? ' 중복 문제 $dropped개는 제외했습니다.' : '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$requested문제 중 $generated문제를 생성했습니다.$droppedText'),
      ),
    );
  }

  Future<void> _generateQuiz() async {
    if (_selectedWordIds.isEmpty) {
      setState(() => _errorMessage = '문제를 생성할 단어를 1개 이상 선택해주세요.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    context.read<AnalyticsService>().logAiGenerationStarted(
      generationType: 'word_quiz',
      requestedCount: _questionCount.round(),
    );

    try {
      final aiService = context.read<AiService>();
      final aiSettings = context.read<AiSettingsProvider>();
      List<Word> selectedWords =
          _words.where((word) => _selectedWordIds.contains(word.id)).toList();
      selectedWords.shuffle();

      final difficultyIndex = (_difficulty.round() - 1).clamp(0, 6);
      final difficultyText = AiDifficultyProfiles.labels[difficultyIndex];
      final quizType = _selectedQuizType == '듣기' ? '종합' : _selectedQuizType;

      final fallbackResult = await aiService.generateQuizWithFallback(
        options: aiSettings.requestOptions(
          fallbackEnabled: aiSettings.autoFallbackEnabled,
        ),
        selectedWords: selectedWords,
        quizType: quizType,
        difficulty: difficultyText,
        questionCount: _questionCount.round(),
        includeExplanation: _includeExplanation,
        questionLanguage: _questionLanguage,
      );
      aiSettings.recordUsedOption(fallbackResult.usedOption);
      final quizResponse = fallbackResult.value;
      if (quizResponse != null &&
          quizResponse.questions.isNotEmpty &&
          mounted) {
        context.read<AnalyticsService>().logAiGenerationCompleted(
          generationType: 'word_quiz',
          generatedCount: quizResponse.answerableQuestionCount,
          usedFallback:
              fallbackResult.usedOption.provider != aiSettings.selectedProvider,
        );
      }

      if (mounted) {
        if (quizResponse != null && quizResponse.questions.isNotEmpty) {
          if (fallbackResult.usedOption.provider !=
              aiSettings.selectedProvider) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${fallbackResult.usedOption.provider.shortLabel} ${fallbackResult.usedOption.modelName} 모델로 자동 대체했습니다.',
                ),
              ),
            );
          }
          _showPartialGenerationNotice(quizResponse);
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AiQuizPlayerScreen(quizResponse: quizResponse),
            ),
          );
        } else {
          setState(() => _errorMessage = 'AI가 문제를 생성하지 못했습니다. 다시 시도해주세요.');
        }
      }
    } catch (e) {
      await _handleApiError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ▼▼▼ [수정] 전체 메서드 수정
  Future<void> _generateAllSentences() async {
    final wordbookManager = context.read<WordbookManager>();
    if (_selectedWordbook == null) return;

    final allowedIds = _selectedWordIds;
    final wordsToUpdate =
        _words
            .where((word) => allowedIds.contains(word.id))
            .where((word) => word.exampleSentence?.trim().isEmpty ?? true)
            .take(20)
            .toList();

    if (wordsToUpdate.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 단어에 예문이 이미 존재합니다.')));
      return;
    }
    setState(() {
      _isGeneratingSentences = true;
      _errorMessage = null;
    });
    context.read<AnalyticsService>().logAiGenerationStarted(
      generationType: 'example_sentences',
      requestedCount: wordsToUpdate.length,
    );
    try {
      final aiService = context.read<AiService>();
      final aiSettings = context.read<AiSettingsProvider>();

      final fallbackResult = await aiService
          .generateSentencesForWordsWithFallback(
            wordsToUpdate,
            aiSettings.requestOptions(
              fallbackEnabled: aiSettings.autoFallbackEnabled,
            ),
          );
      aiSettings.recordUsedOption(fallbackResult.usedOption);
      final sentenceMap = fallbackResult.value;

      final suggestions = <AiWordReviewSuggestion>[];
      for (var index = 0; index < wordsToUpdate.length; index++) {
        final word = wordsToUpdate[index];
        if (sentenceMap.containsKey(word.word)) {
          final sentenceData = sentenceMap[word.word]!;
          suggestions.add(
            AiWordReviewSuggestion(
              index: index,
              word: word.word,
              meaning: word.meaning,
              sentence: sentenceData['sentence'] ?? '',
              translation: sentenceData['translation'] ?? '',
            ),
          );
        }
      }

      if (!mounted) return;
      final approved = await _showMeaningReview(suggestions, wordsToUpdate);
      if (!mounted || approved == null) return;
      final updatedWords = <Word>[
        for (final suggestion in suggestions)
          if (approved.contains(suggestion.index))
            wordsToUpdate[suggestion.index].copyWith(
              exampleSentence: suggestion.sentence,
              exampleSentenceTranslation: suggestion.translation,
            ),
      ];

      if (updatedWords.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('적용할 AI 제안을 선택하지 않았습니다.')));
        return;
      }

      await wordbookManager.updateWordsInWordbook(
        _selectedWordbook!,
        updatedWords,
      );
      if (mounted) {
        context.read<AnalyticsService>().logAiGenerationCompleted(
          generationType: 'example_sentences',
          generatedCount: updatedWords.length,
          usedFallback:
              fallbackResult.usedOption.provider != aiSettings.selectedProvider,
        );
      }
      final allWords = await wordbookManager.getAllWordsFrom(
        _selectedWordbook!,
      );
      final newWords = wordbookManager.wordsAvailableForPlan(
        allWords,
        plan: _studyPlan,
      );
      final reviewedIds = await _reviewProgress.reviewedWordIds(
        _selectedWordbook!.dbFileName,
        newWords,
      );

      if (mounted) {
        setState(() {
          _words = newWords;
          _reviewedWordIds = reviewedIds;
          _selectedWordIds
            ..clear()
            ..addAll(
              _reviewPriorityWords(newWords).take(20).map((word) => word.id!),
            );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              fallbackResult.usedOption.provider == aiSettings.selectedProvider
                  ? '${updatedWords.length}개 단어의 예문 생성이 완료되었습니다.'
                  : '${fallbackResult.usedOption.provider.shortLabel} 모델로 대체해 ${updatedWords.length}개 단어의 예문을 생성했습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      await _handleApiError(e);
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSentences = false);
      }
    }
  }

  Future<void> _reviewMeanings() async {
    final book = _selectedWordbook;
    if (book == null) return;
    final wordbookManager = context.read<WordbookManager>();
    final selectedWords =
        _words.where((word) => _selectedWordIds.contains(word.id)).toList();
    if (selectedWords.isEmpty || selectedWords.length > 20) {
      setState(() => _errorMessage = '뜻 검토할 단어를 1~20개 선택해주세요.');
      return;
    }

    setState(() {
      _isReviewingMeanings = true;
      _errorMessage = null;
    });
    try {
      final aiSettings = context.read<AiSettingsProvider>();
      final result = await context
          .read<AiService>()
          .reviewWordMeaningsWithFallback(
            selectedWords,
            aiSettings.requestOptions(
              fallbackEnabled: aiSettings.autoFallbackEnabled,
            ),
          );
      aiSettings.recordUsedOption(result.usedOption);
      if (!mounted) return;
      if (result.value.isEmpty) {
        setState(() => _errorMessage = '검토 결과를 받지 못했습니다. 다시 시도해주세요.');
        return;
      }

      final changed =
          result.value.where((suggestion) {
            final original = selectedWords[suggestion.index];
            return suggestion.word != original.word ||
                suggestion.meaning != original.meaning ||
                suggestion.sentence != (original.exampleSentence ?? '') ||
                suggestion.translation !=
                    (original.exampleSentenceTranslation ?? '');
          }).toList();
      if (changed.isEmpty) {
        await _reviewProgress.markReviewed(
          book.dbFileName,
          result.value.map((item) => selectedWords[item.index]).toList(),
        );
        if (!mounted) return;
        await _onWordbookSelected(book);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('수정할 내용이 없어 검토 완료로 표시했습니다.')),
        );
        return;
      }

      final approved = await _showMeaningReview(changed, selectedWords);
      if (!mounted || approved == null) return;
      final updates = [
        for (final suggestion in changed)
          if (approved.contains(suggestion.index))
            selectedWords[suggestion.index].copyWith(
              word: suggestion.word,
              meaning: suggestion.meaning,
              exampleSentence: suggestion.sentence,
              exampleSentenceTranslation: suggestion.translation,
            ),
      ];
      if (updates.isNotEmpty) {
        await wordbookManager.updateWordsInWordbook(book, updates);
      }
      final currentWords = await wordbookManager.getAllWordsFrom(book);
      final reviewedIds =
          result.value
              .map((item) => selectedWords[item.index].id)
              .whereType<int>()
              .toSet();
      await _reviewProgress.markReviewed(
        book.dbFileName,
        currentWords.where((word) => reviewedIds.contains(word.id)).toList(),
      );
      if (!mounted) return;
      await _onWordbookSelected(book);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${reviewedIds.length}개 검토 완료 · ${updates.length}개 수정 반영',
            ),
          ),
        );
      }
    } catch (error) {
      await _handleApiError(error);
    } finally {
      if (mounted) setState(() => _isReviewingMeanings = false);
    }
  }

  Future<Set<int>?> _showMeaningReview(
    List<AiWordReviewSuggestion> suggestions,
    List<Word> originals,
  ) {
    final selected = suggestions.map((item) => item.index).toSet();
    return showDialog<Set<int>>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, refresh) => AlertDialog(
                  title: const Text('AI 제안 확인'),
                  content: SizedBox(
                    width: double.maxFinite,
                    height: MediaQuery.sizeOf(context).height * 0.55,
                    child: ListView.builder(
                      itemCount: suggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = suggestions[index];
                        final original = originals[suggestion.index];
                        final changes = <Widget>[
                          if (suggestion.word != original.word)
                            _buildReviewChange(
                              context,
                              '단어',
                              original.word,
                              suggestion.word,
                            ),
                          if (suggestion.meaning != original.meaning)
                            _buildReviewChange(
                              context,
                              '뜻',
                              original.meaning,
                              suggestion.meaning,
                            ),
                          if (suggestion.sentence !=
                              (original.exampleSentence ?? ''))
                            _buildReviewChange(
                              context,
                              '예문',
                              original.exampleSentence ?? '',
                              suggestion.sentence,
                            ),
                          if (suggestion.translation !=
                              (original.exampleSentenceTranslation ?? ''))
                            _buildReviewChange(
                              context,
                              '예문 해석',
                              original.exampleSentenceTranslation ?? '',
                              suggestion.translation,
                            ),
                        ];
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(original.word),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final change in changes) ...[
                                  change,
                                  const SizedBox(height: 6),
                                ],
                              ],
                            ),
                          ),
                          value: selected.contains(suggestion.index),
                          onChanged:
                              (value) => refresh(() {
                                if (value == true) {
                                  selected.add(suggestion.index);
                                } else {
                                  selected.remove(suggestion.index);
                                }
                              }),
                        );
                      },
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('취소'),
                    ),
                    FilledButton(
                      onPressed:
                          () => Navigator.pop(
                            dialogContext,
                            Set<int>.from(selected),
                          ),
                      child: Text(
                        selected.isEmpty
                            ? '변경 없이 완료'
                            : '${selected.length}개 반영',
                      ),
                    ),
                  ],
                ),
          ),
    );
  }

  Widget _buildReviewChange(
    BuildContext context,
    String label,
    String before,
    String after,
  ) {
    final theme = Theme.of(context);
    final beforeRunes = before.runes.toList();
    final afterRunes = after.runes.toList();
    var prefix = 0;
    while (prefix < beforeRunes.length &&
        prefix < afterRunes.length &&
        beforeRunes[prefix] == afterRunes[prefix]) {
      prefix++;
    }
    var suffix = 0;
    while (suffix < beforeRunes.length - prefix &&
        suffix < afterRunes.length - prefix &&
        beforeRunes[beforeRunes.length - 1 - suffix] ==
            afterRunes[afterRunes.length - 1 - suffix]) {
      suffix++;
    }
    String segment(List<int> runes, int start, int end) =>
        String.fromCharCodes(runes.sublist(start, end));
    final oldPart = segment(beforeRunes, prefix, beforeRunes.length - suffix);
    final newPart = segment(afterRunes, prefix, afterRunes.length - suffix);
    final leading = segment(beforeRunes, 0, prefix);
    final trailing = segment(
      beforeRunes,
      beforeRunes.length - suffix,
      beforeRunes.length,
    );
    final errorColor = theme.colorScheme.error;
    final correctedColor = theme.colorScheme.primary;
    final style = theme.textTheme.bodySmall;

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (before.isEmpty)
            const TextSpan(text: '미입력')
          else ...[
            TextSpan(text: leading),
            TextSpan(
              text: oldPart,
              style: TextStyle(
                color: errorColor,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.lineThrough,
                decorationColor: errorColor,
              ),
            ),
            TextSpan(text: trailing),
          ],
          const TextSpan(text: '  →  '),
          TextSpan(text: leading),
          TextSpan(
            text: newPart,
            style: TextStyle(
              color: correctedColor,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: trailing),
          if (after.isEmpty) const TextSpan(text: '없음'),
        ],
      ),
    );
  }

  Widget _buildLearningScopeNotice(ThemeData theme) {
    final plan = _studyPlan;
    if (plan == null) return const SizedBox.shrink();
    final taskLabel =
        widget.initialFocus == AiQuizSetupFocus.sentences ? '예문 생성' : 'AI 퀴즈';

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
            child: Icon(
              CupertinoIcons.calendar,
              color: theme.colorScheme.tertiary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.scopeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$taskLabel는 현재 학습 범위 ${_words.length}/$_totalWordCount개를 사용합니다. 범위 밖 새 단어 $_lockedNewWordCount개는 제외됩니다.',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final isSentenceMode = widget.initialFocus == AiQuizSetupFocus.sentences;
    final busy = _isLoading || _isGeneratingSentences || _isReviewingMeanings;
    final actionEnabled =
        !busy && _selectedWordbook != null && _selectedWordIds.isNotEmpty;

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(
        title: Text(isSentenceMode ? 'AI 예문·뜻 보강' : 'AI 퀴즈 생성'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiConnectionBar(onChange: _showAiSettingsSheet),
              const SizedBox(height: 12),
              _buildCompactWordbookPicker(theme),
              if (_studyPlan != null) ...[
                const SizedBox(height: 10),
                _buildLearningScopeNotice(theme),
              ],
              if (isSentenceMode) ...[
                const SizedBox(height: 22),
                _buildEnrichmentSummary(theme),
                const SizedBox(height: 20),
                _buildEnrichmentTaskSection(theme),
                const SizedBox(height: 18),
                _buildEnrichmentScopeSection(theme),
                if (_enrichmentScope == _AiEnrichmentScope.custom) ...[
                  const SizedBox(height: 18),
                  _buildWordSelectionSection(theme),
                ],
              ] else ...[
                const SizedBox(height: 22),
                _buildQuizScopeSection(theme),
                if (_quizScope == _AiQuizWordScope.custom) ...[
                  const SizedBox(height: 18),
                  _buildWordSelectionSection(theme),
                ],
                const SizedBox(height: 20),
                _buildCompactQuizSettings(theme),
              ],
              const SizedBox(height: 16),
              AiDisclosureRow(
                summary:
                    isSentenceMode
                        ? '선택한 단어 정보가 ${context.watch<AiSettingsProvider>().selectedProvider.shortLabel}로 전송됩니다.'
                        : '선택한 단어와 설정이 ${context.watch<AiSettingsProvider>().selectedProvider.shortLabel}로 전송됩니다.',
                detail:
                    'API 키는 기기의 보안 저장소에 보관됩니다. 생성 요청에는 현재 선택한 단어와 설정만 전달되며 사용자의 API 사용량이 소모될 수 있습니다.',
                expanded: _showDataNotice,
                onTap: () => setState(() => _showDataNotice = !_showDataNotice),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _buildErrorBox(theme),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: FilledButton.icon(
          onPressed:
              busy
                  ? null
                  : actionEnabled
                  ? () {
                    if (!isSentenceMode) {
                      _generateQuiz();
                    } else if (_enrichmentTask ==
                        _AiEnrichmentTask.missingExamples) {
                      _generateAllSentences();
                    } else {
                      _reviewMeanings();
                    }
                  }
                  : null,
          icon:
              busy
                  ? const _AiSparkleIcon(color: Colors.white, size: 22)
                  : const Icon(CupertinoIcons.sparkles),
          label: Text(_primaryActionLabel(isSentenceMode, busy)),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            disabledBackgroundColor: theme.colorScheme.primary,
            disabledForegroundColor: Colors.white,
            shape: const StadiumBorder(),
          ),
        ),
      ),
    );
  }

  String _primaryActionLabel(bool sentenceMode, bool busy) {
    if (busy) return sentenceMode ? 'AI 제안 생성 중...' : '문제 생성 중...';
    if (!sentenceMode) return 'AI 퀴즈 만들기';
    return switch (_enrichmentTask) {
      _AiEnrichmentTask.missingExamples => '${_selectedWordIds.length}개 제안 만들기',
      _AiEnrichmentTask.reviewMeanings => '${_selectedWordIds.length}개 뜻·오타 검토',
      _AiEnrichmentTask.refineExamples =>
        '${_selectedWordIds.length}개 예문·해석 검토',
    };
  }

  Widget _buildCompactWordbookPicker(ThemeData theme) {
    final identity = MemorizeIdentity.of(theme);
    return Material(
      color: identity.softContext,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        side: BorderSide(color: identity.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        onTap: () async {
          final selected = await showWordbookSelectionDialog(context);
          if (selected != null) await _onWordbookSelected(selected);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  CupertinoIcons.book_fill,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedWordbook?.name ?? '단어장을 선택해주세요',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _selectedWordbook == null
                          ? 'AI 학습에 사용할 단어장'
                          : '학습 가능 ${_words.length}개',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEnrichmentSummary(ThemeData theme) {
    final missingExamples =
        _words
            .where((word) => word.exampleSentence?.trim().isEmpty ?? true)
            .length;
    final missingTranslations =
        _words
            .where(
              (word) =>
                  (word.exampleSentence?.trim().isNotEmpty ?? false) &&
                  (word.exampleSentenceTranslation?.trim().isEmpty ?? true),
            )
            .length;
    final needsReview =
        _words
            .where(
              (word) => word.id != null && !_reviewedWordIds.contains(word.id),
            )
            .length;
    final total =
        <int>{
          ..._words
              .where(
                (word) =>
                    (word.exampleSentence?.trim().isEmpty ?? true) ||
                    (word.exampleSentenceTranslation?.trim().isEmpty ?? true) ||
                    (word.id != null && !_reviewedWordIds.contains(word.id)),
              )
              .map((word) => word.id ?? -1),
        }.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '보강이 필요한 단어 '),
              TextSpan(
                text: '$total개',
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ],
          ),
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildMetric(
                theme,
                CupertinoIcons.doc_text_fill,
                '빈 예문',
                missingExamples,
                theme.colorScheme.primary,
              ),
            ),
            Expanded(
              child: _buildMetric(
                theme,
                CupertinoIcons.exclamationmark_triangle_fill,
                '해석 없음',
                missingTranslations,
                theme.colorScheme.error,
              ),
            ),
            Expanded(
              child: _buildMetric(
                theme,
                CupertinoIcons.pencil,
                '검토 필요',
                needsReview,
                theme.colorScheme.tertiary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetric(
    ThemeData theme,
    IconData icon,
    String label,
    int value,
    Color color,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                '$value',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEnrichmentTaskSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '무엇을 보강할까요?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        _buildGroupedChoices<_AiEnrichmentTask>(
          theme: theme,
          value: _enrichmentTask,
          choices: const [
            (
              _AiEnrichmentTask.missingExamples,
              CupertinoIcons.doc_text,
              '빈 예문 채우기',
              '예문과 해석이 없는 단어만',
            ),
            (
              _AiEnrichmentTask.reviewMeanings,
              CupertinoIcons.search,
              '뜻·오타 검토',
              '단어와 뜻의 오류를 확인',
            ),
            (
              _AiEnrichmentTask.refineExamples,
              CupertinoIcons.sparkles,
              '예문·해석 다듬기',
              '기존 문장을 더 자연스럽게',
            ),
          ],
          onChanged:
              (value) => setState(() {
                _enrichmentTask = value;
                if (_enrichmentScope != _AiEnrichmentScope.custom) {
                  _syncAutomaticSelection();
                }
              }),
        ),
      ],
    );
  }

  Widget _buildEnrichmentScopeSection(ThemeData theme) {
    final labels = <_AiEnrichmentScope, String>{
      _AiEnrichmentScope.needed: '필요한 단어',
      _AiEnrichmentScope.today: '오늘 학습',
      _AiEnrichmentScope.custom: '직접 선택',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '대상 범위',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        SegmentedButton<_AiEnrichmentScope>(
          segments:
              labels.entries
                  .map(
                    (entry) => ButtonSegment(
                      value: entry.key,
                      label: Text(entry.value),
                    ),
                  )
                  .toList(),
          selected: {_enrichmentScope},
          showSelectedIcon: false,
          onSelectionChanged:
              (selection) => setState(() {
                _enrichmentScope = selection.first;
                _syncAutomaticSelection();
              }),
        ),
        const SizedBox(height: 8),
        Text(
          '${_selectedWordIds.length}개 단어 · AI 제안 확인 후 적용됩니다.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildQuizScopeSection(ThemeData theme) {
    final counts = <_AiQuizWordScope, int>{
      _AiQuizWordScope.today: _todayWords().length,
      _AiQuizWordScope.due: _dueWords().length,
      _AiQuizWordScope.mistakes: _mistakeWords().length,
      _AiQuizWordScope.custom: _selectedWordIds.length,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '어떤 단어로 만들까요?',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '퀴즈로 만들 단어 범위를 선택하세요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _buildGroupedChoices<_AiQuizWordScope>(
          theme: theme,
          value: _quizScope,
          choices: [
            (
              _AiQuizWordScope.today,
              CupertinoIcons.calendar_today,
              '오늘 학습',
              '오늘 예정된 학습과 복습 · ${counts[_AiQuizWordScope.today]}개',
            ),
            (
              _AiQuizWordScope.due,
              CupertinoIcons.arrow_2_circlepath,
              '복습 필요',
              '지금 다시 봐야 하는 단어 · ${counts[_AiQuizWordScope.due]}개',
            ),
            (
              _AiQuizWordScope.mistakes,
              CupertinoIcons.xmark_circle,
              '최근 오답',
              '다시 확인할 퀴즈 오답 · ${counts[_AiQuizWordScope.mistakes]}개',
            ),
            (
              _AiQuizWordScope.custom,
              CupertinoIcons.checkmark_square,
              '직접 선택',
              '원하는 단어를 직접 고릅니다.',
            ),
          ],
          onChanged:
              (value) => setState(() {
                _quizScope = value;
                _syncAutomaticSelection();
              }),
        ),
      ],
    );
  }

  Widget _buildGroupedChoices<T>({
    required ThemeData theme,
    required T value,
    required List<(T, IconData, String, String)> choices,
    required ValueChanged<T> onChanged,
  }) {
    final identity = MemorizeIdentity.of(theme);
    return Container(
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < choices.length; index++) ...[
            _buildChoiceRow<T>(
              theme,
              choices[index],
              value == choices[index].$1,
              onChanged,
            ),
            if (index != choices.length - 1)
              Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: theme.colorScheme.outline.withValues(alpha: 0.13),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoiceRow<T>(
    ThemeData theme,
    (T, IconData, String, String) choice,
    bool selected,
    ValueChanged<T> onChanged,
  ) {
    return Material(
      color:
          selected
              ? theme.colorScheme.primary.withValues(alpha: 0.08)
              : Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(choice.$1),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            children: [
              Icon(
                selected
                    ? CupertinoIcons.largecircle_fill_circle
                    : CupertinoIcons.circle,
                color:
                    selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
                size: 24,
              ),
              const SizedBox(width: 11),
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: (selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.secondary)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  choice.$2,
                  size: 19,
                  color:
                      selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      choice.$3,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      choice.$4,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactQuizSettings(ThemeData theme) {
    final difficultyProfile = AiDifficultyProfiles.forLevel(
      _difficulty.round(),
    );
    final difficulty = difficultyProfile.label;
    final identity = MemorizeIdentity.of(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '퀴즈 설정',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '문제 유형, 난이도와 문제 수를 설정하세요.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                    child: _buildQuickMenu<String>(
                      theme,
                      '문제 유형',
                      _selectedQuizType,
                      const ['종합', '어휘', '문법', '독해'],
                      (value) => setState(() => _selectedQuizType = value),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickMenu<int>(
                      theme,
                      '난이도',
                      difficulty,
                      List.generate(7, (index) => index + 1),
                      (value) => setState(() => _difficulty = value.toDouble()),
                      itemLabel:
                          (value) => AiDifficultyProfiles.forLevel(value).label,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickMenu<int>(
                      theme,
                      '문제 수',
                      '${_questionCount.round()}문제',
                      const [5, 10, 15, 20],
                      (value) =>
                          setState(() => _questionCount = value.toDouble()),
                      itemLabel: (value) => '$value문제',
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: Align(
                  key: ValueKey(_difficulty.round()),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    difficultyProfile.uiSummary,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const Divider(height: 22),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('해설 포함'),
                subtitle: const Text('문제마다 해설을 함께 생성합니다.'),
                value: _includeExplanation,
                onChanged:
                    (value) => setState(() => _includeExplanation = value),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(CupertinoIcons.slider_horizontal_3),
                title: const Text('세부 설정'),
                subtitle: Text(
                  '출제 언어 ${_questionLanguage == 'English' ? '영어' : '한국어'}',
                ),
                trailing: Icon(
                  _showAdvancedQuizSettings
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                ),
                onTap:
                    () => setState(
                      () =>
                          _showAdvancedQuizSettings =
                              !_showAdvancedQuizSettings,
                    ),
              ),
              if (_showAdvancedQuizSettings) ...[
                const SizedBox(height: 6),
                _buildLanguageSelector(),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${_selectedWordIds.length}개 단어를 중심으로 ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: '${_questionCount.round()}문제',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const TextSpan(text: '를 만듭니다.'),
              ],
            ),
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMenu<T>(
    ThemeData theme,
    String label,
    String valueLabel,
    List<T> values,
    ValueChanged<T> onSelected, {
    String Function(T value)? itemLabel,
  }) {
    return PopupMenuButton<T>(
      onSelected: onSelected,
      itemBuilder:
          (_) =>
              values
                  .map(
                    (value) => PopupMenuItem<T>(
                      value: value,
                      child: Text(itemLabel?.call(value) ?? value.toString()),
                    ),
                  )
                  .toList(),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.38,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    valueLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Icon(CupertinoIcons.chevron_down, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Kept temporarily for compatibility while the new setup layout settles.
  // ignore: unused_element
  Widget _buildSetupIntroCard(ThemeData theme) {
    final isSentenceMode = widget.initialFocus == AiQuizSetupFocus.sentences;
    final title = isSentenceMode ? '예문과 뜻 보강하기' : '단어장 맞춤 퀴즈 만들기';
    final subtitle =
        isSentenceMode ? '예문을 만들고 뜻·해석·오타를 검토합니다.' : '어휘, 문법, 독해 문제를 만듭니다.';
    final activeName = _selectedWordbook?.name ?? '단어장 선택 필요';

    return GlassmorphicCard(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Icon(
              isSentenceMode
                  ? CupertinoIcons.doc_text
                  : CupertinoIcons.sparkles,
              color: theme.colorScheme.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.42,
                  ),
                ),
                const SizedBox(height: 10),
                _buildCompactPill(
                  theme: theme,
                  icon: CupertinoIcons.book_fill,
                  label: activeName,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildSentenceGenerationCard(ThemeData theme) {
    final missingSentenceCount =
        _words
            .where(
              (word) =>
                  word.exampleSentence == null || word.exampleSentence!.isEmpty,
            )
            .length;

    return GlassmorphicCard(
      borderRadius: 26,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme: theme,
            icon: CupertinoIcons.doc_text_fill,
            title: '예문 생성 범위',
            subtitle: '빈 예문을 찾아 채웁니다.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCompactPill(
                theme: theme,
                icon: CupertinoIcons.book_fill,
                label: _selectedWordbook?.name ?? '단어장 없음',
                color: theme.colorScheme.primary,
              ),
              _buildCompactPill(
                theme: theme,
                icon: CupertinoIcons.text_badge_checkmark,
                label: '생성 대상 $missingSentenceCount개',
                color: theme.colorScheme.tertiary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '예문이 비어 있는 단어 $missingSentenceCount개를 채웁니다.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '생성한 예문은 플래시카드와 시험지에 활용됩니다.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            _buildErrorBox(theme),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon:
                  _isGeneratingSentences
                      ? const _AiSparkleIcon(color: Colors.white, size: 20)
                      : const Icon(CupertinoIcons.sparkles),
              label: Text(_isGeneratingSentences ? '예문 생성 중...' : '예문 생성 시작'),
              onPressed:
                  _isGeneratingSentences
                      ? null
                      : _selectedWordbook == null
                      ? null
                      : _generateAllSentences,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: theme.colorScheme.primary,
                disabledForegroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSelectionSection(ThemeData theme) {
    final isReview = widget.initialFocus == AiQuizSetupFocus.sentences;
    final visibleWords =
        isReview
            ? [
              ..._words.where((word) => !_reviewedWordIds.contains(word.id)),
              ..._words.where((word) => _reviewedWordIds.contains(word.id)),
            ]
            : _words;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          theme: theme,
          icon: CupertinoIcons.checkmark_square,
          title: isReview ? '뜻·예문 검토할 단어' : '출제 단어 선택',
          subtitle:
              isReview
                  ? '${_selectedWordIds.length}개 선택 · 검토 완료 ${_reviewedWordIds.length}/${_words.length}개 · 최대 20개'
                  : '${_selectedWordIds.length}/${_words.length}개 선택됨',
        ),
        const SizedBox(height: 10),
        GlassmorphicCard(
          borderRadius: 26,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildCompactPill(
                      theme: theme,
                      icon: CupertinoIcons.square_list_fill,
                      label: '사용 가능 ${_words.length}개',
                      color: theme.colorScheme.primary,
                    ),
                    TextButton(
                      onPressed: _onSelectAll,
                      child: Text(isReview ? '다음 미검토 20개' : '전체 선택'),
                    ),
                    TextButton(
                      onPressed: _onDeselectAll,
                      child: const Text('해제'),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 232,
                child:
                    _selectedWordbook == null
                        ? Center(
                          child: Text(
                            "먼저 학습할 단어장을 선택해주세요.",
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                        : _isLoading
                        ? _buildAiGeneratingWordsEffect(theme)
                        : _words.isEmpty
                        ? Center(
                          child: Text(
                            "단어장에 단어가 없습니다.",
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                        : ListView.builder(
                          itemCount: visibleWords.length,
                          itemBuilder: (context, index) {
                            final word = visibleWords[index];
                            return CheckboxListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      word.word,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                          ),
                                    ),
                                  ),
                                  if (isReview &&
                                      _reviewedWordIds.contains(word.id))
                                    Text(
                                      '검토 완료',
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                word.meaning,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              value: _selectedWordIds.contains(word.id),
                              onChanged: (bool? value) {
                                if (word.id == null) return;
                                if (isReview &&
                                    value == true &&
                                    _selectedWordIds.length >= 20) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        '한 번에 최대 20개까지 검토할 수 있습니다.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  if (value == true) {
                                    _selectedWordIds.add(word.id!);
                                  } else {
                                    _selectedWordIds.remove(word.id!);
                                  }
                                });
                              },
                            );
                          },
                        ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAiGeneratingWordsEffect(ThemeData theme) {
    final hasWords = _words.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.18),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AiSparkleIcon(color: theme.colorScheme.primary, size: 42),
              const SizedBox(height: 12),
              Text(
                hasWords ? 'AI가 문제를 만들고 있어요' : '단어장을 준비하고 있어요',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasWords
                    ? '단어와 난이도에 맞춰 선택지를 다듬는 중입니다.'
                    : '학습 가능 단어를 불러오는 중입니다.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    // ... (기존과 동일)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('출제 언어', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: CupertinoSlidingSegmentedControl<String>(
            groupValue: _questionLanguage,
            children: const {
              'English': Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('영어'),
              ),
              'Korean': Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('한국어'),
              ),
            },
            onValueChanged: (value) {
              if (value != null) {
                setState(() => _questionLanguage = value);
              }
            },
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildQuizTypeSelector() {
    // ... (기존과 동일)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('문제 유형', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children:
              ['종합', '어휘', '문법', '독해'].map((type) {
                return ChoiceChip(
                  label: Text(type),
                  selected: _selectedQuizType == type,
                  onSelected: (isSelected) {
                    if (isSelected) setState(() => _selectedQuizType = type);
                  },
                );
              }).toList(),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildAiBetaNotice(ThemeData theme) {
    final aiSettings = context.watch<AiSettingsProvider>();
    final fallbackText =
        aiSettings.autoFallbackEnabled
            ? '자동 대체가 켜져 있어 실패 시 다른 AI 제공자에도 순차적으로 요청할 수 있습니다.'
            : '자동 대체가 꺼져 있어 현재 선택한 AI 제공자에만 요청합니다.';

    return GlassmorphicCard(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.exclamationmark_shield,
              color: theme.colorScheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI 생성은 개인 API를 사용하는 베타 기능입니다',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '개인 API 키 등록이 필요하며 선택한 단어와 설정은 해당 제공업체로 전송됩니다. 무료 API·모델은 응답 지연, 시간 초과, 토큰·요청 한도가 있을 수 있으니 생성 결과를 학습 전에 확인해 주세요. $fallbackText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
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
    );
  }

  Widget _buildCompactPill({
    required ThemeData theme,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox(ThemeData theme) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.24),
        ),
      ),
      child: Text(
        _errorMessage ?? '',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildDifficultyAndCountSection() {
    // ... (기존과 동일)
    final difficultyIndex = (_difficulty.round() - 1).clamp(0, 6);
    final difficultyProfile = AiDifficultyProfiles.forLevel(
      _difficulty.round(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSlider(
          label: '난이도',
          value: _difficulty,
          min: 1,
          max: 7,
          divisions: 6,
          onChanged: (val) => setState(() => _difficulty = val),
          valueLabel: AiDifficultyProfiles.labels[difficultyIndex],
        ),
        const SizedBox(height: 6),
        Text(
          difficultyProfile.uiSummary,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        _buildSlider(
          label: '문제 수',
          value: _questionCount,
          min: 5,
          max: 20,
          divisions: 3,
          onChanged: (val) => setState(() => _questionCount = val),
          valueLabel: '${_questionCount.round()}문제',
        ),
        const Divider(height: 24),
        CheckboxListTile(
          title: const Text('해설 포함하여 문제 생성'),
          subtitle: const Text('API 사용량이 증가할 수 있습니다.'),
          value: _includeExplanation,
          onChanged: (val) => setState(() => _includeExplanation = val!),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 8),
        _buildAiUsageNotice(),
      ],
    );
  }

  Widget _buildAiUsageNotice() {
    final theme = Theme.of(context);
    final selectedCount = _selectedWordIds.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        '선택 단어 $selectedCount개와 문제 옵션이 외부 AI로 전송되며, 사용자의 API 사용량을 소모합니다. 안정적인 생성을 위해 한 번에 최대 20문제까지 생성합니다.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueLabel,
  }) {
    // ... (기존과 동일)
    return Row(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyLarge),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ),
        Text(
          valueLabel,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }
}

class _AiSparkleIcon extends StatefulWidget {
  final Color color;
  final double size;

  const _AiSparkleIcon({required this.color, required this.size});

  @override
  State<_AiSparkleIcon> createState() => _AiSparkleIconState();
}

class _AiSparkleIconState extends State<_AiSparkleIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse =
            _controller.value < 0.5
                ? _controller.value * 2
                : (1 - _controller.value) * 2;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 0.78 + (pulse * 0.18),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.13 + pulse * 0.10),
                  ),
                ),
              ),
              Transform.rotate(
                angle: _controller.value * 6.28318,
                child: Icon(
                  CupertinoIcons.sparkles,
                  size: widget.size * 0.66,
                  color: widget.color,
                ),
              ),
              Positioned(
                top: widget.size * 0.08,
                right: widget.size * 0.06,
                child: Opacity(
                  opacity: 0.35 + pulse * 0.65,
                  child: Icon(
                    CupertinoIcons.star_fill,
                    size: widget.size * 0.18,
                    color: widget.color,
                  ),
                ),
              ),
              Positioned(
                left: widget.size * 0.10,
                bottom: widget.size * 0.12,
                child: Opacity(
                  opacity: 0.25 + (1 - pulse) * 0.55,
                  child: Icon(
                    CupertinoIcons.star_fill,
                    size: widget.size * 0.13,
                    color: widget.color,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
