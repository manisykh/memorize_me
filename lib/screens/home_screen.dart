// lib/screens/home_screen.dart

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/word_list_provider.dart';
import '../providers/wordbook_manager.dart';
import '../widgets/learning_mode_card.dart';
import 'ai_quiz_setup_screen.dart';
import 'app_settings_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';
import 'srs_status_screen.dart';
import 'wordbook_management_screen.dart';
import 'ai_grammar_quiz_setup_screen.dart'; // ▼▼▼ [추가] ▼▼▼

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // ▼▼▼ [수정] Provider.of 대신 context.watch를 사용하여 변경사항을 즉시 감지합니다. ▼▼▼
    final wordbookManager = context.watch<WordbookManager>();
    final wordCount = context.watch<WordListNotifier>().words.length;
    final reviewWords = wordbookManager.getWordsForReview();
    final bool canStartReviewQuiz = reviewWords.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Memorize Me with Juho'),
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
            // ▼▼▼ [수정] 오답/복습 퀴즈 버튼 로직 ▼▼▼
            Opacity(
              opacity: canStartReviewQuiz ? 1.0 : 0.5,
              child: LearningModeCard(
                heroTag: 'review_quiz_hero',
                title: '오답/복습 퀴즈',
                subtitle: canStartReviewQuiz ? '${reviewWords.length}개 단어 복습하기' : '복습할 단어가 없습니다',
                icon: CupertinoIcons.repeat,
                onTap:
                    canStartReviewQuiz
                        ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const QuizScreen(initialMode: QuizMode.reviewSpelling),
                          ),
                        )
                        : null, // 비활성화
              ),
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
            const SizedBox(height: 16),
            LearningModeCard(
              heroTag: 'ai-grammar-quiz-hero',
              title: 'AI 문법 퀴즈',
              subtitle: '수준별, 챕터별 맞춤 문법 문제 생성',
              icon: CupertinoIcons.pen,
              onTap:
                  () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const AiGrammarQuizSetupScreen())),
            ),
          ],
        ),
      ),
    );
  }
}
