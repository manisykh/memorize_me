// import 'package:google_sign_in/google_sign_in.dart';
// import 'package:googleapis_auth/googleapis_auth.dart' as auth;
// import 'package:http/http.dart' as http;
// import 'package:flutter/foundation.dart';

// class AuthService {
//   final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: [
//       // 이 두 가지 권한을 사용자에게 요청합니다.
//       'https://www.googleapis.com/auth/spreadsheets.readonly', // 구글 시트 읽기 권한
//       'https://www.googleapis.com/auth/drive.readonly', // 구글 드라이브 파일 읽기 권한
//     ],
//   );

//   // 현재 로그인된 사용자 정보를 앱의 다른 곳에서 쉽게 접근할 수 있도록 하는 getter
//   GoogleSignInAccount? get currentUser => _googleSignIn.currentUser;

//   // 구글 로그인 과정을 처리하는 메서드
//   Future<bool> signIn() async {
//     try {
//       // 이전에 로그인한 기록이 있으면, 다시 묻지 않고 조용히 로그인 시도
//       await _googleSignIn.signInSilently();
//       // 조용한 로그인이 실패하면, 사용자에게 직접 계정 선택 창을 띄워 로그인
//       if (_googleSignIn.currentUser == null) {
//         await _googleSignIn.signIn();
//       }
//       // 최종적으로 로그인된 사용자가 있는지 확인하여 성공 여부 반환
//       return _googleSignIn.currentUser != null;
//     } catch (error) {
//       debugPrint("AuthService :: Error signing in: $error");
//       return false;
//     }
//   }

//   // 로그아웃 메서드
//   Future<void> signOut() async {
//     try {
//       await _googleSignIn.disconnect();
//       await _googleSignIn.signOut();
//     } catch (error) {
//       debugPrint("AuthService :: Error signing out: $error");
//     }
//   }

//   // 구글 API에 요청을 보낼 때 필요한 '인증된 http 클라이언트'를 생성하는 메서드
//   Future<auth.AuthClient?> getAuthenticatedClient() async {
//     try {
//       final headers = await _googleSignIn.currentUser?.authHeaders;
//       if (headers == null) {
//         debugPrint("AuthService :: User not signed in or headers are null.");
//         return null;
//       }

//       // 헤더에서 Access Token 정보를 추출
//       final String accessToken = headers['Authorization']!.substring(7); // 'Bearer ' 부분 제외
//       final expiry = DateTime.now().toUtc().add(const Duration(hours: 1)); // 유효기간 1시간으로 설정

//       final credentials = auth.AccessCredentials(
//         auth.AccessToken('Bearer', accessToken, expiry),
//         null, // Refresh Token은 필요 없음
//         _googleSignIn.scopes,
//       );

//       return auth.authenticatedClient(http.Client(), credentials);
//     } catch (e) {
//       debugPrint("AuthService :: Error getting authenticated client: $e");
//       return null;
//     }
//   }
// }
