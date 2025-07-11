// lib/main.dart (수정된 전체 코드)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/ai_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/word_list_provider.dart';
import 'providers/wordbook_manager.dart';
import 'screens/home_screen.dart';
import 'services/ai_service.dart';
import 'services/api_key_service.dart';
import 'services/csv_service.dart';
import 'services/database_service.dart';
import 'services/mode_state_service.dart'; // ▼▼▼ [추가]
import 'services/sheets_service.dart';
import 'services/test_sheet_service.dart';
import 'services/tts_service.dart';
import 'themes/app_theme.dart';
import 'widgets/gradient_background.dart';
import 'providers/flashcard_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<TestSheetService>(create: (_) => TestSheetService()),
        Provider<ApiKeyService>(create: (_) => ApiKeyService()),
        Provider<TtsService>(create: (_) => TtsService()),
        Provider<ModeStateService>(create: (_) => ModeStateService()), // ▼▼▼ [추가]
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider<AiSettingsProvider>(create: (_) => AiSettingsProvider()),
        ChangeNotifierProvider<FlashcardSettingsProvider>(
          create: (_) => FlashcardSettingsProvider(),
        ),
        ProxyProvider<ApiKeyService, AiService>(
          update: (_, apiKeyService, __) => AiService(apiKeyService),
        ),
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
    return Consumer<ThemeNotifier>(
      builder: (context, themeNotifier, child) {
        return MaterialApp(
          title: 'Memorize Me',
          theme: themeNotifier.getTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final currentThemeType = themeNotifier.currentTheme;
            if (currentThemeType == AppThemeType.lightGreen) {
              return GradientBackground(child: child!);
            }
            Color backgroundColor;
            if (currentThemeType == AppThemeType.visionProtection) {
              int levelIndex = (themeNotifier.eyeCareLevel - 1).clamp(0, 4);
              backgroundColor = AppTheme.visionProtectionColors[levelIndex];
            } else {
              backgroundColor = Theme.of(context).scaffoldBackgroundColor;
            }
            return Container(color: backgroundColor, child: child);
          },
          home: const AppInitializer(),
        );
      },
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
    _initializationFuture = context.read<WordbookManager>().loadInitialData();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Center(child: Text('앱 초기화 실패:\n${snapshot.error}')),
            );
          }
          return const HomeScreen();
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
