import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../models/grammar_curriculum.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/ai_difficulty_profile.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/api_key_service.dart';
import '../themes/memorize_identity.dart';
import '../utils/ai_error_utils.dart';
import '../widgets/ai_setup_widgets.dart';
import '../widgets/ai_settings_card.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_button.dart';
import 'ai_quiz_player_screen.dart';

class AiGrammarQuizSetupScreen extends StatefulWidget {
  const AiGrammarQuizSetupScreen({super.key});

  @override
  State<AiGrammarQuizSetupScreen> createState() =>
      _AiGrammarQuizSetupScreenState();
}

class _AiGrammarQuizSetupScreenState extends State<AiGrammarQuizSetupScreen> {
  Wordbook? _selectedWordbook;
  List<Word> _words = [];
  bool _isLoadingWords = false;
  int? _selectedCategoryIndex;
  final Set<GrammarChapter> _selectedChapters = {};
  String? _expandedTopic;
  bool _showDetailedChapters = false;
  double _questionCount = 10.0;
  bool _isLoading = false;
  String? _errorMessage;
  double _difficulty = 3.0;
  bool _includeExplanation = false;
  String _questionLanguage = 'English';
  bool _showDataNotice = false;
  int _grammarStep = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeWordbook = context.read<WordbookManager>().activeWordbook;
      if (activeWordbook != null) _onWordbookSelected(activeWordbook);
    });
  }

  Widget _buildGrammarJourney(ThemeData theme) {
    const labels = ['과정', '주제', '세부 주제', '문제 설정'];
    return Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap:
                  index <= _furthestAvailableGrammarStep()
                      ? () => setState(() => _grammarStep = index)
                      : null,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color:
                          index <= _grammarStep
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color:
                            index <= _grammarStep
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    labels[index],
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          index <= _grammarStep
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (index != labels.length - 1)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.only(bottom: 27),
                color:
                    index < _grammarStep
                        ? theme.colorScheme.primary.withValues(alpha: 0.48)
                        : theme.colorScheme.outline.withValues(alpha: 0.18),
              ),
            ),
        ],
      ],
    );
  }

  int _furthestAvailableGrammarStep() {
    if (_selectedCategoryIndex == null) return 0;
    if (_expandedTopic == null) return 1;
    if (_selectedChapters.isEmpty) return 2;
    return 3;
  }

  // ignore: unused_element
  Widget _buildSelectedCurriculum(ThemeData theme, GrammarCategory category) {
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap:
            () => setState(() {
              _selectedCategoryIndex = null;
              _selectedChapters.clear();
              _expandedTopic = null;
            }),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  CupertinoIcons.book_fill,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '과정 변경',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.chevron_right,
                size: 17,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildTopicAccordionSection(
    ThemeData theme,
    Map<String, List<GrammarChapter>> groupedTopics,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '주제와 세부 주제를 골라주세요',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '주제를 누르면 세부 항목이 바로 펼쳐집니다.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.76),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.16),
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (
                var index = 0;
                index < groupedTopics.entries.length;
                index++
              ) ...[
                _buildTopicAccordionItem(
                  theme,
                  groupedTopics.entries.elementAt(index),
                ),
                if (index != groupedTopics.entries.length - 1)
                  Divider(
                    height: 1,
                    color: theme.colorScheme.outline.withValues(alpha: 0.13),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopicStep(
    ThemeData theme,
    Map<String, List<GrammarChapter>> groupedTopics,
  ) {
    final identity = MemorizeIdentity.of(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '문법 주제를 선택하세요',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '주제를 선택하면 다음 단계에서 세부 범위를 고를 수 있어요.',
          style: theme.textTheme.bodyMedium?.copyWith(color: identity.mutedInk),
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
            children:
                groupedTopics.entries.map((entry) {
                  final selected = _expandedTopic == entry.key;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: identity.softContext,
                    leading: Icon(
                      selected
                          ? CupertinoIcons.check_mark_circled_solid
                          : CupertinoIcons.circle,
                      color:
                          selected ? identity.primaryAction : identity.mutedInk,
                    ),
                    title: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text('${entry.value.length}개 세부 주제'),
                    trailing: const Icon(
                      CupertinoIcons.chevron_right,
                      size: 17,
                    ),
                    onTap:
                        () => setState(() {
                          _expandedTopic = entry.key;
                          _selectedChapters.removeWhere(
                            (chapter) => grammarTopicFor(chapter) != entry.key,
                          );
                          _grammarStep = 2;
                        }),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtopicStep(ThemeData theme, List<GrammarChapter> chapters) {
    final identity = MemorizeIdentity.of(theme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _expandedTopic ?? '세부 주제',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: identity.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '출제할 세부 주제를 하나 이상 선택하세요.',
          style: theme.textTheme.bodyMedium?.copyWith(color: identity.mutedInk),
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
            children:
                chapters.map((chapter) {
                  final selected = _selectedChapters.contains(chapter);
                  return CheckboxListTile(
                    value: selected,
                    activeColor: identity.primaryAction,
                    title: Text(
                      chapter.title,
                      style: TextStyle(
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                    onChanged:
                        (_) => setState(() {
                          selected
                              ? _selectedChapters.remove(chapter)
                              : _selectedChapters.add(chapter);
                        }),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsStep(ThemeData theme) {
    final profile = AiDifficultyProfiles.forLevel(_difficulty.round());
    final identity = MemorizeIdentity.of(theme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '문제 설정',
            style: theme.textTheme.titleLarge?.copyWith(
              color: identity.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '난이도 · ${profile.label}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            value: _difficulty,
            min:
                grammarCurriculum[_selectedCategoryIndex!].minDifficulty
                    .toDouble(),
            max:
                grammarCurriculum[_selectedCategoryIndex!].maxDifficulty
                    .toDouble(),
            divisions:
                grammarCurriculum[_selectedCategoryIndex!].maxDifficulty -
                grammarCurriculum[_selectedCategoryIndex!].minDifficulty,
            label: profile.label,
            onChanged: (value) => setState(() => _difficulty = value),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: Text(
              profile.uiSummary,
              key: ValueKey(profile.level),
              style: theme.textTheme.bodySmall?.copyWith(
                color: identity.mutedInk,
                height: 1.4,
              ),
            ),
          ),
          const Divider(height: 28),
          Text(
            '문제 수 · ${_questionCount.round()}문제',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          Slider(
            value: _questionCount,
            min: 5,
            max: 20,
            divisions: 3,
            label: '${_questionCount.round()}문제',
            onChanged: (value) => setState(() => _questionCount = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('해설 포함'),
            subtitle: const Text('정답과 함께 이유를 보여줍니다.'),
            value: _includeExplanation,
            onChanged: (value) => setState(() => _includeExplanation = value),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicAccordionItem(
    ThemeData theme,
    MapEntry<String, List<GrammarChapter>> entry,
  ) {
    final expanded = _expandedTopic == entry.key;
    final selectedCount = entry.value.where(_selectedChapters.contains).length;
    return Column(
      children: [
        Material(
          color:
              expanded
                  ? theme.colorScheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
          child: InkWell(
            onTap:
                () => setState(
                  () => _expandedTopic = expanded ? null : entry.key,
                ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: (expanded
                              ? theme.colorScheme.primary
                              : theme.colorScheme.secondary)
                          .withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      CupertinoIcons.square_stack_3d_up_fill,
                      size: 18,
                      color:
                          expanded
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Text(
                    selectedCount == 0
                        ? '${entry.value.length}개'
                        : '$selectedCount/${entry.value.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color:
                          selectedCount > 0
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 17,
                    color:
                        expanded
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState:
              expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.23,
            ),
            padding: const EdgeInsets.fromLTRB(15, 4, 15, 8),
            child: Column(
              children:
                  entry.value.map((chapter) {
                    final selected = _selectedChapters.contains(chapter);
                    return CheckboxListTile(
                      value: selected,
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 30),
                      title: Text(
                        chapter.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      onChanged:
                          (_) => setState(() {
                            selected
                                ? _selectedChapters.remove(chapter)
                                : _selectedChapters.add(chapter);
                          }),
                    );
                  }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildCompactGrammarSettings(ThemeData theme) {
    final category = grammarCurriculum[_selectedCategoryIndex!];
    final topics = _selectedChapters.map(grammarTopicFor).toSet();
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showGrammarSettingsSheet(theme),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.doc_text_fill,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${category.title} · ${topics.length}개 주제 · ${_selectedChapters.length}개 세부 주제',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_questionCount.round()}문제 · ${_difficultyLabel()} · ${_includeExplanation ? '해설 포함' : '해설 없음'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '문제 설정 변경',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 3),
              Icon(
                CupertinoIcons.chevron_right,
                size: 15,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showGrammarSettingsSheet(ThemeData theme) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (sheetContext) => StatefulBuilder(
            builder: (sheetContext, refresh) {
              final category = grammarCurriculum[_selectedCategoryIndex!];
              return SafeArea(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    0,
                    18,
                    16 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '문제 설정',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '출제 언어',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'English', label: Text('영어')),
                            ButtonSegment(value: 'Korean', label: Text('한국어')),
                          ],
                          selected: {_questionLanguage},
                          showSelectedIcon: false,
                          onSelectionChanged:
                              (selection) => refresh(
                                () => _questionLanguage = selection.first,
                              ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          '난이도 · ${_difficultyLabel()}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Slider(
                          value: _difficulty,
                          min: category.minDifficulty.toDouble(),
                          max: category.maxDifficulty.toDouble(),
                          divisions:
                              category.maxDifficulty - category.minDifficulty,
                          label: _difficultyLabel(),
                          onChanged:
                              (value) => refresh(() => _difficulty = value),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '문제 수 · ${_questionCount.round()}문제',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Slider(
                          value: _questionCount,
                          min: 5,
                          max: 20,
                          divisions: 3,
                          label: '${_questionCount.round()}문제',
                          onChanged:
                              (value) => refresh(() => _questionCount = value),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('해설 포함'),
                          subtitle: const Text('정답 확인 화면에서 이유를 함께 보여줍니다.'),
                          value: _includeExplanation,
                          onChanged:
                              (value) =>
                                  refresh(() => _includeExplanation = value),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            child: const Text('설정 완료'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _onWordbookSelected(Wordbook wordbook) async {
    setState(() {
      _selectedWordbook = wordbook;
      _words = [];
      _isLoadingWords = true;
    });
    try {
      final manager = context.read<WordbookManager>();
      await manager.setActiveWordbook(wordbook);
      final allWords = await manager.getAllWordsFrom(wordbook);
      final plan = manager.planFor(wordbook);
      final availableWords = manager.wordsAvailableForPlan(
        allWords,
        plan: plan,
      );
      if (mounted) setState(() => _words = availableWords);
    } finally {
      if (mounted) setState(() => _isLoadingWords = false);
    }
  }

  // Kept temporarily for compatibility while the new accordion layout settles.
  // ignore: unused_element
  Map<String, List<GrammarChapter>> _getGroupedChapters() {
    if (_selectedCategoryIndex == null) return {};
    final chapters = grammarCurriculum[_selectedCategoryIndex!].chapters;
    final Map<String, List<GrammarChapter>> groupedChapters = {};
    for (final chapter in chapters) {
      (groupedChapters[chapter.description] ??= []).add(chapter);
    }
    return groupedChapters;
  }

  Future<void> _selectAllChapters(List<GrammarChapter> chapters) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('전체 문법 범위 선택'),
            content: Text(
              '${chapters.length}개 챕터를 범위로 지정하면 ${_questionCount.round()}문제에는 '
              '그중 일부 챕터만 출제됩니다. 계속할까요?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('전체 선택'),
              ),
            ],
          ),
    );
    if (!mounted || confirmed != true) return;
    setState(() {
      _selectedChapters
        ..clear()
        ..addAll(chapters);
    });
  }

  Future<void> _generateQuiz() async {
    if (_selectedWordbook == null || _words.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습 중인 단어장과 사용 가능한 단어가 필요합니다.')),
      );
      return;
    }
    if (_selectedCategoryIndex == null || _selectedChapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('학습할 레벨과 챕터를 1개 이상 선택해주세요.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    context.read<AnalyticsService>().logAiGenerationStarted(
      generationType: 'grammar_quiz',
      requestedCount: _questionCount.round(),
    );

    try {
      final selectedCategory = grammarCurriculum[_selectedCategoryIndex!];
      final aiService = context.read<AiService>();
      final aiSettings = context.read<AiSettingsProvider>();

      final difficultyIndex = (_difficulty.round() - 1).clamp(0, 6);
      final difficultyText = AiDifficultyProfiles.labels[difficultyIndex];

      final fallbackResult = await aiService.generateGrammarQuizWithFallback(
        options: aiSettings.requestOptions(
          fallbackEnabled: aiSettings.autoFallbackEnabled,
        ),
        category: selectedCategory,
        chapters: _selectedChapters.toList(),
        questionCount: _questionCount.round(),
        difficulty: difficultyText,
        includeExplanation: _includeExplanation,
        questionLanguage: _questionLanguage,
        selectedWords: _words,
      );
      aiSettings.recordUsedOption(fallbackResult.usedOption);
      final AiQuizResponse? quizResponse = fallbackResult.value;
      if (quizResponse != null &&
          quizResponse.questions.isNotEmpty &&
          mounted) {
        context.read<AnalyticsService>().logAiGenerationCompleted(
          generationType: 'grammar_quiz',
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
    } on CustomApiException catch (e) {
      await _handleApiError(e);
    } catch (e) {
      await _handleApiError(e);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAiSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder:
          (_) => const SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: SingleChildScrollView(child: AiSettingsCard()),
            ),
          ),
    );
  }

  Future<void> _handleApiError(Object e) async {
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
    } else {
      setState(() => _errorMessage = message);
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final identity = MemorizeIdentity.of(theme);
    final selectedCategory =
        _selectedCategoryIndex == null
            ? null
            : grammarCurriculum[_selectedCategoryIndex!];
    final groupedTopics =
        selectedCategory == null
            ? <String, List<GrammarChapter>>{}
            : groupGrammarTopics(selectedCategory);
    final canGenerate =
        !_isLoading &&
        !_isLoadingWords &&
        _selectedWordbook != null &&
        _selectedChapters.isNotEmpty;
    final selectedTopicChapters =
        _expandedTopic == null
            ? const <GrammarChapter>[]
            : groupedTopics[_expandedTopic] ?? const <GrammarChapter>[];
    final canContinue = switch (_grammarStep) {
      0 => selectedCategory != null,
      1 => _expandedTopic != null,
      2 => _selectedChapters.isNotEmpty,
      _ => canGenerate,
    };

    return Scaffold(
      backgroundColor: identity.canvas,
      appBar: AppBar(
        title: const Text('문법 문제 생성'),
        leading: CloseButton(onPressed: () => Navigator.maybePop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AiConnectionBar(onChange: _showAiSettingsSheet),
              const SizedBox(height: 12),
              WordbookSelectionButton(
                selectedWordbook: _selectedWordbook,
                onWordbookSelected: _onWordbookSelected,
                wordCount: _words.length,
              ),
              const SizedBox(height: 20),
              _buildGrammarJourney(theme),
              const SizedBox(height: 20),
              if (_grammarStep == 0)
                _buildGrammarLevelSection(theme, selectedCategory)
              else if (_grammarStep == 1)
                _buildTopicStep(theme, groupedTopics)
              else if (_grammarStep == 2)
                _buildSubtopicStep(theme, selectedTopicChapters)
              else
                _buildSettingsStep(theme),
              const SizedBox(height: 14),
              AiDisclosureRow(
                summary:
                    '문법 범위와 학습 단어가 ${context.watch<AiSettingsProvider>().selectedProvider.shortLabel}로 전송됩니다.',
                detail:
                    '선택한 문법 과정·주제·세부 주제와 현재 단어장의 학습 가능 단어만 전송합니다. API 키는 기기의 보안 저장소에 보관되며 사용자 API 사용량이 소모될 수 있습니다.',
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
        child: Row(
          children: [
            if (_grammarStep > 0) ...[
              OutlinedButton.icon(
                onPressed:
                    _isLoading ? null : () => setState(() => _grammarStep--),
                icon: const Icon(CupertinoIcons.chevron_left, size: 18),
                label: const Text('이전'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(104, 56),
                  foregroundColor: identity.ink,
                  side: BorderSide(color: identity.border),
                  shape: const StadiumBorder(),
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: FilledButton.icon(
                onPressed:
                    _isLoading
                        ? null
                        : canContinue
                        ? () {
                          if (_grammarStep < 3) {
                            setState(() => _grammarStep++);
                          } else {
                            _generateQuiz();
                          }
                        }
                        : null,
                icon:
                    _isLoading
                        ? const _AiSparkleIcon(color: Colors.white, size: 22)
                        : const Icon(CupertinoIcons.sparkles),
                label: Text(
                  _isLoading
                      ? '문제 생성 중...'
                      : _grammarStep < 3
                      ? '다음 단계'
                      : '문법 문제 만들기',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  disabledBackgroundColor: theme.colorScheme.primary,
                  disabledForegroundColor: Colors.white,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ],
        ),
      ),
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
                  '개인 API 키 등록이 필요하며 선택한 문법 범위와 설정은 해당 제공업체로 전송됩니다. 무료 API·모델은 응답 지연, 시간 초과, 토큰·요청 한도가 있을 수 있으니 생성 결과를 학습 전에 확인해 주세요. $fallbackText',
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

  Widget _buildGrammarLevelSection(
    ThemeData theme,
    GrammarCategory? selectedCategory,
  ) {
    final identity = MemorizeIdentity.of(theme);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: identity.surface,
        borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
        border: Border.all(color: identity.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme: theme,
            icon: CupertinoIcons.square_grid_2x2_fill,
            title: '문법 과정',
            subtitle:
                selectedCategory?.description ?? '중학교·고등학교·토익 과정 중 하나를 선택하세요.',
          ),
          const SizedBox(height: 14),
          ...List.generate(grammarCurriculum.length, (index) {
            final category = grammarCurriculum[index];
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == grammarCurriculum.length - 1 ? 0 : 10,
              ),
              child: _buildLevelTile(
                theme: theme,
                category: category,
                index: index,
                selected: _selectedCategoryIndex == index,
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLevelTile({
    required ThemeData theme,
    required GrammarCategory category,
    required int index,
    required bool selected,
  }) {
    final accent =
        selected ? theme.colorScheme.primary : theme.colorScheme.outline;
    return InkWell(
      borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
          _selectedChapters.clear();
          _expandedTopic = null;
          _difficulty =
              _difficulty
                  .clamp(
                    category.minDifficulty.toDouble(),
                    category.maxDifficulty.toDouble(),
                  )
                  .toDouble();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
        decoration: BoxDecoration(
          color:
              selected
                  ? Color.alphaBlend(
                    theme.colorScheme.primary.withValues(alpha: 0.11),
                    theme.colorScheme.surface,
                  )
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.34,
                  ),
          borderRadius: BorderRadius.circular(MemorizeIdentity.cardRadius),
          border: Border.all(
            color:
                selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.44)
                    : theme.colorScheme.outline.withValues(alpha: 0.18),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(
                alpha: selected ? 0.10 : 0.05,
              ),
              blurRadius: selected ? 18 : 10,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: selected ? 0.14 : 0.07),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                selected
                    ? CupertinoIcons.checkmark_seal_fill
                    : CupertinoIcons.book,
                color: accent,
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
                          category.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildSmallBadge(
                        theme: theme,
                        label: '${category.chapters.length}개',
                        color:
                            selected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildChapterSection(
    ThemeData theme,
    Map<String, List<GrammarChapter>> groupedTopics,
    Map<String, List<GrammarChapter>> groupedChapters,
    List<String> groupKeys,
  ) {
    final totalChapters = groupedChapters.values.fold<int>(
      0,
      (sum, chapters) => sum + chapters.length,
    );
    return GlassmorphicCard(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme: theme,
            icon: CupertinoIcons.checkmark_square_fill,
            title: '문법 주제 선택',
            subtitle: '${_selectedChapters.length}개 챕터 선택 · 전체 $totalChapters개',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      () => _selectAllChapters(
                        groupedChapters.values
                            .expand((chapters) => chapters)
                            .toList(),
                      ),
                  icon: const Icon(
                    CupertinoIcons.checkmark_alt_circle,
                    size: 18,
                  ),
                  label: const Text('전체 선택'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _selectedChapters.isEmpty
                          ? null
                          : () => setState(() => _selectedChapters.clear()),
                  icon: const Icon(CupertinoIcons.clear_circled, size: 18),
                  label: const Text('선택 해제'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...groupedTopics.entries.map((entry) {
            final chapters = entry.value;
            final selectedCount =
                chapters.where(_selectedChapters.contains).length;
            final allSelected = selectedCount == chapters.length;
            return Column(
              children: [
                CheckboxListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  title: Text(entry.key),
                  subtitle: Text('$selectedCount / ${chapters.length}개 세부 챕터'),
                  tristate: true,
                  value:
                      allSelected
                          ? true
                          : selectedCount == 0
                          ? false
                          : null,
                  onChanged:
                      (_) => _toggleChapterGroup(
                        chapters,
                        selectAll: !allSelected,
                      ),
                ),
                const Divider(height: 1),
              ],
            );
          }),
          if (_selectedChapters.length > _questionCount.round() * 2) ...[
            const SizedBox(height: 10),
            Text(
              '선택 범위가 넓어 이번 퀴즈에는 일부 챕터만 출제됩니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed:
                () => setState(
                  () => _showDetailedChapters = !_showDetailedChapters,
                ),
            icon: Icon(
              _showDetailedChapters
                  ? CupertinoIcons.chevron_up
                  : CupertinoIcons.chevron_down,
            ),
            label: Text(_showDetailedChapters ? '세부 선택 접기' : '세부 챕터 선택'),
          ),
          if (_showDetailedChapters) ...[
            const SizedBox(height: 8),
            ...groupKeys.map((groupTitle) {
              final chapters = groupedChapters[groupTitle]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildChapterGroupCard(theme, groupTitle, chapters),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildChapterGroupCard(
    ThemeData theme,
    String groupTitle,
    List<GrammarChapter> chapters,
  ) {
    final selectedCount = chapters.where(_selectedChapters.contains).length;
    final allSelected = selectedCount == chapters.length;
    final hasSelection = selectedCount > 0;
    final accent =
        allSelected
            ? theme.colorScheme.primary
            : hasSelection
            ? theme.colorScheme.secondary
            : theme.colorScheme.outline;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color:
            hasSelection
                ? Color.alphaBlend(
                  accent.withValues(alpha: 0.08),
                  theme.colorScheme.surface,
                )
                : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.32,
                ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: hasSelection ? 0.36 : 0.18),
          width: hasSelection ? 1.3 : 1,
        ),
      ),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          iconColor: accent,
          collapsedIconColor: theme.colorScheme.onSurfaceVariant,
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: hasSelection ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  CupertinoIcons.layers_alt_fill,
                  color: accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$selectedCount / ${chapters.length}개 선택',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _buildSmallBadge(
                theme: theme,
                label:
                    allSelected
                        ? '완료'
                        : selectedCount == 0
                        ? '선택'
                        : '$selectedCount개',
                color: accent,
              ),
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed:
                    () =>
                        _toggleChapterGroup(chapters, selectAll: !allSelected),
                icon: Icon(
                  allSelected
                      ? CupertinoIcons.minus_circle
                      : CupertinoIcons.plus_circle,
                  size: 17,
                ),
                label: Text(allSelected ? '이 그룹 해제' : '이 그룹 선택'),
              ),
            ),
            const SizedBox(height: 4),
            ...chapters.map((chapter) => _buildChapterTile(theme, chapter)),
          ],
        ),
      ),
    );
  }

  void _toggleChapterGroup(
    List<GrammarChapter> chapters, {
    required bool selectAll,
  }) {
    setState(() {
      if (selectAll) {
        _selectedChapters.addAll(chapters);
      } else {
        _selectedChapters.removeAll(chapters);
      }
    });
  }

  Widget _buildChapterTile(ThemeData theme, GrammarChapter chapter) {
    final selected = _selectedChapters.contains(chapter);
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          setState(() {
            if (selected) {
              _selectedChapters.remove(chapter);
            } else {
              _selectedChapters.add(chapter);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color:
                selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.10)
                    : theme.colorScheme.surface.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: selected ? 0.34 : 0.13),
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                color: color,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  chapter.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildQuizOptionsSection(ThemeData theme) {
    final category = grammarCurriculum[_selectedCategoryIndex!];
    return GlassmorphicCard(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme: theme,
            icon: CupertinoIcons.slider_horizontal_3,
            title: '퀴즈 옵션',
            subtitle:
                '${_questionCount.round()}문제 · ${_difficultyLabel()} · ${_questionLanguage == 'English' ? '영어' : '한국어'}',
          ),
          const SizedBox(height: 14),
          _buildLanguageSelector(),
          const SizedBox(height: 14),
          _buildOptionControlCard(
            theme: theme,
            icon: CupertinoIcons.speedometer,
            title: '난이도',
            valueLabel: _difficultyLabel(),
            child: _buildSlider(
              label: '난이도',
              value: _difficulty,
              min: category.minDifficulty.toDouble(),
              max: category.maxDifficulty.toDouble(),
              divisions: category.maxDifficulty - category.minDifficulty,
              valueLabel: _difficultyLabel(),
              onChanged: (value) => setState(() => _difficulty = value),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AiDifficultyProfiles.forLevel(_difficulty.round()).uiSummary,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          _buildOptionControlCard(
            theme: theme,
            icon: CupertinoIcons.question_circle,
            title: '문제 수',
            valueLabel: '${_questionCount.round()}문제',
            child: _buildSlider(
              label: '문제 수',
              value: _questionCount,
              min: 5,
              max: 20,
              divisions: 3,
              valueLabel: '${_questionCount.round()}문제',
              onChanged: (value) => setState(() => _questionCount = value),
            ),
          ),
          const SizedBox(height: 10),
          _buildExplanationToggle(theme),
          const SizedBox(height: 10),
          _buildAiUsageNotice(theme),
        ],
      ),
    );
  }

  Widget _buildAiUsageNotice(ThemeData theme) {
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
        '학습 중인 단어장 단어와 선택한 문법 범위·옵션이 외부 AI로 전송됩니다. 모든 문제는 해당 단어를 포함하도록 생성·검증하며, 한 번에 최대 20문제까지 생성합니다.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          height: 1.35,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOptionControlCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String valueLabel,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.34,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _buildSmallBadge(
                theme: theme,
                label: valueLabel,
                color: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _buildExplanationToggle(ThemeData theme) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _includeExplanation = !_includeExplanation),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color:
              _includeExplanation
                  ? theme.colorScheme.primary.withValues(alpha: 0.11)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.34,
                  ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                _includeExplanation
                    ? theme.colorScheme.primary.withValues(alpha: 0.36)
                    : theme.colorScheme.outline.withValues(alpha: 0.14),
          ),
        ),
        child: Row(
          children: [
            Icon(
              _includeExplanation
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.lightbulb,
              color:
                  _includeExplanation
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '해설 포함',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '정답 확인 화면에서 이유를 함께 보여줍니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _includeExplanation,
              onChanged: (value) => setState(() => _includeExplanation = value),
            ),
          ],
        ),
      ),
    );
  }

  String _difficultyLabel() {
    return AiDifficultyProfiles.forLevel(_difficulty.round()).label;
  }

  Widget _buildSmallBadge({
    required ThemeData theme,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  // ignore: unused_element
  Widget _buildIntroCard(ThemeData theme) {
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
              CupertinoIcons.textformat_alt,
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
                  '문법 범위로 AI 퀴즈 생성',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '레벨과 챕터를 고르면 AI가 해당 범위의 문법 문제를 만들어줍니다.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    height: 1.42,
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

  Widget _buildLanguageSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              CupertinoIcons.globe,
              color: theme.colorScheme.primary,
              size: 19,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '문제 출제 언어',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _buildSmallBadge(
              theme: theme,
              label: _questionLanguage == 'English' ? '영어' : '한국어',
              color: theme.colorScheme.primary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildLanguageChoice(
                theme: theme,
                value: 'English',
                label: '영어',
                detail: '문제와 선택지를 영어 중심으로',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildLanguageChoice(
                theme: theme,
                value: 'Korean',
                label: '한국어',
                detail: '질문만 한국어로 표시',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageChoice({
    required ThemeData theme,
    required String value,
    required String label,
    required String detail,
  }) {
    final selected = _questionLanguage == value;
    final color =
        selected ? theme.colorScheme.primary : theme.colorScheme.outline;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => setState(() => _questionLanguage = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color:
              selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.10)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.34,
                  ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: color.withValues(alpha: selected ? 0.34 : 0.16),
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? CupertinoIcons.checkmark_circle_fill
                  : CupertinoIcons.circle,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
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
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      value: valueLabel,
      child: Column(
        children: [
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  min.round().toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  max.round().toString(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
