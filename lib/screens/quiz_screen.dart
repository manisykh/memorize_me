// screens/quiz_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/quiz_session_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/word_list_provider.dart';
import '../widgets/enhanced_neumorphic_container.dart';
import 'quiz_helpers.dart';
import 'quiz_result_screen.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  void _startQuiz(BuildContext context) {
    final allWords = context.read<WordListNotifier>().words;
    if (allWords.length < 4) {
      // 객관식 대비 최소 단어 수
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('퀴즈를 시작하려면 단어를 4개 이상 추가해주세요.')));
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (ctx) => ChangeNotifierProvider(
              create:
                  (_) => QuizSessionProvider(
                    ctx.read<WordListNotifier>().words,
                    ctx.read<SettingsNotifier>().settings,
                  ),
              child: const SpellingQuizPage(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: EnhancedNeumorphicContainer(
        onTap: () => _startQuiz(context),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        child: Text('스펠링 퀴즈 시작', style: theme.textTheme.titleMedium),
      ),
    );
  }
}

class SpellingQuizPage extends StatefulWidget {
  const SpellingQuizPage({super.key});
  @override
  State<SpellingQuizPage> createState() => _SpellingQuizPageState();
}

class _SpellingQuizPageState extends State<SpellingQuizPage> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit(QuizSessionProvider provider) {
    if (provider.answerSubmitted) {
      // 다음 문제로
      if (provider.isSessionFinished) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder:
                (_) => QuizResultScreen(
                  results: provider.results,
                  totalQuestions: provider.sessionItems.length,
                ),
          ),
        );
      } else {
        provider.nextQuestion();
        _textController.clear();
        _focusNode.requestFocus();
      }
    } else {
      // 정답 제출
      provider.submitAnswer(_textController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<QuizSessionProvider>();
    final theme = Theme.of(context);

    if (provider.sessionItems.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final quizItem = provider.sessionItems[provider.currentIndex];
    final questionText = getQuestionText(quizItem.word, quizItem.questionType);
    final correctAnswer = getAnswerText(quizItem.word, quizItem.questionType);

    return Scaffold(
      appBar: AppBar(
        title: Text('스펠링 퀴즈 (${provider.currentIndex + 1} / ${provider.sessionItems.length})'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 질문 영역
            Text(questionText, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 30),

            // 답변 입력 영역
            TextField(
              controller: _textController,
              focusNode: _focusNode,
              autofocus: true,
              readOnly: provider.answerSubmitted,
              decoration: InputDecoration(
                hintText: '정답을 입력하세요',
                border: const OutlineInputBorder(),
                suffixIcon:
                    provider.answerSubmitted
                        ? (provider.results.last.isCorrect
                            ? const Icon(Icons.check, color: Colors.green)
                            : const Icon(Icons.close, color: Colors.red))
                        : null,
              ),
              onSubmitted: (_) => _handleSubmit(provider),
            ),
            const SizedBox(height: 20),

            // 정답 공개 영역
            if (provider.answerSubmitted)
              Text("정답: $correctAnswer", style: TextStyle(color: theme.primaryColor, fontSize: 16)),

            const Spacer(),

            // 버튼 영역
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _handleSubmit(provider),
                child: Text(
                  provider.answerSubmitted
                      ? (provider.isSessionFinished ? '결과 보기' : '다음 문제')
                      : '정답 확인',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
