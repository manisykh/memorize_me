import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StudySoundEffect { correct, incorrect, knownSwipe, unknownSwipe }

class StudySoundService extends ChangeNotifier {
  static const _enabledKey = 'study_sound_enabled';
  static const Map<StudySoundEffect, String> _assetPaths = {
    StudySoundEffect.correct: 'sounds/study_correct.wav',
    StudySoundEffect.incorrect: 'sounds/study_incorrect.wav',
    StudySoundEffect.knownSwipe: 'sounds/study_known_swipe.wav',
    StudySoundEffect.unknownSwipe: 'sounds/study_unknown_swipe.wav',
  };

  static const _playbackVolume = 0.80;

  final Map<StudySoundEffect, AudioPlayer> _players = {};
  late final Future<void> _prepareFuture;
  AudioPlayer? _activePlayer;
  bool _enabled = true;

  bool get enabled => _enabled;

  StudySoundService() {
    unawaited(_load());
    _prepareFuture = _preparePlayers();
  }

  Future<void> _preparePlayers() async {
    for (final entry in _assetPaths.entries) {
      final player = AudioPlayer();
      try {
        await player.setPlayerMode(PlayerMode.lowLatency);
      } catch (_) {
        // Keep the platform default when low-latency mode is unavailable.
      }
      try {
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setVolume(_playbackVolume);
        await player.setSource(AssetSource(entry.value));
        _players[entry.key] = player;
      } catch (_) {
        await player.dispose();
      }
    }
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

  Future<void> play(StudySoundEffect effect) async {
    if (!_enabled) return;
    final assetPath = _assetPaths[effect];
    if (assetPath == null) return;
    try {
      await _prepareFuture;
      final player = _players[effect];
      if (player == null) return;
      if (_activePlayer != null) await _activePlayer!.stop();
      _activePlayer = player;
      await player.resume();
    } catch (_) {
      // Sound feedback must never interrupt a study session.
    }
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      unawaited(player.dispose());
    }
    super.dispose();
  }
}
