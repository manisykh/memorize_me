import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ▼▼▼ 아래 import 구문들이 모두 있는지 확인하고, 빠진 부분을 추가해주세요 ▼▼▼

// providers 폴더
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/word_list_provider.dart';

// screens 폴더
import 'screens/home_screen.dart';

// services 폴더
import 'services/csv_service.dart';
import 'services/database_service.dart';
import 'services/test_sheet_service.dart';

// themes 폴더
import 'themes/app_theme.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<CsvService>(create: (context) => CsvService(context.read<DatabaseService>())),
        Provider<TestSheetService>(create: (_) => TestSheetService()),
        ChangeNotifierProvider<WordListNotifier>(
          create: (context) => WordListNotifier(context.read<DatabaseService>()),
        ),
        ChangeNotifierProvider<SettingsNotifier>(create: (_) => SettingsNotifier()),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    return MaterialApp(
      title: '단어 학습 앱',
      themeMode: themeNotifier.themeMode,
      theme: AppTheme.lightTheme, // 라이트 모드 테마
      darkTheme: AppTheme.darkTheme, // 다크 모드 테마
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
