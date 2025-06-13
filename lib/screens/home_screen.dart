import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'manage_words_screen.dart';
import 'settings_screen.dart';
import 'flashcard_screen.dart';
import 'quiz_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('내 단어장'),
          bottom: TabBar(
            labelColor: theme.primaryColor,
            unselectedLabelColor: Colors.grey,
            indicatorColor: theme.primaryColor,
            tabs: const [
              Tab(icon: Icon(CupertinoIcons.settings), text: '설정'),
              Tab(icon: Icon(CupertinoIcons.square_stack_3d_down_right), text: '플래시카드'),
              Tab(icon: Icon(CupertinoIcons.question_diamond), text: '퀴즈'),
            ],
          ),
        ),
        body: const TabBarView(children: [SettingsScreen(), FlashcardScreen(), QuizScreen()]),
        floatingActionButton: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: FloatingActionButton.extended(
            onPressed:
                () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const ManageWordsScreen())),
            backgroundColor: theme.primaryColor,
            icon: const Icon(CupertinoIcons.book_fill, color: Colors.white),
            label: const Text('단어장', style: TextStyle(color: Colors.white)),
            elevation: 8,
            highlightElevation: 12,
          ),
        ),
      ),
    );
  }
}
