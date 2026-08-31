// lib/main.dart (수정된 전체 코드)

import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

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
import 'services/onboarding_state_service.dart';
import 'services/sheets_service.dart';
import 'services/study_sound_service.dart';
import 'services/test_sheet_service.dart';
import 'services/tts_service.dart';
import 'themes/app_theme.dart';
import 'widgets/gradient_background.dart';
import 'widgets/launch_notice_gate.dart';
import 'providers/flashcard_settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
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
        ChangeNotifierProvider<StudySoundService>(
          create: (_) => StudySoundService(),
        ),
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
        ChangeNotifierProxyProvider2<
          DatabaseService,
          WordListNotifier,
          WordbookManager
        >(
          create:
              (context) => WordbookManager(
                context.read<DatabaseService>(),
                context.read<WordListNotifier>(),
              ),
          update:
              (_, dbService, wordList, manager) =>
                  manager ?? WordbookManager(dbService, wordList),
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
                final effectiveTheme =
                    currentThemeType == AppThemeType.visionProtection
                        ? AppTheme.visionProtectionThemeForLevel(eyeCareLevel)
                        : theme;
                final backgroundColor = effectiveTheme.scaffoldBackgroundColor;

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
  final OnboardingStateService _onboardingState = const OnboardingStateService();
  late Future<bool> _onboardingDecisionFuture;
  late Future<void> _metadataInitializationFuture;
  bool _activeWordbookLoadStarted = false;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  void _startInitialization() {
    unawaited(context.read<AppConfigService>().initialize());
    unawaited(context.read<EntitlementProvider>().initialize());
    _onboardingDecisionFuture = _onboardingState.shouldShow();
    _metadataInitializationFuture = _loadWordbookMetadata();
    _activeWordbookLoadStarted = false;
    unawaited(
      _metadataInitializationFuture.then((_) {
        _startActiveWordbookLoad();
      }).catchError((_) {}),
    );
  }

  Future<void> _loadWordbookMetadata() async {
    try {
      await context.read<WordbookManager>().loadInitialMetadata();
    } catch (error, stackTrace) {
      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: 'Wordbook metadata initialization failed',
      );
      rethrow;
    }
  }

  void _retryInitialization() {
    setState(_startInitialization);
  }

  void _startActiveWordbookLoad() {
    if (_activeWordbookLoadStarted) return;
    _activeWordbookLoadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        context.read<WordbookManager>().loadActiveWordbookWords().catchError((
          Object error,
          StackTrace stackTrace,
        ) async {
          await FirebaseCrashlytics.instance.recordError(
            error,
            stackTrace,
            reason: 'Active wordbook loading failed',
          );
        }),
      );
    });
  }

  Future<void> _finishOnboarding() async {
    await _onboardingState.markSeen();
    await context.read<AnalyticsService>().logOnboardingCompleted();
    if (mounted) {
      setState(() {
        _onboardingDecisionFuture = Future.value(false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _onboardingDecisionFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InitializationErrorScreen(onRetry: _retryInitialization);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BrandStartupScreen();
        }
        if (snapshot.data == true) {
          return OnboardingScreen(onFinished: _finishOnboarding);
        }
        return FutureBuilder<void>(
          future: _metadataInitializationFuture,
          builder: (context, metadataSnapshot) {
            if (metadataSnapshot.hasError) {
              return _InitializationErrorScreen(onRetry: _retryInitialization);
            }
            if (metadataSnapshot.connectionState != ConnectionState.done) {
              return const _BrandStartupScreen();
            }
            _startActiveWordbookLoad();
            return const _ReadyAppShell();
          },
        );
      },
    );
  }
}

class _ReadyAppShell extends StatelessWidget {
  const _ReadyAppShell();

  @override
  Widget build(BuildContext context) {
    return Consumer<WordbookManager>(
      builder: (context, manager, _) {
        return Stack(
          children: [
            const LaunchNoticeGate(child: AppShellScreen()),
            if (manager.isActiveWordbookLoading)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (manager.activeWordbookLoadError != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.paddingOf(context).bottom + 18,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded),
                        const SizedBox(width: 10),
                        const Expanded(child: Text('단어장을 불러오지 못했습니다.')),
                        TextButton(
                          onPressed: () {
                            unawaited(
                              manager.retryActiveWordbookWords().catchError((_) {}),
                            );
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _BrandStartupScreen extends StatelessWidget {
  const _BrandStartupScreen();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    Icons.layers_rounded,
                    size: 42,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Memorize Me',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitializationErrorScreen extends StatelessWidget {
  const _InitializationErrorScreen({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.sync_problem_rounded,
                  size: 52,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 18),
                Text(
                  '앱을 준비하지 못했습니다',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '잠시 후 다시 시도해주세요. 저장된 단어장은 삭제되지 않습니다.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
