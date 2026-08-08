import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class AppConfigService extends ChangeNotifier {
  AppConfigService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  static const String launchFreeMode = 'launch_free';
  static const String freemiumMode = 'freemium';

  static const Map<String, Object> defaults = {
    'monetization_mode': launchFreeMode,
    'enable_banner_ads': false,
    'enable_interstitial_ads': false,
    'enable_paywall': false,
    'founding_program_open': true,
    'show_launch_notice': true,
    'launch_notice_version': 1,
    'launch_notice_title': '출시 초기 모든 기능 무료',
    'launch_notice_message':
        '출시 초기에는 모든 기능을 무료로 제공합니다. 초기 사용자에게는 Founding 혜택이 계정에 등록되며, 향후 추가되는 유료 기능도 무료로 이용할 수 있습니다.',
    'free_wordbook_limit': -1,
    'free_pdf_export_limit': -1,
    'ai_beta_enabled': true,
  };

  final FirebaseRemoteConfig _remoteConfig;
  Future<void>? _initializationFuture;
  bool _initialized = false;
  bool _lastFetchSucceeded = false;

  bool get initialized => _initialized;
  bool get lastFetchSucceeded => _lastFetchSucceeded;

  String _defaultString(String key) => defaults[key] as String;
  bool _defaultBool(String key) => defaults[key] as bool;
  int _defaultInt(String key) => defaults[key] as int;

  String get monetizationMode =>
      _initialized ? _remoteConfig.getString('monetization_mode') : _defaultString('monetization_mode');
  bool get isLaunchFree => monetizationMode != freemiumMode;
  bool get bannerAdsEnabled =>
      _initialized ? _remoteConfig.getBool('enable_banner_ads') : _defaultBool('enable_banner_ads');
  bool get interstitialAdsEnabled =>
      _initialized ? _remoteConfig.getBool('enable_interstitial_ads') : _defaultBool('enable_interstitial_ads');
  bool get paywallEnabled =>
      _initialized ? _remoteConfig.getBool('enable_paywall') : _defaultBool('enable_paywall');
  bool get foundingProgramOpen =>
      _initialized ? _remoteConfig.getBool('founding_program_open') : _defaultBool('founding_program_open');
  bool get launchNoticeEnabled =>
      _initialized ? _remoteConfig.getBool('show_launch_notice') : _defaultBool('show_launch_notice');
  int get launchNoticeVersion =>
      _initialized ? _remoteConfig.getInt('launch_notice_version') : _defaultInt('launch_notice_version');
  String get launchNoticeTitle =>
      _initialized ? _remoteConfig.getString('launch_notice_title') : _defaultString('launch_notice_title');
  String get launchNoticeMessage =>
      _initialized ? _remoteConfig.getString('launch_notice_message') : _defaultString('launch_notice_message');
  int get freeWordbookLimit =>
      _initialized ? _remoteConfig.getInt('free_wordbook_limit') : _defaultInt('free_wordbook_limit');
  int get freePdfExportLimit =>
      _initialized ? _remoteConfig.getInt('free_pdf_export_limit') : _defaultInt('free_pdf_export_limit');
  bool get aiBetaEnabled =>
      _initialized ? _remoteConfig.getBool('ai_beta_enabled') : _defaultBool('ai_beta_enabled');

  Future<void> initialize() {
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _remoteConfig.setDefaults(defaults);
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval:
              kDebugMode ? const Duration(minutes: 5) : const Duration(hours: 6),
        ),
      );
      _lastFetchSucceeded = await _remoteConfig.fetchAndActivate();
    } catch (error) {
      debugPrint('AppConfigService: using in-app defaults: $error');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }
}
