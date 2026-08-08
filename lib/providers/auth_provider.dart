import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
// ▼▼▼ [추가] 새로 설치한 패키지를 import 합니다. ▼▼▼
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class AuthProvider extends ChangeNotifier {
  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/spreadsheets.readonly',
      'https://www.googleapis.com/auth/drive.file',
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
      if (account != null) {
        unawaited(_syncFirebaseIdentity(account));
      }
    });
    unawaited(_restoreGoogleSession());
  }

  Future<void> signIn() async {
    _setLoading(true);
    try {
      final account = await _googleSignIn.signIn();
      if (account != null) {
        _currentUser = account;
        await _syncFirebaseIdentity(account);
      }
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

  Future<String?> getAccessToken() async {
    final user = _currentUser ?? await _googleSignIn.signInSilently();
    final authentication = await user?.authentication;
    return authentication?.accessToken;
  }

  Future<void> _restoreGoogleSession() async {
    final account = await _googleSignIn.signInSilently();
    if (account == null) return;
    _currentUser = account;
    notifyListeners();
    await _syncFirebaseIdentity(account);
  }

  Future<void> _syncFirebaseIdentity(GoogleSignInAccount account) async {
    try {
      final authentication = await account.authentication;
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      );
      final currentUser = _firebaseAuth.currentUser;

      if (currentUser == null) {
        await _firebaseAuth.signInWithCredential(credential);
        return;
      }

      if (currentUser.isAnonymous) {
        try {
          await currentUser.linkWithCredential(credential);
        } on firebase_auth.FirebaseAuthException catch (error) {
          if (error.code == 'credential-already-in-use' ||
              error.code == 'account-exists-with-different-credential') {
            await _firebaseAuth.signInWithCredential(credential);
          } else {
            rethrow;
          }
        }
        return;
      }

      final linkedGoogleAccount = currentUser.providerData.any(
        (provider) => provider.providerId == firebase_auth.GoogleAuthProvider.PROVIDER_ID,
      );
      if (!linkedGoogleAccount || currentUser.email != account.email) {
        await _firebaseAuth.signInWithCredential(credential);
      }
    } catch (error) {
      debugPrint('AuthProvider :: Firebase identity sync deferred: $error');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
