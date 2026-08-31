import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;

import '../models/word_model.dart';
import '../providers/auth_provider.dart';
import 'word_data_parser.dart';

class SheetsService {
  final AuthProvider _authProvider;

  SheetsService(this._authProvider);

  Future<String?> getSpreadsheetTitle(String spreadsheetId) async {
    auth.AuthClient? client;
    try {
      client = await _authProvider.getAuthenticatedClient();
      if (client == null) {
        throw Exception('Google 로그인이 필요합니다.');
      }

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheet = await sheetsApi.spreadsheets.get(
        spreadsheetId,
        $fields: 'properties.title',
      );
      return spreadsheet.properties?.title;
    } catch (error) {
      debugPrint('SheetsService.getSpreadsheetTitle failed: $error');
      throw Exception(_friendlySheetsError(error));
    } finally {
      client?.close();
    }
  }

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
    final rows = await getRowsFromSheet(spreadsheetId, sheetName);
    if (rows.isEmpty) return <Word>[];
    return WordDataParser.parseRows(rows);
  }

  Future<List<List<Object?>>> getRowsFromSheet(
    String spreadsheetId,
    String sheetName,
  ) async {
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
        "'${sheetName.replaceAll("'", "''")}'!A:Z",
        valueRenderOption: 'UNFORMATTED_VALUE',
      );
      final values = valueRange.values;
      if (values == null || values.isEmpty) return <List<Object?>>[];
      return values.map((row) => row.cast<Object?>()).toList();
    } catch (error, stackTrace) {
      debugPrint('SheetsService.getRowsFromSheet failed: $error');
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
      return '이 앱에 허용되지 않은 스프레드시트입니다. Google Drive에서 파일을 다시 선택해주세요.';
    }
    if (message.contains('404')) {
      return '스프레드시트를 찾을 수 없거나 이 앱에 아직 허용되지 않았습니다. Google Drive에서 파일을 다시 선택해주세요.';
    }
    if (message.contains('429')) {
      return 'Google API 요청 한도를 초과했습니다. 잠시 후 다시 시도해주세요.';
    }
    return message.replaceFirst('Exception: ', '');
  }
}
