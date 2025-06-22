// main.dart (전체 수정 코드)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

// ▼▼▼ [추가] 새로운 서비스 import ▼▼▼
import 'services/api_key_service.dart';
import 'services/ai_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        // --- 독립 서비스 및 Notifier ---
        // 이들은 다른 Provider에 의존하지 않습니다.
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<TestSheetService>(create: (_) => TestSheetService()),
        Provider<ApiKeyService>(create: (_) => ApiKeyService()), // [추가] API 키 서비스
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),

        // --- 의존성을 가진 서비스 (ProxyProvider 사용) ---
        // 다른 Provider의 상태가 변경될 때마다 새로 생성되거나 업데이트됩니다.

        // AiService는 ApiKeyService에 의존합니다.
        ProxyProvider<ApiKeyService, AiService>(
          update: (_, apiKeyService, __) => AiService(apiKeyService),
        ),

        // CsvService는 DatabaseService에 의존합니다.
        ProxyProvider<DatabaseService, CsvService>(
          update: (_, databaseService, __) => CsvService(databaseService),
        ),

        // SheetsService는 AuthProvider에 의존합니다.
        ProxyProvider<AuthProvider, SheetsService>(
          update: (_, authProvider, __) => SheetsService(authProvider),
        ),

        // --- 의존성을 가진 Notifier ---

        // WordListNotifier는 DatabaseService에 의존합니다.
        ChangeNotifierProvider<WordListNotifier>(
          create: (context) => WordListNotifier(context.read<DatabaseService>()),
        ),

        // SettingsNotifier는 WordListNotifier의 상태 변경에 따라 업데이트됩니다.
        ChangeNotifierProxyProvider<WordListNotifier, SettingsNotifier>(
          create: (context) => SettingsNotifier(),
          update: (context, wordList, settings) {
            if (settings == null) return SettingsNotifier();
            settings.resetWordCountToMax(wordList.words);
            return settings;
          },
        ),

        // WordbookManager는 3개의 다른 서비스/Notifier에 의존합니다.
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
      theme: currentThemeData,
      debugShowCheckedModeBanner: false,
      home: const AppInitializer(),
    );
  }
}

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
    // 앱 시작 시 WordbookManager를 통해 모든 초기 데이터를 로드합니다.
    _initializationFuture = context.read<WordbookManager>().loadInitialData();
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
