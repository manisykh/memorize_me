// lib/main.dart (수정된 전체 코드)

import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/ai_settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/entitlement_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/word_list_provider.dart';
import 'providers/wordbook_manager.dart';
import 'screens/app_shell_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/ai_service.dart';
import 'services/analytics_service.dart';
import 'services/api_key_service.dart';
import 'services/app_config_service.dart';
import 'services/csv_service.dart';
import 'services/database_service.dart';
import 'services/mode_state_service.dart'; // ▼▼▼ [추가]
import 'services/sheets_service.dart';
import 'services/test_sheet_service.dart';
import 'services/tts_service.dart';
import 'themes/app_theme.dart';
import 'widgets/gradient_background.dart';
import 'widgets/launch_notice_gate.dart';
import 'providers/flashcard_settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    FirebaseCrashlytics.instance.recordFlutterFatalError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(
    MultiProvider(
      providers: [
        Provider<AnalyticsService>(create: (_) => AnalyticsService()),
        ChangeNotifierProvider<AppConfigService>(
          lazy: false,
          create: (_) => AppConfigService()..initialize(),
        ),
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        Provider<TestSheetService>(create: (_) => TestSheetService()),
        Provider<ApiKeyService>(create: (_) => ApiKeyService()),
        Provider<TtsService>(create: (_) => TtsService()),
        Provider<ModeStateService>(create: (_) => ModeStateService()), // ▼▼▼ [추가]
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<EntitlementProvider>(
          lazy: false,
          create:
              (context) => EntitlementProvider(
                appConfig: context.read<AppConfigService>(),
                analytics: context.read<AnalyticsService>(),
              ),
        ),
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
    return Selector<ThemeNotifier, AppThemeType>(
      selector: (_, themeNotifier) => themeNotifier.currentTheme,
      builder: (context, currentThemeType, child) {
        final theme = AppTheme.appThemes[currentThemeType]!;
        return MaterialApp(
          title: 'Memorize Me',
          theme: theme,
          debugShowCheckedModeBanner: false,
          navigatorObservers: [context.read<AnalyticsService>().observer],
          builder: (context, child) {
            final content = child ?? const SizedBox.shrink();
            return Selector<ThemeNotifier, int>(
              selector: (_, themeNotifier) => themeNotifier.eyeCareLevel,
              builder: (context, eyeCareLevel, _) {
                final backgroundColor = _backgroundColorFor(
                  theme,
                  currentThemeType,
                  eyeCareLevel,
                );
                final effectiveTheme =
                    currentThemeType == AppThemeType.visionProtection
                        ? theme.copyWith(scaffoldBackgroundColor: backgroundColor)
                        : theme;

                if (currentThemeType == AppThemeType.lightGreen) {
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: _systemUiOverlayStyle(
                      effectiveTheme,
                      currentThemeType,
                      backgroundColor,
                    ),
                    child: Theme(
                      data: effectiveTheme,
                      child: GradientBackground(child: content),
                    ),
                  );
                }

                return AnnotatedRegion<SystemUiOverlayStyle>(
                  value: _systemUiOverlayStyle(
                    effectiveTheme,
                    currentThemeType,
                    backgroundColor,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    color: backgroundColor,
                    child: Theme(data: effectiveTheme, child: content),
                  ),
                );
              },
            );
          },
          home: const AppInitializer(),
        );
      },
    );
  }

  Color _backgroundColorFor(
    ThemeData theme,
    AppThemeType themeType,
    int eyeCareLevel,
  ) {
    if (themeType == AppThemeType.visionProtection) {
      final levelIndex =
          (eyeCareLevel - 1).clamp(0, AppTheme.visionProtectionColors.length - 1).toInt();
      return AppTheme.visionProtectionColors[levelIndex];
    }
    return theme.scaffoldBackgroundColor;
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
      AppThemeType.visionProtection => Color.alphaBlend(
        Colors.white.withValues(alpha: 0.50),
        fallbackSurfaceColor,
      ),
    };
    final navigationBarColor = switch (themeType) {
      AppThemeType.lightGreen => Colors.white,
      AppThemeType.dark => const Color(0xFF3A2E24),
      AppThemeType.visionProtection => Color.alphaBlend(
        Colors.white.withValues(alpha: 0.42),
        fallbackSurfaceColor,
      ),
    };
    final dividerColor = switch (themeType) {
      AppThemeType.lightGreen => const Color(0xFFDCDCE0),
      AppThemeType.dark => const Color(0xFF604A35),
      AppThemeType.visionProtection => Color.alphaBlend(
        const Color(0xFFE5D6BD).withValues(alpha: 0.72),
        fallbackSurfaceColor,
      ),
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
  static const String _onboardingSeenKey = 'onboarding_seen_v1';

  late Future<_InitialAppState> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initialize();
  }

  Future<_InitialAppState> _initialize() async {
    unawaited(context.read<AppConfigService>().initialize());
    unawaited(context.read<EntitlementProvider>().initialize());
    await context.read<WordbookManager>().loadInitialData();
    final prefs = await SharedPreferences.getInstance();
    return _InitialAppState(
      shouldShowOnboarding: !(prefs.getBool(_onboardingSeenKey) ?? false),
    );
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingSeenKey, true);
    await context.read<AnalyticsService>().logOnboardingCompleted();
    if (mounted) {
      setState(() {
        _initializationFuture = Future.value(
          const _InitialAppState(shouldShowOnboarding: false),
        );
      });
    }
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
          final appState = snapshot.data ?? const _InitialAppState();
          if (appState.shouldShowOnboarding) {
            return OnboardingScreen(onFinished: _finishOnboarding);
          }
          return const LaunchNoticeGate(child: AppShellScreen());
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: const Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}

class _InitialAppState {
  const _InitialAppState({this.shouldShowOnboarding = false});

  final bool shouldShowOnboarding;
}
