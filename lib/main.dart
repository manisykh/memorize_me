// lib/main.dart (수정된 전체 코드)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'providers/ai_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/word_list_provider.dart';
import 'providers/wordbook_manager.dart';
import 'screens/app_shell_screen.dart';
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
        final theme = themeNotifier.getTheme();
        return MaterialApp(
          title: 'Memorize Me',
          theme: theme,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            final currentThemeType = themeNotifier.currentTheme;
            final content = child ?? const SizedBox.shrink();
            Color backgroundColor;
            if (currentThemeType == AppThemeType.lightGreen) {
              backgroundColor = theme.scaffoldBackgroundColor;
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: _systemUiOverlayStyle(theme, currentThemeType, backgroundColor),
                child: GradientBackground(child: content),
              );
            } else if (currentThemeType == AppThemeType.visionProtection) {
              int levelIndex = (themeNotifier.eyeCareLevel - 1).clamp(0, 4);
              backgroundColor = AppTheme.visionProtectionColors[levelIndex];
            } else {
              backgroundColor = theme.scaffoldBackgroundColor;
            }
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: _systemUiOverlayStyle(theme, currentThemeType, backgroundColor),
              child: Container(color: backgroundColor, child: content),
            );
          },
          home: const AppInitializer(),
        );
      },
    );
  }

  SystemUiOverlayStyle _systemUiOverlayStyle(
    ThemeData theme,
    AppThemeType themeType,
    Color fallbackSurfaceColor,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final statusBarColor = switch (themeType) {
      AppThemeType.lightGreen => Colors.white,
      AppThemeType.dark => const Color(0xFF2D241C),
      AppThemeType.visionProtection => const Color(0xFFFFF8ED),
    };
    final navigationBarColor = switch (themeType) {
      AppThemeType.lightGreen => Colors.white,
      AppThemeType.dark => const Color(0xFF3A2E24),
      AppThemeType.visionProtection => const Color(0xFFFBF6EC),
    };
    final dividerColor = switch (themeType) {
      AppThemeType.lightGreen => const Color(0xFFDCDCE0),
      AppThemeType.dark => const Color(0xFF604A35),
      AppThemeType.visionProtection => const Color(0xFFE5D6BD),
    };

    return SystemUiOverlayStyle(
      statusBarColor:
          statusBarColor == Colors.transparent ? fallbackSurfaceColor : statusBarColor,
      systemNavigationBarColor: navigationBarColor,
      systemNavigationBarDividerColor: dividerColor,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemStatusBarContrastEnforced: true,
      systemNavigationBarContrastEnforced: true,
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
          return const AppShellScreen();
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
