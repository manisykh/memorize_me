import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();

  TtsService() {
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setPitch(1.0);

    // ▼▼▼ 진단용 코드로 변경 ▼▼▼
    // 기기에 설치된 모든 음성 데이터를 가져와서 출력합니다.
    try {
      final voices = await _flutterTts.getVoices as List;
      debugPrint("===== 사용 가능한 TTS 음성 목록 =====");
      for (var voice in voices) {
        // 영어(en-US) 음성만 필터링해서 보여줍니다.
        if ((voice as Map)['locale'] == 'en-US') {
          debugPrint(voice.toString());
        }
      }
      debugPrint("===================================");
    } catch (e) {
      debugPrint("음성 목록을 가져오는 데 실패했습니다: $e");
    }
  }

  // 특정 음성을 선택하는 메서드 (향후 사용 가능)
  // Future<void> setVoiceByName(String name) async {
  //   await _flutterTts.setVoice({"name": name, "locale": "en-US"});
  // }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
