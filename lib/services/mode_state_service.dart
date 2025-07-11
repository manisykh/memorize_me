// lib/services/mode_state_service.dart (신규 파일)

import 'package:shared_preferences/shared_preferences.dart';

// 각 학습 모드를 식별하기 위한 열거형(Enum)
enum LearningMode { flashcard, quiz, aiQuiz, srsStatus }

class ModeStateService {
  static const _prefix = 'last_wordbook_id_';

  // 특정 모드에 대해 마지막으로 사용한 단어장 ID를 저장합니다.
  Future<void> setLastUsedWordbookId(LearningMode mode, int wordbookId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_prefix${mode.name}', wordbookId);
  }

  // 특정 모드의 마지막 단어장 ID를 불러옵니다.
  Future<int?> getLastUsedWordbookId(LearningMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_prefix${mode.name}');
  }
}
