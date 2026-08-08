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
import '../services/analytics_service.dart';
import '../services/api_key_service.dart';
import '../services/mode_state_service.dart';
import '../utils/ai_error_utils.dart';
import '../widgets/ai_settings_card.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_button.dart';
import 'ai_quiz_player_screen.dart';

enum AiQuizSetupFocus { quiz, sentences }

class AiQuizSetupScreen extends StatefulWidget {
  final AiQuizSetupFocus initialFocus;

  const AiQuizSetupScreen({super.key, this.initialFocus = AiQuizSetupFocus.quiz});

  @override
  State<AiQuizSetupScreen> createState() => _AiQuizSetupScreenState();
}

class _AiQuizSetupScreenState extends State<AiQuizSetupScreen> {
  Wordbook? _selectedWordbook;
  StudyPlan? _studyPlan;
  List<Word> _words = [];
  final Set<int> _selectedWordIds = {};
  int _totalWordCount = 0;
  int _lockedNewWordCount = 0;

  String _selectedQuizType = '종합';
  double _difficulty = 3.0;
  double _questionCount = 10.0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _includeExplanation = false;
  bool _isGeneratingSentences = false;
  String _questionLanguage = 'English';

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
    });

    final wordbookManager = context.read<WordbookManager>();
    final modeStateService = context.read<ModeStateService>();
    await wordbookManager.setActiveWordbook(wordbook);

    final allWords = await wordbookManager.getAllWordsFrom(wordbook);
    final studyPlan = wordbookManager.planFor(wordbook);
    final words = wordbookManager.wordsAvailableForPlan(allWords, plan: studyPlan);
    final lockedNewWordCount = wordbookManager.lockedNewWordCount(allWords, plan: studyPlan);
    if (mounted) {
      setState(() {
        _studyPlan = studyPlan;
        _totalWordCount = allWords.length;
        _lockedNewWordCount = lockedNewWordCount;
        _words = words;
        _selectedWordIds.addAll(words.where((word) => word.id != null).map((word) => word.id!));
        _isLoading = false;
      });
    }

    await modeStateService.setLastUsedWordbookId(LearningMode.aiQuiz, wordbook.id!);
  }

  void _onSelectAll() => setState(
        () => _selectedWordIds.addAll(_words.where((w) => w.id != null).map((w) => w.id!)),
      );
  void _onDeselectAll() => setState(() => _selectedWordIds.clear());

  void _showAiSettingsSheet() {
    showModalBottomSheet<void>(
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
        _showAiSettingsSheet();
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

      final difficultyLabels = ['기초', '기본', '중급', '중고급', '고급', '최상급', '전문가'];
      final difficultyIndex = (_difficulty.round() - 1).clamp(0, 6);
      final difficultyText = difficultyLabels[difficultyIndex];
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
      if (quizResponse != null && quizResponse.questions.isNotEmpty && mounted) {
        context.read<AnalyticsService>().logAiGenerationCompleted(
          generationType: 'word_quiz',
          generatedCount: quizResponse.answerableQuestionCount,
          usedFallback: fallbackResult.usedOption.provider != aiSettings.selectedProvider,
        );
      }

      if (mounted) {
        if (quizResponse != null && quizResponse.questions.isNotEmpty) {
          if (fallbackResult.usedOption.provider != aiSettings.selectedProvider) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${fallbackResult.usedOption.provider.shortLabel} ${fallbackResult.usedOption.modelName} 모델로 자동 대체했습니다.',
                ),
              ),
            );
          }
          _showPartialGenerationNotice(quizResponse);
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => AiQuizPlayerScreen(quizResponse: quizResponse)));
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

    final wordsToUpdate =
        _words.where((w) => w.exampleSentence == null || w.exampleSentence!.isEmpty).toList();

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

      final fallbackResult = await aiService.generateSentencesForWordsWithFallback(
        wordsToUpdate,
        aiSettings.requestOptions(
          fallbackEnabled: aiSettings.autoFallbackEnabled,
        ),
      );
      aiSettings.recordUsedOption(fallbackResult.usedOption);
      final sentenceMap = fallbackResult.value;

      final updatedWords = <Word>[];
      for (final word in wordsToUpdate) {
        if (sentenceMap.containsKey(word.word)) {
          final sentenceData = sentenceMap[word.word]!;
          updatedWords.add(
            word.copyWith(
              exampleSentence: sentenceData['sentence'],
              exampleSentenceTranslation: sentenceData['translation'],
            ),
          );
        }
      }

      await wordbookManager.updateWordsInWordbook(_selectedWordbook!, updatedWords);
      if (mounted) {
        context.read<AnalyticsService>().logAiGenerationCompleted(
          generationType: 'example_sentences',
          generatedCount: updatedWords.length,
          usedFallback: fallbackResult.usedOption.provider != aiSettings.selectedProvider,
        );
      }
      final allWords = await wordbookManager.getAllWordsFrom(_selectedWordbook!);
      final newWords = wordbookManager.wordsAvailableForPlan(allWords, plan: _studyPlan);

      if (mounted) {
        setState(() {
          _words = newWords;
          _selectedWordIds
            ..clear()
            ..addAll(newWords.where((word) => word.id != null).map((word) => word.id!));
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
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

  Widget _buildLearningScopeNotice(ThemeData theme) {
    final plan = _studyPlan;
    if (plan == null) return const SizedBox.shrink();
    final totalDays = plan.estimatedTotalDays();
    final currentDay = totalDays == 0 ? 0 : plan.currentChunk().clamp(1, totalDays).toInt();
    final taskLabel = widget.initialFocus == AiQuizSetupFocus.sentences ? '예문 생성' : 'AI 퀴즈';

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
                  '$taskLabel는 열린 단어 ${_words.length}/$_totalWordCount개만 사용합니다. 잠긴 단어 $_lockedNewWordCount개는 아직 제외됩니다.',
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
    final isSentenceMode = widget.initialFocus == AiQuizSetupFocus.sentences;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(isSentenceMode ? 'AI 예문 생성' : 'AI 퀴즈 생성'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSetupIntroCard(theme),
              const SizedBox(height: 12),
              _buildAiBetaNotice(theme),
              const SizedBox(height: 14),
              WordbookSelectionButton(
                selectedWordbook: _selectedWordbook,
                onWordbookSelected: _onWordbookSelected,
                wordCount: _words.length,
              ),
              if (_studyPlan != null) ...[
                const SizedBox(height: 12),
                _buildLearningScopeNotice(theme),
              ],
              if (isSentenceMode) ...[
                const SizedBox(height: 18),
                _buildSentenceGenerationCard(theme),
              ] else ...[
                const SizedBox(height: 18),
                _buildWordSelectionSection(theme),
                const SizedBox(height: 16),
                _buildSectionTitle(
                  theme: theme,
                  icon: CupertinoIcons.slider_horizontal_3,
                  title: '퀴즈 옵션',
                  subtitle: '언어, 유형, 난이도와 문제 수를 정합니다.',
                ),
                const SizedBox(height: 10),
                GlassmorphicCard(
                  borderRadius: 26,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildLanguageSelector(),
                      const Divider(height: 24),
                      _buildQuizTypeSelector(),
                      const Divider(height: 24),
                      _buildDifficultyAndCountSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  _buildErrorBox(theme),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon:
                        _isLoading
                            ? _AiSparkleIcon(color: theme.colorScheme.onPrimary, size: 24)
                            : const Icon(CupertinoIcons.sparkles),
                    label: Text(_isLoading ? '문제 생성 중...' : 'AI 퀴즈 생성하기'),
                    onPressed: _isLoading || _selectedWordbook == null ? null : _generateQuiz,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupIntroCard(ThemeData theme) {
    final isSentenceMode = widget.initialFocus == AiQuizSetupFocus.sentences;
    final title = isSentenceMode ? '예문과 번역 채우기' : '단어장 맞춤 퀴즈 만들기';
    final subtitle =
        isSentenceMode
            ? '빈 예문과 번역을 채웁니다.'
            : '어휘, 문법, 독해 문제를 만듭니다.';
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
              isSentenceMode ? CupertinoIcons.doc_text : CupertinoIcons.sparkles,
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
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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

  Widget _buildSentenceGenerationCard(ThemeData theme) {
    final missingSentenceCount =
        _words.where((word) => word.exampleSentence == null || word.exampleSentence!.isEmpty).length;

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
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                      ? _AiSparkleIcon(color: theme.colorScheme.onPrimary, size: 20)
                      : const Icon(CupertinoIcons.sparkles),
              label: Text(_isGeneratingSentences ? '예문 생성 중...' : '예문 생성 시작'),
              onPressed:
                  _isGeneratingSentences || _selectedWordbook == null
                      ? null
                      : _generateAllSentences,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWordSelectionSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          theme: theme,
          icon: CupertinoIcons.checkmark_square,
          title: '출제 단어 선택',
          subtitle: '${_selectedWordIds.length}/${_words.length}개 선택됨',
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
                    TextButton(onPressed: _onSelectAll, child: const Text('전체 선택')),
                    TextButton(onPressed: _onDeselectAll, child: const Text('해제')),
                  ],
                ),
              ),
              SizedBox(
                height: 232,
                child:
                    _selectedWordbook == null
                        ? Center(
                          child: Text("먼저 학습할 단어장을 선택해주세요.", style: theme.textTheme.bodyMedium),
                        )
                        : _isLoading
                        ? _buildAiGeneratingWordsEffect(theme)
                        : _words.isEmpty
                        ? Center(child: Text("단어장에 단어가 없습니다.", style: theme.textTheme.bodyMedium))
                        : ListView.builder(
                          itemCount: _words.length,
                          itemBuilder: (context, index) {
                            final word = _words[index];
                            return CheckboxListTile(
                              title: Text(
                                word.word,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              subtitle: Text(
                                word.meaning,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              value: _selectedWordIds.contains(word.id),
                              onChanged: (bool? value) {
                                if (word.id == null) return;
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
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
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
              'English': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('영어')),
              'Korean': Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('한국어')),
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
                  'AI 생성 기능은 베타입니다',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '선택한 단어, 뜻, 예문 정보가 외부 AI 제공자에게 전송됩니다. 생성된 문제와 해설은 틀릴 수 있으니 학습 전 확인하세요. $fallbackText',
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
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
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
        border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.24)),
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

  Widget _buildDifficultyAndCountSection() {
    // ... (기존과 동일)
    final difficultyLabels = ['기초', '기본', '중급', '중고급', '고급', '최상급', '전문가'];
    final difficultyIndex = (_difficulty.round() - 1).clamp(0, 6);

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
          valueLabel: difficultyLabels[difficultyIndex],
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
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.16)),
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
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).primaryColor),
        ),
      ],
    );
  }
}

class _AiSparkleIcon extends StatefulWidget {
  final Color color;
  final double size;

  const _AiSparkleIcon({
    required this.color,
    required this.size,
  });

  @override
  State<_AiSparkleIcon> createState() => _AiSparkleIconState();
}

class _AiSparkleIconState extends State<_AiSparkleIcon> with SingleTickerProviderStateMixin {
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
        final pulse = _controller.value < 0.5
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
