import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

class _TtsTask {
  final Map<String, String>? voice;
  final String text;
  _TtsTask(this.voice, this.text);
}

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  final Queue<_TtsTask> _speakQueue = Queue();
  List<Map<String, String>> _voices = [];
  Map<String, String>? _selectedVoice;

  Map<String, String>? get selectedVoice => _selectedVoice;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    _flutterTts.setCompletionHandler(() => _speakNextInQueue());
    if (Platform.isIOS) {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts
          .setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          ]);
    }
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);
    try {
      var voices = await _flutterTts.getVoices;
      if (voices != null) {
        _voices = List<Map<String, String>>.from(
          voices.map((v) => Map<String, String>.from(v)),
        );
        _selectedVoice =
            await _loadVoicePreference('tts_voice') ??
            await _loadVoicePreference('female_voice');
        if (_selectedVoice == null) {
          final englishVoices =
              _voices
                  .where((v) => v['locale']?.toLowerCase() == 'en-us')
                  .toList();
          if (englishVoices.isNotEmpty) {
            _selectedVoice =
                _findVoice(englishVoices, ['female', 'woman']) ??
                englishVoices.first;
          }
        }
        debugPrint("선택된 학습 음성: $_selectedVoice");
      }
    } catch (e) {
      debugPrint("음성 목록을 가져오는 데 실패했습니다: $e");
    }
  }

  Map<String, String>? _findVoice(
    List<Map<String, String>> voiceList,
    List<String> keywords,
  ) {
    for (var keyword in keywords) {
      try {
        return voiceList.firstWhere(
          (v) =>
              v['name']!.toLowerCase().contains(keyword) ||
              (v['gender'] != null && v['gender']!.toLowerCase() == keyword),
        );
      } catch (_) {
        // 해당 키워드와 맞는 음성이 없으면 다음 키워드로 계속 탐색합니다.
      }
    }
    return null;
  }

  Future<List<Map<String, String>>> getEnglishVoices() async {
    if (_voices.isEmpty) {
      var voices = await _flutterTts.getVoices;
      if (voices != null) {
        _voices = List<Map<String, String>>.from(
          voices.map((v) => Map<String, String>.from(v)),
        );
      }
    }
    return _voices.where((v) => v['locale']?.toLowerCase() == 'en-us').toList();
  }

  Future<void> setVoice(Map<String, String> voice) async {
    _selectedVoice = voice;
    await _saveVoicePreference('tts_voice', voice);
  }

  Future<void> speakWithVoice(Map<String, String> voice, String text) async {
    await stop();
    await _flutterTts.setVoice(voice);
    await _flutterTts.speak(text);
  }

  Future<void> _saveVoicePreference(
    String key,
    Map<String, String> voice,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(voice));
  }

  Future<Map<String, String>?> _loadVoicePreference(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final voiceString = prefs.getString(key);
    if (voiceString != null) {
      try {
        return Map<String, String>.from(jsonDecode(voiceString));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await stop();
      await _flutterTts.setLanguage("en-US");
      if (_selectedVoice != null) await _flutterTts.setVoice(_selectedVoice!);
      await _flutterTts.speak(text);
    }
  }

  Future<void> speakDialogue(String script) async {
    if (_isSpeaking) {
      await stop();
      return;
    }
    _isSpeaking = true;
    _speakQueue.clear();
    final parts = script.split(RegExp(r'(?=\[MALE\]|\[FEMALE\])'));
    for (final part in parts) {
      String textToSpeak;
      if (part.startsWith('[MALE]')) {
        textToSpeak = part.substring(6).trim();
      } else if (part.startsWith('[FEMALE]')) {
        textToSpeak = part.substring(8).trim();
      } else {
        textToSpeak = part.trim();
      }
      if (textToSpeak.isNotEmpty) {
        _speakQueue.add(_TtsTask(_selectedVoice, textToSpeak));
      }
    }
    _speakNextInQueue();
  }

  void _speakNextInQueue() async {
    if (_speakQueue.isNotEmpty && _isSpeaking) {
      final task = _speakQueue.removeFirst();
      if (task.voice != null) {
        await _flutterTts.setVoice(task.voice!);
      }
      await _flutterTts.speak(task.text);
    } else {
      _isSpeaking = false;
    }
  }

  Future<void> stop() async {
    _isSpeaking = false;
    _speakQueue.clear();
    await _flutterTts.stop();
  }
}
