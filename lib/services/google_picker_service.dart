import 'package:flutter/services.dart';

import '../providers/auth_provider.dart';

class PickedSpreadsheet {
  final String id;
  final String name;

  const PickedSpreadsheet({required this.id, required this.name});
}

class GooglePickerService {
  static const _channel = MethodChannel('memorize_me/google_picker');

  final AuthProvider _authProvider;

  const GooglePickerService(this._authProvider);

  bool get isConfigured => true;

  Future<PickedSpreadsheet?> pickSpreadsheet() async {
    var user = _authProvider.currentUser;
    if (user == null) {
      await _authProvider.signIn();
      user = _authProvider.currentUser;
    }

    if (user == null) {
      throw Exception('Google 계정 로그인이 필요합니다.');
    }

    final result = await _channel.invokeMapMethod<String, dynamic>(
      'pickSpreadsheet',
      {'accountEmail': user.email},
    );

    if (result == null) return null;
    final id = result['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final accessToken = result['accessToken']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception('선택한 Google Drive 파일의 접근 권한을 확인하지 못했습니다.');
    }
    _authProvider.usePickerAccessToken(accessToken);

    return PickedSpreadsheet(
      id: id,
      name: result['name']?.toString() ?? 'Google Sheets',
    );
  }
}
