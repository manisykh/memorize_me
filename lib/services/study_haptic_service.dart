import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudyHapticEffect { cardFlip, knownOrCorrect, unknownOrIncorrect }

class StudyHapticService extends ChangeNotifier {
  static const _enabledKey = 'study_haptic_enabled';
  static const _channel = MethodChannel('memorize_me/study_haptics');

  bool _enabled = true;

  bool get enabled => _enabled;

  StudyHapticService() {
    unawaited(_load());
  }

  Future<void> _load() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_enabledKey) ?? true;
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, value);
  }

  Future<void> play(StudyHapticEffect effect) async {
    if (!_enabled) return;
    try {
      final played = await _channel.invokeMethod<bool>('play', {
        'effect': effect.name,
      });
      if (played == true) return;
    } catch (_) {
      // Fall back to Flutter's platform haptics outside Android or when the
      // native channel is temporarily unavailable.
    }

    try {
      switch (effect) {
        case StudyHapticEffect.cardFlip:
          await HapticFeedback.mediumImpact();
        case StudyHapticEffect.knownOrCorrect:
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 65));
          await HapticFeedback.mediumImpact();
        case StudyHapticEffect.unknownOrIncorrect:
          await HapticFeedback.vibrate();
      }
    } catch (_) {
      // Haptic feedback must never interrupt a study session.
    }
  }
}
