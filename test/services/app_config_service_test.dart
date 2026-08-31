import 'package:flutter_test/flutter_test.dart';
import 'package:memorize_app/services/app_config_service.dart';

class FakeAppConfigBackend implements AppConfigBackend {
  FakeAppConfigBackend({this.failOnPrepare = false, Map<String, Object>? values})
    : values = values ?? <String, Object>{};

  final bool failOnPrepare;
  final Map<String, Object> values;

  @override
  Future<void> prepare(
    Map<String, Object> defaults, {
    required Duration fetchTimeout,
    required Duration minimumFetchInterval,
  }) async {
    if (failOnPrepare) throw StateError('offline');
    for (final entry in defaults.entries) {
      values.putIfAbsent(entry.key, () => entry.value);
    }
  }

  @override
  Future<bool> fetchAndActivate() async => true;

  @override
  bool getBool(String key) => values[key] as bool;

  @override
  int getInt(String key) => values[key] as int;

  @override
  String getString(String key) => values[key] as String;
}

void main() {
  test('초기화 전에는 앱 내부 기본값을 사용한다', () {
    final service = AppConfigService(backend: FakeAppConfigBackend());

    expect(service.isLaunchFree, isTrue);
    expect(service.bannerAdsEnabled, isFalse);
    expect(service.foundingProgramOpen, isTrue);
    expect(service.freeWordbookLimit, -1);
  });

  test('Remote Config 준비가 실패해도 기본값으로 초기화된다', () async {
    final service = AppConfigService(
      backend: FakeAppConfigBackend(failOnPrepare: true),
    );

    await service.initialize();

    expect(service.initialized, isTrue);
    expect(service.lastFetchSucceeded, isFalse);
    expect(service.isLaunchFree, isTrue);
    expect(service.paywallEnabled, isFalse);
    expect(service.aiBetaEnabled, isTrue);
  });

  test('초기화 성공 시 원격 값을 사용한다', () async {
    final service = AppConfigService(
      backend: FakeAppConfigBackend(
        values: {
          'monetization_mode': AppConfigService.freemiumMode,
          'enable_paywall': true,
        },
      ),
    );

    await service.initialize();

    expect(service.lastFetchSucceeded, isTrue);
    expect(service.isLaunchFree, isFalse);
    expect(service.paywallEnabled, isTrue);
  });
}
