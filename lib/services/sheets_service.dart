// // import 'package:flutter/foundation.dart';
// // import 'package:googleapis/sheets/v4.dart' as sheets;
// // import 'package:googleapis_auth/googleapis_auth.dart' as auth;
// // import '../models/word_model.dart';
// // import '../providers/auth_provider.dart';

// // class SheetsService {
// //   final AuthProvider _authProvider;
// //   SheetsService(this._authProvider);

// //   // 스프레드시트 ID와 시트 이름을 받아 단어를 가져오는 메서드
// //   Future<List<Word>?> getWordsFromSheet(String spreadsheetId, String sheetName) async {
// //     try {
// //       // 인증된 클라이언트 가져오기
// //       final auth.AuthClient? client = await _authProvider.getAuthenticatedClient();
// //       if (client == null) {
// //         throw Exception('Authentication failed.');
// //       }

// //       final sheets.SheetsApi sheetsApi = sheets.SheetsApi(client);
// //       // A열과 B열의 모든 데이터를 요청
// //       final sheet = await sheetsApi.spreadsheets.values.get(spreadsheetId, '$sheetName!A:B');
// //       final values = sheet.values;

// //       if (values != null && values.length > 1) {
// //         // 첫 번째 줄(헤더)을 제외하고 Word 객체로 변환
// //         return values
// //             .skip(1)
// //             .map((row) {
// //               if (row.length >= 2) {
// //                 return Word(word: row[0].toString(), meaning: row[1].toString());
// //               }
// //               return null;
// //             })
// //             .where((word) => word != null)
// //             .cast<Word>()
// //             .toList();
// //       }
// //       return [];
// //     } catch (e) {
// //       debugPrint('Error fetching sheet data: $e');
// //       return null;
// //     } finally {
// //       // 클라이언트 사용 후 닫아주기 (선택사항이지만 좋은 습관)
// //       // client?.close();
// //     }
// //   }
// // }
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
//     auth.AuthClient? client;

//     try {
//       debugPrint('🔍 시트에서 데이터 가져오기 시작');
//       debugPrint('📊 Spreadsheet ID: $spreadsheetId');
//       debugPrint('📋 Sheet Name: $sheetName');

//       // 1. 인증 상태 확인
//       debugPrint('🔐 인증 상태 확인 중...');
//       client = await _authProvider.getAuthenticatedClient();

//       if (client == null) {
//         debugPrint('❌ 인증 실패: 클라이언트가 null입니다.');
//         throw Exception('Authentication failed - client is null');
//       }

//       debugPrint('✅ 인증 성공');

//       // 2. Sheets API 초기화
//       final sheets.SheetsApi sheetsApi = sheets.SheetsApi(client);
//       debugPrint('🚀 Sheets API 초기화 완료');

//       // 3. 스프레드시트 접근 권한 확인
//       debugPrint('📊 스프레드시트 메타데이터 확인 중...');
//       try {
//         final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
//         debugPrint('✅ 스프레드시트 접근 가능: ${spreadsheet.properties?.title}');

//         // 시트 목록 출력
//         final sheetTitles = spreadsheet.sheets?.map((s) => s.properties?.title).toList();
//         debugPrint('📋 사용 가능한 시트들: $sheetTitles');

//         // 요청한 시트가 존재하는지 확인
//         final sheetExists = sheetTitles?.contains(sheetName) == true;
//         if (!sheetExists) {
//           debugPrint('❌ 시트 "$sheetName"를 찾을 수 없습니다.');
//           debugPrint('💡 사용 가능한 시트: $sheetTitles');
//           throw Exception('Sheet "$sheetName" not found. Available sheets: $sheetTitles');
//         }
//       } catch (e) {
//         debugPrint('❌ 스프레드시트 접근 실패: $e');
//         if (e.toString().contains('404')) {
//           throw Exception('Spreadsheet not found or no access permission');
//         } else if (e.toString().contains('403')) {
//           throw Exception('Permission denied. Please check sharing settings');
//         }
//         rethrow;
//       }

//       // 4. 데이터 가져오기 (범위를 더 구체적으로 지정)
//       final range = '$sheetName!A:B';
//       debugPrint('📊 데이터 범위: $range');

//       final sheet = await sheetsApi.spreadsheets.values.get(
//         spreadsheetId,
//         range,
//         valueRenderOption: 'UNFORMATTED_VALUE', // 원본 값으로 가져오기
//         dateTimeRenderOption: 'SERIAL_NUMBER',
//       );

//       final values = sheet.values;
//       debugPrint('📥 받은 데이터 행 수: ${values?.length ?? 0}');

//       if (values != null && values.isNotEmpty) {
//         debugPrint('📋 첫 번째 행 (헤더): ${values.first}');

//         if (values.length > 1) {
//           debugPrint('📝 두 번째 행 (데이터 예시): ${values[1]}');

//           // 5. Word 객체로 변환
//           final words = <Word>[];
//           int processedCount = 0;
//           int skippedCount = 0;

//           for (int i = 1; i < values.length; i++) {
//             // 헤더 스킵
//             final row = values[i];

//             if (row.length >= 2 &&
//                 row[0] != null &&
//                 row[0].toString().trim().isNotEmpty &&
//                 row[1] != null &&
//                 row[1].toString().trim().isNotEmpty) {
//               final word = Word(word: row[0].toString().trim(), meaning: row[1].toString().trim());
//               words.add(word);
//               processedCount++;

//               // 처음 3개만 로그로 출력
//               if (i <= 3) {
//                 debugPrint('✅ 처리된 단어 $i: ${word.word} -> ${word.meaning}');
//               }
//             } else {
//               skippedCount++;
//               if (skippedCount <= 3) {
//                 // 처음 3개 스킵된 것만 로그
//                 debugPrint('⚠️ 스킵된 행 $i: $row (빈 값 또는 불완전한 데이터)');
//               }
//             }
//           }

//           debugPrint('📊 처리 완료: $processedCount개 성공, $skippedCount개 스킵');

//           if (words.isEmpty) {
//             debugPrint('⚠️ 유효한 단어 데이터가 없습니다.');
//             return [];
//           }

//           debugPrint('🎉 성공적으로 ${words.length}개의 단어를 가져왔습니다.');
//           return words;
//         } else {
//           debugPrint('⚠️ 헤더만 있고 데이터가 없습니다.');
//           return [];
//         }
//       } else {
//         debugPrint('⚠️ 시트가 비어있습니다.');
//         return [];
//       }
//     } catch (e, stackTrace) {
//       debugPrint('❌ SheetsService 오류 발생:');
//       debugPrint('오류 메시지: $e');
//       debugPrint('스택 트레이스: $stackTrace');

//       // 구체적인 오류 메시지 제공
//       String errorMessage = 'Unknown error occurred';

//       if (e.toString().contains('Authentication')) {
//         errorMessage = '인증 오류: Google 계정 로그인을 확인해주세요.';
//       } else if (e.toString().contains('404')) {
//         errorMessage = '스프레드시트를 찾을 수 없습니다. ID를 확인해주세요.';
//       } else if (e.toString().contains('403')) {
//         errorMessage = '권한이 없습니다. 스프레드시트 공유 설정을 확인해주세요.';
//       } else if (e.toString().contains('Sheet') && e.toString().contains('not found')) {
//         errorMessage = e.toString(); // 시트 이름 오류는 그대로 전달
//       } else if (e.toString().contains('network') || e.toString().contains('connection')) {
//         errorMessage = '네트워크 연결을 확인해주세요.';
//       } else {
//         errorMessage = '시트 데이터를 가져오는 중 오류가 발생했습니다: ${e.toString()}';
//       }

//       throw Exception(errorMessage);
//     } finally {
//       // 클라이언트 리소스 정리
//       client?.close();
//       debugPrint('🔧 리소스 정리 완료');
//     }
//   }

//   // 스프레드시트 연결 테스트 메서드 추가
//   Future<bool> testConnection(String spreadsheetId) async {
//     try {
//       final client = await _authProvider.getAuthenticatedClient();
//       if (client == null) return false;

//       final sheetsApi = sheets.SheetsApi(client);
//       final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);

//       client.close();
//       return spreadsheet.spreadsheetId == spreadsheetId;
//     } catch (e) {
//       debugPrint('연결 테스트 실패: $e');
//       return false;
//     }
//   }
// }

import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:googleapis/drive/v3.dart' as drive; // Drive API 추가
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import '../models/word_model.dart';
import '../providers/auth_provider.dart';

class SheetsService {
  final AuthProvider _authProvider;
  SheetsService(this._authProvider);

  // --- 신규 추가: 구글 드라이브에서 스프레드시트 파일 목록 가져오기 ---
  Future<List<drive.File>> listSpreadsheets() async {
    auth.AuthClient? client;
    try {
      client = await _authProvider.getAuthenticatedClient();
      if (client == null) throw Exception('Authentication failed.');

      final driveApi = drive.DriveApi(client);
      final result = await driveApi.files.list(
        q: "mimeType='application/vnd.google-apps.spreadsheet'", // 스프레드시트만 필터링
        $fields: "files(id, name, modifiedTime, iconLink)", // 필요한 필드만 요청
      );

      return result.files ?? [];
    } catch (e) {
      debugPrint('Error listing spreadsheets: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  // --- 신규 추가: 특정 스프레드시트의 시트(탭) 목록 가져오기 ---
  Future<List<sheets.Sheet>> getSheetInfo(String spreadsheetId) async {
    auth.AuthClient? client;
    try {
      client = await _authProvider.getAuthenticatedClient();
      if (client == null) throw Exception('Authentication failed.');

      final sheetsApi = sheets.SheetsApi(client);
      final spreadsheet = await sheetsApi.spreadsheets.get(
        spreadsheetId,
        $fields: 'sheets.properties',
      );
      return spreadsheet.sheets ?? [];
    } catch (e) {
      debugPrint('Error getting sheet info: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  // 디버깅을 위한 상세 로그가 포함된 메서드
  Future<List<Word>?> getWordsFromSheet(String spreadsheetId, String sheetName) async {
    auth.AuthClient? client;
    DateTime startTime = DateTime.now();

    try {
      debugPrint('🚀 [${DateTime.now()}] 시트 데이터 가져오기 시작');
      debugPrint('📊 Spreadsheet ID: $spreadsheetId');
      debugPrint('📋 Sheet Name: $sheetName');

      // 1. 인증 단계
      debugPrint('🔐 [Step 1] 인증 클라이언트 요청 중...');
      client = await _authProvider.getAuthenticatedClient();

      if (client == null) {
        debugPrint('❌ [Step 1] 인증 실패 - 클라이언트가 null');
        throw Exception('인증 실패: 다시 로그인해주세요.');
      }
      debugPrint('✅ [Step 1] 인증 성공');

      // 2. API 초기화
      debugPrint('🔧 [Step 2] Sheets API 초기화 중...');
      final sheets.SheetsApi sheetsApi = sheets.SheetsApi(client);
      debugPrint('✅ [Step 2] Sheets API 초기화 완료');

      // 3. 스프레드시트 접근 테스트
      debugPrint('🔍 [Step 3] 스프레드시트 접근 테스트 중...');
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      debugPrint('✅ [Step 3] 스프레드시트 접근 성공: ${spreadsheet.properties?.title}');

      // 4. 시트 목록 확인
      debugPrint('📋 [Step 4] 시트 목록 확인 중...');
      final availableSheets = spreadsheet.sheets?.map((s) => s.properties?.title).toList() ?? [];
      debugPrint('📋 [Step 4] 사용 가능한 시트: $availableSheets');

      if (!availableSheets.contains(sheetName)) {
        debugPrint('❌ [Step 4] 시트 "$sheetName" 찾을 수 없음');
        throw Exception('시트 "$sheetName"를 찾을 수 없습니다.\n사용 가능한 시트: ${availableSheets.join(", ")}');
      }
      debugPrint('✅ [Step 4] 시트 "$sheetName" 존재 확인');

      // 5. 데이터 범위 설정
      final range = '$sheetName!A:B';
      debugPrint('📊 [Step 5] 데이터 범위 설정: $range');

      // 6. 데이터 요청
      debugPrint('📥 [Step 6] 데이터 요청 중...');
      final valueRange = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        range,
        valueRenderOption: 'UNFORMATTED_VALUE',
      );

      final values = valueRange.values;
      debugPrint('📥 [Step 6] 데이터 수신 완료: ${values?.length ?? 0}행');

      // 7. 데이터 검증
      debugPrint('🔍 [Step 7] 데이터 검증 중...');
      if (values == null || values.isEmpty) {
        debugPrint('⚠️ [Step 7] 데이터가 없음');
        return [];
      }

      debugPrint('📋 [Step 7] 첫 번째 행: ${values.first}');
      if (values.length > 1) {
        debugPrint('📋 [Step 7] 두 번째 행: ${values[1]}');
      }

      // 8. 데이터 파싱
      debugPrint('🔄 [Step 8] 데이터 파싱 시작...');
      final words = <Word>[];
      int successCount = 0;
      int skipCount = 0;

      for (int i = 1; i < values.length; i++) {
        try {
          final row = values[i];

          if (row.length >= 2) {
            final wordText = row[0]?.toString().trim() ?? '';
            final meaningText = row[1]?.toString().trim() ?? '';

            if (wordText.isNotEmpty && meaningText.isNotEmpty) {
              final word = Word(word: wordText, meaning: meaningText);
              words.add(word);
              successCount++;

              if (i <= 3) {
                // 처음 3개만 로그
                debugPrint('✅ [Step 8] 행 $i: "$wordText" -> "$meaningText"');
              }
            } else {
              skipCount++;
              if (skipCount <= 3) {
                debugPrint('⚠️ [Step 8] 행 $i 스킵: 빈 값 ("$wordText", "$meaningText")');
              }
            }
          } else {
            skipCount++;
            if (skipCount <= 3) {
              debugPrint('⚠️ [Step 8] 행 $i 스킵: 컬럼 부족 (${row.length}개)');
            }
          }
        } catch (e) {
          skipCount++;
          debugPrint('❌ [Step 8] 행 $i 파싱 오류: $e');
        }
      }

      final duration = DateTime.now().difference(startTime);
      debugPrint('🎉 [완료] ${words.length}개 단어 처리 완료 (성공: $successCount, 스킵: $skipCount)');
      debugPrint('⏱️ [완료] 총 소요시간: ${duration.inMilliseconds}ms');

      return words;
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('❌ [오류] 처리 실패 (소요시간: ${duration.inMilliseconds}ms)');
      debugPrint('❌ [오류] 오류 타입: ${e.runtimeType}');
      debugPrint('❌ [오류] 오류 메시지: $e');
      debugPrint('❌ [오류] 스택 트레이스: $stackTrace');

      // 구체적인 오류 분류
      if (e.toString().contains('SocketException') ||
          e.toString().contains('NetworkException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception('네트워크 연결 오류: 인터넷 연결을 확인해주세요.');
      } else if (e.toString().contains('HttpException') && e.toString().contains('429')) {
        throw Exception('API 호출 제한 초과: 잠시 후 다시 시도해주세요.');
      } else if (e.toString().contains('HttpException') && e.toString().contains('401')) {
        throw Exception('인증 오류: 다시 로그인해주세요.');
      } else if (e.toString().contains('HttpException') && e.toString().contains('403')) {
        throw Exception('권한 오류: 스프레드시트 접근 권한을 확인해주세요.');
      } else if (e.toString().contains('HttpException') && e.toString().contains('404')) {
        throw Exception('스프레드시트를 찾을 수 없습니다: ID를 확인해주세요.');
      } else if (e.toString().contains('FormatException')) {
        throw Exception('데이터 형식 오류: 시트의 데이터 형식을 확인해주세요.');
      } else {
        throw Exception('예상치 못한 오류: ${e.toString()}');
      }
    } finally {
      client?.close();
      debugPrint('🔧 [정리] 리소스 정리 완료');
    }
  }

  // 간단한 연결 테스트 메서드
  Future<Map<String, dynamic>> diagnoseConnection(String spreadsheetId) async {
    final diagnosis = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'spreadsheetId': spreadsheetId,
      'steps': <String, dynamic>{},
    };

    try {
      // 1. 인증 테스트
      final client = await _authProvider.getAuthenticatedClient();
      diagnosis['steps']['authentication'] = client != null;

      if (client != null) {
        // 2. API 초기화 테스트
        final sheetsApi = sheets.SheetsApi(client);
        diagnosis['steps']['api_initialization'] = true;

        // 3. 스프레드시트 접근 테스트
        try {
          final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
          diagnosis['steps']['spreadsheet_access'] = true;
          diagnosis['spreadsheet_title'] = spreadsheet.properties?.title;
          diagnosis['available_sheets'] =
              spreadsheet.sheets?.map((s) => s.properties?.title).toList();
        } catch (e) {
          diagnosis['steps']['spreadsheet_access'] = false;
          diagnosis['spreadsheet_error'] = e.toString();
        }

        client.close();
      }
    } catch (e) {
      diagnosis['error'] = e.toString();
    }

    return diagnosis;
  }
}
