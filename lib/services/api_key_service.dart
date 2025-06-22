// lib/services/api_key_service.dart (새 파일)

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// 어떤 AI 제공자인지 구분하기 위한 Enum
enum AiProvider { gemini, openAI }

class ApiKeyService {
  final _storage = const FlutterSecureStorage();

  // 프로바이더별 키 이름 정의
  String _keyName(AiProvider provider) {
    return 'api_key_${provider.name}';
  }

  // API 키 저장
  Future<void> saveApiKey(AiProvider provider, String apiKey) async {
    await _storage.write(key: _keyName(provider), value: apiKey);
  }

  // API 키 불러오기
  Future<String?> getApiKey(AiProvider provider) async {
    return await _storage.read(key: _keyName(provider));
  }

  // API 키 삭제 (선택적 기능)
  Future<void> deleteApiKey(AiProvider provider) async {
    await _storage.delete(key: _keyName(provider));
  }
}
