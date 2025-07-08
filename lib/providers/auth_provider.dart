import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
// ▼▼▼ [추가] 새로 설치한 패키지를 import 합니다. ▼▼▼
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

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
    _googleSignIn.onCurrentUserChanged.listen((account) {
      _currentUser = account;
      notifyListeners();
    });
    _googleSignIn.signInSilently();
  }

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

  // ▼▼▼ [수정] 인증된 http 클라이언트를 가져오는 방식을 더 안정적으로 변경 ▼▼▼
  Future<auth.AuthClient?> getAuthenticatedClient() async {
    // getAuthenticatedClient 함수는 이제 더 이상 사용되지 않습니다.
    // 대신, google_sign_in 패키지에서 제공하는 extension을 사용합니다.
    // 이 방식은 토큰 만료 및 갱신을 자동으로 처리해줍니다.
    if (await _googleSignIn.isSignedIn()) {
      return await _googleSignIn.authenticatedClient();
    }
    return null;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
