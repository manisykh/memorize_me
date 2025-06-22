// screens/home_screen.dart (수정 코드)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wordbook_manager.dart';
import '../widgets/gradient_background.dart';
import 'flashcard_screen.dart';
// import 'manage_words_screen.dart'; // 이 import는 더 이상 필요 없을 수 있습니다.
import 'quiz_screen.dart';
import 'settings_screen.dart';
import '../providers/theme_provider.dart';
import '../themes/app_theme.dart';
import 'ai_quiz_setup_screen.dart'; // ▼▼▼ [추가] 새로운 AI 퀴즈 설정 화면 import ▼▼▼

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // ▼▼▼ [수정] TabController의 길이를 3에서 4로 변경 ▼▼▼
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      FocusScope.of(context).unfocus();
      if (_currentTabIndex != _tabController.index) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeWordbookName = context.watch<WordbookManager>().activeWordbook?.name ?? '단어장';
    final themeNotifier = context.watch<ThemeNotifier>();

    final scaffold = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(activeWordbookName),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.appBarTheme.foregroundColor,
          unselectedLabelColor: theme.appBarTheme.foregroundColor?.withOpacity(0.7),
          indicatorColor: theme.appBarTheme.foregroundColor,
          tabs: const [
            Tab(icon: Icon(CupertinoIcons.settings), text: '설정'),
            Tab(icon: Icon(CupertinoIcons.square_stack_3d_down_right), text: '플래시카드'),
            Tab(icon: Icon(CupertinoIcons.question_diamond), text: '퀴즈'),
            // ▼▼▼ [추가] AI 학습 탭 추가 ▼▼▼
            Tab(icon: Icon(CupertinoIcons.sparkles), text: 'AI 학습'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        // ▼▼▼ [수정] TabBarView에 AiQuizSetupScreen 추가 ▼▼▼
        children: const [
          SettingsScreen(),
          FlashcardScreen(),
          QuizScreen(),
          AiQuizSetupScreen(), // 새로 추가될 화면
        ],
      ),
    );

    // ... (이하 나머지 코드는 기존과 동일)
    if (themeNotifier.currentTheme == AppThemeType.basic) {
      return GradientBackground(child: scaffold);
    } else {
      Color currentSepiaColor;
      switch (themeNotifier.eyeCareLevel) {
        case 2:
          currentSepiaColor = AppTheme.backgroundSepiaLevel2;
          break;
        case 3:
          currentSepiaColor = AppTheme.backgroundSepiaLevel3;
          break;
        case 1:
        default:
          currentSepiaColor = AppTheme.backgroundSepiaLevel1;
      }
      return Container(color: currentSepiaColor, child: scaffold);
    }
  }
}
