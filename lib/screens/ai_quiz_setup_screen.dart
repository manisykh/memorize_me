import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../models/word_model.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/ai_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'ai_quiz_player_screen.dart';
import 'app_settings_screen.dart';

class AiQuizSetupScreen extends StatefulWidget {
  const AiQuizSetupScreen({super.key});

  @override
  State<AiQuizSetupScreen> createState() => _AiQuizSetupScreenState();
}

class _AiQuizSetupScreenState extends State<AiQuizSetupScreen> {
  final Set<int> _selectedWordIds = {};
  String _selectedQuizType = '종합';
  double _difficulty = 2.0;
  double _questionCount = 10.0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _includeExplanation = false;
  bool _isGeneratingSentences = false;

  void _onSelectAll(List<Word> allWords) {
    setState(() => _selectedWordIds.addAll(allWords.map((w) => w.id!)));
  }

  void _onDeselectAll() {
    setState(() => _selectedWordIds.clear());
  }

  Future<void> _handleApiError(dynamic e) async {
    if (e is CustomApiException && e.code == 'api_key_missing') {
      if (!mounted) return;
      await showCupertinoDialog(
        context: context,
        builder:
            (dialogContext) => CupertinoAlertDialog(
              title: const Text('API 키 필요'),
              content: Text(e.message),
              actions: [
                CupertinoDialogAction(
                  child: const Text('취소'),
                  onPressed: () => Navigator.pop(dialogContext),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
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
      setState(() => _errorMessage = null);
    } else {
      setState(() => _errorMessage = e.toString());
    }
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
    try {
      final aiService = context.read<AiService>();
      final aiSettings = context.read<AiSettingsProvider>();
      final allWords = context.read<WordListNotifier>().words;
      final selectedWords = allWords.where((word) => _selectedWordIds.contains(word.id)).toList();
      final difficultyText = ['쉬움', '보통', '어려움'][_difficulty.round() - 1];

      final quizResponse = await aiService.generateQuiz(
        provider: aiSettings.selectedProvider,
        modelName: aiSettings.selectedModel,
        selectedWords: selectedWords,
        quizType: _selectedQuizType,
        difficulty: difficultyText,
        questionCount: _questionCount.round(),
        includeExplanation: _includeExplanation,
      );

      if (mounted) {
        if (quizResponse != null && quizResponse.questions.isNotEmpty) {
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

  Future<void> _generateAllSentences() async {
    final wordListNotifier = context.read<WordListNotifier>();
    final aiSettings = context.read<AiSettingsProvider>();
    final wordsToUpdate =
        wordListNotifier.words
            .where((w) => w.exampleSentence == null || w.exampleSentence!.isEmpty)
            .toList();

    if (wordsToUpdate.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('모든 단어에 예문이 이미 존재합니다.')));
      return;
    }
    setState(() => _isGeneratingSentences = true);
    try {
      await wordListNotifier.generateAndUpdateAllSentences(context.read<AiService>(), aiSettings);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${wordsToUpdate.length}개 단어의 예문 생성이 완료되었습니다.')));
      }
    } catch (e) {
      await _handleApiError(e);
    } finally {
      if (mounted) {
        setState(() => _isGeneratingSentences = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = context.watch<WordListNotifier>().words;
    final activeWordbook = context.watch<WordbookManager>().activeWordbook;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('AI 학습'), automaticallyImplyLeading: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ▼▼▼ [수정] 단어장 선택 버튼을 '현재 단어장'을 표시하는 텍스트로 변경 ▼▼▼
              Text(
                '현재 단어장: ${activeWordbook?.name ?? '선택되지 않음'}',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text('단어장을 변경하려면 \'내 단어장\' 메뉴를 이용해주세요.', style: theme.textTheme.bodySmall),
              const SizedBox(height: 24),

              Text('AI 예문 일괄 생성(플래시카드 학습)', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              GlassmorphicCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '현재 단어장에 예문이 없는 모든 단어에 대해 AI가 예문을 생성하고 저장합니다.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon:
                            _isGeneratingSentences
                                ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                                : const Icon(Icons.auto_awesome_rounded),
                        label: Text(_isGeneratingSentences ? '예문 생성 중...' : '일괄 생성 시작'),
                        onPressed:
                            _isGeneratingSentences || activeWordbook == null
                                ? null
                                : _generateAllSentences,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Text('AI 퀴즈 생성', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),

              Text('문제에 포함될 단어 선택', style: theme.textTheme.titleMedium),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '선택된 단어: ${_selectedWordIds.length} / ${words.length}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Row(
                    children: [
                      TextButton(onPressed: () => _onSelectAll(words), child: const Text('전체 선택')),
                      TextButton(onPressed: _onDeselectAll, child: const Text('전체 해제')),
                    ],
                  ),
                ],
              ),
              GlassmorphicCard(
                padding: const EdgeInsets.all(0),
                child: SizedBox(
                  height: 200,
                  child:
                      activeWordbook == null
                          ? Center(
                            child: Text("단어장을 먼저 선택해주세요.", style: theme.textTheme.bodyMedium),
                          )
                          : words.isEmpty
                          ? Center(child: Text("단어장에 단어가 없습니다.", style: theme.textTheme.bodyMedium))
                          : ListView.builder(
                            itemCount: words.length,
                            itemBuilder: (context, index) {
                              final word = words[index];
                              return CheckboxListTile(
                                title: Text(word.word),
                                subtitle: Text(word.meaning),
                                value: _selectedWordIds.contains(word.id),
                                onChanged: (bool? value) {
                                  if (word.id == null) return;
                                  setState(() {
                                    if (value == true)
                                      _selectedWordIds.add(word.id!);
                                    else
                                      _selectedWordIds.remove(word.id!);
                                  });
                                },
                              );
                            },
                          ),
                ),
              ),
              const SizedBox(height: 24),

              GlassmorphicCard(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    children: [
                      _buildQuizTypeSelector(),
                      const Divider(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: _buildDifficultyAndCountSection(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Center(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
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
                  onPressed: _isLoading || activeWordbook == null ? null : _generateQuiz,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('문제 유형', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: RawChip(
            label: const Text('종합'),
            selected: _selectedQuizType == '종합',
            onSelected: (isSelected) {
              if (isSelected) setState(() => _selectedQuizType = '종합');
            },
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          alignment: WrapAlignment.center,
          children:
              ['어휘', '문법', '독해', '듣기'].map((type) {
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

  Widget _buildDifficultyAndCountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('난이도 및 문제 수', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        _buildSlider(
          label: '난이도',
          value: _difficulty,
          min: 1,
          max: 3,
          divisions: 2,
          onChanged: (val) => setState(() => _difficulty = val),
          valueLabel: ['쉬움', '보통', '어려움'][_difficulty.round() - 1],
        ),
        const SizedBox(height: 10),
        _buildSlider(
          label: '문제 수',
          value: _questionCount,
          min: 5,
          max: 30,
          divisions: 5,
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
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).primaryColor),
        ),
      ],
    );
  }
}
