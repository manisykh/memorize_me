import '../services/ai_service.dart';

String aiUserFacingErrorMessage(Object error) {
  if (error is CustomApiException) {
    return switch (error.code) {
      'api_key_missing' => '${error.message}\n\n설정 탭에서 사용할 AI 회사와 API 키를 등록해주세요.',
      'api_key_invalid' => '${error.message}\n\nAPI 키가 만료되었거나 잘못 입력되었을 수 있습니다.',
      'endpoint_missing' =>
        '${error.message}\n\nCustom OpenAI Compatible 또는 NVIDIA NIM을 쓰는 경우 Chat Completions Endpoint가 필요합니다.',
      'fallback_exhausted' =>
        '${error.message}\n\n자동 대체 후보의 API 키, 모델명, endpoint를 확인해주세요.',
      'quota_exceeded' =>
        'API 사용량 한도를 초과했습니다.\n\n문제 수를 줄이거나, 잠시 후 다시 시도하거나, 자동 대체 모델을 사용해주세요.',
      'server_overloaded' =>
        'AI 서버가 현재 바쁩니다.\n\n잠시 후 다시 시도하거나 자동 대체 모델을 사용해주세요.',
      'request_timeout' =>
        'AI 응답 시간이 초과되었습니다.\n\n문제 수나 선택 단어 수를 줄인 뒤 다시 시도해주세요.',
      'network_error' => '네트워크 연결을 확인한 뒤 다시 시도해주세요.',
      'model_response_invalid' =>
        'AI 응답을 문제로 변환하지 못했습니다.\n\n문제 수를 줄이거나 다른 모델로 다시 생성해주세요.',
      'model_request_failed' =>
        '${error.message}\n\n모델명이 제공자의 실제 모델 ID와 일치하는지 확인해주세요.',
      'sentence_generation_failed' =>
        '예문 생성에 실패했습니다.\n\n선택 단어 수를 줄이거나 다른 모델로 다시 시도해주세요.',
      'openai_request_failed' =>
        '${error.message}\n\nEndpoint, 모델명, API 키가 서로 맞는지 확인해주세요.',
      'anthropic_request_failed' => '${error.message}\n\n모델명과 API 키를 확인해주세요.',
      'unknown_error' => error.message,
      _ => error.message,
    };
  }
  return '알 수 없는 오류가 발생했습니다: $error';
}

bool aiErrorShouldOpenSettings(Object error) {
  return error is CustomApiException &&
      {
        'api_key_missing',
        'api_key_invalid',
        'endpoint_missing',
        'fallback_exhausted',
        'model_request_failed',
        'openai_request_failed',
        'anthropic_request_failed',
      }.contains(error.code);
}
