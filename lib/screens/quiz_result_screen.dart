// screens/quiz_result_screen.dart

import 'package:flutter/material.dart';
import '../providers/quiz_session_provider.dart';

class QuizResultScreen extends StatelessWidget {
  final List<QuizResult> results;
  final int totalQuestions;

  const QuizResultScreen({super.key, required this.results, required this.totalQuestions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correctCount = results.where((r) => r.isCorrect).length;

    return Scaffold(
      appBar: AppBar(title: const Text('퀴즈 결과')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              '결과: $totalQuestions문제 중 $correctCount개 정답!',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 20),
            Text('틀린 문제', style: theme.textTheme.titleLarge),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: results.where((r) => !r.isCorrect).length,
                itemBuilder: (context, index) {
                  final wrongResult = results.where((r) => !r.isCorrect).toList()[index];
                  final additionalMeanings = wrongResult.word.additionalMeanings;
                  final question = wrongResult.word.meaning;
                  final correctAnswer = wrongResult.word.word;

                  return Card(
                    color: theme.colorScheme.errorContainer,
                    child: ListTile(
                      title: Text('Q. $question'),
                      subtitle: Text(
                        '정답: $correctAnswer\n'
                        '내 답변: ${wrongResult.userAnswer}'
                        '${additionalMeanings.isEmpty ? '' : '\n추가 뜻: ${additionalMeanings.join(' · ')}'}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                child: const Text('돌아가기'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
