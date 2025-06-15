import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// 분리된 파일들을 import
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/word_list_provider.dart';
import 'screens/home_screen.dart';
import 'services/csv_service.dart';
import 'services/database_service.dart';
import 'services/test_sheet_service.dart';
import 'themes/app_theme.dart';
import 'services/sheets_service.dart';

void main() async {
  // async 키워드 추가
  // runApp을 실행하기 전에 Flutter 엔진과 위젯 바인딩이 완전히 초기화되도록 보장합니다.
  WidgetsFlutterBinding.ensureInitialized();

  // (선택사항) 나중에 다른 비동기 초기화 로직(예: 날짜 포맷)이 필요하다면 여기에 추가할 수 있습니다.
  // await initializeDateFormatting('ko_KR', null);

  // 모든 준비가 끝난 후 앱을 실행합니다.
  runApp(
    MultiProvider(
      providers: [
        // 레벨 1: 의존성이 없는 기본 서비스들
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<TestSheetService>(create: (_) => TestSheetService()),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<SettingsNotifier>(create: (_) => SettingsNotifier()),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),

        // 레벨 2: DatabaseService에 의존하는 서비스들
        ProxyProvider<DatabaseService, CsvService>(
          update: (context, databaseService, previous) => CsvService(databaseService),
        ),

        // 레벨 3: AuthProvider에 의존하는 서비스들
        ProxyProvider<AuthProvider, SheetsService>(
          update: (context, authProvider, previous) => SheetsService(authProvider),
        ),

        // 레벨 4: DatabaseService에 의존하는 ChangeNotifier들
        ChangeNotifierProxyProvider<DatabaseService, WordListNotifier>(
          create: (context) => WordListNotifier(context.read<DatabaseService>()),
          update:
              (context, databaseService, previous) => previous ?? WordListNotifier(databaseService),
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
      theme: AppTheme.lightTheme, // 라이트 모드 테마
      darkTheme: AppTheme.darkTheme, // 다크 모드 테마
      home: const HomeScreen(), // 앱의 첫 화면 지정
      debugShowCheckedModeBanner: false,
    );
  }
}
