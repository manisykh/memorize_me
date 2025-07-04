import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../themes/app_theme.dart';
import '../widgets/gradient_background.dart';
import '../widgets/learning_mode_card.dart';
import 'ai_quiz_setup_screen.dart';
import 'app_settings_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'wordbook_management_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    final wordListNotifier = context.watch<WordListNotifier>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Memorize me with Juho'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(CupertinoIcons.settings),
            onPressed:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const AppSettingsScreen())),
            tooltip: '앱 설정',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            LearningModeCard(
              heroTag: 'wordbook-hero',
              title: '내 단어장',
              subtitle: '단어 추가, 수정, 가져오기 및 병합',
              icon: CupertinoIcons.book_fill,
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const WordbookManagementScreen())),
            ),
            const SizedBox(height: 16),
            LearningModeCard(
              heroTag: 'flashcards-hero',
              title: '플래시카드',
              subtitle: '복습할 단어: ${wordListNotifier.words.length}개',
              icon: CupertinoIcons.square_stack_3d_down_right,
              // ▼▼▼ [수정] 단순한 화면 이동 로직으로 복원합니다. ▼▼▼
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const FlashcardScreen())),
            ),
            const SizedBox(height: 16),
            LearningModeCard(
              heroTag: 'quiz-hero',
              title: '셀프 테스트',
              subtitle: '스펠링 퀴즈, 시험지 생성하기',
              icon: CupertinoIcons.question_diamond,
              // ▼▼▼ [수정] 단순한 화면 이동 로직으로 복원합니다. ▼▼▼
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const QuizScreen())),
            ),
            const SizedBox(height: 16),
            LearningModeCard(
              heroTag: 'ai-quiz-hero',
              title: 'AI 학습',
              subtitle: 'AI가 생성하는 맞춤형 문제 풀기',
              icon: CupertinoIcons.sparkles,
              // ▼▼▼ [수정] 단순한 화면 이동 로직으로 복원합니다. ▼▼▼
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AiQuizSetupScreen())),
            ),
          ],
        ),
      ),
    );
  }
}
