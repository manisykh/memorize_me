import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../models/grammar_curriculum.dart';
import '../providers/ai_settings_provider.dart';
import '../services/ai_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'ai_quiz_player_screen.dart';
import 'app_settings_screen.dart';

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

    try {
      final selectedCategory = grammarCurriculum[_selectedCategoryIndex!];
      final aiService = context.read<AiService>();
      final aiSettings = context.read<AiSettingsProvider>();

      final difficultyLabels = ['기초', '기본', '중급', '중고급', '고급', '최상급', '전문가'];
      final difficultyIndex = (_difficulty.round() - 1).clamp(0, 6);
      final difficultyText = difficultyLabels[difficultyIndex];

      final AiQuizResponse? quizResponse = await aiService.generateGrammarQuiz(
        provider: aiSettings.selectedProvider,
        modelName: aiSettings.selectedModel,
        category: selectedCategory,
        chapters: _selectedChapters.toList(),
        questionCount: _questionCount.round(),
        difficulty: difficultyText,
        includeExplanation: _includeExplanation,
        questionLanguage: _questionLanguage,
      );

      if (mounted) {
        if (quizResponse != null && quizResponse.questions.isNotEmpty) {
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
      setState(() => _errorMessage = '알 수 없는 오류가 발생했습니다: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleApiError(CustomApiException e) async {
    if (!mounted) return;
    if (e.code == 'api_key_missing') {
      await showDialog(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              title: const Text('API 키 필요'),
              content: Text(e.message),
              actions: [
                TextButton(child: const Text('취소'), onPressed: () => Navigator.pop(dialogContext)),
                FilledButton(
                  child: const Text('설정으로 이동'),
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.of(
                      context,
                    ).push(MaterialPageRoute(builder: (_) => const AppSettingsScreen()));
                  },
                ),
              ],
            ),
      );
    } else {
      setState(() => _errorMessage = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupedChapters = _getGroupedChapters();
    final groupKeys = groupedChapters.keys.toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('AI 문법 퀴즈 설정')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. 학습 레벨 선택', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0,
              children: List.generate(grammarCurriculum.length, (index) {
                return ChoiceChip(
                  label: Text(grammarCurriculum[index].title),
                  selected: _selectedCategoryIndex == index,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategoryIndex = index;
                        _selectedChapters.clear();
                      }
                    });
                  },
                );
              }),
            ),
            if (_selectedCategoryIndex != null) ...[
              const SizedBox(height: 24),
              Text('2. 학습 챕터 선택 (다중 선택 가능)', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              GlassmorphicCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groupKeys.length,
                  itemBuilder: (context, index) {
                    final groupTitle = groupKeys[index];
                    final chaptersInGroup = groupedChapters[groupTitle]!;
                    return ExpansionTile(
                      title: Text(groupTitle, style: theme.textTheme.titleMedium),
                      children:
                          chaptersInGroup.map((chapter) {
                            return CheckboxListTile(
                              title: Text(chapter.title, style: theme.textTheme.bodyMedium),
                              value: _selectedChapters.contains(chapter),
                              onChanged: (selected) {
                                setState(() {
                                  if (selected == true) {
                                    _selectedChapters.add(chapter);
                                  } else {
                                    _selectedChapters.remove(chapter);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              Text('3. 퀴즈 옵션 설정', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              GlassmorphicCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildLanguageSelector(),
                    const Divider(height: 24),
                    _buildSlider(
                      label: '난이도',
                      value: _difficulty,
                      min: 1,
                      max: 7,
                      divisions: 6,
                      valueLabel:
                          ['기초', '기본', '중급', '중고급', '고급', '최상급', '전문가'][(_difficulty.round() - 1)
                              .clamp(0, 6)],
                      onChanged: (value) => setState(() => _difficulty = value),
                    ),
                    const SizedBox(height: 10),
                    _buildSlider(
                      label: '문제 수',
                      value: _questionCount,
                      min: 5,
                      max: 30,
                      divisions: 5,
                      valueLabel: '${_questionCount.round()}문제',
                      onChanged: (value) => setState(() => _questionCount = value),
                    ),
                    const Divider(height: 24),
                    CheckboxListTile(
                      title: const Text('해설 포함하여 문제 생성'),
                      subtitle: const Text('API 사용량이 증가할 수 있습니다.'),
                      value: _includeExplanation,
                      onChanged: (val) => setState(() => _includeExplanation = val!),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Center(
                    child: Text(_errorMessage!, style: TextStyle(color: theme.colorScheme.error)),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                          : const Icon(Icons.auto_awesome),
                  label: Text(_isLoading ? '문제 생성 중...' : 'AI 퀴즈 생성하기'),
                  onPressed: _isLoading ? null : _generateQuiz,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('문제 출제 언어', style: Theme.of(context).textTheme.titleMedium),
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

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required String valueLabel,
  }) {
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
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
