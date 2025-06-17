// screens/home_screen.dart (최종 수정)

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/wordbook_manager.dart';
import '../widgets/gradient_background.dart';
import 'flashcard_screen.dart';
import 'manage_words_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import '../providers/theme_provider.dart';
import '../themes/app_theme.dart';

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      // ▼▼▼ 탭 전환 리스너 로직 수정 ▼▼▼
      // 탭 이동이 시작될 때마다 키보드 포커스를 해제 (스와이프/탭 클릭 모두 해당)
      FocusScope.of(context).unfocus();
      // ▲▲▲

      // FAB 버튼 표시 여부를 위해 현재 탭 인덱스를 계속 추적합니다.
      // setState는 build를 다시 호출하므로, 불필요한 호출을 막기 위해 index가 실제로 변경되었을 때만 호출합니다.
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
      // 단어 관리 버튼이 설정 화면의 일부가 되었으므로 FAB는 제거되었습니다.
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [SettingsScreen(), FlashcardScreen(), QuizScreen()],
      ),
    );

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
