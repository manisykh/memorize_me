import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../models/word_model.dart';
import '../models/wordbook_model.dart';
import '../providers/ai_settings_provider.dart';
import '../providers/wordbook_manager.dart';
import '../services/ai_service.dart';
import '../services/mode_state_service.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/wordbook_selection_button.dart';
import 'ai_quiz_player_screen.dart';
import 'app_settings_screen.dart';

class AiQuizSetupScreen extends StatefulWidget {
  const AiQuizSetupScreen({super.key});

  @override
  State<AiQuizSetupScreen> createState() => _AiQuizSetupScreenState();
}

class _AiQuizSetupScreenState extends State<AiQuizSetupScreen> {
  Wordbook? _selectedWordbook;
  List<Word> _words = [];
  final Set<int> _selectedWordIds = {};

  String _selectedQuizType = '종합';
  double _difficulty = 2.0;
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
      _words.clear();
      _selectedWordIds.clear();
    });

    final wordbookManager = context.read<WordbookManager>();
    await wordbookManager.setActiveWordbook(wordbook);

    final words = await wordbookManager.getAllWordsFrom(wordbook);
    if (mounted) {
      setState(() {
        _words = words;
        _isLoading = false;
      });
    }

    final modeStateService = context.read<ModeStateService>();
    await modeStateService.setLastUsedWordbookId(LearningMode.aiQuiz, wordbook.id!);
  }

  void _onSelectAll() => setState(() => _selectedWordIds.addAll(_words.map((w) => w.id!)));
  void _onDeselectAll() => setState(() => _selectedWordIds.clear());

  Future<void> _handleApiError(dynamic e) async {
    if (!mounted) return;
    String message = e.toString();
    if (e is CustomApiException) {
      message = e.message;
      if (e.code == 'api_key_missing') {
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
        return;
      }
    }
    setState(() => _errorMessage = message);
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

      List<Word> selectedWords =
          _words.where((word) => _selectedWordIds.contains(word.id)).toList();
      selectedWords.shuffle();

      final difficultyText = ['쉬움', '보통', '어려움'][(_difficulty.round() - 1).clamp(0, 2)];

      final quizResponse = await aiService.generateQuiz(
        provider: aiSettings.selectedProvider,
        modelName: aiSettings.selectedModel,
        selectedWords: selectedWords,
        quizType: _selectedQuizType,
        difficulty: difficultyText,
        questionCount: _questionCount.round(),
        includeExplanation: _includeExplanation,
        questionLanguage: _questionLanguage,
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
    setState(() => _isGeneratingSentences = true);
    try {
      final aiService = context.read<AiService>();
      final aiSettings = context.read<AiSettingsProvider>();

      final sentenceMap = await aiService.generateSentencesForWords(
        wordsToUpdate,
        aiSettings.selectedModel,
      );

      final updatedWords = <Word>[];
      for (final word in wordsToUpdate) {
        if (sentenceMap.containsKey(word.word)) {
          updatedWords.add(word.copyWith(exampleSentence: sentenceMap[word.word]));
        }
      }

      await wordbookManager.updateWordsInWordbook(_selectedWordbook!, updatedWords);

      final newWords = await wordbookManager.getAllWordsFrom(_selectedWordbook!);

      if (mounted) {
        setState(() {
          _words = newWords;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${updatedWords.length}개 단어의 예문 생성이 완료되었습니다.')));
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('AI 단어 퀴즈 설정'), automaticallyImplyLeading: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WordbookSelectionButton(
                selectedWordbook: _selectedWordbook,
                onWordbookSelected: _onWordbookSelected,
                wordCount: _words.length,
              ),
              const SizedBox(height: 24),
              Text('AI 예문 일괄 생성', style: theme.textTheme.titleLarge),
              const SizedBox(height: 10),
              GlassmorphicCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '선택된 단어장에 예문이 없는 모든 단어에 대해 AI가 예문을 생성합니다.',
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
                            _isGeneratingSentences || _selectedWordbook == null
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
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 4.0,
                children: [
                  Text(
                    '문제에 포함될 단어 선택 (${_selectedWordIds.length} / ${_words.length})',
                    style: theme.textTheme.titleMedium,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(onPressed: _onSelectAll, child: const Text('전체 선택')),
                      TextButton(onPressed: _onDeselectAll, child: const Text('전체 해제')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GlassmorphicCard(
                padding: const EdgeInsets.all(0),
                child: SizedBox(
                  height: 200,
                  child:
                      _selectedWordbook == null
                          ? Center(
                            child: Text("먼저 학습할 단어장을 선택해주세요.", style: theme.textTheme.bodyMedium),
                          )
                          : _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _words.isEmpty
                          ? Center(child: Text("단어장에 단어가 없습니다.", style: theme.textTheme.bodyMedium))
                          : ListView.builder(
                            itemCount: _words.length,
                            itemBuilder: (context, index) {
                              final word = _words[index];
                              return CheckboxListTile(
                                title: Text(word.word),
                                subtitle: Text(word.meaning),
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
              ),
              const SizedBox(height: 24),
              GlassmorphicCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                  onPressed: _isLoading || _selectedWordbook == null ? null : _generateQuiz,
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

  Widget _buildQuizTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('문제 유형', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8.0,
          runSpacing: 4.0,
          children:
              ['종합', '어휘', '문법', '독해', '듣기'].map((type) {
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
        _buildSlider(
          label: '난이도',
          value: _difficulty,
          min: 1,
          max: 3,
          divisions: 2,
          onChanged: (val) => setState(() => _difficulty = val),
          valueLabel: ['쉬움', '보통', '어려움'][(_difficulty.round() - 1).clamp(0, 2)],
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
