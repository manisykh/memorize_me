import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_quiz_model.dart';
import '../models/word_model.dart';
import '../providers/word_list_provider.dart';
import '../services/ai_service.dart';
import '../services/api_key_service.dart';
import '../widgets/glassmorphic_card.dart';
import 'ai_quiz_player_screen.dart';

class AiQuizSetupScreen extends StatefulWidget {
  const AiQuizSetupScreen({super.key});

  @override
  State<AiQuizSetupScreen> createState() => _AiQuizSetupScreenState();
}

class _AiQuizSetupScreenState extends State<AiQuizSetupScreen> {
  // --- UI 상태 변수들 ---
  bool _isGeminiKeyRegistered = false;
  bool _isOpenAiKeyRegistered = false;
  AiProvider _selectedProvider = AiProvider.gemini;
  final List<String> _geminiModels = ['gemini-2.5-flash', 'gemini-2.5-pro'];
  final List<String> _openAiModels = ['gpt-3.5-turbo', 'gpt-4o'];
  late String _selectedGeminiModel;
  late String _selectedGptModel;
  final Set<int> _selectedWordIds = {};
  String _selectedQuizType = '종합';
  double _difficulty = 2.0;
  double _questionCount = 10.0;
  bool _isLoading = false;
  String? _errorMessage;
  bool _includeExplanation = false;

  @override
  void initState() {
    super.initState();
    _selectedGeminiModel = _geminiModels.first;
    _selectedGptModel = _openAiModels.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkApiStatus();
    });
  }

  Future<void> _checkApiStatus() async {
    final apiKeyService = context.read<ApiKeyService>();
    final geminiKey = await apiKeyService.getApiKey(AiProvider.gemini);
    final openAiKey = await apiKeyService.getApiKey(AiProvider.openAI);
    if (mounted) {
      setState(() {
        _isGeminiKeyRegistered = (geminiKey != null && geminiKey.isNotEmpty);
        _isOpenAiKeyRegistered = (openAiKey != null && openAiKey.isNotEmpty);
      });
    }
  }

  Future<void> _showApiKeyDialog(AiProvider provider) async {
    final apiKeyController = TextEditingController();
    await showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('${provider.name} API 키 등록'),
            content: TextField(controller: apiKeyController),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
              TextButton(
                onPressed: () async {
                  if (apiKeyController.text.isNotEmpty) {
                    await context.read<ApiKeyService>().saveApiKey(provider, apiKeyController.text);
                    if (mounted) Navigator.pop(context);
                    await _checkApiStatus();
                    // 키 저장 후 바로 문제 생성 재시도
                    await _generateQuiz();
                  }
                },
                child: const Text('저장 및 재시도'),
              ),
            ],
          ),
    );
  }

  void _onSelectAll(List<Word> allWords) {
    setState(() => _selectedWordIds.addAll(allWords.map((w) => w.id!)));
  }

  void _onDeselectAll() {
    setState(() => _selectedWordIds.clear());
  }

  // ▼▼▼ [수정] AI 문제 생성 요청을 처리하는 함수의 내용을 채웁니다. ▼▼▼
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
      final allWords = context.read<WordListNotifier>().words;
      final selectedWords = allWords.where((word) => _selectedWordIds.contains(word.id)).toList();
      final selectedModel =
          _selectedProvider == AiProvider.gemini ? _selectedGeminiModel : _selectedGptModel;
      final difficultyText = ['쉬움', '보통', '어려움'][_difficulty.round() - 1];

      // AI 서비스 호출
      final quizResponse = await aiService.generateQuiz(
        provider: _selectedProvider,
        modelName: selectedModel,
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
    } on CustomApiException catch (e) {
      // ▼▼▼ [추가] 사용자 정의 예외 처리 ▼▼▼
      if (e.code == 'server_overloaded') {
        _errorMessage = 'AI 서버가 현재 바쁩니다. 잠시 후 다시 시도해주세요.';
      } else if (e.code == 'quota_exceeded') {
        _errorMessage = 'API 사용량 한도를 초과했습니다. 내일 다시 시도하거나 다른 엔진을 선택해주세요.';
      } else {
        _errorMessage = e.message;
      }
      setState(() {});
    } on Exception catch (e) {
      if (e.toString().contains('API 키가 등록되지 않았습니다')) {
        if (mounted) await _showApiKeyDialog(_selectedProvider);
      } else {
        setState(() => _errorMessage = '오류 발생: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final words = context.watch<WordListNotifier>().words;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. AI 엔진 상태 및 모델 선택 섹션 ---
            Text('1. AI 엔진 선택', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            GlassmorphicCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildApiStatusRow(
                      provider: AiProvider.gemini,
                      isRegistered: _isGeminiKeyRegistered,
                    ),
                    const Divider(height: 24),
                    _buildApiStatusRow(
                      provider: AiProvider.openAI,
                      isRegistered: _isOpenAiKeyRegistered,
                    ),
                    const Divider(height: 24),
                    SegmentedButton<AiProvider>(
                      segments: const [
                        ButtonSegment(value: AiProvider.gemini, label: Text('Gemini')),
                        ButtonSegment(value: AiProvider.openAI, label: Text('GPT')),
                      ],
                      selected: {_selectedProvider},
                      onSelectionChanged:
                          (newSelection) => setState(() => _selectedProvider = newSelection.first),
                    ),
                    const SizedBox(height: 8),
                    if (_selectedProvider == AiProvider.gemini)
                      _buildModelDropdown(
                        models: _geminiModels,
                        selectedValue: _selectedGeminiModel,
                        onChanged: (newValue) => setState(() => _selectedGeminiModel = newValue!),
                      )
                    else
                      _buildModelDropdown(
                        models: _openAiModels,
                        selectedValue: _selectedGptModel,
                        onChanged: (newValue) => setState(() => _selectedGptModel = newValue!),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- 2. 단어 선택 섹션 ---
            Text('2. 문제에 포함할 단어 선택', style: theme.textTheme.titleLarge),
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
                    words.isEmpty
                        ? Center(
                          child: Text("활성 단어장에 단어가 없습니다.", style: theme.textTheme.bodyMedium),
                        )
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

            // --- 3. 문제 유형 섹션 ---
            Text('3. 문제 유형', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            GlassmorphicCard(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Wrap(
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
              ),
            ),
            const SizedBox(height: 24),

            // --- 4. 난이도 및 문제 수 섹션 ---
            Text('4. 난이도 및 문제 수', style: theme.textTheme.titleLarge),
            const SizedBox(height: 10),
            GlassmorphicCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
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
                  ],
                ),
              ),
            ),
            GlassmorphicCard(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: CheckboxListTile(
                title: const Text('해설 포함하여 문제 생성'),
                subtitle: const Text('API 사용량이 증가할 수 있습니다.'),
                value: _includeExplanation,
                onChanged: (val) => setState(() => _includeExplanation = val!),
                activeColor: theme.primaryColor,
              ),
            ),
            const SizedBox(height: 24),

            // --- 5. 버튼 및 로딩/에러 표시 UI ---
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
                        ? Container(
                          width: 24,
                          height: 24,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                        : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isLoading ? '문제 생성 중...' : 'AI 문제 생성하기',
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                onPressed: _isLoading ? null : _generateQuiz, // [수정] _generateQuiz 함수 연결
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiStatusRow({required AiProvider provider, required bool isRegistered}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(provider.name, style: theme.textTheme.titleMedium),
        Row(
          children: [
            Text(
              isRegistered ? '등록 완료' : '등록 필요',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isRegistered ? Colors.green : Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 30,
              child: OutlinedButton(
                onPressed: () => _showApiKeyDialog(provider),
                child: Text(isRegistered ? '관리' : '등록'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModelDropdown({
    required List<String> models,
    required String selectedValue,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButton<String>(
      value: selectedValue,
      isExpanded: true,
      underline: Container(height: 1, color: Theme.of(context).primaryColor.withOpacity(0.5)),
      onChanged: onChanged,
      items:
          models
              .map<DropdownMenuItem<String>>(
                (String value) => DropdownMenuItem<String>(value: value, child: Text(value)),
              )
              .toList(),
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
