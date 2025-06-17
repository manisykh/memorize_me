// screens/home_screen.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wordbook_manager.dart';
import '../widgets/gradient_background.dart';
import 'flashcard_screen.dart';
import 'manage_words_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';

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
      setState(() {
        _currentTabIndex = _tabController.index;
      });
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

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(activeWordbookName),
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController, // 컨트롤러 연결
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.7),
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(CupertinoIcons.settings), text: '설정'),
              Tab(icon: Icon(CupertinoIcons.square_stack_3d_down_right), text: '플래시카드'),
              Tab(icon: Icon(CupertinoIcons.question_diamond), text: '퀴즈'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController, // 컨트롤러 연결
          children: const [SettingsScreen(), FlashcardScreen(), QuizScreen()],
        ),
        // ▼▼▼ 4. FAB 표시 여부 제어 ▼▼▼
        floatingActionButton:
            _currentTabIndex ==
                    0 // '설정' 탭일 때만 보이기
                ? FloatingActionButton.extended(
                  onPressed:
                      () => Navigator.of(
                        context,
                      ).push(MaterialPageRoute(builder: (_) => const ManageWordsScreen())),
                  backgroundColor: theme.primaryColor,
                  icon: const Icon(CupertinoIcons.book_fill, color: Colors.white),
                  label: const Text('단어 관리', style: TextStyle(color: Colors.white)),
                )
                : null, // 다른 탭에서는 보이지 않음
        // ▲▲▲
      ),
    );
  }
}
