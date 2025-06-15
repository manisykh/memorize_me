// import 'package:flutter/foundation.dart';
// import 'package:googleapis/sheets/v4.dart' as sheets;
// import 'package:googleapis_auth/googleapis_auth.dart' as auth;
// import '../models/word_model.dart';
// import '../providers/auth_provider.dart';

// class SheetsService {
//   final AuthProvider _authProvider;
//   SheetsService(this._authProvider);

//   // 스프레드시트 ID와 시트 이름을 받아 단어를 가져오는 메서드
//   Future<List<Word>?> getWordsFromSheet(String spreadsheetId, String sheetName) async {
//     try {
//       // 인증된 클라이언트 가져오기
//       final auth.AuthClient? client = await _authProvider.getAuthenticatedClient();
//       if (client == null) {
//         throw Exception('Authentication failed.');
//       }

//       final sheets.SheetsApi sheetsApi = sheets.SheetsApi(client);
//       // A열과 B열의 모든 데이터를 요청
//       final sheet = await sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetName!A:B');
//       final values = sheet.values;

//       if (values != null && values.length > 1) {
//         // 첫 번째 줄(헤더)을 제외하고 Word 객체로 변환
//         return values
//             .skip(1)
//             .map((row) {
//               if (row.length >= 2) {
//                 return Word(word: row[0].toString(), meaning: row[1].toString());
//               }
//               return null;
//             })
//             .where((word) => word != null)
//             .cast<Word>()
//             .toList();
//       }
//       return [];
//     } catch (e) {
//       debugPrint('Error fetching sheet data: $e');
//       return null;
//     } finally {
//       // 클라이언트 사용 후 닫아주기 (선택사항이지만 좋은 습관)
//       // client?.close();
//     }
//   }
// }
import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import '../models/word_model.dart';
import '../providers/auth_provider.dart';

class SheetsService {
  final AuthProvider _authProvider;
  SheetsService(this._authProvider);

  // 스프레드시트 ID와 시트 이름을 받아 단어를 가져오는 메서드
  Future<List<Word>?> getWordsFromSheet(String spreadsheetId, String sheetName) async {
    auth.AuthClient? client;

    try {
      debugPrint('🔍 시트에서 데이터 가져오기 시작');
      debugPrint('📊 Spreadsheet ID: $spreadsheetId');
      debugPrint('📋 Sheet Name: $sheetName');

      // 1. 인증 상태 확인
      debugPrint('🔐 인증 상태 확인 중...');
      client = await _authProvider.getAuthenticatedClient();

      if (client == null) {
        debugPrint('❌ 인증 실패: 클라이언트가 null입니다.');
        throw Exception('Authentication failed - client is null');
      }

      debugPrint('✅ 인증 성공');

      // 2. Sheets API 초기화
      final sheets.SheetsApi sheetsApi = sheets.SheetsApi(client);
      debugPrint('🚀 Sheets API 초기화 완료');

      // 3. 스프레드시트 접근 권한 확인
      debugPrint('📊 스프레드시트 메타데이터 확인 중...');
      try {
        final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
        debugPrint('✅ 스프레드시트 접근 가능: ${spreadsheet.properties?.title}');

        // 시트 목록 출력
        final sheetTitles = spreadsheet.sheets?.map((s) => s.properties?.title).toList();
        debugPrint('📋 사용 가능한 시트들: $sheetTitles');

        // 요청한 시트가 존재하는지 확인
        final sheetExists = sheetTitles?.contains(sheetName) == true;
        if (!sheetExists) {
          debugPrint('❌ 시트 "$sheetName"를 찾을 수 없습니다.');
          debugPrint('💡 사용 가능한 시트: $sheetTitles');
          throw Exception('Sheet "$sheetName" not found. Available sheets: $sheetTitles');
        }
      } catch (e) {
        debugPrint('❌ 스프레드시트 접근 실패: $e');
        if (e.toString().contains('404')) {
          throw Exception('Spreadsheet not found or no access permission');
        } else if (e.toString().contains('403')) {
          throw Exception('Permission denied. Please check sharing settings');
        }
        rethrow;
      }

      // 4. 데이터 가져오기 (범위를 더 구체적으로 지정)
      final range = '$sheetName!A:B';
      debugPrint('📊 데이터 범위: $range');

      final sheet = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
        valueRenderOption: 'UNFORMATTED_VALUE', // 원본 값으로 가져오기
        dateTimeRenderOption: 'SERIAL_NUMBER',
      );

      final values = sheet.values;
      debugPrint('📥 받은 데이터 행 수: ${values?.length ?? 0}');

      if (values != null && values.isNotEmpty) {
        debugPrint('📋 첫 번째 행 (헤더): ${values.first}');

        if (values.length > 1) {
          debugPrint('📝 두 번째 행 (데이터 예시): ${values[1]}');

          // 5. Word 객체로 변환
          final words = <Word>[];
          int processedCount = 0;
          int skippedCount = 0;

          for (int i = 1; i < values.length; i++) {
            // 헤더 스킵
            final row = values[i];

            if (row.length >= 2 &&
                row[0] != null &&
                row[0].toString().trim().isNotEmpty &&
                row[1] != null &&
                row[1].toString().trim().isNotEmpty) {
              final word = Word(word: row[0].toString().trim(), meaning: row[1].toString().trim());
              words.add(word);
              processedCount++;

              // 처음 3개만 로그로 출력
              if (i <= 3) {
                debugPrint('✅ 처리된 단어 $i: ${word.word} -> ${word.meaning}');
              }
            } else {
              skippedCount++;
              if (skippedCount <= 3) {
                // 처음 3개 스킵된 것만 로그
                debugPrint('⚠️ 스킵된 행 $i: $row (빈 값 또는 불완전한 데이터)');
              }
            }
          }

          debugPrint('📊 처리 완료: $processedCount개 성공, $skippedCount개 스킵');

          if (words.isEmpty) {
            debugPrint('⚠️ 유효한 단어 데이터가 없습니다.');
            return [];
          }

          debugPrint('🎉 성공적으로 ${words.length}개의 단어를 가져왔습니다.');
          return words;
        } else {
          debugPrint('⚠️ 헤더만 있고 데이터가 없습니다.');
          return [];
        }
      } else {
        debugPrint('⚠️ 시트가 비어있습니다.');
        return [];
      }
    } catch (e, stackTrace) {
      debugPrint('❌ SheetsService 오류 발생:');
      debugPrint('오류 메시지: $e');
      debugPrint('스택 트레이스: $stackTrace');

      // 구체적인 오류 메시지 제공
      String errorMessage = 'Unknown error occurred';

      if (e.toString().contains('Authentication')) {
        errorMessage = '인증 오류: Google 계정 로그인을 확인해주세요.';
      } else if (e.toString().contains('404')) {
        errorMessage = '스프레드시트를 찾을 수 없습니다. ID를 확인해주세요.';
      } else if (e.toString().contains('403')) {
        errorMessage = '권한이 없습니다. 스프레드시트 공유 설정을 확인해주세요.';
      } else if (e.toString().contains('Sheet') && e.toString().contains('not found')) {
        errorMessage = e.toString(); // 시트 이름 오류는 그대로 전달
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = '네트워크 연결을 확인해주세요.';
      } else {
        errorMessage = '시트 데이터를 가져오는 중 오류가 발생했습니다: ${e.toString()}';
      }

      throw Exception(errorMessage);
    } finally {
      // 클라이언트 리소스 정리
      client?.close();
      debugPrint('🔧 리소스 정리 완료');
    }
  }

  // 스프레드시트 연결 테스트 메서드 추가
  Future<bool> testConnection(String spreadsheetId) async {
    try {
      final client = await _authProvider.getAuthenticatedClient();
      if (client == null) return false;

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);

      client.close();
      return spreadsheet.spreadsheetId == spreadsheetId;
    } catch (e) {
      debugPrint('연결 테스트 실패: $e');
      return false;
    }
  }
}
