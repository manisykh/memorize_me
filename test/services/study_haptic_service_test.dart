import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:memorize_app/services/study_haptic_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('haptic preference is loaded and persisted', () async {
    SharedPreferences.setMockInitialValues({'study_haptic_enabled': false});

    final service = StudyHapticService();
    addTearDown(service.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(service.enabled, isFalse);

    await service.setEnabled(true);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('study_haptic_enabled'), isTrue);
  });
}
