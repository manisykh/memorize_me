// services/tts_service.dart

import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsService() {
    _initTts();
  }

  void _initTts() async {
    // TTS 엔진 초기화 및 기본 설정
    await _flutterTts.setLanguage("en-US"); // 영어 발음으로 설정
    await _flutterTts.setSpeechRate(0.5); // 발음 속도 조절
    await _flutterTts.setPitch(1.0); // 음높이 조절
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
