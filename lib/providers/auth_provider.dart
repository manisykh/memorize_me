import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/spreadsheets.readonly',
      'https://www.googleapis.com/auth/drive.readonly',
    ],
  );

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  AuthProvider() {
    // 앱이 시작될 때 사용자의 로그인 상태 변경을 감지
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      notifyListeners(); // 로그인 상태 변경을 UI에 알림
    });
    // 앱 시작 시 조용히 로그인 시도
    _googleSignIn.signInSilently();
  }

  // 로그인 메서드
  Future<void> signIn() async {
    _setLoading(true);
    try {
      await _googleSignIn.signIn();
    } catch (error) {
      debugPrint("AuthProvider :: Error signing in: $error");
    } finally {
      _setLoading(false);
    }
  }

  // 로그아웃 메서드
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _googleSignIn.disconnect();
      await _googleSignIn.signOut();
    } catch (error) {
      debugPrint("AuthProvider :: Error signing out: $error");
    } finally {
      _setLoading(false);
    }
  }

  // API 요청을 위한 인증된 http 클라이언트 생성
  Future<auth.AuthClient?> getAuthenticatedClient() async {
    try {
      final headers = await _googleSignIn.currentUser?.authHeaders;
      if (headers == null) {
        debugPrint("AuthProvider :: User not signed in or headers are null.");
        return null;
      }

      final String accessToken = headers['Authorization']!.substring(7);
      final expiry = DateTime.now().toUtc().add(const Duration(hours: 1));

      final credentials = auth.AccessCredentials(
        auth.AccessToken('Bearer', accessToken, expiry),
        null,
        _googleSignIn.scopes,
      );

      return auth.authenticatedClient(http.Client(), credentials);
    } catch (e) {
      debugPrint("AuthProvider :: Error getting authenticated client: $e");
      return null;
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
