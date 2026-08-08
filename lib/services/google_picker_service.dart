import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';

class PickedSpreadsheet {
  final String id;
  final String name;

  const PickedSpreadsheet({required this.id, required this.name});
}

class GooglePickerService {
  static const _channel = MethodChannel('memorize_me/google_picker');
  static const _defaultPickerWebUrl =
      'https://memorize-me-71f4e.web.app/google_picker.html';

  static const _configuredPickerWebUrl = String.fromEnvironment(
    'GOOGLE_PICKER_WEB_URL',
  );
  static const _pickerWebUrl =
      _configuredPickerWebUrl == '' ? _defaultPickerWebUrl : _configuredPickerWebUrl;

  final AuthProvider _authProvider;

  const GooglePickerService(this._authProvider);

  bool get isConfigured => _pickerWebUrl.isNotEmpty;

  Future<PickedSpreadsheet?> pickSpreadsheet() async {
    if (!isConfigured) {
      throw Exception(
        'Google Drive 파일 선택기가 설정되지 않았습니다. 앱 실행 또는 빌드 시 GOOGLE_PICKER_WEB_URL을 지정해주세요.',
      );
    }

    var accessToken = await _authProvider.getAccessToken();
    if (accessToken == null || accessToken.isEmpty) {
      await _authProvider.signIn();
      accessToken = await _authProvider.getAccessToken();
    }

    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('Google 계정 로그인이 필요합니다.');
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickSpreadsheet',
      {'pickerUrl': _pickerWebUrl},
    );

    if (result == null) return null;
    final id = result['id']?.toString();
    if (id == null || id.isEmpty) return null;
    return PickedSpreadsheet(
      id: id,
      name: result['name']?.toString() ?? 'Google Sheets',
    );
  }
}
