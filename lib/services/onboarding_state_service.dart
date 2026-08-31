import 'package:shared_preferences/shared_preferences.dart';

class OnboardingStateService {
  const OnboardingStateService();

  static const String seenKey = 'onboarding_seen_v1';

  Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(seenKey) ?? false);
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(seenKey, true);
  }
}
