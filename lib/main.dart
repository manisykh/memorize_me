// main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 분리된 파일들을 import
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/word_list_provider.dart';
import 'providers/wordbook_manager.dart'; // WordbookManager import
import 'screens/home_screen.dart';
import 'services/csv_service.dart';
import 'services/database_service.dart';
import 'services/test_sheet_service.dart';
import 'themes/app_theme.dart';
import 'services/sheets_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        // --- 레벨 1: 의존성 없는 기본 서비스 및 Notifier ---
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<TestSheetService>(create: (_) => TestSheetService()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<SettingsNotifier>(create: (_) => SettingsNotifier()),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),

        // --- 레벨 2: 레벨 1에 의존하는 서비스 ---
        ProxyProvider<DatabaseService, CsvService>(
          update: (_, databaseService, __) => CsvService(databaseService),
        ),
        ProxyProvider<AuthProvider, SheetsService>(
          update: (_, authProvider, __) => SheetsService(authProvider),
        ),

        // --- 레벨 3: WordListNotifier (단일 인스턴스로 존재) ---
        // WordbookManager가 WordListNotifier를 직접 제어하므로 먼저 생성합니다.
        ChangeNotifierProvider<WordListNotifier>(
          create: (context) => WordListNotifier(context.read<DatabaseService>()),
        ),

        // --- 레벨 4: WordbookManager (핵심 총괄 관리자) ---
        // 앱의 단어장 관련 모든 상태를 관리합니다.
        ChangeNotifierProxyProvider3<
          DatabaseService,
          SheetsService,
          WordListNotifier,
          WordbookManager
        >(
          create:
              (context) => WordbookManager(
                context.read<DatabaseService>(),
                context.read<SheetsService>(),
                context.read<WordListNotifier>(),
              ),
          update:
              (_, dbService, sheetsService, wordList, manager) =>
                  manager ?? WordbookManager(dbService, sheetsService, wordList),
        ),
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      // ▼▼▼ 수정된 부분 ▼▼▼
      // FutureBuilder를 사용하여 앱 초기화 과정을 처리합니다.
      home: FutureBuilder(
        // WordbookManager의 loadWordbooks를 실행하고 완료될 때까지 기다립니다.
        future: context.read<WordbookManager>().loadWordbooks(),
        builder: (context, snapshot) {
          // 로딩이 완료되면 HomeScreen을 보여줍니다.
          if (snapshot.connectionState == ConnectionState.done) {
            return const HomeScreen();
          }
          // 로딩 중에는 로딩 화면(Splash Screen)을 보여줍니다.
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        },
      ),
      // ▲▲▲ 수정된 부분 ▲▲▲
    );
  }
}
