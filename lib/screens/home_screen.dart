// lib/screens/home_screen.dart (메뉴 추가된 코드)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/word_list_provider.dart';
import '../widgets/learning_mode_card.dart';
import 'ai_quiz_setup_screen.dart';
import 'app_settings_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'srs_status_screen.dart'; // ▼▼▼ [추가] 새로 만든 화면 import
import 'wordbook_management_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wordCount = context.watch<WordListNotifier>().words.length;

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
            // ▼▼▼ [추가] SRS 현황 보기 메뉴 카드 ▼▼▼
            LearningModeCard(
              heroTag: 'srs-status-hero',
              title: 'SRS 학습 현황',
              subtitle: '나의 학습 진행 상황을 확인하세요',
              icon: CupertinoIcons.chart_bar_square,
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const SrsStatusScreen())),
            ),
            const SizedBox(height: 16),
            LearningModeCard(
              heroTag: 'flashcards-hero',
              title: '플래시카드',
              subtitle: '활성 단어장의 $wordCount개 단어 학습',
              icon: CupertinoIcons.square_stack_3d_down_right,
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
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const QuizScreen())),
            ),
            const SizedBox(height: 16),
            LearningModeCard(
              heroTag: 'ai-quiz-hero',
              title: 'AI 학습',
              subtitle: 'AI가 만들어주는 실전 문제',
              icon: CupertinoIcons.sparkles,
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
