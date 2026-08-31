import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/googleapis_auth.dart' as auth;
import 'package:http/http.dart' as http;
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class AuthProvider extends ChangeNotifier {
  static const _driveFileScope = 'https://www.googleapis.com/auth/drive.file';

  final firebase_auth.FirebaseAuth _firebaseAuth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [_driveFileScope],
  );

  String? _pickerAccessToken;
  DateTime? _pickerAccessTokenExpiry;

  GoogleSignInAccount? _currentUser;
  GoogleSignInAccount? get currentUser => _currentUser;
  bool get isGoogleDriveConnected => _currentUser != null;
  bool get hasGoogleCloudIdentity {
    final user = _firebaseAuth.currentUser;
    if (user == null || user.isAnonymous) return false;
    return user.providerData.any(
      (provider) => provider.providerId == firebase_auth.GoogleAuthProvider.PROVIDER_ID,
    );
  }
  String? get cloudIdentityEmail => _firebaseAuth.currentUser?.email;

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

  Future<void> disconnectGoogleDrive() async {
    _setLoading(true);
    try {
      _pickerAccessToken = null;
      _pickerAccessTokenExpiry = null;
      try {
        await _googleSignIn.disconnect();
      } catch (error) {
        debugPrint("AuthProvider :: Google access revocation deferred: $error");
      }
      try {
        await _googleSignIn.signOut();
      } catch (error) {
        debugPrint("AuthProvider :: Google local sign-out deferred: $error");
      }
    } finally {
      _currentUser = null;
      _setLoading(false);
    }
  }

  Future<void> signOut() => disconnectGoogleDrive();

  Future<void> reauthenticateForCloudDeletion() async {
    final firebaseUser = _firebaseAuth.currentUser;
    if (firebaseUser == null || firebaseUser.isAnonymous) return;

    final googleUser = _currentUser;
    if (googleUser == null) {
      throw StateError('클라우드 계정을 삭제하려면 연결했던 Google 계정을 먼저 다시 연결해주세요.');
    }
    if (firebaseUser.email != null && firebaseUser.email != googleUser.email) {
      throw StateError('Founding 혜택을 보관한 Google 계정으로 다시 연결해주세요.');
    }

    final authentication = await googleUser.authentication;
    final credential = firebase_auth.GoogleAuthProvider.credential(
      accessToken: authentication.accessToken,
      idToken: authentication.idToken,
    );
    await firebaseUser.reauthenticateWithCredential(credential);
  }

  Future<auth.AuthClient?> getAuthenticatedClient() async {
    final pickerToken = _pickerAccessToken;
    final pickerTokenExpiry = _pickerAccessTokenExpiry;
    if (pickerToken != null &&
        pickerTokenExpiry != null &&
        DateTime.now().toUtc().isBefore(pickerTokenExpiry)) {
      final credentials = auth.AccessCredentials(
        auth.AccessToken('Bearer', pickerToken, pickerTokenExpiry),
        null,
        const [_driveFileScope],
      );
      return auth.authenticatedClient(
        http.Client(),
        credentials,
        closeUnderlyingClient: true,
      );
    }

    if (await _googleSignIn.isSignedIn()) {
      return await _googleSignIn.authenticatedClient();
    }
    return null;
  }

  void usePickerAccessToken(String accessToken) {
    _pickerAccessToken = accessToken;
    _pickerAccessTokenExpiry = DateTime.now().toUtc().add(const Duration(minutes: 50));
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
    } finally {
      notifyListeners();
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
