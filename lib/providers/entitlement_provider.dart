import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_entitlement.dart';
import '../services/analytics_service.dart';
import '../services/app_config_service.dart';

class EntitlementProvider extends ChangeNotifier {
  EntitlementProvider({
    required AppConfigService appConfig,
    required AnalyticsService analytics,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _appConfig = appConfig,
       _analytics = analytics,
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance {
    _appConfig.addListener(_handleConfigChanged);
  }

  final AppConfigService _appConfig;
  final AnalyticsService _analytics;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  StreamSubscription<User?>? _authSubscription;
  Future<void>? _initializationFuture;
  EntitlementSnapshot _snapshot = const EntitlementSnapshot();
  bool _initialized = false;
  bool _loading = false;
  String? _lastError;

  EntitlementSnapshot get snapshot => _snapshot;
  AppPlan get plan => _snapshot.plan;
  bool get initialized => _initialized;
  bool get loading => _loading;
  bool get isFoundingMember => _snapshot.foundingMember;
  bool get isServerConfirmed => _snapshot.isServerConfirmed;
  bool get usesAnonymousIdentity => _auth.currentUser?.isAnonymous ?? true;
  String? get lastError => _lastError;

  bool canUse(AppFeature feature) {
    if (_appConfig.isLaunchFree) return true;
    if (_snapshot.hasFullAccess) return true;
    return feature.isAlwaysFree;
  }

  Future<void> initialize() {
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    _loading = true;
    notifyListeners();

    _authSubscription ??= _auth.authStateChanges().listen((user) {
      if (_initialized && user != null) unawaited(_loadOrClaim(user));
    });

    try {
      final user = await _getOrCreateUser();
      if (user != null) await _loadOrClaim(user);
    } catch (error) {
      _lastError = error.toString();
      debugPrint('EntitlementProvider: identity initialization failed: $error');
    } finally {
      _initialized = true;
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();

    try {
      final user = await _getOrCreateUser();
      if (user != null) await _loadOrClaim(user);
    } catch (error) {
      _lastError = error.toString();
      debugPrint('EntitlementProvider: manual sync failed: $error');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<User?> _getOrCreateUser() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser;

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return (await _auth.signInAnonymously()).user;
      } on FirebaseAuthException catch (error) {
        final canRetry = error.code == 'network-request-failed' && attempt == 0;
        if (!canRetry) rethrow;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  Future<void> deleteCloudIdentity() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('entitlements').doc(user.uid).delete();
    await user.delete();
    _snapshot = const EntitlementSnapshot();
    notifyListeners();
  }

  Future<void> _loadOrClaim(User user) async {
    final reference = _firestore.collection('entitlements').doc(user.uid);
    try {
      var document = await reference.get();
      var claimedNow = false;
      if (!document.exists && _appConfig.foundingProgramOpen) {
        await reference.set({
          'plan': AppPlan.founding.name,
          'foundingMember': true,
          'claimedAt': FieldValue.serverTimestamp(),
          'source': 'launch_founding_program',
          'schemaVersion': 1,
        });
        claimedNow = true;
        document = await reference.get();
      }

      _snapshot = _snapshotFrom(document.data());
      _lastError = null;
      await _analytics.setPlan(_snapshot.plan.name);
      if (claimedNow && _snapshot.foundingMember) {
        await _analytics.logFoundingRegistrationCompleted();
      }
      notifyListeners();
    } catch (error) {
      _lastError = error.toString();
      debugPrint('EntitlementProvider: entitlement sync deferred: $error');
      notifyListeners();
    }
  }

  EntitlementSnapshot _snapshotFrom(Map<String, dynamic>? data) {
    if (data == null) return const EntitlementSnapshot();
    final claimedAt = data['claimedAt'];
    return EntitlementSnapshot(
      plan: EntitlementSnapshot.parsePlan(data['plan']),
      foundingMember: data['foundingMember'] == true,
      claimedAt: claimedAt is Timestamp ? claimedAt.toDate() : null,
      isServerConfirmed: true,
    );
  }

  void _handleConfigChanged() {
    notifyListeners();
    if (_initialized && _appConfig.foundingProgramOpen && !_snapshot.isServerConfirmed) {
      unawaited(refresh());
    }
  }

  @override
  void dispose() {
    _appConfig.removeListener(_handleConfigChanged);
    _authSubscription?.cancel();
    super.dispose();
  }
}
