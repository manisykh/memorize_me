import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../models/grammar_curriculum.dart';
import '../providers/ai_settings_provider.dart';
import '../services/ai_service.dart';
import '../services/analytics_service.dart';
import '../services/api_key_service.dart';
import '../utils/ai_error_utils.dart';
import '../widgets/ai_settings_card.dart';
import '../widgets/glassmorphic_card.dart';
import 'ai_quiz_player_screen.dart';

class AiGrammarQuizSetupScreen extends StatefulWidget {
  const AiGrammarQuizSetupScreen({super.key});

  @override
  State<AiGrammarQuizSetupScreen> createState() => _AiGrammarQuizSetupScreenState();
}

class _AiGrammarQuizSetupScreenState extends State<AiGrammarQuizSetupScreen> {
  int? _selectedCategoryIndex;
  final Set<GrammarChapter> _selectedChapters = {};
  double _questionCount = 10.0;
  bool _isLoading = false;
  String? _errorMessage;
  double _difficulty = 3.0;
  bool _includeExplanation = false;
  String _questionLanguage = 'English';

  Map<String, List<GrammarChapter>> _getGroupedChapters() {
    if (_selectedCategoryIndex == null) return {};
    final chapters = grammarCurriculum[_selectedCategoryIndex!].chapters;
    final Map<String, List<GrammarChapter>> groupedChapters = {};
    for (final chapter in chapters) {
      (groupedChapters[chapter.description] ??= []).add(chapter);
    }
    return groupedChapters;
  }

  Future<void> _generateQuiz() async {
    if (_selectedCategoryIndex == null || _selectedChapters.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('학습할 레벨과 챕터를 1개 이상 선택해주세요.')));
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

      final difficultyLabels = ['기초', '기본', '중급', '중고급', '고급', '최상급', '전문가'];
      final difficultyIndex = (_difficulty.round() - 1).clamp(0, 6);
      final difficultyText = difficultyLabels[difficultyIndex];

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
      );
      aiSettings.recordUsedOption(fallbackResult.usedOption);
      final AiQuizResponse? quizResponse = fallbackResult.value;
      if (quizResponse != null && quizResponse.questions.isNotEmpty && mounted) {
        context.read<AnalyticsService>().logAiGenerationCompleted(
          generationType: 'grammar_quiz',
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
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => AiQuizPlayerScreen(quizResponse: quizResponse)),
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

  void _showAiSettingsSheet() {
    showModalBottomSheet<void>(
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
                TextButton(child: const Text('취소'), onPressed: () => Navigator.pop(dialogContext)),
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
    final groupedChapters = _getGroupedChapters();
    final groupKeys = groupedChapters.keys.toList();
    final selectedCategory =
        _selectedCategoryIndex == null ? null : grammarCurriculum[_selectedCategoryIndex!];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('AI 문법 퀴즈 설정')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIntroCard(theme),
              const SizedBox(height: 12),
              _buildAiBetaNotice(theme),
              const SizedBox(height: 16),
              _buildGrammarLevelSection(theme, selectedCategory),
              if (_selectedCategoryIndex != null) ...[
                const SizedBox(height: 18),
                _buildChapterSection(theme, groupedChapters, groupKeys),
                const SizedBox(height: 18),
                _buildQuizOptionsSection(theme),
                const SizedBox(height: 24),
                if (_errorMessage != null) _buildErrorBox(theme),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon:
                        _isLoading
                            ? _AiSparkleIcon(color: theme.colorScheme.onPrimary, size: 24)
                            : const Icon(CupertinoIcons.sparkles),
                    label: Text(_isLoading ? '문제 생성 중...' : 'AI 문법 퀴즈 생성하기'),
                    onPressed: _isLoading ? null : _generateQuiz,
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
                  '선택한 문법 범위와 생성 옵션이 외부 AI 제공자에게 전송됩니다. 생성된 문제와 해설은 틀릴 수 있으니 학습 전 확인하세요. $fallbackText',
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

  Widget _buildGrammarLevelSection(ThemeData theme, GrammarCategory? selectedCategory) {
    return GlassmorphicCard(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme: theme,
            icon: CupertinoIcons.square_grid_2x2_fill,
            title: '문법 레벨',
            subtitle: selectedCategory?.description ?? '학습 범위에 맞는 레벨을 먼저 선택하세요.',
          ),
          const SizedBox(height: 14),
          ...List.generate(grammarCurriculum.length, (index) {
            final category = grammarCurriculum[index];
            return Padding(
              padding: EdgeInsets.only(bottom: index == grammarCurriculum.length - 1 ? 0 : 10),
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
    final accent = selected ? theme.colorScheme.primary : theme.colorScheme.outline;
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        setState(() {
          _selectedCategoryIndex = index;
          _selectedChapters.clear();
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
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color:
                selected
                    ? theme.colorScheme.primary.withValues(alpha: 0.44)
                    : theme.colorScheme.outline.withValues(alpha: 0.18),
            width: selected ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.shadowColor.withValues(alpha: selected ? 0.10 : 0.05),
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
                selected ? CupertinoIcons.checkmark_seal_fill : CupertinoIcons.book,
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
                        color: selected ? theme.colorScheme.primary : theme.colorScheme.secondary,
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

  Widget _buildChapterSection(
    ThemeData theme,
    Map<String, List<GrammarChapter>> groupedChapters,
    List<String> groupKeys,
  ) {
    final totalChapters = groupedChapters.values.fold<int>(0, (sum, chapters) => sum + chapters.length);
    return GlassmorphicCard(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            theme: theme,
            icon: CupertinoIcons.checkmark_square_fill,
            title: '챕터 선택',
            subtitle: '${_selectedChapters.length}개 선택 · 전체 $totalChapters개',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedChapters
                        ..clear()
                        ..addAll(groupedChapters.values.expand((chapters) => chapters));
                    });
                  },
                  icon: const Icon(CupertinoIcons.checkmark_alt_circle, size: 18),
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
          ...groupKeys.map((groupTitle) {
            final chapters = groupedChapters[groupTitle]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildChapterGroupCard(theme, groupTitle, chapters),
            );
          }),
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
                ? Color.alphaBlend(accent.withValues(alpha: 0.08), theme.colorScheme.surface)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
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
                child: Icon(CupertinoIcons.layers_alt_fill, color: accent, size: 18),
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
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
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
                label: allSelected ? '완료' : selectedCount == 0 ? '선택' : '$selectedCount개',
                color: accent,
              ),
            ],
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _toggleChapterGroup(chapters, selectAll: !allSelected),
                icon: Icon(allSelected ? CupertinoIcons.minus_circle : CupertinoIcons.plus_circle, size: 17),
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

  void _toggleChapterGroup(List<GrammarChapter> chapters, {required bool selectAll}) {
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
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.outline;
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
            border: Border.all(color: color.withValues(alpha: selected ? 0.34 : 0.13)),
          ),
          child: Row(
            children: [
              Icon(
                selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
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

  Widget _buildQuizOptionsSection(ThemeData theme) {
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
            subtitle: '${_questionCount.round()}문제 · ${_difficultyLabel()} · ${_questionLanguage == 'English' ? '영어' : '한국어'}',
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
              min: 1,
              max: 7,
              divisions: 6,
              valueLabel: _difficultyLabel(),
              onChanged: (value) => setState(() => _difficulty = value),
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
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.16)),
      ),
      child: Text(
        '선택한 문법 범위와 문제 옵션이 외부 AI로 전송되며, 사용자의 API 사용량을 소모합니다. 안정적인 생성을 위해 한 번에 최대 20문제까지 생성합니다.',
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
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.14)),
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
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              _buildSmallBadge(theme: theme, label: valueLabel, color: theme.colorScheme.primary),
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
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
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
              _includeExplanation ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.lightbulb,
              color: _includeExplanation ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '해설 포함',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
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
    final difficultyLabels = ['기초', '기본', '중급', '중고급', '고급', '최상급', '전문가'];
    return difficultyLabels[(_difficulty.round() - 1).clamp(0, 6)];
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
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
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

  Widget _buildLanguageSelector() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(CupertinoIcons.globe, color: theme.colorScheme.primary, size: 19),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '문제 출제 언어',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
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
                detail: '설명을 한국어로 더 쉽게',
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
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.outline;
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
                  : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: selected ? 0.34 : 0.16)),
        ),
        child: Row(
          children: [
            Icon(
              selected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
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
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
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
