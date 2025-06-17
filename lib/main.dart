// main.dart (수정 후)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 분리된 파일들을 import
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/word_list_provider.dart';
import 'providers/wordbook_manager.dart';
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
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<TestSheetService>(create: (_) => TestSheetService()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
        ProxyProvider<DatabaseService, CsvService>(
          update: (_, databaseService, __) => CsvService(databaseService),
        ),
        ProxyProvider<AuthProvider, SheetsService>(
          update: (_, authProvider, __) => SheetsService(authProvider),
        ),
        ChangeNotifierProvider<WordListNotifier>(
          create: (context) => WordListNotifier(context.read<DatabaseService>()),
        ),
        ChangeNotifierProxyProvider<WordListNotifier, SettingsNotifier>(
          create: (context) => SettingsNotifier(),
          update: (context, wordList, settings) {
            if (settings == null) return SettingsNotifier();
            settings.resetWordCountToMax(wordList.words);
            return settings;
          },
        ),
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
    // ThemeNotifier를 watch하여 테마 변경을 감지합니다.
    final themeNotifier = context.watch<ThemeNotifier>();

    // 현재 선택된 테마 타입에 따라 적절한 ThemeData를 선택합니다.
    final ThemeData currentThemeData;
    switch (themeNotifier.currentTheme) {
      case AppThemeType.eyeCare:
        currentThemeData = AppTheme.eyeCareTheme;
        break;
      case AppThemeType.basic:
      default:
        currentThemeData = AppTheme.defaultTheme;
        break;
    }

    return MaterialApp(
      title: '단어 학습 앱',
      // themeMode, darkTheme 대신 theme에 직접 적용합니다.
      theme: currentThemeData,
      debugShowCheckedModeBanner: false,
      home: const AppInitializer(),
    );
  }
}

/// 앱의 초기화 로직을 안정적으로 처리하기 위한 StatefulWidget
class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  late final Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = context.read<WordbookManager>().loadWordbooks();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Scaffold(body: Center(child: Text('앱 초기화 실패:\n${snapshot.error}')));
          }
          return const HomeScreen();
        }
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}
