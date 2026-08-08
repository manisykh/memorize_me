import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

import '../models/word_model.dart';
import '../providers/auth_provider.dart';

class SheetsService {
  final AuthProvider _authProvider;

  SheetsService(this._authProvider);

  Future<List<sheets.Sheet>> getSheetInfo(String spreadsheetId) async {
    auth.AuthClient? client;
    try {
      client = await _authProvider.getAuthenticatedClient();
      if (client == null) {
        throw Exception('Google 로그인이 필요합니다.');
      }

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheet = await sheetsApi.spreadsheets.get(
        spreadsheetId,
        $fields: 'sheets.properties',
      );
      return spreadsheet.sheets ?? const <sheets.Sheet>[];
    } catch (error) {
      debugPrint('SheetsService.getSheetInfo failed: $error');
      throw Exception(_friendlySheetsError(error));
    } finally {
      client?.close();
    }
  }

  Future<List<Word>?> getWordsFromSheet(String spreadsheetId, String sheetName) async {
    auth.AuthClient? client;
    try {
      client = await _authProvider.getAuthenticatedClient();
      if (client == null) {
        throw Exception('Google 로그인이 필요합니다.');
      }

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final availableSheets =
          spreadsheet.sheets?.map((sheet) => sheet.properties?.title).toList() ??
          const <String?>[];
      if (!availableSheets.contains(sheetName)) {
        throw Exception(
          '시트 "$sheetName"을 찾을 수 없습니다. 사용 가능한 시트: ${availableSheets.whereType<String>().join(', ')}',
        );
      }

      final valueRange = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        '$sheetName!A:B',
        valueRenderOption: 'UNFORMATTED_VALUE',
      );
      final values = valueRange.values;
      if (values == null || values.isEmpty) return <Word>[];

      final words = <Word>[];
      for (var index = 1; index < values.length; index++) {
        final row = values[index];
        if (row.length < 2) continue;

        final word = row[0]?.toString().trim() ?? '';
        final meaning = row[1]?.toString().trim() ?? '';
        if (word.isEmpty || meaning.isEmpty) continue;

        words.add(Word(word: word, meaning: meaning));
      }
      return words;
    } catch (error, stackTrace) {
      debugPrint('SheetsService.getWordsFromSheet failed: $error');
      debugPrint('$stackTrace');
      throw Exception(_friendlySheetsError(error));
    } finally {
      client?.close();
    }
  }

  Future<Map<String, dynamic>> diagnoseConnection(String spreadsheetId) async {
    auth.AuthClient? client;
    final diagnosis = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'spreadsheetId': spreadsheetId,
      'steps': <String, dynamic>{},
    };

    try {
      client = await _authProvider.getAuthenticatedClient();
      diagnosis['steps']['authentication'] = client != null;
      if (client == null) return diagnosis;

      final sheetsApi = sheets.SheetsApi(client);
      diagnosis['steps']['apiInitialization'] = true;

      try {
        final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
        diagnosis['steps']['spreadsheetAccess'] = true;
        diagnosis['spreadsheetTitle'] = spreadsheet.properties?.title;
        diagnosis['availableSheets'] =
            spreadsheet.sheets?.map((sheet) => sheet.properties?.title).toList();
      } catch (error) {
        diagnosis['steps']['spreadsheetAccess'] = false;
        diagnosis['spreadsheetError'] = error.toString();
      }
    } catch (error) {
      diagnosis['error'] = error.toString();
    } finally {
      client?.close();
    }

    return diagnosis;
  }

  String _friendlySheetsError(Object error) {
    final message = error.toString();
    if (message.contains('SocketException') ||
        message.contains('NetworkException') ||
        message.contains('TimeoutException')) {
      return '네트워크 연결을 확인해주세요.';
    }
    if (message.contains('401')) {
      return 'Google 인증이 만료되었습니다. 다시 로그인해주세요.';
    }
    if (message.contains('403')) {
      return '스프레드시트 접근 권한이 없습니다. 공유 권한을 확인해주세요.';
    }
    if (message.contains('404')) {
      return '스프레드시트를 찾을 수 없습니다. URL 또는 ID를 확인해주세요.';
    }
    if (message.contains('429')) {
      return 'Google API 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
    }
    return message.replaceFirst('Exception: ', '');
  }
}
